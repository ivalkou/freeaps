import Combine
import SwiftUI
import Swinject

extension Migration {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        var body: some View {
            VStack {
                Circle()
                    .trim(from: 0.1, to: 0.9)
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [.red, .yellow]), center: .center),
                        style: StrokeStyle(lineWidth: 15, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(state.animated ? 360 : 0))
                    .animation(.linear(duration: 0.7).repeatForever(autoreverses: false))
                Text("Preparing data \n Please wait")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
            .onAppear {
                configureView()
                state.animated.toggle()
                state.runMigration()
            }
            .preference(key: PreferenceKeyAppLoading.self, value: state.loadingIsEnded)
        }
    }
}
