//
//  FullScreenAVPlayerView.swift
//  SocialFeedApp
//
//  Created by Usman on 26.06.25.
//

import SwiftUI
import AVKit

struct FullScreenAVPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.videoGravity = .resizeAspectFill
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.videoGravity = .resizeAspectFill
    }
}
