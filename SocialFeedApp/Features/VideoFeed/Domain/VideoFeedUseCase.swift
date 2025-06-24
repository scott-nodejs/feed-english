//
//  VideoFeedUseCase.swift
//  SocialFeedApp
//
//  Created by Usman on 24.06.25.
//

import Foundation

protocol VideoFeedUseCaseType {
    func fetchVideos() async throws -> [API.Feed.Response.Video]
}

@Observable
final class VideoFeedUseCase {
    private let repository: VideoFeedRepositoryType
    
    init(
        repository: VideoFeedRepositoryType = VideoFeedRepository()
    ) {
        self.repository = repository
    }
}

extension VideoFeedUseCase: VideoFeedUseCaseType {
    func fetchVideos() async throws -> [API.Feed.Response.Video] {
        return try await repository.fetchVideos().videos
    }
}
