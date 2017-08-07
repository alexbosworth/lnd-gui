//
//  ConnectivityStatus.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 8/6/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Network connectivity status
 */
enum ConnectivityStatus {
  case connected, disconnected, initializing
  
  var localizedDescription: String {
    let status: String
    
    switch self {
    case .connected:
      status = "Connected"
      
    case .disconnected:
      status = "Disconnected"
      
    case .initializing:
      status = "Initializing"
    }
    
    return NSLocalizedString(status, comment: "Description of connected status")
  }
  
  var statusImage: NSImage? {
    let imageName: String
    
    switch self {
    case .connected:
      imageName = NSImageNameStatusAvailable
      
    case .disconnected:
      imageName = NSImageNameStatusUnavailable
      
    case .initializing:
      imageName = NSImageNameStatusNone
    }
    
    return NSImage(named: imageName)
  }
}
