import SwiftUI

extension Home {
    struct RootView: BaseView {
        @EnvironmentObject var viewModel: ViewModel<Provider>
        @State var showHours = 1

        var previewChart: some View {
            GeometryReader { geo in
                CombinedChartView(
                    maxWidth: geo.size.width,
                    showHours: 24,
                    glucoseData: $viewModel.glucose,
                    predictionsData: []
                )
            }
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }

        var predictions: [PredictionLineData] {
            PredictionType.allCases.compactMap { predictionType in
                createPredictionData(for: predictionType, suggestion: viewModel.suggestion)
            }
        }

        var info: [InformationBarEntryData] {
            APSDataTypes.allCases.compactMap { dataType in
                createAPSInfo(for: dataType, suggestion: viewModel.suggestion)
            }
        }

        // Handle nil properly
        var currenGlucose: Double {
            Double(viewModel.glucose.last?.sgv ?? 0)
        }

        // Handle nil properly
        var delta: Double {
            currenGlucose - Double(viewModel.glucose.suffix(2).first?.sgv ?? 0)
        }

        var direction: BloodGlucose.Direction {
            viewModel.glucose.last?.direction ?? BloodGlucose.Direction.none
        }

        var body: some View {
            GeometryReader { geo in
                VStack {
                    GlucoseInformationBarView(data: info, glucoseValue: currenGlucose, glucoseDelta: delta, direction: direction)
                        .frame(height: 150)
                        .padding(.horizontal)
                    HoursPickerView(selectedHour: $showHours).padding(.horizontal)

                    MainChartView(
                        showHours: showHours,
                        glucoseData: $viewModel.glucose,
                        predictionsData: predictions
                    )
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal)

                    previewChart
                        .frame(height: 50)
                        .padding(.horizontal)

                    Button(action: viewModel.runLoop) {
                        Text("Run loop now").buttonBackground().padding()
                    }.foregroundColor(.white)

                    ZStack {
                        Rectangle().fill(Color.gray.opacity(0.2))
                            .frame(height: 50 + geo.safeAreaInsets.bottom)

                        HStack {
                            Button { viewModel.showModal(for: .addCarbs) }
                            label: {
                                Image(systemName: "circlebadge.2.fill")
                            }.foregroundColor(.green)
                            Spacer()
                            Button { viewModel.showModal(for: .addTempTarget) }
                            label: {
                                Image(systemName: "target")
                            }.foregroundColor(.green)
                            Spacer()
                            Button { viewModel.showModal(for: .bolus) }
                            label: {
                                Image(systemName: "drop.fill")
                            }.foregroundColor(.orange)
                            Spacer()
                            if viewModel.allowManualTemp {
                                Button { viewModel.showModal(for: .manualTempBasal) }
                                label: {
                                    Image(systemName: "circle.bottomhalf.fill")
                                }.foregroundColor(.blue)
                                Spacer()
                            }
                            Button { viewModel.showModal(for: .settings) }
                            label: {
                                Image(systemName: "gearshape")
                            }.foregroundColor(.gray)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, geo.safeAreaInsets.bottom)
                    }
                }
                .edgesIgnoringSafeArea(.bottom)
            }
            .navigationTitle("Home")
            .navigationBarHidden(true)
        }
    }
}

private func createPredictionData(
    for type: PredictionType,
    suggestion: Suggestion?
) -> PredictionLineData?
{
    if suggestion == nil {
        return nil
    }

    let predictions: [Int]?
    let lastDate = suggestion?.deliverAt ?? Date()

    switch type {
    case .iob:
        predictions = suggestion?.predictions?.iob
    case .cob:
        predictions = suggestion?.predictions?.cob
    case .uam:
        predictions = suggestion?.predictions?.uam
    case .zt:
        predictions = suggestion?.predictions?.zt
    }

    if let predictions = predictions {
        let glucose = predictions.enumerated().map {
            BloodGlucose(
                sgv: $1,
                dateString: lastDate.addingTimeInterval(Double($0 * 300))
            )
        }
        return PredictionLineData(type: type, values: glucose)
    }
    return nil
}

// TODO: Implement delta, direction, sage and cage
private func createAPSInfo(
    for type: APSDataTypes,
    suggestion: Suggestion?
) -> InformationBarEntryData?
{
    if suggestion == nil {
        return nil
    }

    switch type {
    case .basal:
        guard let rate = suggestion?.rate else {
            return nil
        }
        return InformationBarEntryData(label: "Basal", value: rate, type: type)
    case .cob:
        guard let cob = suggestion?.cob else {
            return nil
        }
        return InformationBarEntryData(label: "COB", value: cob, type: type)
    case .iob:
        guard let iob = suggestion?.iob else {
            return nil
        }
        return InformationBarEntryData(label: "IOB", value: iob, type: type)
    default:
        return nil
    }
}
