import Foundation
import GRPCClient
import SwiftGRPC
import SwiftProtobuf

public final class PlasmaClient {
    public typealias EventHandler = (ResultOrRPCError<Proto_Payload?>) -> Void
    
    public static var isDebugLogEnabled = false
    
    private let host: String
    private let port: Int
    private lazy var service: Proto_StreamServiceServiceClient = .init(address: "\(host):\(port)")
    
    public static func useInsecureConnections(forHost host: String) {
        GRPCCall.useInsecureConnections(forHost: host)
    }
    
    public static func setTLSPEMRootCerts(pemRootCert: String, forHost host: String) throws {
        try GRPCCall.setTLSPEMRootCerts(pemRootCert, forHost: host)
    }
    
    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
    
    public func connect(_ eventHandler: @escaping EventHandler) -> Connection {
        return .init(service: service, eventHandler: eventHandler)
    }
}

public extension PlasmaClient {
    public final class Connection {
        private final class Call {
            private let protoCall: Proto_StreamServiceEventsCall
            
            init(service: Proto_StreamServiceServiceClient, events: [Proto_EventType], eventHandler: @escaping EventHandler) {
                protoCall = try! service.events(completion: nil)
                subscribe(events: events, eventHandler: eventHandler)
            }
            
            func subscribe(events: [Proto_EventType], eventHandler: @escaping EventHandler) {
                guard !events.isEmpty else { return }
                do {
                    try protoCall.send(Proto_Request(events: events))
                    try protoCall.receive(completion: eventHandler)
                } catch let error {
                    PlasmaClient.log("error = \(error.localizedDescription)")
                }
            }
            
            func cancel() {
                try! protoCall.send(Proto_Request(forceClose: true))
                protoCall.cancel()
            }
        }
        private let reconnectQueue: DispatchQueue = .init(label: "io.github.openfresh.plasma.reconnectQueue")
        private let service: Proto_StreamServiceServiceClient
        private let eventHandler: EventHandler
        private let call: Atomic<Call?> = .init(nil) { oldValue in
            oldValue?.cancel()
        }
        private var events: [Proto_EventType] = []
        
        fileprivate init(service: Proto_StreamServiceServiceClient, eventHandler: @escaping EventHandler) {
            self.service = service
            self.eventHandler = eventHandler
            connect(retry: 10)
        }
        
        @discardableResult
        public func subscribe(types: [String]) -> Self {
            let events = types.map(Proto_EventType.init(type:))
            let handler = eventHandler
            call.withValue { call in
                call?.subscribe(events: events, eventHandler: handler)
                self.events = events
            }
            PlasmaClient.log("sent subscribed events \(types) to plasma")
            
            return self
        }
        
        public func shutdown() {
            call.withValue { call in call?.cancel() }
            PlasmaClient.log("closed connection")
        }
        
        private func connect(retry: Int) {
            call.modify { call in
                call = Call(service: service, events: events) { [weak self] result in
                    switch result {
                    case .result(let payload?):
                        PlasmaClient.log("received payload = \(payload)")
                        
                    case .result:
                        break
                        
                    case .error(let error) where error.callResult?.statusCode == .unavailable && retry > 0:
                        PlasmaClient.log("stream service is gone. \(error.localizedDescription)")
                        self?.reconnectQueue.asyncAfter(deadline: .now() + 5) {
                            PlasmaClient.log("trying to reconnect... eventTypes=\(String(describing: self?.events.map { $0.type }))")
                            self?.connect(retry: retry - 1)
                        }
                        return
                        
                    case .error(let error):
                        PlasmaClient.log("error = \(error.localizedDescription)")
                    }
                    
                    self?.eventHandler(result)
                }
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
        let fullLog = "\(dateString) [PLASMA] \(data())"
        
        print(fullLog)
    }
}

private extension Proto_Request {
    init(forceClose: Bool) {
        self.init()
        self.forceClose = forceClose
    }
    
    init(events: [Proto_EventType]) {
        self.init()
        self.events = events
    }
}

private extension Proto_EventType {
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

