import SwiftUI

struct PredictionsChartView: View {
    let minValue: Int
    let maxValue: Int
    let maxWidth: CGFloat
    var data: [PredictionLineData]
    let showHours: Int

    var chartsData: some View {
        ForEach(0 ..< data.count, id: \.self) { index -> AnyView in
            let binded = Binding(
                get: { data[index].values }
            ) { _ in }
            return HStack {
                PointChartView(
                    minValue: minValue,
                    maxValue: maxValue,
                    maxWidth: maxWidth,
                    showHours: showHours,
                    glucoseData: binded
                ) { value in
                    PredictionPointView(
                        predictionType: data[index].type,
                        value: value
                    )
                }
                Spacer()
            }.asAny()
        }
    }

    var body: some View {
        ZStack {
            chartsData
        }
    }
}
