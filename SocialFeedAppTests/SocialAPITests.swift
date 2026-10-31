import Foundation
import Testing
@testable import SocialFeedApp

private final class SocialMockProtocol: URLProtocol, @unchecked Sendable {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}

@Suite("Social API contracts", .serialized)
@MainActor struct SocialAPITests {
    private func client() -> SocialAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SocialMockProtocol.self]
        return SocialAPI(baseURL: "http://localhost:9080/oneCode", session: URLSession(configuration: configuration), token: "test-token")
    }
    @Test func preservesContextPathCursorAndIdentity() async throws {
        let api = client()
        SocialMockProtocol.handler = { request in
            #expect(request.url?.path == "/oneCode/lazyer/mobile/social/feed")
            #expect(request.url?.query?.contains("before=12") == true)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            return (200, Data(#"{"code":200,"data":{"items":[],"nextCursor":null}}"#.utf8))
        }
        let page = try await api.feed(before: 12)
        #expect(page.items.isEmpty); #expect(page.nextCursor == nil)
    }
    @Test func unauthorizedClearsIdentity() async throws {
        let api = client()
        SocialMockProtocol.handler = { _ in (401, Data(#"{"code":401,"msg":"expired"}"#.utf8)) }
        do { let _: SocialPerson = try await api.request("lazyer/mobile/social/me"); Issue.record("Expected authentication failure") }
        catch { #expect(!api.isLoggedIn) }
    }
    @Test func businessFailuresDoNotBecomeSuccess() async throws {
        let api = client()
        SocialMockProtocol.handler = { _ in (200, Data(#"{"code":409,"msg":"请按顺序提交当前台词"}"#.utf8)) }
        do { let _: PracticeSession = try await api.request("lazyer/mobile/social/practice/1"); Issue.record("Expected rejected request") }
        catch { #expect(error.localizedDescription == "请按顺序提交当前台词") }
    }
    @Test func emptyMutationsAndNullableActiveRoom() async throws {
        let api = client()
        SocialMockProtocol.handler = { _ in (200, Data(#"{"code":200,"data":null}"#.utf8)) }
        try await api.empty("lazyer/mobile/social/friends/2/request")
        #expect(try await api.activeRoom() == nil)
    }
    @Test func roomWithoutScoresNeverDefaultsToDemoScores() async throws {
        let api = client()
        SocialMockProtocol.handler = { _ in (200, Data(#"{"code":200,"data":{"roomId":5,"dialogueId":10,"status":0,"inviterUid":1,"lines":[]}}"#.utf8)) }
        let room: PkRoom = try await api.request("lazyer/mobile/social/rooms/5")
        #expect(room.inviterScore == nil); #expect(room.inviteeScore == nil)
        #expect(!room.terminal)
    }
    @Test func likeUsesIdempotentVerb() async throws {
        let api = client()
        SocialMockProtocol.handler = { request in
            #expect(request.httpMethod == "PUT")
            return (200, Data(#"{"code":200,"data":{"liked":true,"likes":42}}"#.utf8))
        }
        let result: LikeResponse = try await api.request("lazyer/mobile/social/feed/2/like", method: "PUT")
        #expect(result.liked); #expect(result.likes == 42)
    }
    @Test func originalFeedRepositoryMapsSceneAndResetsCursor() async throws {
        let api = client()
        let repository = VideoFeedRepository(api: api)
        var requests = 0
        SocialMockProtocol.handler = { request in
            requests += 1
            if requests == 2 {
                #expect(request.url?.query?.contains("before=3") == true)
                return (200, Data(#"{"code":200,"data":{"items":[],"nextCursor":null}}"#.utf8))
            }
            #expect(request.url?.query?.contains("before=") == false)
            return (200, Data(#"{"code":200,"data":{"items":[{"id":3,"dialogueId":10,"title":"Coffee","description":"Order coffee","videoUrl":"https://example.com/coffee.mp4","coverUrl":"https://example.com/cover.jpg","category":"Daily","level":1,"creatorUid":2,"creatorName":"Emma","creatorAvatar":null,"sentenceCount":8,"likes":4,"comments":2,"liked":true,"dislikes":1,"disliked":false}],"nextCursor":3}}"#.utf8))
        }
        let first = try await repository.fetchVideos()
        #expect(first.first?.id == "3")
        #expect(first.first?.normalize().scene?.dialogueId == 10)
        #expect(first.first?.likes == 4)
        #expect(first.first?.shortVideoURL == "https://example.com/coffee.mp4")
        #expect(try await repository.fetchVideos().isEmpty)
        #expect(try await repository.fetchVideos().isEmpty)
        #expect(requests == 2)
        await repository.resetPagination()
        #expect(try await repository.fetchVideos().count == 1)
        #expect(requests == 3)
    }

}
