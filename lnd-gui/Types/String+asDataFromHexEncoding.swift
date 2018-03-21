//
//  String+asData.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/29/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Bytes: 8 bit data type
 */
typealias Byte = UInt8

/** Hex string that represents a byte array.
 */
typealias HexEncodedData = String

// MARK: - Data
extension HexEncodedData {
  /** Convert hex serialized string to binary data
   */
  func asDataFromHexEncoding() throws -> Data {
    let scalars = self.unicodeScalars
    var bytes = Array<Byte>(repeating: 0, count: (scalars.count + 1) >> 1)

    try scalars.enumerated().forEach { index, scalar in
      var nibble = try hexNibble(for: scalar)

      if index & 1 == 0 {
        nibble <<= 4
      }

      bytes[index >> 1] |= nibble
    }

    return Data(bytes: bytes)
  }

  /** Failures
   */
  enum Failure: Error {
    case invalidHexNibble(UnicodeScalar)
  }
  
  /** Get byte for hex nibble
   */
  private func hexNibble(for scalar: UnicodeScalar) throws -> Byte {
    switch scalar.value {
    case 48...57:
      return Byte(scalar.value - 48)
    case 65...70:
      return Byte(scalar.value - 55)
    case 97...102:
      return Byte(scalar.value - 87)
    default:
      throw Failure.invalidHexNibble(scalar)
    }
  }
}
