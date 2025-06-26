//
//  VideoFeedPlayerView.swift
//  SocialFeedApp
//
//  Created by Usman on 25.06.25.
//

import SwiftUI
import AVKit

// MARK: - Video Player View
struct VideoFeedPlayerView: View {
    let videoURL: String
    let isCurrentVideo: Bool
    let isScrolling: Bool
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    
    private var shouldPlayVideo: Bool {
        return isCurrentVideo && !isScrolling
    }
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                        isPlaying = true
                    }
                    .onDisappear {
                        player.pause()
                        isPlaying = false
                    }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .tint(.white)
                    )
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
        .onChange(of: isCurrentVideo) { _, newValue in
            managePlayerState()
        }
        .onChange(of: isScrolling) { _, newValue in
            managePlayerState()
        }
    }
    
    private func setupPlayer() {
        guard let url = URL(string: videoURL) else { return }
        player = AVPlayer(url: url)
        player?.actionAtItemEnd = .none
        
        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }
    
    private func managePlayerState() {
        guard let player = player else { return }
    
        if shouldPlayVideo {
            player.play()
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }
    }
}
