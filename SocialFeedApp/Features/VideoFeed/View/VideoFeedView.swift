//
//  VideosFeedView.swift
//  SocialFeedApp
//
//  Created by Usman on 24.06.25.
//

import SwiftUI

// MARK: - Main View
struct VideoFeedView: View {
    @State private var viewModel = VideoFeedViewModel()
    @State private var scrollLastOffset: CGFloat = 0
    @State private var currentIndex = 0
    @State private var scrollPosition: Int? = 0
    @State private var isScrolling = false
    
    var body: some View {
        ZStack(alignment: .center) {
            switch viewModel.viewState {
            case .idle, .loading:
                LoadingView(message: "")
            case .error(let error):
                FallbackView(errorMessage: error.localizedDescription) {
                    // TODO: Handle retry action
                }
            case .result(let videos):
                videoFeedPlayerView(
                    videos: videos
                )
            case .empty:
                FallbackView {
                    // TODO: Handle retry action
                }
            }
        }
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .task {
            await viewModel.fetchVideos()
        }
    }
    
    // MARK: - Video Feed Player View
    private func videoFeedPlayerView(
        videos: [UI.Feed.Video]
    ) -> some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                        VideoFeedItemView(
                            video: video,
                            isCurrentVideo: index == currentIndex,
                            isScrolling: isScrolling
                        )
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .clipped()
                        .id(index)
                        .onAppear {
                            // Load more videos when scroll reaches at last item.
                            if index >= videos.count - 1 {
                                Task {
                                    await viewModel.loadMoreVideos()
                                }
                            }
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPosition)
            .onChange(of: scrollPosition) { _, newValue in
                if let newValue = newValue {
                    currentIndex = newValue
                }
            }
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                if value != scrollLastOffset {
                    isScrolling = true
                } else {
                    isScrolling = false
                }
                
                scrollLastOffset = value
            }
            .ignoresSafeArea(.all)
            .background(Color.black)
        }
    }
}

// MARK: - Video Feed Item View
struct VideoFeedItemView: View {
    let video: UI.Feed.Video
    let isCurrentVideo: Bool
    let isScrolling: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video player
                VideoFeedPlayerView(
                    videoURL: video.shortVideoURL,
                    isCurrentVideo: isCurrentVideo,
                    isScrolling: isScrolling
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                
                // Gradient overlay
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.3),
                        Color.clear,
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Content overlay
                VStack {
                    // Top section with creator info
                    HStack {
                        VideoFeedCreatorView(creator: video.creator)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Bottom section with description and actions
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(video.description)
                                .font(.body)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VideoFeedActionButtonsView(video: video)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 60)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    VideoFeedView()
}
