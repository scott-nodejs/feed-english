//
//  VideoFeedRepository.swift
//  SocialFeedApp
//
//  Created by Usman on 24.06.25.
//

import Foundation

protocol VideoFeedRepositoryType {
    func fetchVideos() async throws -> [Domain.Feed.Video]
}

@Observable
final class VideoFeedRepository {
    private let jsonReader: JSONReaderType
    
    init(
        jsonReader: JSONReaderType = JSONReader()
    ) {
        self.jsonReader = jsonReader
    }
}

extension VideoFeedRepository: VideoFeedRepositoryType {
    func fetchVideos() async throws -> [Domain.Feed.Video] {
        return try await withCheckedThrowingContinuation { continuation in
            // Simulate network delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                do {
                    let response: API.Feed.Response = try self.jsonReader.load("videos")
                    let normalizedVideos = response.normalize()
                    continuation.resume(returning: normalizedVideos)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
