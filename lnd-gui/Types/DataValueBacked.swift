//
//  DataValueBacked.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 7/5/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Data value backed structure is a data structure with data that is stored as bytes
 */
protocol DataValueBacked {
  var value: Data { get }
}

extension DataValueBacked {
  /** Hex encoded
   */
  var hexEncoded: String { return value.asHexString }
}
