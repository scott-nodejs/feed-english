//
//  UI+Videos.swift
//  SocialFeedApp
//
//  Created by Usman on 25.06.25.
//

import Foundation

// MARK: - Video Model
extension UI.Feed {
    struct Video: Identifiable, Equatable {
        let id = UUID()
        let creator: Creator
        let shortVideoURL: String
        let fullVideoURL: String
        let description: String
        let likes: Int
        let comments: Int
        var scene: SceneFeed? = nil
        
        static func == (lhs: UI.Feed.Video, rhs: UI.Feed.Video) -> Bool {
            lhs.id == rhs.id
        }
    }
}

extension UI.Feed.Video {
    struct Creator {
        let name: String
        let avatarURL: String
    }
}

// Normalize Domain Video to UI Video
extension Domain.Feed.Video: Normalizable {
    typealias Output = UI.Feed.Video
     
    func normalize() -> Output {
        Output(
            creator: creator.normalize(),
            shortVideoURL: shortVideoURL,
            fullVideoURL: fullVideoURL,
            description: description,
            likes: likes,
            comments: comments,
            scene: scene
        )
    }
}

// Normalize Domain Video to UI Video
extension Domain.Feed.Video.Creator: Normalizable {
    typealias Output = UI.Feed.Video.Creator
     
    func normalize() -> Output {
        Output(
            name: name,
            avatarURL: avatarURL
        )
    }
}
