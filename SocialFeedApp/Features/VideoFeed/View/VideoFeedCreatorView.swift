//
//  VideoFeedCreatorView.swift
//  SocialFeedApp
//
//  Created by Usman on 25.06.25.
//

import SwiftUI

struct VideoFeedCreatorView: View {
    let creator: UI.Feed.Video.Creator
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: creator.avatarURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            Text(creator.name)
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}
