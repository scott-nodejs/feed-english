//
//  LoadingView.swift
//  SocialFeedApp
//
//  Created by Usman on 25.06.25.
//

import SwiftUI

struct LoadingView: View {
    let message: String
    
    init(message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        ProgressView(message)
            .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
            .scaleEffect(1)
    }
}
