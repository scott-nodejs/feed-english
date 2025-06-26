//
//  VideoFeedRepository+Mock.swift
//  SocialFeedAppTests
//
//  Created by Usman on 26.06.25.
//

import Foundation
@testable import SocialFeedApp

class VideoFeedRepositoryMock: VideoFeedRepositoryType {
    private let result: Result<Decodable, Error>
    
    init(
        result: Result<Decodable, Error>
    ) {
        self.result = result
    }
    
    func fetchVideos() async throws -> [Domain.Feed.Video] {
        return try await withCheckedThrowingContinuation { continuation in
            // Simulate network delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                switch self.result {
                case .success(let decodable):
                    if let response = decodable as? API.Feed.Response {
                        let normalizedVideos = response.normalize()
                        continuation.resume(returning: normalizedVideos)
                    } else {
                        continuation.resume(throwing: MockError.decodingError)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

