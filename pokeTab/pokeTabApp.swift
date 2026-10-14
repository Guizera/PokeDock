//
//  pokeTabApp.swift
//  pokeTab
//
//  Created by José Alves da Cunha on 12/10/26.
//

import SwiftUI
import Sparkle

@main
struct pokeTabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var body: some Scene {
        WindowGroup(id: "pokedex") {
            ContentView()
                .frame(minWidth: 820, minHeight: 620)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }

        Window("Personalizar Dock", id: "dock-editor") {
            DockEditorView()
        }
        .defaultSize(width: 860, height: 760)

        Window("Finanças", id: "finance") {
            FinanceView()
        }
        .defaultSize(width: 650, height: 650)

        Window("Produtividade", id: "productivity") {
            ProductivityView()
        }
        .defaultSize(width: 600, height: 700)
    }
}
