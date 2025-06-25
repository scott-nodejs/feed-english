//
//  Domain+Videos.swift
//  SocialFeedApp
//
//  Created by Usman on 25.06.25.
//

import Foundation

// MARK: - Video Model
extension Domain.Feed {
    struct Video: Decodable {
        let id: String
        let creator: Creator
        let shortVideoURL: String
        let fullVideoURL: String
        let description: String
        let likes: Int
        let comments: Int
    }
}


// MARK: - Creator Model
extension Domain.Feed.Video {
    struct Creator: Decodable {
        let id: String
        let name: String
        let avatarURL: String
    }
}

// Normalize the API.Feed to Domain.Feed
extension API.Feed.Response: Normalizable {
    typealias Output = [Domain.Feed.Video]
    
    func normalize() -> Output {
        return videos.map { $0.normalize() }
    }
}

// Normalize the API.Feed to Domain.Feed
extension API.Feed.Response.Video: Normalizable {
    typealias Output = Domain.Feed.Video
    
    func normalize() -> Output {
        Output(
            id: id,
            creator: creator.normalize(),
            shortVideoURL: shortVideoURL,
            fullVideoURL: fullVideoURL,
            description: description,
            likes: likes,
            comments: comments
        )
    }
}


extension API.Feed.Response.Video.Creator: Normalizable {
    typealias Output = Domain.Feed.Video.Creator
    func normalize() -> Output {
        return Output(
            id: id,
            name: name,
            avatarURL: avatarURL
        )
    }
}

