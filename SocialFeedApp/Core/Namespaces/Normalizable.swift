//
//  Normalizable.swift
//  SocialFeedApp
//
//  Created by Usman on 25.06.25.
//

import Foundation

protocol Normalizable {
    associatedtype Output
    
    func normalize() -> Output
}
    
