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

typealias JsonDictionary = [String: Any]

// MARK: - Initialization
extension JsonInitialized {
  /** Get a JSON dictionary from data
   */
  static func jsonDictionaryFromData(_ data: Data?) throws -> JsonDictionary {
    guard let data = data else { throw ParseJsonFailure.nilData }
    
    let dataDownloadedAsJson = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
    
    guard let json = dataDownloadedAsJson as? JsonDictionary else { throw ParseJsonFailure.expectedDictionary }
    
    return json
  }
}
