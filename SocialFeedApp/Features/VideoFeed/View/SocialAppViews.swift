import SwiftUI

@MainActor @Observable
final class SocialFeedStore {
    static let shared = SocialFeedStore()
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
            let page = try await SocialAPI.shared.feed(before: reset ? nil : nextCursor)
            let known = Set(items.map(\.id))
            items.append(contentsOf: page.items.filter { !known.contains($0.id) })
            nextCursor = page.nextCursor
        } catch { self.error = error.localizedDescription }
    }
    func refresh(_ id: Int) async {
        do {
            let updated: SceneFeed = try await SocialAPI.shared.request("lazyer/mobile/social/feed/\(id)")
            if let index = items.firstIndex(where: { $0.id == id }) { items[index] = updated }
        } catch { self.error = error.localizedDescription }
    }
    func like(_ scene: SceneFeed) async throws {
        let current = items.first(where: { $0.id == scene.id }) ?? scene
        if scene.preview == true {
            if let index = items.firstIndex(where: { $0.id == scene.id }) { items[index].liked.toggle(); items[index].disliked = false }
            return
        }
        let response: LikeResponse = try await SocialAPI.shared.request("lazyer/mobile/social/feed/\(scene.id)/like", method: current.liked ? "DELETE" : "PUT")
        if let index = items.firstIndex(where: { $0.id == scene.id }) { items[index].liked = response.liked; items[index].likes = response.likes; items[index].disliked = response.disliked; items[index].dislikes = response.dislikes }
    }
    func dislike(_ scene: SceneFeed) async throws {
        let current = items.first(where: { $0.id == scene.id }) ?? scene
        if scene.preview == true {
            if let index = items.firstIndex(where: { $0.id == scene.id }) { items[index].disliked = !(items[index].disliked ?? false); items[index].liked = false }
            return
        }
        let response: LikeResponse = try await SocialAPI.shared.request("lazyer/mobile/social/feed/\(scene.id)/dislike", method: current.disliked == true ? "DELETE" : "PUT")
        if let index = items.firstIndex(where: { $0.id == scene.id }) {
            items[index].liked = response.liked; items[index].likes = response.likes
            items[index].disliked = response.disliked; items[index].dislikes = response.dislikes
        }
    }

}

struct SocialSettingsView: View {
    var embedded = false
    @Environment(\.dismiss) private var dismiss
    @State private var api = SocialAPI.shared
    @State private var address = SocialAPI.shared.baseURL
    @State private var phone = ""
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("本地后端") {
                    TextField("http://127.0.0.1:9080/oneCode", text: $address).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    Text("模拟器可用 127.0.0.1；真机请填写电脑的局域网地址。正式环境请使用 HTTPS。").font(.caption).foregroundStyle(.secondary)
                    Button("保存地址") { do { try api.configure(address); message = "后端地址已保存" } catch { message = error.localizedDescription } }
                }
                if api.isLoggedIn {
                    Section("当前账号") {
                        Text(api.person?.name ?? "已登录")
                        if let uid = api.person?.uid { Text("用户 ID：\(uid)") }
                        Button("退出登录", role: .destructive) { api.logout() }
                    }
                } else {
                    Section("手机号登录") {
                        TextField("手机号", text: $phone).textContentType(.username).keyboardType(.phonePad)
                        SecureField("密码", text: $password).textContentType(.password)
                        Button(busy ? "登录中…" : "登录") {
                            busy = true; message = nil
                            Task {
                                defer { busy = false }
                                do { try api.configure(address); try await api.login(phone: phone, password: password); password = ""; message = "登录成功" }
                                catch { message = error.localizedDescription }
                            }
                        }.disabled(busy || phone.isEmpty || password.isEmpty)
                    }
                }
                if let message { Section { Text(message).font(.subheadline) } }
            }.navigationTitle("我的账号").navigationBarTitleDisplayMode(.inline)
                .toolbar { if !embedded { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } } }
        }.preferredColorScheme(.light)
            .task { do { try await api.restore() } catch { message = error.localizedDescription } }
    }
}

struct SceneCommentsView: View {
    let scene: SceneFeed
    @State private var comments: [SceneComment] = []
    @State private var nextCursor: Int64?
    @State private var bodyText = ""
    @State private var busy = false
    @State private var error: String?
    @State private var requestId = UUID().uuidString
    @State private var login = false
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
                    }.swipeActions { if comment.uid == SocialAPI.shared.person?.uid {
                        Button("删除", role: .destructive) { Task {
                            do { try await SocialAPI.shared.empty("lazyer/mobile/social/comments/\(comment.id)", method: "DELETE"); await load(reset: true); await SocialFeedStore.shared.refresh(scene.id) }
                            catch { self.error = error.localizedDescription }
                        } }
                    } }
                }
                if comments.isEmpty && !busy { Text("还没有评论，聊聊你的练习心得吧").foregroundStyle(.secondary) }
                if nextCursor != nil { Button("加载更多") { Task { await load(reset: false) } } }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(alignment: .bottom) {
                    TextField("写下评论…", text: $bodyText, axis: .vertical).lineLimit(1...4).padding(12).background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
                    Button("发送") {
                        guard SocialAPI.shared.isLoggedIn else { login = true; return }
                        busy = true
                        Task {
                            defer { busy = false }
                            do {
                                let _: SceneComment = try await SocialAPI.shared.request("lazyer/mobile/social/feed/\(scene.id)/comments", method: "POST", body: ["body": bodyText, "requestId": requestId])
                                bodyText = ""; requestId = UUID().uuidString
                                await load(reset: true); await SocialFeedStore.shared.refresh(scene.id)
                            } catch { self.error = error.localizedDescription }
                        }
                    }.disabled(busy || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bodyText.count > 500)
                }.padding(16).background(.white)
            }
            .navigationTitle("评论").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }.preferredColorScheme(.light).task { await load(reset: true) }.sheet(isPresented: $login) { SocialSettingsView() }
            .onChange(of: bodyText) { _, _ in requestId = UUID().uuidString }
    }
    private func load(reset: Bool) async {
        do {
            let cursor = reset ? "" : nextCursor.map { "&before=\($0)" } ?? ""
            let page: SocialPage<SceneComment> = try await SocialAPI.shared.request("lazyer/mobile/social/feed/\(scene.id)/comments?limit=20\(cursor)")
            comments = reset ? page.items : comments + page.items; nextCursor = page.nextCursor; error = nil
        } catch { self.error = error.localizedDescription }
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

