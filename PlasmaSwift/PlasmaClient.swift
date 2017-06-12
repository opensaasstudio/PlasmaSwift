//
//  PlasmaClient.swift
//  Pods
//
//  Created by @stormcat24 on 2017/05/09.
//  Copyright (c) 2017 io.github.openfresh.plasma. All rights reserved.
//

import Foundation
import GRPCClient

public final class PlasmaClient {
    public typealias Event = (Bool, PLASMAPayload?, Error?)
    public typealias EventHandler = (Event) -> Void
    
    public static var isDebugLogEnabled = false
    
    private let host: String
    private let port: Int
    private lazy var service: PLASMAStreamService = .init(host: "\(self.host):\(self.port)")
    
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
    
    public func connect(eventHandler: @escaping EventHandler) -> Connection {
        return .init(service: service, eventHandler: eventHandler)
    }
}

public extension PlasmaClient {
    public final class Connection {
        private final class Call {
            private let requestBuffer: GRXBufferedPipe = .init()
            private let protoCall: GRPCProtoCall
            
            init(service: PLASMAStreamService, events: [PLASMAEventType], eventHandler: @escaping EventHandler) {
                protoCall = service.rpcToEvents(withRequestsWriter: requestBuffer, eventHandler: eventHandler)
                protoCall.start()
                
                subscribe(events: events)
            }
            
            func subscribe(events: [PLASMAEventType]) {
                guard !events.isEmpty else { return }
                requestBuffer.writeValue(PLASMARequest(events: events))
            }
            
            func cancel() {
                requestBuffer.writeValue(PLASMARequest(forceClose: true))
                protoCall.cancel()
            }
        }
        private let reconnectQueue: DispatchQueue = .init(label: "io.github.openfresh.plasma.reconnectQueue")
        private let service: PLASMAStreamService
        private let eventHandler: EventHandler
        private let call: Atomic<Call?> = .init(nil) { oldValue in
            oldValue?.cancel()
        }
        private var events: [PLASMAEventType] = []
        
        fileprivate init(service: PLASMAStreamService, eventHandler: @escaping EventHandler) {
            self.service = service
            self.eventHandler = eventHandler
            connect(retry: 10)
        }
        
        public func subscribe(types: [String]) -> Self {
            let events = types.map(PLASMAEventType.init(type:))
            call.withValue { call in
                call?.subscribe(events: events)
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
                call = Call(service: service, events: events) { [weak self] result, payload, error in
                    if let error = error as NSError?,
                        error.domain == "io.grpc" && error.code == Int(GRPCErrorCode.unavailable.rawValue) && retry > 0 {
                        PlasmaClient.log("stream service is gone. \(error.localizedDescription)")
                        
                        self?.reconnectQueue.asyncAfter(deadline: .now() + 5) {
                            PlasmaClient.log("trying to reconnect... eventTypes=\(String(describing: self?.events.map { $0.type }))")
                            self?.connect(retry: retry - 1)
                        }
                        return
                    }
                    if let error = error as NSError? {
                        PlasmaClient.log("error = \(error.localizedDescription)")
                    }
                    
                    if let payload = payload {
                        PlasmaClient.log("received payload = \(payload)")
                    }
                    
                    self?.eventHandler(result, payload, error)
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

private extension PLASMARequest {
    convenience init(forceClose: Bool) {
        self.init()
        self.forceClose = forceClose
    }
    
    convenience init(events: [PLASMAEventType]) {
        self.init()
        self.eventsArray = NSMutableArray(array: events)
    }
}

private extension PLASMAEventType {
    convenience init(type: String) {
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
