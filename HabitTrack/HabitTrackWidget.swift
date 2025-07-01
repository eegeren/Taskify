//
//  HabitTrackWidget.swift
//  HabitTrack
//
//  Created by Yusufege Eren on 1.07.2025.
//

import WidgetKit
import SwiftUI

// Widget için veri modeli
struct TaskProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: Date(), taskCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> ()) {
        let entry = TaskEntry(date: Date(), taskCount: 0)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: "group.com.yourcompany.HabitTrack") // AppGroup ID
        let taskCount = sharedDefaults?.integer(forKey: "taskCount") ?? 0
        let entries = [TaskEntry(date: Date(), taskCount: taskCount)]
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// Widget için giriş modeli
struct TaskEntry: TimelineEntry {
    let date: Date
    let taskCount: Int
}

// Widget görünümü
struct HabitTrackWidgetEntryView : View {
    var entry: TaskProvider.Entry

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground) // Arka plan
            VStack {
                Text("Görev Sayısı")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(entry.taskCount)")
                    .font(.largeTitle)
                    .foregroundColor(.primary)
            }
            .padding()
        }
    }
}

// Widget yapılandırması
struct HabitTrackWidget: Widget {
    let kind: String = "HabitTrackWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskProvider()) { entry in
            HabitTrackWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("HabitTrack Widget")
        .description("Görev sayınızı gösterir.")
        .supportedFamilies([.systemSmall]) // Küçük boyut
    }
}

// Önizleme
struct HabitTrackWidget_Previews: PreviewProvider {
    static var previews: some View {
        HabitTrackWidgetEntryView(entry: TaskEntry(date: Date(), taskCount: 5))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
