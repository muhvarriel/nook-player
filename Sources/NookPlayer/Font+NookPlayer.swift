import SwiftUI
import AppKit

extension Font {
    public static func outfitRegular(size: CGFloat) -> Font {
        return Font.custom("Outfit-Regular", size: size)
    }
    
    public static func outfitMedium(size: CGFloat) -> Font {
        return Font.custom("Outfit-Medium", size: size)
    }
    
    public static func outfitBold(size: CGFloat) -> Font {
        return Font.custom("Outfit-Bold", size: size)
    }
}

public func debugPrintRegisteredFonts() {
    print("--- Registered Fonts ---")
    let fontFamilies = NSFontManager.shared.availableFontFamilies
    for family in fontFamilies {
        if family.contains("Outfit") {
            print("Found Outfit family: \(family)")
            if let members = NSFontManager.shared.availableMembers(ofFontFamily: family) {
                for member in members {
                    if let fontName = member[0] as? String {
                        print("  Font name: \(fontName)")
                    }
                }
            }
        }
    }
    print("------------------------")
}
