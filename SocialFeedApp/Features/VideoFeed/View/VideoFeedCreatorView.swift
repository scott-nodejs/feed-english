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
            
            Spacer()
            

            Button {
                // TODO: Handle follow action event
            } label: {
                HStack(spacing: 4) {
                    Text("Follow")
                        .font(.headline)
                        .fontWeight(.regular)
                        .foregroundColor(.white)

                    Image(systemName: "plus")
                        .font(.body)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white, lineWidth: 1)
                )
                .cornerRadius(20)
            }
        }
    }
}

#Preview {
    VideoFeedCreatorView(
        creator: UI.Feed.Video.Creator(
            name: "name",
            avatarURL: "https://picsum.photos/150/150?random=1"
        )
    )
}
