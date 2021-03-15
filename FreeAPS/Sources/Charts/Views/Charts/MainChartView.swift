import SwiftUI

struct MainChartView: View {
    let showHours: Int
    @Binding var glucoseData: [BloodGlucose]
    @Binding var predictionsData: [PredictionLineData]

    var body: some View {
        let allValues = getAllValues()
        let minValue = allValues.min() ?? 40
        let maxValue = allValues.max() ?? 400
        GeometryReader { geo in
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack {
                        MeshView()
                        CombinedChartView(
                            maxWidth: geo.size.width,
                            showHours: showHours,
                            glucoseData: $glucoseData,
                            predictionsData: $predictionsData
                        )
                    }
                }
                NumberIndicatorsView(minValue: minValue, maxValue: maxValue)
            }
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

extension MainChartView {
    func getAllValues() -> [Int] {
        let glucoseValues = glucoseData.compactMap(\.sgv)
        guard let predictionValues = getPredictionValues() else {
            return glucoseValues
        }
        return glucoseValues + predictionValues
    }

    func getPredictionValues() -> [Int]? {
        guard !predictionsData.isEmpty else {
            return nil
        }
        return predictionsData.flatMap { prediction in
            prediction.values.compactMap(\.sgv)
        }
    }
}
