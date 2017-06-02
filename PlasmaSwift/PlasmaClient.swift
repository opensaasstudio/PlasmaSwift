//
//  PlasmaClient.swift
//  Pods
//
//  Created by @stormcat24 on 2017/05/09.
//
//

import Foundation
import GRPCClient

public class PlasmaClient {
    
    let target: String
    let client: PLASMAStreamService
    let reconnectInterval = 5
    
    private var requestBuffer: GRXBufferedPipe
    private var lastEventTypes: [String] = []
    private var dead = false
    
    public init(host: String, port: Int, pemRootCert: String? = nil) throws {
        self.target = "\(host):\(port)"
        
        if let pem = pemRootCert {
            try GRPCCall.setTLSPEMRootCerts(pem, forHost: host)
        } else {
            GRPCCall.useInsecureConnections(forHost: self.target)
        }

        self.client = PLASMAStreamService(host: self.target)
        self.requestBuffer = GRXBufferedPipe()
    }
    
    public func connect(_ responseHandler: @escaping (Bool, PLASMAPayload?, Error?) -> Swift.Void) {
        
        let handler: (Bool, PLASMAPayload?, Error?) -> Void = { result, payload, error in
            
            if let err = error {
                let nserror: NSError = err as NSError
                if (nserror.domain == "io.grpc" && nserror.code == GRPCErrorCode.unavailable.hashValue) {
                    self.writeLog("\(self.target) is gone. \(err.localizedDescription)")
                    
                    // reconnect and resubscribe
                    self.dead = true
                    DispatchQueue.global().async {
                        while self.dead {
                            self.writeLog("trying to reconnect and resubscribe... eventTypes=\(self.lastEventTypes)")
                            Thread.sleep(forTimeInterval: TimeInterval(self.reconnectInterval))
                            self.reconnect(responseHandler)
                        }
                    }
                    
                } else {
                    self.writeLog("error = \(err.localizedDescription)")
                    responseHandler(result, payload, error)
                }
            } else {
                if let p = payload {
                    self.writeLog("received payload = \(p)")
                }
                responseHandler(result, payload, error)
            }
        }
        
        client.rpcToEvents(withRequestsWriter: requestBuffer, eventHandler: handler).start()
        self.dead = false
    }
    
    public func subscribe(_ eventTypes: [String]) {
    
        let eventTypeRequests = eventTypes.map { (type: String) -> PLASMAEventType in
            let et = PLASMAEventType()
            et.type = type
            return et
        }
        
        let req = PLASMARequest()
        req.eventsArray = NSMutableArray(array: eventTypeRequests)
        
        requestBuffer.writeValue(req)
        lastEventTypes = eventTypes
        writeLog("sent subscribed events \(eventTypes) to plasma")
    }
    
    public func shutdown() {
        let closeReq = PLASMARequest()
        closeReq.forceClose = true
        requestBuffer.writeValue(closeReq)
        writeLog("closed connection")
    }
    
    private func reconnect(_ responseHandler: @escaping (Bool, PLASMAPayload?, Error?) -> Swift.Void) {
        self.requestBuffer = GRXBufferedPipe()
        self.connect(responseHandler)
        self.subscribe(self.lastEventTypes)
    }
    
    private func writeLog(_ log: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS "
        let ts = formatter.string(from: Date())
        print("\(ts)[PLASMA] \(log)")
    }
    
}
