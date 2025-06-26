//
//  Error+Mock.swift
//  SocialFeedAppTests
//
//  Created by Usman on 26.06.25.
//

import Foundation

enum MockError: Error, LocalizedError {
    case invalidData
    case networkError
    case decodingError
    case unknownError
    
    public var errorDescription: String? {
        switch self {
        case .invalidData:
            "Invalid data"
        case .networkError:
            "Network error"
        case .decodingError:
            "Decoding error"
        case .unknownError:
            "Unknown error"
        }
    }
}
