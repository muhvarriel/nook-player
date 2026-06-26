import Foundation
import ApplicationServices
import Observation

@Observable
public final class PermissionManager {
    public static let shared = PermissionManager()
    
    public enum PermissionState {
        case unknown
        case authorized
        case denied
    }
    
    public var appleMusicState: PermissionState = .unknown
    public var spotifyState: PermissionState = .unknown
    
    private init() {
        checkAll()
    }
    
    public func checkAll() {
        appleMusicState = checkAutomationPermission(for: "com.apple.Music")
        spotifyState = checkAutomationPermission(for: "com.spotify.client")
    }
    
    private func checkAutomationPermission(for bundleIdentifier: String) -> PermissionState {
        let targetAEAddress = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
        guard var addressDesc = targetAEAddress.aeDesc?.pointee else { return .unknown }
        
        let status = AEDeterminePermissionToAutomateTarget(
            &addressDesc,
            typeWildCard,
            typeWildCard,
            false
        )
        
        switch status {
        case noErr:
            return .authorized
        case -1743:
            return .denied
        default:
            return .unknown
        }
    }
    
    public func requestPermission(for bundleIdentifier: String) {
        let targetAEAddress = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
        guard var addressDesc = targetAEAddress.aeDesc?.pointee else { return }
        
        // Pass true to prompt the user
        _ = AEDeterminePermissionToAutomateTarget(
            &addressDesc,
            typeWildCard,
            typeWildCard,
            true
        )
        checkAll()
    }
}
