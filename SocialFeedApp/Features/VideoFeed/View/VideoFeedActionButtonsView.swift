//
//  VideoFeedActionButtonsView.swift
//  SocialFeedApp
//
//  Created by Usman on 25.06.25.
//

import SwiftUI

struct VideoFeedActionButtonsView: View {
    @State private var isLiked: Bool = false
    let video: UI.Feed.Video
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                
                // Like button
                Button(action: {
                   // Action for liking the video
                }) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(isLiked ? .red : .white)
                        .scaleEffect(isLiked ? 1.2 : 1.0)
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
}
