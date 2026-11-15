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

    @Test func deployedBackendUsesRootApiPath() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SocialMockProtocol.self]
        let api = SocialAPI(baseURL: SocialAPI.defaultURL, session: URLSession(configuration: configuration))
        SocialMockProtocol.handler = { request in
            #expect(request.url?.absoluteString == "https://yima.hazer.top/lazyer/mobile/social/feed?limit=10")
            return (200, Data(#"{"code":200,"data":{"items":[],"nextCursor":null}}"#.utf8))
        }
        #expect(try await api.feed().items.isEmpty)
    }

    private var practiceScene: SceneFeed {
        .init(id: 3, dialogueId: 10, title: "Coffee", description: nil, videoUrl: nil, coverUrl: nil,
              category: "Daily", level: 1, creatorUid: nil, creatorName: "Yiner", creatorAvatar: nil,
              sentenceCount: 1, likes: 0, comments: 0, liked: false)
    }
    @Test func selectedPracticeResumesOnceAfterLogin() async throws {
        let api = client()
        api.logout()
        let model = ChallengeFlowModel(scene: practiceScene, api: api)
        model.step = .modes
        var starts = 0
        SocialMockProtocol.handler = { request in
            switch request.url?.path {
            case "/oneCode/lazyer/mobile/login":
                return (200, Data(#"{"code":200,"data":{"token":"test-token"}}"#.utf8))
            case "/oneCode/lazyer/mobile/social/me":
                return (200, Data(#"{"code":200,"data":{"uid":7,"nickname":"Test"}}"#.utf8))
            case "/oneCode/lazyer/mobile/social/feed/3/practice":
                #expect(request.httpMethod == "POST")
                starts += 1
                return (200, Data(#"{"code":200,"data":{"id":9,"uid":7,"dialogueId":10,"finished":false,"lines":[{"contentId":100,"contentOrder":1,"role":0,"en":"Hello","zh":"你好"}]}}"#.utf8))
            default:
                Issue.record("Unexpected request")
                return (500, Data())
            }
        }
        await model.selectMode("单人练习")
        #expect(model.login)
        #expect(model.step == .modes)
        #expect(starts == 0)
        try await api.login(phone: "test-user", password: "test-password")
        model.login = false
        await model.resumeAfterLogin()
        #expect(model.step == .practice)
        #expect(model.practice?.id == 9)
        #expect(model.lines.first?.contentId == 100)
        await model.resumeAfterLogin()
        #expect(starts == 1)
    }
    @Test func cancellingLoginClearsPendingMode() async throws {
        let api = client()
        api.logout()
        let model = ChallengeFlowModel(scene: practiceScene, api: api)
        model.step = .modes
        await model.selectMode("好友 PK")
        #expect(model.login)
        model.login = false
        await model.resumeAfterLogin()
        SocialMockProtocol.handler = { request in
            if request.url?.path.hasSuffix("/login") == true {
                return (200, Data(#"{"code":200,"data":{"token":"test-token"}}"#.utf8))
            }
            #expect(request.url?.path.hasSuffix("/me") == true)
            return (200, Data(#"{"code":200,"data":{"uid":7,"nickname":"Test"}}"#.utf8))
        }
        try await api.login(phone: "test-user", password: "test-password")
        await model.resumeAfterLogin()
        #expect(model.step == .modes)
        #expect(model.friends.isEmpty)
    }

    private var wechatSession: WechatLoginSession {
        .init(sessionId: "al_" + String(repeating: "A", count: 22), verifier: String(repeating: "B", count: 43), confirmationCode: "123456", expiresAt: 9999999999999, qrImageBase64: "aW1hZ2U=", miniProgramUrl: nil)
    }
    @Test func wechatCreationDoesNotSendOldLoginToken() async throws {
        let api = client()
        SocialMockProtocol.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/oneCode/lazyer/mobile/wechat-login/sessions")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            return (200, Data(#"{"code":200,"data":{"sessionId":"al_AAAAAAAAAAAAAAAAAAAAAA","verifier":"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB","confirmationCode":"123456","expiresAt":9999999999999,"qrImageBase64":"aW1hZ2U="}}"#.utf8))
        }
        let result = try await api.createWechatLogin()
        #expect(result.sessionId == wechatSession.sessionId)
    }
    @Test func wechatPollingNeverPutsOwnerSecretInUrl() async throws {
        let api = client()
        SocialMockProtocol.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.query == nil)
            #expect(request.url?.path.hasSuffix("/status") == true)
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            return (200, Data(#"{"code":200,"data":{"status":"SCANNED","confirmationCode":"123456","expiresAt":9999999999999,"nickname":"Alex"}}"#.utf8))
        }
        #expect(try await api.wechatStatus(wechatSession).status == "SCANNED")
    }
    @Test func confirmedWechatSessionLoadsSameUserProfile() async throws {
        let api = client()
        SocialMockProtocol.handler = { request in
            if request.url?.path.hasSuffix("/exchange") == true {
                #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
                return (200, Data(#"{"code":200,"data":{"token":"wechat-user-token"}}"#.utf8))
            }
            #expect(request.url?.path.hasSuffix("/social/me") == true)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer wechat-user-token")
            return (200, Data(#"{"code":200,"data":{"uid":7,"nickname":"WeChat user"}}"#.utf8))
        }
        try await api.completeWechatLogin(wechatSession)
        #expect(api.person?.uid == 7)
        #expect(api.isLoggedIn)
    }
    @Test func unconfirmedWechatSessionDoesNotReplaceLogin() async throws {
        let api = client()
        SocialMockProtocol.handler = { _ in (200, Data(#"{"code":409,"msg":"请先在小程序中确认登录"}"#.utf8)) }
        do { try await api.completeWechatLogin(wechatSession); Issue.record("Expected confirmation requirement") }
        catch { #expect(api.token == "test-token") }
    }
    @Test func followUsesIdempotentEndpoint() async throws {
        let api = client()
        SocialMockProtocol.handler = { request in
            #expect(request.httpMethod == "PUT")
            #expect(request.url?.path == "/oneCode/lazyer/mobile/social/creators/2/follow")
            return (200, Data(#"{"code":200,"data":{"uid":2,"followed":true,"followers":1}}"#.utf8))
        }
        let response: FollowResponse = try await api.request("lazyer/mobile/social/creators/2/follow", method: "PUT")
        #expect(response.followed); #expect(response.followers == 1)
    }
    @Test func manualVideoPauseSurvivesBackgroundAndReturningToFeed() {
        var intent = VideoPlaybackIntent(isCurrent: true)
        #expect(intent.shouldPlay)
        intent.toggle()
        intent.isForeground = false
        #expect(!intent.shouldPlay)
        intent.isForeground = true
        #expect(!intent.shouldPlay)
        intent.isCurrent = false
        intent.isCurrent = true
        #expect(!intent.shouldPlay)
        intent.toggle()
        #expect(intent.shouldPlay)
    }
    @Test func videosOnlyResumeWhenCurrentAndForeground() {
        var intent = VideoPlaybackIntent(isCurrent: true)
        intent.isScrolling = true
        #expect(!intent.shouldPlay)
        intent.isCurrent = false; intent.isScrolling = false
        #expect(!intent.shouldPlay)
        intent.isCurrent = true; intent.isForeground = false
        #expect(!intent.shouldPlay)
        intent.isForeground = true
        #expect(intent.shouldPlay)
    }

}
