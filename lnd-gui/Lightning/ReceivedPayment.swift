//
//  ReceivedPayment.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/2/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Received payment is an invoiced payment.
 
 FIXME: - eliminate and use Transaction instead
 */
struct ReceivedPayment {
  let createdAt: Date
  let description: String
  let isConfirmed: Bool
  let invoice: SerializedInvoice
  let tokens: Tokens
}
