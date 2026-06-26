import SwiftUI
import AppKit

struct AppRootView: View {
    @State private var interactionStore = NotchInteractionStore.shared
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch interactionStore.state {
                case .bezelEmpty:
                    BezelEmptyView()
                        .frame(width: 130, height: 26)
                case .mini:
                    GeometryReader { geometry in
                        let actualWidth = geometry.size.width - (NotchGeometry.shadowPadding * 2)
                        HStack {
                            Spacer()
                            MiniNowPlayingView()
                                .frame(width: actualWidth, height: 32)
                                .background(
                                    UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14)
                                        .fill(Color.black)
                                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                )
                            Spacer()
                        }
                    }
                    .frame(height: 32)
                case .peek:
                    GeometryReader { geometry in
                        let actualWidth = geometry.size.width - (NotchGeometry.shadowPadding * 2)
                        HStack {
                            Spacer()
                            PeekNowPlayingView()
                                .frame(width: actualWidth, height: 76)
                                .background(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 0,
                                        bottomLeadingRadius: 22,
                                        bottomTrailingRadius: 22,
                                        topTrailingRadius: 0
                                    )
                                    .fill(Color.black)
                                    .shadow(color: Color.black.opacity(0.3), radius: 18, x: 0, y: 8)
                                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
                                )
                            Spacer()
                        }
                    }
                    .frame(height: 76)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                case .expanded:
                    GeometryReader { geometry in
                        let actualWidth = geometry.size.width - (NotchGeometry.shadowPadding * 2)
                        HStack {
                            Spacer()
                            ExpandedPlayerView()
                                .frame(width: actualWidth, height: 140)
                                .background(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 0,
                                        bottomLeadingRadius: 22,
                                        bottomTrailingRadius: 22,
                                        topTrailingRadius: 0
                                    )
                                    .fill(Color.black)
                                    .shadow(color: Color.black.opacity(0.35), radius: 25, x: 0, y: 12)
                                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 3)
                                )
                            Spacer()
                        }
                    }
                    .frame(height: 140)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            Spacer(minLength: 0)
        }
        .animation(.spring(duration: 0.22), value: interactionStore.state)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BezelEmptyView: View {
    var body: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10)
            .fill(Color.black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NotchInteractionStore.shared.handleHoverEnter()
                }
            }
    }
}

struct MiniNowPlayingView: View {
    @State private var store = MediaSessionStore.shared
    
    var body: some View {
        HStack(spacing: 8) {
            if let session = store.currentSession, session.playbackState == .playing {
                if let artImage = session.artwork?.image {
                    Image(nsImage: artImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .cornerRadius(3)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(3)
                }
                
                Spacer()
                
                WaveformIndicator()
                    .frame(width: 14, height: 10)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text("No media playing")
                    .font(.outfitMedium(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NotchInteractionStore.shared.handleHoverEnter()
            } else {
                NotchInteractionStore.shared.handleHoverExit()
            }
        }
        .onTapGesture {
            NotchInteractionStore.shared.handleClick()
        }
    }
}

struct PeekNowPlayingView: View {
    @State private var store = MediaSessionStore.shared
    
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 34) // Notch exclusion height
            
            if let session = store.currentSession {
                HStack(alignment: .center, spacing: 10) {
                    ZStack(alignment: .bottomTrailing) {
                        if let artImage = session.artwork?.image {
                            Image(nsImage: artImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 36, height: 36)
                                .cornerRadius(5)
                                .shadow(radius: 1)
                        } else {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(LinearGradient(colors: [.purple.opacity(0.4), .blue.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.8))
                                )
                                .shadow(radius: 1)
                        }
                        
                        providerIcon(for: session.providerId)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.title ?? "Unknown Track")
                            .font(.outfitBold(size: 12))
                            .lineLimit(1)
                        Text(session.artist ?? "Unknown Artist")
                            .font(.outfitRegular(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    WaveformIndicator()
                        .frame(width: 14, height: 10)
                }
                .padding(.horizontal, 14)
                .frame(height: 42)
            } else {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                    Text("No Media Playing")
                        .font(.outfitBold(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NotchInteractionStore.shared.handleHoverEnter()
            } else {
                NotchInteractionStore.shared.handleHoverExit()
            }
        }
        .onTapGesture {
            NotchInteractionStore.shared.handleClick()
        }
    }
    
    private func providerIcon(for providerId: String) -> some View {
        let systemName: String
        let color: Color
        if providerId == "com.apple.Music" {
            systemName = "music.note"
            color = .pink
        } else if providerId == "com.spotify.client" {
            systemName = "play.circle.fill"
            color = .green
        } else {
            systemName = "music.note"
            color = .blue
        }
        
        return Image(systemName: systemName)
            .font(.system(size: 5, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 9, height: 9)
            .background(color)
            .clipShape(Circle())
            .offset(x: 2, y: 2)
    }
}

struct ExpandedPlayerView: View {
    @State private var store = MediaSessionStore.shared
    @State private var isMuted = false
    
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 34) // Notch exclusion height
            
            HStack(alignment: .center, spacing: 10) {
                if let session = store.currentSession {
                    ZStack(alignment: .bottomTrailing) {
                        ZStack(alignment: .topLeading) {
                            if let artImage = session.artwork?.image {
                                Image(nsImage: artImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 42, height: 42)
                                    .cornerRadius(5)
                                    .shadow(radius: 2)
                            } else {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(LinearGradient(colors: [.purple.opacity(0.4), .blue.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 42, height: 42)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white.opacity(0.8))
                                    )
                                    .shadow(radius: 2)
                            }
                            
                            Button(action: {
                                toggleSystemMute()
                            }) {
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.white)
                                    .frame(width: 10, height: 10)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .offset(x: -2, y: -2)
                        }
                        
                        providerIcon(for: session.providerId)
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(session.title ?? "Unknown Track")
                            .font(.outfitBold(size: 13))
                            .lineLimit(1)
                        Text(session.artist ?? "Unknown Artist")
                            .font(.outfitRegular(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text(session.providerName)
                            .font(.outfitMedium(size: 8))
                            .foregroundColor(.blue.opacity(0.8))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(2.5)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                         NotchInteractionStore.shared.handleOutsideClick()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "music.note.house.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("No Media Playing")
                            .font(.outfitBold(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .frame(height: 48)
            .padding(.horizontal, 16)
            
            if let session = store.currentSession {
                VStack(spacing: 2) {
                    let duration = session.duration ?? 1.0
                    let position = session.position ?? 0.0
                    
                    CustomSlider(value: Binding(
                        get: { position },
                        set: { newPos in
                            Task {
                                await store.seek(to: newPos)
                            }
                        }
                    ), bounds: 0...duration)
                    
                    HStack {
                        Text(formatTime(position))
                        Spacer()
                        Text(formatTime(duration))
                    }
                    .font(.outfitRegular(size: 7.5))
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 28)
                .padding(.top, 4)
                
                Spacer(minLength: 0)
                
                HStack(spacing: 24) {
                    Button(action: {
                        Task { await store.previousTrack() }
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        Task { await store.togglePlayPause() }
                    }) {
                        Image(systemName: session.playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        Task { await store.nextTrack() }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 10)
            } else {
                Spacer()
            }
        }
        .onAppear {
            isMuted = checkSystemMuted()
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {
                    NotchInteractionStore.shared.handleEscape()
                    return nil
                }
                return event
            }
        }
    }
    
    private func checkSystemMuted() -> Bool {
        let scriptSource = "output muted of (get volume settings)"
        guard let script = NSAppleScript(source: scriptSource) else { return false }
        var error: NSDictionary? = nil
        let result = script.executeAndReturnError(&error)
        return result.booleanValue
    }
    
    private func toggleSystemMute() {
        let scriptSource = "set volume output muted (not (output muted of (get volume settings)))"
        guard let script = NSAppleScript(source: scriptSource) else { return }
        var error: NSDictionary? = nil
        script.executeAndReturnError(&error)
        isMuted = checkSystemMuted()
    }
    
    private func providerIcon(for providerId: String) -> some View {
        let systemName: String
        let color: Color
        if providerId == "com.apple.Music" {
            systemName = "music.note"
            color = .pink
        } else if providerId == "com.spotify.client" {
            systemName = "play.circle.fill"
            color = .green
        } else {
            systemName = "music.note"
            color = .blue
        }
        
        return Image(systemName: systemName)
            .font(.system(size: 6, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 10, height: 10)
            .background(color)
            .clipShape(Circle())
            .offset(x: 3, y: 3)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct WaveformIndicator: View {
    @State private var waveHeights: [CGFloat] = [2, 4, 3, 5]
    private let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<waveHeights.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 1.5, height: waveHeights[index])
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.12)) {
                for i in 0..<waveHeights.count {
                    waveHeights[i] = CGFloat.random(in: 2...10)
                }
            }
        }
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    let bounds: ClosedRange<Double>
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 3)
                
                let range = bounds.upperBound - bounds.lowerBound
                let percent = range > 0 ? CGFloat((value - bounds.lowerBound) / range) : 0.0
                
                Capsule()
                    .fill(Color.white)
                    .frame(width: geometry.size.width * percent, height: 3)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .offset(x: geometry.size.width * percent - 4)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let percentage = min(max(0, gesture.location.x / geometry.size.width), 1)
                        let range = bounds.upperBound - bounds.lowerBound
                        value = bounds.lowerBound + Double(percentage) * range
                    }
            )
        }
        .frame(height: 8)
    }
}
