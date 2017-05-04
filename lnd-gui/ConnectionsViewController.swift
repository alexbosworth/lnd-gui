//
//  ConnectionsViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/4/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** ConnectionsViewController is a view controller for creating invoices.
 */
class ConnectionsViewController: NSViewController {
  // MARK: - @IBOutlets
  
  /** Connections table view
   */
  @IBOutlet weak var connectionsTableView: NSTableView?

  // MARK: - NSViewController

  /** View will appear
   */
  override func viewWillAppear() {
    super.viewWillAppear()
    
    refreshConnections()
  }
  
  /** View loaded
   */
  override func viewDidLoad() {
    super.viewDidLoad()

    initMenu()
  }
  
  // MARK: - Properties

  /** Connections
   */
  lazy var connections: [Connection] = []
}

// MARK: - Columns
extension ConnectionsViewController {
  /** Table columns
   */
  fileprivate enum Column: StoryboardIdentifier {
    case balance = "BalanceColumn"
    case online = "OnlineColumn"
    case ping = "PingColumn"
    case publicKey = "PublicKeyColumn"
    
    /** Create from a table column
     */
    init?(fromTableColumn col: NSTableColumn?) {
      if let id = col?.identifier, let column = type(of: self).init(rawValue: id) { self = column } else { return nil }
    }
    
    /** Cell identifier for column cell
     */
    var asCellIdentifier: String {
      switch self {
      case .balance:
        return "BalanceCell"
        
      case .online:
        return "OnlineCell"
        
      case .ping:
        return "PingCell"
        
      case .publicKey:
        return "PublicKeyCell"
      }
    }
    
    /** Column identifier
     */
    var asColumnIdentifier: String { return rawValue }
    
    /** Make a cell in column
     */
    func makeCell(inTableView tableView: NSTableView, withTitle title: String) -> NSTableCellView? {
      let cell = tableView.make(withIdentifier: asCellIdentifier, owner: nil) as? NSTableCellView
      
      cell?.textField?.stringValue = title
      
      return cell
    }
  }
}

// MARK: - Networking
extension ConnectionsViewController {
  /** Get connections JSON errors
   */
  private enum GetJsonFailure: String, Error {
    case expectedData
    case expectedJson
  }

  /** Refresh connections
   */
  func refreshConnections() {
    let url = URL(string: "http://localhost:10553/v0/connections/")!
    
    let task = URLSession.shared.dataTask(with: URLRequest(url: url)) { [weak self] data, urlResponse, error in
      guard let data = data else { return print(GetJsonFailure.expectedData) }
      
      let dataDownloadedAsJson = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
      
      guard let jsonArray = dataDownloadedAsJson as? [[String: Any]] else { return print(GetJsonFailure.expectedJson) }
      
      do {
        let connections = try jsonArray.map { try Connection(from: $0) }
        
        DispatchQueue.main.async {
          self?.connections = connections
          
          self?.connectionsTableView?.reloadData()
        }
      } catch {
        print(error)
      }
    }
    
    task.resume()
  }
}

// MARK: - NSMenuDelegate
extension ConnectionsViewController: NSMenuDelegate {
  /** Close channel
   */
  func close(_ channel: Channel) {
    let session = URLSession.shared
    let sendUrl = URL(string: "http://localhost:10553/v0/channels/\(channel.id!)")!
    var sendUrlRequest = URLRequest(url: sendUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30)
    sendUrlRequest.httpMethod = "DELETE"
    sendUrlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let sendCloseChannelTask = session.dataTask(with: sendUrlRequest) { [weak self] data, urlResponse, error in
      DispatchQueue.main.async { self?.refreshConnections() }
    }
    
    sendCloseChannelTask.resume()
  }
  
  /** Decrease channel balance
   */
  func decreaseChannelBalance() {
    guard let clickedConnectionAtRow = connectionsTableView?.clickedRow else { return print("expectedClickedRow") }
    
    guard let connection = connection(at: clickedConnectionAtRow) else { return print("expectedConnection") }

    connection.channels.forEach { close($0) }
  }
  
  /** Increase channel balance
   */
  func increaseChannelBalance() {
    guard let clickedConnectionAtRow = connectionsTableView?.clickedRow else { return print("expectedClickedRow") }
    
    guard let connection = connection(at: clickedConnectionAtRow) else { return print("expectedConnection") }

    guard let _ = connection.peers.first else { return print("expectedPeer") }

    openChannel(with: connection)
  }
  
  /** Init the connections table menu
   */
  fileprivate func initMenu() {
    connectionsTableView?.menu = NSMenu()
    
    connectionsTableView?.menu?.delegate = self
  }
  
  /** Context menu is appearing
   */
  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()

    guard let selected = connectionsTableView?.selectedRow, let connection = connection(at: selected) else {
      menu.addItem(NSMenuItem(title: "Add Peer", action: #selector(segueToAddPeer), keyEquivalent: String()))
      
      return
    }

    switch connection.balance > Tokens() {
    case false:
      menu.addItem(NSMenuItem(title: "Increase Channel Balance", action: #selector(increaseChannelBalance), keyEquivalent: String()))
      
    case true:
      menu.addItem(NSMenuItem(title: "Decrease Channel Balance", action: #selector(decreaseChannelBalance), keyEquivalent: String()))
    }
  }
  
  /** Navigate to add peer sheet
   */
  func segueToAddPeer() {
    performSegue(withIdentifier: "AddPeerSegue", sender: self)
  }
  
  /** Open a channel with a connection
   */
  func openChannel(with connection: Connection) {
    let session = URLSession.shared
    let sendUrl = URL(string: "http://localhost:10553/v0/channels/")!
    var sendUrlRequest = URLRequest(url: sendUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30)
    sendUrlRequest.httpMethod = "POST"
    sendUrlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let data = "{\"partner_public_key\": \"\(connection.publicKey.hexEncoded)\"}".data(using: .utf8)
    
    // FIXME: - cleanup
    let sendTask = session.uploadTask(with: sendUrlRequest, from: data) { data, urlResponse, error in
      if let error = error { return print("ERROR \(error)") }

      print("OPENED CHANNEL")
    }
    
    sendTask.resume()
  }
}

extension ConnectionsViewController: NSTableViewDataSource {
  /** Data source error
   */
  enum DataSourceError: String, Error {
    case expectedKnownColumn
    case expectedConnectionForRow
  }

  /** Number of rows in table
   */
  func numberOfRows(in tableView: NSTableView) -> Int {
    return connections.count
  }
  
  /** Make cell for row at column
   */
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let column = Column(fromTableColumn: tableColumn) else {
      print(DataSourceError.expectedKnownColumn)
      
      return nil
    }
    
    guard let connection = connection(at: row) else { print(DataSourceError.expectedConnectionForRow); return nil }
    

    let title: String
    
    switch column {
    case .balance:
      title = "\(connection.balance.formatted) tBTC"
      
    case .online:
      let hasActivePeer = !connection.peers.isEmpty
      
      guard hasActivePeer else { title = "Offline"; break }
      
      let hasActiveChannel = connection.channels.contains { $0.state == .active }
      
      guard !hasActiveChannel else { title = "Online"; break }
      
      let hasOpeningChannel = connection.channels.contains { $0.state == .opening }
      
      guard !hasOpeningChannel else { title = "Connecting"; break }
      
      let hasClosingChannel = connection.channels.contains { $0.state == .closing }
      
      guard !hasClosingChannel else { title = "Closing"; break }
      
      title = "Online"
      
    case .ping:
      guard let ping = connection.bestPing else {
        title = " "
        
        break
      }
      
      title = "\(ping)ms"
      
    case .publicKey:
      title = connection.publicKey.hexEncoded
    }
    
    return column.makeCell(inTableView: tableView, withTitle: title)
  }

  func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
    return connection(at: row)
  }
  
  /** Get a connection for a row number
   */
  fileprivate func connection(at row: Int) -> Connection? {
    guard row >= Int() && row < connections.count else { return nil }
    
    return connections[row]
  }
}

// MARK: - NSTableViewDelegate
extension ConnectionsViewController: NSTableViewDelegate {}

// MARK: - WalletListener
extension ConnectionsViewController: WalletListener {
  /** Wallet was updated
   */
  func wallet(updated: Wallet) {
    refreshConnections()

    // FIXME: - animate changes
  }
}
