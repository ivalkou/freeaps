import Combine
import ConnectIQ
import Foundation
import Swinject

protocol GarminManager {
    func selectDevices() -> AnyPublisher<[IQDevice], Never>
    var devices: [IQDevice] { get }
    func sendState(_ data: Data)
    var stateRequet: (() -> (Data))? { get set }
}

extension Notification.Name {
    static let openFromGarminConnect = Notification.Name("Notification.Name.openFromGarminConnect")
}

final class BaseGarminManager: NSObject, GarminManager, Injectable {
    private let connectIQ = ConnectIQ.sharedInstance()

    @Injected() private var notificationCenter: NotificationCenter!

    @Persisted(key: "BaseGarminManager.persistedDevices") private var persistedDevices: [CodableDevice] = []

    private var watchfaces: [IQApp] = []

    var stateRequet: (() -> (Data))?

    private(set) var devices: [IQDevice] = [] {
        didSet {
            persistedDevices = devices.map(CodableDevice.init)
            watchfaces = []
            devices.forEach { device in
                connectIQ?.register(forDeviceEvents: device, delegate: self)
                let watchfaceApp = IQApp(
                    uuid: UUID(uuidString: "EC3420F6-027D-49B3-B45F-D81D6D3ED90A"),
                    store: UUID(),
                    device: device
                )
                watchfaces.append(watchfaceApp!)
                connectIQ?.register(forAppMessages: watchfaceApp, delegate: self)
            }
        }
    }

    private var lifetime = Lifetime()
    private var selectPromise: Future<[IQDevice], Never>.Promise?

    init(resolver: Resolver) {
        super.init()
        connectIQ?.initialize(withUrlScheme: "freeaps-x", uiOverrideDelegate: self)
        injectServices(resolver)
        restoreDevices()
        subsctibeToOpenFromGarminConnect()
        setupApplications()
    }

    private func subsctibeToOpenFromGarminConnect() {
        notificationCenter
            .publisher(for: .openFromGarminConnect)
            .sink { notification in
                guard let url = notification.object as? URL else { return }
                self.parseDevicesFor(url: url)
            }
            .store(in: &lifetime)
    }

    private func restoreDevices() {
        devices = persistedDevices.map(\.iqDevice)
    }

    private func parseDevicesFor(url: URL) {
        devices = connectIQ?.parseDeviceSelectionResponse(from: url) as? [IQDevice] ?? []
        selectPromise?(.success(devices))
        selectPromise = nil
    }

    private func setupApplications() {
        devices.forEach { _ in
        }
    }

    func selectDevices() -> AnyPublisher<[IQDevice], Never> {
        Future { promise in
            self.selectPromise = promise
            self.connectIQ?.showDeviceSelection()
        }
        .timeout(120, scheduler: DispatchQueue.main)
        .replaceEmpty(with: [])
        .eraseToAnyPublisher()
    }

    func sendState(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
            return
        }
        watchfaces.forEach { app in
            print("ASDF: sending message")
            connectIQ?.getAppStatus(app) { status in
                guard status?.isInstalled ?? false else {
                    print("ASDF: app not installed")
                    return
                }
                self.connectIQ?.sendMessage(object, to: app, progress: { sent, all in
                    print("ASDF: sending progress: \(sent / all * 100) %")
                }, completion: { result in
                    if result == .success {
                        print("ASDF: message sent OK")
                    } else {
                        print("ASDF: message Failed")
                    }
                })
            }
        }
    }
}

extension BaseGarminManager: IQUIOverrideDelegate {
    func needsToInstallConnectMobile() {}
}

extension BaseGarminManager: IQDeviceEventDelegate {
    func deviceStatusChanged(_ device: IQDevice, status: IQDeviceStatus) {
        print("ASDF: \(device.uuid!)")
        switch status {
        case .invalidDevice:
            print("ASDF: invalidDevice")
        case .bluetoothNotReady:
            print("ASDF: bluetoothNotReady")
        case .notFound:
            print("ASDF: notFound")
        case .notConnected:
            print("ASDF: notConnected")
        case .connected:
            print("ASDF: connected")
        @unknown default:
            print("ASDF: unknown")
        }
    }
}

extension BaseGarminManager: IQAppMessageDelegate {
    func receivedMessage(_ message: Any, from app: IQApp) {
        print("ASDF: got message: \(message) from app: \(app.uuid!)")
        if let status = message as? String, status == "status", let watchState = stateRequet?() {
            sendState(watchState)
        }
    }
}

struct CodableDevice: Codable, Equatable {
    let id: UUID
    let modelName: String
    let friendlyName: String

    init(iqDevice: IQDevice) {
        id = iqDevice.uuid
        modelName = iqDevice.modelName
        friendlyName = iqDevice.modelName
    }

    var iqDevice: IQDevice {
        IQDevice(id: id, modelName: modelName, friendlyName: friendlyName)
    }
}
