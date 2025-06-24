//
//  API+Videos.swift
//  SocialFeedApp
//
//  Created by Usman on 24.06.25.
//

import Foundation

// MARK: - Main Response Model
extension API.Feed {
    struct Response: Decodable {
        let videos: [Video]
    }
}

// MARK: - Video Model
extension API.Feed.Response {
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
extension API.Feed.Response.Video {
    struct Creator: Decodable {
        let id: String
        let name: String
        let avatarURL: String
    }
}

