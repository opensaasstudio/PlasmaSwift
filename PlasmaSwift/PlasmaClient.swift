import SwiftGRPC
import SwiftProtobuf

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

    private let service: PlasmaStreamServiceServiceClient
    
    public init(host: String, port: Int, secure: Bool = true) {
        service = .init(address: "\(host):\(port)", secure: secure)
    }

    public init(host: String, port: Int, certificates: String) {
        service = .init(address: "\(host):\(port)", certificates: certificates)
    }
    
    public func connect(retryCount: Int = 10, eventHandler: @escaping (Event) -> Void) -> Connection {
        return .init(service: service, retryCount: retryCount, eventHandler: eventHandler)
    }

    @discardableResult
    public func subscribe(eventTypes: [String], connectionRetryCount: Int = 10, _ eventHandler: @escaping (Event) -> Void) -> Connection {
        return connect(retryCount: connectionRetryCount, eventHandler: eventHandler).subscribe(eventTypes: eventTypes)
    }
}

public extension PlasmaClient {
    public final class Connection {
        private let service: PlasmaStreamServiceServiceClient
        private let eventHandler: (Event) -> Void

        private let reconnectQueue = DispatchQueue(label: "io.github.openfresh.plasma.reconnectQueue")
        private let callLock = NSLock()
        private var events: [PlasmaEventType] = []
        private var call: Call? = nil {
            didSet { oldValue?.cancel() }
        }
        
        fileprivate init(service: PlasmaStreamServiceServiceClient, retryCount: Int, eventHandler: @escaping (Event) -> Void) {
            self.service = service
            self.eventHandler = eventHandler

            service.timeout = .greatestFiniteMagnitude
            connect(retryCount: retryCount)
        }
        
        @discardableResult
        public func subscribe(eventTypes: [String]) -> Self {
            callLock.lock()
            defer { callLock.unlock() }

            let events = eventTypes.map(PlasmaEventType.init)
            call?.subscribe(events: events)
            self.events = events

            PlasmaClient.log("subscribed events sent to plasma: \(eventTypes)")
            return self
        }
        
        public func shutdown() {
            callLock.lock()
            defer { callLock.unlock() }

            call?.cancel()

            PlasmaClient.log("connection closed")
        }
        
        private func connect(retryCount: Int) {
            callLock.lock()
            defer { callLock.unlock() }

            call = Call(service: service, events: events) { [weak self] event in
                switch event {
                case .next(let payload):
                    PlasmaClient.log("received payload: \(payload)")

                case .error(let error as RPCError) where error.callResult?.statusCode == .unavailable && retryCount > 0:
                    PlasmaClient.log("stream service is gone. \(error.localizedDescription)")
                    self?.reconnect(after: 5, remainingCount: retryCount - 1)
                    return

                case .error(let error):
                    PlasmaClient.log("error: \(error.localizedDescription)")
                }

                self?.eventHandler(event)
            }
        }

        private func reconnect(after interval: TimeInterval, remainingCount: Int) {
            reconnectQueue.asyncAfter(deadline: .now() + interval) { [weak self] in
                guard let `self` = self else { return }

                PlasmaClient.log("trying to reconnect... remaining: \(remainingCount) times, eventTypes: \(self.events.map { $0.type })")
                self.connect(retryCount: remainingCount)
            }
        }
    }
}

private extension PlasmaClient.Connection {
    final class Call {
        private let eventHandler: (PlasmaClient.Event) -> Void
        private let protoCall: PlasmaStreamServiceEventsCall

        init?(service: PlasmaStreamServiceServiceClient, events: [PlasmaEventType], eventHandler: @escaping (PlasmaClient.Event) -> Void) {
            do {
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

                    case .result:
                        return

                    case .error(let error):
                        self.eventHandler(.error(error))
                    }

                    self.subscribeReceiveMessage()
                }

            } catch {
                eventHandler(.error(error))
            }
        }

        func subscribe(events: [PlasmaEventType]) {
            guard !events.isEmpty else { return }

            do {
                let request = PlasmaRequest(events: events)
                try protoCall.send(request)

            } catch {
                eventHandler(.error(error))
            }

            subscribeReceiveMessage()
        }

        func cancel() {
            do {
                let request = PlasmaRequest(forceClose: true)
                try protoCall.send(request)
                protoCall.cancel()

            } catch {
                eventHandler(.error(error))
            }
        }
    }
}

private extension PlasmaClient {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .long
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
