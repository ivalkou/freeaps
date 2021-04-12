import Intents
import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in _: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), lastGlucose: nil)
    }

    func getSnapshot(in _: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date(), lastGlucose: nil)
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date(), lastGlucose: BloodGlucose(
            _id: "sd",
            sgv: 100,
            direction: .flat,
            date: Decimal(Date().timeIntervalSince1970 * 1000),
            dateString: Date(),
            filtered: nil,
            noise: 1,
            glucose: 100
        ))

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
}

struct FreeAPSWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        CurrentGlucoseView(
            recentGlucose: .constant(entry.lastGlucose),
            delta: .constant(5),
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
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
        .supportedFamilies([.systemMedium])
    }
}

struct FreeAPSWidget_Previews: PreviewProvider {
    static var previews: some View {
        let glucose = BloodGlucose(
            _id: "sd",
            sgv: 100,
            direction: .flat,
            date: Decimal(Date().timeIntervalSince1970 * 1000),
            dateString: Date(),
            filtered: nil,
            noise: 1,
            glucose: 100
        )
        return FreeAPSWidgetEntryView(entry: SimpleEntry(date: Date(), lastGlucose: glucose))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
