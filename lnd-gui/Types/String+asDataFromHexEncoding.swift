//
//  String+asData.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/29/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Hex string that represents a byte array.
 */
typealias HexEncodedData = String

// MARK: - Data
extension HexEncodedData {
  /** Convert hex String to Data
   */
  func asDataFromHexEncoding() throws -> Data {
    var data = Data()
    var hex = self
    let hexCharactersPerByte = 2

    while(hex.characters.count > String().characters.count) {
      let c = hex.substring(to: hex.index(hex.startIndex, offsetBy: hexCharactersPerByte))

      hex = hex.substring(from: hex.index(hex.startIndex, offsetBy: hexCharactersPerByte))

      var ch = UInt32()

      Scanner(string: c).scanHexInt32(&ch)

      var char = UInt8(ch)

      data.append(&char, count: 1)
    }

    return data
  }
}
