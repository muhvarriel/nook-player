import Foundation
import AppKit

// Helper to execute AppleScripts off the main thread safely
private func runScript(_ scriptSource: String) async throws -> String {
    guard let script = NSAppleScript(source: scriptSource) else {
        throw MediaProviderError.scriptFailed("Could not compile AppleScript")
    }
    
    var errorInfo: NSDictionary? = nil
    let result = script.executeAndReturnError(&errorInfo)
    
    if let error = errorInfo {
        let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
        let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
        if errorNumber == -1743 {
            throw MediaProviderError.permissionDenied
        }
        throw MediaProviderError.scriptFailed(message)
    }
    
    return result.stringValue ?? ""
}

private func parseDouble(_ string: String) -> Double? {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    if let val = Double(trimmed) {
        return val
    }
    let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
    return Double(normalized)
}

public final class AppleMusicAdapter: MediaProvider {
    public let id: String = "com.apple.Music"
    public let displayName: String = "Apple Music"
    
    public var isAvailable: Bool {
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).first != nil
    }
    
    public init() {}
    
    public func fetchCurrentSession() async throws -> MediaSession? {
        guard isAvailable else { return nil }
        
        let script = """
        tell application "Music"
            if it is running then
                set pState to player state as string
                if pState is "stopped" then
                    return "stopped||||0|0"
                end if
                try
                    set currTrack to current track
                    set tName to name of currTrack
                    set tArtist to artist of currTrack
                    set tAlbum to album of currTrack
                    set tDuration to duration of currTrack
                    set tPosition to player position
                    return pState & "|" & tName & "|" & tArtist & "|" & tAlbum & "|" & tDuration & "|" & tPosition
                on error
                    return "stopped||||0|0"
                end try
            else
                return "stopped||||0|0"
            end if
        end tell
        """
        
        let rawResult = try await runScript(script)
        let parts = rawResult.components(separatedBy: "|")
        guard parts.count >= 6 else { return nil }
        
        let pStateRaw = parts[0]
        let title = parts[1].isEmpty ? nil : parts[1]
        let artist = parts[2].isEmpty ? nil : parts[2]
        let album = parts[3].isEmpty ? nil : parts[3]
        let duration = parseDouble(parts[4]) ?? 0
        let position = parseDouble(parts[5]) ?? 0
        
        let playbackState: PlaybackState
        switch pStateRaw {
        case "playing": playbackState = .playing
        case "paused": playbackState = .paused
        default: playbackState = .stopped
        }
        
        // Fetch artwork if playing
        var artwork: MediaArtwork? = nil
        if playbackState != .stopped {
            artwork = await fetchArtworkBytes()
        }
        
        return MediaSession(
            providerId: id,
            providerName: displayName,
            title: title,
            artist: artist,
            album: album,
            artwork: artwork,
            playbackState: playbackState,
            duration: duration,
            position: position
        )
    }
    
    private func fetchArtworkBytes() async -> MediaArtwork? {
        let artworkScript = """
        tell application "Music"
            if it is running and player state is not stopped then
                try
                    tell current track
                        if (count of artworks) > 0 then
                            return raw data of artwork 1
                        end if
                    end tell
                end try
            end if
            return ""
        end tell
        """
        
        guard let script = NSAppleScript(source: artworkScript) else { return nil }
        var errorInfo: NSDictionary? = nil
        let descriptor = script.executeAndReturnError(&errorInfo)
        
        if errorInfo == nil {
            let data = descriptor.data
            if let image = NSImage(data: data) {
                return MediaArtwork(image: image)
            }
        }
        return nil
    }
    
    public func play() async throws {
        _ = try await runScript("tell application \"Music\" to play")
    }
    
    public func pause() async throws {
        _ = try await runScript("tell application \"Music\" to pause")
    }
    
    public func togglePlayPause() async throws {
        _ = try await runScript("tell application \"Music\" to playpause")
    }
    
    public func nextTrack() async throws {
        _ = try await runScript("tell application \"Music\" to next track")
    }
    
    public func previousTrack() async throws {
        _ = try await runScript("tell application \"Music\" to previous track")
    }
    
    public func seek(to seconds: TimeInterval) async throws {
        _ = try await runScript("tell application \"Music\" to set player position to \(seconds)")
    }
}

public final class SpotifyAdapter: MediaProvider {
    public let id: String = "com.spotify.client"
    public let displayName: String = "Spotify"
    
    public var isAvailable: Bool {
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).first != nil
    }
    
    public init() {}
    
    public func fetchCurrentSession() async throws -> MediaSession? {
        guard isAvailable else { return nil }
        
        let script = """
        tell application "Spotify"
            if it is running then
                set pState to player state as string
                try
                    set currTrack to current track
                    set tName to name of currTrack
                    set tArtist to artist of currTrack
                    set tAlbum to album of currTrack
                    set tDuration to (duration of currTrack) / 1000
                    set tPosition to player position
                    set tUrl to artwork url of currTrack
                    return pState & "|" & tName & "|" & tArtist & "|" & tAlbum & "|" & tDuration & "|" & tPosition & "|" & tUrl
                on error
                    return "stopped||||0|0|"
                end try
            else
                return "stopped||||0|0|"
            end if
        end tell
        """
        
        let rawResult = try await runScript(script)
        let parts = rawResult.components(separatedBy: "|")
        guard parts.count >= 7 else { return nil }
        
        let pStateRaw = parts[0]
        let title = parts[1].isEmpty ? nil : parts[1]
        let artist = parts[2].isEmpty ? nil : parts[2]
        let album = parts[3].isEmpty ? nil : parts[3]
        let duration = parseDouble(parts[4]) ?? 0
        let position = parseDouble(parts[5]) ?? 0
        let artworkUrlStr = parts[6]
        
        let playbackState: PlaybackState
        switch pStateRaw {
        case "playing": playbackState = .playing
        case "paused": playbackState = .paused
        default: playbackState = .stopped
        }
        
        var artwork: MediaArtwork? = nil
        if !artworkUrlStr.isEmpty, let url = URL(string: artworkUrlStr) {
            if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                artwork = MediaArtwork(image: image)
            }
        }
        
        return MediaSession(
            providerId: id,
            providerName: displayName,
            title: title,
            artist: artist,
            album: album,
            artwork: artwork,
            playbackState: playbackState,
            duration: duration,
            position: position
        )
    }
    
    public func play() async throws {
        _ = try await runScript("tell application \"Spotify\" to play")
    }
    
    public func pause() async throws {
        _ = try await runScript("tell application \"Spotify\" to pause")
    }
    
    public func togglePlayPause() async throws {
        _ = try await runScript("tell application \"Spotify\" to playpause")
    }
    
    public func nextTrack() async throws {
        _ = try await runScript("tell application \"Spotify\" to next track")
    }
    
    public func previousTrack() async throws {
        _ = try await runScript("tell application \"Spotify\" to previous track")
    }
    
    public func seek(to seconds: TimeInterval) async throws {
        // Spotify scripting support for seek:
        _ = try await runScript("tell application \"Spotify\" to set player position to \(seconds)")
    }
}

#if DEBUG
public final class MockMediaAdapter: MediaProvider {
    public let id: String = "com.nookplayer.mock"
    public let displayName: String = "Mock Player"
    public var isAvailable: Bool = true
    
    private var isPlaying = true
    private var trackIndex = 0
    private var position: TimeInterval = 12.0
    
    private let mockTracks = [
        (title: "Mockingbird", artist: "Eminem", album: "Encore", duration: 251.0),
        (title: "Starlight", artist: "Muse", album: "Black Holes and Revelations", duration: 240.0),
        (title: "Blinding Lights", artist: "The Weeknd", album: "After Hours", duration: 200.0)
    ]
    
    public init() {}
    
    public func fetchCurrentSession() async throws -> MediaSession? {
        let track = mockTracks[trackIndex]
        if isPlaying {
            position += 1
            if position > track.duration {
                position = 0
                trackIndex = (trackIndex + 1) % mockTracks.count
            }
        }
        
        return MediaSession(
            providerId: id,
            providerName: displayName,
            title: track.title,
            artist: track.artist,
            album: track.album,
            artwork: nil,
            playbackState: isPlaying ? .playing : .paused,
            duration: track.duration,
            position: position
        )
    }
    
    public func play() async throws { isPlaying = true }
    public func pause() async throws { isPlaying = false }
    public func togglePlayPause() async throws { isPlaying.toggle() }
    public func nextTrack() async throws {
        trackIndex = (trackIndex + 1) % mockTracks.count
        position = 0
    }
    public func previousTrack() async throws {
        trackIndex = (trackIndex - 1 + mockTracks.count) % mockTracks.count
        position = 0
    }
    public func seek(to seconds: TimeInterval) async throws {
        position = seconds
    }
}
#endif
