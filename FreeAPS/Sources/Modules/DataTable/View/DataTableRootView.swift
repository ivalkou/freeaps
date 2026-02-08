import SwiftUI
import Swinject

extension DataTable {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        @State private var treatmentToDelete: Treatment?
        @State private var isDeleteAlertPresented = false

        private var glucoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            if state.units == .mmolL {
                formatter.minimumFractionDigits = 1
                formatter.maximumFractionDigits = 1
            }
            formatter.roundingMode = .halfUp
            return formatter
        }

        private var dateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter
        }

        private var insulinFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        private var localizedUnits: String {
            NSLocalizedString(state.units.rawValue, comment: "Glucose units")
        }

        var body: some View {
            VStack {
                Picker("Mode", selection: $state.mode) {
                    ForEach(Mode.allCases.indexed(), id: \.1) { index, item in
                        Text(item.name).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                Form {
                    switch state.mode {
                    case .treatments: treatmentsList
                    case .glucose: glucoseList
                    case .events: eventsList
                    }
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(
                leading: Button("Close", action: state.hideModal),
                trailing: Group {
                    if state.mode == .glucose {
                        Button(action: { state.showModal(for: .addGlucose) }) {
                            Image(systemName: "plus")
                        }
                    } else if state.mode == .events {
                        Button(action: { state.showModal(for: .addEvent) }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            )
            .alert(isPresented: $isDeleteAlertPresented) {
                guard let treatment = treatmentToDelete else {
                    return Alert(title: Text("Error"))
                }
                let title: String
                let message: String
                switch treatment.type {
                case .carbs:
                    title = NSLocalizedString("Delete carbs?", comment: "Delete carbs alert title")
                    message = treatment.amountText
                case .tempTarget:
                    title = NSLocalizedString("Delete temp target?", comment: "Delete temp target alert title")
                    message = treatment.amountText
                default:
                    title = NSLocalizedString("Delete?", comment: "Delete alert title")
                    message = ""
                }
                return Alert(
                    title: Text(title),
                    message: Text(message),
                    primaryButton: .destructive(Text("Delete")) {
                        performDelete(treatment)
                    },
                    secondaryButton: .cancel()
                )
            }
        }

        private func performDelete(_ treatment: Treatment) {
            switch treatment.type {
            case .carbs:
                state.deleteCarbs(treatment)
            case .tempTarget:
                state.deleteTempTarget(treatment)
            default:
                break
            }
        }

        // MARK: - Treatments

        private var treatmentsList: some View {
            List {
                ForEach(state.treatments) { item in
                    treatmentView(item)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if item.type == .carbs || item.type == .tempTarget {
                                Button(role: .destructive) {
                                    treatmentToDelete = item
                                    isDeleteAlertPresented = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }
            }
        }

        @ViewBuilder private func treatmentView(_ item: Treatment) -> some View {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.color)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 0) {
                    Text(dateFormatter.string(from: item.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 50, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.type.name)
                    if !item.amountText.isEmpty || item.durationText != nil {
                        HStack(spacing: 4) {
                            Text(item.amountText)
                            if let duration = item.durationText {
                                Text("·")
                                Text(duration)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    if item.type == .carbs, let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if item.type == .bolus, let rec = item.insulinRecommendation, rec > 0 {
                        Text("Recommended: \(insulinFormatter.string(from: rec as NSNumber) ?? "0") U")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }

        // MARK: - Glucose

        private var glucoseList: some View {
            List {
                ForEach(state.glucose) { item in
                    gluciseView(item)
                }.onDelete(perform: deleteGlucose)
            }
        }

        @ViewBuilder private func gluciseView(_ item: Glucose) -> some View {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.loopGreen)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 0) {
                    Text(dateFormatter.string(from: item.glucose.dateString))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 50, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.glucose.glucose.map {
                            glucoseFormatter.string(from: Double(
                                state.units == .mmolL ? $0.asMmolL : Decimal($0)
                            ) as NSNumber)!
                        } ?? "--")
                        Text(localizedUnits)
                        Text(item.glucose.direction?.symbol ?? "--")
                        if item.glucose.type == "manual" {
                            Text("Manual")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange))
                        }
                    }
                    Text("ID: " + item.glucose.id)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }

        private func deleteGlucose(at offsets: IndexSet) {
            state.deleteGlucose(at: offsets[offsets.startIndex])
        }

        // MARK: - Events

        private var eventsList: some View {
            List {
                ForEach(state.events) { event in
                    eventView(event)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            state.showModal(for: .editEvent(event: event))
                        }
                }.onDelete(perform: deleteEvent)
            }
        }

        @ViewBuilder private func eventView(_ event: EventEntry) -> some View {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.purple)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 0) {
                    Text(dateFormatter.string(from: event.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 50, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name)
                    HStack(spacing: 12) {
                        if let startBG = state.nearestGlucose(to: event.createdAt),
                           let sgv = startBG.glucose
                        {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.right").font(.caption2)
                                Text(formattedGlucose(sgv))
                                Text(localizedUnits)
                            }
                        }
                        if let endAt = event.endAt {
                            if let endBG = state.nearestGlucose(to: endAt),
                               let sgv = endBG.glucose
                            {
                                HStack(spacing: 2) {
                                    Image(systemName: "flag.checkered").font(.caption2)
                                    Text(formattedGlucose(sgv))
                                    Text(localizedUnits)
                                }
                            }
                            Text(
                                String(
                                    format: NSLocalizedString("Until: %@", comment: "Event end time"),
                                    dateFormatter.string(from: endAt)
                                )
                            )
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }

        private func formattedGlucose(_ value: Int) -> String {
            if state.units == .mmolL {
                return glucoseFormatter.string(from: Double(value.asMmolL) as NSNumber) ?? "--"
            }
            return glucoseFormatter.string(from: value as NSNumber) ?? "--"
        }

        private func deleteEvent(at offsets: IndexSet) {
            for index in offsets {
                state.deleteEvent(state.events[index])
            }
        }
    }
}
