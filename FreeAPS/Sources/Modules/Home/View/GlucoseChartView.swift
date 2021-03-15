import Charts
import SwiftDate
import SwiftUI

extension DateFormatter: AxisValueFormatter {
    public func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
        timeStyle = .short
        return string(from: Date(timeIntervalSince1970: value))
    }
}

struct GlucoseChartView: UIViewRepresentable {
    @Binding var glucose: [BloodGlucose]
    @Binding var suggestion: Suggestion?

    func makeUIView(context _: Context) -> LineChartView {
        let view = LineChartView()
        makeDataPointsFor(view: view)
        view.xAxis.valueFormatter = DateFormatter()
        return view
    }

    func updateUIView(_ view: LineChartView, context _: Context) {
        makeDataPointsFor(view: view)
    }

    private func makeDataPointsFor(view: LineChartView) {

        var series = []

        let lastDate = suggestion?.deliverAt ?? Date()

        if let iob = suggestion?.predictions?.iob {
            let dataPoints = iob.enumerated().map {
                ChartDataEntry(
                    x: lastDate.addingTimeInterval(Double($0 * 300)).timeIntervalSince1970,
                    y: Double($1)
                )
            }
            let data = MyLineChartDataSet(entries: dataPoints, label: "IOB")
            data.drawCirclesEnabled = true
            data.circleRadius = 2
            data.setCircleColor(.blue)
            data.setColor(.blue)
            data.lineWidth = 0
            data.drawValuesEnabled = false
            series.append(data)
        }

        if let zt = suggestion?.predictions?.zt {
            let dataPoints = zt.enumerated().map {
                ChartDataEntry(
                    x: lastDate.addingTimeInterval(Double($0 * 300)).timeIntervalSince1970,
                    y: Double($1)
                )
            }
            let data = MyLineChartDataSet(entries: dataPoints, label: "ZT")
            data.drawCirclesEnabled = true
            data.circleRadius = 2
            data.setCircleColor(.cyan)
            data.setColor(.cyan)
            data.lineWidth = 0
            data.drawValuesEnabled = false
            series.append(data)
        }

        if let cob = suggestion?.predictions?.cob {
            let dataPoints = cob.enumerated().map {
                ChartDataEntry(
                    x: lastDate.addingTimeInterval(Double($0 * 300)).timeIntervalSince1970,
                    y: Double($1)
                )
            }
            let data = MyLineChartDataSet(entries: dataPoints, label: "COB")
            data.drawCirclesEnabled = true
            data.circleRadius = 2
            data.setCircleColor(.orange)
            data.setColor(.orange)
            data.lineWidth = 0
            data.drawValuesEnabled = false
            series.append(data)
        }

        if let uam = suggestion?.predictions?.uam {
            let dataPoints = uam.enumerated().map {
                ChartDataEntry(
                    x: lastDate.addingTimeInterval(Double($0 * 300)).timeIntervalSince1970,
                    y: Double($1)
                )
            }
            let data = MyLineChartDataSet(entries: dataPoints, label: "UAM")
            data.drawCirclesEnabled = true
            data.circleRadius = 2
            data.setCircleColor(.yellow)
            data.setColor(.yellow)
            data.lineWidth = 0
            data.drawValuesEnabled = false
            series.append(data)
        }

        view.data = LineChartData(dataSets: series)
    }
}

