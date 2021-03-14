import SwiftUI

struct MeshEntryPointView: View {
    let orientation: MeshEntryOrientations
    var body: some View {
        Capsule()
            .foregroundColor(Color(.systemGray3))
            .capsuleOrientation(orentation: orientation)
    }
}

private struct CapsuleOrientation: ViewModifier {
    let orientation: MeshEntryOrientations

    func body(content: Content) -> some View {
        switch orientation {
        case .vertical:
            return content.frame(width: 1, height: 5)
        case .horizontal:
            return content.frame(width: 5, height: 0.5)
        }
    }
}

private extension View {
    func capsuleOrientation(orentation: MeshEntryOrientations) -> some View {
        modifier(CapsuleOrientation(orientation: orentation))
    }
}

struct MeshEntryPoint_Previews: PreviewProvider {
    static var previews: some View {
        MeshEntryPointView(orientation: .horizontal)
            .preferredColorScheme(.light)
    }
}
