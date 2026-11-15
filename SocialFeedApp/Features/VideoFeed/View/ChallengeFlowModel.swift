import SwiftUI
import AVFoundation

@MainActor @Observable
final class ChallengeFlowModel {
    enum Step: Equatable { case detail, modes, friends, waiting, practice, result, report }
    let scene: SceneFeed?
    private let api: SocialAPI
    private var pendingMode: String?
    var step: Step = .detail
    var mode = "单人练习"
    var lines: [DialogueLine] = []
    var friends: [SocialPerson] = []
    var selectedFriend: Int?
    var room: PkRoom?
    var practice: PracticeSession?
    var busy = false
    var error: String?
    var login = false
    var recording = false
    var pendingAudio: URL?
    private var recordingLine: Int?
    private var duration: Double = 0
    private var requestId = UUID().uuidString
    private var recorder: AVAudioRecorder?
    private var player: AVPlayer?
    private var timer: Task<Void, Never>?
    private let speech = AVSpeechSynthesizer()
    var previewTurn = 0
    var previewAnswerVisible = false
    var isPreview: Bool { SocialAPI.usesLocalPreview && scene?.preview == true }
    var myAvatar: String? { isPreview ? "preview://我" : api.person?.avatar }
    var uid: Int? { isPreview ? 101 : api.person?.uid }
    var isHost: Bool { room?.inviterUid == uid }
    var isMyTurn: Bool { isPreview || room == nil || (room?.status == 1 && room?.currentUid == uid) }
    var currentLine: DialogueLine? {
        if isPreview { return lines.indices.contains(previewTurn) ? lines[previewTurn] : nil }
        if let room { return room.lines?.first(where: { $0.contentOrder == room.currentContentOrder })?.line }
        return practice?.lines.first(where: { $0.score == nil }) ?? lines.first
    }
    var currentIndex: Int { lines.firstIndex(where: { $0.contentId == currentLine?.contentId }) ?? 0 }
    var opponentName: String { isHost ? room?.inviteeName ?? "等待好友加入" : room?.inviterName ?? "好友" }
    var opponentAvatar: String? { isHost ? room?.inviteeAvatar : room?.inviterAvatar }
    var ownScore: Double? { if isPreview { return 92 }; if let room { return isHost ? room.inviterScore : room.inviteeScore }; return practice?.score }
    var otherScore: Double? { isHost ? room?.inviteeScore : room?.inviterScore }
    var ownLines: [DialogueLine] {
        if isPreview { return LocalDialoguePreview.lines }
        if let room { return (room.lines ?? []).filter { $0.submittedUid == uid }.map(\.line) }
        return practice?.lines ?? []
    }
    var fluency: Double? {
        let values = ownLines.compactMap(\.fluency)
        return values.isEmpty ? nil : Double(values.reduce(0, +)) / Double(values.count)
    }
    var resultTitle: String {
        guard let room else { return "练习完成！" }
        if room.winnerUid == 0 { return "势均力敌！" }
        return room.winnerUid == uid ? "你赢了！" : "继续加油！"
    }
    init(scene: SceneFeed?, room: PkRoom? = nil, api: SocialAPI? = nil) {
        self.api = api ?? SocialAPI.shared
        self.scene = scene; self.room = room
        if let room { mode = "好友 PK"; step = room.status == 2 ? .result : room.status == 1 ? .practice : .waiting; lines = (room.lines ?? []).map(\.line) }
    }
    func load() async {
        if isPreview { lines = LocalDialoguePreview.lines; return }
        guard let scene else { error = "该内容未关联后端情景"; return }
        await run {
            if api.isLoggedIn { try await api.restore() }
            self.lines = try await api.request("lazyer/mobile/social/feed/\(scene.id)/lines")
        }
    }
    func run(_ operation: () async throws -> Void) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do { try await operation() } catch { self.error = error.localizedDescription }
    }
    func requireLogin() -> Bool {
        if isPreview { return true }
        if !api.isLoggedIn { login = true; return false }; return true
    }
    func selectMode(_ mode: String) async {
        if isPreview {
            self.mode = mode; previewTurn = 0; previewAnswerVisible = false
            if mode == "好友 PK" { friends = LocalDialoguePreview.friends; selectedFriend = friends.first?.uid; step = .friends }
            else if mode == "单人练习" { room = nil; step = .practice }
            else { room = LocalDialoguePreview.room(friend: nil, status: 7); step = .waiting }
            return
        }
        guard let scene else { return }
        guard requireLogin() else { pendingMode = mode; return }
        pendingMode = nil
        self.mode = mode
        await run {
            try await api.restore()
            switch mode {
            case "单人练习":
                self.room = nil
                self.practice = try await api.request("lazyer/mobile/social/feed/\(scene.id)/practice", method: "POST")
                self.lines = self.practice?.lines ?? []; self.step = .practice
            case "好友 PK":
                self.friends = try await api.request("lazyer/mobile/social/friends")
                self.selectedFriend = self.friends.first?.uid; self.step = .friends
            default:
                let result: PkRoom = try await api.request("lazyer/mobile/social/feed/\(scene.id)/random-rooms", method: "POST")
                self.apply(result); self.step = result.status == 1 ? .practice : .waiting
            }
        }
    }
    func resumeAfterLogin() async {
        let selectedMode = pendingMode
        pendingMode = nil
        guard api.isLoggedIn, let selectedMode else { return }
        await selectMode(selectedMode)
    }
    func invite() async {
        if isPreview { room = LocalDialoguePreview.room(friend: friends.first { $0.uid == selectedFriend }, status: 7); step = .waiting; return }
        guard let selectedFriend, let scene else { return }
        await run {
            let room: PkRoom = try await api.request("lazyer/mobile/social/feed/\(scene.id)/rooms", method: "POST", body: ["friendUid": selectedFriend])
            self.apply(room); self.step = .waiting
        }
    }
    func startRoom() async {
        if isPreview { room = LocalDialoguePreview.room(friend: friends.first { $0.uid == selectedFriend }, status: 1); step = .practice; return }
        guard let room else { return }
        await run {
            let updated: PkRoom = try await api.request("lazyer/mobile/social/rooms/\(room.id)/start", method: "POST")
            self.apply(updated)
        }
    }
    func poll() async {
        if isPreview { return }
        guard let room, !busy, !recording, !room.terminal else { return }
        do {
            let updated: PkRoom = try await api.request("lazyer/mobile/social/rooms/\(room.id)")
            apply(updated)
            if mode == "随机匹配", updated.status == 7, isHost { await startRoom() }
        } catch { self.error = error.localizedDescription }
    }
    private func apply(_ room: PkRoom) {
        self.room = room
        lines = (room.lines ?? []).map(\.line)
        if room.status == 1 { step = .practice }
        else if room.status == 2 { step = .result }
        else if room.terminal { error = room.statusName ?? "对局已结束" }
    }
    func speak() {
        guard let line = currentLine else { return }
        stopPlayback()
        if let path = line.referenceVoiceUrl, !path.isEmpty, let url = URL(string: SocialAPI.mediaURL(path)) {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            player = AVPlayer(url: url); player?.play()
        } else {
            let utterance = AVSpeechUtterance(string: line.en); utterance.voice = AVSpeechSynthesisVoice(language: "en-US"); speech.speak(utterance)
        }
    }
    func toggleRecording() async {
        if recording { finishRecording(); return }
        guard isMyTurn, let line = currentLine, !busy else { return }
        stopPlayback()
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { error = "请在系统设置中允许麦克风权限"; return }
        do {
            discardAudio()
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audio.setActive(true)
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("dialogue-\(UUID().uuidString).wav")
            let recorder = try AVAudioRecorder(url: file, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsFloatKey: false])
            self.recorder = recorder; recordingLine = line.contentId
            guard recorder.record() else { throw SocialError.message("无法开始录音") }
            pendingAudio = file; requestId = UUID().uuidString; recording = true
            timer = Task { do { try await Task.sleep(for: .seconds(60)); if self.recording { self.finishRecording() } } catch { } }
        } catch { self.error = error.localizedDescription; discardAudio() }
    }
    func finishRecording() {
        duration = recorder?.currentTime ?? 0
        recorder?.stop(); recorder = nil; recording = false; timer?.cancel(); timer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if duration < 0.3 { discardAudio(); error = "录音太短，请重新录制" }
    }
    func submit() async {
        guard let audio = pendingAudio, let line = recordingLine, !recording else { return }
        await run {
            if let room = self.room {
                let updated: PkRoom = try await api.upload("lazyer/mobile/social/rooms/\(room.id)/voices", line: line, requestId: self.requestId, url: audio, duration: self.duration)
                self.apply(updated)
            } else if let practice = self.practice {
                let updated: PracticeSession = try await api.upload("lazyer/mobile/social/practice/\(practice.id)/voices", line: line, requestId: self.requestId, url: audio, duration: self.duration)
                self.practice = updated; self.lines = updated.lines
                if updated.finished { self.step = .result }
            }
            self.discardAudio()
        }
    }
    func discardAudio() {
        recorder?.stop(); recorder = nil; recording = false; timer?.cancel(); timer = nil
        if let pendingAudio { try? FileManager.default.removeItem(at: pendingAudio) }
        pendingAudio = nil; recordingLine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func stopPlayback() { player?.pause(); player = nil; speech.stopSpeaking(at: .immediate) }
    func leave() async -> Bool {
        stopPlayback(); discardAudio()
        if isPreview { room = nil; return true }
        guard let room, !room.terminal else { return true }
        do { let _: PkRoom = try await api.request("lazyer/mobile/social/rooms/\(room.id)/leave", method: "POST"); self.room = nil; return true }
        catch { self.error = error.localizedDescription; return false }
    }
    func replay() async {
        discardAudio()
        if isPreview {
            previewTurn = 0; previewAnswerVisible = false
            if room == nil { step = .practice } else { await invite() }
            return
        }
        if room == nil { await selectMode("单人练习") }
        else {
            selectedFriend = isHost ? room?.inviteeUid : room?.inviterUid
            await invite()
        }
    }
    func nextPreviewLine() {
        if previewTurn == LocalDialoguePreview.lines.count - 1 { step = .result }
        else { previewTurn += 1; previewAnswerVisible = false }
    }

}
