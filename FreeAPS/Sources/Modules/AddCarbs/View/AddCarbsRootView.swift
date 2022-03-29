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
                            "Carbs will add and FreeAPX X will determine and inject bolus without your participation"
                        )
                        .font(.caption)
                        .foregroundColor(Color.secondary)
                    }
                    .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 5) {
                        Button { state.addWithoutbolus() }
                        label: { Text("Simple Add") }
                            .disabled(state.carbs <= 0)
                        Text(
                            "Carbs will add without bolus"
                        )
                        .font(.caption)
                        .foregroundColor(Color.secondary)
                    }
                    .padding(.top, 5)
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Add Carbs")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(leading: Button("Close", action: state.hideModal))
        }
    }
}
