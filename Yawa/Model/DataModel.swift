//
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
  let date: Date // date of transaction in real world (set by user)
  let createdDate: Date // date when user created the transaction
  let modifiedDate: Date // last modificatino date
  
  init(amount: Float, category: TransactionCategory, author: String, date: Date) {
    self.amount = amount
    self.category = category
    self.author = author
    self.date = date
    self.createdDate = Date()
    self.modifiedDate = self.createdDate
  }
  
  required init(coder decoder: NSCoder) {
    amount = decoder.decodeFloat(forKey: "amount")
    let categoryRawValue = decoder.decodeInteger(forKey: "category")
    category = TransactionCategory(rawValue: categoryRawValue)!
    author = decoder.decodeObject(forKey: "author") as! String
    date = decoder.decodeObject(forKey: "date") as! Date
    createdDate = decoder.decodeObject(forKey: "createdDate") as! Date
    modifiedDate = decoder.decodeObject(forKey: "modifiedDate") as! Date
  }
  
  func encode(with coder: NSCoder) {
    coder.encode(amount, forKey: "amount")
    coder.encode(category.rawValue, forKey: "category")
    coder.encode(author, forKey: "author")
    coder.encode(date, forKey: "date")
    coder.encode(createdDate, forKey: "createdDate")
    coder.encode(modifiedDate, forKey: "modifiedDate")
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

enum SyncRequestMode: Int {
  case merge
  case update
}

// Meta-object that encapsulates all information required for sync
class SyncData: NSObject, NSCoding {
  let transactions: [Transaction]
  let mode: SyncRequestMode
  let deviceID: String
  
  init(transactions: [Transaction], mode:SyncRequestMode = .merge) {
    self.transactions = transactions
    self.mode = mode
    deviceID = deviceUniqueIdentifier()
  }
  
  required init?(coder decoder: NSCoder) {
    transactions = decoder.decodeObject(forKey: "transactions") as! [Transaction]
    mode = SyncRequestMode(rawValue: decoder.decodeInteger(forKey: "mode"))!
    deviceID = decoder.decodeObject(forKey: "deviceID") as! String
  }
  
  func encode(with coder: NSCoder) {
    coder.encode(transactions, forKey: "transactions")
    coder.encode(mode.rawValue, forKey: "mode")
    coder.encode(deviceID, forKey: "deviceID")
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
