//
//  VideoFeedUseCase+Mock.swift
//  SocialFeedAppTests
//
//  Created by Usman on 26.06.25.
//

import Foundation
@testable import SocialFeedApp

class VideoFeedUseCaseMock: VideoFeedUseCaseType {
    private let repository: VideoFeedRepositoryType
    
    init(
        repository: VideoFeedRepositoryType
    ) {
        self.repository = repository
    }
    
    func fetchVideos() async throws -> [Domain.Feed.Video] {
        try await repository.fetchVideos()
    }
}
