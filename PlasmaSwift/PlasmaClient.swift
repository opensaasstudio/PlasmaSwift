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
    
    let host: String
    let target: String
    let pemRootCert: String?
    
    public init(host: String, port: Int, pemRootCert: String? = nil) {
        self.host = host
        self.target = "\(host):\(port)"
        self.pemRootCert = pemRootCert
    }
    
    public func subscribe(eventTypes: [String], eventHandler: @escaping (Bool, PLASMAPayload?, Error?) -> Swift.Void) throws {
    
        if let pem = self.pemRootCert {
            try GRPCCall.setTLSPEMRootCerts(pem, forHost: self.host)
        } else {
            GRPCCall.useInsecureConnections(forHost: self.target)
        }
        
        let eventTypeRequests = eventTypes.map {
            let et = PLASMAEventType()
            et.type = $0
        }
        
        let req = PLASMARequest()
        req.eventsArray = NSMutableArray(array: eventTypeRequests)
        
        let client = PLASMAStreamService(host: self.target)
        client.events(with: req, eventHandler: eventHandler)
    }
    
}
