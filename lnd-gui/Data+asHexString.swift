//
//  Data+asHexString.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/29/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

extension Data {
  /** Data hex encoded.
   */
  var asHexString: HexEncodedData { return map { String(format: "%02hhx", $0) }.joined() }
}
