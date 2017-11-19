//
//  Daemon+getDecodedPaymentRequest.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 11/19/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

extension Daemon {
  /** Responses for decoded payment request
   */
  enum DecodedPaymentResponse {
    case error(Error)
    case paymentRequest(LightningPayment)
  }
  
  /** Get decoded payment request
   */
  static func getDecodedPaymentRequest(
    _ encodedPaymentRequestRequest: String,
    completion: @escaping (DecodedPaymentResponse) -> ()) throws
  {
    try get(from: Daemon.Api.paymentRequest(encodedPaymentRequestRequest)) { result in
      switch result {
      case .data(let data):
        do {
          let paymentRequest = try LightningPayment(from: data, paymentRequest: encodedPaymentRequestRequest)
          
          completion(.paymentRequest(paymentRequest))
        } catch {
          completion(.error(error))
        }

      case .error(let error):
        completion(.error(error))
      }
    }
  }
}
