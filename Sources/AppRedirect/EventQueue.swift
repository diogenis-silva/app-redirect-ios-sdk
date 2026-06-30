//
//  EventQueue.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

/// Disk-backed FIFO for non-critical requests (`app-open`, `events`).
/// Guarantees at-least-once delivery across launches when the network is unavailable.
/// `first-open` is intentionally excluded — its retry is driven by `checkDeferredDeepLink`.
@MainActor
final class EventQueue {

    private struct Item: Codable {
        let path: String
        let body: Data
        let createdAt: Date
    }

    private let networking: any Networking
    private let fileURL: URL
    private let maxItems = 200
    private var items: [Item]
    private var draining = false

    init(networking: any Networking, directory: URL? = nil) {
        self.networking = networking

        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppRedirect", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("event-queue.json")

        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode([Item].self, from: data) {
            self.items = stored
        } else {
            self.items = []
        }
    }

    func enqueue(path: String, body: Data) {
        items.append(Item(path: path, body: body, createdAt: Date()))
        if items.count > maxItems {
            items.removeFirst(items.count - maxItems)   // drop oldest under back-pressure
        }
        persist()
        Logger.debug("Queued \(path) (depth: \(items.count))")
    }

    /// Best-effort flush. Stops at the first failure and keeps the remainder for the next attempt.
    func flush() {
        guard !draining, !items.isEmpty else { return }
        draining = true
        Task { await drain() }
    }

    // MARK: - Testing seam

    var pendingCount: Int { items.count }
    var pendingPaths: [String] { items.map(\.path) }

    /// Deterministic flush for tests — awaits the drain instead of detaching a `Task`.
    func drainNow() async {
        guard !draining else { return }
        draining = true
        await drain()
    }

    // MARK: - Private

    private func drain() async {
        defer { draining = false }
        while let item = items.first {
            do {
                try await networking.send(path: item.path, bodyData: item.body)
                items.removeFirst()
                persist()
            } catch {
                Logger.debug("Queue flush paused: \(error)")
                break
            }
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
