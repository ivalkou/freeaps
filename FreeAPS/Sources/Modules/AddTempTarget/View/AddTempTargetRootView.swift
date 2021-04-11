import SwiftUI

extension AddTempTarget {
    struct RootView: BaseView {
        @EnvironmentObject var viewModel: ViewModel<Provider>
        @State private var isPromtPresented = false
        @State private var isRemoveAlertPresented = false
        @State private var removeAlert: Alert?

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        var body: some View {
            Form {
                if !viewModel.presets.isEmpty {
                    Section(header: Text(NSLocalizedString("Presets", comment: "Presets title"))) {
                        ForEach(viewModel.presets) { preset in
                            presetView(for: preset)
                        }
                    }
                }

                Section(header: Text(NSLocalizedString("Custom", comment: "Custom target temp"))) {
                    HStack {
                        Text(NSLocalizedString("Bottom target", comment: "Bottom target temp"))
                        Spacer()
                        DecimalTextField("0", value: $viewModel.low, formatter: formatter, cleanInput: true)
                        Text(viewModel.units.rawValue).foregroundColor(.secondary)
                    }
                    HStack {
                        Text(NSLocalizedString("Top target", comment: "Top target temp"))
                        Spacer()
                        DecimalTextField("0", value: $viewModel.high, formatter: formatter, cleanInput: true)
                        Text(viewModel.units.rawValue).foregroundColor(.secondary)
                    }
                    HStack {
                        Text(NSLocalizedString("Duration", comment: "Duration target temp"))
                        Spacer()
                        DecimalTextField("0", value: $viewModel.duration, formatter: formatter, cleanInput: true)
                        Text(NSLocalizedString("minutes", comment: "minutes target temp")).foregroundColor(.secondary)
                    }
                    DatePicker(NSLocalizedString("Date", comment: "Date"), selection: $viewModel.date)
                    Button { isPromtPresented = true }
                    label: { Text(NSLocalizedString("Save as preset", comment: "Save as preset")) }
                }

                Section {
                    Button { viewModel.enact() }
                    label: { Text(NSLocalizedString("Enact temp target", comment: "Enact temp target")) }
                    Button { viewModel.cancel() }
                    label: { Text(NSLocalizedString("Cancel temp target", comment: "Cancel temp target")) }
                }
            }
            .popover(isPresented: $isPromtPresented) {
                Form {
                    Section(header: Text(NSLocalizedString("Enter preset name", comment: "Enter preset name"))) {
                        TextField("Name", text: $viewModel.newPresetName)
                        Button {
                            viewModel.save()
                            isPromtPresented = false
                        }
                        label: { Text(NSLocalizedString("Save", comment: "Save preset name")) }
                        Button { isPromtPresented = false }
                        label: { Text(NSLocalizedString("Cancel", comment: "Cancel preset name")) }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Enact temp target", comment: "Enact temp target"))
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(leading: Button(NSLocalizedString("Close", comment: "Close"), action: viewModel.hideModal))
        }

        private func presetView(for preset: TempTarget) -> some View {
            var low = preset.targetBottom
            var high = preset.targetTop
            if viewModel.units == .mmolL {
                low = low?.asMmolL
                high = high?.asMmolL
            }
            return HStack {
                VStack {
                    HStack {
                        Text(preset.displayName)
                        Spacer()
                    }
                    HStack {
                        Text(
                            "\(formatter.string(from: (low ?? 0) as NSNumber)!) - \(formatter.string(from: (high ?? 0) as NSNumber)!)"
                        )
                        .foregroundColor(.secondary)
                        .font(.caption)

                        Text(viewModel.units.rawValue)
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("for \(formatter.string(from: preset.duration as NSNumber)!) min")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Spacer()
                    }.padding(.top, 2)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.enactPreset(id: preset.id)
                }

                Image(systemName: "xmark.circle").foregroundColor(.secondary)
                    .contentShape(Rectangle())
                    .padding(.vertical)
                    .onTapGesture {
                        removeAlert = Alert(
                            title: Text(NSLocalizedString("A you sure?", comment: "A you sure delete preset?")),
                            message: Text(
                                String(
                                    format: NSLocalizedString("Delete preset %@", comment: "Delete preset %@"),
                                    preset.displayName
                                )
                            ),
                            primaryButton: .destructive(
                                Text(NSLocalizedString("Delete", comment: "Delete")),
                                action: { viewModel.removePreset(id: preset.id) }
                            ),
                            secondaryButton: .cancel()
                        )
                        isRemoveAlertPresented = true
                    }
                    .alert(isPresented: $isRemoveAlertPresented) {
                        removeAlert!
                    }
            }
        }
    }
}
