//
//  FiatConverting.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 7/23/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Protocol for fiat converting
 */
protocol FiatConverting {
  /** Converter for coins to fiat
   */
  var centsPerCoin: (() -> (Int?))? { get set }
}
