
//  Transaction.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

enum TransactionCategory: Int, CustomStringConvertible {
  case grocery
  case cafe
  case transport
  case entertainment
  case bills
  case other
  
  init?(exportName name: String) {
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
    case .grocery: return "Grocery"
    case .cafe: return "Cafe"
    case .transport: return "Transport"
    case .entertainment: return "Entertainment"
    case .bills: return "Bills"
    case .other: return "Other"
    }
  }
  
  var exportName: String {
    switch self {
    case .grocery: return "Grocery"
    case .cafe: return "Cafe"
    case .transport: return "Transport"
    case .entertainment: return "Entertainment"
    case .bills: return "Bills"
    case .other: return "Other"
    }
  }
}

struct Transaction {
  var amount: Double {
    didSet {
      modifiedDate = Date.now
    }
  }
  var category: TransactionCategory {
    didSet {
      modifiedDate = Date.now
    }
  }
  var authorName: String {
    didSet {
      modifiedDate = Date.now
    }
  }
  
  var date: Date { // date of transaction in real world (set by user)
    didSet {
      modifiedDate = Date.now
    }
  }
  let createdDate: Date // date when user created the transaction
  private(set) var modifiedDate: Date // last modification date
  
  init(amount: Double, category: TransactionCategory, authorName: String, transactionDate: Date, creationDate: Date = Date.now, modifiedDate: Date = Date.now) {
    self.amount = amount
    self.category = category
    self.authorName = authorName
    self.date = transactionDate
    self.createdDate = creationDate
    self.modifiedDate = modifiedDate
  }
  
  var hash: Int {
    return createdDate.hashValue
  }
}

extension Transaction: Equatable {
  public static func ==(lhs: Transaction, rhs: Transaction) -> Bool {
    return lhs.amount == rhs.amount &&
      lhs.authorName == rhs.authorName &&
      lhs.category == rhs.category &&
      abs(lhs.createdDate.timeIntervalSince(rhs.createdDate)) < 1e-6 &&
      abs(lhs.date.timeIntervalSince(rhs.date)) < 1e-6
  }
}

extension Transaction: CustomStringConvertible {
  var description: String {
    return "\(authorName), \(date): \(category), \(amount)"
  }
}

struct MonthReport {
  let monthDate: Date
  let amount: Double
}

enum SyncMode: Int, CustomStringConvertible {
  case merge
  case update
  
  var description: String {
    switch self {
    case .merge: return "Merge"
    case .update: return "Update"
    }
  }
}

// Meta-object that encapsulates all information required for sync
class SyncData: NSObject, NSCoding {
  let mode: SyncMode
  let transactions: [Transaction]
  
  init(transactions: [Transaction], mode: SyncMode) {
    self.transactions = transactions
    self.mode = mode
  }
  
  required init?(coder decoder: NSCoder) {
    transactions = decoder.decodeObject(forKey: "transactions") as! [Transaction]
    mode = SyncMode(rawValue: decoder.decodeInteger(forKey: "mode"))!
  }
  
  init?(data: Data) {
    guard let syncData = NSKeyedUnarchiver.unarchiveObject(with: data) as? SyncData else { return nil }
    mode = syncData.mode
    transactions = syncData.transactions
  }
  
  func encode(with coder: NSCoder) {
    coder.encode(transactions, forKey: "transactions")
    coder.encode(mode.rawValue, forKey: "mode")
  }
  
  func archived() -> Data {
    return NSKeyedArchiver.archivedData(withRootObject: self)
  }
}

struct SyncHistoryManager {
  private var dirPath: String {
    return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/sync-history"
  }
  
  init() {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: dirPath) {
      do {
        try fileManager.createDirectory(atPath: dirPath, withIntermediateDirectories: false, attributes: nil)
      } catch {
        print("can't create sync history directory: \(error)")
      }
    }
  }
  
  private func filePathFor(_ deviceID: String) -> String {
    return dirPath + "/" + deviceID
  }
  
  func transactionsListAtPreviousSync(forDeviceID deviceID: String) -> [Int] {
    let filePath = filePathFor(deviceID)
    let fileUrl = URL(fileURLWithPath: filePath)
    guard FileManager.default.fileExists(atPath: filePath),
      let data = try? Data(contentsOf: fileUrl),
      let transactions = NSKeyedUnarchiver.unarchiveObject(with: data) as? [Int]
      else { return [] }
    return transactions
  }
  
  func update(transactionsList: [Int], forDeviceID deviceID: String) {
    let fileUrl = URL(fileURLWithPath: filePathFor(deviceID))
    let data = NSKeyedArchiver.archivedData(withRootObject: transactionsList)
    do {
      try data.write(to: fileUrl)
    } catch {
      print("Can't write sync history for deviceID \(deviceID): \(error)")
    }
  }
}
