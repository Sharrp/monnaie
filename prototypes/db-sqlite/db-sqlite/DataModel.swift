//
//  DataModel.swift
//  db-sqlite
//
//  Created by Anton Vronskii on 2018/10/14.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation

enum TransactionCategory: Int, CustomStringConvertible {
  case grocery
  case cafe
  case transport
  case entertainment
  case bills
  case other
  
  init?(name: String) {
    for category in TransactionCategory.allCases() {
      if category.name == name {
        self = category
        return
      }
    }
    return nil
  }
  
  static func allCases() -> [TransactionCategory] {
    var rawValue = 0
    var cases = [TransactionCategory]()
    while true {
      if let enumValue = TransactionCategory(rawValue: rawValue) {
        cases.append(enumValue)
        rawValue += 1
      } else {
        break
      }
    }
    return cases
  }
  
  static var defaultCategory: TransactionCategory {
    return .grocery
  }
  
  var description: String {
    return name
  }
  
  var emoji: String {
    switch self {
    case .grocery: return "🍙"
    case .cafe: return "🍜"
    case .transport: return "🚌"
    case .entertainment: return "🤘"
    case .bills: return "💴"
    case .other: return "📌"
    }
  }
  
  var name: String {
    switch self {
    case .grocery:
      return "Grocery"
    case .cafe:
      return "Cafe"
    case .transport:
      return "Transport"
    case .entertainment:
      return "Entertainment"
    case .bills:
      return "Bills"
    case .other:
      return "Other"
    }
  }
}

class Transaction: NSObject, NSCoding {
  var amount: Float {
    didSet {
      modifiedDate = Date()
    }
  }
  var category: TransactionCategory {
    didSet {
      modifiedDate = Date()
    }
  }
  var authorName: String {
    didSet {
      modifiedDate = Date()
    }
  }
  
  var date: Date { // date of transaction in real world (set by user)
    didSet {
      modifiedDate = Date()
    }
  }
  let createdDate: Date // date when user created the transaction
  private(set) var modifiedDate: Date // last modification date
  
  init(amount: Float, category: TransactionCategory, authorName: String, transactionDate: Date, creationDate: Date = Date()) {
    self.amount = amount
    self.category = category
    self.authorName = authorName
    self.date = transactionDate
    self.createdDate = creationDate
    self.modifiedDate = Date()
  }
  
  required init(coder decoder: NSCoder) {
    amount = decoder.decodeFloat(forKey: "amount")
    let categoryRawValue = decoder.decodeInteger(forKey: "category")
    category = TransactionCategory(rawValue: categoryRawValue)!
    authorName = decoder.decodeObject(forKey: "authorName") as! String
    
    date = decoder.decodeObject(forKey: "date") as! Date
    createdDate = decoder.decodeObject(forKey: "createdDate") as! Date
    modifiedDate = decoder.decodeObject(forKey: "modifiedDate") as! Date
  }
  
  func encode(with coder: NSCoder) {
    coder.encode(amount, forKey: "amount")
    coder.encode(category.rawValue, forKey: "category")
    coder.encode(authorName, forKey: "authorName")
    
    coder.encode(date, forKey: "date")
    coder.encode(createdDate, forKey: "createdDate")
    coder.encode(modifiedDate, forKey: "modifiedDate")
  }
}

extension Transaction {
  override func isEqual(_ object: Any?) -> Bool {
    guard let transaction = object as? Transaction else { return false }
    return date == transaction.date
  }
  
  override var hash: Int {
    return createdDate.hashValue
  }
}

extension Transaction {
  override var description: String {
    return "\(authorName), \(date): \(category), \(amount)"
  }
}
