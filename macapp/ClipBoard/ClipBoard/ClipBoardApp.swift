//
//  ClipBoardApp.swift
//  ClipBoard
//
//  Created by 汪梓文 on 2025/8/11.
//

import SwiftUI

@main
struct ClipBoardApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
