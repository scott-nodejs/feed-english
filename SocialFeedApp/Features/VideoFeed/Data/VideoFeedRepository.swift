import Foundation

protocol VideoFeedRepositoryType {
    func fetchVideos() async throws -> [Domain.Feed.Video]
    func resetPagination() async
}
extension VideoFeedRepositoryType {
    func resetPagination() async { }
}

/// Replaces the local JSON source while keeping the original feed/view hierarchy intact.
@Observable
final class VideoFeedRepository {
    private let api: SocialAPI?
    init(api: SocialAPI? = nil) { self.api = api }
    private var cursor: Int64?
    private var hasLoaded = false
}

extension VideoFeedRepository: VideoFeedRepositoryType {
    @MainActor func resetPagination() async { cursor = nil; hasLoaded = false; SocialFeedStore.shared.items = [] }
    @MainActor func fetchVideos() async throws -> [Domain.Feed.Video] {
        guard !hasLoaded || cursor != nil else { return [] }
        if api == nil && SocialAPI.usesLocalPreview {
            let response: API.Feed.Response = try JSONReader().load("videos")
            hasLoaded = true; cursor = nil
            return response.normalize().enumerated().map { index, original in
                let url = original.shortVideoURL.replacingOccurrences(of: "http://", with: "https://")
                let scene = SceneFeed(id: -(index + 1), dialogueId: -1, title: "咖啡店 · 点咖啡", description: "学习在咖啡店点单的常用表达，练习自然开口。", videoUrl: url,
                    coverUrl: nil, category: "日常生活", level: 1, creatorUid: nil, creatorName: original.creator.name,
                    creatorAvatar: original.creator.avatarURL, sentenceCount: 8, likes: original.likes, comments: original.comments,
                    liked: false, dislikes: 0, disliked: false, preview: true)
                SocialFeedStore.shared.items.append(scene)
                return Domain.Feed.Video(id: original.id, creator: original.creator, shortVideoURL: url,
                    fullVideoURL: original.fullVideoURL.replacingOccurrences(of: "http://", with: "https://"),
                    description: original.description, likes: original.likes, comments: original.comments, scene: scene)
            }
        }
        let page = try await (api ?? SocialAPI.shared).feed(before: cursor)
        cursor = page.nextCursor; hasLoaded = true
        let known = Set(SocialFeedStore.shared.items.map(\.id))
        SocialFeedStore.shared.items.append(contentsOf: page.items.filter { !known.contains($0.id) })
        return page.items.map { scene in
            Domain.Feed.Video(id: String(scene.id),
                creator: .init(id: scene.creatorUid.map(String.init) ?? "yiner", name: scene.creatorName, avatarURL: SocialAPI.mediaURL(scene.creatorAvatar)),
                shortVideoURL: SocialAPI.mediaURL(scene.videoUrl), fullVideoURL: SocialAPI.mediaURL(scene.videoUrl),
                description: scene.description ?? scene.title, likes: scene.likes, comments: scene.comments, scene: scene)
        }
    }
}
