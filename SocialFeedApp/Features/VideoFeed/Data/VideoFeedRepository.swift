//
//  VideoFeedRepository.swift
//  SocialFeedApp
//
//  Created by Usman on 24.06.25.
//

import Foundation

protocol VideoFeedRepositoryType {
    func fetchVideos() async throws -> API.Feed.Response
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
    func fetchVideos() async throws -> API.Feed.Response {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let response: API.Feed.Response = try self.jsonReader.load("videos.json")
                continuation.resume(returning: response)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
