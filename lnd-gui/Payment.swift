//
//  Payment.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/13/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

struct ChainSend {
  let address: String
  let tokens: Tokens
}

/** Payments represent outward transfers, either via a LN payment request or a blockchain settlement.
 */
enum Payment {
  case chainSend(ChainSend)
  case paymentRequest(PaymentRequest)
}
