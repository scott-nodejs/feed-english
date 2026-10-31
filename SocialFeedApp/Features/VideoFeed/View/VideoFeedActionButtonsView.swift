import SwiftUI

struct VideoFeedActionButtonsView: View {
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    let video: UI.Feed.Video
    @State private var busy = false
    @State private var comments = false
    @State private var login = false
    @State private var error: String?
    private var scene: SceneFeed? { SocialFeedStore.shared.items.first(where: { $0.id == video.scene?.id }) ?? video.scene }
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Button { react(dislike: false) } label: {
                    Image(systemName: scene?.liked == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.title2).foregroundColor(.white).scaleEffect(scene?.liked == true ? 1.2 : 1.0)
                }.disabled(busy).accessibilityLabel("Like")
                Text("\(scene?.likes ?? video.likes)").font(.caption).foregroundColor(.white)
            }
            VStack(spacing: 4) {
                Button { react(dislike: true) } label: {
                    Image(systemName: scene?.disliked == true ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .font(.title2).foregroundColor(.white).scaleEffect(scene?.disliked == true ? 1.2 : 1.0)
                }.disabled(busy).accessibilityLabel("Dislike")
                Text("\(scene?.dislikes ?? 0)").font(.caption).foregroundColor(.white)
            }
            VStack(spacing: 4) {
                Button {
                    impactFeedback.impactOccurred()
                    if scene?.preview == true { error = "当前为本地预览，连接后端后可查看和发布评论。" }
                    else { comments = true }
                } label: {
                    Image(systemName: "message").font(.title2).foregroundColor(.white)
                }.accessibilityLabel("Message")
                Text("\(scene?.comments ?? video.comments)").font(.caption).foregroundColor(.white)
            }
        }
        .sheet(isPresented: $comments) { if let scene { SceneCommentsView(scene: scene) } }
        .sheet(isPresented: $login) { SocialSettingsView() }
        .alert("操作未完成", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("知道了") { error = nil } } message: { Text(error ?? "") }
    }
    private func react(dislike: Bool) {
        guard let scene else { return }
        if scene.preview != true && !SocialAPI.shared.isLoggedIn { login = true; return }
        busy = true
        Task {
            defer { busy = false }
            do {
                if dislike { try await SocialFeedStore.shared.dislike(scene) } else { try await SocialFeedStore.shared.like(scene) }
                impactFeedback.impactOccurred()
            } catch { self.error = error.localizedDescription }
        }
    }
}
