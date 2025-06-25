//
//  FallbackView.swift
//  SocialFeedApp
//
//  Created by Usman on 25.06.25.
//

import SwiftUI

struct FallbackView: View {
    let errorMessage: String?
    var retryAction: (() -> Void)
    
    init(
        errorMessage: String? = nil,
        retryAction: @escaping (() -> Void)
    ) {
        self.errorMessage = errorMessage
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            Spacer()
            
            if let errorMessage {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 70))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.bottom, 16)
                    .accessibilityLabel("Error Icon")
                
                Text(errorMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 32)
                    .accessibilityLabel("Error Message: \(errorMessage)")
            }
            
            Button(action: retryAction) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("try_again_button_title")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.blue)
                )
                .foregroundColor(.white)
                .font(.headline)
            }
            .padding(.top, 16)
            .accessibilityLabel("Retry Button")
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

