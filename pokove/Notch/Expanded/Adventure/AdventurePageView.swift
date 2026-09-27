import SwiftUI

extension Color {
    /// The adventure's warm red-orange, for tabs, badges and banners.
    static let adventure = Color(red: 1.0, green: 0.48, blue: 0.27)
}

extension Notification.Name {
    static let pokoveOpenAdventure = Notification.Name("com.geonhwiii.pokove.openAdventure")
    #if DEBUG
    static let pokoveDebugSelectPokemon = Notification.Name("pokoveDebugSelectPokemon")
    static let pokoveDebugAdventurePane = Notification.Name("pokoveDebugAdventurePane")
    static let pokoveDebugOpenBall = Notification.Name("pokoveDebugOpenBall")
    static let pokoveDebugChallengeMode = Notification.Name("pokoveDebugChallengeMode")
    #endif
}

/// Which view fills the right half of the adventure page.
enum AdventurePane: String, CaseIterable {
    case challenge, dex, gacha

    var title: String {
        switch self {
        case .challenge: String(localized: "Challenge")
        case .dex: String(localized: "Pokédex")
        case .gacha: String(localized: "Gacha")
        }
    }
}

/// The adventure page: the battle and party on the left; the challenges, Pokédex or gacha on the right.
struct AdventurePageView: View {
    @Environment(AppModel.self) private var app
    /// The species whose details replace the battle scene.
    @State private var selection: Int?
    @AppStorage("adventurePane") private var pane: AdventurePane = .challenge
    /// The right pane shows the history instead of a tab.
    @State private var showsHistory = false
    /// What happened while the page was closed, as one line over the battle for a few seconds.
    @State private var toast: AdventureRecap?
    @State private var toastHovered = false

    var body: some View {
        let adventure = app.adventure
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    switch adventure.dex.state {
                    case .ready:
                        if let id = selection, let species = adventure.dex.species(id) {
                            PokeDetailCard(species: species) { selection = nil }
                                .id(id)
                                .transition(.blurReplace)
                        } else if !adventure.hasStarted {
                            StarterPicker()
                                .transition(.blurReplace)
                        } else {
                            BattleSceneView()
                                .overlay(alignment: .top) {
                                    if let toast {
                                        RecapToast(recap: toast) { openHistory() }
                                            .onHover { toastHovered = $0 }
                                            .padding(.top, 5)
                                            .padding(.horizontal, 6)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                }
                                .transition(.blurReplace)
                        }
                    case .failed:
                        DexUnavailable()
                    case .idle, .loading:
                        DexLoading()
                    }
                }
                .frame(height: BattleSceneView.height)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.08)))
                .animation(.smooth(duration: 0.28), value: selection)

                PartyBar(selection: $selection)
            }
            .frame(minWidth: 226, maxWidth: 262)

            VStack(alignment: .leading, spacing: 6) {
                PaneTabs(pane: $pane, showsHistory: $showsHistory)
                if showsHistory {
                    HistoryView()
                } else {
                    switch pane {
                    case .challenge: ChallengeView()
                    case .dex: DexGrid(selection: $selection)
                    case .gacha: GachaView()
                    }
                }
            }
            .frame(width: 216)
            .disabled(!adventure.hasStarted)
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            adventure.dex.load()
            adventure.isWatching = true
            // The recap goes to the history either way; only the big things get the line.
            if let recap = adventure.takeRecap(), recap.isNotable { toast = recap }
        }
        .onDisappear {
            adventure.isWatching = false
            toast = nil
            showsHistory = false
        }
        .task(id: toast?.until) {
            // A few seconds, longer while the pointer rests on it.
            guard toast != nil, (try? await Task.sleep(for: .seconds(Self.toastSeconds))) != nil else { return }
            while toastHovered {
                guard (try? await Task.sleep(for: .seconds(1))) != nil else { return }
            }
            withAnimation(.smooth(duration: 0.3)) { toast = nil }
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .pokoveDebugSelectPokemon)) { note in
            selection = note.object as? Int
        }
        .onReceive(NotificationCenter.default.publisher(for: .pokoveDebugAdventurePane)) { note in
            if let raw = note.object as? String, let value = AdventurePane(rawValue: raw) { pane = value }
            if note.object as? String == "history" { openHistory() }
            if note.object as? String == "toast" { toast = adventure.history.first }
        }
        #endif
    }
}

extension AdventurePageView {
    static let toastSeconds: Double = 4

    private func openHistory() {
        withAnimation(.smooth(duration: 0.25)) {
            toast = nil
            showsHistory = true
        }
        app.adventure.markHistoryRead()
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// Challenge, Pokédex and Gacha tabs, with the history, the banner switch and the stardust purse.
private struct PaneTabs: View {
    @Binding var pane: AdventurePane
    @Binding var showsHistory: Bool
    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        HStack(spacing: 3) {
            ForEach(AdventurePane.allCases, id: \.self) { item in
                let on = pane == item && !showsHistory
                Button {
                    withAnimation(.smooth(duration: 0.2)) { pane = item; showsHistory = false }
                } label: {
                    Text(item.title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(on ? .white : .white.opacity(0.45))
                        .padding(.horizontal, 8)
                        .frame(height: 19)
                        .background(on ? .white.opacity(0.14) : .clear, in: Capsule())
                        .overlay(alignment: .topTrailing) {
                            if item == .gacha, adventure.hasGachaWaiting {
                                Circle().fill(Color(hex: 0xFFD35A)).frame(width: 5, height: 5).offset(x: -1, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 2)
            HistoryButton(showsHistory: $showsHistory)
            BannerToggle()
            HStack(spacing: 3) {
                StardustIcon(size: 11)
                Text("\(adventure.stardust)")
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.75))
                    .contentTransition(.numericText())
            }
            .help("Stardust, from stations, bosses and the dungeon. \(Gacha.price) buy three Poké Balls.")
        }
    }
}

/// Mutes the adventure's banners and sounds in one click, say before sharing a screen.
private struct BannerToggle: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let preferences = app.preferences
        let on = preferences.adventureAnnounceCatches
        Button {
            preferences.adventureAnnounceCatches.toggle()
        } label: {
            Image(systemName: on ? "bell.fill" : "bell.slash.fill")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(on ? .white.opacity(0.55) : Color(hex: 0xFF8A70))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(on ? "Adventure banners are on. Click to mute them, say before sharing your screen." : "Adventure banners are muted. Click to turn them back on.")
    }
}

/// Opens the history: what happened while the page was closed, today and yesterday. A dot shows
/// until the newest recap has been looked at.
private struct HistoryButton: View {
    @Binding var showsHistory: Bool
    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        Button {
            withAnimation(.smooth(duration: 0.25)) { showsHistory.toggle() }
            if showsHistory { adventure.markHistoryRead() }
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(showsHistory ? .white : .white.opacity(0.55))
                .frame(width: 18, height: 18)
                .background(showsHistory ? .white.opacity(0.14) : .clear, in: Circle())
                .overlay(alignment: .topTrailing) {
                    if adventure.historyUnread, !showsHistory {
                        Circle().fill(Color(hex: 0xFF8A70)).frame(width: 5, height: 5).offset(x: -1, y: 1)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(GuideText.historyHelp)
    }
}

/// One line over the battle when the page opens after something big: the thing itself when
/// there's one, a count of them when there are several. Tapping it opens the history.
private struct RecapToast: View {
    let recap: AdventureRecap
    let open: () -> Void
    @Environment(AppModel.self) private var app

    var body: some View {
        let notable = RecapLine.lines(for: recap, adventure: app.adventure).filter(\.isNotable)
        Button(action: open) {
            HStack(spacing: 5) {
                if let first = notable.first {
                    RecapIcon(icon: first.icon).frame(width: 20, height: 15)
                }
                Text(notable.count == 1 ? notable[0].text : "\(RecapText.title) · \(summary)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 7.5, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.leading, 5)
            .padding(.trailing, 8)
            .frame(height: 22)
            .background(Color(hex: 0x0B0D12).opacity(0.9), in: Capsule())
            .overlay(Capsule().strokeBorder(Color(hex: 0xFFD35A).opacity(0.45), lineWidth: 0.8))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var summary: String {
        GuideText.summary(badges: recap.badges.count, gyms: recap.gymsOpened.count, evolved: recap.evolutions.count, joined: recap.discovered.count,
                          losses: recap.losses.values.reduce(0, +), dungeons: recap.dungeon.count, shinies: recap.shinies.count)
    }
}

/// The right pane's history: each time the page was closed, what happened, newest first.
private struct HistoryView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        Group {
            if adventure.history.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(GuideText.noHistory)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(GuideText.noHistoryDetail)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        // One view per recap, so its lines' IDs only need to be unique within it.
                        ForEach(adventure.history, id: \.until) { recap in
                            VStack(alignment: .leading, spacing: 1) {
                                HistoryHeader(recap: recap)
                                ForEach(RecapLine.lines(for: recap, adventure: adventure)) { RecapRow(line: $0) }
                            }
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                }
                .scrollIndicators(.automatic)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0x101218), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// "방금 · 42분", "13:10 · 1시간 5분", "어제 22:40 · 2시간".
private struct HistoryHeader: View {
    let recap: AdventureRecap

    var body: some View {
        HStack(spacing: 4) {
            Text(when)
            if let since = recap.since, let until = recap.until {
                Text(verbatim: "·")
                Text(RecapText.span(until.timeIntervalSince(since)))
            }
        }
        .font(.system(size: 9, weight: .bold).monospacedDigit())
        .foregroundStyle(.white.opacity(0.4))
        .padding(.top, 4)
        .padding(.bottom, 1)
    }

    private var when: String {
        guard let until = recap.until else { return "" }
        if Date().timeIntervalSince(until) < 120 { return GuideText.justNow }
        let time = until.formatted(date: .omitted, time: .shortened)
        let today = DailyDungeon.day(of: Date())
        return DailyDungeon.day(of: until) == today ? time : "\(GuideText.yesterday) \(time)"
    }
}

private struct RecapRow: View {
    let line: RecapLine
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: 6) {
            RecapIcon(icon: line.icon)
                .frame(width: 22, height: 17)
            Text(line.text)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 4)
            if let detail = line.detail {
                HStack(spacing: 2) {
                    if line.detailIsStardust { StardustIcon(size: 10) }
                    Text(detail)
                }
                .font(.system(size: 10, weight: .bold).monospacedDigit())
                .foregroundStyle(line.detailTint)
                .lineLimit(1)
                .fixedSize()
            }
            if line.offersBestTeam {
                Button {
                    withAnimation(.smooth(duration: 0.25)) { app.adventure.recommendParty() }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "hand.thumbsup.fill").font(.system(size: 7.5, weight: .bold))
                        Text(RecapText.bestTeam).font(.system(size: 9, weight: .heavy))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .frame(height: 15)
                    .background(Color(hex: 0xFFD35A), in: Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
        }
        .frame(height: 17)
    }

}

private struct RecapIcon: View {
    let icon: RecapLine.Icon

    var body: some View {
        switch icon {
        case .pokemon(let id): PokeIconView(id: id, pixelSize: 0.5)
        case .shiny(let id):
            PokeIconView(id: id, pixelSize: 0.5).overlay(alignment: .topTrailing) { ShinyMark(size: 6).offset(x: 2, y: -1) }
        case .team(let ids):
            ZStack {
                ForEach(Array(ids.prefix(3).enumerated()), id: \.offset) { index, id in
                    PokeIconView(id: id, pixelSize: 0.5).offset(x: CGFloat(index - (min(ids.count, 3) - 1)) * 4)
                }
            }
        case .badge(let number): BadgeImageView(number: number, size: 14)
        case .openBadge(let number): BadgeImageView(number: number, size: 14, earned: false, unearnedColor: .white.opacity(0.55))
        case .stardust: StardustIcon(size: 13)
        case .symbol(let name, let color):
            Image(systemName: name).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
        }
    }
}

/// One line of the recap, most notable first.
struct RecapLine: Identifiable {
    enum Icon {
        case pokemon(Int)
        /// A shiny: the icon with its ✦.
        case shiny(Int)
        /// A few Pokémon, overlapping.
        case team([Int])
        case badge(Int)
        /// A badge still to win, as its outline.
        case openBadge(Int)
        case stardust
        case symbol(String, Color)
    }

    let id: String
    let icon: Icon
    let text: String
    var detail: String?
    var detailTint: Color = .white.opacity(0.5)
    var detailIsStardust = false
    var offersBestTeam = false
    /// Big enough for the line over the battle.
    var isNotable = false

    /// How many joins or moves get a line of their own before the rest are counted together.
    private static let namedLimit = 3

    static func lines(for recap: AdventureRecap, adventure: AdventureService) -> [RecapLine] {
        let name = { (id: Int) in adventure.dex.species(id)?.name ?? "#\(id)" }
        let trainers = adventure.chapters.flatMap(\.bosses)
        var lines: [RecapLine] = []

        for milestone in recap.dexMilestones {
            lines.append(.init(id: "dex\(milestone)", icon: .symbol("book.closed.fill", Color(hex: 0xFFD35A)),
                               text: RecapText.dexMilestone(milestone), isNotable: true))
        }
        if let floor = recap.tower {
            lines.append(.init(id: "tower", icon: .symbol("building.columns.fill", Color(hex: 0xB9A4FF)), text: RecapText.tower(floor)))
        }
        for (i, species) in recap.shinies.enumerated() {
            lines.append(.init(id: "shiny\(i)", icon: .shiny(species), text: RecapText.shiny(name(species)), isNotable: true))
        }
        for badge in recap.badges {
            let trainer = trainers.first { $0.badge == badge }?.name ?? ""
            lines.append(.init(id: "badge\(badge)", icon: .badge(badge),
                               text: RecapText.beat(trainer, badge: Kanto.badgeName(badge)), isNotable: true))
        }
        for chapter in recap.gymsOpened {
            guard let info = adventure.chapters[safeChapter: chapter], let first = info.bosses.first else { continue }
            if let badge = info.badge {
                lines.append(.init(id: "gym\(chapter)", icon: .openBadge(badge), text: RecapText.gymOpened(first.name), isNotable: true))
            } else {
                lines.append(.init(id: "gym\(chapter)", icon: .symbol("crown.fill", Color(hex: 0xFFD35A)), text: RecapText.leagueOpened,
                                   isNotable: true))
            }
        }
        // A boss that keeps winning comes early: it's the one line with something to do.
        for (trainerID, times) in recap.losses.sorted(by: { $0.key < $1.key }) {
            guard let trainer = trainers.first(where: { $0.id == trainerID }) else { continue }
            let stuck = recap.stuck == trainerID
            lines.append(.init(id: "lost\(trainerID)", icon: .symbol("shield.lefthalf.filled.slash", Color(hex: 0xFF9E6B)),
                               text: RecapText.lost(to: trainer.name, times: times), offersBestTeam: stuck, isNotable: true))
        }
        for (i, step) in recap.evolutions.enumerated() {
            lines.append(.init(id: "evolved\(i)", icon: .pokemon(step.to),
                               text: RecapText.evolved(step.from == step.to ? nil : name(step.from), into: name(step.to)), isNotable: true))
        }
        // Party members first, then anyone else who grew.
        let order = Dictionary(uniqueKeysWithValues: adventure.partyIDs.enumerated().map { ($1, $0) })
        for growth in recap.growth.sorted(by: { (order[$0.member] ?? 9) < (order[$1.member] ?? 9) }) {
            lines.append(.init(id: "growth\(growth.member)", icon: .pokemon(growth.species), text: name(growth.species),
                               detail: "Lv \(growth.from) → \(growth.to)", detailTint: Color(hex: 0x7FE08A)))
        }
        if !recap.discovered.isEmpty {
            lines.append(.init(id: "joined", icon: recap.discovered.count == 1 ? .pokemon(recap.discovered[0]) : .team(recap.discovered),
                               text: RecapText.joined(recap.discovered.map(name)), isNotable: true))
        }
        for tier in recap.dungeon {
            let prize = DailyDungeon.stardust[tier]
            lines.append(.init(id: "dungeon\(tier.rawValue)", icon: .symbol("door.left.hand.open", Color(hex: 0xB9A4FF)),
                               text: RecapText.dungeon(tier.title),
                               detail: prize.map { "+\($0)" } ?? RecapText.ultraBall,
                               detailTint: Color(hex: 0xFFD35A), detailIsStardust: prize != nil, isNotable: true))
        }
        for (i, learned) in recap.learned.prefix(namedLimit).enumerated() {
            let move = adventure.data?.moves.move(learned.move)?.name ?? ""
            lines.append(.init(id: "learned\(i)", icon: .pokemon(learned.species),
                               text: RecapText.learned(name(learned.species), move)))
        }
        if recap.learned.count > namedLimit {
            lines.append(.init(id: "learnedMore", icon: .symbol("bolt.fill", Color(hex: 0xFFD35A)),
                               text: RecapText.learnedMore(recap.learned.count - namedLimit)))
        }
        if recap.clears > 0 || recap.stardust > 0 {
            // How far the line moved, else where the party stayed; the stardust rides along.
            let label = { (point: StationPoint) in "\(point.chapter + 1)-\(point.station + 1)" }
            let text: String
            if let reached = recap.reached {
                text = RecapText.moved(from: recap.start.map(label), to: label(reached))
            } else if let stayed = recap.stayed {
                text = RecapText.stayed(at: label(stayed))
            } else {
                text = RecapText.stardust
            }
            lines.append(.init(id: "wins", icon: .symbol("flag.fill", Color(hex: 0x7FE08A)), text: text,
                               detail: recap.stardust > 0 ? "+\(recap.stardust)" : nil,
                               detailTint: Color(hex: 0xFFD35A), detailIsStardust: true))
        }
        return lines
    }
}

// MARK: Starter, loading

private struct StarterPicker: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            StageBackdrop(scenery: .meadow)
            VStack(spacing: 4) {
                Text("Choose your partner")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                HStack(spacing: 6) {
                    ForEach(AdventureService.starters, id: \.self) { id in
                        StarterButton(id: id)
                    }
                }
            }
            .padding(.top, 6)
        }
    }
}

private struct StarterButton: View {
    let id: Int
    @Environment(AppModel.self) private var app
    @State private var isHovering = false

    var body: some View {
        let species = app.adventure.dex.species(id)
        Button {
            withAnimation(.smooth(duration: 0.3)) { app.adventure.chooseStarter(id) }
        } label: {
            VStack(spacing: 3) {
                PokeSpriteView(id: id, pixelSize: 1)
                    .frame(height: 50, alignment: .bottom)
                Text(species?.name ?? "")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.white)
                if let type = species?.types.first { PokeTypeBadge(type: type, compact: true) }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .frame(width: 70)
            .background(.black.opacity(isHovering ? 0.4 : 0.22), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(isHovering ? 1.05 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct DexLoading: View {
    var body: some View {
        ZStack {
            StageBackdrop(scenery: .meadow)
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Getting Pokédex data…")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.4), in: Capsule())
        }
    }
}

private struct DexUnavailable: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            StageBackdrop(scenery: .cave)
            VStack(spacing: 6) {
                Text("Couldn't reach PokéAPI")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                Text("The adventure starts once the Pokédex downloads.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.7))
                Button("Try Again") { app.adventure.dex.retry() }
                    .controlSize(.small)
            }
        }
    }
}

// MARK: Party

private struct PartyBar: View {
    @Binding var selection: Int?
    @Environment(AppModel.self) private var app
    /// The slot a dragged Pokémon is over.
    @State private var dropTarget: Int?

    var body: some View {
        let adventure = app.adventure
        let party = adventure.party
        HStack(spacing: 4) {
            ForEach(0..<AdventureService.maxParty, id: \.self) { slot in
                Group {
                    if let member = party[safe: slot] {
                        PartySlot(member: member, order: slot + 1, isSelected: selection == member.speciesID) {
                            selection = selection == member.speciesID ? nil : member.speciesID
                        }
                        .draggable(member.id.uuidString) { PokeIconView(id: member.speciesID, pixelSize: 1) }
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(height: Self.height)
                            .overlay(
                                Text("Empty")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.25))
                            )
                            .help("Drag a Pokémon here from the Pokédex.")
                    }
                }
                // Party members swap places; one dragged from the Pokédex takes the slot.
                .overlay {
                    if dropTarget == slot {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(hex: 0xFFD35A), lineWidth: 1.5)
                    }
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                    withAnimation(.smooth(duration: 0.25)) { adventure.place(id, at: slot) }
                    return true
                } isTargeted: { targeted in
                    if targeted { dropTarget = slot } else if dropTarget == slot { dropTarget = nil }
                }
            }
            // Lit when the box holds a better team for the next boss than the one out now.
            let better = adventure.hasBetterTeam
            Button {
                withAnimation(.smooth(duration: 0.25)) { adventure.recommendParty() }
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "hand.thumbsup.fill").font(.system(size: 8, weight: .bold))
                    Text(GuideText.recommend).font(.system(size: 8, weight: .heavy))
                }
                .foregroundStyle(better ? .black : .white.opacity(0.75))
                .frame(width: 30, height: Self.height)
                .background(better ? Color(hex: 0xFFD35A) : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(adventure.owned.count < 2)
            .help("Best team for what's next")
        }
        .frame(height: Self.height)
    }

    static let height: CGFloat = 28
}

private struct PartySlot: View {
    let member: OwnedPokemon
    /// Place in the relay: 1 battles first.
    let order: Int
    let isSelected: Bool
    let action: () -> Void

    @Environment(AppModel.self) private var app
    @State private var isHovering = false

    var body: some View {
        let species = app.adventure.dex.species(member.speciesID)
        let tint = species?.types.first?.color ?? .white
        Button(action: action) {
            HStack(spacing: 2) {
                PokeIconView(id: member.speciesID, pixelSize: 1)
                    .overlay(alignment: .topTrailing) { if member.shiny { ShinyMark(size: 7).offset(x: -3, y: 1) } }
                    .padding(.leading, -3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lv \(member.level)")
                        .font(.system(size: 9.5, weight: .heavy).monospacedDigit())
                        .foregroundStyle(.white)
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.14))
                        Capsule().fill(Color(hex: 0x7FC8FF)).frame(width: 30 * member.levelProgress)
                    }
                    .frame(width: 30, height: 2.5)
                }
                Spacer(minLength: 0)
            }
            .padding(.trailing, 4)
            .frame(maxWidth: .infinity, minHeight: PartyBar.height, maxHeight: PartyBar.height)
            .background(tint.opacity(isHovering ? 0.22 : 0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? .white.opacity(0.7) : tint.opacity(0.3), lineWidth: isSelected ? 1.5 : 1)
            )
            .overlay(alignment: .topLeading) {
                Text("\(order)")
                    .font(.system(size: 7, weight: .black, design: .rounded))
                    .foregroundStyle(order == 1 ? Color(hex: 0xFFE14D) : .white.opacity(0.5))
                    .offset(x: 4, y: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(species.map { "\($0.name) · Lv \(member.level) · \(GuideText.xpLeftLong(PokeMath.xpToNext(level: member.level, xp: member.xp)))" } ?? "")
    }
}

// MARK: Pokédex

private struct DexGrid: View {
    @Binding var selection: Int?
    @Environment(AppModel.self) private var app
    @AppStorage("dexOwnedOnly") private var ownedOnly = false

    private let columns = Array(repeating: GridItem(.fixed(40), spacing: 4), count: 5)
    /// A hovered cell scales up; this leaves it room so the scroll view doesn't clip it.
    private static let growRoom: CGFloat = 4

    var body: some View {
        let adventure = app.adventure
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1))
                        Capsule().fill(Color.adventure)
                            .frame(width: proxy.size.width * CGFloat(adventure.caught.count) / CGFloat(PokeDexStore.maxID))
                    }
                }
                .frame(height: 4)
                Text("\(adventure.caught.count)/\(PokeDexStore.maxID)")
                    .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.numericText())
                // The next Pokédex milestone, which pays an Ultra Ball.
                if let next = DexRewards.next(caught: adventure.caught.count) {
                    HStack(spacing: 1) {
                        ItemSpriteView(slug: "ultra-ball", pixelSize: 0.5).frame(width: 11, height: 11)
                        Text("\(next)")
                            .font(.system(size: 9.5, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .help(GuideText.nextDexReward(next))
                }
                if adventure.shinyCount > 0 {
                    HStack(spacing: 1) {
                        ShinyMark(size: 7)
                        Text("\(adventure.shinyCount)")
                            .font(.system(size: 9.5, weight: .bold).monospacedDigit())
                            .foregroundStyle(Color(hex: 0xFFE14D))
                    }
                    .help(RecapText.shinyLabel)
                }
                Button {
                    withAnimation(.smooth(duration: 0.2)) { ownedOnly.toggle() }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: ownedOnly ? "checkmark" : "line.3.horizontal.decrease").font(.system(size: 7, weight: .heavy))
                        Text(GuideText.ownedOnly).font(.system(size: 8.5, weight: .bold))
                    }
                    .foregroundStyle(ownedOnly ? .black : .white.opacity(0.6))
                    .padding(.horizontal, 6)
                    .frame(height: 15)
                    .background(ownedOnly ? Color(hex: 0xFFD35A) : .white.opacity(0.1), in: Capsule())
                    .contentShape(Capsule())
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(ownedOnly ? ownedSpecies(adventure) : Array(1...PokeDexStore.maxID), id: \.self) { id in
                        DexCell(id: id, isSelected: selection == id) {
                            selection = selection == id ? nil : id
                        }
                    }
                }
                .padding(.horizontal, Self.growRoom)
                .padding(.top, Self.growRoom + 2)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, -Self.growRoom)
            .padding(.top, -Self.growRoom)
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: Self.growRoom)
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 22)
                }
            }
        }
        .frame(width: 5 * 40 + 4 * 4)
        .onAppear {
            if adventure.dex.isReady { PokeSpriteCache.shared.prefetchIcons(upTo: PokeDexStore.maxID) }
        }
        .onChange(of: adventure.dex.isReady) { _, ready in
            if ready { PokeSpriteCache.shared.prefetchIcons(upTo: PokeDexStore.maxID) }
        }
    }

    /// Species in the box right now, by number.
    private func ownedSpecies(_ adventure: AdventureService) -> [Int] {
        Array(Set(adventure.owned.map(\.speciesID))).sorted()
    }
}

private struct DexCell: View {
    let id: Int
    let isSelected: Bool
    let action: () -> Void

    @Environment(AppModel.self) private var app
    @State private var isHovering = false

    var body: some View {
        let adventure = app.adventure
        let caught = adventure.caught.contains(id)
        let seen = adventure.seen.contains(id)
        let species = adventure.dex.species(id)
        let tint = species?.types.first?.color ?? .white
        let inParty = adventure.party.contains { $0.speciesID == id }
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(caught ? tint.opacity(isHovering ? 0.24 : 0.13) : .white.opacity(isHovering ? 0.09 : 0.045))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? .white.opacity(0.7) : (caught ? tint.opacity(0.35) : .clear), lineWidth: isSelected ? 1.5 : 1)
                PokeIconView(id: id, pixelSize: 1, silhouette: !caught, silhouetteOpacity: seen ? 0.34 : 0.12)
                if adventure.owned(species: id)?.shiny == true {
                    ShinyMark(size: 7).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(3)
                }
                if !caught && !seen {
                    Text("?")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(width: 40, height: 30)
            .overlay(alignment: .topTrailing) {
                if inParty {
                    Circle().fill(Color.adventure).frame(width: 5, height: 5).offset(x: -3, y: 3)
                }
            }
            .scaleEffect(isHovering ? 1.06 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(Self.help(species: species, caught: caught, seen: seen, id: id))
        // One you have can be dragged onto the party bar.
        .modifier(DragToParty(member: adventure.owned(species: id)))
    }

    static func help(species: PokeSpecies?, caught: Bool, seen: Bool, id: Int) -> String {
        let number = String(format: "#%03d", id)
        guard let species, caught || seen else { return number }
        return "\(number) \(species.name)"
    }
}

private struct DragToParty: ViewModifier {
    let member: OwnedPokemon?

    func body(content: Content) -> some View {
        if let member {
            content.draggable(member.id.uuidString) { PokeIconView(id: member.speciesID, pixelSize: 1) }
        } else {
            content
        }
    }
}

/// Details for the selected species, shown where the battle was.
private struct PokeDetailCard: View {
    let species: PokeSpecies
    let close: () -> Void

    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        let caught = adventure.caught.contains(species.id)
        let seen = caught || adventure.seen.contains(species.id)
        let owned = adventure.owned(species: species.id)
        let tint = species.types.first?.color ?? .white
        ZStack(alignment: .topTrailing) {
            Rectangle().fill(Color(hex: 0x101218))
            if caught {
                RadialGradient(colors: [tint.opacity(0.35), tint.opacity(0.08), .clear], center: .init(x: 0.14, y: 0.35),
                               startRadius: 2, endRadius: 60)
            }
            HStack(alignment: .top, spacing: 9) {
                VStack(spacing: 4) {
                    PokeSpriteView(id: species.id, pixelSize: 1, silhouette: !caught, shiny: owned?.shiny == true, fitHeight: 56)
                        .frame(width: 64, height: 58, alignment: .bottom)
                        .opacity(seen ? 1 : 0.5)
                    if seen { EvolutionBox(species: species) }
                }
                .frame(width: 64)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(species.number)
                            .font(.system(size: 9.5, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.45))
                        Text(seen ? species.name : "???")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if owned?.shiny == true { ShinyMark(size: 9) }
                    }
                    .padding(.trailing, owned == nil ? 20 : 62)
                    if seen {
                        HStack(spacing: 3) {
                            ForEach(species.types, id: \.self) { PokeTypeBadge(type: $0, compact: true) }
                            if !species.genus.isEmpty {
                                Text(species.genus)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .lineLimit(1)
                            }
                        }
                    }
                    if let owned {
                        OwnedSummary(member: owned)
                    } else {
                        Text(caught ? species.flavor : GuideText.habitat(adventure.habitat(of: species.id)) { id in
                            adventure.dex.species(id)?.name ?? "#\(id)"
                        })
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 8)
            .padding(.trailing, 8)
            .padding(.vertical, 7)

            HStack(spacing: 3) {
                if let owned { PartyActions(member: owned) }
                CardButton(symbol: "xmark", help: nil, action: close)
            }
            .padding(6)
        }
    }
}

/// The small round buttons in the card's corner.
private struct CardButton: View {
    let symbol: String
    let help: String?
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: { withAnimation(.smooth(duration: 0.25)) { action() } }) {
            Image(systemName: symbol)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(.white.opacity(enabled ? 0.7 : 0.25))
                .frame(width: 18, height: 18)
                .background(.white.opacity(0.1), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help ?? "")
    }
}

/// Lead, remove or add, as icons so the card has room for what the Pokémon can do.
private struct PartyActions: View {
    let member: OwnedPokemon
    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        if adventure.isInParty(member.id) {
            if adventure.partyIDs.first != member.id {
                CardButton(symbol: "arrow.up.to.line", help: String(localized: "Go First")) { adventure.makeLeader(member.id) }
            }
            if adventure.partyIDs.count > 1 {
                CardButton(symbol: "minus", help: String(localized: "Remove")) { adventure.toggleParty(member.id) }
            }
        } else {
            let full = adventure.partyIDs.count >= AdventureService.maxParty
            CardButton(symbol: "plus", help: full ? String(localized: "Party is full") : String(localized: "Add to Party"),
                       enabled: !full) { adventure.toggleParty(member.id) }
        }
    }
}

/// What this species becomes next and at what level; a silhouette until that form has been seen.
private struct EvolutionBox: View {
    let species: PokeSpecies
    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        let next = adventure.dex.evolutions(of: species.id)
        if let first = next.first {
            let seen = next.map { adventure.seen.contains($0.id) || adventure.caught.contains($0.id) }
            VStack(spacing: 1) {
                Text(GuideText.nextEvolution)
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                HStack(spacing: 2) {
                    HStack(spacing: -6) {
                        ForEach(Array(next.prefix(3).enumerated()), id: \.element.id) { index, form in
                            PokeIconView(id: form.id, pixelSize: 0.5, silhouette: !seen[index], silhouetteOpacity: 0.35)
                        }
                    }
                    .frame(height: 15)
                    if let level = first.evolveLevel {
                        Text("Lv \(level)")
                            .font(.system(size: 9, weight: .heavy).monospacedDigit())
                            .foregroundStyle(.white)
                            .fixedSize()
                    }
                }
                Text(next.count > 1 ? GuideText.oneOf(next.count) : (seen[0] ? first.name : "???"))
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.vertical, 3)
            .frame(width: 64)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}

/// Level against the cap, moves, what comes next, and how it fares against the next boss.
private struct OwnedSummary: View {
    let member: OwnedPokemon
    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        let cap = adventure.levelCap
        let atCap = member.level >= cap
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                // "Lv 5/16": the level out of the most it can reach before the next badge.
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("Lv \(member.level)")
                        .font(.system(size: 11, weight: .heavy).monospacedDigit())
                        .foregroundStyle(.white)
                    Text(verbatim: "/\(cap)")
                        .font(.system(size: 9, weight: .bold).monospacedDigit())
                        .foregroundStyle(atCap ? Color(hex: 0xFFD35A) : .white.opacity(0.45))
                }
                .help(GuideText.cap(cap))
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.14))
                    Capsule().fill(Color(hex: 0x7FC8FF)).frame(width: 40 * (atCap ? 1 : member.levelProgress))
                }
                .frame(width: 40, height: 3)
                .help(GuideText.xpLeftLong(PokeMath.xpToNext(level: member.level, xp: member.xp)))
                if !atCap {
                    Text(GuideText.xpLeft(PokeMath.xpToNext(level: member.level, xp: member.xp)))
                        .font(.system(size: 8.5, weight: .bold).monospacedDigit())
                        .foregroundStyle(Color(hex: 0x7FC8FF))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            MoveChips(moves: adventure.moves(of: member))
            if let next = nextLine(adventure: adventure, atCap: atCap) {
                Text(next)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if let matchup = adventure.matchup(of: member), let boss = adventure.nextBoss?.trainer.name {
                MatchupLine(matchup: matchup, boss: boss)
            }
        }
    }

    /// The next move, or at the cap, what the next badge lets it do.
    private func nextLine(adventure: AdventureService, atCap: Bool) -> String? {
        if atCap {
            let badges = adventure.progress.badges
            let nextCap = badges >= 8 ? PokeMath.maxLevel : Kanto.levelCap(badges: badges + 1, champion: false)
            let reach = PokeMath.level(forXP: min(member.xp + member.banked, PokeMath.xpLimit(cap: nextCap)))
            return reach > member.level ? GuideText.afterBadge(reach - member.level) : GuideText.atCap
        }
        guard let data = adventure.data, let species = data.dex[member.speciesID],
              let next = Guidance.nextMove(species: species, level: member.level, moves: data.moves) else { return nil }
        return GuideText.learns(next.move.name, at: next.level)
    }
}

private struct MatchupLine: View {
    let matchup: Matchup
    let boss: String

    var body: some View {
        switch matchup {
        case .strong: pill(GuideText.strong(against: boss), color: Color(hex: 0x7EE08F))
        case .weak: pill(GuideText.weak(against: boss), color: Color(hex: 0xFF8A70))
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .frame(height: 14)
            .background(color.opacity(0.16), in: Capsule())
            .fixedSize()
    }
}

/// A Pokémon's four moves as type-colored chips, two to a row.
private struct MoveChips: View {
    let moves: [PokeMove]

    var body: some View {
        let rows = stride(from: 0, to: moves.count, by: 2).map { Array(moves[$0..<min($0 + 2, moves.count)]) }
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 2) {
                    ForEach(row, id: \.id) { move in
                        Text(move.name)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 4)
                            .frame(height: 13)
                            .background(move.type.color.opacity(0.55), in: Capsule())
                            .help(help(move))
                    }
                }
            }
        }
    }

    private func help(_ move: PokeMove) -> String {
        let power = move.power.map { " · \($0)" } ?? ""
        return "\(move.type.title)\(power)"
    }
}

// MARK: Compact notch

/// The party leader, hopping beside the timer while an agent works.
struct PartnerIcon: View {
    let speciesID: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let hop = reduceMotion ? 0 : -abs(sin(time * 3.2)) * 2.5
            PokeIconView(id: speciesID, pixelSize: 0.5)
                .offset(y: (hop * 2).rounded() / 2)
        }
        .frame(width: 20, height: 18)
        .accessibilityLabel(Text("Adventure partner"))
    }
}
