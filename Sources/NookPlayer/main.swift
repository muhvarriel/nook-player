import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Register available providers
        var providers: [MediaProvider] = [
            AppleMusicAdapter(),
            SpotifyAdapter()
        ]
        
        #if DEBUG
        providers.append(MockMediaAdapter())
        #endif
        
        MediaSessionStore.shared.register(providers: providers)
        
        // Show floating notch overlay
        OverlaySystem.shared.showOverlay(with: AppRootView())
        
        // Create auxiliary Menu Bar item for status, permission prompt, and quitting
        setupMenuBar()
        
        // Debug fonts
        debugPrintRegisteredFonts()
        
        // Request automation permission initially for installed apps
        PermissionManager.shared.checkAll()
    }
    
    private func setupMenuBar() {
        guard let button = statusItem?.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        if let symbolImage = NSImage(systemSymbolName: "waveform", accessibilityDescription: "NookPlayer")?.withSymbolConfiguration(config) {
            button.image = symbolImage
        } else {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "NookPlayer")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "NookPlayer Active", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let preferredMenu = NSMenuItem(title: "Preferred Provider", action: nil, keyEquivalent: "")
        let subMenu = NSMenu()
        
        let providers = ["Auto", "Apple Music", "Spotify"]
        for provider in providers {
            let item = NSMenuItem(title: provider, action: #selector(setPreferredProvider(_:)), keyEquivalent: "")
            item.target = self
            if SettingsStore.shared.preferredProvider == provider {
                item.state = .on
            }
            subMenu.addItem(item)
        }
        preferredMenu.submenu = subMenu
        menu.addItem(preferredMenu)
        
        let checkPermsItem = NSMenuItem(
            title: "Check Scripting Permissions",
            action: #selector(checkPermissions),
            keyEquivalent: ""
        )
        checkPermsItem.target = self
        menu.addItem(checkPermsItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(title: "Quit NookPlayer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )
        
        statusItem?.menu = menu
    }
    
    @objc private func setPreferredProvider(_ sender: NSMenuItem) {
        SettingsStore.shared.preferredProvider = sender.title
        
        // Update checkmarks
        if let subMenu = statusItem?.menu?.items.first(where: { $0.title == "Preferred Provider" })?.submenu {
            for item in subMenu.items {
                item.state = (item.title == sender.title) ? .on : .off
            }
        }
        
        Task {
            await MediaSessionStore.shared.pollNow()
        }
    }
    
    @objc private func checkPermissions() {
        PermissionManager.shared.requestPermission(for: "com.apple.Music")
        PermissionManager.shared.requestPermission(for: "com.spotify.client")
    }
}

// Custom NSApplication launch
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
