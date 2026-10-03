import SwiftUI

/// The ways to take the journey on: the stage line agents push along, the gyms, the daily dungeons,
/// and the tower after the Champion.
enum ChallengeMode: String, CaseIterable {
    case stage, gym, dungeon, tower

    var title: String {
        switch self {
        case .stage: String(localized: "Stages")
        case .gym: String(localized: "Gym")
        case .dungeon: String(localized: "Dungeon")
        case .tower: String(localized: "Tower")
        }
    }
}

struct ChallengeView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("challengeMode") private var mode: ChallengeMode = .stage
    /// A legendary opened from its branch station, shown over the line.
    @State private var legend: String?

    var body: some View {
        // The tower is per region, so a region without its Champion yet shows the line instead.
        let shown = mode == .tower && !app.adventure.progress.isChampion ? .stage : mode
        VStack(spacing: 5) {
            ModePicker(mode: $mode, shown: shown)
            ZStack {
                switch shown {
                case .stage:
                    StageLineView(openLegend: { id in withAnimation(.smooth(duration: 0.25)) { legend = id } },
                                  openGym: { withAnimation(.smooth(duration: 0.2)) { mode = .gym } },
                                  openDungeon: { withAnimation(.smooth(duration: 0.2)) { mode = .dungeon } })
                case .gym:
                    BossVSView()
                case .dungeon:
                    DungeonView()
                case .tower:
                    TowerView()
                }
                if shown == .stage, let legend, let spot = app.adventure.data?.legend(legend) {
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
    /// The mode on screen, which falls back from the tower where it isn't open.
    let shown: ChallengeMode
    @Environment(AppModel.self) private var app

    var body: some View {
        // The tower opens after the Champion.
        let modes = ChallengeMode.allCases.filter { $0 != .tower || app.adventure.progress.isChampion }
        HStack(spacing: 0) {
            ForEach(modes, id: \.self) { item in
                Button {
                    withAnimation(.smooth(duration: 0.2)) { mode = item }
                } label: {
                    Text(item.title)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(shown == item ? .white : .white.opacity(0.5))
                        .overlay(alignment: .topTrailing) {
                            // A gym is open and waiting.
                            if item == .gym, waitingGym != nil {
                                Circle().fill(Color(hex: 0xFFD35A)).frame(width: 4.5, height: 4.5).offset(x: 5, y: -1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 15)
                        .background(shown == item ? .white.opacity(0.17) : .clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item == .gym ? waitingGym ?? "" : "")
            }
        }
        .padding(1.5)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 6.5, style: .continuous))
    }

    /// "Brock is waiting", while a gym is open and nothing else is being fought.
    private var waitingGym: String? {
        let adventure = app.adventure
        guard adventure.progress.isBossOpen(adventure.chapters), !adventure.isChallenging, let boss = adventure.nextBoss else { return nil }
        return String(localized: "\(boss.trainer.name) is waiting")
    }
}

// MARK: Regions

/// Where the journey is, once there's more than Kanto: each region keeps its own party and progress.
private struct RegionMenu: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        Menu {
            ForEach(Region.allCases.filter(adventure.isOpen), id: \.self) { region in
                Button {
                    withAnimation(.smooth(duration: 0.3)) { adventure.travel(to: region) }
                } label: {
                    if region == adventure.region {
                        Label(region.name, systemImage: "checkmark")
                    } else {
                        Text(region.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(adventure.region.name)
                    .font(.system(size: 9.5, weight: .heavy))
                Image(systemName: "chevron.down")
                    .font(.system(size: 6.5, weight: .heavy))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 6)
            .frame(height: 17)
            .background(.white.opacity(0.13), in: Capsule())
            .overlay(alignment: .topTrailing) {
                // A region opened and not yet visited.
                if adventure.hasUnvisitedRegion {
                    Circle().fill(Color(hex: 0xFFD35A)).frame(width: 5, height: 5).offset(x: 1, y: -1)
                }
            }
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .disabled(adventure.isChallenging)
        .help(adventure.isChallenging ? String(localized: "Battling…") : "")
    }
}

// MARK: Stage line

/// A chapter as a subway line: ten stations, the last one a terminus with tougher Pokémon, the party
/// leader hopping above the station it's on. A cleared station can be picked to repeat.
private struct StageLineView: View {
    let openLegend: (String) -> Void
    let openGym: () -> Void
    let openDungeon: () -> Void

    @Environment(AppModel.self) private var app
    @AppStorage("adventurePane") private var pane: AdventurePane = .challenge
    /// The chapter on screen, when browsing back; nil follows the party.
    @State private var browsing: Int?
    @State private var selected: StationPoint?

    private static let lineY: CGFloat = 52
    private static let inset: CGFloat = 11

    var body: some View {
        let adventure = app.adventure
        let chapters = adventure.chapters
        let index = min(browsing ?? current, chapters.count - 1)
        let chapter = chapters[index]
        GeometryReader { proxy in
            let width = proxy.size.width
            let step = (width - Self.inset * 2) / CGFloat(Chapter.stationCount - 1)
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
        .onChange(of: app.adventure.progress.chapter) { browsing = nil; selected = nil }
    }

    /// Where the party is on the line: a station while it fights one, else the one lined up.
    private var here: StationPoint {
        let adventure = app.adventure
        if case .station(let point) = adventure.target { return point }
        return adventure.stationPoint
    }

    /// The chapter the party is on. It can be the one before the line's, while the party works up
    /// to the next chapter's first station.
    private var current: Int { min(here.chapter, app.adventure.progress.chapter) }

    // MARK: Header

    private func header(chapter: Chapter, index: Int) -> some View {
        let adventure = app.adventure
        let progress = adventure.progress
        return HStack(spacing: 3) {
            if adventure.hasRegionChoice { RegionMenu() }
            chevron("chevron.left", enabled: index > 0) { browse(index - 1) }
            Text("Chapter \(chapter.number)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            chevron("chevron.right", enabled: index < progress.chapter) { browse(index + 1) }
            Spacer(minLength: 4)
            if chapter.isLeague, progress.badges >= 8, !progress.isChampion, progress.boss > 0 {
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
            browsing = index == current ? nil : index
            selected = nil
        }
    }

    // MARK: Line

    @ViewBuilder
    private func line(chapter: Chapter, index: Int, width: CGFloat, x: @escaping (Int) -> CGFloat) -> some View {
        let adventure = app.adventure
        let progress = adventure.progress
        let cleared = progress.cleared(in: index)
        let here = self.here
        let isHere = here.chapter == index && !adventure.isChallenging
        let terminal = x(Chapter.stationCount - 1)
        let doneEnd = x(min(cleared, Chapter.stationCount - 1))

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
                    StationDot(state: state, isHere: isHere && here.station == station, isSelected: selected == point,
                               isTerminus: station == Chapter.stationCount - 1,
                               gauge: gauge(at: station, here: here, isHere: isHere))
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

        if isHere, let leader = adventure.leader {
            HoppingIcon(speciesID: leader.speciesID, training: progress.isTraining || progress.repeating != nil)
                .position(x: x(here.station), y: Self.lineY - 19)
                .animation(.smooth(duration: 0.4), value: here)
                .allowsHitTesting(false)
        }
    }

    /// How far the party is through the station it's on, 0–1: the frontier's wins so far over
    /// what it takes. Nil on a terminus, a repeat or training, which don't fill up.
    private func gauge(at station: Int, here: StationPoint, isHere: Bool) -> CGFloat? {
        let adventure = app.adventure
        guard isHere, here.station == station, here == adventure.progress.frontier, station < Chapter.stationCount - 1,
              let count = adventure.stationWins, count.needed > 0 else { return nil }
        return CGFloat(min(count.wins, count.needed)) / CGFloat(count.needed)
    }

    static let lineColor = Color(hex: 0x3DBB6A)

    // MARK: Footer

    @ViewBuilder
    private func footer(chapter: Chapter, index: Int) -> some View {
        let adventure = app.adventure
        let progress = adventure.progress
        // The line's chapter, or the one before while the party works up to it.
        let isCurrent = index == progress.chapter || index == current
        HStack(spacing: 5) {
            if let selected, selected.chapter == index {
                let isTerminus = selected.station == Chapter.stationCount - 1
                let level = adventure.foeLevel(chapter.stations[selected.station], isTerminus: isTerminus)
                Text("\(chapter.number)-\(selected.station + 1)").font(.system(size: 9.5, weight: .heavy).monospacedDigit())
                Text(isTerminus ? "3 wild Pokémon · Lv \(level)" : "1 wild Pokémon · Lv \(level)")
                    .foregroundStyle(.white.opacity(0.5))
                Spacer(minLength: 2)
                if progress.repeating == selected {
                    pill(String(localized: "Next station"), symbol: "arrow.forward") { adventure.resumeJourney(); self.selected = nil }
                } else if progress.isCleared(selected) {
                    pill(String(localized: "Repeat"), symbol: "repeat") { adventure.repeatStation(selected); self.selected = nil }
                }
            } else if let repeating = progress.repeating {
                Image(systemName: "repeat").foregroundStyle(Color(hex: 0x7FC8FF))
                Text("Repeating \(repeating.chapter + 1)-\(repeating.station + 1)").foregroundStyle(Color(hex: 0x7FC8FF))
                Spacer(minLength: 2)
                pill(String(localized: "Next station"), symbol: "arrow.forward") { adventure.resumeJourney() }
            } else if progress.isTraining, isCurrent {
                // Back a station after a loss, for a few clears.
                let point = adventure.stationPoint
                Image(systemName: "arrow.counterclockwise").foregroundStyle(Color(hex: 0xFF9E6B))
                Text("Training at \(point.chapter + 1)-\(point.station + 1)").foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                Spacer(minLength: 2)
                pill(String(localized: "Next station"), symbol: "arrow.forward") { adventure.resumeJourney() }
            } else if adventure.isChallenging {
                Image(systemName: "bolt.fill").foregroundStyle(Color(hex: 0xFFD35A))
                Text("A challenge is underway").foregroundStyle(.white.opacity(0.7))
                Spacer(minLength: 0)
            } else if let boss = adventure.nextBoss, progress.isBossOpen(adventure.chapters), isCurrent {
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
            } else if isCurrent, progress.isLooping {
                Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.white.opacity(0.6))
                Text("Looping the last line").foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
            } else if isCurrent {
                // On the line: how far to the line's end (and whose gym opens there), or that it
                // waits for an agent; a pull when there's one.
                let point = adventure.stationPoint
                let station = adventure.chapters[point.chapter].stations[point.station]
                let onTheWay = adventure.nextBoss.flatMap { boss in
                    adventure.stationsToNextBoss.map { GuideText.stationsTo(boss.trainer.name, $0) }
                } ?? GuideText.stationsLeft(adventure.stationsLeft)
                Image(systemName: adventure.isBattling ? "play.fill" : "moon.zzz.fill")
                    .foregroundStyle(adventure.isBattling ? Color(hex: 0xFFD35A) : .white.opacity(0.5))
                Text(adventure.isBattling ? onTheWay : GuideText.resting)
                    .foregroundStyle(.white.opacity(adventure.isBattling ? 0.8 : 0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                if adventure.hasGachaWaiting {
                    fixPill(.gacha)
                } else if adventure.isBattling {
                    let isTerminus = point.station == Chapter.stationCount - 1
                    Text("Lv \(adventure.foeLevel(station, isTerminus: isTerminus))")
                        .font(.system(size: 8.5, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.4))
                }
            } else {
                Image(systemName: "checkmark").foregroundStyle(Self.lineColor)
                Text("Cleared").foregroundStyle(.white.opacity(0.55)).lineLimit(1)
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

    /// A quicker way to get stronger than waiting: a dungeon with tries left, a pull.
    private enum Fix { case dungeon, gacha }

    private func fix(_ adventure: AdventureService) -> Fix? {
        if adventure.openDungeon != nil { return .dungeon }
        if adventure.hasGachaWaiting { return .gacha }
        return nil
    }

    @ViewBuilder
    private func fixPill(_ fix: Fix) -> some View {
        switch fix {
        case .dungeon:
            pill(GuideText.dungeon, symbol: "door.left.hand.open", primary: true) { openDungeon() }
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
    /// The line's last station, drawn as a bigger terminus.
    var isTerminus = false
    /// The wild Pokémon beaten here so far, 0–1, filling a ring around the dot; nil draws none.
    var gauge: CGFloat?

    @State private var pulse = false

    var body: some View {
        let size: CGFloat = isTerminus ? 16 : 12
        let ring: CGFloat = isTerminus ? 3.5 : 2.5
        ZStack {
            if isHere, let gauge {
                // Each win fills the ring a little more; a full ring moves the line on.
                Circle().fill(Color(hex: 0xFFD35A).opacity(pulse ? 0.06 : 0.22)).frame(width: pulse ? size + 12 : size + 7, height: pulse ? size + 12 : size + 7)
                Circle().fill(.black).frame(width: size + 5, height: size + 5)
                Circle().stroke(.white.opacity(0.22), lineWidth: 3).frame(width: size + 2, height: size + 2)
                Circle().trim(from: 0, to: gauge)
                    .stroke(Color(hex: 0xFFD35A), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size + 2, height: size + 2)
                    .animation(.smooth(duration: 0.45), value: gauge)
                Circle().fill(Color(hex: 0xFFD35A)).frame(width: size - 6, height: size - 6)
            } else if isHere {
                Circle().fill(Color(hex: 0xFFD35A).opacity(pulse ? 0.08 : 0.35)).frame(width: pulse ? size + 10 : size + 4, height: pulse ? size + 10 : size + 4)
                Circle().fill(Color(hex: 0xFFD35A)).frame(width: size + 2, height: size + 2)
                Circle().strokeBorder(.white, lineWidth: 3).frame(width: size + 3, height: size + 3)
            } else {
                switch state {
                case .cleared:
                    Circle().fill(StageLineView.lineColor).frame(width: size, height: size)
                    Circle().strokeBorder(Color(hex: 0x1E7A41), lineWidth: ring).frame(width: size, height: size)
                case .frontier, .ahead:
                    Circle().fill(.black).frame(width: size, height: size)
                    Circle().strokeBorder(.white.opacity(state == .frontier ? 0.6 : 0.28), lineWidth: ring).frame(width: size, height: size)
                }
            }
            if isSelected {
                Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1).frame(width: size + 6, height: size + 6)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
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
                    PokeSpriteView(id: leader.speciesID, pixelSize: 1, back: true, shiny: leader.shiny, fitHeight: 52)
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
            .fixedSize()
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
        .fixedSize()
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
        let next = progress.nextBoss(adventure.chapters)
        let nextIndex = next.flatMap { next in entries.firstIndex { $0.chapter == next.chapter && $0.index == next.index } } ?? entries.count - 1
        let shown = min(browsing ?? nextIndex, entries.count - 1)
        let entry = entries[shown]
        let goal = BattleTarget.boss(chapter: entry.chapter, index: entry.index)
        let beaten = shown < nextIndex || progress.isChampion && entry.trainer.isChampion
            || (progress.beatenBosses ?? []).contains(entry.trainer.id)
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
                    BadgeImageView(number: app.adventure.region.badgeImage(badge), size: 17, earned: beaten, unearnedColor: .white.opacity(0.45))
                } else {
                    // The Champion's crown, a star for the one after (Red), else the League's order.
                    let postgame = adventure.chapters[safeChapter: entry.chapter]?.isLeague == false
                    Image(systemName: entry.trainer.isChampion ? "crown.fill" : postgame ? "star.fill" : "\(entry.index + 1).circle.fill")
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
                GoButton(title: String(localized: "Challenge!")) { adventure.challengeBoss() }
                    .disabled(adventure.isChallenging)
            } else if isNext {
                VSNote(symbol: "lock.fill", text: String(localized: "\(adventure.stationsToNextBoss ?? adventure.stationsLeft) stations left"))
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

// MARK: Dungeons

/// The stardust and experience dungeons, each a climb of stages with three tries a day.
private struct DungeonView: View {
    var body: some View {
        VStack(spacing: 4) {
            ForEach(DungeonKind.allCases, id: \.self) { DungeonCard(kind: $0) }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// One dungeon: its next stage and what it pays, the tries left, a try at the next stage, and a
/// sweep of the best one.
private struct DungeonCard: View {
    let kind: DungeonKind

    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        let climb = adventure.climb(kind)
        let running = runningStage(adventure)
        let stage = running ?? climb.next ?? climb.best
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if kind == .stardust {
                    StardustIcon(size: 11)
                } else {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 9.5, weight: .bold)).foregroundStyle(Color(hex: 0x7FC8FF))
                }
                Text(ChallengeText.dungeonCard(kind))
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
                    .fixedSize()
                ForEach(adventure.dungeonTypes(kind), id: \.self) { PokeTypeBadge(type: $0, compact: true) }
                Spacer(minLength: 2)
                TriesDots(tries: climb.tries)
                    .help(climb.tries > 0 ? ChallengeText.tries(climb.tries) : ChallengeText.triesTomorrow)
            }
            HStack(spacing: 5) {
                VStack(alignment: .leading, spacing: -2) {
                    Text(ChallengeText.stage(stage))
                        .font(.system(size: 13, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    // The reward sits under the stage, so the buttons keep their room in every language.
                    HStack(spacing: 4) {
                        Text("Lv \(DailyDungeon.level(stage: stage))")
                            .font(.system(size: 8.5, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.5))
                        reward(stage: stage, isNew: stage == climb.next)
                    }
                }
                .fixedSize()
                Spacer(minLength: 2)
                actions(adventure, climb: climb, running: running)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(running != nil ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(hex: 0xFFD35A).opacity(running != nil ? 0.6 : 0)))
        .animation(.smooth(duration: 0.25), value: climb)
    }

    private func runningStage(_ adventure: AdventureService) -> Int? {
        guard adventure.isChallenging, case .dungeon(let current, let stage) = adventure.target, current == kind else { return nil }
        return stage
    }

    /// What the stage pays: stardust, with an Ultra Ball on a first clear of every tenth, or experience.
    @ViewBuilder
    private func reward(stage: Int, isNew: Bool) -> some View {
        HStack(spacing: 2) {
            switch kind {
            case .stardust:
                StardustIcon(size: 10)
                Text("\(DailyDungeon.stardust(stage: stage))")
                if isNew, DailyDungeon.paysUltraBall(stage: stage) {
                    ItemSpriteView(slug: "ultra-ball", pixelSize: 0.5).frame(width: 11, height: 11)
                }
            case .experience:
                Text("EXP \(DailyDungeon.experience(stage: stage))")
            }
        }
        .font(.system(size: 8.5, weight: .bold).monospacedDigit())
        .foregroundStyle(.white.opacity(0.75))
        .lineLimit(1)
        .fixedSize()
    }

    @ViewBuilder
    private func actions(_ adventure: AdventureService, climb: DungeonClimb, running: Int?) -> some View {
        if running != nil, let battle = adventure.battle {
            Text("\(min(battle.foeIndex + 1, battle.plan.foes.count))/\(battle.plan.foes.count)")
                .font(.system(size: 9.5, weight: .heavy).monospacedDigit())
                .foregroundStyle(Color(hex: 0xFFD35A))
                .frame(height: 19)
        } else if climb.tries == 0 {
            VSNote(symbol: "moon.zzz.fill", text: ChallengeText.triesTomorrow)
        } else {
            HStack(spacing: 4) {
                if climb.best > 0 {
                    Button {
                        withAnimation(.smooth(duration: 0.25)) { adventure.sweepDungeon(kind) }
                    } label: {
                        Text(ChallengeText.sweep)
                            .font(.system(size: 8.5, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 7)
                            .frame(height: 19)
                            .background(.white.opacity(0.15), in: Capsule())
                            .contentShape(Capsule())
                            .fixedSize()
                    }
                    .buttonStyle(.plain)
                    .help(ChallengeText.sweepHelp(climb.best))
                }
                if climb.next != nil {
                    GoButton(title: String(localized: "Go!")) { adventure.enterDungeon(kind) }
                }
            }
            .disabled(adventure.isChallenging)
            .opacity(adventure.isChallenging ? 0.4 : 1)
        }
    }
}

/// Today's tries as three dots, lit while they last.
private struct TriesDots: View {
    let tries: Int

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<DailyDungeon.triesPerDay, id: \.self) { index in
                Circle()
                    .fill(index < tries ? Color(hex: 0xFFD35A) : .white.opacity(0.15))
                    .frame(width: 5, height: 5)
            }
        }
        .animation(.smooth(duration: 0.25), value: tries)
    }
}

// MARK: Battle Tower

/// After the Champion: the next floor's three, the record, and the button to climb.
private struct TowerView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        let running = adventure.tower.floor != nil && adventure.isChallenging
        let floor = adventure.tower.floor ?? 1
        let foes = adventure.data.map { BattleTower.plan(floor: floor, on: Date(), data: $0).foes } ?? []
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(ChallengeText.tower)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 2)
                if adventure.tower.best > 0 {
                    Text(ChallengeText.best(adventure.tower.best))
                        .font(.system(size: 9, weight: .heavy).monospacedDigit())
                        .foregroundStyle(Color(hex: 0xFFD35A))
                }
            }
            .padding(.horizontal, 2)

            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(ChallengeText.floor(floor))
                        .font(.system(size: 17, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("Lv \(BattleTower.level(floor: floor))")
                        .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer(minLength: 2)
                HStack(spacing: -6) {
                    ForEach(Array(foes.enumerated()), id: \.offset) { _, foe in PokeIconView(id: foe.species, pixelSize: 1) }
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 50)
            .background(.white.opacity(running ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(hex: 0xFFD35A).opacity(running ? 0.6 : 0)))

            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    StardustIcon(size: 10)
                    Text("\(BattleTower.stardustPerFloor)").font(.system(size: 9, weight: .bold).monospacedDigit())
                }
                .foregroundStyle(.white.opacity(0.75))
                HStack(spacing: 2) {
                    ItemSpriteView(slug: "ultra-ball", pixelSize: 0.6).frame(width: 14, height: 14)
                    Text(ChallengeText.floor(nextUltraFloor(after: floor)))
                        .font(.system(size: 9, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 2)
                if running {
                    VSNote(symbol: "bolt.fill", text: String(localized: "Battling…"), tint: Color(hex: 0xFFD35A))
                } else {
                    GoButton(title: String(localized: "Challenge!")) { adventure.enterTower() }
                        .disabled(adventure.isChallenging)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// The next floor that pays an Ultra Ball, from this one.
    private func nextUltraFloor(after floor: Int) -> Int {
        let every = BattleTower.ultraBallEvery
        return (floor + every - 1) / every * every
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
