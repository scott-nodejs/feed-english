//
//  VideoFeedCreatorView.swift
//  SocialFeedApp
//
//  Created by Usman on 25.06.25.
//

import SwiftUI

struct VideoFeedCreatorView: View {
    let creator: UI.Feed.Video.Creator
    var foregroundColor: Color = .white
    
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
                .foregroundColor(foregroundColor)
            
            Spacer()
            

            Button {
                // TODO: Handle follow action event
            } label: {
                HStack(spacing: 4) {
                    Text("Follow")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(foregroundColor)

                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(foregroundColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(foregroundColor, lineWidth: 1)
                )
                .cornerRadius(22)
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
