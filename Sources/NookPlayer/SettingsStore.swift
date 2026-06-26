import Foundation
import Observation

@Observable
public final class SettingsStore {
    public static let shared = SettingsStore()
    
    private let defaults = UserDefaults.standard
    
    public var preferredProvider: String {
        get { defaults.string(forKey: "preferredProvider") ?? "Auto" }
        set { defaults.set(newValue, forKey: "preferredProvider") }
    }
    
    public var expandOnHover: Bool {
        get { defaults.object(forKey: "expandOnHover") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "expandOnHover") }
    }
    
    public var hoverDelay: Double {
        get { defaults.double(forKey: "hoverDelay") == 0 ? 0.3 : defaults.double(forKey: "hoverDelay") }
        set { defaults.set(newValue, forKey: "hoverDelay") }
    }
    
    public var compactMode: Bool {
        get { defaults.bool(forKey: "compactMode") }
        set { defaults.set(newValue, forKey: "compactMode") }
    }
    
    private init() {}
}
