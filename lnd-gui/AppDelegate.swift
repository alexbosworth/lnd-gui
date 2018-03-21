//
//  AppDelegate.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/5/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

// FIXME: - minimal payment value should be dynamic
// FIXME: - register for lightning:// url handler
// FIXME: - when receiving very small amounts under $0.00 use a different way to express it than 0.000
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  // MARK: - @IBActions
  
  /** Show blockchain browser
   */
  @IBAction func showBlockchain(_ sender: AnyObject) {
    do { try presentBlockchainViewController() } catch { report(error) }
  }
  
  /** Show connections view. This interface allows for direct manipulation of Lightning channels and peers.
   */
  @IBAction func showConnections(_ sender: AnyObject) {
    do { try presentConnectionsViewController() } catch { report(error) }
  }
  
  // MARK: - Properties

  /** Daemons view controller. This shows the connectivity to the backing daemons.
   */
  fileprivate var daemonsViewController: DaemonsViewController?

  /** Main view controller. This is the main backing window, it has the balance and price, as well as connection info.
   */
  fileprivate var mainViewController: MainViewController?

  /** Minimal payment amount - used for skipping payment confirmation
   */
  lazy fileprivate var minimalPaymentAmount: Tokens = 200
  
  /** Wallet
   */
  lazy var wallet: Wallet = Wallet()

  /** Controllers for application windows
   */
  lazy fileprivate var windowControllers: [NSWindowController] = []

  /** Initialize the application
   */
  func applicationDidFinishLaunching(_ aNotification: Notification) {
    mainViewController = NSApplication.shared().windows.first?.contentViewController as? MainViewController
    
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleUrl(event:reply:)),
      forEventClass: UInt32(kInternetEventClass),
      andEventID: UInt32(kAEGetURL)
    )
    
    mainViewController?.reportError = { [weak self] error in self?.report(error) }
    mainViewController?.showDaemons = { [weak self] in self?.presentDaemons() }
    mainViewController?.showInvoice = { [weak self] invoice in self?.present(invoice) }
    mainViewController?.showPayment = { [weak self] payment in self?.present(payment) }
    mainViewController?.mainTabViewController?.wallet = wallet
    mainViewController?.wallet = wallet

    do { try refreshExchangeRate() } catch { report(error) }
    
    do { try wallet.initWalletServiceConnection() } catch { report(error) }
    
    wallet.didInsertTransaction = { [weak self] transaction in
      do { try self?.notify(of: transaction) } catch { self?.report(error) }
    }
    
    wallet.didUpdate = { [weak self] in
      guard let wallet = self?.wallet else { return }

      self?.mainViewController?.wallet = wallet
      self?.mainViewController?.walletUpdated()
      self?.updatedConnectivity()
      
      NSApplication.shared().windows.map { $0.contentViewController as? WalletListener }.forEach { $0?.walletUpdated() }
    }
    
    wallet.reportError = { [weak self] error in self?.report(error) }
  }
  
  /** Refresh exchange rate
   */
  func refreshExchangeRate() throws {
    try Daemon.getExchangeRate(currency: .testUnitedStatesDollars) { [weak self] result in
      switch result {
      case .centsPerCoin(let centsPerCoin):
        self?.wallet.centsPerCoin = centsPerCoin
        
      case .error(let error):
        self?.report(error)
      }
    }
  }
  
  func formatted(tokens: Tokens) throws -> String {
    guard let centsPerCoin = wallet.centsPerCoin else { return tokens.formatted }
    
    return try tokens.converted(to: .testUnitedStatesDollars, with: centsPerCoin)
  }
  
  /** Notify of transaction
   
   FIXME: - when there is no description, show a nicer received message
   FIXME: - show units and fiat conversion
   */
  func notify(of transaction: Transaction) throws {
    guard
      let isConfirmed = transaction.isConfirmed,
      let isOutgoing = transaction.isOutgoing,
      let tokens = transaction.sendTokens
      else
    {
      throw Failure.expectedTransactionMetadata
    }
    
    enum TransactionType {
      case incoming
      case outgoing
    }
    
    let type: TransactionType = isOutgoing ? .outgoing : .incoming

    enum ConfirmationStatus {
      case confirmed
      case unconfirmed
    }
    
    let confirmation: ConfirmationStatus = isConfirmed ? .confirmed : .unconfirmed
    
    switch (transaction, type, confirmation) {
    // Received blockchain tokens.
    case (.blockchain(_), .incoming, .confirmed):
      let notification = NSUserNotification()
        
      notification.title = "Received funds"
      notification.informativeText = "Received \(try formatted(tokens: tokens))"
      notification.soundName = NSUserNotificationDefaultSoundName
        
      NSUserNotificationCenter.default.deliver(notification)
    
    // Receiving blockchain tokens.
    case (.blockchain(_), .incoming, .unconfirmed):
      let notification = NSUserNotification()
      
      notification.title = "Incoming transaction"
      notification.informativeText = "Receiving \(try formatted(tokens: tokens))"
      notification.soundName = NSUserNotificationDefaultSoundName
      
      NSUserNotificationCenter.default.deliver(notification)
      
    case (.blockchain(_), .outgoing, .confirmed):
      break
      
    case (.blockchain(_), .outgoing, .unconfirmed):
      break
      
    // Received payment for a channel invoice.
    case (.lightning(let lightningTransaction), .incoming, .confirmed):
      let notification = NSUserNotification()
      
      if let description = lightningTransaction.description {
        notification.title = "Payment for \(description)"
      } else {
        notification.title = "Payment Received"
      }
      
      notification.informativeText = "Received \(try formatted(tokens: lightningTransaction.tokens))"
      notification.soundName = NSUserNotificationDefaultSoundName
      
      NSUserNotificationCenter.default.deliver(notification)
      
    // New unpaid channel invoice
    case (.lightning(_), .incoming, .unconfirmed):
      break

    // Sent a channel payment
    case (.lightning(_), .outgoing, .confirmed):
      break
      
    // Sending a channel payment
    case (.lightning(_), .outgoing, .unconfirmed):
      break
    }
  }

  // MARK: - Core Data stack

  lazy var applicationDocumentsDirectory: Foundation.URL = {
      // The directory the application uses to store the Core Data store file. This code uses a directory named "com.apple.toolsQA.CocoaApp_CD" in the user's Application Support directory.
      let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      let appSupportURL = urls[urls.count - 1]
      return appSupportURL.appendingPathComponent("com.apple.toolsQA.CocoaApp_CD")
  }()

  lazy var managedObjectModel: NSManagedObjectModel = {
      // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
      let modelURL = Bundle.main.url(forResource: "lnd_gui", withExtension: "momd")!
      return NSManagedObjectModel(contentsOf: modelURL)!
  }()

  lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
      // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.) This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
      let fileManager = FileManager.default
      var failError: NSError? = nil
      var shouldFail = false
      var failureReason = "There was an error creating or loading the application's saved data."

      // Make sure the application files directory is there
      do {
          let properties = try self.applicationDocumentsDirectory.resourceValues(forKeys: [URLResourceKey.isDirectoryKey])
          if !properties.isDirectory! {
              failureReason = "Expected a folder to store application data, found a file \(self.applicationDocumentsDirectory.path)."
              shouldFail = true
          }
      } catch  {
          let nserror = error as NSError
          if nserror.code == NSFileReadNoSuchFileError {
              do {
                  try fileManager.createDirectory(atPath: self.applicationDocumentsDirectory.path, withIntermediateDirectories: true, attributes: nil)
              } catch {
                  failError = nserror
              }
          } else {
              failError = nserror
          }
      }
      
      // Create the coordinator and store
      var coordinator: NSPersistentStoreCoordinator? = nil
      if failError == nil {
          coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
          let url = self.applicationDocumentsDirectory.appendingPathComponent("lnd_gui.storedata")
          do {
              try coordinator!.addPersistentStore(ofType: NSXMLStoreType, configurationName: nil, at: url, options: nil)
          } catch {
              // Replace this implementation with code to handle the error appropriately.
               
              /*
               Typical reasons for an error here include:
               * The persistent store is not accessible, due to permissions or data protection when the device is locked.
               * The device is out of space.
               * The store could not be migrated to the current model version.
               Check the error message to determine what the actual problem was.
               */
              failError = error as NSError
          }
      }
      
      if shouldFail || (failError != nil) {
          // Report any error we got.
          if let error = failError {
              NSApplication.shared().presentError(error)
              fatalError("Unresolved error: \(error), \(error.userInfo)")
          }
          fatalError("Unsresolved error: \(failureReason)")
      } else {
          return coordinator!
      }
  }()

  lazy var managedObjectContext: NSManagedObjectContext = {
      // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
      let coordinator = self.persistentStoreCoordinator
      var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
      managedObjectContext.persistentStoreCoordinator = coordinator
      return managedObjectContext
  }()

  // MARK: - Core Data Saving and Undo support

  @IBAction func saveAction(_ sender: AnyObject?) {
      // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
      if !managedObjectContext.commitEditing() {
          NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
      }
      if managedObjectContext.hasChanges {
          do {
              try managedObjectContext.save()
          } catch {
              let nserror = error as NSError
              NSApplication.shared().presentError(nserror)
          }
      }
  }

  func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
      // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
      return managedObjectContext.undoManager
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplicationTerminateReply {
      // Save changes in the application's managed object context before the application terminates.
      
      if !managedObjectContext.commitEditing() {
          NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
          return .terminateCancel
      }
      
      if !managedObjectContext.hasChanges {
          return .terminateNow
      }
      
      do {
          try managedObjectContext.save()
      } catch {
          let nserror = error as NSError
          // Customize this code block to include application-specific recovery steps.
          let result = sender.presentError(nserror)
          if (result) {
              return .terminateCancel
          }
          
          let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
          let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
          let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
          let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
          let alert = NSAlert()
          alert.messageText = question
          alert.informativeText = info
          alert.addButton(withTitle: quitButton)
          alert.addButton(withTitle: cancelButton)
          
          let answer = alert.runModal()
          if answer == NSAlertSecondButtonReturn {
              return .terminateCancel
          }
      }
      // If we got here, it is time to quit.
      return .terminateNow
  }
}

// MARK: - Failures
extension AppDelegate {
  /** Errors at the app delegate level.
   
   These are situatiosn which should not occur, but should not necessarily terminate the application.
   */
  fileprivate enum Failure: Error {
    case expectedTransactionMetadata
    case expectedViewController(AppViewController)
  }
  
  /** Report an error
   */
  fileprivate func report(_ error: Error) {
    print(error)
   
    DispatchQueue.main.async {
      print("ALERT", error, error.localizedDescription)
//      NSAlert(error: error).runModal()
    }
  }
}

// MARK: - Navigation
extension AppDelegate {
  /** Handle a payment request
   */
  func handlePayment(_ serializedInvoice: SerializedInvoice) throws {
    try Daemon.getDecodedInvoice(serializedInvoice) { [weak self] result in
      switch result {
      case .error(let error):
        self?.report(error)
        
      case .invoice(let invoice):
        // Exit early on minimal payment amounts
        if let minimalPaymentAmount = self?.minimalPaymentAmount {
          guard invoice.tokens > minimalPaymentAmount else {
            self?.hide()
            
            do { try self?.makePayment(invoice) } catch { self?.report(error) }
            
            return
          }
        }
        
        do { try self?.presentPaymentConfirmation(serializedInvoice) } catch { self?.report(error) }
      }
    }
  }
  
  /** Handle URL open
   */
  func handleUrl(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
    guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else { return }
    
    let scheme = ((URL(string: urlString)?.scheme ?? String()) as String) + ":"
    
    let serializedInvoice = urlString.substring(from: urlString.index(urlString.startIndex, offsetBy: scheme.utf8.count)).trimmingCharacters(in: NSCharacterSet(charactersIn: "/") as CharacterSet)

    do { try handlePayment(serializedInvoice) } catch { report(error) }
  }

  /** Hide the Application
   */
  func hide() {
    NSApplication.shared().windows.forEach { $0.orderBack(self) }
  }
  
  /** Show daemons
   */
  func presentDaemons() {
    do { try presentDaemonsViewController() } catch { report(error) }
  }
  
  /** Show individual invoice
   */
  func present(_ invoice: LightningInvoice) {
    do { try presentInvoiceViewController(with: invoice) } catch { report(error) }
  }
  
  /** Show individual payment
   */
  func present(_ payment: LightningPayment) {
    do { try presentPaymentViewController(with: payment) } catch { report(error) }
  }

  /** Show a confirmation for a payment request
   */
  func presentPaymentConfirmation(_ invoice: SerializedInvoice) throws {
    try mainViewController?.mainTabViewController?.showPayment(invoice)
  }
  
  fileprivate func presentBlockchainViewController() throws {
    let _ = try presentViewController(.blockchainInfo)
  }
  
  fileprivate func presentConnectionsViewController() throws {
    let _ = try presentViewController(.connections)
  }
  
  fileprivate func presentDaemonsViewController() throws {
    daemonsViewController = try presentViewController(.daemons) as? DaemonsViewController
    
    daemonsViewController?.connectivityStatus = wallet.realtimeConnectionStatus
    
    daemonsViewController?.showConnections = { [weak self] in
      do { try self?.presentConnectionsViewController() } catch { self?.report(error) }
    }

    try Daemon.getConnections { [weak self] result in
      switch result {
      case .connections(let connections):
        self?.daemonsViewController?.connectionsCount = connections.count
        
      case .error(let error):
        self?.report(error)
      }
    }
  }
  
  /** Present an invoice view controller
   */
  fileprivate func presentInvoiceViewController(with invoice: LightningInvoice) throws {
    let invoiceViewController = try presentViewController(.invoice) as? InvoiceViewController
    
    invoiceViewController?.invoice = invoice
    invoiceViewController?.wallet = wallet
  }

  /** Present a payment view controller
   */
  fileprivate func presentPaymentViewController(with payment: LightningPayment) throws {
    let paymentViewController = try presentViewController(.payment) as? PaymentViewController

    paymentViewController?.payment = payment
  }
  
  /** Show the blockchain info view controller
   */
  fileprivate func presentViewController(_ viewController: AppViewController) throws -> NSViewController? {
    let windowController: NSWindowController
    
    if viewController.isUnique, let openWindowController = viewController.first(in: windowControllers) {
      windowController = openWindowController
    } else {
      windowController = try viewController.asViewControllerInWindowController()
      
      windowControllers += [windowController]
    }
    
    windowController.showWindow(self)

    if var errorReportingViewController = windowController.contentViewController as? ErrorReporting {
      errorReportingViewController.reportError = { [weak self] error in self?.report(error) }
    }

    if var fiatConvertingViewController = windowController.contentViewController as? FiatConverting {
      fiatConvertingViewController.centsPerCoin = { [weak self] in self?.wallet.centsPerCoin }
    }
    
    return windowController.contentViewController
  }
}

// MARK: - Payments
extension AppDelegate {
  func makePayment(_ invoice: LightningPayment) throws {
    let amount = try formatted(tokens: invoice.tokens)
    
    try Daemon.makePayment(invoice) { [weak self] response in
      switch response {
      case .error(let error):
        self?.report(error)
        
      case .success:
        let notification = NSUserNotification()
        
        notification.title = "Sent payment"
        notification.informativeText = "Sent \(amount)"
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
      }
    }
  }
}

// MARK: - Updates
extension AppDelegate {
  /** Updated connectivity status
   */
  func updatedConnectivity() {
    daemonsViewController?.connectivityStatus = wallet.realtimeConnectionStatus
  }
}
