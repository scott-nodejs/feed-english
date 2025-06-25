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
    enum ViewState {
        case loading
        case result(videos: [UI.Feed.Video])
        case error(Error)
        case empty
        case idle
    }
    
    private(set) var viewState: ViewState = .idle
    
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
        // Set the initial state to loading
        self.viewState = .loading
        
        do {
            // Fetch videos using the use case
            let videos = try await useCase.fetchVideos()
            
            // Normalize the videos to the UI model
            let normalizedVideos = videos.map { $0.normalize() }
                
            // Update the view state with the fetched videos
            self.viewState = normalizedVideos.isEmpty ? .empty : .result(videos: normalizedVideos)
        } catch {
            // Handle error appropriately, e.g., show an alert or log the error
            viewState = .error(error)
            
            print("Failed to fetch videos: \(error)")
        }
    }
}
