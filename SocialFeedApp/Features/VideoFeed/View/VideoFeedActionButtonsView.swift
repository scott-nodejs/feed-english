//
//  VideoFeedActionButtonsView.swift
//  SocialFeedApp
//
//  Created by Usman on 25.06.25.
//

import SwiftUI

struct VideoFeedActionButtonsView: View {
    @State private var isLiked: Bool = false
    @State private var isDisLiked: Bool = false
    let video: UI.Feed.Video
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                
                // Like button
                Button(action: {
                    updateLikeAStatus(isLiked: !isLiked)
                }) {
                    Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.title2)
                        .foregroundColor(.white)
                        .scaleEffect(isLiked ? 1.2 : 1.0)
                }
                
                Text("\(video.likes)")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                
                // DisLike button
                Button(action: {
                    updateLikeAStatus(isDisLiked: !isDisLiked)
                }) {
                    Image(systemName: isDisLiked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .font(.title2)
                        .foregroundColor(.white)
                        .scaleEffect(isDisLiked ? 1.2 : 1.0)
                }
                
                Text("\(video.likes)")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            // Comment button
            VStack(spacing: 4) {
                Button(action: {}) {
                    Image(systemName: "message")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Text("\(video.comments)")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
    
    private func updateLikeAStatus(
        isLiked: Bool = false,
        isDisLiked: Bool = false
    ) {
        if isLiked {
            self.isLiked = true
            self.isDisLiked = false
        } else if isDisLiked {
            self.isDisLiked = true
            self.isLiked = false
        } else {
            self.isLiked = false
            self.isDisLiked = false
        }
    }
}
