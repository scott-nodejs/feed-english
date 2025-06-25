//
//  VideoFeedUseCase.swift
//  SocialFeedApp
//
//  Created by Usman on 24.06.25.
//

import Foundation

protocol VideoFeedUseCaseType {
    func fetchVideos() async throws -> [Domain.Feed.Video]
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
    func fetchVideos() async throws -> [Domain.Feed.Video] {
        return try await repository.fetchVideos()
    }
}
