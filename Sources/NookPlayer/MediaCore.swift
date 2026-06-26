import Foundation
import Observation
import AppKit

public enum PlaybackState: String, Codable {
    case playing
    case paused
    case stopped
    case unknown
}

public enum MediaProviderError: Error, LocalizedError {
    case appNotRunning
    case permissionDenied
    case scriptFailed(String)
    case unsupportedCommand
    
    public var errorDescription: String? {
        switch self {
        case .appNotRunning: return "Application is not running"
        case .permissionDenied: return "Automation permission denied"
        case .scriptFailed(let msg): return "AppleScript failed: \(msg)"
        case .unsupportedCommand: return "Command unsupported by provider"
        }
    }
}

public struct MediaArtwork: Equatable {
    public let image: NSImage?
    public let dominantColor: NSColor?
    
    public init(image: NSImage? = nil, dominantColor: NSColor? = nil) {
        self.image = image
        self.dominantColor = dominantColor
    }
    
    public static func == (lhs: MediaArtwork, rhs: MediaArtwork) -> Bool {
        return lhs.image === rhs.image && lhs.dominantColor == rhs.dominantColor
    }
}

public struct MediaSession: Equatable {
    public let providerId: String
    public let providerName: String
    public let title: String?
    public let artist: String?
    public let album: String?
    public let artwork: MediaArtwork?
    public let playbackState: PlaybackState
    public let duration: TimeInterval?
    public let position: TimeInterval?
    public let updatedAt: Date
    
    public init(
        providerId: String,
        providerName: String,
        title: String?,
        artist: String?,
        album: String?,
        artwork: MediaArtwork?,
        playbackState: PlaybackState,
        duration: TimeInterval?,
        position: TimeInterval?,
        updatedAt: Date = Date()
    ) {
        self.providerId = providerId
        self.providerName = providerName
        self.title = title
        self.artist = artist
        self.album = album
        self.artwork = artwork
        self.playbackState = playbackState
        self.duration = duration
        self.position = position
        self.updatedAt = updatedAt
    }
    
    public static func == (lhs: MediaSession, rhs: MediaSession) -> Bool {
        return lhs.providerId == rhs.providerId &&
            lhs.title == rhs.title &&
            lhs.artist == rhs.artist &&
            lhs.album == rhs.album &&
            lhs.playbackState == rhs.playbackState &&
            lhs.duration == rhs.duration &&
            lhs.position == rhs.position &&
            lhs.artwork == rhs.artwork
    }
}

public protocol MediaProvider: AnyObject {
    var id: String { get }
    var displayName: String { get }
    var isAvailable: Bool { get }
    
    func fetchCurrentSession() async throws -> MediaSession?
    func play() async throws
    func pause() async throws
    func togglePlayPause() async throws
    func nextTrack() async throws
    func previousTrack() async throws
    func seek(to seconds: TimeInterval) async throws
}

@Observable
public final class MediaSessionStore {
    public static let shared = MediaSessionStore()
    
    public var currentSession: MediaSession? = nil
    public var isPanelExpanded: Bool = false {
        didSet {
            // Instantly trigger polling logic adjustments on state changes
            adjustPollingInterval()
        }
    }
    
    private var providers: [MediaProvider] = []
    private var timer: Timer? = nil
    private var localProgressTimer: Timer? = nil
    private var lastTimerTrackId: String = ""
    private var currentInterval: TimeInterval = 3.0
    
    private init() {}
    
    public func register(providers: [MediaProvider]) {
        self.providers = providers
        startPolling()
    }
    
    public func startPolling() {
        adjustPollingInterval()
    }
    
    public func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    private func adjustPollingInterval() {
        let newInterval: TimeInterval
        if isPanelExpanded {
            newInterval = 1.0
        } else if let session = currentSession, session.playbackState == .playing {
            newInterval = 2.5
        } else {
            newInterval = 7.0 // Idle/no media
        }
        
        if timer == nil || abs(currentInterval - newInterval) > 0.1 {
            currentInterval = newInterval
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
                Task {
                    await self?.pollNow()
                }
            }
            // Fire immediately on adjustment
            Task {
                await pollNow()
            }
        }
    }
    
    public func pollNow() async {
        let settings = SettingsStore.shared
        let preferred = settings.preferredProvider
        
        var selectedSession: MediaSession? = nil
        
        // Prioritized selection logic (O(n) where n is providers count)
        if preferred != "Auto" {
            // Prioritize preferred provider
            if let provider = providers.first(where: { $0.displayName == preferred && $0.isAvailable }) {
                do {
                    selectedSession = try await provider.fetchCurrentSession()
                } catch {
                    print("Preferred provider error: \(error)")
                }
            }
        }
        
        if selectedSession == nil {
            // Auto selection logic:
            // 1. Find the first provider that is playing.
            // 2. Otherwise, find the first provider that has a paused/stopped session with metadata.
            var activeSession: MediaSession? = nil
            var pausedSession: MediaSession? = nil
            
            for provider in providers where provider.isAvailable {
                do {
                    if let session = try await provider.fetchCurrentSession() {
                        if session.playbackState == .playing {
                            activeSession = session
                            break
                        } else if pausedSession == nil && (session.title != nil || session.artist != nil) {
                            pausedSession = session
                        }
                    }
                } catch {
                    // Fail silently for individual provider query
                }
            }
            selectedSession = activeSession ?? pausedSession
        }
        
        let newSession = selectedSession
        await MainActor.run {
            if let sess = newSession {
                print("[DEBUG] Provider: \(sess.providerName), Title: \(sess.title ?? "nil"), Pos: \(sess.position ?? -1), Dur: \(sess.duration ?? -1), State: \(sess.playbackState)")
            } else {
                print("[DEBUG] No active session")
            }
            fflush(stdout)
            if self.currentSession != newSession {
                self.currentSession = newSession
                self.adjustPollingInterval()
            }
            self.updateLocalProgressTimer()
            
            let interaction = NotchInteractionStore.shared
            if let session = self.currentSession, session.playbackState == .playing {
                if interaction.state == .bezelEmpty {
                    interaction.transition(to: .mini)
                }
            } else {
                if interaction.state == .mini && !interaction.isHovered {
                    interaction.transition(to: .bezelEmpty)
                }
            }
        }
    }
    
    private func updateLocalProgressTimer() {
        guard let session = currentSession, session.playbackState == .playing else {
            localProgressTimer?.invalidate()
            localProgressTimer = nil
            lastTimerTrackId = ""
            return
        }
        
        let trackId = "\(session.providerId)-\(session.title ?? "")-\(session.artist ?? "")"
        if lastTimerTrackId != trackId {
            localProgressTimer?.invalidate()
            localProgressTimer = nil
            lastTimerTrackId = trackId
        }
        
        guard localProgressTimer == nil else { return }
        
        localProgressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, var session = self.currentSession else { return }
                let currentPos = session.position ?? 0.0
                let duration = session.duration ?? 0.0
                if currentPos < duration {
                    session = MediaSession(
                        providerId: session.providerId,
                        providerName: session.providerName,
                        title: session.title,
                        artist: session.artist,
                        album: session.album,
                        artwork: session.artwork,
                        playbackState: session.playbackState,
                        duration: session.duration,
                        position: currentPos + 1.0,
                        updatedAt: Date()
                    )
                    self.currentSession = session
                }
            }
        }
    }
    
    private func activeProvider() -> MediaProvider? {
        guard let session = currentSession else { return nil }
        return providers.first { $0.id == session.providerId }
    }
    
    public func play() async {
        do {
            try await activeProvider()?.play()
            await pollNow()
        } catch { print("Play command failed: \(error)") }
    }
    
    public func pause() async {
        do {
            try await activeProvider()?.pause()
            await pollNow()
        } catch { print("Pause command failed: \(error)") }
    }
    
    public func togglePlayPause() async {
        do {
            try await activeProvider()?.togglePlayPause()
            await pollNow()
        } catch { print("TogglePlayPause command failed: \(error)") }
    }
    
    public func nextTrack() async {
        do {
            try await activeProvider()?.nextTrack()
            await pollNow()
        } catch { print("NextTrack failed: \(error)") }
    }
    
    public func previousTrack() async {
        do {
            try await activeProvider()?.previousTrack()
            await pollNow()
        } catch { print("PreviousTrack failed: \(error)") }
    }
    
    public func seek(to seconds: TimeInterval) async {
        do {
            try await activeProvider()?.seek(to: seconds)
            await pollNow()
        } catch { print("Seek failed: \(error)") }
    }
}
