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
    func loadMoreVideos() async
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
    private var canLoadMorePages: Bool {
        return currentPageNumber < totalPages && viewState != .loading // Flag to control loading more pages
    }
    private var currentPageNumber = 0 // Start from page 0
    private var totalPages = 5 // Assuming a total of 5 pages
    
    init(
        useCase: VideoFeedUseCaseType = VideoFeedUseCase()
    ) {
        self.useCase = useCase
    }
}

extension VideoFeedViewModel: VideoFeedViewModelType {
    @MainActor
    func fetchVideos() async {
        guard canLoadMorePages else { return }
        
        // Set the initial state to loading
        self.viewState = .loading
        
        do {
            // Fetch videos using the use case
            let videos = try await useCase.fetchVideos()
            
            // Normalize the videos to the UI model
            let normalizedVideos = videos.map { $0.normalize() }
            self.totalVideos += normalizedVideos
            self.currentPageNumber += 1
            
            // Update the view state with the fetched videos
            self.viewState = normalizedVideos.isEmpty ? .empty : .result(videos: self.totalVideos)
        } catch {
            // Handle error appropriately, e.g., show an alert or log the error
            viewState = .error(error)
        }
    }
    
    func loadMoreVideos() async {
        await fetchVideos()
    }
}
