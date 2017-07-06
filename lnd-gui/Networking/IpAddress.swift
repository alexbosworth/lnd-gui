//
//  IpAddress.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/6/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** IP Address
 
  FIXME: - represent value with in4in6_addr
 */
enum IpAddress {
  case v4(String)
  case v6(String)
  
  /** Create from serialized ip address
   */
  init(from ip: String) throws {
    var sin6 = sockaddr_in6()
    
    if (ip.withCString() { inet_pton(AF_INET6, $0, &sin6.sin6_addr) }) == 1 {
      self = .v6(ip)

      return
    }
    
    var sin = sockaddr_in()

    if (ip.withCString() { inet_pton(AF_INET, $0, &sin.sin_addr) }) == 1 {
      self = .v4(ip)

      return
    }
    
    throw Failure.unknownFormat(ip)
  }
  
  enum Failure: Error {
    case unknownFormat(String)
  }
  
  var serialized: String {
    switch self {
    case .v4(let value), .v6(let value):
      return value
    }
  }
}

