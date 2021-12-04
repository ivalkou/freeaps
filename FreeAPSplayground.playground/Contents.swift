import UIKit

extension Array where Element: Hashable {
    func removeDublicates() -> Self {
        var result = Self()
        for item in self {
            if !result.contains(item) {
                result.append(item)
            }
        }
        return result
    }
}

var a = [1, 2, 3, 4, 4, 5, 6, 7, 7]

a.removeDublicates()
