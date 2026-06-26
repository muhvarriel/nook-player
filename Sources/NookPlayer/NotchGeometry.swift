import Foundation
import AppKit

public struct NotchMetrics {
    public let bezelEmpty: CGSize
    public let mini: CGSize
    public let peek: CGSize
    public let expanded: CGSize
    
    public static let `default` = NotchMetrics(
        bezelEmpty: CGSize(width: 130, height: 26),
        mini: CGSize(width: 240, height: 32),
        peek: CGSize(width: 300, height: 76),
        expanded: CGSize(width: 400, height: 140)
    )
}

public struct NotchGeometry {
    public static let shadowPadding: CGFloat = 30
    
    public static func rect(for state: NotchInteractionState, metrics: NotchMetrics = .default, on screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        let size: CGSize
        
        switch state {
        case .bezelEmpty:
            size = metrics.bezelEmpty
        case .mini:
            let maxWidth = screenFrame.size.width - 64
            let adaptiveWidth = min(metrics.mini.width, maxWidth)
            size = CGSize(width: adaptiveWidth, height: metrics.mini.height)
        case .peek:
            let maxWidth = screenFrame.size.width - 64
            let adaptiveWidth = min(metrics.peek.width, maxWidth)
            size = CGSize(width: adaptiveWidth, height: metrics.peek.height)
        case .expanded:
            let maxWidth = screenFrame.size.width - 64
            let adaptiveWidth = min(metrics.expanded.width, maxWidth)
            size = CGSize(width: adaptiveWidth, height: metrics.expanded.height)
        }
        
        let windowWidth = size.width + (shadowPadding * 2)
        let windowHeight = size.height + shadowPadding
        
        let x = screenFrame.origin.x + (screenFrame.size.width - windowWidth) / 2
        let y = screenFrame.origin.y + screenFrame.size.height - windowHeight
        
        return NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
    }
}
