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
    let requestBuffer: GRXBufferedPipe
    let client: PLASMAStreamService
    
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
    
    public func connect(responseHandler: @escaping (Bool, PLASMAPayload?, Error?) -> Swift.Void) {
        client.rpcToEvents(withRequestsWriter: requestBuffer, eventHandler: responseHandler).start()
    }
    
    public func subscribe(eventTypes: [String]) {
    
        let eventTypeRequests = eventTypes.map { (type: String) -> PLASMAEventType in
            let et = PLASMAEventType()
            et.type = type
            return et
        }
        
        let req = PLASMARequest()
        req.eventsArray = NSMutableArray(array: eventTypeRequests)
        
        requestBuffer.writeValue(req)
    }
    
    public func shutdown() {
        let closeReq = PLASMARequest()
        closeReq.forceClose = true
        requestBuffer.writeValue(closeReq)
    }
    
}
