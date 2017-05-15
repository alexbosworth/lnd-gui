//
//  Daemon.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/6/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

struct Daemon {}

extension Daemon {
  enum SendJsonResult {
    case error(Error)
    case success
  }
  
  enum Api: String {
    case payments
    case peers
    case transactions
    
    var url: URL? {
      return URL(string: "http://localhost:10553/v0/\(rawValue)/")
    }

    var urlRequest: URLRequest? {
      guard let url = url else { return nil }
      
      let timeoutInterval: TimeInterval = 30
      
      return URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeoutInterval)
    }
  }
  
  enum SendJsonFailure: Error {
    case expectedValidUrl
  }
  
  enum HttpMethod: String {
    case post = "POST"
    
    var asString: String { return rawValue }
  }
  
  static func send(json: [String: Any], to: Api, completion: @escaping (SendJsonResult) -> ()) throws {
    let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)

    guard var urlRequest = to.urlRequest else { throw SendJsonFailure.expectedValidUrl }

    urlRequest.httpMethod = HttpMethod.post.asString
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let task = URLSession.shared.uploadTask(with: urlRequest, from: data) { data, urlResponse, error in
      DispatchQueue.main.async {
        if let error = error { return completion(.error(error)) }
        
        return completion(.success)
      }
    }
    
    task.resume()
  }
}

extension Daemon {
  enum AddPeerResult {
    case error(Error)
    case success
  }

  enum AddPeerJsonAttribute: String {
    case host
    case publicKey = "public_key"
    
    var key: String { return rawValue }
  }
  
  static func addPeer(ip: IpAddress, publicKey: PublicKey, completion: @escaping (AddPeerResult) -> ()) throws {
    let json = [AddPeerJsonAttribute.host.key: ip.serialized, AddPeerJsonAttribute.publicKey.key: publicKey.hexEncoded]

    try send(json: json, to: .peers) { result in
      switch result {
      case .error(let error):
        completion(.error(error))
        
      case .success:
        completion(.success)
      }
    }
  }
}
