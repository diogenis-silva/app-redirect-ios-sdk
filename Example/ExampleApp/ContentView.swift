//
//  ContentView.swift
//  ExampleApp
//
//  Created by Diógenis Silva on 12/06/26.
//

import SwiftUI
import AppRedirect

struct ContentView: View {
    @EnvironmentObject private var store: DeepLinkStore

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    LabeledContent("Estado", value: store.status)
                }

                if let result = store.result {
                    Section("Atribuição") {
                        row("hasDeepLink", result.hasDeepLink ? "true" : "false")
                        row("source", result.source.rawValue)
                        if let destination = result.destination { row("destination", destination) }
                        if let type = result.attributionType { row("attributionType", type) }
                        if let confidence = result.confidence { row("confidence", String(format: "%.0f", confidence)) }
                        if let clickId = result.clickId { row("clickId", clickId.uuidString) }
                        if let deepLinkId = result.deepLinkId { row("deepLinkId", deepLinkId.uuidString) }
                        ForEach(result.params.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            row(key, value)
                        }
                    }
                }

                Section("Eventos") {
                    Button("track(\"sign_up\")") { store.track("sign_up") }
                    Button("track(\"purchase\", revenue: 49.90)") { store.trackRevenue() }
                    Button("reset()", role: .destructive) { store.reset() }
                }

                Section("Log") {
                    ForEach(store.log, id: \.self) { entry in
                        Text(entry).font(.caption.monospaced())
                    }
                }
            }
            .navigationTitle("App Redirect")
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value).textSelection(.enabled).multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    ContentView().environmentObject(DeepLinkStore())
}
