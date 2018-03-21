//
//  Daemon+getDecodedInvoice.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 11/19/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

extension Daemon {
  /** Responses for decoded payment request
   */
  enum DecodedInvoiceResponse {
    case error(Error)
    case invoice(LightningPayment)
  }
  
  /** Get decoded payment request
   */
  static func getDecodedInvoice(
    _ encodedInvoiceRequest: String,
    completion: @escaping (DecodedInvoiceResponse) -> ()) throws
  {
    try get(from: Daemon.Api.invoices(encodedInvoiceRequest)) { result in
      switch result {
      case .data(let data):
        do {
          let invoice = try LightningPayment(from: data, invoice: encodedInvoiceRequest)
          
          completion(.invoice(invoice))
        } catch {
          completion(.error(error))
        }

      case .error(let error):
        completion(.error(error))
      }
    }
  }
}
