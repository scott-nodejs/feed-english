//
//  VideoFeedUseCaseTests.swift
//  SocialFeedAppTests
//
//  Created by Usman on 27.06.25.
//

import Testing
@testable import SocialFeedApp

@Suite("Tests for VideoFeedUseCase")
struct VideoFeedUseCaseTests {
    
    @Test("Test 1: fetch videos with success")
    func testFetchFeedVideos_withSuccess_expectVideosList() async throws {
        // Given
        let mockResponse: API.Feed.Response = .mock()
        let result = Result<Decodable, Error>.success(mockResponse)
        let repository = VideoFeedRepositoryMock(result: result)
        let sut = VideoFeedUseCaseMock(repository: repository)
        
        do {
            // When
            let videos = try await sut.fetchVideos()
            
            // Then
            #expect(videos.count == 3)
            let video = try #require(videos.last)
            #expect(video.id == "mock-video-id-3")
            #expect(video.likes == 300)
        } catch {
            #expect(Bool(false), "Test failed with unexpected state")
        }
    }
    
    @Test("Test 2: fetch videos with failure")
    func testFetchFeedVideos_withFailure_expectError() async throws {
        // Given
        let mockError = MockError.networkError
        let result = Result<Decodable, Error>.failure(mockError)
        let repository = VideoFeedRepositoryMock(result: result)
        let sut = VideoFeedUseCaseMock(repository: repository)
        
        do {
            // When
            let videos = try await sut.fetchVideos()
            
            // Then
            #expect(Bool(false), "Test failed, expected an error but got videos: \(videos)")
        } catch {
            #expect(Bool(true), "Test passed with expected state")
        }
    }
}
