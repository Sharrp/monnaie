
//  Transaction.swift
//  monnaie
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
    for category in TransactionCategory.allCases {
      if category.exportName == name {
        self = category
        return
      }
    }
    return nil
  }
  
  static var defaultCategory: TransactionCategory {
    return .grocery
  }
  
  var description: String {
    return name
  }
  
  var emoji: String {
    switch self {
    case .grocery: return NSLocalizedString("🍙", comment: "Grocery category emoji")
    case .cafe: return NSLocalizedString("🍜", comment: "Cafe category emoji")
    case .transport: return NSLocalizedString("🚌", comment: "Transport category emoji")
    case .entertainment: return NSLocalizedString("🤘", comment: "Entertainment category emoji")
    case .bills: return NSLocalizedString("💴", comment: "Bills category emoji")
    case .other: return NSLocalizedString("📌", comment: "Other category emoji")
    }
  }
  
  var name: String {
    switch self {
    case .grocery: return NSLocalizedString("Grocery", comment: "Category grocery")
    case .cafe: return NSLocalizedString("Cafe", comment: "Category cafe")
    case .transport: return NSLocalizedString("Transport", comment: "Category transport")
    case .entertainment: return NSLocalizedString("Entertainment", comment: "Category entertainment")
    case .bills: return NSLocalizedString("Bills", comment: "Category bills")
    case .other: return NSLocalizedString("Other", comment: "Category other")
    }
  }
  
  // Do not translate for compatibility between all languages
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

extension TransactionCategory: RawIntEnum { }

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

enum Currency: Int {
  case USD
  case EUR
  case GBP
  case JPY
  case RUB
  case any
  
  init?(withCode code: String?) {
    guard let code = code else { return nil }
    for currency in Currency.allCases {
      if currency.code == code {
        self = currency
        return
      }
    }
    return nil
  }
  
  static var defaultCurrency: Currency {
    let localCode = NumberFormatter().currencyCode
    return Currency(withCode: localCode) ?? .USD
  }
  
  var code: String {
    switch self {
    case .USD: return "USD"
    case .EUR: return "EUR"
    case .GBP: return "GBP"
    case .JPY: return "JPY"
    case .RUB: return "RUB"
    case .any: return ""
    }
  }
  
  var sign: String {
    switch self {
    case .USD: return "$"
    case .EUR: return "€"
    case .GBP: return "£"
    case .JPY: return "¥"
    case .RUB: return "₽"
    case .any: return "¤"
    }
  }
  
  var name: String {
    switch self {
    case .USD: return NSLocalizedString("US Dollar", comment: "US Dollar name")
    case .EUR: return NSLocalizedString("Euro", comment: "Euro name")
    case .GBP: return NSLocalizedString("Great Britain Pound", comment: "Great Britain Pound name")
    case .JPY: return NSLocalizedString("Japanese Yen", comment: "Japanese Yen name")
    case .RUB: return NSLocalizedString("Russian Rouble", comment: "Russian Rouble name")
    case .any: return NSLocalizedString("Universal currency sign", comment: "Universal currency sign name")
    }
  }
  
  var decimalsAllowed: Bool {
    if self == .JPY {
      return false
    }
    return true
  }
}

extension Currency: RawIntEnum { }

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
