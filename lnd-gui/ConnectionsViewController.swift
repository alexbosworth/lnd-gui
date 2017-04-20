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
  @IBOutlet weak var connectionsTableView: NSTableView?

  override func viewDidAppear() {
    super.viewDidAppear()
    
    refreshConnections()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()

    connectionsTableView?.menu = NSMenu()
    
    connectionsTableView?.menu?.delegate = self
  }
  
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
    
    /** Create from a table column
     */
    init?(fromTableColumn: NSTableColumn?) {
      if let id = fromTableColumn?.identifier, let c = type(of: self).init(rawValue: id) { self = c } else { return nil }
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
  private enum GetJsonFailure: String, Error {
    case expectedData
    case expectedJson
  }

  func refreshConnections() {
    let url = URL(string: "http://localhost:10553/v0/connections/")!
    let session = URLSession.shared
    
    var request = URLRequest(url: url)
    
    request.httpMethod = "GET"
    
    let task = session.dataTask(with: request) { [weak self] data, urlResponse, error in
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

extension ConnectionsViewController: NSMenuDelegate {
  func close(_ channel: Channel) {
    let session = URLSession.shared
    let sendUrl = URL(string: "http://localhost:10553/v0/channels/\(channel.id)")!
    var sendUrlRequest = URLRequest(url: sendUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30)
    sendUrlRequest.httpMethod = "DELETE"
    sendUrlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let sendCloseChannelTask = session.dataTask(with: sendUrlRequest) { [weak self] data, urlResponse, error in
      DispatchQueue.main.async {
        print("CONNECTION CLOSED", urlResponse, error)

        self?.refreshConnections()
      }
    }
    
    sendCloseChannelTask.resume()
  }
  
  func decreaseChannelBalance() {
    guard let clickedConnectionAtRow = connectionsTableView?.clickedRow else { return print("expectedClickedRow") }
    
    guard let connection = connection(at: clickedConnectionAtRow) else { return print("expectedConnection") }

    connection.channels.forEach { close($0) }
  }
  
  func increaseChannelBalance() {
    guard let clickedConnectionAtRow = connectionsTableView?.clickedRow else { return print("expectedClickedRow") }
    
    guard let connection = connection(at: clickedConnectionAtRow) else { return print("expectedConnection") }

    guard let peer = connection.peers.first else { return print("expectedPeer") }

    openChannel(with: connection)
  }
  
  /** Context menu is appearing
   */
  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()
    
    menu.addItem(NSMenuItem(title: "Decrease Channel Balance", action: #selector(decreaseChannelBalance), keyEquivalent: String()))
    menu.addItem(NSMenuItem(title: "Increase Channel Balance", action: #selector(increaseChannelBalance), keyEquivalent: String()))
    
    menu.addItem(NSMenuItem(title: "Add Peer", action: #selector(segueToAddPeer), keyEquivalent: String()))
  }
  
  func segueToAddPeer() {
    performSegue(withIdentifier: "AddPeerSegue", sender: self)
  }
  
  func openChannel(with connection: Connection) {
    let session = URLSession.shared
    let sendUrl = URL(string: "http://localhost:10553/v0/channels/")!
    var sendUrlRequest = URLRequest(url: sendUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30)
    sendUrlRequest.httpMethod = "POST"
    sendUrlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let data = "{\"partner_public_key\": \"\(connection.publicKey.hexEncoded)\"}".data(using: .utf8)
    
    // FIXME: - cleanup
    let sendTask = session.uploadTask(with: sendUrlRequest, from: data) { [weak self] data, urlResponse, error in
      if let error = error { return print("ERROR \(error)") }

      print("OPENED CHANNEL", data, urlResponse as? HTTPURLResponse, error)
    }
    
    sendTask.resume()
  }
}

// FIXME: - animate changes
extension ConnectionsViewController: NSTableViewDataSource {
  enum DataSourceError: String, Error {
    case expectedKnownColumn
    case expectedConnectionForRow
  }

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
      title = connection.peers.isEmpty ? "Offline": "Online"
      
    case .ping:
      guard let ping = connection.bestPing else {
        title = " "
        
        break
      }
      
      title = "\(ping)ms"
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

extension ConnectionsViewController: NSTableViewDelegate {}
