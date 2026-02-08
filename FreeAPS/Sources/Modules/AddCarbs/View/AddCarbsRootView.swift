import SwiftUI
import Swinject

extension AddCarbs {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
        }

        var body: some View {
            Form {
                if let carbsReq = state.carbsRequired {
                    Section {
                        HStack {
                            Text("Carbs required")
                            Spacer()
                            Text(formatter.string(from: carbsReq as NSNumber)! + " g")
                        }
                    }
                }
                Section {
                    HStack {
                        Text("Amount")
                        Spacer()
                        DecimalTextField("0", value: $state.carbs, formatter: formatter, autofocus: true, cleanInput: true)
                        Text("grams").foregroundColor(.secondary)
                    }
                    DatePicker("Date", selection: $state.date)
                    TextField(
                        NSLocalizedString("Note (what you ate)", comment: "Carbs note placeholder"),
                        text: $state.note
                    )
                }

                Section {
                    Button { state.add() }
                    label: { Text("Add") }
                        .disabled(state.carbs <= 0)
                    VStack(alignment: .leading, spacing: 5) {
                        Button { state.fastAdd() }
                        label: { Text("Fast Add") }
                            .disabled(state.carbs <= 0)
                        Text(
                            "Carbs will add and FreeAPX X will update forecasts without bolus"
                        )
                        .font(.caption)
                        .foregroundColor(Color.secondary)
                    }
                    .padding(.top, 5)
                }

                if !state.recentPresets.isEmpty {
                    Section(header: recentPresetsHeader) {
                        if state.isEditingPresets {
                            recentPresetsEditList
                        } else {
                            recentPresetsBadges
                        }
                    }
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Add Carbs")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(leading: Button("Close", action: state.hideModal))
        }

        private var recentPresetsHeader: some View {
            HStack {
                Text("Recent Carbs")
                Spacer()
                Button {
                    withAnimation {
                        state.isEditingPresets.toggle()
                    }
                } label: {
                    Text(
                        state.isEditingPresets ?
                            NSLocalizedString("Done", comment: "Done editing button") :
                            NSLocalizedString("Edit", comment: "Edit button")
                    )
                    .font(.caption)
                    .textCase(.none)
                }
            }
        }

        private var recentPresetsBadges: some View {
            FlowLayout(spacing: 8) {
                ForEach(state.recentPresets) { preset in
                    presetBadge(for: preset)
                }
            }
            .padding(.vertical, 4)
        }

        private func presetBadge(for preset: RecentCarbPreset) -> some View {
            let isSelected = state.note == preset.name && state.carbs == preset.carbs
            return Text(state.presetLabel(preset))
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        isSelected
                            ? Color.accentColor.opacity(0.2)
                            : Color.secondary.opacity(0.15)
                    )
                )
                .foregroundColor(isSelected ? .accentColor : .primary)
                .overlay(
                    Capsule().stroke(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 1
                    )
                )
                .contentShape(Capsule())
                .onTapGesture {
                    state.selectPreset(preset)
                }
        }

        private var recentPresetsEditList: some View {
            ForEach(state.recentPresets) { preset in
                HStack {
                    Text(state.presetLabel(preset))
                    Spacer()
                    Button {
                        withAnimation {
                            state.deletePreset(preset)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
