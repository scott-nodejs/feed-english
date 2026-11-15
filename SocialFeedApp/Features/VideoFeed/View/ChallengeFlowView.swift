import SwiftUI

struct ChallengeFlowView: View {
    let video: UI.Feed.Video
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: ChallengeFlowModel
    @State private var detailTab = 0
    @State private var reportTab = 0
    @State private var search = ""
    @State private var showComments = false
    @State private var showExit = false
    private let pink = Color(red: 1, green: 0.18, blue: 0.46)
    private let ink = Color(red: 0.08, green: 0.10, blue: 0.16)
    private let muted = Color(red: 0.49, green: 0.51, blue: 0.57)
    private let surface = Color(red: 0.965, green: 0.967, blue: 0.98)
    private let green = Color(red: 0.04, green: 0.79, blue: 0.54)
    private var scene: SceneFeed? { SocialFeedStore.shared.items.first(where: { $0.id == video.scene?.id }) ?? video.scene }
    private var title: String { scene?.title ?? "情景对话" }

    init(video: UI.Feed.Video, initialRoom: PkRoom? = nil) {
        self.video = video
        _model = State(initialValue: ChallengeFlowModel(scene: video.scene, room: initialRoom))
    }
    var body: some View {
        VStack(spacing: 0) {
            switch model.step {
            case .detail: detail
            case .modes: modes
            case .friends: friendPicker
            case .waiting: waiting
            case .practice: practice
            case .result: result
            case .report: report
            }
        }
        .foregroundStyle(ink).background(.white).preferredColorScheme(.light)
        .overlay { if model.busy { ProgressView("正在处理…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18)) } }
        .task { await model.load() }
        .task(id: "\(model.room?.id ?? 0)-\(scenePhase)") {
            guard scenePhase == .active, model.room != nil, !model.isPreview else { return }
            while !Task.isCancelled {
                await model.poll()
                do { try await Task.sleep(for: .seconds(2)) } catch { break }
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.stopPlayback(); if model.recording { model.finishRecording() } } }
        .onDisappear { model.stopPlayback(); model.discardAudio() }
        .sheet(isPresented: $model.login, onDismiss: { Task { await model.resumeAfterLogin() } }) {
            SocialLoginView(reason: "登录后可保存练习记录、查看学习报告和参与 PK。")
        }
        .sheet(isPresented: $showComments) { if let scene { SceneCommentsView(scene: scene) } }
        .alert("操作未完成", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("知道了") { model.error = nil } } message: { Text(model.error ?? "") }
        .confirmationDialog("退出当前挑战？", isPresented: $showExit, titleVisibility: .visible) {
            Button("退出挑战", role: .destructive) { Task { if await model.leave() { dismiss() } } }
        } message: { Text(model.room == nil ? "本次已提交的练习记录已保存。" : "退出后，本场未完成的 PK 将结束。") }
    }

    private func back() {
        guard !model.busy else { return }
        model.stopPlayback()
        switch model.step {
        case .detail: dismiss()
        case .modes: model.step = .detail
        case .friends: model.step = .modes
        case .report: model.step = .result
        case .waiting, .practice: showExit = true
        case .result: dismiss()
        }
    }
    private func header(_ text: String) -> some View {
        HStack {
            Button(action: back) { Image(systemName: "chevron.left").font(.system(size: 21, weight: .medium)).frame(width: 44, height: 44) }.accessibilityLabel("返回")
            Spacer(); Text(text).font(.system(size: 18, weight: .semibold)); Spacer()
            Color.clear.frame(width: 44, height: 44)
        }.padding(.horizontal, 12).padding(.bottom, 8)
    }
    private func screen<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            header(title)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24, content: content).padding(.horizontal, 24).padding(.vertical, 20)
                    .frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
        }
    }
    private var poster: some View {
        GeometryReader { geometry in
            if model.isPreview {
                let scale = max(geometry.size.width / 280, geometry.size.height / 230)
                Image("ChallengeReference").resizable().frame(width: 1199 * scale, height: 1312 * scale)
                    .offset(x: -313 * scale - (280 * scale - geometry.size.width) / 2,
                            y: -772 * scale - (230 * scale - geometry.size.height) / 2)
            } else {
            AsyncImage(url: URL(string: SocialAPI.mediaURL(scene?.coverUrl))) { image in
                image.resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
            } placeholder: { ZStack { surface; Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 48)).foregroundStyle(pink.opacity(0.5)) }.frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
        }.clipped().allowsHitTesting(false)
    }
    private var detail: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    poster.frame(height: geometry.size.height * 0.35)
                        .overlay(alignment: .topLeading) {
                            Button { dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 20)).foregroundStyle(.white).frame(width: 40, height: 40).background(.black.opacity(0.25), in: Circle()) }.disabled(model.busy).padding(20)
                        }
                    VStack(alignment: .leading, spacing: 20) {
                        Text(title).font(.system(size: 27, weight: .bold))
                        HStack(spacing: 10) { badge(scene?.category ?? "情景口语", color: muted); badge("Level \(scene?.level ?? 1)", color: .blue) }
                        HStack {
                            stat("text.bubble.fill", "\(model.lines.count)", "台词")
                            Button { Task { if model.requireLogin(), let scene { await model.run { try await SocialFeedStore.shared.like(scene) } } } } label: {
                                stat(scene?.liked == true ? "heart.fill" : "heart", "\(scene?.likes ?? 0)", "喜欢")
                            }.buttonStyle(.plain)
                            Button {
                                if model.isPreview { model.error = "当前为本地预览，连接后端后可查看和发布评论。" }
                                else { showComments = true }
                            } label: { stat("message.fill", "\(scene?.comments ?? 0)", "评论") }.buttonStyle(.plain)
                        }.padding(.vertical, 4)
                        tabs(["场景介绍", "对话示例", "相关场景"], selection: $detailTab)
                        if detailTab == 0 {
                            Text(scene?.description ?? "跟随情景台词，练习清晰、自然地表达。").font(.system(size: 15)).foregroundStyle(muted).lineSpacing(6)
                            HStack(spacing: 8) {
                                metric("clock.fill", "\(max(1, model.lines.count / 2)) 分钟", "预计时长", .blue)
                                metric("text.bubble.fill", "\(model.lines.count) 句话", "对话台词", green)
                                metric("checkmark.shield.fill", scene?.category ?? "口语", "适用场景", .orange)
                            }
                        } else if detailTab == 1 {
                            ForEach(model.lines.prefix(4)) { line in
                                VStack(alignment: .leading, spacing: 8) { Text(line.en).font(.subheadline.weight(.semibold)); Text(line.zh ?? "").font(.subheadline).foregroundStyle(muted) }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(surface, in: RoundedRectangle(cornerRadius: 14))
                            }
                        } else {
                            ForEach(SocialFeedStore.shared.items.filter { $0.id != scene?.id }.prefix(3)) { related in
                                HStack { Text(related.title).font(.subheadline.weight(.semibold)); Spacer(); Text("Level \(related.level)").font(.caption).foregroundStyle(muted) }.padding(16).background(surface, in: RoundedRectangle(cornerRadius: 14))
                            }
                            if SocialFeedStore.shared.items.count <= 1 { Text("暂无相关场景").foregroundStyle(muted) }
                        }
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)).padding(.top, -20)
                }
            }
            .safeAreaInset(edge: .bottom) { primary("开始挑战") { model.step = .modes }.disabled(model.lines.isEmpty).padding(.horizontal, 24).padding(.vertical, 12).background(.white) }
        }
    }
    private var modes: some View {
        screen("选择挑战模式") {
            sceneHeader.padding(.bottom, 8)
            modeCard("单人练习", "跟随情景台词，提升口语能力", "person.fill", .blue)
            modeCard("好友 PK", "邀请好友一起挑战，看看谁更强", "figure.fencing", .orange)
            modeCard("随机匹配", "匹配相同情景的在线练习伙伴", "person.3.fill", .purple)
            Text("PK 开局按现有规则消耗金币，准备阶段不扣费。").font(.caption).foregroundStyle(muted).padding(.top, 20)
        }
    }
    private var friendPicker: some View {
        screen("选择好友一起 PK") {
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(muted); TextField("搜索好友", text: $search).font(.system(size: 14)) }.padding(13).background(surface, in: RoundedRectangle(cornerRadius: 16))
            VStack(spacing: 0) {
                ForEach(model.friends.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { friend in
                    Button { model.selectedFriend = friend.uid } label: {
                        HStack(spacing: 14) {
                            SocialAvatar(url: friend.avatar, name: friend.name, size: 48)
                            VStack(alignment: .leading, spacing: 6) { Text(friend.name).font(.system(size: 16, weight: .semibold)); Text("ID：\(friend.uid)").font(.caption).foregroundStyle(muted) }
                            Spacer()
                            Image(systemName: model.selectedFriend == friend.uid ? "checkmark.circle.fill" : "circle").font(.system(size: 24)).foregroundStyle(model.selectedFriend == friend.uid ? pink : .gray.opacity(0.4))
                        }.padding(.vertical, 13).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider()
                }
                if model.friends.isEmpty { Text("还没有可邀请的好友。").font(.subheadline).foregroundStyle(muted).padding(.vertical, 30) }
            }
        }.safeAreaInset(edge: .bottom) { primary("发起 PK（\(model.selectedFriend == nil ? 0 : 1)）") { Task { await model.invite() } }.disabled(model.selectedFriend == nil || model.busy).padding(.horizontal, 24).padding(.vertical, 12).background(.white) }
    }
    private var waiting: some View {
        VStack(spacing: 0) {
            header(model.mode)
            Text(model.room?.dialogueTitle ?? title).font(.system(size: 20, weight: .bold)).padding(.top, 20)
            Text("Level \(scene?.level ?? 1) · \(scene?.category ?? "情景口语")").font(.system(size: 14)).foregroundStyle(muted).padding(.top, 10)
            Spacer(minLength: 28)
            HStack(spacing: 14) {
                contestant("我", avatar: model.myAvatar, color: .orange, ready: "已准备", crown: true)
                vsMark
                contestant(model.opponentName, avatar: model.opponentAvatar, color: .purple, ready: model.room?.inviteeUid == nil ? "等待加入…" : "已准备")
            }.padding(.horizontal, 24)
            Spacer(minLength: 28)
            VStack(alignment: .leading, spacing: 20) {
                readyRow("场景已准备", ready: true)
                readyRow("对话台词已就绪", ready: !model.lines.isEmpty)
                readyRow(model.room?.inviteeUid == nil ? "等待对方准备…" : "双方已准备", ready: model.room?.status == 7)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(24).background(surface, in: RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 36)
            Spacer(minLength: 28)
            if model.isHost {
                primary(model.room?.status == 7 ? "开始 PK" : "等待对方加入") { Task { await model.startRoom() } }.disabled(model.room?.status != 7 || model.busy).padding(.horizontal, 24)
            } else { Text("等待房主开始 PK…").font(.subheadline).foregroundStyle(muted) }
            Text("放松心态，自然表达就好！").font(.caption).foregroundStyle(muted).padding(.vertical, 24)
        }
    }
    private var practice: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack(spacing: 22) {
                    Button { showExit = true } label: { Image(systemName: "xmark").font(.title3) }.accessibilityLabel("退出练习")
                    VStack(spacing: 8) {
                        Text("\(min(model.currentIndex + 1, model.lines.count)) / \(model.lines.count)").font(.system(size: 14, weight: .semibold))
                        ProgressView(value: Double(model.currentIndex + 1), total: Double(max(1, model.lines.count))).tint(green)
                    }
                }.padding(.horizontal, 24).padding(.vertical, 12)
                ZStack(alignment: .bottom) {
                    poster
                    LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .center, endPoint: .bottom).allowsHitTesting(false)
                    Button { model.speak() } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "speaker.wave.2.fill").font(.system(size: 21))
                            VStack(alignment: .leading, spacing: 8) {
                                Text(model.currentLine?.en ?? "正在加载台词…").font(.system(size: 17, weight: .semibold))
                                Text(model.currentLine?.zh ?? "").font(.system(size: 14)).foregroundStyle(muted)
                            }; Spacer(minLength: 0)
                        }.foregroundStyle(ink).padding(20).background(.white, in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain).padding(18)
                }.frame(height: geometry.size.height * 0.56).clipShape(RoundedRectangle(cornerRadius: 22)).padding(.horizontal, 12)
                Spacer(minLength: 12)
                if model.isPreview && model.previewAnswerVisible {
                    Text(LocalDialoguePreview.answers[model.previewTurn]).font(.system(size: 17, weight: .medium)).padding(.horizontal, 24).multilineTextAlignment(.center)
                    primary(model.previewTurn == 7 ? "查看演示结果" : "下一句") { model.nextPreviewLine() }.padding(.horizontal, 24).padding(.top, 14)
                } else if model.pendingAudio != nil && !model.recording {
                    primary(model.busy ? "正在上传评分…" : "提交录音") { Task { await model.submit() } }.disabled(model.busy).padding(.horizontal, 24)
                    Button("重新录制") { model.discardAudio() }.font(.subheadline).foregroundStyle(muted).padding(.top, 14)
                } else {
                    HStack(spacing: 20) {
                        waveform
                        Button { if model.isPreview { model.previewAnswerVisible = true } else { Task { await model.toggleRecording() } } } label: {
                            Image(systemName: model.recording ? "stop.fill" : "mic.fill").font(.system(size: 38)).foregroundStyle(.white)
                                .frame(width: 90, height: 90).background(pink, in: Circle()).overlay(Circle().stroke(pink.opacity(0.15), lineWidth: 7))
                        }.disabled(!model.isMyTurn || model.busy).opacity(model.isMyTurn ? 1 : 0.4).accessibilityLabel(model.isPreview ? "查看参考回答" : model.recording ? "停止录音" : "开始录音")
                        waveform
                    }
                    Text(model.isPreview ? "点击查看参考回答" : model.recording ? "录音中 · 点击停止" : model.isMyTurn ? "点击录音，完成后提交" : "等待对方完成当前台词…").font(.system(size: 13)).foregroundStyle(muted).padding(.top, 14)
                }
                Spacer(minLength: 8)
                Text(model.isPreview ? "本地演示 · 不录音，成绩为示例数据" : "录音最长 60 秒 · 提交后由语音服务评分").font(.system(size: 11)).foregroundStyle(muted).padding(.bottom, 10)
            }
        }
    }
    private var result: some View {
        screen(model.room == nil ? "练习结果" : "PK 结果") {
            VStack(spacing: 16) {
                Image(systemName: "trophy.fill").font(.system(size: 72)).foregroundStyle(.orange).shadow(color: .orange.opacity(0.2), radius: 18)
                Text(model.resultTitle).font(.system(size: 25, weight: .bold))
            }.frame(maxWidth: .infinity).padding(.vertical, 16)
            HStack {
                resultPlayer("我", avatar: model.myAvatar, score: model.ownScore, color: .orange)
                if model.room != nil { Spacer(); vsMark; Spacer(); resultPlayer(model.opponentName, avatar: model.opponentAvatar, score: model.otherScore, color: .purple) }
            }.frame(maxWidth: .infinity).padding(.horizontal, 12)
            VStack(spacing: 20) {
                scoreRow("发音", score: model.ownScore, color: green)
                scoreRow("流利度", score: model.fluency, color: pink)
            }.padding(22).background(surface, in: RoundedRectangle(cornerRadius: 20))
            Button { model.step = .report } label: { HStack { Text("查看详细分析"); Spacer(); Image(systemName: "chevron.right") }.font(.system(size: 15, weight: .medium)).foregroundStyle(muted) }
        }.safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                Button { Task { await model.replay() } } label: { Text("再来一局").font(.system(size: 17, weight: .semibold)).foregroundStyle(ink).frame(maxWidth: .infinity).frame(height: 56).background(surface, in: RoundedRectangle(cornerRadius: 18)) }
                primary("换个场景") { dismiss() }
            }.disabled(model.busy).padding(.horizontal, 24).padding(.vertical, 12).background(.white)
        }
    }
    private var report: some View {
        screen("详细分析") {
            tabs(["整体表现", "逐句分析"], selection: $reportTab)
            if reportTab == 0 {
                VStack(alignment: .leading, spacing: 16) {
                    Text("综合评分").font(.system(size: 15))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(scoreText(model.ownScore)).font(.system(size: 44, weight: .bold))
                        Text("/ 100").font(.system(size: 18)).foregroundStyle(muted); Spacer()
                        if let score = model.ownScore { badge(score >= 90 ? "优秀" : score >= 75 ? "良好" : "继续加油", color: pink) }
                    }
                    ProgressView(value: (model.ownScore ?? 0) / 100).tint(pink)
                    Text("根据本次已提交的录音计算，逐句查看发音表现。").font(.system(size: 13)).foregroundStyle(muted)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    scoreTile("发音", value: scoreText(model.ownScore), note: "语音评测", color: green)
                    scoreTile("流利度", value: scoreText(model.fluency), note: "语音评测", color: .blue)
                    scoreTile("完成台词", value: "\(model.ownLines.filter { $0.score != nil }.count)", note: "已提交录音", color: .green)
                    scoreTile("对话轮次", value: "\(model.lines.count)", note: "本场总台词", color: .orange)
                }
                Text("推荐练习").font(.system(size: 21, weight: .bold))
                ForEach(SocialFeedStore.shared.items.filter { $0.id != scene?.id }.prefix(2)) { item in
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: SocialAPI.mediaURL(item.coverUrl))) { image in image.resizable().scaledToFill() } placeholder: { surface }
                            .frame(width: 66, height: 58).clipped().clipShape(RoundedRectangle(cornerRadius: 10)).allowsHitTesting(false)
                        VStack(alignment: .leading, spacing: 7) { Text(item.title).font(.system(size: 14, weight: .semibold)); Text("Level \(item.level)").font(.caption).foregroundStyle(muted) }; Spacer()
                    }.padding(10).background(surface, in: RoundedRectangle(cornerRadius: 16))
                }
            } else {
                ForEach(model.ownLines) { line in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) { Text(line.en).font(.system(size: 16, weight: .semibold)); Spacer(); Text(line.score.map(String.init) ?? "—").foregroundStyle(pink) }
                        Text(line.zh ?? "").font(.subheadline).foregroundStyle(muted)
                        if let fluency = line.fluency { Text("流利度：\(fluency)").font(.caption).foregroundStyle(green) }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(surface, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
    private var sceneHeader: some View {
        HStack(spacing: 16) {
            poster.frame(width: 108, height: 94).clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 12) { Text(title).font(.system(size: 18, weight: .bold)); Text("Level \(scene?.level ?? 1) · \(scene?.category ?? "情景口语")").font(.system(size: 14)).foregroundStyle(muted) }; Spacer(minLength: 0)
        }
    }
    private func primary(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(text).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 56).background(LinearGradient(colors: [pink, pink.opacity(0.9)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18)) }.buttonStyle(.plain)
    }
    private func modeCard(_ title: String, _ subtitle: String, _ icon: String, _ color: Color) -> some View {
        Button { Task { await model.selectMode(title) } } label: {
            HStack(spacing: 18) {
                Image(systemName: icon).font(.system(size: 34, weight: .semibold)).frame(width: 44)
                VStack(alignment: .leading, spacing: 10) { Text(title).font(.system(size: 20, weight: .bold)); Text(subtitle).font(.system(size: 13)).opacity(0.9) }; Spacer(minLength: 0); Image(systemName: "chevron.right").font(.system(size: 19))
            }.foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, minHeight: 116)
                .background(LinearGradient(colors: [color, color.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18)).shadow(color: color.opacity(0.18), radius: 10, y: 5)
        }.buttonStyle(.plain).disabled(model.busy)
    }
    private func tabs(_ titles: [String], selection: Binding<Int>) -> some View {
        HStack(spacing: 0) {
            ForEach(titles.indices, id: \.self) { index in
                Button { selection.wrappedValue = index } label: {
                    VStack(spacing: 14) { Text(titles[index]).font(.system(size: 15, weight: selection.wrappedValue == index ? .semibold : .regular)).foregroundStyle(selection.wrappedValue == index ? ink : muted); Rectangle().fill(selection.wrappedValue == index ? pink : .clear).frame(width: 64, height: 2) }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }.overlay(alignment: .bottom) { Rectangle().fill(ink.opacity(0.04)).frame(height: 1).allowsHitTesting(false) }
    }
    private func badge(_ text: String, color: Color) -> some View { Text(text).font(.system(size: 13, weight: .medium)).foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 5).background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 6)) }
    private func metric(_ icon: String, _ value: String, _ title: String, _ color: Color) -> some View {
        VStack(spacing: 10) { Image(systemName: icon).font(.system(size: 22)).foregroundStyle(color); Text(value).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7); Text(title).font(.system(size: 12)).foregroundStyle(muted) }.frame(maxWidth: .infinity).padding(.vertical, 14).background(surface, in: RoundedRectangle(cornerRadius: 14))
    }
    private func stat(_ icon: String, _ value: String, _ text: String) -> some View { VStack(spacing: 7) { Label(value, systemImage: icon).font(.system(size: 15, weight: .semibold)); Text(text).font(.system(size: 11)).foregroundStyle(muted) }.frame(maxWidth: .infinity) }
    private func readyRow(_ text: String, ready: Bool) -> some View { Label { Text(text).font(.system(size: 15, weight: .medium)).foregroundStyle(ink) } icon: { Image(systemName: ready ? "checkmark.circle.fill" : "circle").foregroundStyle(ready ? green : muted).font(.system(size: 23)) } }
    private func contestant(_ name: String, avatar: String?, color: Color, ready: String, crown: Bool = false) -> some View {
        VStack(spacing: 14) {
            SocialAvatar(url: avatar, name: name, size: 88).overlay(Circle().stroke(color.opacity(0.75), lineWidth: 4)).overlay(alignment: .top) { if crown { Image(systemName: "crown.fill").font(.system(size: 27)).foregroundStyle(.orange).offset(y: -22) } }
            Text(name).font(.system(size: 19, weight: .bold)).lineLimit(1); Text(ready).font(.system(size: 13)).foregroundStyle(muted)
        }.frame(maxWidth: .infinity)
    }
    private var vsMark: some View { Text("VS").font(.system(size: 37, weight: .black, design: .rounded)).italic().foregroundStyle(LinearGradient(colors: [.blue, pink], startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: pink.opacity(0.2), radius: 10) }
    private func resultPlayer(_ name: String, avatar: String?, score: Double?, color: Color) -> some View { VStack(spacing: 12) { SocialAvatar(url: avatar, name: name, size: 66).overlay(Circle().stroke(color, lineWidth: 3)); Text(name).font(.system(size: 15, weight: .semibold)); Text(scoreText(score)).font(.system(size: 40, weight: .bold)).foregroundStyle(color) } }
    private func scoreText(_ score: Double?) -> String { score.map { String(Int($0.rounded())) } ?? "—" }
    private func scoreRow(_ title: String, score: Double?, color: Color) -> some View { HStack { Text(title).font(.subheadline).frame(width: 64, alignment: .leading); ProgressView(value: (score ?? 0) / 100).tint(color); Text(scoreText(score)).font(.subheadline.bold()).frame(width: 30) } }
    private func scoreTile(_ title: String, value: String, note: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(title).font(.system(size: 14)); HStack(alignment: .firstTextBaseline, spacing: 8) { Text(value).font(.system(size: 27, weight: .bold)); Text(note).font(.system(size: 10)) }.foregroundStyle(color) }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(LinearGradient(colors: [surface, color.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
    }
    private var waveform: some View { HStack(spacing: 4) { ForEach(0..<10) { index in Capsule().fill(muted.opacity(0.5)).frame(width: 3, height: CGFloat([4, 7, 12, 6, 18, 10, 23, 9, 5, 3][index])) } } }
}
