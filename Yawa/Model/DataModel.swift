//
//  Transaction.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation

enum TransactionCategory: Int, CustomStringConvertible {
  case grocery
  case cafe
  case other
  
  var description: String {
    switch self {
    case .grocery:
      return "Grocery"
    case .cafe:
      return "Cafe"
    case .other:
      return "Other"
    }
  }
}

class Transaction: NSObject, NSCoding {
  let amount: Float
  let category: TransactionCategory
  let author: String
  let date: Date
  
  init(amount: Float, category: TransactionCategory, author: String, date: Date) {
    self.amount = amount
    self.category = category
    self.author = author
    self.date = date
  }
  
  required init(coder decoder: NSCoder) {
    amount = decoder.decodeFloat(forKey: "amount")
    let categoryRawValue = decoder.decodeInteger(forKey: "category")
    category = TransactionCategory(rawValue: categoryRawValue)!
    author = decoder.decodeObject(forKey: "author") as! String
    date = decoder.decodeObject(forKey: "date") as! Date
  }
  
  func encode(with coder: NSCoder) {
    coder.encode(amount, forKey: "amount")
    coder.encode(category.rawValue, forKey: "category")
    coder.encode(author, forKey: "author")
    coder.encode(date, forKey: "date")
  }
}

extension Transaction {
  override func isEqual(_ object: Any?) -> Bool {
    guard let transaction = object as? Transaction else { return false }
    let equal = author == transaction.author && date == transaction.date
    return equal
  }
  
  override var hashValue: Int {
    return "\(author)\(date)".hashValue
  }
}

extension Transaction {
  override var description: String {
    return "\(author), \(date): \(category), \(amount)"
  }
}
