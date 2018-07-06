import SwiftGRPC
import SwiftProtobuf
import SystemConfiguration

public final class PlasmaClient {
    public struct Payload {
        public let data: String
        public let eventType: String
    }

    public enum Event {
        case next(payload: Payload)
        case error(Error)
    }

    public static var isDebugLogEnabled = false

    private let makeService: () -> PlasmaStreamServiceServiceClient

    public convenience init(host: String, port: Int, secure: Bool = true, timeout: TimeInterval = .greatestFiniteMagnitude) {
        self.init {
            let service = PlasmaStreamServiceServiceClient(address: "\(host):\(port)", secure: secure)
            service.timeout = timeout
            return service
        }
    }

    public convenience init(host: String, port: Int, certificates: String, timeout: TimeInterval = .greatestFiniteMagnitude) {
        self.init {
            let service = PlasmaStreamServiceServiceClient(address: "\(host):\(port)", certificates: certificates)
            service.timeout = timeout
            return service
        }
    }

    private init(makeService: @escaping () -> PlasmaStreamServiceServiceClient) {
        self.makeService = makeService
    }

    public func connect(retryCount: Int, eventHandler: @escaping (Event) -> Void) -> Connection {
        return .init(retryCount: retryCount, makeService: makeService, eventHandler: eventHandler)
    }

    @discardableResult
    public func subscribe(eventTypes: [String], retryCount: Int, _ eventHandler: @escaping (Event) -> Void) -> Connection {
        return connect(retryCount: retryCount, eventHandler: eventHandler).subscribe(eventTypes: eventTypes)
    }
}

public extension PlasmaClient {
    public final class Connection {
        private var makeService: () -> PlasmaStreamServiceServiceClient
        private let eventHandler: (Event) -> Void
        private let reconnectQueue = DispatchQueue(label: "io.github.openfresh.plasma.reconnectQueue")
        private let lock = NSLock()
        private var retryCount: Int
        private var events = [PlasmaEventType]()
        private lazy var networkReachability = NetworkReachability(queue: reconnectQueue)

        private var call: Call? = nil {
            didSet { oldValue?.cancel() }
        }

        fileprivate init(retryCount: Int, makeService: @escaping () -> PlasmaStreamServiceServiceClient, eventHandler: @escaping (Event) -> Void) {
            self.retryCount = retryCount
            self.makeService = makeService
            self.eventHandler = eventHandler

            connect()
            networkReachability?.changed = { [weak self] networkReachability in
                guard let `self` = self else { return }

                if networkReachability.isReachable {
                    PlasmaClient.log("network reachability changed. trying to reconnect...")
                    self.connect()

                } else {
                    self.shutdown()
                }
            }
        }

        @discardableResult
        public func subscribe(eventTypes: [String]) -> Self {
            lock.lock()
            defer { lock.unlock() }

            let events = eventTypes.map(PlasmaEventType.init)
            call?.subscribe(events: events)
            self.events = events

            PlasmaClient.log("subscribed events sent to plasma: \(eventTypes)")
            return self
        }

        public func shutdown() {
            lock.lock()
            defer { lock.unlock() }

            call = nil

            PlasmaClient.log("connection closed")
        }

        private func connect() {
            lock.lock()
            defer { lock.unlock() }

            let service = makeService()
            call = Call(service: service, events: events) { [weak self] event in
                guard let `self` = self else { return }

                let isMaybeReachable = self.networkReachability?.isReachable ?? false

                switch event {
                case .next(let payload):
                    PlasmaClient.log("received payload: \(payload)")
                    self.eventHandler(event)

                case .error(let error) where !isMaybeReachable:
                    PlasmaClient.log("stream is not reachable. error: \(error.localizedDescription)")

                case .error(let error):
                    PlasmaClient.log("received error: \(error.localizedDescription).")
                    let reconnectResult = self.reconnect(after: 5)

                    if !reconnectResult {
                        self.eventHandler(event)
                    }
                }
            }
        }

        private func reconnect(after interval: TimeInterval) -> Bool {
            lock.lock()
            defer { lock.unlock() }

            let events = self.events
            let remaining = retryCount - 1
            self.retryCount = remaining

            guard remaining >= 0 else { return false }

            reconnectQueue.asyncAfter(deadline: .now() + interval) { [weak self] in
                guard let `self` = self else { return }

                PlasmaClient.log("trying to reconnect... remaining: \(remaining) times, eventTypes: \(events.map { $0.type })")
                self.connect()
            }

            return true
        }
    }
}

private extension PlasmaClient.Connection {
    final class Call {
        private let service: PlasmaStreamServiceServiceClient
        private let eventHandler: (PlasmaClient.Event) -> Void
        private let protoCall: PlasmaStreamServiceEventsCall

        init?(service: PlasmaStreamServiceServiceClient, events: [PlasmaEventType], eventHandler: @escaping (PlasmaClient.Event) -> Void) {
            do {
                self.service = service
                self.eventHandler = eventHandler
                self.protoCall = try service.events { callResult in
                    if callResult.statusCode == .unavailable {
                        eventHandler(.error(RPCError.callError(callResult)))
                    }
                }

                subscribe(events: events)

            } catch {
                eventHandler(.error(error))
                return nil
            }
        }

        func subscribeReceiveMessage() {
            do {
                try protoCall.receive { [weak self] result in
                    guard let `self` = self else { return }

                    switch result {
                    case .result(let payload?) where payload.hasEventType:
                        let payload = PlasmaClient.Payload(data: payload.data, eventType: payload.eventType.type)
                        self.eventHandler(.next(payload: payload))
                        self.subscribeReceiveMessage()

                    case .result:
                        break

                    case .error(let error):
                        self.eventHandler(.error(error))
                    }
                }

            } catch {
                eventHandler(.error(error))
            }
        }

        func subscribe(events: [PlasmaEventType]) {
            guard !events.isEmpty else { return }

            do {
                let request = PlasmaRequest(events: events)
                try protoCall.send(request) { [weak self] error in
                    guard let `self` = self, let error = error else { return }

                    self.eventHandler(.error(error))
                }

            } catch {
                eventHandler(.error(error))
            }

            subscribeReceiveMessage()
        }

        func cancel() {
            do {
                let request = PlasmaRequest(forceClose: true)
                try protoCall.send(request) { [weak self] error in
                    guard let `self` = self, let error = error else { return }

                    self.eventHandler(.error(error))
                }

                protoCall.cancel()

            } catch {
                eventHandler(.error(error))
            }
        }
    }
}

private final class NetworkReachability {
    var changed: ((NetworkReachability) -> Void)?

    var isReachable: Bool {
        return currentFlags.contains(.reachable)
    }

    private let reachability: SCNetworkReachability
    private var currentFlags: SCNetworkReachabilityFlags

    init?(queue: DispatchQueue) {
        var address = sockaddr()
        address.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        address.sa_family = sa_family_t(AF_INET)

        guard let reachability = SCNetworkReachabilityCreateWithAddress(nil, &address) else {
            return nil
        }

        var _flags = SCNetworkReachabilityFlags()
        let getFlagsResult = SCNetworkReachabilityGetFlags(reachability, &_flags)

        self.reachability = reachability
        self.currentFlags = getFlagsResult ? _flags : .init()

        var context = SCNetworkReachabilityContext(
            version: 0,
            info: .init(Unmanaged<NetworkReachability>.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let setCallbackResult = SCNetworkReachabilitySetCallback(reachability, reachabilityCallback, &context)
        let setDispatchQueueResult = SCNetworkReachabilitySetDispatchQueue(reachability, queue)

        guard setCallbackResult && setDispatchQueueResult else {
            return nil
        }
    }

    func reachabilityChanged(with flags: SCNetworkReachabilityFlags) {
        guard currentFlags != flags else { return }

        currentFlags = flags
        changed?(self)
    }

    deinit {
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
    }
}

private func reachabilityCallback(reachability: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) {
    guard let info = info else { return }

    let networkReachability = Unmanaged<NetworkReachability>.fromOpaque(info).takeUnretainedValue()
    networkReachability.reachabilityChanged(with: flags)
}

private extension PlasmaClient {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZ"
        return formatter
    }()

    static func log<T>(_ data: @autoclosure () -> T) {
        guard isDebugLogEnabled else { return }

        let now = Date()
        let dateString = dateFormatter.string(from: now)
        let log = "\(dateString) [Plasma] \(data())"

        print(log)
    }
}

private extension PlasmaRequest {
    init(forceClose: Bool) {
        self.init()
        self.forceClose = forceClose
    }

    init(events: [PlasmaEventType]) {
        self.init()
        self.events = events
    }
}

private extension PlasmaEventType {
    init(type: String) {
        self.init()
        self.type = type
    }
}
