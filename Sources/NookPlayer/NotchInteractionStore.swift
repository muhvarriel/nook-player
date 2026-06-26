import Foundation
import Observation

public enum NotchInteractionState {
    case bezelEmpty
    case mini
    case peek
    case expanded
}

@Observable
public final class NotchInteractionStore {
    public static let shared = NotchInteractionStore()
    
    public var state: NotchInteractionState = .bezelEmpty
    public var isHovered: Bool = false
    
    private var collapseTimer: Timer? = nil
    private var dwellTimer: Timer? = nil
    
    private let collapseDelay: TimeInterval = 0.15 // 150 ms delayed collapse
    private let dwellDelay: TimeInterval = 0.05 // short dwell delay for responsive enter
    
    private init() {}
    
    public func cancelTimers() {
        collapseTimer?.invalidate()
        collapseTimer = nil
        dwellTimer?.invalidate()
        dwellTimer = nil
    }
    
    public func handleHoverEnter() {
        isHovered = true
        collapseTimer?.invalidate()
        collapseTimer = nil
        
        let isPlaying = MediaSessionStore.shared.currentSession?.playbackState == .playing
        
        if state == .bezelEmpty && isPlaying {
            transition(to: .mini)
        }
        
        if state == .mini {
            dwellTimer?.invalidate()
            dwellTimer = Timer.scheduledTimer(withTimeInterval: dwellDelay, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    if self.isHovered && self.state == .mini {
                        self.transition(to: .peek)
                    }
                }
            }
        }
    }
    
    public func handleHoverExit() {
        isHovered = false
        dwellTimer?.invalidate()
        dwellTimer = nil
        
        if state == .expanded {
            return
        }
        
        let isPlaying = MediaSessionStore.shared.currentSession?.playbackState == .playing
        
        collapseTimer?.invalidate()
        collapseTimer = Timer.scheduledTimer(withTimeInterval: collapseDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.isHovered else { return }
                
                if isPlaying {
                    if self.state == .peek {
                        self.transition(to: .mini)
                    }
                } else {
                    if self.state == .mini || self.state == .peek {
                        self.transition(to: .bezelEmpty)
                    }
                }
            }
        }
    }
    
    public func handleClick() {
        if state == .mini || state == .peek {
            cancelTimers()
            transition(to: .expanded)
        }
    }
    
    public func handleOutsideClick() {
        if state == .expanded {
            cancelTimers()
            let isPlaying = MediaSessionStore.shared.currentSession?.playbackState == .playing
            transition(to: isPlaying ? .mini : .bezelEmpty)
        }
    }
    
    public func handleEscape() {
        if state == .expanded {
            cancelTimers()
            let isPlaying = MediaSessionStore.shared.currentSession?.playbackState == .playing
            transition(to: isPlaying ? .mini : .bezelEmpty)
        }
    }
    
    func transition(to newState: NotchInteractionState) {
        state = newState
        OverlaySystem.shared.animateStateChange()
    }
}
