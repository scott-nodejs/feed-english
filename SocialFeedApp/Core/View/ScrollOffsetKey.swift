//
//  ScrollOffsetKey.swift
//  SocialFeedApp
//
//  Created by Usman on 26.06.25.
//

import SwiftUI

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

