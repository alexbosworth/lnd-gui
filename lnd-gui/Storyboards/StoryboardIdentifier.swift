//
//  StoryboardIdentifier.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/20/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

typealias StoryboardIdentifier = String

enum AppStoryboard: StoryboardIdentifier {
  case blockchainInfo = "BlockchainInfo"
  case invoice = "Invoice"
  case payment = "Payment"

  var asStoryboardIdentifier: StoryboardIdentifier { return rawValue }
  
  var asStoryboard: NSStoryboard { return NSStoryboard(name: asStoryboardIdentifier, bundle: nil) }
}

enum AppViewController: StoryboardIdentifier {
  case blockchainInfo = "BlockchainInfoViewController"
  case invoice = "InvoiceViewController"
  case payment = "PaymentViewController"
  
  var asStoryboardId: StoryboardIdentifier { return rawValue }

  func asViewController(in storyboardType: AppStoryboard) -> NSViewController? {
    return storyboardType.asStoryboard.instantiateController(withIdentifier: asStoryboardId) as? NSViewController
  }
}
