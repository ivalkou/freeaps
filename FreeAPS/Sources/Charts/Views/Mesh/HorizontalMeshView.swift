import SwiftUI

struct MeshView: View {
    var line: some View {
        VStack {
            Spacer()
            Capsule()
                .frame(maxWidth: .infinity, maxHeight: 0.5)
                .foregroundColor(Color(.systemGray4))
            Spacer()
        }
    }

    var body: some View {
        VStack {
            ForEach(0 ..< 4, id: \.self) { _ in
                line
            }
        }
    }
}

struct MeshView_Previews: PreviewProvider {
    static var previews: some View {
        MeshView()
    }
}
