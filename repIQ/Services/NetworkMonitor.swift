import Foundation
import Network

/// Monitors network connectivity using NWPathMonitor.
/// Provides a reactive `isConnected` property and notifies when connectivity changes.
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected: Bool = true
    private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.repiq.network-monitor", qos: .utility)

    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown
    }

    /// Callbacks registered by services that want to be notified on reconnect.
    private var onReconnectHandlers: [() async -> Void] = []

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let wasConnected = self?.isConnected ?? true
            let nowConnected = path.status == .satisfied

            Task { @MainActor in
                self?.isConnected = nowConnected
                self?.connectionType = self?.resolveConnectionType(path) ?? .unknown

                // Fire reconnect handlers when going from disconnected → connected
                if !wasConnected && nowConnected {
                    let handlers = self?.onReconnectHandlers ?? []
                    for handler in handlers {
                        await handler()
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    /// Register a handler to be called when network connectivity is restored.
    func onReconnect(_ handler: @escaping () async -> Void) {
        onReconnectHandlers.append(handler)
    }

    private func resolveConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wired }
        return .unknown
    }
}
