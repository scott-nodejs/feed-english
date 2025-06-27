//
//  VideoFeedViewModelTests.swift
//  SocialFeedAppTests
//
//  Created by Usman on 24.06.25.
//

import Testing
@testable import SocialFeedApp

@Suite("Tests for VideoFeedViewModel")
struct VideoFeedViewModelTests {

    @Test("Test 1: fetch videos with success")
    func testFetchFeedVideos_withSuccess_expectVideosList() async throws {
        // Given
        let mockResponse: API.Feed.Response = .mock()
        let result = Result<Decodable, Error>.success(mockResponse)
        let repository = VideoFeedRepositoryMock(result: result)
        let useCase = VideoFeedUseCaseMock(repository: repository)
        let sut = VideoFeedViewModel(useCase: useCase)
        
        // When
        await sut.fetchVideos()
        
        // Then
        switch sut.viewState {
        case .result(let videos):
            #expect(videos.count == 3)
            
            let video = try #require(videos.first)
            #expect(video.shortVideoURL == "https://example.com/short-video.mp4")
            #expect(video.likes == 100)
        default:
            #expect(Bool(false), "Test failed with unexpected state")
        }
    }
    
    @Test("Test 2: fetch videos with empty list")
    func testFetchFeedVideos_withSuccess_expectEmptyList() async throws {
        // Given
        let mockResponse: API.Feed.Response = .init(videos: [])
        let result = Result<Decodable, Error>.success(mockResponse)
        let repository = VideoFeedRepositoryMock(result: result)
        let useCase = VideoFeedUseCaseMock(repository: repository)
        let sut = VideoFeedViewModel(useCase: useCase)
        
        // When
        await sut.fetchVideos()
        
        // Then
        switch sut.viewState {
        case .empty:
            #expect(Bool(true), "Test passed with 'empty' state")
        default:
            #expect(Bool(false), "Test failed with unexpected state")
        }
    }
    
    @Test("Test 3: fetch videos with error")
    func testFetchFeedVideos_withFailure_expectError() async throws {
        // Given
        let mockError: Error = MockError.invalidData
        let result = Result<Decodable, Error>.failure(MockError.invalidData)
        let repository = VideoFeedRepositoryMock(result: result)
        let useCase = VideoFeedUseCaseMock(repository: repository)
        let sut = VideoFeedViewModel(useCase: useCase)
        
        // When
        await sut.fetchVideos()
        
        // Then
        switch sut.viewState {
        case .error(let error):
            #expect(error.localizedDescription == mockError.localizedDescription)
        default:
            #expect(Bool(false), "Test failed with unexpected state")
        }
    }
}
