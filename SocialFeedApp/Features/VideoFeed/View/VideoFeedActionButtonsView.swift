import SwiftUI

struct VideoFeedActionButtonsView: View {
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    let video: UI.Feed.Video
    @Binding var interaction: Bool
    init(video: UI.Feed.Video, interaction: Binding<Bool> = .constant(false)) { self.video = video; self._interaction = interaction }
    @State private var busy = false
    @State private var comments = false
    @State private var login = false
    @State private var pendingDislike: Bool?
    @State private var pendingValue: Bool?
    @State private var error: String?
    private var scene: SceneFeed? { SocialFeedStore.shared.items.first(where: { $0.id == video.scene?.id }) ?? video.scene }
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Button { react(dislike: false) } label: {
                    Image(systemName: scene?.liked == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.title2).foregroundColor(.white).scaleEffect(scene?.liked == true ? 1.2 : 1.0)
                }.disabled(busy).accessibilityLabel("Like").accessibilityValue(scene?.liked == true ? "已点赞" : "未点赞")
                Text("\(scene?.likes ?? video.likes)").font(.caption).foregroundColor(.white)
            }
            VStack(spacing: 4) {
                Button { react(dislike: true) } label: {
                    Image(systemName: scene?.disliked == true ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .font(.title2).foregroundColor(.white).scaleEffect(scene?.disliked == true ? 1.2 : 1.0)
                }.disabled(busy).accessibilityLabel("Dislike").accessibilityValue(scene?.disliked == true ? "不喜欢" : "未选择")
                Text("\(scene?.dislikes ?? 0)").font(.caption).foregroundColor(.white)
            }
            VStack(spacing: 4) {
                Button {
                    impactFeedback.impactOccurred()
                    if scene?.preview == true { error = "当前为本地预览，连接后端后可查看和发布评论。" }
                    else { comments = true }
                } label: {
                    Image(systemName: "message").font(.title2).foregroundColor(.white)
                }.accessibilityLabel("Message").accessibilityValue("\(scene?.comments ?? video.comments) 条评论")
                Text("\(scene?.comments ?? video.comments)").font(.caption).foregroundColor(.white)
            }
        }
        .onChange(of: comments) { _, _ in interaction = comments || login }
        .onChange(of: login) { _, _ in interaction = comments || login }
        .sheet(isPresented: $comments) { if let scene { SceneCommentsView(scene: scene) } }
        .sheet(isPresented: $login, onDismiss: {
            let pending = pendingDislike
            let value = pendingValue
            pendingDislike = nil; pendingValue = nil
            if SocialAPI.shared.isLoggedIn, let pending { react(dislike: pending, desired: value) }
        }) { SocialLoginView(reason: "登录后可点赞并保存你的互动记录。") }
        .alert("操作未完成", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("知道了") { error = nil } } message: { Text(error ?? "") }
    }
    private func react(dislike: Bool, desired: Bool? = nil) {
        guard let scene else { return }
        let value = desired ?? !(dislike ? (scene.disliked ?? false) : scene.liked)
        if scene.preview != true && !SocialAPI.shared.isLoggedIn { pendingDislike = dislike; pendingValue = value; login = true; return }
        busy = true
        Task {
            defer { busy = false }
            do {
                if dislike { try await SocialFeedStore.shared.dislike(scene, desired: value) } else { try await SocialFeedStore.shared.like(scene, desired: value) }
                impactFeedback.impactOccurred()
            } catch { self.error = error.localizedDescription }
        }
    }
}
