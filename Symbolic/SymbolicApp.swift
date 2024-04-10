//
//  SymbolicApp.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/8.
//

import SwiftUI
import SwiftData

@main
struct SymbolicApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            CanvasView()
        }
        .modelContainer(sharedModelContainer)
    }
}
