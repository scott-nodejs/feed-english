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
                            video: video
                        )
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .clipped()
                        .id(index)
                        .onAppear {
                            // TODO: Handle loading more videos when approaching the end
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .ignoresSafeArea(.all)
            .background(Color.black)
        }
    }
}

// MARK: - Video Feed Item View
struct VideoFeedItemView: View {
    let video: UI.Feed.Video
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video player
                VideoFeedPlayerView(
                    videoURL: video.shortVideoURL
                )
                .clipped()
    
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
                    .padding(.bottom, 100)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    VideoFeedView()
}
