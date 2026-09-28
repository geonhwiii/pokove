import SwiftUI

/// The battle, laid out like the games: the foe on its platform at the top right, the party's
/// Pokémon from behind at the bottom left, info plates, and a text box along the bottom.
struct BattleSceneView: View {
    static let height: CGFloat = 130

    @Environment(AppModel.self) private var app
    @State private var size = CGSize(width: 250, height: BattleSceneView.height)
    @State private var effects: [MoveEffect] = []
    @State private var popups: [ScenePopup] = []
    @State private var caption: String?
    @State private var captionSerial = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lunging: UUID?
    /// How far the user runs at the target: further for a tackle than a punch.
    @State private var lungeDistance: CGFloat = 9
    /// Flashes white as a hit lands.
    @State private var struck: UUID?
    /// Knocked back by a hit.
    @State private var knocked: UUID?
    @State private var shake = SceneShake(amount: 0, seconds: 0)
    @State private var shakeSerial = 0
    /// A challenge's VS splash, then its result card, over the scene.
    @State private var intro: StagePlan?
    @State private var pendingIntro: StagePlan?
    @State private var result: ChallengeResult?
    @State private var cardSerial = 0
    @State private var sparkling = false
    @State private var sparkleSerial = 0
    /// A new station reached, and its stardust, across the middle of the scene for a moment.
    @State private var arrival: Arrival?
    @State private var arrivalSerial = 0

    var body: some View {
        let adventure = app.adventure
        let battle = adventure.battle
        let layout = SceneLayout(size: size)
        ZStack(alignment: .topLeading) {
            StageBackdrop(scenery: adventure.scenery)
            ScenePlatforms(layout: layout)

            if let battle {
                if case .intro = battle.phase, let trainer = battle.plan.trainer {
                    TrainerSpriteView(slug: trainer.sprite, pixelSize: 0.75)
                        .position(x: layout.foeFeet.x, y: layout.foeFeet.y - 30)
                        .transition(.opacity)
                } else if let foe = battle.foeActive {
                    figure(foe, back: false, layout: layout)
                }
                if let ally = battle.partyActive {
                    figure(ally, back: true, layout: layout)
                }
            } else if let leader = adventure.leader {
                PokeSpriteView(id: leader.speciesID, pixelSize: 1, back: true, shiny: leader.shiny, fitHeight: SceneLayout.allyFit)
                    .frame(width: 110, height: SceneLayout.allyFit, alignment: .bottom)
                    .position(x: layout.allyFeet.x, y: layout.allyFeet.y - SceneLayout.allyFit / 2)
            }

            MoveEffectsLayer(effects: effects)

            // A shiny partner sparkles as it comes out.
            if sparkling {
                PixelSparkles(color: Color(hex: 0xFFE14D), count: 12, prismatic: true)
                    .frame(width: 90, height: 70)
                    .position(x: layout.allyFeet.x, y: layout.allyFeet.y - SceneLayout.allyFit / 2)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if let battle {
                if let foe = battle.foeActive, !isTrainerIntro(battle) {
                    FoePlate(foe: foe, battle: battle)
                        .position(x: 6 + FoePlate.width / 2, y: 36)
                }
                if let ally = battle.partyActive {
                    AllyPlate(ally: ally, battle: battle)
                        .position(x: layout.size.width - 6 - AllyPlate.width / 2, y: layout.size.height - SceneTextBox.height - 16)
                }
            }

            // Numbers over the plates, so a big hit is never hidden.
            ForEach(popups) { popup in
                ScenePopupView(popup: popup).position(popup.point)
            }

            if let arrival {
                ArrivalBanner(arrival: arrival)
                    .position(x: layout.size.width / 2, y: layout.size.height * 0.5)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .allowsHitTesting(false)
            }

            SceneChrome()
                .frame(width: layout.size.width)

            SceneTextBox(caption: caption)
                .frame(width: layout.size.width)
                .position(x: layout.size.width / 2, y: layout.size.height - SceneTextBox.height / 2)

            if let result {
                ChallengeResultView(result: result)
                    .frame(width: layout.size.width, height: layout.size.height)
                    .transition(.opacity)
            } else if let intro {
                ChallengeIntroView(plan: intro)
                    .frame(width: layout.size.width, height: layout.size.height)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .keyframeAnimator(initialValue: CGSize.zero, trigger: shakeSerial) { content, offset in
            content.offset(offset)
        } keyframes: { _ in
            let steps = max(3, Int(shake.seconds / 0.045))
            KeyframeTrack(\.width) {
                for step in 0..<steps {
                    let fade = 1 - CGFloat(step) / CGFloat(steps)
                    LinearKeyframe((step % 2 == 0 ? 1 : -1) * shake.amount * fade, duration: shake.seconds / Double(steps))
                }
                LinearKeyframe(0, duration: 0.04)
            }
            KeyframeTrack(\.height) {
                for step in 0..<steps {
                    let fade = 1 - CGFloat(step) / CGFloat(steps)
                    LinearKeyframe((step % 3 == 0 ? 0.6 : -0.4) * shake.amount * shake.vertical * fade, duration: shake.seconds / Double(steps))
                }
                LinearKeyframe(0, duration: 0.04)
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onChange(of: adventure.eventSerial) { handle(adventure.lastEvent, layout: layout) }
        // What a knockout at a station was worth, over the party's plate once the foe is gone.
        .onChange(of: adventure.xpSerial) {
            let plate = CGPoint(x: layout.size.width - 6 - AllyPlate.width / 2, y: layout.size.height - SceneTextBox.height - 34)
            let xp = adventure.lastXP
            Task {
                guard (try? await Task.sleep(for: .seconds(0.8))) != nil else { return }
                addPopup(ScenePopup(text: GuideText.xpGained(xp), style: .xp, point: plate))
            }
        }
        .onChange(of: battle?.foes.first?.id) {
            introduce(adventure.battle)
            if adventure.target?.showsIntro == true, let plan = adventure.battle?.plan { showIntro(plan) }
        }
        .onChange(of: adventure.resultSerial) { showResult(adventure.lastResult) }
        .onChange(of: adventure.arrivalSerial) { showArrival(adventure.lastArrival) }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .pokoveDebugMoveEffect)) { note in
            debugEffect(slug: note.object as? String, byFoe: note.userInfo?["foe"] as? Bool == true, layout: layout)
        }
        #endif
        .onAppear { introduce(adventure.battle) }
    }

    // MARK: Challenge cards

    private func showIntro(_ plan: StagePlan) {
        // A result still showing goes first; the next challenge's splash follows it.
        guard result == nil else { pendingIntro = plan; return }
        withAnimation(.smooth(duration: 0.2)) { intro = plan }
        cardSerial &+= 1
        let serial = cardSerial
        Task {
            guard (try? await Task.sleep(for: .seconds(AdventureService.introHold - 0.2))) != nil, cardSerial == serial else { return }
            withAnimation(.smooth(duration: 0.3)) { intro = nil }
        }
    }

    private func showArrival(_ value: Arrival?) {
        guard let value else { return }
        withAnimation(.smooth(duration: 0.25)) { arrival = value }
        arrivalSerial &+= 1
        let serial = arrivalSerial
        Task {
            guard (try? await Task.sleep(for: .seconds(1.8))) != nil, arrivalSerial == serial else { return }
            withAnimation(.smooth(duration: 0.4)) { arrival = nil }
        }
    }

    private func showResult(_ value: ChallengeResult?) {
        guard let value else { return }
        if let intro { pendingIntro = intro }
        withAnimation(.smooth(duration: 0.25)) {
            intro = nil
            result = value
        }
        cardSerial &+= 1
        let serial = cardSerial
        Task {
            guard (try? await Task.sleep(for: .seconds(AdventureService.resultHold - 0.2))) != nil, cardSerial == serial else { return }
            withAnimation(.smooth(duration: 0.3)) { result = nil }
            if let next = pendingIntro {
                pendingIntro = nil
                showIntro(next)
            }
        }
    }

    private func isTrainerIntro(_ battle: BattleState) -> Bool {
        if case .intro = battle.phase { return battle.plan.trainer != nil }
        return false
    }

    private func figure(_ combatant: Combatant, back: Bool, layout: SceneLayout) -> some View {
        let feet = back ? layout.allyFeet : layout.foeFeet
        let fit = back ? SceneLayout.allyFit : SceneLayout.foeFit
        let toward: CGFloat = back ? 1 : -1
        let lunge: CGFloat = lunging == combatant.id ? lungeDistance * toward : 0
        let knock: CGFloat = knocked == combatant.id ? -5 * toward : 0
        return PokeSpriteView(id: combatant.speciesID, pixelSize: 1, back: back, shiny: back && app.adventure.isShiny(combatant), fitHeight: fit)
            .brightness(struck == combatant.id ? 0.6 : 0)
            .saturation(combatant.isFainted ? 0 : 1)
            .frame(width: 120, height: fit, alignment: .bottom)
            .offset(x: lunge + knock, y: combatant.isFainted ? 16 : 0)
            .opacity(combatant.isFainted ? 0 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: lunging)
            .animation(.spring(response: 0.16, dampingFraction: 0.4), value: knocked)
            // The battle moves on before the move's effect lands, so fainting waits for it.
            .animation(.easeIn(duration: 0.35).delay(0.35), value: combatant.isFainted)
            .position(x: feet.x, y: feet.y - fit / 2)
            .id(combatant.id)
            .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
    }

    // MARK: Events

    private func name(of combatant: Combatant?) -> String {
        combatant.flatMap { app.adventure.dex.species($0.speciesID)?.name } ?? "?"
    }

    private func introduce(_ battle: BattleState?) {
        guard let battle else { return }
        switch battle.plan.kind {
        case .trainer(let trainer): say(BattleText.challenged(trainer))
        case .legend: say(BattleText.legendAppeared(name(of: battle.foeActive)))
        case .wild, .dungeon: say(BattleText.wildAppeared(name(of: battle.foeActive)))
        case .tower(let floor): say("\(ChallengeText.tower) \(ChallengeText.floor(floor))!")
        }
    }

    private func say(_ text: String) {
        caption = text
        captionSerial &+= 1
        let serial = captionSerial
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if captionSerial == serial { caption = nil }
        }
    }

    private func handle(_ event: BattleEvent?, layout: SceneLayout) {
        guard let event, let battle = app.adventure.battle else { return }
        switch event {
        case .sentOut(let side, let id):
            let name = name(of: battle.combatant(id))
            if side == .party {
                say(BattleText.goPartner(name))
                if let ally = battle.combatant(id), app.adventure.isShiny(ally) { sparkle() }
            } else if let trainer = battle.plan.trainer {
                say(BattleText.sentOut(trainer, name))
            } else if case .tower = battle.plan.kind {
                say(BattleText.legendAppeared(name))
            } else {
                say(BattleText.wildAppeared(name))
            }
        case .action(let action):
            play(action, battle: battle, layout: layout)
        case .status(let status):
            let name = name(of: battle.combatant(status.targetID))
            let at = status.onParty ? layout.allyCenter : layout.foeCenter
            switch status.kind {
            case .inflicted:
                say(BattleText.inflicted(name, status.ailment))
            case .immobile:
                say(BattleText.immobile(name))
                addPopup(ScenePopup(text: BattleText.tag(status.ailment), style: .note, point: CGPoint(x: at.x, y: at.y - 18)))
            case .hurt(let amount):
                say(BattleText.hurt(name, status.ailment))
                struck = status.targetID
                addPopup(ScenePopup(text: "\(amount)", style: status.onParty ? .taken : .dealt, point: CGPoint(x: at.x + 10, y: at.y - 10),
                                    weight: .weak))
                Task {
                    try? await Task.sleep(for: .seconds(0.14))
                    struck = nil
                    guard status.fainted, (try? await Task.sleep(for: .seconds(0.5))) != nil else { return }
                    say(BattleText.fainted(name))
                }
            }
        case .cleared:
            say(BattleText.victory)
        case .wiped:
            say(BattleText.defeat)
        }
    }

    private func sparkle() {
        sparkleSerial += 1
        let serial = sparkleSerial
        withAnimation(.easeOut(duration: 0.2)) { sparkling = true }
        Task {
            guard (try? await Task.sleep(for: .seconds(1.4))) != nil, sparkleSerial == serial else { return }
            withAnimation(.easeIn(duration: 0.4)) { sparkling = false }
        }
    }

    private func play(_ action: BattleAction, battle: BattleState, layout: SceneLayout) {
        let attacker = battle.combatant(action.attackerID)
        let target = battle.combatant(action.targetID)
        let from = action.byParty ? layout.allyCenter : layout.foeCenter
        let to = action.byParty ? layout.foeCenter : layout.allyCenter
        let feet = action.byParty ? layout.foeFeet : layout.allyFeet
        say(action.missed ? BattleText.missed(name(of: attacker)) : BattleText.used(name(of: attacker), action.move.name))

        let strong = action.critical || action.effectiveness >= 2
        let effect = MoveEffect(move: action.move, hits: max(1, action.hits), from: from, to: to, feet: feet, strong: strong)
        if effect.shape.isContact {
            lungeDistance = effect.shape == .strike ? 16 : 10
            lunging = action.attackerID
        }
        if !action.missed { effects.append(effect) }
        // Each hit on its own: the number, a white flash and a knock back.
        let strikes = action.strikes.isEmpty ? [action.damage] : action.strikes
        let weight = Self.weight(of: action)

        Task {
            guard !action.missed else {
                try? await Task.sleep(for: .seconds(effect.impact))
                lunging = nil
                addPopup(ScenePopup(text: BattleText.miss, style: .note, point: CGPoint(x: to.x, y: to.y - 18)))
                return
            }
            var elapsed = 0.0
            for (index, amount) in strikes.enumerated() {
                let landing = effect.landing(index)
                try? await Task.sleep(for: .seconds(max(0, landing - elapsed)))
                elapsed = landing
                if index == strikes.count - 1 { lunging = nil }
                if amount > 0 {
                    struck = action.targetID
                    knocked = action.targetID
                }
                if index == 0 { rumble(effect.shake) }
                // Later hits stack up and to the sides, so each number stays readable.
                let sway: CGFloat = [0, 24, -24, 12, -12][index % 5]
                addPopup(ScenePopup(text: "\(amount)", style: action.byParty ? .dealt : .taken,
                                    point: CGPoint(x: to.x + 8 + sway, y: to.y - 12 - CGFloat(index) * 6), weight: weight))
                if index == 0, let note = Self.note(for: action) {
                    addPopup(ScenePopup(text: note, style: .note, point: CGPoint(x: to.x, y: to.y - 32)))
                }
                try? await Task.sleep(for: .seconds(0.07))
                elapsed += 0.07
                struck = nil
                knocked = nil
            }
            if action.healed > 0 {
                addPopup(ScenePopup(text: "+\(action.healed)", style: .healed, point: CGPoint(x: from.x, y: from.y - 18)))
            }
            if action.recoil > 0 {
                addPopup(ScenePopup(text: "-\(action.recoil)", style: .taken, point: CGPoint(x: from.x, y: from.y - 18), weight: .weak))
            }
            try? await Task.sleep(for: .seconds(max(0.3, effect.duration - elapsed)))
            effects.removeAll { $0.id == effect.id }
            if action.targetFainted { say(BattleText.fainted(name(of: target))) }
            if action.attackerFainted { say(BattleText.fainted(name(of: attacker))) }
        }
    }

    #if DEBUG
    /// A move's effect on the battle on screen, without touching the battle itself.
    private func debugEffect(slug: String?, byFoe: Bool, layout: SceneLayout) {
        guard let battle = app.adventure.battle, let ally = battle.partyActive, let foe = battle.foeActive,
              let move = app.adventure.data?.moves.moves.first(where: { $0.slug == slug }) else { return }
        let hits = move.maxHits > 1 ? 3 : 1
        let action = BattleAction(
            attackerID: byFoe ? foe.id : ally.id, targetID: byFoe ? ally.id : foe.id, move: move, byParty: !byFoe, missed: false,
            hits: hits, damage: 123 * hits, effectiveness: 1, critical: false, healed: 0, recoil: 0, targetFainted: false,
            attackerFainted: false, strikes: Array(repeating: 123, count: hits)
        )
        play(action, battle: battle, layout: layout)
    }
    #endif

    /// Shakes the scene, unless motion is reduced.
    private func rumble(_ shake: (amount: CGFloat, seconds: Double)) {
        guard !reduceMotion, shake.amount > 0 else { return }
        self.shake = SceneShake(amount: shake.amount, seconds: shake.seconds)
        shakeSerial &+= 1
    }

    private static func weight(of action: BattleAction) -> ScenePopup.Weight {
        if action.critical { return .critical }
        if action.effectiveness >= 2 { return .strong }
        if action.effectiveness < 1 { return .weak }
        return .normal
    }

    private static func note(for action: BattleAction) -> String? {
        if action.effectiveness == 0 { return BattleText.noEffect }
        if action.critical { return BattleText.critical }
        if action.effectiveness >= 2 { return BattleText.superEffective }
        if action.effectiveness < 1 { return BattleText.notVeryEffective }
        if action.hits > 1 { return BattleText.hits(action.hits) }
        return nil
    }

    private func addPopup(_ popup: ScenePopup) {
        popups.append(popup)
        if popups.count > 9 { popups.removeFirst(popups.count - 9) }
        Task {
            try? await Task.sleep(for: .seconds(1))
            popups.removeAll { $0.id == popup.id }
        }
    }
}

/// Where things stand in a scene of a given size.
private struct SceneLayout {
    let size: CGSize

    static let foeFit: CGFloat = 52
    static let allyFit: CGFloat = 62

    var foeFeet: CGPoint { CGPoint(x: (size.width * 0.73).rounded(), y: 70) }
    /// The party's Pokémon stands on its pad just above the text strip, so messages never cover it.
    var allyFeet: CGPoint { CGPoint(x: (size.width * 0.26).rounded(), y: size.height - SceneTextBox.height + 2) }
    var foeCenter: CGPoint { CGPoint(x: foeFeet.x, y: foeFeet.y - 22) }
    var allyCenter: CGPoint { CGPoint(x: allyFeet.x, y: allyFeet.y - 38) }
}

// MARK: Pieces

/// The two oval pads the Pokémon stand on, in pixel steps.
private struct ScenePlatforms: View {
    let layout: SceneLayout

    var body: some View {
        Canvas { canvas, _ in
            func pad(center: CGPoint, width: CGFloat, height: CGFloat) {
                let step: CGFloat = 2
                var y = -height / 2
                while y < height / 2 {
                    let t = y / (height / 2)
                    let half = (width / 2 * (1 - t * t).squareRoot() / step).rounded() * step
                    canvas.fill(Path(CGRect(x: center.x - half, y: center.y + y, width: half * 2, height: step)),
                                with: .color(.black.opacity(0.18)))
                    y += step
                }
                canvas.fill(Path(CGRect(x: center.x - width * 0.32, y: center.y - height / 2, width: width * 0.64, height: step)),
                            with: .color(.white.opacity(0.12)))
            }
            pad(center: CGPoint(x: layout.foeFeet.x, y: layout.foeFeet.y - 2), width: 96, height: 16)
            pad(center: CGPoint(x: layout.allyFeet.x, y: layout.allyFeet.y - 4), width: 118, height: 18)
        }
        .allowsHitTesting(false)
    }
}

/// The games' text box: battle messages, or what the party is up to.
private struct SceneTextBox: View {
    static let height: CGFloat = 20
    let caption: String?

    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        HStack(spacing: 5) {
            if let caption {
                Text(caption)
            } else if !adventure.isBattling {
                Image(systemName: "moon.zzz.fill").foregroundStyle(.white.opacity(0.6))
                Text("Stages move on while an agent works")
            } else if let status = status(adventure) {
                Text(status)
            }
        }
        .font(.system(size: 9.5, weight: .semibold))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.9), radius: 1, y: 0.5)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 9)
        .padding(.top, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .frame(height: Self.height)
        // A see-through strip: the scene shows through while the words stay readable.
        .background(LinearGradient(colors: [.black.opacity(0), .black.opacity(0.62)], startPoint: .top, endPoint: .bottom))
    }

    private func status(_ adventure: AdventureService) -> String? {
        guard let repeating = adventure.progress.repeating else { return nil }
        return String(localized: "Repeating \(repeating.chapter + 1)-\(repeating.station + 1)")
    }
}

/// What the party is fighting at the top left; Next station at the top right while the party is
/// repeating a station or training behind the next one.
private struct SceneChrome: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        HStack(spacing: 4) {
            Text(label(adventure))
                .font(.system(size: 9, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(height: 15)
                .background(.black.opacity(0.42), in: Capsule())
            Spacer(minLength: 4)
            if !adventure.isChallenging, adventure.isBehindFrontier {
                Button {
                    withAnimation(.smooth(duration: 0.25)) { adventure.resumeJourney() }
                } label: {
                    HStack(spacing: 2) {
                        Text("Next station")
                        Image(systemName: "arrow.forward")
                    }
                    .font(.system(size: 8.5, weight: .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .frame(height: 15)
                    .background(Color(hex: 0xFFD35A), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Take on the next station now")
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 5)
    }

    private func label(_ adventure: AdventureService) -> String {
        guard let target = adventure.target else { return "" }
        let chapters = adventure.chapters
        switch target {
        case .station(let point):
            let text = "\(point.chapter + 1)-\(point.station + 1)"
            return adventure.progress.isTraining || adventure.progress.repeating != nil ? "↻ " + text : text
        case .boss(let chapter, let index):
            guard let info = chapters[safeChapter: chapter], info.bosses.indices.contains(index) else { return "" }
            let trainer = info.bosses[index]
            return info.isLeague && !trainer.isChampion ? "\(trainer.title) \(index + 1)/4 · \(trainer.name)" : "\(trainer.title) · \(trainer.name)"
        case .legend(let id):
            return "★ " + (adventure.data?.legend(id).flatMap { adventure.dex.species($0.species)?.name } ?? "")
        case .dungeon(let kind, let stage):
            let count = adventure.battle?.plan.foes.count ?? DailyDungeon.foes(stage: stage)
            let foe = min((adventure.battle?.foeIndex ?? 0) + 1, count)
            return "\(ChallengeText.dungeon(kind)) \(ChallengeText.stage(stage)) · \(foe)/\(count)"
        case .tower(let floor):
            return "\(ChallengeText.tower) · \(ChallengeText.floor(floor))"
        }
    }
}

/// Name, level and HP of the foe, with its trainer's remaining Pokémon.
private struct FoePlate: View {
    static let width: CGFloat = 112
    let foe: Combatant
    let battle: BattleState

    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(app.adventure.dex.species(foe.speciesID)?.name ?? "")
                    .lineLimit(1)
                if let status = foe.status { StatusTag(ailment: status) }
                Spacer(minLength: 2)
                Text("Lv\(foe.level)").monospacedDigit()
            }
            .font(.system(size: 8.5, weight: .heavy))
            .foregroundStyle(.white)
            HealthBar(fraction: foe.hpFraction, width: FoePlate.width - 12, delay: 0.25)
            TeamBalls(members: battle.foes, activeID: foe.id)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(width: Self.width)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// The party's active Pokémon: name, level, HP, experience and the rest of the party.
private struct AllyPlate: View {
    static let width: CGFloat = 112
    let ally: Combatant
    let battle: BattleState

    @Environment(AppModel.self) private var app

    var body: some View {
        let owned = ally.ownedID.flatMap { app.adventure.pokemon($0) }
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(app.adventure.dex.species(ally.speciesID)?.name ?? "")
                    .lineLimit(1)
                if let status = ally.status { StatusTag(ailment: status) }
                Spacer(minLength: 2)
                Text("Lv\(ally.level)").monospacedDigit()
            }
            .font(.system(size: 8.5, weight: .heavy))
            .foregroundStyle(.white)
            HealthBar(fraction: ally.hpFraction, width: AllyPlate.width - 12, delay: 0.25)
            HStack(spacing: 3) {
                TeamBalls(members: battle.party, activeID: ally.id)
                if let owned {
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule().fill(Color(hex: 0x7FC8FF)).frame(width: 30 * owned.levelProgress)
                    }
                    .frame(width: 30, height: 2)
                }
                Spacer(minLength: 2)
                Text("\(max(0, ally.hp))/\(ally.maxHP)")
                    .font(.system(size: 7.5, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(width: Self.width)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// "독", "화상" or "마비" beside a name, in the colors the games use.
private struct StatusTag: View {
    let ailment: Ailment

    var body: some View {
        Text(BattleText.tag(ailment))
            .font(.system(size: 7, weight: .black))
            .foregroundStyle(.white)
            .padding(.horizontal, 3)
            .frame(height: 10)
            .background(color, in: RoundedRectangle(cornerRadius: 2.5, style: .continuous))
            .fixedSize()
    }

    private var color: Color {
        switch ailment {
        case .poison: Color(hex: 0xA040A0)
        case .burn: Color(hex: 0xE0602C)
        case .paralysis: Color(hex: 0xC8A818)
        }
    }
}

struct HealthBar: View {
    let fraction: Double
    let width: CGFloat
    /// Seconds to wait before moving, so a battle's bar drops as the hit lands.
    var delay: Double = 0

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.black.opacity(0.55))
            Capsule().fill(color).frame(width: max(0, width * fraction))
        }
        .frame(width: width, height: 3.5)
        .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
        .animation(.smooth(duration: 0.4).delay(delay), value: fraction)
    }

    private var color: Color {
        fraction > 0.5 ? Color(hex: 0x5CE07A) : (fraction > 0.2 ? Color(hex: 0xF7D02C) : Color(hex: 0xFF5A4A))
    }
}

/// A Poké Ball per team member: bright while it can fight, dim once it's fainted.
private struct TeamBalls: View {
    let members: [Combatant]
    let activeID: UUID

    var body: some View {
        HStack(spacing: 2) {
            ForEach(members) { member in
                PokeBallDot(fainted: member.isFainted, active: member.id == activeID)
            }
        }
    }
}

struct PokeBallDot: View {
    var fainted = false
    var active = false
    var size: CGFloat = 6

    var body: some View {
        ZStack {
            Circle().fill(fainted ? Color(hex: 0x3A3A44) : .white)
            Rectangle().fill(fainted ? Color(hex: 0x2A2A30) : Color(hex: 0xE8453C))
                .frame(height: size / 2)
                .offset(y: -size / 4)
                .clipShape(Circle())
            Rectangle().fill(.black.opacity(0.6)).frame(height: 0.8)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(active ? Color(hex: 0xFFE14D) : .black.opacity(0.4), lineWidth: active ? 1 : 0.5))
    }
}

/// How the scene shakes when a move lands.
private struct SceneShake {
    var amount: CGFloat
    var seconds: Double
    /// Earthquakes rock the scene up and down too.
    var vertical: CGFloat { amount >= 3 ? 1 : 0.3 }
}

/// "1-3 도착 · 별의모래 +20" on a dark pill.
private struct ArrivalBanner: View {
    let arrival: Arrival

    var body: some View {
        HStack(spacing: 3) {
            StardustIcon(size: 11)
            Text(GuideText.arrived(arrival))
                .font(.system(size: 9.5, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(Color(hex: 0xFFE14D))
        }
        .padding(.horizontal, 8)
        .frame(height: 19)
        .background(.black.opacity(0.62), in: Capsule())
        .overlay(Capsule().strokeBorder(Color(hex: 0xFFE14D).opacity(0.45), lineWidth: 1))
        .fixedSize()
    }
}

struct ScenePopup: Identifiable, Equatable {
    enum Style { case dealt, taken, healed, note, xp }
    /// How hard a hit was, for the number's size and color.
    enum Weight { case weak, normal, strong, critical }
    let id = UUID()
    let text: String
    let style: Style
    let point: CGPoint
    var weight: Weight = .normal
}

private struct ScenePopupView: View {
    let popup: ScenePopup
    @State private var shown = false

    private struct Motion {
        var scale: CGFloat = 1
        var rise: CGFloat = 0
        var opacity: Double = 0
    }

    var body: some View {
        switch popup.style {
        case .dealt, .taken, .healed: number
        case .note, .xp: label
        }
    }

    /// Damage lands big and settles, then drifts up.
    private var number: some View {
        let pop: CGFloat = switch popup.weight {
        case .critical: 2.1
        case .strong: 1.8
        case .normal: 1.6
        case .weak: 1.3
        }
        return Text(popup.text)
            .font(.system(size: size, weight: .black, design: .rounded).monospacedDigit())
            .foregroundStyle(color)
            .shadow(color: .black, radius: 0, x: 1, y: 1)
            .shadow(color: .black, radius: 0, x: -0.8, y: -0.4)
            .shadow(color: .black.opacity(0.5), radius: 2)
            .fixedSize()
            .keyframeAnimator(initialValue: Motion(), trigger: shown) { content, motion in
                content
                    .scaleEffect(motion.scale)
                    .offset(y: motion.rise)
                    .opacity(motion.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    MoveKeyframe(pop)
                    SpringKeyframe(1, duration: 0.3, spring: .init(response: 0.22, dampingRatio: 0.5))
                    LinearKeyframe(1, duration: 0.3)
                    LinearKeyframe(0.9, duration: 0.4)
                }
                KeyframeTrack(\.rise) {
                    LinearKeyframe(0, duration: 0.55)
                    CubicKeyframe(-16, duration: 0.45)
                }
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(1)
                    LinearKeyframe(1, duration: 0.65)
                    LinearKeyframe(0, duration: 0.35)
                }
            }
            .onAppear { shown = true }
    }

    private var label: some View {
        Text(popup.text)
            .font(.system(size: 8.5, weight: .heavy).monospacedDigit())
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.85), radius: 1, y: 1)
            .fixedSize()
            .offset(y: shown ? -12 : 0)
            .opacity(shown ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 0.9)) { shown = true } }
    }

    private var size: CGFloat {
        guard popup.style != .healed else { return 12 }
        return switch popup.weight {
        case .critical: 21
        case .strong: 18
        case .normal: 15.5
        case .weak: 12.5
        }
    }

    private var color: Color {
        switch popup.style {
        case .dealt:
            switch popup.weight {
            case .critical: Color(hex: 0xFFE14D)
            case .strong: Color(hex: 0xFFB347)
            case .normal: .white
            case .weak: Color(hex: 0xD4D4DC)
            }
        case .taken:
            switch popup.weight {
            case .critical: Color(hex: 0xFFD04A)
            case .strong: Color(hex: 0xFF6A58)
            case .normal: Color(hex: 0xFF8A80)
            case .weak: Color(hex: 0xFFB8B0)
            }
        case .healed: Color(hex: 0x7CF0A0)
        case .note: Color(hex: 0xFFE14D)
        case .xp: Color(hex: 0x7FC8FF)
        }
    }
}

/// A pixel landscape per kind of place: sky bands with a dithered seam, and ground tiles.
struct StageBackdrop: View {
    let scenery: Scenery

    private struct Theme {
        var skyTop: UInt32, skyBottom: UInt32, ground: UInt32, groundDark: UInt32
        var horizon: CGFloat = 0.5
    }

    private var theme: Theme {
        switch scenery {
        case .meadow: Theme(skyTop: 0x3A86E0, skyBottom: 0xB8E4FF, ground: 0x6CC05A, groundDark: 0x4E9A44)
        case .forest: Theme(skyTop: 0x1E4A3A, skyBottom: 0x5E9A6A, ground: 0x3E7A3A, groundDark: 0x2C5A2A)
        case .cave: Theme(skyTop: 0x1E1A22, skyBottom: 0x4A4048, ground: 0x6A5A4C, groundDark: 0x4E4238)
        case .sea: Theme(skyTop: 0x2A6AD0, skyBottom: 0x9AD8F8, ground: 0x3A8AD8, groundDark: 0x2A6AB8, horizon: 0.42)
        case .volcano: Theme(skyTop: 0x4A1A1A, skyBottom: 0xC85A2A, ground: 0x5A3A30, groundDark: 0x3A2420)
        case .ice: Theme(skyTop: 0x6A8AB8, skyBottom: 0xD8ECFF, ground: 0xE8F2FF, groundDark: 0xB8CCE4)
        case .tower: Theme(skyTop: 0x1A1430, skyBottom: 0x4A3A6A, ground: 0x5A4A6A, groundDark: 0x3E3250)
        case .gym: Theme(skyTop: 0x5A4E44, skyBottom: 0x8A7A68, ground: 0xC8B48A, groundDark: 0xA8946C, horizon: 0.4)
        case .league: Theme(skyTop: 0x2A1A4A, skyBottom: 0x6A3A8A, ground: 0x8A6AA8, groundDark: 0x6A4A88, horizon: 0.4)
        case .plant: Theme(skyTop: 0x2A2E24, skyBottom: 0x5A6040, ground: 0x6A6A5A, groundDark: 0x4A4A3E)
        }
    }

    var body: some View {
        let theme = theme
        Canvas { canvas, size in
            let pixel: CGFloat = 2
            let horizon = (size.height * theme.horizon / pixel).rounded() * pixel
            let bands = 5
            for band in 0..<bands {
                let t = Double(band) / Double(bands - 1)
                let top = CGFloat(band) * horizon / CGFloat(bands)
                let bottom = CGFloat(band + 1) * horizon / CGFloat(bands)
                canvas.fill(Path(CGRect(x: 0, y: top, width: size.width, height: bottom - top + 0.5)),
                            with: .color(Color(hex: Self.mix(theme.skyTop, theme.skyBottom, t))))
                if band + 1 < bands {
                    let next = Color(hex: Self.mix(theme.skyTop, theme.skyBottom, Double(band + 1) / Double(bands - 1)))
                    for x in stride(from: 0, to: size.width, by: pixel * 2) {
                        canvas.fill(Path(CGRect(x: x, y: bottom - pixel, width: pixel, height: pixel)), with: .color(next))
                    }
                }
            }
            canvas.fill(Path(CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon)), with: .color(Color(hex: theme.ground)))
            // A checker of darker tiles so the ground reads as pixel art.
            var row = 0
            for y in stride(from: horizon + pixel * 3, to: size.height, by: pixel * 4) {
                for x in stride(from: CGFloat(row % 2) * pixel * 6, to: size.width, by: pixel * 12) {
                    canvas.fill(Path(CGRect(x: x, y: y, width: pixel * 3, height: pixel)), with: .color(Color(hex: theme.groundDark)))
                }
                row += 1
            }
            canvas.fill(Path(CGRect(x: 0, y: horizon, width: size.width, height: pixel)), with: .color(Color(hex: theme.groundDark)))
        }
    }

    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let x = Double((a >> shift) & 0xFF), y = Double((b >> shift) & 0xFF)
            return UInt32((x + (y - x) * t).rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }
}
