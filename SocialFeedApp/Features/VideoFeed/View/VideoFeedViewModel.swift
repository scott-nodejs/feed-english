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
    func loadMoreVideos(video: UI.Feed.Video?) async
}

@Observable
final class VideoFeedViewModel {
    enum ViewState: Equatable {
        case loading
        case result(videos: [UI.Feed.Video])
        case error(Error)
        case empty
        case idle
        
        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading):
                return true
            case (.empty, .empty):
                return true
            case (.idle, .idle):
                return true
            case let (.result(lhsVideos), .result(rhsVideos)):
                return lhsVideos == rhsVideos
            case let (.error(lhsError), .error(rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }
    
    private(set) var viewState: ViewState = .idle
    private let useCase: VideoFeedUseCaseType
    private var totalVideos: [UI.Feed.Video] = []
    private var canLoadMoreVideos: Bool = false
    private var offset = 0 // Start from page 0
    private var limit = 20 //
    
    init(
        useCase: VideoFeedUseCaseType = VideoFeedUseCase()
    ) {
        self.useCase = useCase
    }
    
    private func reset() {
        totalVideos.removeAll()
        offset = 0
        canLoadMoreVideos = true
    }
}

extension VideoFeedViewModel: VideoFeedViewModelType {
    @MainActor
    func fetchVideos() async {
        // Set the initial state to loading
        if totalVideos.isEmpty { self.viewState = .loading }
        
        do {
            // Fetch videos using the use case
            let videos = try await useCase.fetchVideos()
            
            if videos.isEmpty {
                canLoadMoreVideos = false
                
                if self.totalVideos.isEmpty {
                    // If no videos are available, set the view state to empty
                    self.viewState = .empty
                } else {
                    // If there are already videos loaded, just update the view state to show results
                    self.viewState = .result(videos: self.totalVideos)
                }
                    
            } else {
                // Normalize the videos to the UI model
                let normalizedVideos = videos.map { $0.normalize() }
                self.totalVideos += normalizedVideos
                self.offset += normalizedVideos.count
                
                // Update the view state with the fetched videos
                self.viewState = .result(videos: self.totalVideos)
            }
        } catch {
            // Handle error appropriately, e.g., show an alert or log the error
            viewState = .error(error)
        }
    }
    
    func loadMoreVideos(video: UI.Feed.Video?) async {
        guard let video else {
            reset() // Reset if the video is nil, which means we want to start fresh
            await useCase.resetPagination()
            await fetchVideos()
            return
        }
        
        guard canLoadMoreVideos && viewState != .loading else { return }
        
        let thresholdIndex = totalVideos.index(totalVideos.endIndex, offsetBy: -1)
        if totalVideos.firstIndex(where: { $0.id == video.id }) == thresholdIndex {
            await fetchVideos()
        }
    }
}
