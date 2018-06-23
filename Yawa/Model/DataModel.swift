
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
  var amount: Float
  var category: TransactionCategory
  var authorName: String
  
  var date: Date // date of transaction in real world (set by user)
  let createdDate: Date // date when user created the transaction
  var modifiedDate: Date // last modification date
  private let authorID: String
  
  init(amount: Float, category: TransactionCategory, authorName: String, date: Date) {
    self.amount = amount
    self.category = category
    self.authorName = authorName
    self.date = date
    self.createdDate = Date()
    self.modifiedDate = self.createdDate
    authorID = deviceUniqueIdentifier()
  }
  
  required init(coder decoder: NSCoder) {
    amount = decoder.decodeFloat(forKey: "amount")
    let categoryRawValue = decoder.decodeInteger(forKey: "category")
    category = TransactionCategory(rawValue: categoryRawValue)!
    authorName = decoder.decodeObject(forKey: "authorName") as! String
    
    date = decoder.decodeObject(forKey: "date") as! Date
    createdDate = decoder.decodeObject(forKey: "createdDate") as! Date
    modifiedDate = decoder.decodeObject(forKey: "modifiedDate") as! Date
    authorID = decoder.decodeObject(forKey: "authorID") as! String
  }
  
  func encode(with coder: NSCoder) {
    coder.encode(amount, forKey: "amount")
    coder.encode(category.rawValue, forKey: "category")
    coder.encode(authorName, forKey: "authorName")
    
    coder.encode(date, forKey: "date")
    coder.encode(createdDate, forKey: "createdDate")
    coder.encode(modifiedDate, forKey: "modifiedDate")
    coder.encode(authorID, forKey: "authorID")
  }
  
  var isCreatedOnCurrentDevice: Bool {
    return authorID == deviceUniqueIdentifier()
  }
}

extension Transaction {
  override func isEqual(_ object: Any?) -> Bool {
    guard let transaction = object as? Transaction else { return false }
    let equal = authorID == transaction.authorID && date == transaction.date
    return equal
  }
  
  override var hashValue: Int {
    return "\(authorID)\(date)".hashValue
  }
}

extension Transaction {
  override var description: String {
    return "\(authorName), \(date): \(category), \(amount)"
  }
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
