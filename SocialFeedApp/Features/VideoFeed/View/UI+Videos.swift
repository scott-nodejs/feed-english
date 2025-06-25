//
//  UI+Videos.swift
//  SocialFeedApp
//
//  Created by Usman on 25.06.25.
//

import Foundation

// MARK: - Video Model
extension UI.Feed {
    struct Video: Identifiable {
        let id = UUID()
        let creatorName: String
        let creatorAvatarURL: String
        let shortVideoURL: String
        let fullVideoURL: String
        let description: String
        let likes: Int
        let comments: Int
    }
}

// Normalize Domain Video to UI Video
extension Domain.Feed.Video: Normalizable {
    typealias Output = UI.Feed.Video
     
    func normalize() -> Output {
        Output(
            creatorName: creator.name,
            creatorAvatarURL: creator.avatarURL,
            shortVideoURL: shortVideoURL,
            fullVideoURL: fullVideoURL,
            description: description,
            likes: likes,
            comments: comments
        )
    }
}
