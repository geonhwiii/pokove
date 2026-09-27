import SwiftUI

/// The three ways to take the journey on: the stage line agents push along, the gym bosses, and
/// the daily dungeon.
enum ChallengeMode: String, CaseIterable {
    case stage, gym, dungeon

    var title: String {
        switch self {
        case .stage: String(localized: "Stages")
        case .gym: String(localized: "Gym")
        case .dungeon: String(localized: "Dungeon")
        }
    }
}

struct ChallengeView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("challengeMode") private var mode: ChallengeMode = .stage
    /// A legendary opened from its branch station, shown over the line.
    @State private var legend: String?

    var body: some View {
        VStack(spacing: 5) {
            ModePicker(mode: $mode)
            ZStack {
                switch mode {
                case .stage:
                    StageLineView(openLegend: { id in withAnimation(.smooth(duration: 0.25)) { legend = id } },
                                  openGym: { withAnimation(.smooth(duration: 0.2)) { mode = .gym } },
                                  openDungeon: { withAnimation(.smooth(duration: 0.2)) { mode = .dungeon } })
                case .gym:
                    BossVSView()
                case .dungeon:
                    DungeonView()
                }
                if mode == .stage, let legend, let spot = app.adventure.data?.legend(legend) {
                    LegendVSView(spot: spot) { withAnimation(.smooth(duration: 0.25)) { self.legend = nil } }
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .pokoveDebugChallengeMode)) { note in
            guard let raw = note.object as? String else { return }
            if let value = ChallengeMode(rawValue: raw) { mode = value; legend = nil }
            if raw.hasPrefix("legend:") { mode = .stage; legend = String(raw.dropFirst(7)) }
        }
        #endif
    }
}

private struct ModePicker: View {
    @Binding var mode: ChallengeMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ChallengeMode.allCases, id: \.self) { item in
                Button {
                    withAnimation(.smooth(duration: 0.2)) { mode = item }
                } label: {
                    Text(item.title)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(mode == item ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 15)
                        .background(mode == item ? .white.opacity(0.17) : .clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(1.5)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 6.5, style: .continuous))
    }
}

// MARK: Stage line

/// A chapter as a subway line: ten stations and the boss at the end, the party leader hopping
/// above the station it's on. A cleared station can be picked to repeat.
private struct StageLineView: View {
    let openLegend: (String) -> Void
    let openGym: () -> Void
    let openDungeon: () -> Void

    @Environment(AppModel.self) private var app
    @AppStorage("adventurePane") private var pane: AdventurePane = .challenge
    /// The chapter on screen, when browsing back; nil follows the journey.
    @State private var browsing: Int?
    @State private var selected: StationPoint?

    private static let lineY: CGFloat = 52
    private static let inset: CGFloat = 11

    var body: some View {
        let adventure = app.adventure
        let chapters = adventure.chapters
        let progress = adventure.progress
        let index = min(browsing ?? progress.chapter, chapters.count - 1)
        let chapter = chapters[index]
        GeometryReader { proxy in
            let width = proxy.size.width
            let step = (width - Self.inset * 2) / CGFloat(Chapter.stationCount)
            let x = { (station: Int) in Self.inset + CGFloat(station) * step }
            ZStack(alignment: .topLeading) {
                header(chapter: chapter, index: index)
                    .frame(width: width)

                line(chapter: chapter, index: index, width: width, x: x)

                footer(chapter: chapter, index: index)
                    .frame(width: width)
                    .position(x: width / 2, y: proxy.size.height - 11)
            }
        }
        .onChange(of: progress.chapter) { browsing = nil; selected = nil }
    }

    // MARK: Header

    private func header(chapter: Chapter, index: Int) -> some View {
        let adventure = app.adventure
        let progress = adventure.progress
        return HStack(spacing: 3) {
            chevron("chevron.left", enabled: index > 0) { browse(index - 1) }
            Text("Chapter \(chapter.number)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            chevron("chevron.right", enabled: index < progress.chapter) { browse(index + 1) }
            Spacer(minLength: 4)
            if chapter.isLeague, index == progress.chapter {
                Text("Elite Four \(min(progress.boss, 4))/4")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                Text("Badges \(progress.badges)/8")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 2)
    }

    private func chevron(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 8.5, weight: .heavy))
                .foregroundStyle(.white.opacity(enabled ? 0.55 : 0.12))
                .frame(width: 13, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func browse(_ index: Int) {
        withAnimation(.smooth(duration: 0.25)) {
            browsing = index == app.adventure.progress.chapter ? nil : index
            selected = nil
        }
    }

    // MARK: Line

    @ViewBuilder
    private func line(chapter: Chapter, index: Int, width: CGFloat, x: @escaping (Int) -> CGFloat) -> some View {
        let adventure = app.adventure
        let progress = adventure.progress
        let cleared = progress.cleared(in: index)
        let here = adventure.target.flatMap { target -> StationPoint? in
            if case .station(let point) = target { return point }
            return nil
        } ?? adventure.stationPoint
        let isHere = here.chapter == index && !adventure.isChallenging
        let terminal = x(Chapter.stationCount)
        let doneEnd = cleared >= Chapter.stationCount ? terminal : x(cleared)

        // Track, with the cleared part in the line's color.
        Capsule().fill(.white.opacity(0.14))
            .frame(width: terminal - x(0), height: 5)
            .position(x: (x(0) + terminal) / 2, y: Self.lineY)
        Capsule().fill(Self.lineColor)
            .frame(width: max(5, doneEnd - x(0)), height: 5)
            .position(x: (x(0) + doneEnd) / 2, y: Self.lineY)

        if let legend = chapter.legend {
            LegendBranch(spot: legend, reached: progress.hasReached(chapter: index)) { openLegend(legend.id) }
                .position(x: (x(4) + x(5)) / 2, y: Self.lineY + 23)
        }

        ForEach(0..<Chapter.stationCount, id: \.self) { station in
            let point = StationPoint(chapter: index, station: station)
            let state: StationDot.State = station < cleared ? .cleared : (station == cleared ? .frontier : .ahead)
            Button {
                withAnimation(.smooth(duration: 0.2)) { selected = selected == point ? nil : point }
            } label: {
                VStack(spacing: 3) {
                    StationDot(state: state, isHere: isHere && here.station == station, isSelected: selected == point)
                        .frame(height: 18)
                    Text("\(station + 1)")
                        .font(.system(size: 9, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(isHere && here.station == station ? Color(hex: 0xFFD35A) : .white.opacity(0.42))
                }
                .frame(width: 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(state == .ahead)
            .position(x: x(station), y: Self.lineY + 7)
        }

        Terminal(chapter: chapter, index: index) { openGym() }
            .position(x: terminal, y: Self.lineY + 7)

        if isHere, let leader = adventure.leader {
            HoppingIcon(speciesID: leader.speciesID, training: progress.isTraining || progress.repeating != nil)
                .position(x: x(here.station), y: Self.lineY - 19)
                .animation(.smooth(duration: 0.4), value: here)
                .allowsHitTesting(false)
        }
    }

    static let lineColor = Color(hex: 0x3DBB6A)

    // MARK: Footer

    @ViewBuilder
    private func footer(chapter: Chapter, index: Int) -> some View {
        let adventure = app.adventure
        let progress = adventure.progress
        HStack(spacing: 5) {
            if let selected, selected.chapter == index {
                let level = adventure.foeLevel(chapter.stations[selected.station])
                Text("\(chapter.number)-\(selected.station + 1)").font(.system(size: 9.5, weight: .heavy).monospacedDigit())
                Text(selected.station == Chapter.stationCount - 1 ? "2 wild Pokémon · Lv \(level)" : "1 wild Pokémon · Lv \(level)")
                    .foregroundStyle(.white.opacity(0.5))
                Spacer(minLength: 2)
                if progress.repeating == selected {
                    pill(String(localized: "Move On"), symbol: "arrow.forward") { adventure.resumeJourney(); self.selected = nil }
                } else if progress.isCleared(selected) {
                    pill(String(localized: "Repeat"), symbol: "repeat") { adventure.repeatStation(selected); self.selected = nil }
                }
            } else if let repeating = progress.repeating {
                Image(systemName: "repeat").foregroundStyle(Color(hex: 0x7FC8FF))
                Text("Repeating \(repeating.chapter + 1)-\(repeating.station + 1)").foregroundStyle(Color(hex: 0x7FC8FF))
                Spacer(minLength: 2)
                pill(String(localized: "Move On"), symbol: "arrow.forward") { adventure.resumeJourney() }
            } else if adventure.isChallenging {
                Image(systemName: "bolt.fill").foregroundStyle(Color(hex: 0xFFD35A))
                Text("A challenge is underway").foregroundStyle(.white.opacity(0.7))
                Spacer(minLength: 0)
            } else if progress.isTraining, let boss = adventure.nextBoss, progress.isBossOpen(adventure.chapters) {
                // Training after a loss: how far along, what level would do it, and a quicker way there.
                Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(Color(hex: 0x7FC8FF))
                Text("Training \(AutoChallenge.trainingClears - progress.training)/\(AutoChallenge.trainingClears)")
                    .foregroundStyle(Color(hex: 0x7FC8FF))
                    .monospacedDigit()
                    .fixedSize()
                Text("· \(shortHint(adventure) ?? GuideText.chance(boss.trainer.name, adventure.readiness ?? 0))")
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                if let fix = fix(adventure) { fixPill(fix) }
            } else if let boss = adventure.nextBoss, progress.isBossOpen(adventure.chapters), index == progress.chapter {
                let chance = adventure.readiness ?? 0
                if chance >= Guidance.goodChance {
                    Image(systemName: "flag.checkered").foregroundStyle(Color(hex: 0xFFD35A))
                    Text(GuideText.chance(boss.trainer.name, chance)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                    Spacer(minLength: 2)
                    pill("VS", symbol: "bolt.fill", primary: true) { openGym() }
                } else {
                    // Not ready: the level that would do it, and the quickest way to get stronger.
                    Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(Color(hex: 0xFF9E6B))
                    Text(longHint(adventure) ?? String(localized: "\(boss.trainer.name) is waiting"))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 2)
                    if let fix = fix(adventure) {
                        fixPill(fix)
                    } else {
                        pill("VS", symbol: "bolt.fill", primary: true) { openGym() }
                    }
                }
            } else if index == progress.chapter, adventure.nextBoss == nil {
                Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.white.opacity(0.6))
                Text("Looping the last line").foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
            } else if index == progress.chapter, let boss = adventure.nextBoss {
                // On the line: how far to the boss, or that it waits for an agent; a pull when there's one.
                let station = chapter.stations[adventure.stationPoint.station]
                Image(systemName: adventure.isBattling ? "play.fill" : "moon.zzz.fill")
                    .foregroundStyle(adventure.isBattling ? Color(hex: 0xFFD35A) : .white.opacity(0.5))
                Text(adventure.isBattling ? GuideText.stationsTo(boss.trainer.name, adventure.stationsLeft) : GuideText.resting)
                    .foregroundStyle(.white.opacity(adventure.isBattling ? 0.8 : 0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                if adventure.hasGachaWaiting {
                    fixPill(.gacha)
                } else if adventure.isBattling {
                    Text("Lv \(adventure.foeLevel(station))")
                        .font(.system(size: 8.5, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.4))
                }
            } else {
                Image(systemName: "checkmark").foregroundStyle(Self.lineColor)
                Text("Cleared · pick a station to repeat it").foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .font(.system(size: 9.5, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    // MARK: Next step

    /// A quicker way to get stronger than waiting: a better team from the box, today's dungeon, a pull.
    private enum Fix { case bestTeam, dungeon(DungeonTier), gacha }

    private func fix(_ adventure: AdventureService) -> Fix? {
        if adventure.hasBetterTeam { return .bestTeam }
        if let tier = adventure.openDungeonTier { return .dungeon(tier) }
        if adventure.hasGachaWaiting { return .gacha }
        return nil
    }

    @ViewBuilder
    private func fixPill(_ fix: Fix) -> some View {
        switch fix {
        case .bestTeam:
            pill(GuideText.bestTeam, symbol: "hand.thumbsup.fill", primary: true) { app.adventure.recommendParty() }
        case .dungeon(let tier):
            pill(GuideText.dungeon(tier.title), symbol: "door.left.hand.open", primary: true) { openDungeon() }
        case .gacha:
            pill(GuideText.gacha, symbol: "sparkles", primary: true) { pane = .gacha }
        }
    }

    /// "Lv 18이면 이길 확률 90%", or "상한 Lv 23이어도 20%".
    private func longHint(_ adventure: AdventureService) -> String? {
        guard let hint = adventure.levelHint else { return nil }
        return hint.atCap ? GuideText.evenAtCap(hint.level, hint.chance) : GuideText.needLevel(hint.level, hint.chance)
    }

    private func shortHint(_ adventure: AdventureService) -> String? {
        guard let hint = adventure.levelHint else { return nil }
        return hint.atCap ? GuideText.evenAtCap(hint.level, hint.chance) : GuideText.needLevelShort(hint.level, hint.chance)
    }

    private func pill(_ title: String, symbol: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) { action() }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 7, weight: .bold))
                Text(title).font(.system(size: 8.5, weight: .heavy))
            }
            .foregroundStyle(primary ? .black : .white.opacity(0.9))
            .padding(.horizontal, 7)
            .frame(height: 16)
            .fixedSize()
            .background(primary ? Color(hex: 0xFFD35A) : .white.opacity(0.14), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct StationDot: View {
    enum State { case cleared, frontier, ahead }
    let state: State
    let isHere: Bool
    let isSelected: Bool

    @State private var pulse = false

    var body: some View {
        ZStack {
            if isHere {
                Circle().fill(Color(hex: 0xFFD35A).opacity(pulse ? 0.08 : 0.35)).frame(width: pulse ? 22 : 16, height: pulse ? 22 : 16)
                Circle().fill(Color(hex: 0xFFD35A)).frame(width: 14, height: 14)
                Circle().strokeBorder(.white, lineWidth: 3).frame(width: 15, height: 15)
            } else {
                switch state {
                case .cleared:
                    Circle().fill(StageLineView.lineColor).frame(width: 12, height: 12)
                    Circle().strokeBorder(Color(hex: 0x1E7A41), lineWidth: 2.5).frame(width: 12, height: 12)
                case .frontier, .ahead:
                    Circle().fill(.black).frame(width: 12, height: 12)
                    Circle().strokeBorder(.white.opacity(state == .frontier ? 0.6 : 0.28), lineWidth: 2.5).frame(width: 12, height: 12)
                }
            }
            if isSelected {
                Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1).frame(width: 18, height: 18)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

/// The end of the line: the gym badge at stake, the League's crown, or a loop after the League.
private struct Terminal: View {
    let chapter: Chapter
    let index: Int
    let action: () -> Void

    @Environment(AppModel.self) private var app

    var body: some View {
        let progress = app.adventure.progress
        let done = index < progress.chapter || (chapter.isLeague && progress.isChampion)
        let open = index == progress.chapter && progress.isBossOpen(app.adventure.chapters)
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(hex: 0x2E2819))
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(open ? Color(hex: 0xFFD35A) : Color(hex: 0xB8A038).opacity(0.7), lineWidth: open ? 2 : 1.5)
                    if let badge = chapter.badge {
                        BadgeImageView(number: badge, size: 17, earned: done, unearnedColor: .white.opacity(0.3))
                    } else if chapter.isLeague {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(done ? Color(hex: 0xFFD35A) : .white.opacity(0.4))
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(width: 23, height: 23)
                Text(label)
                    .font(.system(size: 7.5, weight: .heavy))
                    .foregroundStyle(open ? Color(hex: 0xFFD35A) : .white.opacity(0.45))
                    .lineLimit(1)
                    .fixedSize()
            }
            .offset(y: 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(chapter.bosses.isEmpty)
        .help(chapter.bosses.map(\.name).joined(separator: ", "))
    }

    private var label: String {
        if chapter.isLeague { return String(localized: "League") }
        return chapter.bosses.first?.name ?? String(localized: "Loop")
    }
}

/// A legendary's branch off the line: a short spur down to a star.
private struct LegendBranch: View {
    let spot: LegendSpot
    let reached: Bool
    let action: () -> Void

    @Environment(AppModel.self) private var app
    @State private var glow = false

    var body: some View {
        let beaten = app.adventure.progress.beatenLegends.contains(spot.id)
        VStack(spacing: 0) {
            Rectangle().fill(StageLineView.lineColor.opacity(reached ? 0.8 : 0.25)).frame(width: 2.5, height: 12)
            Button(action: action) {
                ZStack {
                    Circle().fill(Color(hex: 0x241C08))
                    Circle().strokeBorder(Color(hex: 0xFFD35A).opacity(reached ? 1 : 0.3), lineWidth: 1.5)
                    if beaten {
                        PokeIconView(id: spot.species, pixelSize: 0.5)
                    } else {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(Color(hex: 0xFFD35A).opacity(reached ? 1 : 0.35))
                            .shadow(color: Color(hex: 0xFFD35A).opacity(glow && reached ? 0.9 : 0), radius: 3)
                    }
                }
                .frame(width: 17, height: 17)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!reached)
        }
        .offset(y: 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { glow = true }
        }
        .help(reached ? (app.adventure.dex.species(spot.species)?.name ?? "") : String(localized: "Not yet reached"))
    }
}

/// The party leader, hopping (or bobbing while it trains) above its station.
private struct HoppingIcon: View {
    let speciesID: Int
    let training: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let hop = reduceMotion ? 0 : -abs(sin(time * (training ? 5 : 3.2))) * (training ? 1.5 : 3)
            PokeIconView(id: speciesID, pixelSize: 1)
                .offset(y: (hop * 2).rounded() / 2)
        }
        .frame(width: 40, height: 30)
    }
}

// MARK: VS

/// The games' trainer-battle intro, as a card: the party on the left, the opponent on a band of
/// its color on the right, what's at stake in the middle, and the win chance and button below.
private struct VSCard<Opponent: View, Stake: View, Actions: View>: View {
    let color: Color
    let name: String
    let title: String
    let team: [Int]
    let chance: Double?
    /// Why the chance is what it is, on its own row above the bar.
    var hint: String?
    @ViewBuilder let opponent: Opponent
    @ViewBuilder let stake: Stake
    @ViewBuilder let actions: Actions

    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        GeometryReader { proxy in
            let size = proxy.size
            let bar: CGFloat = hint == nil ? 27 : 38
            ZStack(alignment: .topLeading) {
                VSBackground(color: color)

                HStack(spacing: -4) {
                    ForEach(adventure.party) { member in PokeIconView(id: member.speciesID, pixelSize: 0.5) }
                }
                .padding(.leading, 3)
                .padding(.top, 2)

                if let leader = adventure.leader {
                    PokeSpriteView(id: leader.speciesID, pixelSize: 1, back: true, fitHeight: 52)
                        .frame(width: 78, height: 56, alignment: .bottom)
                        .position(x: 42, y: size.height - bar - 30)
                }

                opponent
                    .position(x: size.width - 58, y: 44)

                VStack(alignment: .trailing, spacing: -1) {
                    ForEach(Array(team.enumerated()), id: \.offset) { _, species in PokeIconView(id: species, pixelSize: 0.5) }
                }
                .frame(width: size.width - 2, alignment: .trailing)
                .padding(.top, 1)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(name)
                        .font(.system(size: 14, weight: .black).italic())
                        .foregroundStyle(.white)
                        .shadow(color: .black, radius: 0, x: 1.2, y: 1.2)
                    Text(title)
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.9), radius: 0, x: 0.8, y: 0.8)
                }
                .lineLimit(1)
                .frame(width: size.width - 8, alignment: .trailing)
                .position(x: size.width / 2, y: size.height - bar - 17)

                stake
                    .position(x: size.width / 2 + 1, y: 17)

                Text("VS")
                    .font(.system(size: 22, weight: .black, design: .rounded).italic())
                    .foregroundStyle(Color(hex: 0xFFD35A))
                    .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .position(x: size.width / 2 + 1, y: 50)

                VStack(spacing: 0) {
                    if let hint {
                        Text(hint)
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 11)
                            .padding(.top, 3)
                    }
                    HStack(spacing: 5) {
                        VStack(alignment: .leading, spacing: -1) {
                            Text("To win").font(.system(size: 7.5, weight: .bold)).foregroundStyle(.white.opacity(0.6))
                            Text(chance.map { "\(Int(($0 * 100).rounded()))%" } ?? "–")
                                .font(.system(size: 14, weight: .black).italic().monospacedDigit())
                                .foregroundStyle(Self.chanceColor(chance))
                                .contentTransition(.numericText())
                        }
                        Spacer(minLength: 2)
                        actions
                    }
                    .frame(height: hint == nil ? 27 : 24)
                }
                .padding(.horizontal, 7)
                .frame(width: size.width, height: bar)
                .background(.black.opacity(0.72))
                .position(x: size.width / 2, y: size.height - bar / 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    static func chanceColor(_ chance: Double?) -> Color {
        guard let chance else { return .white.opacity(0.5) }
        return chance >= 0.6 ? Color(hex: 0x7EE08F) : (chance >= 0.3 ? Color(hex: 0xFFD35A) : Color(hex: 0xFF8A70))
    }
}

/// Navy for the party, the opponent's color on a diagonal band, a white slash and speed lines.
struct VSBackground: View {
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                let w = size.width, h = size.height
                func band(_ top: CGFloat, _ bottom: CGFloat) -> Path {
                    var path = Path()
                    path.move(to: CGPoint(x: w * top, y: 0))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w * bottom, y: h))
                    path.closeSubpath()
                    return path
                }
                canvas.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x14203A)))
                canvas.fill(band(0.56, 0.38), with: .color(color.opacity(0.62)))
                canvas.fill(band(0.62, 0.44), with: .color(color))
                // Speed lines streaking left across the opponent's band.
                canvas.clip(to: band(0.62, 0.44))
                let lines: [(y: CGFloat, length: CGFloat, speed: Double, phase: Double)] = [
                    (0.22, 34, 150, 0), (0.36, 22, 190, 0.4), (0.55, 30, 130, 0.7), (0.68, 18, 210, 0.2), (0.12, 16, 170, 0.9),
                ]
                for line in lines {
                    let span = w * 0.7 + line.length
                    let travel = (time * line.speed / Double(span) + line.phase).truncatingRemainder(dividingBy: 1)
                    let x = w + line.length - CGFloat(travel) * span
                    canvas.fill(Path(roundedRect: CGRect(x: x, y: h * line.y, width: line.length, height: 1.5), cornerRadius: 0.75),
                                with: .color(.white.opacity(0.4)))
                }
            }
            .overlay {
                Canvas { canvas, size in
                    var slash = Path()
                    slash.move(to: CGPoint(x: size.width * 0.59, y: 0))
                    slash.addLine(to: CGPoint(x: size.width * 0.41, y: size.height))
                    canvas.stroke(slash, with: .color(.white), lineWidth: 2.5)
                }
                .shadow(color: .white.opacity(0.7), radius: 3)
            }
        }
    }
}

/// The glowing button that starts a challenge.
private struct GoButton: View {
    let title: String
    let action: () -> Void

    @State private var glow = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: "bolt.fill").font(.system(size: 8, weight: .black))
                Text(title).font(.system(size: 11, weight: .black).italic())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .frame(height: 19)
            .background(Color(hex: 0xFF5A4E), in: Capsule())
            .overlay(Capsule().strokeBorder(.white, lineWidth: 1.5))
            .shadow(color: Color(hex: 0xFF5A4E).opacity(glow ? 0.9 : 0.25), radius: glow ? 6 : 2)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

/// A quiet state in place of the button: locked, underway, or done.
private struct VSNote: View {
    let symbol: String
    let text: String
    var tint: Color = .white.opacity(0.7)

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 8, weight: .bold))
            Text(text).font(.system(size: 9, weight: .heavy)).lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .frame(height: 19)
        .background(.white.opacity(0.1), in: Capsule())
    }
}

private struct BestTeamButton: View {
    let goal: BattleTarget

    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        // Lit when it would change the party for the next boss.
        let better = adventure.hasBetterTeam && adventure.nextBoss.map { BattleTarget.boss(chapter: $0.chapter, index: $0.index) } == goal
        Button {
            withAnimation(.smooth(duration: 0.25)) { adventure.recommendParty(for: goal) }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "hand.thumbsup.fill").font(.system(size: 7.5, weight: .bold))
                // The short label, so the Challenge button keeps its room.
                Text(GuideText.recommend).font(.system(size: 8.5, weight: .heavy))
            }
            .foregroundStyle(better ? .black : .white.opacity(0.9))
            .padding(.horizontal, 6)
            .frame(height: 19)
            .background(better ? Color(hex: 0xFFD35A) : .white.opacity(0.16), in: Capsule())
            .contentShape(Capsule())
            .fixedSize()
        }
        .buttonStyle(.plain)
        .disabled(app.adventure.owned.count < 2 || app.adventure.isChallenging)
        .help("Best team for this fight")
    }
}

/// The next boss (or any other, browsing), as a VS screen.
private struct BossVSView: View {
    @Environment(AppModel.self) private var app
    /// A boss picked with the arrows; nil shows the next one.
    @State private var browsing: Int?

    private struct Entry: Equatable {
        let chapter: Int
        let index: Int
        let trainer: Trainer
    }

    var body: some View {
        let adventure = app.adventure
        let progress = adventure.progress
        let entries = adventure.chapters.enumerated().flatMap { chapter, info in
            info.bosses.enumerated().map { Entry(chapter: chapter, index: $0.offset, trainer: $0.element) }
        }
        let nextIndex = entries.firstIndex { $0.chapter == progress.chapter && $0.index == progress.boss } ?? entries.count - 1
        let shown = min(browsing ?? nextIndex, entries.count - 1)
        let entry = entries[shown]
        let goal = BattleTarget.boss(chapter: entry.chapter, index: entry.index)
        let beaten = shown < nextIndex || progress.isChampion && entry.trainer.isChampion
        let isNext = shown == nextIndex && !beaten
        let running = adventure.target == goal && adventure.isChallenging
        VSCard(color: entry.trainer.specialty?.color ?? Color(hex: 0xC8A040),
               name: entry.trainer.name, title: entry.trainer.title,
               team: entry.trainer.battleTeam.map(\.species),
               chance: beaten ? nil : adventure.winChance(goal),
               hint: beaten || running ? nil : hint(isNext: isNext)) {
            TrainerSpriteView(slug: entry.trainer.sprite, pixelSize: 1)
                .frame(width: 80, height: 80)
                .id(entry.trainer.id)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } stake: {
            ZStack {
                Circle().fill(.black.opacity(0.6))
                Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1.5)
                if let badge = entry.trainer.badge {
                    BadgeImageView(number: badge, size: 17, earned: beaten, unearnedColor: .white.opacity(0.45))
                } else {
                    Image(systemName: entry.trainer.isChampion ? "crown.fill" : "\(entry.index + 1).circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(beaten ? Color(hex: 0xFFD35A) : .white.opacity(0.55))
                }
            }
            .frame(width: 25, height: 25)
        } actions: {
            arrows(shown: shown, count: entries.count)
            if beaten {
                VSNote(symbol: "checkmark", text: entry.trainer.badge.map { _ in String(localized: "Badge earned") } ?? String(localized: "Beaten"),
                       tint: Color(hex: 0x7EE08F))
            } else if running {
                VSNote(symbol: "bolt.fill", text: String(localized: "Battling…"), tint: Color(hex: 0xFFD35A))
            } else if isNext, progress.isBossOpen(adventure.chapters) {
                BestTeamButton(goal: goal)
                GoButton(title: String(localized: "Challenge!")) { adventure.challengeBoss() }
                    .disabled(adventure.isChallenging)
            } else if isNext {
                BestTeamButton(goal: goal)
                VSNote(symbol: "lock.fill", text: String(localized: "\(adventure.stationsLeft) stations left"))
            } else {
                VSNote(symbol: "lock.fill", text: String(localized: "Chapter \(entry.chapter + 1)"))
            }
        }
        .onChange(of: nextIndex) { browsing = nil }
        .animation(.smooth(duration: 0.25), value: shown)
    }

    /// The level the party needs for the next boss; short, since "To win" sits right below it.
    private func hint(isNext: Bool) -> String? {
        guard isNext, let hint = app.adventure.levelHint else { return nil }
        return hint.atCap ? GuideText.evenAtCap(hint.level, hint.chance) : GuideText.needLevelShort(hint.level, hint.chance)
    }

    private func arrows(shown: Int, count: Int) -> some View {
        HStack(spacing: 0) {
            arrow("chevron.left", enabled: shown > 0) { browsing = shown - 1 }
            arrow("chevron.right", enabled: shown < count - 1) { browsing = shown + 1 }
        }
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(.white.opacity(enabled ? 0.6 : 0.15))
                .frame(width: 14, height: 19)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// A legendary on its branch, as a VS screen over the line.
private struct LegendVSView: View {
    let spot: LegendSpot
    let close: () -> Void

    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        let species = adventure.dex.species(spot.species)
        let beaten = adventure.progress.beatenLegends.contains(spot.id)
        let goal = BattleTarget.legend(spot.id)
        let running = adventure.target == goal && adventure.isChallenging
        VSCard(color: species?.types.first?.color ?? Color(hex: 0xC8A040),
               name: species?.name ?? "", title: String(localized: "Legendary · Lv \(spot.level)"),
               team: [], chance: beaten ? nil : adventure.winChance(goal)) {
            PokeSpriteView(id: spot.species, pixelSize: 1, fitHeight: 58)
                .frame(width: 84, height: 62, alignment: .bottom)
        } stake: {
            ZStack {
                Circle().fill(.black.opacity(0.6))
                Circle().strokeBorder(Color(hex: 0xFFD35A).opacity(0.7), lineWidth: 1.5)
                Image(systemName: "star.fill").font(.system(size: 10, weight: .black)).foregroundStyle(Color(hex: 0xFFD35A))
            }
            .frame(width: 25, height: 25)
        } actions: {
            if beaten {
                VSNote(symbol: "checkmark", text: String(localized: "Joined your team"), tint: Color(hex: 0x7EE08F))
            } else if running {
                VSNote(symbol: "bolt.fill", text: String(localized: "Battling…"), tint: Color(hex: 0xFFD35A))
            } else if !adventure.isLegendOpen(spot) {
                VSNote(symbol: "lock.fill", text: String(localized: "Not yet reached"))
            } else {
                BestTeamButton(goal: goal)
                GoButton(title: String(localized: "Challenge!")) { adventure.challengeLegend(spot.id) }
                    .disabled(adventure.isChallenging)
            }
        }
        .overlay(alignment: .topLeading) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 16, height: 16)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 60)
            .padding(.top, 3)
        }
    }
}

// MARK: Dungeon

/// Today's dungeon: three tiers, each paying once until 04:00.
private struct DungeonView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        let types = adventure.dungeonTypes
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Text("Today's dungeon")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.white)
                ForEach(types, id: \.self) { PokeTypeBadge(type: $0, compact: true) }
                Spacer(minLength: 2)
                Text("Resets at 4:00")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.42))
            }
            .padding(.horizontal, 2)
            ForEach(DungeonTier.allCases, id: \.self) { tier in
                TierRow(tier: tier)
            }
            Text("5 floors · a boss on the last · lose and try again")
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
                .padding(.horizontal, 2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct TierRow: View {
    let tier: DungeonTier

    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        let claimed = adventure.isClaimed(tier)
        let running = adventure.target == .dungeon(tier) && adventure.isChallenging
        HStack(spacing: 6) {
            Text(tier.title)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(claimed ? .white.opacity(0.5) : .white)
                .frame(width: 36, alignment: .leading)
            Text("Lv \(adventure.dungeonLevel(tier))")
                .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(claimed ? 0.35 : 0.6))
            Spacer(minLength: 2)
            if claimed {
                Label("Claimed", systemImage: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x7EE08F))
            } else {
                reward
                if running, let battle = adventure.battle {
                    Text("Floor \(min(battle.foeIndex + 1, DailyDungeon.floors))/\(DailyDungeon.floors)")
                        .font(.system(size: 9, weight: .heavy).monospacedDigit())
                        .foregroundStyle(Color(hex: 0xFFD35A))
                        .frame(height: 17)
                } else {
                    Button {
                        withAnimation(.smooth(duration: 0.25)) { adventure.enterDungeon(tier) }
                    } label: {
                        Text("Enter")
                            .font(.system(size: 9.5, weight: .heavy))
                            .foregroundStyle(tier == .normal ? .black : .white)
                            .padding(.horizontal, 9)
                            .frame(height: 17)
                            .background(tier == .normal ? Color(hex: 0xFFD35A) : .white.opacity(0.15), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(adventure.isChallenging)
                    .opacity(adventure.isChallenging ? 0.4 : 1)
                }
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 5)
        .frame(height: 24)
        .background(.white.opacity(running ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color(hex: 0xFFD35A).opacity(running ? 0.6 : 0)))
    }

    @ViewBuilder
    private var reward: some View {
        if let stardust = DailyDungeon.stardust[tier] {
            HStack(spacing: 3) {
                StardustIcon(size: 10)
                Text("\(stardust)").font(.system(size: 9, weight: .bold).monospacedDigit())
            }
            .foregroundStyle(.white.opacity(0.75))
        } else {
            ItemSpriteView(slug: "ultra-ball", pixelSize: 0.6)
                .frame(width: 14, height: 14)
                .help("An Ultra Ball: three balls, all rare or better")
        }
    }
}

extension DungeonTier {
    var title: String {
        switch self {
        case .easy: String(localized: "Easy")
        case .normal: String(localized: "Normal")
        case .hard: String(localized: "Hard")
        }
    }
}

// MARK: Stardust

/// PokéAPI's Stardust item, the adventure's currency, fit to a square.
struct StardustIcon: View {
    var size: CGFloat = 11

    @State private var image: PokeImage?

    var body: some View {
        let shown = image ?? PokeSpriteCache.shared.cached(key: "item-stardust")
        Group {
            if let shown {
                Image(decorative: shown.frames[0], scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Circle().fill(Color(hex: 0xE8D8A0).opacity(0.5)).padding(size * 0.15)
            }
        }
        .frame(width: size, height: size)
        .task { image = await PokeSpriteCache.shared.item("stardust") }
    }
}
