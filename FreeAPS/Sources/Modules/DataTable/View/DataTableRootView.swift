import SwiftUI
import Swinject

extension DataTable {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        @State private var isRemoveCarbsAlertPresented = false
        @State private var removeCarbsAlert: Alert?

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
                    }
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(
                leading: Button("Close", action: state.hideModal),
                trailing: state.mode == .glucose ? HStack {
                    Button(action: { state.showModal(for: .addGlucose) }) {
                        Image(systemName: "plus")
                    }
                    EditButton()
                }.asAny() : EmptyView().asAny()
            )
        }

        private var treatmentsList: some View {
            List {
                ForEach(state.treatments) { item in
                    treatmentView(item)
                }
            }
        }

        private var glucoseList: some View {
            List {
                ForEach(state.glucose) { item in
                    gluciseView(item)
                }.onDelete(perform: deleteGlucose)
            }
        }

        @ViewBuilder private func treatmentView(_ item: Treatment) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "circle.fill").foregroundColor(item.color)
                    Text(dateFormatter.string(from: item.date))
                        .moveDisabled(true)
                    Text(item.type.name)
                    Text(item.amountText).foregroundColor(.secondary)
                    if let duration = item.durationText {
                        Text(duration).foregroundColor(.secondary)
                    }

                    if item.type == .carbs {
                        Spacer()
                        Image(systemName: "xmark.circle").foregroundColor(.secondary)
                            .contentShape(Rectangle())
                            .padding(.vertical)
                            .onTapGesture {
                                removeCarbsAlert = Alert(
                                    title: Text("Delete carbs?"),
                                    message: Text(item.amountText),
                                    primaryButton: .destructive(
                                        Text("Delete"),
                                        action: {
                                            state.deleteCarbs(item)
                                        }
                                    ),
                                    secondaryButton: .cancel()
                                )
                                isRemoveCarbsAlertPresented = true
                            }
                            .alert(isPresented: $isRemoveCarbsAlertPresented) {
                                removeCarbsAlert!
                            }
                    }
                }
                if item.type == .carbs, let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                }
                if item.type == .bolus, let rec = item.insulinRecommendation, rec > 0 {
                    Text("Recommended: \(insulinFormatter.string(from: rec as NSNumber) ?? "0") U")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                }
            }
        }

        @ViewBuilder private func gluciseView(_ item: Glucose) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dateFormatter.string(from: item.glucose.dateString))
                    if item.glucose.type == "manual" {
                        Text("Manual")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange))
                    }
                    Spacer()
                    Text(item.glucose.glucose.map {
                        glucoseFormatter.string(from: Double(
                            state.units == .mmolL ? $0.asMmolL : Decimal($0)
                        ) as NSNumber)!
                    } ?? "--")
                    Text(state.units.rawValue)
                    Text(item.glucose.direction?.symbol ?? "--")
                }
                Text("ID: " + item.glucose.id).font(.caption2).foregroundColor(.secondary)
            }
        }

        private func deleteGlucose(at offsets: IndexSet) {
            state.deleteGlucose(at: offsets[offsets.startIndex])
        }
    }
}
