import SwiftUI

@MainActor @Observable
final class SocialFeedStore {
    static let shared = SocialFeedStore()
    private let api: SocialAPI
    init(api: SocialAPI? = nil) { self.api = api ?? SocialAPI.shared }
    var items: [SceneFeed] = []
    var nextCursor: Int64?
    var loading = false
    var error: String?
    func load(reset: Bool = false) async {
        guard !loading else { return }
        if reset { items = []; nextCursor = nil }
        guard reset || items.isEmpty || nextCursor != nil else { return }
        loading = true; error = nil
        defer { loading = false }
        do {
            let page = try await api.feed(before: reset ? nil : nextCursor)
            let known = Set(items.map(\.id))
            items.append(contentsOf: page.items.filter { !known.contains($0.id) })
            nextCursor = page.nextCursor
        } catch { self.error = error.localizedDescription }
    }
    func refresh(_ id: Int) async {
        do {
            let updated: SceneFeed = try await api.request("lazyer/mobile/social/feed/\(id)")
            if let index = items.firstIndex(where: { $0.id == id }) { items[index] = updated }
        } catch { self.error = error.localizedDescription }
    }
    func like(_ scene: SceneFeed, desired: Bool? = nil) async throws {
        let current = items.first(where: { $0.id == scene.id }) ?? scene
        if scene.preview == true {
            if let index = items.firstIndex(where: { $0.id == scene.id }) { items[index].liked = desired ?? !current.liked; items[index].disliked = false }
            return
        }
        let response: LikeResponse = try await api.request("lazyer/mobile/social/feed/\(scene.id)/like", method: (desired ?? !current.liked) ? "PUT" : "DELETE")
        if let index = items.firstIndex(where: { $0.id == scene.id }) { items[index].liked = response.liked; items[index].likes = response.likes; items[index].disliked = response.disliked; items[index].dislikes = response.dislikes }
    }
    func dislike(_ scene: SceneFeed, desired: Bool? = nil) async throws {
        let current = items.first(where: { $0.id == scene.id }) ?? scene
        if scene.preview == true {
            if let index = items.firstIndex(where: { $0.id == scene.id }) { items[index].disliked = desired ?? !(current.disliked ?? false); items[index].liked = false }
            return
        }
        let response: LikeResponse = try await api.request("lazyer/mobile/social/feed/\(scene.id)/dislike", method: (desired ?? !(current.disliked ?? false)) ? "PUT" : "DELETE")
        if let index = items.firstIndex(where: { $0.id == scene.id }) {
            items[index].liked = response.liked; items[index].likes = response.likes
            items[index].disliked = response.disliked; items[index].dislikes = response.dislikes
        }
    }

    func follow(_ scene: SceneFeed, desired: Bool? = nil) async throws {
        let current = items.first(where: { $0.id == scene.id }) ?? scene
        if scene.preview == true {
            if let index = items.firstIndex(where: { $0.id == scene.id }) { items[index].followed = desired ?? !(current.followed ?? false) }
            return
        }
        guard let uid = current.creatorUid else { throw SocialError.message("该内容暂无可关注的作者") }
        let response: FollowResponse = try await api.request("lazyer/mobile/social/creators/\(uid)/follow", method: (desired ?? !(current.followed ?? false)) ? "PUT" : "DELETE")
        for index in items.indices where items[index].creatorUid == uid { items[index].followed = response.followed }
    }

}

/// Authentication only. Server configuration is not part of the user login flow.
struct SocialLoginView: View {
    var reason = "登录后可保存练习记录、参与 PK 和互动。"
    @Environment(\.dismiss) private var dismiss
    @State private var api = SocialAPI.shared
    @State private var phone = ""
    @State private var password = ""
    @State private var wechat = false
    @State private var busy = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(reason).font(.subheadline).foregroundStyle(.secondary)
                }
                Section {
                    Button { wechat = true } label: {
                        Label("微信小程序登录", systemImage: "bubble.left.and.bubble.right.fill").foregroundStyle(.green)
                    }.disabled(busy)
                }
                Section("手机号登录") {
                    TextField("手机号", text: $phone).textContentType(.username).keyboardType(.phonePad)
                    SecureField("密码", text: $password).textContentType(.password)
                    Button(busy ? "登录中…" : "登录") {
                        busy = true; message = nil
                        Task {
                            defer { busy = false }
                            do {
                                try await api.login(phone: phone.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                                password = ""; dismiss()
                            } catch { message = error.localizedDescription }
                        }
                    }.disabled(busy || phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                }
                if let message { Section { Text(message).font(.subheadline).foregroundStyle(.red) } }
            }
            .navigationTitle("登录").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() }.disabled(busy) } }
        }
        .tint(.pink).preferredColorScheme(.light).interactiveDismissDisabled(busy)
        .sheet(isPresented: $wechat, onDismiss: { if api.isLoggedIn && api.person != nil { dismiss() } }) { WechatLoginView() }
    }
}

struct SceneCommentsView: View {
    let scene: SceneFeed
    @State private var comments: [SceneComment] = []
    @State private var nextCursor: Int64?
    @State private var bodyText = ""
    @State private var busy = false
    @State private var loading = false
    @State private var generation = UUID()
    @State private var error: String?
    @State private var requestId = UUID().uuidString
    @State private var login = false
    @State private var pendingSend = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if let error { Text(error).foregroundStyle(.red) }
                ForEach(comments) { comment in
                    HStack(alignment: .top, spacing: 12) {
                        SocialAvatar(url: comment.avatar, name: comment.nickname ?? "", size: 38)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(comment.nickname ?? "用户 \(comment.uid)").font(.subheadline.bold())
                            Text(comment.body).font(.subheadline)
                            Text(comment.createdAt).font(.caption).foregroundStyle(.secondary)
                        }
                    }.swipeActions {
                        if comment.uid == SocialAPI.shared.person?.uid {
                            Button("删除", role: .destructive) { Task { await delete(comment) } }
                        }
                    }
                }
                if loading { ProgressView().frame(maxWidth: .infinity) }
                if comments.isEmpty && !loading && error == nil { Text("还没有评论，聊聊你的练习心得吧").foregroundStyle(.secondary) }
                if nextCursor != nil { Button("加载更多") { Task { await load(reset: false) } }.disabled(loading) }
            }
            .refreshable { await load(reset: true) }
            .safeAreaInset(edge: .bottom) {
                HStack(alignment: .bottom) {
                    TextField("写下评论…", text: $bodyText, axis: .vertical).lineLimit(1...4)
                        .disabled(busy).padding(12).background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
                    Button(busy ? "发送中…" : "发送", action: send)
                        .disabled(busy || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bodyText.unicodeScalars.count > 500)
                }.padding(16).background(.white)
            }
            .navigationTitle("评论").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() }.disabled(busy) } }
        }
        .preferredColorScheme(.light).task { await load(reset: true) }
        .sheet(isPresented: $login, onDismiss: {
            let shouldSend = pendingSend && SocialAPI.shared.isLoggedIn
            pendingSend = false
            if shouldSend { send() }
        }) { SocialLoginView(reason: "登录后可发表评论，分享练习心得。") }
        .onChange(of: bodyText) { _, _ in requestId = UUID().uuidString }
        .interactiveDismissDisabled(busy)
    }
    private func send() {
        guard !busy, !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, bodyText.unicodeScalars.count <= 500 else { return }
        guard SocialAPI.shared.isLoggedIn else { pendingSend = true; login = true; return }
        let text = bodyText, id = requestId
        busy = true; error = nil
        Task {
            defer { busy = false }
            do {
                let _: SceneComment = try await SocialAPI.shared.request("lazyer/mobile/social/feed/\(scene.id)/comments", method: "POST", body: ["body": text, "requestId": id])
                bodyText = ""; requestId = UUID().uuidString
                await load(reset: true); await SocialFeedStore.shared.refresh(scene.id)
            } catch { self.error = error.localizedDescription }
        }
    }
    private func delete(_ comment: SceneComment) async {
        guard !busy else { return }; busy = true
        defer { busy = false }
        do {
            try await SocialAPI.shared.empty("lazyer/mobile/social/comments/\(comment.id)", method: "DELETE")
            comments.removeAll { $0.id == comment.id }; await SocialFeedStore.shared.refresh(scene.id)
        } catch { self.error = error.localizedDescription }
    }
    private func load(reset: Bool) async {
        guard reset || !loading else { return }
        if reset { generation = UUID() }
        let currentGeneration = generation
        loading = true
        defer { if currentGeneration == generation { loading = false } }
        do {
            let cursor = reset ? "" : nextCursor.map { "&before=\($0)" } ?? ""
            let page: SocialPage<SceneComment> = try await SocialAPI.shared.request("lazyer/mobile/social/feed/\(scene.id)/comments?limit=20\(cursor)")
            guard currentGeneration == generation else { return }
            let known = Set(comments.map(\.id))
            comments = reset ? page.items : comments + page.items.filter { !known.contains($0.id) }
            nextCursor = page.nextCursor; error = nil
        } catch { if currentGeneration == generation { self.error = error.localizedDescription } }
    }
}

struct SocialAvatar: View {
    let url: String?
    let name: String
    var size: CGFloat = 46
    var body: some View {
        Group {
            if let url, url.hasPrefix("preview://"), SocialAPI.usesLocalPreview {
                GeometryReader { geometry in
                    let index = ["Alex", "Emma", "David", "Sophia", "Lucas", "Olivia", "Jack"].firstIndex(of: name) ?? 1
                    let rect = name == "我" ? CGRect(x: 37, y: 868, width: 73, height: 73) : CGRect(x: 932, y: 175 + index * 55, width: 37, height: 37)
                    let scale = geometry.size.width / rect.width
                    Image("ChallengeReference").resizable().frame(width: 1199 * scale, height: 1312 * scale).offset(x: -rect.minX * scale, y: -rect.minY * scale)
                }.frame(width: size, height: size).clipShape(Circle()).allowsHitTesting(false)
            } else {
        AsyncImage(url: URL(string: SocialAPI.mediaURL(url))) { image in image.resizable().scaledToFill() }
        placeholder: { Text(String(name.prefix(1))).font(.system(size: size * 0.4, weight: .semibold)).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.pink.opacity(0.12)) }
            .frame(width: size, height: size).clipShape(Circle())
            }
        }
    }
}


struct WechatLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: WechatLoginSession?
    @State private var creating = false
    @State private var finished = false
    @State private var terminal = false
    @State private var error: String?
    @State private var status = "正在获取微信登录码…"
    @State private var retry = 0
    private var qrImage: UIImage? {
        guard let encoded = session?.qrImageBase64, let data = Data(base64Encoded: encoded) else { return nil }
        return UIImage(data: data)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 44)).foregroundStyle(.green)
                    Text("使用微信小程序账号登录").font(.title3.bold())
                    Text("在小程序中核对确认码并点击确认，返回 App 后继续刚才的操作。")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if creating { ProgressView() }
                    if let qrImage {
                        Image(uiImage: qrImage).interpolation(.none).resizable().scaledToFit().frame(width: 230, height: 230)
                            .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 18))
                    }
                    if let session {
                        Text("确认码  \(session.confirmationCode)").font(.title2.monospaced().bold())
                        Text("请核对小程序中显示的确认码").font(.caption).foregroundStyle(.secondary)
                        if let link = session.miniProgramUrl, let url = URL(string: link), url.scheme == "https", !terminal {
                            Button("打开微信小程序") { openURL(url) }.buttonStyle(.borderedProminent).tint(.green)
                        }
                        if let qrImage, !terminal {
                            ShareLink(item: Image(uiImage: qrImage), preview: SharePreview("微信小程序登录码", image: Image(uiImage: qrImage))) {
                                Label("保存或分享登录码", systemImage: "square.and.arrow.up")
                            }
                            Text("也可用另一台设备的微信扫一扫；本机可保存图片后在微信扫一扫中从相册识别。")
                                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                    }
                    Text(status).font(.subheadline).foregroundStyle(.secondary)
                    if let error {
                        Text(error).font(.subheadline).foregroundStyle(.red).multilineTextAlignment(.center)
                        if session != nil && !terminal { Button("重新检查授权状态") { self.error = nil; retry += 1 } }
                    }
                    Button(session == nil ? "重新获取登录码" : "刷新登录码") { Task { await create() } }.disabled(creating)
                }.padding(28).frame(maxWidth: .infinity)
            }.background(Color(.systemGroupedBackground))
                .navigationTitle("微信登录").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } } }
        }.preferredColorScheme(.light)
        .task { if session == nil { await create() } }
        .task(id: "\(session?.sessionId ?? "")-\(scenePhase)-\(retry)") {
            guard scenePhase == .active, let session, !terminal else { return }
            while !Task.isCancelled {
                if Date().timeIntervalSince1970 * 1000 >= Double(session.expiresAt) { terminal = true; status = "登录码已过期，请刷新"; break }
                do {
                    let response = try await SocialAPI.shared.wechatStatus(session)
                    switch response.status {
                    case "CONFIRMED", "CONSUMED":
                        status = "正在登录…"
                        try await SocialAPI.shared.completeWechatLogin(session)
                        finished = true; dismiss(); return
                    case "EXPIRED": terminal = true; status = "登录码已过期，请刷新"; return
                    case "REJECTED": terminal = true; status = "已取消授权，可刷新登录码重试"; return
                    case "SCANNED": status = "已打开小程序，请确认登录"
                    default: status = "等待微信小程序确认…"
                    }
                    try await Task.sleep(for: .seconds(2))
                } catch is CancellationError { return }
                catch {
                    if Task.isCancelled { return }
                    self.error = error.localizedDescription; return
                }
            }
        }
        .onDisappear {
            guard !finished, let session else { return }
            Task { await SocialAPI.shared.cancelWechatLogin(session) }
        }
    }
    private func create() async {
        guard !creating else { return }
        creating = true; error = nil; terminal = true; status = "正在获取微信登录码…"
        let previous = session
        session = nil
        defer { creating = false }
        if let previous { await SocialAPI.shared.cancelWechatLogin(previous) }
        do {
            let result = try await SocialAPI.shared.createWechatLogin()
            guard Data(base64Encoded: result.qrImageBase64).flatMap({ UIImage(data: $0) }) != nil else {
                throw SocialError.message("登录码图片无效，请重试")
            }
            terminal = false; session = result; status = "等待微信小程序确认…"
        } catch { self.error = error.localizedDescription; status = "暂时无法获取微信登录码" }
    }
}
