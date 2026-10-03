//
//  Provider.swift
//  identeam
//
//  Created by Nico Stern on 30.09.26.
//

import SwiftData
import System
import WidgetKit

struct Provider: TimelineProvider {
    // dummy data, e.g. in gallery
    func placeholder(in context: Context) -> WeekEntry {
        WeekEntry(date: Date(), week: .templateKanten)
    }

    // fast preview, e.g. in gallery preview
    func getSnapshot(in context: Context, completion: @escaping (WeekEntry) -> Void) {
        let week = loadWeek() ?? .templateKanten  // TODO "not found"
        completion(WeekEntry(date: Date(), week: week))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let week = loadWeek() ?? .templateKanten  // TODO "not found"
        var entry = WeekEntry(date: Date(), week: week)

        completion(Timeline(entries: [entry], policy: .never))
    }

    private func loadWeek() -> TeamWeek? {
        let container = SharedModelConfig.makeContainer(for: .widget)
        let context = ModelContext(container)

        let slug = "die-kanten"
        let currentWeekStart = AppCalendar.startOfWeek(containing: Date())
        let descriptor = FetchDescriptor<TeamWeek>(
            predicate: #Predicate {
                $0.weekStart == currentWeekStart && $0.slug == slug
            }
        )

        return try? context.fetch(descriptor).first
    }
}
