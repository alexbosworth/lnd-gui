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
      
      return URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeoutInterval)
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
    guard let url = api.url else { throw RequestFailure.expectedValidUrl }
    
    let getJsonTask = URLSession.shared.dataTask(with: URLRequest(url: url)) { data, _, error in
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

extension Daemon {
  enum AddPeerResult {
    case error(Error)
    case success
  }

  enum AddInvoiceJsonAttribute: String {
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
  
  static func addInvoice(amount: Tokens, memo: String?, completion: @escaping (AddInvoiceResult) -> ()) throws {
    let json: JsonDictionary = [
      AddInvoiceJsonAttribute.includeAddress.key: true,
      AddInvoiceJsonAttribute.memo.key: (memo ?? String()) as String,
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
  
  static func addPeer(ip: IpAddress, publicKey: PublicKey, completion: @escaping (AddPeerResult) -> ()) throws {
    let json = [AddPeerJsonAttribute.host.key: ip.serialized, AddPeerJsonAttribute.publicKey.key: publicKey.hexEncoded]

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
