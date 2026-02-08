import SwiftUI
import Swinject

extension AddEvent {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        let editingEvent: EventEntry?

        init(resolver: Resolver, editingEvent: EventEntry? = nil) {
            self.resolver = resolver
            self.editingEvent = editingEvent
        }

        var body: some View {
            Form {
                Section(header: Text("Event Details")) {
                    TextField(
                        NSLocalizedString("Event name", comment: "Event name placeholder"),
                        text: $state.name
                    )
                    DatePicker(
                        NSLocalizedString("Start time", comment: "Event start time"),
                        selection: $state.startDate
                    )
                    Toggle(
                        NSLocalizedString("End time", comment: "Event end time toggle"),
                        isOn: $state.hasEndDate
                    )
                    if state.hasEndDate {
                        DatePicker(
                            NSLocalizedString("End time", comment: "Event end time"),
                            selection: $state.endDate
                        )
                    }
                }

                Section {
                    Button {
                        state.save()
                    } label: {
                        Text(
                            state.isEditing ?
                                NSLocalizedString("Save Changes", comment: "Save event changes button") :
                                NSLocalizedString("Add Event", comment: "Add event button")
                        )
                    }
                    .disabled(state.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !state.isEditing, !state.recentNames.isEmpty {
                    Section(header: recentEventsHeader) {
                        if state.isEditingRecentNames {
                            recentNamesEditList
                        } else {
                            recentNamesBadges
                        }
                    }
                }
            }
            .onAppear {
                configureView {
                    state.editingEvent = editingEvent
                }
            }
            .navigationTitle(
                state.isEditing ?
                    NSLocalizedString("Edit Event", comment: "Edit event screen title") :
                    NSLocalizedString("Add Event", comment: "Add event screen title")
            )
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(leading: Button(
                NSLocalizedString("Close", comment: "Close button"),
                action: state.hideModal
            ))
        }

        private var recentEventsHeader: some View {
            HStack {
                Text("Recent Events")
                Spacer()
                Button {
                    withAnimation {
                        state.isEditingRecentNames.toggle()
                    }
                } label: {
                    Text(
                        state.isEditingRecentNames ?
                            NSLocalizedString("Done", comment: "Done editing button") :
                            NSLocalizedString("Edit", comment: "Edit button")
                    )
                    .font(.caption)
                    .textCase(.none)
                }
            }
        }

        private var recentNamesBadges: some View {
            FlowLayout(spacing: 8) {
                ForEach(state.recentNames, id: \.self) { recentName in
                    badgeView(for: recentName)
                }
            }
            .padding(.vertical, 4)
        }

        private func badgeView(for recentName: String) -> some View {
            let isSelected = state.name == recentName
            return Text(recentName)
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
                    state.selectRecentName(recentName)
                }
        }

        private var recentNamesEditList: some View {
            ForEach(state.recentNames, id: \.self) { recentName in
                HStack {
                    Text(recentName)
                    Spacer()
                    Button {
                        withAnimation {
                            state.deleteRecentName(recentName)
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
