import EventKit
import Observation

/// Today's upcoming calendar events for the expanded notch.
@Observable
final class CalendarService {
    struct Event: Identifiable, Equatable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
        let color: CGColor?
    }

    private(set) var events: [Event] = []
    private(set) var authorization: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private var refreshTimer: Timer?

    var isAuthorized: Bool { authorization == .fullAccess }

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    func start() {
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        reload()
    }

    func requestAccess() {
        Task {
            _ = try? await store.requestFullAccessToEvents()
            authorization = EKEventStore.authorizationStatus(for: .event)
            reload()
        }
    }

    func reload() {
        authorization = EKEventStore.authorizationStatus(for: .event)
        guard preferences.calendarEnabled, isAuthorized else {
            events = []
            return
        }
        let now = Date()
        let calendar = Calendar.current
        guard let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) else { return }
        let predicate = store.predicateForEvents(withStart: calendar.startOfDay(for: now), end: endOfDay, calendars: nil)
        events = store.events(matching: predicate)
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .prefix(4)
            .map {
                Event(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    title: $0.title ?? String(localized: "Untitled"),
                    start: $0.startDate,
                    end: $0.endDate,
                    isAllDay: $0.isAllDay,
                    color: $0.calendar?.cgColor
                )
            }
    }
}
