//
//  Wallet.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/3/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Wallet represents the set of chain and channel transactions.
 */
class Wallet {
  // MARK: - Properties
  
  /** Token balances
   */
  var balances: WalletBalances? { didSet { didUpdate?() } }
  
  /** Cents per coin
    FIXME: - replace with an abstract Forex Rates structure
   */
  var centsPerCoin: Int? { didSet { didUpdate?() } } 
  
  /** Did insert a transaction
   */
  var didInsertTransaction: ((Transaction) -> ())?
  
  /** Did update wallet data
   */
  var didUpdate: (() -> ())?
  
  /** Realtime update connectivity status
   */
  var realtimeConnectionStatus: ConnectivityStatus = .initializing { didSet { didUpdate?() } }
  
  /** Address of realtime host
   
   FIXME: - move this to configuration setup
   */
  let realtimeHost = "localhost:10554"
  
  /** Report async error
   */
  var reportError: (Error) -> () = { _ in }
  
  /** Password for realtime host
   
   FIXME: - move this to configuration setup
   */
  var servicePasword = "pass"
  
  /** Confirmed transactions
   */
  var transactions: Set<Transaction> = Set() { didSet { didUpdate?() } }
  
  /** Realtime web socket connection
   */
  fileprivate var webSocket: WebSocket?
}

// MARK: - ErrorReporting
extension Wallet: ErrorReporting {
  /** Failures
   */
  enum WalletFailure: Error {
    case disconnected
    case missingAuth
    case missingHost
    case uncleanWebsocketDisconnect(Int, String)
    case unexpectedMessageFormat
  }
}

// MARK: - Pull Sync
extension Wallet {
  /** Update wallet token balance information
   */
  func updateBalances() throws {
    try Daemon.getBalances { [weak self] result in
      switch result {
      case .balances(let balances):
        self?.balances = balances
        
      case .error(let error):
        self?.reportError(error)
      }
    }
  }
  
  /** Update wallet transaction history
   */
  func updateTransactions() throws {
    try Daemon.getHistory { [weak self] result in
      switch result {
      case .error(let error):
        self?.reportError(error)
        
      case .transactions(let transactions):        
        self?.transactions = transactions
      }
    }
  }
}

// MARK: - Realtime Sync
extension Wallet {
  enum WalletCommand {
    case sendChannelPayment(SerializedPaymentRequest)
    
    /** Get the wallet command as a JSON dictionary
     */
    private var asJson: JsonDictionary {
      switch self {
      case .sendChannelPayment(let payment):
        return ["payment_request": payment]
      }
    }
    
    /** Get the wallet command as a binary formatted JSON dictionary
     */
    func asData() throws -> Data {
      return try JSONSerialization.data(withJSONObject: asJson, options: .prettyPrinted)
    }
  }
  
  /** Send wallet command over realtime connection
   */
  func sendWalletCommand(_ command: WalletCommand) throws {
    guard let webSocket = webSocket else { throw WalletFailure.disconnected }
    
    webSocket.send(data: try command.asData())
  }
  
  /** Did receive a push message from the web socket connection
   
   FIXME: - join all update requests together and use socket connection
   */
  func receivedPushMessage(message: Any) throws {
    guard let message = message as? String else { throw WalletFailure.unexpectedMessageFormat }
    
    try receivedWalletServiceMessage(message)
    
    try updateBalances()

    try updateTransactions()
  }
  
  /** Initialize the wallet service connection

   // FIXME: - short circuit daemon POST calls to use this socket when available
   // FIXME: - get wallet data on websocket connection
   */
  func initWalletServiceConnection() throws {
    webSocket = WebSocket("ws://\(realtimeHost)?secret_key=\(servicePasword)")
    
    webSocket?.event.close = { [weak self] code, reason, clean in
      self?.realtimeConnectionStatus = .disconnected
      
      self?.webSocket?.open()
      
      guard clean else {
        self?.reportError(WalletFailure.uncleanWebsocketDisconnect(code, reason))
        
        return
      }
    }
    
    webSocket?.event.error = { [weak self] error in
      self?.reportError(error)
    }
    
    webSocket?.event.message = { [weak self] message in
      do { try self?.receivedPushMessage(message: message) } catch { self?.reportError(error) }
    }
    
    webSocket?.event.open = { [weak self] in
      self?.realtimeConnectionStatus = .connected
      
      do { try self?.updateTransactions() } catch { self?.reportError(error) }

      do { try self?.updateBalances() } catch { self?.reportError(error) }
    }
  }
  
  /** Update the set of transactions with a new transaction
   */
  func updateTransactions(with transaction: Transaction) {
    if !transactions.contains(transaction) { didInsertTransaction?(transaction) }
    
    transactions.update(with: transaction)
  }
  
  /** Received socket message
   */
  func receivedWalletServiceMessage(_ message: String) throws {
    let walletObject = try WalletObject(from: message.data(using: .utf8, allowLossyConversion: false))
    
    switch walletObject {
    case .transaction(let transaction):
      updateTransactions(with: transaction)
    }
  }
}

/** Wallet protocol triggers on wallet updates
 */
protocol WalletListener {
  func walletUpdated()
}

// MARK: - invoice
extension Wallet {
  /** Determine if a payment is present
   */
  func invoice(_ invoice: LightningInvoice) -> LightningInvoice? {
    guard let tx = (transactions.first { $0.id == invoice.id }) else { return nil }
    
    switch tx {
    case .blockchain(_):
      return nil
      
    case .lightning(let lightningTransaction):
      switch lightningTransaction {
      case .invoice(let invoice):
        return invoice
        
      case .payment(_):
        return nil
      }
    }
  }
}
