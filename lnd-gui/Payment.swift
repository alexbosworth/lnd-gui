//
//  Payment.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/13/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Payment
 */
enum Payment {
  case chainSend(String, Tokens) // FIXME: - make a chain send struct, address struct
  case paymentRequest(PaymentRequest)
}
