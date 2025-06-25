//
//  VideosFeedView.swift
//  SocialFeedApp
//
//  Created by Usman on 24.06.25.
//

import SwiftUI

struct VideoFeedView: View {
    @State var viewModel = VideoFeedViewModel()
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .task {
            await viewModel.fetchVideos()
        }
    }
}

#Preview {
    VideoFeedView()
}
