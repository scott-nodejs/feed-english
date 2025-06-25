//
//  VideoFeedViewModel.swift
//  SocialFeedApp
//
//  Created by Usman on 24.06.25.
//

import Foundation
import SwiftUI

protocol VideoFeedViewModelType {
    func fetchVideos() async
}

@Observable
final class VideoFeedViewModel {
    private(set) var videos: [UI.Feed.Video] = []
    
    private let useCase: VideoFeedUseCaseType
    
    init(
        useCase: VideoFeedUseCaseType = VideoFeedUseCase()
    ) {
        self.useCase = useCase
    }
}

extension VideoFeedViewModel: VideoFeedViewModelType {
    
    @MainActor
    func fetchVideos() async {
        do {
            let videos = try await useCase.fetchVideos()
            self.videos = videos.map { $0.normalize() }
            print("Fetched \(videos.count) videos")
        } catch {
            print("Failed to fetch videos: \(error)")
            // Handle error appropriately, e.g., show an alert or log the error
        }
    }
}
