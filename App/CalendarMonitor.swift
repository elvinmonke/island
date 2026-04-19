import Foundation
import EventKit
import AppKit

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarName: String
    let color: NSColor
    let isAllDay: Bool
}

final class CalendarMonitor: ObservableObject {
    @Published var upcomingEvents: [CalendarEvent] = []
    @Published var hasAccess: Bool = false

    private let store = EKEventStore()
    private var timer: Timer?

    init() {
        checkCurrentStatus()
    }

    private func checkCurrentStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess || status == .authorized {
            hasAccess = true
            fetchEvents()
            startPolling()
        }
    }

    deinit { timer?.invalidate() }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted {
                        self?.fetchEvents()
                        self?.startPolling()
                    }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted {
                        self?.fetchEvents()
                        self?.startPolling()
                    }
                }
            }
        }
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.fetchEvents()
        }
    }

    func fetchEvents() {
        let now = Date()
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate)

        DispatchQueue.main.async {
            self.upcomingEvents = events.prefix(5).map { event in
                CalendarEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "No Title",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    calendarName: event.calendar.title,
                    color: NSColor(cgColor: event.calendar.cgColor) ?? .systemBlue,
                    isAllDay: event.isAllDay
                )
            }
        }
    }
}
