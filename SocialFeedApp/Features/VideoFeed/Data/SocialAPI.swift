import Foundation
import Observation
import Security

struct SceneFeed: Decodable, Identifiable {
    let id: Int
    let dialogueId: Int
    let title: String
    let description: String?
    let videoUrl: String?
    let coverUrl: String?
    let category: String
    let level: Int
    let creatorUid: Int?
    let creatorName: String
    let creatorAvatar: String?
    let sentenceCount: Int
    var likes: Int
    var comments: Int
    var liked: Bool
    var dislikes: Int? = nil
    var disliked: Bool? = nil
    var preview: Bool? = nil

    var video: UI.Feed.Video {
        .init(creator: .init(name: creatorName, avatarURL: SocialAPI.mediaURL(creatorAvatar)),
              shortVideoURL: SocialAPI.mediaURL(videoUrl), fullVideoURL: SocialAPI.mediaURL(videoUrl),
              description: description ?? title, likes: likes, comments: comments, scene: self)
    }
}
struct SocialPage<Item: Decodable>: Decodable { let items: [Item]; let nextCursor: Int64? }
struct SceneComment: Decodable, Identifiable {
    let id: Int64
    let uid: Int
    let feedId: Int
    let body: String
    let nickname: String?
    let avatar: String?
    let createdAt: String
}
struct SocialPerson: Decodable, Identifiable {
    let uid: Int
    let nickname: String?
    let avatar: String?
    let requesterUid: Int?
    let friendshipStatus: Int?
    var id: Int { uid }
    var name: String { nickname?.isEmpty == false ? nickname! : "用户 \(uid)" }
}
struct DialogueLine: Decodable, Identifiable {
    let contentId: Int
    let contentOrder: Int
    let role: Int?
    let en: String
    let zh: String?
    let referenceVoiceUrl: String?
    let submittedVoiceUrl: String?
    let score: Int?
    let fluency: Int?
    var id: Int { contentId }
}
struct PracticeSession: Decodable {
    let id: Int
    let uid: Int
    let dialogueId: Int
    let lines: [DialogueLine]
    let score: Double?
    let fluency: Double?
    let finished: Bool
}
struct PkLine: Decodable, Identifiable {
    let contentId: Int
    let contentOrder: Int
    let role: Int
    let roleName: String?
    let en: String
    let zh: String?
    let referenceVoiceUrl: String?
    let submittedUid: Int?
    let submittedVoiceUrl: String?
    let score: Int?
    let fluency: Int?
    var id: Int { contentId }
    var line: DialogueLine {
        .init(contentId: contentId, contentOrder: contentOrder, role: role, en: en, zh: zh,
              referenceVoiceUrl: referenceVoiceUrl, submittedVoiceUrl: submittedVoiceUrl, score: score, fluency: fluency)
    }
}
struct PkRoom: Decodable, Identifiable {
    let roomId: Int
    let dialogueId: Int
    let dialogueTitle: String?
    let status: Int
    let statusName: String?
    let inviterUid: Int
    let inviterName: String?
    let inviterAvatar: String?
    let inviteeUid: Int?
    let inviteeName: String?
    let inviteeAvatar: String?
    let currentContentOrder: Int?
    let currentUid: Int?
    let inviterScore: Double?
    let inviteeScore: Double?
    let winnerUid: Int?
    let lines: [PkLine]?
    var id: Int { roomId }
    var terminal: Bool { [2, 3, 4, 5, 6].contains(status) }
}

struct LikeResponse: Decodable { let liked: Bool; let likes: Int; let disliked: Bool?; let dislikes: Int? }
private struct APIEnvelope<Value: Decodable>: Decodable { let code: Int; let msg: String?; let data: Value? }
private struct EmptyPayload: Decodable { }
private struct LoginPayload: Decodable { let token: String }

enum SocialError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

private enum LoginKeychain {
    static func read() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "SocialFeedApp",
            kSecAttrAccount as String: "yiner-token", kSecReturnData as String: true]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ token: String?) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "SocialFeedApp", kSecAttrAccount as String: "yiner-token"]
        SecItemDelete(query as CFDictionary)
        guard let token else { return }
        var values = query
        values[kSecValueData as String] = Data(token.utf8)
        values[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(values as CFDictionary, nil)
    }
}

@MainActor @Observable
final class SocialAPI {
    nonisolated static var usesLocalPreview: Bool {
        #if DEBUG
        let value = ProcessInfo.processInfo.environment["ONECODE_USE_LOCAL_PREVIEW"] ?? (Bundle.main.object(forInfoDictionaryKey: "OneCodeUseLocalPreview") as? String) ?? "NO"
        return ["YES", "TRUE", "1"].contains(value.uppercased())
        #else
        return false
        #endif
    }
    static let shared = SocialAPI()
    var baseURL: String
    private(set) var token: String?
    private(set) var person: SocialPerson?
    private(set) var revision = 0
    private let session: URLSession
    private let persists: Bool
    var isLoggedIn: Bool { token != nil }
    static let localURL = "http://127.0.0.1:9080/oneCode"

    init(baseURL: String? = nil, session: URLSession = .shared, token: String? = nil) {
        self.baseURL = baseURL ?? UserDefaults.standard.string(forKey: "social-base-url") ?? Self.localURL
        self.session = session
        self.persists = baseURL == nil
        self.token = token ?? (baseURL == nil ? LoginKeychain.read() : nil)
    }
    func configure(_ address: String) throws {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URLComponents(string: value), ["http", "https"].contains(url.scheme), url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
            throw SocialError.message("请输入完整后端地址，例如 \(Self.localURL)")
        }
        if baseURL != value {
            logout(); baseURL = value
            if persists { UserDefaults.standard.set(value, forKey: "social-base-url") }
            revision += 1
        }
    }
    func login(phone: String, password: String) async throws {
        let result: LoginPayload = try await request("lazyer/mobile/login", method: "POST", body: ["phone": phone, "password": password])
        token = result.token
        if persists { LoginKeychain.save(result.token) }
        do { person = try await request("lazyer/mobile/social/me") }
        catch { logout(); throw error }
        revision += 1
    }
    func restore() async throws { if isLoggedIn { person = try await request("lazyer/mobile/social/me") } }
    func logout() { token = nil; person = nil; if persists { LoginKeychain.save(nil) }; revision += 1 }

    private func response<Value: Decodable>(_ path: String, method: String, body: [String: Any]?, multipart: Data? = nil, contentType: String? = nil) async throws -> Value? {
        guard let base = URL(string: baseURL + "/"), let url = URL(string: path, relativeTo: base)?.absoluteURL else { throw SocialError.message("后端地址无效") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = multipart == nil ? 30 : 120
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let multipart { request.httpBody = multipart; request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        let (data, rawResponse) = try await session.data(for: request)
        guard let http = rawResponse as? HTTPURLResponse else { throw SocialError.message("后端响应无效") }
        if http.statusCode == 401 { logout(); throw SocialError.message("登录已过期，请重新登录") }
        guard (200..<300).contains(http.statusCode) else { throw SocialError.message("请求失败（\(http.statusCode)）") }
        let envelope = try JSONDecoder().decode(APIEnvelope<Value>.self, from: data)
        if envelope.code == 401 { logout() }
        guard envelope.code == 200 else { throw SocialError.message(envelope.msg ?? "请求失败") }
        return envelope.data
    }
    func request<Value: Decodable>(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> Value {
        guard let value: Value = try await response(path, method: method, body: body) else { throw SocialError.message("服务器未返回数据") }
        return value
    }
    func empty(_ path: String, method: String = "POST") async throws {
        let _: EmptyPayload? = try await response(path, method: method, body: nil)
    }
    func activeRoom() async throws -> PkRoom? { try await response("lazyer/mobile/social/rooms/active", method: "GET", body: nil) }
    func feed(before: Int64? = nil) async throws -> SocialPage<SceneFeed> {
        try await request("lazyer/mobile/social/feed?limit=10" + (before.map { "&before=\($0)" } ?? ""))
    }
    func upload<Value: Decodable>(_ path: String, line: Int, requestId: String, url: URL, duration: Double) async throws -> Value {
        let boundary = "Boundary-\(UUID().uuidString)"
        var data = Data()
        for (key, value) in ["contentId": String(line), "requestId": requestId, "fileLength": String(Int(duration.rounded()))] {
            data.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n".utf8))
        }
        data.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"voice.wav\"\r\nContent-Type: audio/wav\r\n\r\n".utf8))
        data.append(try Data(contentsOf: url))
        data.append(Data("\r\n--\(boundary)--\r\n".utf8))
        guard let value: Value = try await response(path, method: "POST", body: nil, multipart: data, contentType: "multipart/form-data; boundary=\(boundary)") else {
            throw SocialError.message("服务器未返回录音结果")
        }
        return value
    }
    nonisolated static func mediaURL(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        if value.hasPrefix("https://") || value.hasPrefix("http://") { return value }
        // Existing yiner services store object keys rather than complete CDN URLs.
        return "https://img.hazer.top/" + value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

/// Explicit Debug preview fixtures. Live API failures never fall back to these values.
enum LocalDialoguePreview {
    static let english = ["What can I get for you today?", "What size would you like?", "Would you like it hot or iced?", "Would you like anything else?", "Is that for here or to go?", "May I have your name?", "How would you like to pay?", "Enjoy your coffee!"]
    static let chinese = ["今天想喝点什么？", "你想要什么尺寸的？", "你想要热的还是冰的？", "还需要其他东西吗？", "在这里享用还是带走？", "可以告诉我你的名字吗？", "你想如何付款？", "享用你的咖啡吧！"]
    static let answers = ["I'd like a latte, please.", "A medium, please.", "Iced, please.", "That's all, thank you.", "To go, please.", "My name is Alex.", "By card, please.", "Thank you. Have a nice day!"]
    static var lines: [DialogueLine] {
        english.indices.map { .init(contentId: $0 + 1, contentOrder: $0 + 1, role: $0 % 2, en: english[$0], zh: chinese[$0], referenceVoiceUrl: nil, submittedVoiceUrl: nil, score: [94,89,96,88,92,94,91,92][$0], fluency: 89) }
    }
    static var friends: [SocialPerson] {
        ["Alex", "Emma", "David", "Sophia", "Lucas", "Olivia", "Jack"].enumerated().map {
            .init(uid: 202 + $0.offset, nickname: $0.element, avatar: "preview://\($0.element)", requesterUid: nil, friendshipStatus: 1)
        }
    }
    static func room(friend: SocialPerson?, status: Int) -> PkRoom {
        .init(roomId: -1, dialogueId: -1, dialogueTitle: "咖啡店 · 点咖啡", status: status, statusName: status == 7 ? "准备就绪" : "进行中",
              inviterUid: 101, inviterName: "我", inviterAvatar: "preview://我", inviteeUid: friend?.uid ?? 202, inviteeName: friend?.name ?? "Alex", inviteeAvatar: friend?.avatar ?? "preview://Alex",
              currentContentOrder: 1, currentUid: 101, inviterScore: 92, inviteeScore: 87, winnerUid: 101, lines: [])
    }
}
