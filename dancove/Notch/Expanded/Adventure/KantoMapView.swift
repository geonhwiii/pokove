import SwiftUI

/// A pixel map of Kanto with the journey on it: where the party is, what's cleared, the gyms'
/// badges and the legendaries. Tapping a place shows what's there.
struct KantoMapView: View {
    @Environment(AppModel.self) private var app
    @State private var selection: String?

    static let cell: CGFloat = 4

    var body: some View {
        let adventure = app.adventure
        let nodes = adventure.nodes
        let width = Kanto.mapSize.width * Self.cell, height = Kanto.mapSize.height * Self.cell
        ZStack(alignment: .topLeading) {
            KantoTerrain()
                .frame(width: width, height: height)

            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                MapMarker(node: node, index: index, isSelected: selection == node.id)
                    .position(Self.point(node.point))
                    .onTapGesture { select(node.id) }
            }
            ForEach(Kanto.legends.filter { adventure.progress.isReached(legend: $0, in: nodes) }) { node in
                LegendMarker(node: node, isSelected: selection == node.id)
                    .position(Self.point(node.point))
                    .onTapGesture { select(node.id) }
            }
            if let node = adventure.currentNode, let leader = adventure.leader {
                PartnerIcon(speciesID: leader.speciesID)
                    .position(x: Self.point(node.point).x, y: Self.point(node.point).y - 9)
                    .allowsHitTesting(false)
            }

            if let selection, let node = adventure.data?.node(selection) ?? nodes.first(where: { $0.id == selection }) {
                MapInfoCard(node: node) { self.selection = nil }
                    .frame(width: width)
                    .position(x: width / 2, y: height - MapInfoCard.height / 2 - 2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.08)))
        .animation(.smooth(duration: 0.25), value: selection)
    }

    private func select(_ id: String) {
        selection = selection == id ? nil : id
    }

    static func point(_ point: MapPoint) -> CGPoint {
        CGPoint(x: (point.x + 0.5) * cell, y: (point.y + 0.5) * cell)
    }
}

// MARK: Terrain

/// Sea, land, forests and mountains, rasterized once into grid cells, with roads and towns.
private struct KantoTerrain: View {
    enum Ground { case sea, land, forest, mountain }

    static let grid: [[Ground]] = {
        func polygon(_ points: [(Double, Double)]) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: points[0].0, y: points[0].1))
            for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
            path.closeSubpath()
            return path
        }
        let mainland = polygon([(1, 1), (53, 1), (53, 14), (51, 16), (51, 27.5), (37, 27.5), (35, 26.6), (17, 26.6), (16, 24.6),
                                (8, 24.6), (8, 21), (1, 21)])
        let islands = [CGRect(x: 8, y: 27, width: 8, height: 3), CGRect(x: 22, y: 27, width: 6, height: 3)]
        let forests: [(Double, Double, Double)] = [(12, 12, 2.6), (32, 21, 2.4), (20, 17, 1.6), (44, 25, 1.8)]
        let mountains: [(Double, Double, Double)] = [(4, 4, 3.4), (3, 9, 3), (4, 13, 2.2), (24, 5, 2.8), (46, 7, 2.4), (29, 1.6, 1.8)]
        func inCircle(_ x: Double, _ y: Double, _ circle: (Double, Double, Double)) -> Bool {
            let dx = x - circle.0, dy = y - circle.1
            return dx * dx + dy * dy <= circle.2 * circle.2
        }
        return (0..<Int(Kanto.mapSize.height)).map { row in
            (0..<Int(Kanto.mapSize.width)).map { column in
                let x = Double(column) + 0.5, y = Double(row) + 0.5
                let point = CGPoint(x: x, y: y)
                guard mainland.contains(point) || islands.contains(where: { $0.contains(point) }) else { return .sea }
                if mountains.contains(where: { inCircle(x, y, $0) }) { return .mountain }
                if forests.contains(where: { inCircle(x, y, $0) }) { return .forest }
                return .land
            }
        }
    }()

    var body: some View {
        Canvas { canvas, _ in
            let cell = KantoMapView.cell
            for (row, line) in Self.grid.enumerated() {
                for (column, ground) in line.enumerated() {
                    let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    let checker = (row + column) % 2 == 0
                    let color: UInt32 = switch ground {
                    case .sea: (row % 4 == 0 && column % 6 == row % 3) ? 0x4A8AD0 : 0x2F6FB8
                    case .land: checker ? 0x7CC456 : 0x74BC50
                    case .forest: checker ? 0x3E8A3E : 0x347A36
                    case .mountain: checker ? 0xA08058 : 0x8E7050
                    }
                    canvas.fill(Path(rect), with: .color(Color(hex: color)))
                }
            }
            for road in Kanto.roads {
                var path = Path()
                path.move(to: KantoMapView.point(road[0]))
                for point in road.dropFirst() { path.addLine(to: KantoMapView.point(point)) }
                canvas.stroke(path, with: .color(Color(hex: 0xE8D8A0).opacity(0.85)), style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
            }
            for town in Kanto.towns {
                let center = KantoMapView.point(town.point)
                canvas.fill(Path(CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)), with: .color(Color(hex: 0xF4F0E8)))
                canvas.fill(Path(CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 2)), with: .color(Color(hex: 0xD84A3A)))
            }
        }
    }
}

// MARK: Markers

private struct MapMarker: View {
    let node: JourneyNode
    let index: Int
    let isSelected: Bool

    @Environment(AppModel.self) private var app
    @State private var pulse = false

    var body: some View {
        let adventure = app.adventure
        let progress = adventure.progress
        let nodes = adventure.nodes
        let reached = progress.hasReached(index)
        let cleared = progress.clearedStages(of: index, in: nodes) >= node.stageCount
        let isFrontier = progress.frontier.node == index && !progress.isComplete(nodes)
        ZStack {
            if let badge = node.trainers.first?.badge, node.isGym {
                BadgeImageView(number: badge, size: 10, earned: progress.badges >= badge, unearnedColor: .black.opacity(0.55))
            } else if !node.isRoute {
                Image(systemName: "crown.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(progress.isChampion ? Color(hex: 0xFFD35A) : .white.opacity(reached ? 0.8 : 0.3))
            } else {
                Rectangle()
                    .fill(cleared ? Color(hex: 0xFFD35A) : (reached ? .white : Color(hex: 0x2A3A2A)))
                    .frame(width: 4, height: 4)
                    .overlay(Rectangle().strokeBorder(.black.opacity(0.5), lineWidth: 0.5))
            }
            if isFrontier {
                Circle()
                    .strokeBorder(Color(hex: 0xFFE14D), lineWidth: 1)
                    .frame(width: pulse ? 14 : 8, height: pulse ? 14 : 8)
                    .opacity(pulse ? 0 : 1)
            }
            if isSelected {
                RoundedRectangle(cornerRadius: 2).strokeBorder(.white, lineWidth: 1).frame(width: 12, height: 12)
            }
        }
        .frame(width: 14, height: 14)
        .contentShape(Rectangle())
        .opacity(reached || !node.isRoute ? 1 : 0.55)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { pulse = true }
        }
        .help(node.name)
    }
}

private struct LegendMarker: View {
    let node: JourneyNode
    let isSelected: Bool

    @Environment(AppModel.self) private var app
    @State private var glow = false

    var body: some View {
        let beaten = app.adventure.progress.beatenLegends.contains(node.id)
        ZStack {
            if beaten, case .legend(let species, _, _) = node.kind {
                PokeIconView(id: species, pixelSize: 0.5)
            } else {
                Image(systemName: "star.fill")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(Color(hex: 0xFFD35A))
                    .shadow(color: Color(hex: 0xFFD35A).opacity(glow ? 0.9 : 0.2), radius: glow ? 3 : 1)
            }
            if isSelected {
                RoundedRectangle(cornerRadius: 2).strokeBorder(.white, lineWidth: 1).frame(width: 12, height: 12)
            }
        }
        .frame(width: 14, height: 14)
        .contentShape(Rectangle())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { glow = true }
        }
        .help(node.name)
    }
}

// MARK: Info card

/// What's at a place: its Pokémon, its trainer, or its legendary, and what you can do there.
private struct MapInfoCard: View {
    static let height: CGFloat = 52
    let node: JourneyNode
    let close: () -> Void

    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        let nodes = adventure.nodes
        let index = nodes.firstIndex { $0.id == node.id }
        HStack(alignment: .center, spacing: 7) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(node.name)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(status(index: index))
                        .font(.system(size: 8.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                content(index: index)
            }
            Spacer(minLength: 0)
            action(index: index)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: Self.height)
        .background(Color(hex: 0x101218).opacity(0.94), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.1)))
        .overlay(alignment: .topTrailing) {
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 7, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .padding(2)
        }
        .padding(.horizontal, 3)
    }

    private func status(index: Int?) -> String {
        let adventure = app.adventure
        let nodes = adventure.nodes
        if case .legend = node.kind {
            return adventure.progress.beatenLegends.contains(node.id) ? String(localized: "Joined") : String(localized: "Legendary")
        }
        guard let index else { return "" }
        guard adventure.progress.hasReached(index) else { return String(localized: "Not yet reached") }
        let cleared = adventure.progress.clearedStages(of: index, in: nodes)
        return "\(cleared)/\(node.stageCount)"
    }

    @ViewBuilder
    private func content(index: Int?) -> some View {
        let adventure = app.adventure
        switch node.kind {
        case .route:
            let pool = adventure.data.map { $0.encounters.pool(for: node, dex: $0.dex) } ?? []
            HStack(spacing: 0) {
                ForEach(pool.prefix(7), id: \.species) { entry in
                    PokeIconView(id: entry.species, pixelSize: 0.5, silhouette: !adventure.seen.contains(entry.species),
                                 silhouetteOpacity: 0.3)
                }
                if pool.count > 7 {
                    Text("+\(pool.count - 7)").font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.4))
                }
            }
        case .trainers(let trainers):
            let trainer = trainerShown(trainers, index: index)
            HStack(spacing: 3) {
                if let specialty = trainer.specialty { PokeTypeBadge(type: specialty, compact: true) }
                Text(trainer.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                ForEach(Array(trainer.battleTeam.enumerated()), id: \.offset) { _, member in
                    PokeIconView(id: member.species, pixelSize: 0.5)
                }
            }
        case .legend(let species, let level, _):
            HStack(spacing: 4) {
                PokeIconView(id: species, pixelSize: 0.5, silhouette: !adventure.caught.contains(species), silhouetteOpacity: 0.35)
                Text("Lv \(level)").font(.system(size: 9, weight: .bold).monospacedDigit()).foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func trainerShown(_ trainers: [Trainer], index: Int?) -> Trainer {
        let progress = app.adventure.progress
        if let index, progress.frontier.node == index, trainers.indices.contains(progress.frontier.stage) {
            return trainers[progress.frontier.stage]
        }
        return trainers[0]
    }

    @ViewBuilder
    private func action(index: Int?) -> some View {
        let adventure = app.adventure
        let progress = adventure.progress
        switch node.kind {
        case .route:
            if let index, progress.stay == index {
                pill(String(localized: "Move On"), symbol: "arrow.forward") { adventure.resumeJourney() }
            } else if let index, progress.clearedStages(of: index, in: adventure.nodes) > 0, progress.frontier.node != index || progress.stay != nil {
                pill(String(localized: "Stay Here"), symbol: "tent.fill") { adventure.stay(at: index) }
            }
        case .trainers:
            if let index, progress.frontier.node == index, !progress.isComplete(adventure.nodes) {
                VStack(alignment: .trailing, spacing: 3) {
                    if let readiness = adventure.readiness {
                        Text("\(Int((readiness * 100).rounded()))% to win")
                            .font(.system(size: 8.5, weight: .bold).monospacedDigit())
                            .foregroundStyle(readiness >= AutoChallenge.confident ? Color(hex: 0x7CF0A0) : Color(hex: 0xFFB070))
                    }
                    HStack(spacing: 3) {
                        Button {
                            withAnimation(.smooth(duration: 0.25)) { adventure.recommendParty() }
                        } label: {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(width: 19, height: 17)
                                .background(.white.opacity(0.12), in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Best team for this trainer")
                        pill(String(localized: "Challenge"), symbol: "flag.checkered", primary: true) { adventure.challengeTrainer() }
                    }
                }
            }
        case .legend:
            if progress.legend == node.id {
                pill(String(localized: "Retreat"), symbol: "arrow.uturn.backward") { adventure.resumeJourney() }
            } else if !progress.beatenLegends.contains(node.id) {
                pill(String(localized: "Challenge"), symbol: "star.fill", primary: true) { adventure.challengeLegend(node.id) }
            }
        }
    }

    private func pill(_ title: String, symbol: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) { action() }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 7, weight: .bold))
                Text(title).font(.system(size: 8.5, weight: .bold))
            }
            .foregroundStyle(primary ? .black : .white.opacity(0.9))
            .padding(.horizontal, 6)
            .frame(height: 17)
            .background(primary ? Color(hex: 0xFFD35A) : .white.opacity(0.12), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
