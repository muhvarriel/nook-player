import AppKit
import SwiftUI

public final class NookPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
}

public final class OverlaySystem: NSObject {
    public static let shared = OverlaySystem()
    
    private var panel: NookPanel?
    private var clickMonitor: NookEventMonitor?
    
    private override init() {
        super.init()
        setupClickMonitor()
    }
    
    public func showOverlay(with contentView: some View) {
        let primaryScreen = NSScreen.main ?? NSScreen.screens.first
        
        let initialRect = NotchGeometry.rect(for: .bezelEmpty, on: primaryScreen ?? NSScreen.screens.first!)
        
        let nookPanel = NookPanel(contentRect: initialRect)
        let hostingView = NSHostingView(rootView: contentView)
        nookPanel.contentView = hostingView
        nookPanel.makeKeyAndOrderFront(nil as Any?)
        
        self.panel = nookPanel
        reposition()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    private func setupClickMonitor() {
        clickMonitor = NookEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel else { return }
            let mouseLocation = NSEvent.mouseLocation
            let screenFrame = panel.frame
            if !NSMouseInRect(mouseLocation, screenFrame, false) {
                Task { @MainActor in
                    NotchInteractionStore.shared.handleOutsideClick()
                }
            }
        }
    }
    
    @objc private func screenParametersChanged() {
        reposition()
    }
    
    public func animateStateChange() {
        guard let panel = panel else { return }
        
        let state = NotchInteractionStore.shared.state
        let primaryScreen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = primaryScreen else { return }
        
        let newFrame = NotchGeometry.rect(for: state, on: targetScreen)
        
        if state == .expanded {
            clickMonitor?.start()
        } else {
            clickMonitor?.stop()
        }
        
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        
        if reduceMotion {
            panel.setFrame(newFrame, display: true)
            panel.invalidateShadow()
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.26
                if state == .bezelEmpty {
                    context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0)
                } else {
                    context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                }
                panel.animator().setFrame(newFrame, display: true)
            }, completionHandler: {
                panel.invalidateShadow()
            })
        }
    }
    
    private func reposition() {
        guard let panel = panel else { return }
        let state = NotchInteractionStore.shared.state
        let primaryScreen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = primaryScreen else { return }
        
        let newFrame = NotchGeometry.rect(for: state, on: targetScreen)
        panel.setFrame(newFrame, display: true)
    }
}
