//
//  Videos+Mock.swift
//  SocialFeedAppTests
//
//  Created by Usman on 26.06.25.
//

import Foundation
@testable import SocialFeedApp

extension API.Feed.Response {
    static func mock() -> API.Feed.Response  {
        .init(
            videos: [
                .mock(),
                .mock(id: "mock-video-id-2", description: "Another mock video description", likes: 200, comments: 100),
                .mock(id: "mock-video-id-3", creator: .mock(name: "Another Mock Creator", avatarURL: "https://example.com/another-avatar.jpg"), shortVideoURL: "https://example.com/another-short-video.mp4", fullVideoURL: "https://example.com/another-full-video.mp4", description: "Yet another mock video description", likes: 300, comments: 150)
            ]
        )
    }
}

extension API.Feed.Response.Video {
    static func mock(
        id: String = "mock-video-id-1",
        creator: API.Feed.Response.Video.Creator = .mock(),
        shortVideoURL: String = "https://example.com/short-video.mp4",
        fullVideoURL: String = "https://example.com/full-video.mp4",
        description: String = "Mock video description",
        likes: Int = 100,
        comments: Int = 50
    ) -> API.Feed.Response.Video {
        .init(
            id: id,
            creator: creator,
            shortVideoURL: shortVideoURL,
            fullVideoURL: fullVideoURL,
            description: description,
            likes: likes,
            comments: comments
        )
    }
}

extension API.Feed.Response.Video.Creator {
    static func mock(
        id: String = "mock-creator-id",
        name: String = "Mock Creator",
        avatarURL: String = "https://example.com/avatar.jpg"
    ) -> API.Feed.Response.Video.Creator {
        .init(
            id: id,
            name: name,
            avatarURL: avatarURL
        )
    }
}
