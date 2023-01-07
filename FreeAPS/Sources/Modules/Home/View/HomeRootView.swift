import SpriteKit
import SwiftDate
import SwiftUI
import Swinject

extension Home {
    struct RootView: BaseView {
        let resolver: Resolver

        @StateObject var state = StateModel()
        @State var isStatusPopupPresented = false

        private var numberFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        private var targetFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        private var dateFormatter: DateFormatter {
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            return dateFormatter
        }

        private var spriteScene: SKScene {
            let scene = SnowScene()
            scene.scaleMode = .resizeFill
            scene.backgroundColor = .clear
            return scene
        }

        @ViewBuilder func header(_ geo: GeometryProxy) -> some View {
            HStack(alignment: .bottom) {
                Spacer()
                cobIobView
                Spacer()
                glucoseView
                Spacer()
                pumpView
                Spacer()
                loopView
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 70)
            .padding(.top, geo.safeAreaInsets.top)
            .background(Color.gray.opacity(0.2))
        }

        var cobIobView: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("IOB").font(.caption2).foregroundColor(.secondary)
                    Text(
                        (numberFormatter.string(from: (state.suggestion?.iob ?? 0) as NSNumber) ?? "0") +
                            NSLocalizedString(" U", comment: "Insulin unit")
                    )
                    .font(.system(size: 12, weight: .bold))
                }
                HStack {
                    Text("COB").font(.caption2).foregroundColor(.secondary)
                    Text(
                        (numberFormatter.string(from: (state.suggestion?.cob ?? 0) as NSNumber) ?? "0") +
                            NSLocalizedString(" g", comment: "gram of carbs")
                    )
                    .font(.system(size: 12, weight: .bold))
                }
            }
        }

        var glucoseView: some View {
            CurrentGlucoseView(
                recentGlucose: $state.recentGlucose,
                delta: $state.glucoseDelta,
                units: $state.units,
                alarm: $state.alarm
            )
            .onTapGesture {
                if state.alarm == nil {
                    state.openCGM()
                } else {
                    state.showModal(for: .snooze)
                }
            }
            .onLongPressGesture {
                let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                impactHeavy.impactOccurred()
                if state.alarm == nil {
                    state.showModal(for: .snooze)
                } else {
                    state.openCGM()
                }
            }
        }

        var pumpView: some View {
            PumpView(
                reservoir: $state.reservoir,
                battery: $state.battery,
                name: $state.pumpName,
                expiresAtDate: $state.pumpExpiresAtDate,
                timerDate: $state.timerDate
            )
            .onTapGesture {
                if state.pumpDisplayState != nil {
                    state.setupPump = true
                }
            }
        }

        var loopView: some View {
            LoopView(
                suggestion: $state.suggestion,
                enactedSuggestion: $state.enactedSuggestion,
                closedLoop: $state.closedLoop,
                timerDate: $state.timerDate,
                isLooping: $state.isLooping,
                lastLoopDate: $state.lastLoopDate,
                manualTempBasal: $state.manualTempBasal
            ).onTapGesture {
                isStatusPopupPresented = true
            }.onLongPressGesture {
                let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                impactHeavy.impactOccurred()
                state.runLoop()
            }
        }

        var infoPanal: some View {
            HStack(alignment: .center) {
                if state.pumpSuspended {
                    Text("Pump suspended")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.loopGray)
                        .padding(.leading, 8)
                } else if let tempRate = state.tempRate {
                    if state.apsManager.isManualTempBasal {
                        Text(
                            (numberFormatter.string(from: tempRate as NSNumber) ?? "0") +
                                NSLocalizedString(" U/hr", comment: "Unit per hour with space") +
                                NSLocalizedString(" -  Manual Basal ⚠️", comment: "Manual Temp basal")
                        )
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.insulin)
                        .padding(.leading, 8)
                    } else {
                        Text(
                            (numberFormatter.string(from: tempRate as NSNumber) ?? "0") +
                                NSLocalizedString(" U/hr", comment: "Unit per hour with space")
                        )
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.insulin)
                        .padding(.leading, 8)
                    }
                }

                if let tempTarget = state.tempTarget {
                    Text(tempTarget.displayName).font(.caption).foregroundColor(.secondary)
                    if state.units == .mmolL {
                        Text(
                            targetFormatter
                                .string(from: (tempTarget.targetBottom?.asMmolL ?? 0) as NSNumber)!
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        if tempTarget.targetBottom != tempTarget.targetTop {
                            Text("-").font(.caption)
                                .foregroundColor(.secondary)
                            Text(
                                targetFormatter
                                    .string(from: (tempTarget.targetTop?.asMmolL ?? 0) as NSNumber)! +
                                    " \(state.units.rawValue)"
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        } else {
                            Text(state.units.rawValue).font(.caption)
                                .foregroundColor(.secondary)
                        }

                    } else {
                        Text(targetFormatter.string(from: (tempTarget.targetBottom ?? 0) as NSNumber)!)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if tempTarget.targetBottom != tempTarget.targetTop {
                            Text("-").font(.caption)
                                .foregroundColor(.secondary)
                            Text(
                                targetFormatter
                                    .string(from: (tempTarget.targetTop ?? 0) as NSNumber)! + " \(state.units.rawValue)"
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        } else {
                            Text(state.units.rawValue).font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                if let progress = state.bolusProgress {
                    Text("Bolusing")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.insulin)
                    ProgressView(value: Double(progress))
                        .progressViewStyle(BolusProgressViewStyle())
                        .padding(.trailing, 8)
                        .onTapGesture {
                            state.cancelBolus()
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 30)
        }

        var legendPanal: some View {
            HStack(alignment: .center) {
                Group {
                    Circle().fill(Color.loopGreen).frame(width: 8, height: 8)
                    Text("BG")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.loopGreen)
                }
                Group {
                    Circle().fill(Color.insulin).frame(width: 8, height: 8)
                        .padding(.leading, 8)
                    Text("IOB")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.insulin)
                }
                Group {
                    Circle().fill(Color.zt).frame(width: 8, height: 8)
                        .padding(.leading, 8)
                    Text("ZT")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.zt)
                }
                Group {
                    Circle().fill(Color.loopYellow).frame(width: 8, height: 8)
                        .padding(.leading, 8)
                    Text("COB")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.loopYellow)
                }
                Group {
                    Circle().fill(Color.uam).frame(width: 8, height: 8)
                        .padding(.leading, 8)
                    Text("UAM")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.uam)
                }

                if let eventualBG = state.eventualBG {
                    Text(
                        "⇢ " + numberFormatter.string(
                            from: (state.units == .mmolL ? eventualBG.asMmolL : Decimal(eventualBG)) as NSNumber
                        )!
                    )
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 30)
        }

        var mainChart: some View {
            ZStack {
                if state.animatedBackground {
                    SpriteView(scene: spriteScene, options: [.allowsTransparency])
                        .ignoresSafeArea()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                }

                MainChartView(
                    glucose: $state.glucose,
                    suggestion: $state.suggestion,
                    tempBasals: $state.tempBasals,
                    boluses: $state.boluses,
                    suspensions: $state.suspensions,
                    hours: .constant(state.filteredHours),
                    maxBasal: $state.maxBasal,
                    autotunedBasalProfile: $state.autotunedBasalProfile,
                    basalProfile: $state.basalProfile,
                    tempTargets: $state.tempTargets,
                    carbs: $state.carbs,
                    timerDate: $state.timerDate,
                    units: $state.units
                )
            }
            .padding(.bottom)
            .modal(for: .dataTable, from: self)
        }

        @ViewBuilder private func bottomPanel(_ geo: GeometryProxy) -> some View {
            ZStack {
                Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 50 + geo.safeAreaInsets.bottom)

                HStack {
                    Button { state.showModal(for: .addCarbs) }
                    label: {
                        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                            Image("carbs")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.loopGreen)
                                .padding(8)
                            if let carbsReq = state.carbsRequired {
                                Text(numberFormatter.string(from: carbsReq as NSNumber)!)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Capsule().fill(Color.red))
                            }
                        }
                    }
                    Spacer()
                    Button { state.showModal(for: .addTempTarget) }
                    label: {
                        Image("target")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .padding(8)
                    }.foregroundColor(.loopYellow)
                    Spacer()
                    Button { state.showModal(for: .bolus(waitForSuggestion: false)) }
                    label: {
                        Image("bolus")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .padding(8)
                    }.foregroundColor(.insulin)
                    Spacer()
                    if state.allowManualTemp {
                        Button { state.showModal(for: .manualTempBasal) }
                        label: {
                            Image("bolus1")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding(8)
                        }.foregroundColor(.insulin)
                        Spacer()
                    }
                    Button { state.showModal(for: .settings) }
                    label: {
                        Image("settings1")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .padding(8)
                    }.foregroundColor(.loopGray)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, geo.safeAreaInsets.bottom)
            }
        }

        var body: some View {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    header(geo)
                    infoPanal
                    mainChart
                    legendPanal
                    bottomPanel(geo)
                }
                .edgesIgnoringSafeArea(.vertical)
            }
            .onAppear(perform: configureView)
            .navigationTitle("Home")
            .navigationBarHidden(true)
            .ignoresSafeArea(.keyboard)
            .popup(isPresented: isStatusPopupPresented, alignment: .top, direction: .top) {
                popup
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(UIColor.darkGray))
                    )
                    .onTapGesture {
                        isStatusPopupPresented = false
                    }
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.height < 0 {
                                    isStatusPopupPresented = false
                                }
                            }
                    )
            }
        }

        private var popup: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.statusTitle).font(.headline).foregroundColor(.white)
                    .padding(.bottom, 4)
                if let suggestion = state.suggestion {
                    TagCloudView(tags: suggestion.reasonParts).animation(.none, value: false)
                    Text(suggestion.reasonConclusion.capitalizingFirstLetter()).font(.body).foregroundColor(.white)
                } else {
                    Text("No sugestion found").font(.body).foregroundColor(.white)
                }

                if let errorMessage = state.errorMessage, let date = state.errorDate {
                    Text("Error at \(dateFormatter.string(from: date))")
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding(.bottom, 4)
                        .padding(.top, 8)
                    Text(errorMessage).font(.caption).foregroundColor(.loopRed)
                }
            }
        }
    }
}
