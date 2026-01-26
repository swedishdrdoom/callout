//
//  CalloutApp.swift
//  Callout
//
//  Voice-first workout logging
//

import SwiftUI
import SwiftData

@main
struct CalloutApp: App {
    /// Persistence controller
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(persistenceController.container)
        }
    }
}
