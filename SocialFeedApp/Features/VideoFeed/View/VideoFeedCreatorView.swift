import SwiftUI

struct VideoFeedCreatorView: View {
    let creator: UI.Feed.Video.Creator
    var foregroundColor: Color = .white
    var scene: SceneFeed? = nil
    @Binding var interaction: Bool
    init(creator: UI.Feed.Video.Creator, foregroundColor: Color = .white, scene: SceneFeed? = nil, interaction: Binding<Bool> = .constant(false)) {
        self.creator = creator; self.foregroundColor = foregroundColor; self.scene = scene; self._interaction = interaction
    }
    @State private var busy = false
    @State private var login = false
    @State private var pendingFollow: Bool?
    @State private var error: String?
    private var current: SceneFeed? { SocialFeedStore.shared.items.first { $0.id == scene?.id } ?? scene }
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: creator.avatarURL)) { image in image.resizable().aspectRatio(contentMode: .fill) }
            placeholder: { Circle().fill(Color.gray.opacity(0.3)) }
                .frame(width: 40, height: 40).clipShape(Circle())
            Text(creator.name).font(.headline).foregroundColor(foregroundColor)
            Spacer()
            if current?.preview == true || (current?.creatorUid != nil && current?.creatorUid != SocialAPI.shared.person?.uid) {
                Button { follow() } label: {
                    HStack(spacing: 4) {
                        Text(current?.followed == true ? "Following" : "Follow").font(.caption).fontWeight(.semibold)
                        Image(systemName: current?.followed == true ? "checkmark" : "plus").font(.caption)
                    }.foregroundStyle(foregroundColor).padding(.horizontal, 12).padding(.vertical, 5)
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(foregroundColor, lineWidth: 1))
                }.disabled(busy).accessibilityLabel(current?.followed == true ? "取消关注" : "关注")
            }
        }
        .onChange(of: login) { _, value in interaction = value }
        .sheet(isPresented: $login, onDismiss: {
            let desired = pendingFollow
            pendingFollow = nil
            if SocialAPI.shared.isLoggedIn, let desired { follow(desired: desired) }
        }) { SocialLoginView(reason: "登录后可关注作者，保存关注关系。") }
        .alert("操作未完成", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("知道了") { error = nil } } message: { Text(error ?? "") }
    }
    private func follow(desired: Bool? = nil) {
        guard !busy, let scene = current else { return }
        let value = desired ?? !(scene.followed ?? false)
        guard scene.preview == true || SocialAPI.shared.isLoggedIn else { pendingFollow = value; login = true; return }
        busy = true
        Task {
            defer { busy = false }
            do { try await SocialFeedStore.shared.follow(scene, desired: value) }
            catch { self.error = error.localizedDescription }
        }
    }
}
