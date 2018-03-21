//
//  Payment.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 11/19/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Payments represent outward transfers, either via a LN payment request or a blockchain settlement.
 */
enum Payment {
  case chainSend(ChainSend)
  case invoice(LightningPayment)
}
