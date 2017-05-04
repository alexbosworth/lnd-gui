//
//  JsonInitialized.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/2/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Json Initialized protocol
 */
protocol JsonInitialized {}

/** Parse JSON failure
 */
enum ParseJsonFailure: Error {
  case expectedDictionary
  case nilData
}

extension JsonInitialized {
  /** Get a JSON dictionary from data
   */
  static func jsonDictionaryFromData(_ data: Data?) throws -> [String: Any] {
    guard let data = data else { throw ParseJsonFailure.nilData }
    
    let dataDownloadedAsJson = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
    
    guard let json = dataDownloadedAsJson as? [String: Any] else { throw ParseJsonFailure.expectedDictionary }
    
    return json
  }
}
