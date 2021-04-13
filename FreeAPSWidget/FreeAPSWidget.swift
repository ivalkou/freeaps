import Intents
import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in _: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), lastGlucose: nil, delta: nil)
    }

    func getSnapshot(in _: Context, completion: @escaping (SimpleEntry) -> Void) {
        let glucose = UserDefaults.appGroup?.getValue(BloodGlucose.self, forKey: "RecentGlucose")
        let delta = UserDefaults.appGroup?.getValue(Int.self, forKey: "GlucoseDelta")
        let entry = SimpleEntry(date: Date(), lastGlucose: glucose, delta: delta)
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let glucose = UserDefaults.appGroup?.getValue(BloodGlucose.self, forKey: "RecentGlucose")
        let delta = UserDefaults.appGroup?.getValue(Int.self, forKey: "GlucoseDelta")
        let entry = SimpleEntry(date: Date(), lastGlucose: glucose, delta: delta)

        let timeline = Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(60 * 15))
        )
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date

    let lastGlucose: BloodGlucose?
    let delta: Int?
}

struct FreeAPSWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        CurrentGlucoseView(
            recentGlucose: .constant(entry.lastGlucose),
            delta: .constant(entry.delta),
            units: .mmolL
        )
    }
}

@main struct FreeAPSWidget: Widget {
    let kind: String = "FreeAPSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FreeAPSWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("FreeAPS X status")
        .description("FreeAPS X status")
        .supportedFamilies([.systemMedium])
    }
}

struct FreeAPSWidget_Previews: PreviewProvider {
    static var previews: some View {
        let glucose = BloodGlucose(
            _id: "000000",
            sgv: 100,
            direction: .flat,
            date: Decimal(Date().timeIntervalSince1970 * 1000),
            dateString: Date(),
            filtered: nil,
            noise: 1,
            glucose: 100
        )
        return FreeAPSWidgetEntryView(entry: SimpleEntry(date: Date(), lastGlucose: glucose, delta: 0))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
