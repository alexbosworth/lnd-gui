//
//  FiatConverting.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 7/23/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Protocol for fiat converting

 FIXME: - Make more generic to support different fiat currencies
 */
protocol FiatConverting {
  /** Converter for coins to fiat
   */
  var centsPerCoin: (() -> (Int?))? { get set }
}
