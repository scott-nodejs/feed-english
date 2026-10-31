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
    @State private var reloadTrigger = UUID()
    
    var body: some View {
        ZStack(alignment: .center) {
            switch viewModel.viewState {
            case .idle, .loading:
                LoadingView(message: "")
            case .error(_):
                FallbackView() {
                    reloadTrigger = UUID()
                }
            case .result(let videos):
                videoFeedPlayerView(
                    videos: videos
                )
            case .empty:
                FallbackView(errorMessage: "No videos available") {
                    reloadTrigger = UUID()
                }
            }
        }
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onChange(of: SocialAPI.shared.revision) { _, _ in reloadTrigger = UUID() }
        .task(id: reloadTrigger) {
            await viewModel.loadMoreVideos(video: nil)
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
                        .onAppear {
                            // Load more videos when scroll reaches at last item.
                            Task {
                                await viewModel.loadMoreVideos(video: video)
                            }
                        }
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .clipped()
                        .id(index)
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
    @State private var showsChallenge = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video player
                ZStack {
                    if video.scene?.preview == true {
                        let scale = max(geometry.size.width / 280, geometry.size.height / 230)
                        Image("ChallengeReference").resizable().frame(width: 1199 * scale, height: 1312 * scale)
                            .offset(x: -313 * scale - (280 * scale - geometry.size.width) / 2,
                                    y: -772 * scale - (230 * scale - geometry.size.height) / 2)
                            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                            .clipped().allowsHitTesting(false)
                    } else {
                        AsyncImage(url: URL(string: SocialAPI.mediaURL(video.scene?.coverUrl))) { image in image.resizable().scaledToFill() }
                        placeholder: { Color.black }
                        .allowsHitTesting(false)
                        if !video.shortVideoURL.isEmpty {
                            VideoFeedPlayerView(videoURL: video.shortVideoURL, isCurrentVideo: isCurrentVideo && !showsChallenge, isScrolling: isScrolling)
                        }
                    }
                }.frame(width: geometry.size.width, height: geometry.size.height).clipped()

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
                            Button {
                                showsChallenge = true
                            } label: {
                                Label("挑战这个场景", systemImage: "mic")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .overlay(Capsule().stroke(.white, lineWidth: 1))
                            }
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
        .fullScreenCover(isPresented: $showsChallenge) {
            ChallengeFlowView(video: video)
        }
    }
}

#Preview {
    VideoFeedView()
}
