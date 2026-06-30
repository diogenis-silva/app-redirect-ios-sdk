//
//  EventQueueTests.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//
//  Covers durable retry of app-open/events (item 6).

import Testing
import Foundation
@testable import AppRedirect

@MainActor
struct EventQueueTests {

    private func body(_ s: String) -> Data { Data(s.utf8) }

    @Test func enqueuePersistsAcrossInstances() {
        let dir = TestEnv.tempDirectory()
        let net = MockNetworking()

        let queue = EventQueue(networking: net, directory: dir)
        queue.enqueue(path: "mobile/v1/events", body: body("a"))
        queue.enqueue(path: "mobile/v1/app-open", body: body("b"))

        // A fresh instance over the same directory reloads the pending items.
        let reloaded = EventQueue(networking: net, directory: dir)
        #expect(reloaded.pendingCount == 2)
        #expect(reloaded.pendingPaths == ["mobile/v1/events", "mobile/v1/app-open"])
    }

    @Test func drainSendsAllAndClearsOnSuccess() async {
        let dir = TestEnv.tempDirectory()
        let net = MockNetworking()
        let queue = EventQueue(networking: net, directory: dir)

        queue.enqueue(path: "mobile/v1/events", body: body("a"))
        queue.enqueue(path: "mobile/v1/events", body: body("b"))

        await queue.drainNow()

        #expect(queue.pendingCount == 0)
        #expect(await net.sentPaths.count == 2)
        // Persisted state is also empty.
        #expect(EventQueue(networking: net, directory: dir).pendingCount == 0)
    }

    @Test func drainStopsOnFailureAndKeepsItems() async {
        let dir = TestEnv.tempDirectory()
        let net = MockNetworking(sendShouldFail: true)
        let queue = EventQueue(networking: net, directory: dir)

        queue.enqueue(path: "mobile/v1/events", body: body("a"))
        await queue.drainNow()

        #expect(queue.pendingCount == 1)              // kept for next attempt
        #expect(await net.sentPaths.isEmpty)

        // Recover once the network is back.
        await net.setSendShouldFail(false)
        await queue.drainNow()
        #expect(queue.pendingCount == 0)
    }

    @Test func capDropsOldestUnderBackPressure() {
        let dir = TestEnv.tempDirectory()
        let queue = EventQueue(networking: MockNetworking(), directory: dir)

        for i in 0..<205 {
            queue.enqueue(path: "p\(i)", body: body("\(i)"))
        }

        #expect(queue.pendingCount == 200)
        // Oldest five (p0..p4) were dropped; p5 is now the head.
        #expect(queue.pendingPaths.first == "p5")
        #expect(queue.pendingPaths.last == "p204")
    }
}
