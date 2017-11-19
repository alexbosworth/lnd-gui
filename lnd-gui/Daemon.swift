//
//  Daemon.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/6/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

struct Daemon {}

extension Daemon {
  enum DeletionResult {
    case error(Error)
    case success
  }
  
  enum GetJsonResult {
    case error(Error)
    case data(Data)
  }
  
  enum SendJsonResult {
    case error(Error)
    case success(Data)
  }
  
  enum Api {
    case balance
    case channels(String)
    case connections
    case exchangeRate(CurrencyType)
    case history
    case invoices
    case paymentRequest(String)
    case payments
    case peers
    case transactions
    
    private var type: String {
      switch self {
      case .balance:
        return "balance"
        
      case .channels:
        return "channels"
        
      case .connections:
        return "connections"
        
      case .exchangeRate(_):
        return "exchange"
        
      case .history:
        return "history"
        
      case .invoices:
        return "invoices"
        
      case .paymentRequest(_):
        return "payment_request"
        
      case .payments:
        return "payments"
        
      case .peers:
        return "peers"
        
      case .transactions:
        return "transactions"
      }
    }
    
    var url: URL? {
      let route = "http://localhost:10553/v0/\(type)/"
      
      switch self {
      case .balance, .connections, .history, .invoices, .payments, .peers, .transactions:
        return URL(string: route)
        
      case .channels(let channelId):
        return URL(string: "\(route)\(channelId)")
        
      case .exchangeRate(let currency):
        return URL(string: "\(route)\(currency.exchangeSymbol)/current_rate")
        
      case .paymentRequest(let paymentRequest):
        return URL(string: "\(route)\(paymentRequest)")
      }
    }
    
    var urlRequest: URLRequest? {
      guard let url = url else { return nil }
      
      let timeoutInterval: TimeInterval = 30
      
      var urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeoutInterval)
      
      // FIXME: - cleanup and abstract
      let username = "user"
      let password = "pass"
      let loginString = String(format: "%@:%@", username, password)
      guard let loginData = loginString.data(using: String.Encoding.utf8) else { return nil }
      let base64LoginString = loginData.base64EncodedString()
      urlRequest.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
      
      return urlRequest
    }
  }
  
  enum RequestFailure: Error {
    case expectedHttpResponse
    case expectedResponseData
    case expectedUrlRequest
    case expectedValidUrl
    case unexpectedFailureResponse
  }
  
  enum HttpMethod: String {
    case delete = "DELETE"
    case post = "POST"
    
    var asString: String { return rawValue }
  }
  
  static func delete(in api: Api, completion: @escaping (DeletionResult) -> ()) throws {
    guard var urlRequest = api.urlRequest else { throw RequestFailure.expectedUrlRequest }
    
    urlRequest.httpMethod = HttpMethod.delete.asString
    
    let deleteTask = URLSession.shared.dataTask(with: urlRequest) { _, _, error in
      DispatchQueue.main.async {
        if let error = error { return completion(.error(error)) }
        
        completion(.success)
      }
    }
    
    deleteTask.resume()
  }
  
  static func get(from api: Api, completion: @escaping (GetJsonResult) -> ()) throws {
    guard let urlRequest = api.urlRequest else { throw RequestFailure.expectedValidUrl }
    
    let getJsonTask = URLSession.shared.dataTask(with: urlRequest) { data, _, error in
      DispatchQueue.main.async {
        if let error = error { return completion(.error(error)) }
        
        guard let data = data else { return completion(.error(RequestFailure.expectedResponseData)) }
        
        return completion(.data(data))
      }
    }
    
    getJsonTask.resume()
  }
  
  enum StatusCode {
    case success
    
    enum Failure: Error {
      case unexpectedStatusCode
    }
    
    init(from response: HTTPURLResponse) throws {
      switch response.statusCode {
      case 200:
        self = .success
        
      default:
        throw Failure.unexpectedStatusCode
      }
    }
    
    var isSuccess: Bool {
      switch self {
      case .success:
        return true
      }
    }
  }
  
  static func send(json: [String: Any], to: Api, completion: @escaping (SendJsonResult) -> ()) throws {
    let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
    
    guard var urlRequest = to.urlRequest else { throw RequestFailure.expectedValidUrl }
    
    urlRequest.httpMethod = HttpMethod.post.asString
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.timeoutInterval = TimeInterval(60)
    
    let task = URLSession.shared.uploadTask(with: urlRequest, from: data) { data, urlResponse, error in
      DispatchQueue.main.async {
        if let error = error { return completion(.error(error)) }
        
        guard let httpUrlResponse = urlResponse as? HTTPURLResponse else {
          return completion(.error(RequestFailure.expectedHttpResponse))
        }
        
        let statusCode: StatusCode
        
        do { statusCode = try StatusCode(from: httpUrlResponse) } catch { return completion(.error(error)) }
        
        guard statusCode.isSuccess else { return completion(.error(RequestFailure.unexpectedFailureResponse)) }
        
        return completion(.success((data ?? Data()) as Data))
      }
    }
    
    task.resume()
  }
}

// MARK: - makePayment
extension Daemon {
  enum MakePaymentResult {
    case error(Error)
    case success
  }

  enum SendPaymentJsonAttribute: String {
    case paymentRequest
    
    var key: String {
      switch self {
      case .paymentRequest:
        return "payment_request"
      }
    }
  }
  
  enum MakePaymentError: Error {
    case expectedSerializedPaymentRequest
  }

  static func makePayment(_ payment: LightningPayment, completion: @escaping(MakePaymentResult) -> ()) throws {
    guard let serializedPaymentRequest = payment.serializedPaymentRequest else {
      throw MakePaymentError.expectedSerializedPaymentRequest
    }
    
    let json: JsonDictionary = [SendPaymentJsonAttribute.paymentRequest.key: serializedPaymentRequest]

    try send(json: json, to: .payments) { result in
      switch result {
      case .error(let error):
        completion(.error(error))
        
      case .success:
        completion(.success)
      }
    }
  }
}

// MARK: - getExchangeRate
extension Daemon {
  enum GetExchangeRateResult {
    case error(Error)
    case centsPerCoin(Int)
  }
  
  enum ExchangeRateResponseJsonKey: String {
    case centsPerBitcoin = "cents_per_bitcoin"
    
    var key: String { return rawValue }
  }
  
  static func getExchangeRate(currency: CurrencyType, completion: @escaping(GetExchangeRateResult) -> ()) throws {
    try get(from: .exchangeRate(currency)) { result in
      switch result {
      case .data(let data):
        let dataDownloadedAsJson: Any
        
        do {
          dataDownloadedAsJson = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        } catch {
          return completion(.error(RequestFailure.expectedResponseData))
        }
        
        guard
          let json = dataDownloadedAsJson as? JsonDictionary,
          let centsPerBitcoin = (json[ExchangeRateResponseJsonKey.centsPerBitcoin.key] as? NSNumber)?.intValue
          else
        {
          return completion(.error(RequestFailure.expectedResponseData))
        }
        
        completion(.centsPerCoin(centsPerBitcoin))
        
      case .error(let error):
        completion(.error(error))
      }
    }
  }
}

// MARK: - getHistory
extension Daemon {
  enum GetHistoryResult {
    case error(Error)
    case transactions(Set<Transaction>)
  }
  
  enum RefreshHistoryFailure: Error {
    case expectedHistoryData
  }
  
  /** Get transaction history
   */
  static func getHistory(completion: @escaping(GetHistoryResult) -> ()) throws {
    try get(from: .history) { result in
      switch result {
      case .data(let data):
        let dataDownloadedAsJson = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
        
        guard let history = dataDownloadedAsJson as? [JsonDictionary] else {
          return completion(.error(RefreshHistoryFailure.expectedHistoryData))
        }
        
        do {
          completion(.transactions(Set(try history.map { try Transaction(from: $0) })))
        } catch {
          completion(.error(error))
        }
        
      case .error(let error):
        completion(.error(error))
      }
    }
  }
}

// getConnections
extension Daemon {
  enum GetConnectionsResult {
    case connections([Connection])
    case error(Error)
  }
  
  enum GetConnectionsFailure: Error {
    case expectedJson
  }
  
  static func getConnections(completion: @escaping (GetConnectionsResult) -> ()) throws {
    try get(from: .connections) { result in
      switch result {
      case .data(let data):
        do {
          let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
          
          guard let jsonArray = jsonObject as? [JsonDictionary] else {
            return completion(.error(GetConnectionsFailure.expectedJson))
          }
          
          completion(.connections(try jsonArray.map { try Connection(from: $0) }))
        } catch {
          return completion(.error(error))
        }
        
      case .error(let error):
        completion(.error(error))
      }
    }
  }
}

extension Daemon {
  enum GetBalancesResult {
    case error(Error)
    case balances(WalletBalances)
  }
  
  static func getBalances(completion: @escaping (GetBalancesResult) -> ()) throws {
    try get(from: .balance) { result in
      switch result {
      case .data(let data):
        do {
          completion(.balances(try WalletBalances(from: data)))
        } catch {
          completion(.error(error))
        }
        
      case .error(let error):
        completion(.error(error))
      }
    }
  }
}

extension Daemon {
  enum AddPeerResult {
    case error(Error)
    case success
  }
  
  enum AddInvoiceJsonAttribute: String {
    case description
    case includeAddress = "include_address"
    case memo
    case tokens
    
    var key: String { return rawValue }
  }
  
  enum AddPeerJsonAttribute: String {
    case host
    case publicKey = "public_key"
    
    var key: String { return rawValue }
  }
  
  enum AddInvoiceResult {
    case addedInvoice(LightningInvoice)
    case error(Error)
  }
  
  static func addInvoice(amount: Tokens, description: String?, completion: @escaping (AddInvoiceResult) -> ()) throws {
    let json: JsonDictionary = [
      AddInvoiceJsonAttribute.description.key: (description ?? String()) as String,
      AddInvoiceJsonAttribute.includeAddress.key: true,
      AddInvoiceJsonAttribute.memo.key: (description ?? String()) as String,
      AddInvoiceJsonAttribute.tokens.key: amount
    ]
    
    try send(json: json, to: .invoices) { result in
      switch result {
      case .error(let error):
        completion(.error(error))
        
      case .success(let data):
        do { completion(.addedInvoice(try LightningInvoice(from: data))) } catch { completion(.error(error)) }
      }
    }
  }
  
  static func addPeer(ip: String, publicKey: PublicKey, completion: @escaping (AddPeerResult) -> ()) throws {
    let json = [AddPeerJsonAttribute.host.key: ip, AddPeerJsonAttribute.publicKey.key: publicKey.hexEncoded]
    
    try send(json: json, to: .peers) { result in
      switch result {
      case .error(let error):
        completion(.error(error))
        
      case .success:
        completion(.success)
      }
    }
  }
}
