import SwiftUI

struct NumberIndicatorsView: View {
    let minValue: Int
    let maxValue: Int

    var body: some View {
        VStack {
            ForEach(values, id: \.self) { value in
                getIndicator(for: value)
            }
        }
    }
}

extension NumberIndicatorsView {
    func getIndicator(for value: Int) -> some View {
        VStack {
            Spacer()
            Text(String(value)).font(.footnote).padding(.trailing, 2)
            Spacer()
        }
    }

    var values: [Int] {
        let step = (maxValue - minValue) / 4
        return (1 ..< 5).map { (step + step * $0) / 18 }.reversed()
    }
}
