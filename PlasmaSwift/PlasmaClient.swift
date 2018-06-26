import SwiftGRPC
import SwiftProtobuf

public final class PlasmaClient {
    public enum Result {
        case success(payload: PlasmaPayload)
        case failure(error: Error)
    }
    
    public static var isDebugLogEnabled = false

    private let service: PlasmaStreamServiceServiceClient
    
    public init(host: String, port: Int, secure: Bool = true) {
        self.service = .init(address: "\(host):\(port)", secure: secure)
    }

    public init(host: String, port: Int, certificates: String) {
        service = .init(address: "\(host):\(port)", certificates: certificates)
        service.timeout = .greatestFiniteMagnitude
    }
    
    public func connect(_ eventHandler: @escaping (Result) -> Void) -> Connection {
        return .init(service: service, eventHandler: eventHandler)
    }
}

public extension PlasmaClient {
    public final class Connection {
        private let service: PlasmaStreamServiceServiceClient
        private let eventHandler: (Result) -> Void

        private let reconnectQueue = DispatchQueue(label: "io.github.openfresh.plasma.reconnectQueue")
        private let call = Atomic<Call?>(nil) { oldValue in
            oldValue?.cancel()
        }
        private var events: [PlasmaEventType] = []
        
        fileprivate init(service: PlasmaStreamServiceServiceClient, eventHandler: @escaping (Result) -> Void) {
            self.service = service
            self.eventHandler = eventHandler

            connect(retry: 10)
        }
        
        @discardableResult
        public func subscribe(types: [String]) -> Self {
            let events = types.map(PlasmaEventType.init)

            call.withValue { call in
                call?.subscribe(events: events)
                self.events = events
            }

            PlasmaClient.log("sent subscribed events \(types) to plasma")
            return self
        }
        
        public func shutdown() {
            call.withValue { $0?.cancel() }
            PlasmaClient.log("closed connection")
        }
        
        private func connect(retry: Int) {
            call.modify { call in
                call = Call(service: service, events: events) { [weak self] result in
                    switch result {
                    case .success(let payload):
                        PlasmaClient.log("received payload = \(payload)")
                        
                    case .failure(let error as RPCError) where error.callResult?.statusCode == .unavailable && retry > 0:
                        PlasmaClient.log("stream service is gone. \(error.localizedDescription)")
                        self?.reconnect(after: 5, retry: retry - 1)
                        return
                        
                    case .failure(let error):
                        PlasmaClient.log("error = \(error.localizedDescription)")
                    }
                    
                    self?.eventHandler(result)
                }
            }
        }

        private func reconnect(after interval: TimeInterval, retry: Int) {
            reconnectQueue.asyncAfter(deadline: .now() + interval) { [weak self] in
                guard let `self` = self else { return }

                PlasmaClient.log("trying to reconnect... eventTypes = \(self.events.map { $0.type })")
                self.connect(retry: retry)
            }
        }
    }
}

private extension PlasmaClient.Connection {
    final class Call {
        private let protoCall: PlasmaStreamServiceEventsCall
        private let eventHandler: (PlasmaClient.Result) -> Void

        init(service: PlasmaStreamServiceServiceClient, events: [PlasmaEventType], eventHandler: @escaping (PlasmaClient.Result) -> Void) {
            self.protoCall = try! service.events(completion: nil)
            self.eventHandler = eventHandler

            subscribe(events: events)
        }

        func subscribeReceiveMessage() {
            do {
                try protoCall.receive { [weak self] result in
                    switch result {
                    case .result(let payload?):
                        self?.eventHandler(.success(payload: payload))

                    case .result(.none):
                        return

                    case .error(let error):
                        self?.eventHandler(.failure(error: error))
                    }

                    self?.subscribeReceiveMessage()
                }

            } catch let error {
                eventHandler(.failure(error: error))
            }
        }

        func subscribe(events: [PlasmaEventType]) {
            guard !events.isEmpty else { return }

            do {
                let request = PlasmaRequest(events: events)
                try protoCall.send(request)

            } catch let error {
                eventHandler(.failure(error: error))
            }

            subscribeReceiveMessage()
        }

        func cancel() {
            do {
                let request = PlasmaRequest(forceClose: true)
                try protoCall.send(request)
                protoCall.cancel()

            } catch let error {
                eventHandler(.failure(error: error))
            }
        }
    }
}

private extension PlasmaClient {
    static let dateFormatter: DateFormatter = {
        var formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    static func log<T>(_ data: @autoclosure () -> T) {
        guard isDebugLogEnabled else { return }
        
        let dateString = dateFormatter.string(from: Date())
        let fullLog = "\(dateString) [Plasma] \(data())"
        
        print(fullLog)
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

private final class Atomic<Value> {
    private var _value: Value {
        didSet {
            didSet?(oldValue)
        }
    }
    private let didSet: ((Value) -> Void)?
    private let lock: NSLock = .init()
    
    init(_ value: Value, didSet: ((Value) -> Void)? = nil) {
        _value = value
        self.didSet = didSet
    }
    
    var value: Value {
        get {
            return withValue { $0 }
        }
        set {
            swap(newValue)
        }
    }
    
    @discardableResult
    func modify<Result>(_ action: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try action(&_value)
    }
    
    @discardableResult
    func withValue<Result>(_ action: (Value) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        
        return try action(_value)
    }
    
    @discardableResult
    func swap(_ newValue: Value) -> Value {
        return modify { value in
            let oldValue = value
            value = newValue
            return oldValue
        }
    }
}
