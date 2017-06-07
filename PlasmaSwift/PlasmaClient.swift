//
//  PlasmaClient.swift
//  Pods
//
//  Created by @stormcat24 on 2017/05/09.
//
//

import Foundation
import GRPCClient

public final class PlasmaClient {
    public typealias Event = (Bool, PLASMAPayload?, Error?)
    public typealias EventHandler = (Event) -> Void
    
    private let host: String
    private lazy var service: PLASMAStreamService = .init(host: self.host)
    
    public static func useInsecureConnections(forHost host: String) {
        GRPCCall.useInsecureConnections(forHost: host)
    }
    
    public static func setTLSPEMRootCerts(pemRootCert: String, forHost host: String) throws {
        try GRPCCall.setTLSPEMRootCerts(pemRootCert, forHost: host)
    }
    
    public init(host: String, port: Int) {
        self.host = "\(host):\(port)"
    }
    
    public func connect(eventHandler: @escaping EventHandler) -> Connection {
        return .init(service: service, eventHandler: eventHandler)
    }
}

public extension PlasmaClient {
    public final class Connection {
        final class Call {
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
        private let retry: Int = 10
        private let reconnectQueue: DispatchQueue = .init(label: "tv.freshlive.plasma.reconnectQueue")
        private let service: PLASMAStreamService
        private let eventHandler: EventHandler
        private var call: Call? {
            didSet {
                oldValue?.cancel()
            }
        }
        private var events: [PLASMAEventType] = []
        
        fileprivate init(service: PLASMAStreamService, eventHandler: @escaping EventHandler) {
            self.service = service
            self.eventHandler = eventHandler
            connect(retry: retry)
        }
        
        func subscribe(types: [String]) -> Self {
            let events = types.map(PLASMAEventType.init(type:))
            call?.subscribe(events: events)
            self.events = events
            
            return self
        }
        
        func shutdown() {
            call?.cancel()
        }
        
        private func connect(retry: Int) {
            call = Call(service: service, events: events) { [weak self] result, payload, error in
                if let error = error as NSError?,
                    error.domain == "io.grpc" && error.code == Int(GRPCErrorCode.unavailable.rawValue) && retry > 0 {
                    self?.reconnectQueue.asyncAfter(deadline: .now() + 5) {
                        self?.connect(retry: retry - 1)
                    }
                    return
                }
                self?.eventHandler(result, payload, error)
            }
        }
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
