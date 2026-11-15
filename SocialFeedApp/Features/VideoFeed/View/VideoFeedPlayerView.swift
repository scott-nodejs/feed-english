import SwiftUI
import AVKit

struct VideoPlaybackIntent {
    var isCurrent = false
    var isScrolling = false
    var isForeground = true
    var userPaused = false
    var shouldPlay: Bool { isCurrent && !isScrolling && isForeground && !userPaused }
    mutating func toggle() { userPaused.toggle() }
}

@MainActor @Observable
final class FeedVideoPlayback {
    let player = AVPlayer()
    private(set) var intent = VideoPlaybackIntent()
    private var observer: NSObjectProtocol?
    private var url: String?
    func configure(_ url: String) {
        guard self.url != url, let mediaURL = URL(string: url), !url.isEmpty else { return }
        removeObserver()
        self.url = url
        let item = AVPlayerItem(url: mediaURL)
        player.replaceCurrentItem(with: item)
        player.actionAtItemEnd = .pause
        observer = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.player.currentItem === item else { return }
                self.player.seek(to: .zero) { [weak self] finished in
                    Task { @MainActor [weak self] in
                        guard finished, let self, self.player.currentItem === item else { return }
                        self.apply()
                    }
                }
            }
        }
        apply()
    }
    func update(current: Bool, scrolling: Bool, foreground: Bool) {
        intent.isCurrent = current; intent.isScrolling = scrolling; intent.isForeground = foreground
        apply()
    }
    func toggle() { intent.toggle(); apply() }
    private func apply() { if intent.shouldPlay { player.play() } else { player.pause() } }
    func stop() {
        intent.isCurrent = false
        player.pause(); removeObserver(); player.replaceCurrentItem(with: nil); url = nil
    }
    private func removeObserver() { if let observer { NotificationCenter.default.removeObserver(observer); self.observer = nil } }
}

struct VideoFeedPlayerView: View {
    let videoURL: String
    let isCurrentVideo: Bool
    let isScrolling: Bool
    @State private var playback = FeedVideoPlayback()
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            FullScreenAVPlayerView(player: playback.player)
            Button { playback.toggle() } label: {
                ZStack {
                    Color.clear
                    if playback.intent.userPaused {
                        Image(systemName: "play.fill").font(.system(size: 44)).foregroundStyle(.white.opacity(0.9))
                            .padding(24).background(.black.opacity(0.25), in: Circle())
                    }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel(playback.intent.userPaused ? "继续播放" : "暂停视频")
                .disabled(!isCurrentVideo)
        }
        .onAppear { playback.configure(videoURL); update() }
        .onDisappear { playback.stop() }
        .onChange(of: videoURL) { _, value in playback.configure(value); update() }
        .onChange(of: isCurrentVideo) { _, _ in update() }
        .onChange(of: isScrolling) { _, _ in update() }
        .onChange(of: scenePhase) { _, _ in update() }
    }
    private func update() { playback.update(current: isCurrentVideo, scrolling: isScrolling, foreground: scenePhase == .active) }
}
