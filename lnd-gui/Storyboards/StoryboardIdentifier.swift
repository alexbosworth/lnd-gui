//
//  StoryboardIdentifier.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/20/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** A storyboard identifier is an identifier used to uniquely identify components within a storyboard
 */
typealias StoryboardIdentifier = String

/** Application storyboards, typically mapped to specific windows within the application.
 */
enum AppStoryboard: StoryboardIdentifier {
  case blockchainInfo = "BlockchainInfo"
  case connections = "Connections"
  case daemons = "Daemons"
  case invoice = "Invoice"
  case payment = "Payment"

  /** Storyboard's standard unique identifier.
   */
  var asStoryboardIdentifier: StoryboardIdentifier { return rawValue }
  
  /** Storyboard as a Storyboard object
   */
  var asStoryboard: NSStoryboard { return NSStoryboard(name: asStoryboardIdentifier, bundle: nil) }
}

/** Application view controllers
 */
enum AppViewController: StoryboardIdentifier {
  case blockchainInfo = "BlockchainInfoViewController"
  case connections = "ConnectionsViewController"
  case daemons = "DaemonsViewController"
  case invoice = "InvoiceViewController"
  case main = "MainViewController"
  case payment = "PaymentViewController"
  
  var asStoryboardId: StoryboardIdentifier { return rawValue }

  func asViewController(in storyboardType: AppStoryboard) -> NSViewController? {
    return storyboardType.asStoryboard.instantiateController(withIdentifier: asStoryboardId) as? NSViewController
  }
  
  enum Failure: Error {
    case expectedUniqueMainWindow
    case expectedViewController
  }

  func first(in windowControllers: [NSWindowController]) -> NSWindowController? {
    switch self {
    case .blockchainInfo:
      return windowControllers.first { $0.contentViewController is BlockchainInfoViewController }

    case .connections:
      return windowControllers.first { $0.contentViewController is ConnectionsViewController }
      
    case .daemons:
      return windowControllers.first { $0.contentViewController is DaemonsViewController }
      
    case .invoice:
      return windowControllers.first { $0.contentViewController is InvoiceViewController }
      
    case .main:
      return windowControllers.first { $0.contentViewController is MainViewController }

    case .payment:
      return windowControllers.first { $0.contentViewController is PaymentViewController }
    }
  }
  
  func asViewControllerInWindowController() throws -> NSWindowController {
    let viewController: NSViewController
    let windowTitle: String
    let windowTitleLocalizationComment: String
    
    switch self {
    case .blockchainInfo:
      guard let blockchainInfoVc = asViewController(in: .blockchainInfo) as? BlockchainInfoViewController else {
        throw Failure.expectedViewController
      }
    
      viewController = blockchainInfoVc
      windowTitle = "Blockchain Info"
      windowTitleLocalizationComment = "Title for blockchain information query window"
      
    case .connections:
      guard let connectionsViewController = asViewController(in: .connections) as? ConnectionsViewController else {
        throw Failure.expectedViewController
      }
      
      viewController = connectionsViewController
      windowTitle = "Connections"
      windowTitleLocalizationComment = "Title for connections window"
      
    case .daemons:
      guard let daemonsViewController = asViewController(in: .daemons) as? DaemonsViewController else {
        throw Failure.expectedViewController
      }
      
      viewController = daemonsViewController
      windowTitle = "Daemons"
      windowTitleLocalizationComment = "Title for daemons window"
      
    case .invoice:
      guard let invoiceViewController = asViewController(in: .invoice) as? InvoiceViewController else {
        throw Failure.expectedViewController
      }
      
      viewController = invoiceViewController
      windowTitle = "Invoice"
      windowTitleLocalizationComment = "Title for incoming requested payment window"
      
    case .main:
      throw Failure.expectedUniqueMainWindow
      
    case .payment:
      guard let paymentViewController = asViewController(in: .payment) as? PaymentViewController else {
        throw Failure.expectedViewController
      }
      
      viewController = paymentViewController
      windowTitle = "Payment"
      windowTitleLocalizationComment = "Title for outgoing payment window"
    }
    
    let window = NSWindow(contentViewController: viewController)
    
    window.title = NSLocalizedString(windowTitle, comment: windowTitleLocalizationComment)
    
    window.makeKeyAndOrderFront(self)
    
    return NSWindowController(window: window)
  }
  
  /** View controller is unique
   */
  var isUnique: Bool {
    switch self {
    case .blockchainInfo, .connections, .daemons, .main:
      return true
      
    case .invoice, .payment:
      return false
    }
  }
}
