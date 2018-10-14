//
//  TransactionsController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/19.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation

// Represenets range of transactions for a day or a month
private struct CalendarSection {
  let first: Int
  let length: Int
  
  var firstOfNext: Int {
    return first + length
  }
}

private struct TransactionsIndex {
  var days = [CalendarSection]()
  var months = [CalendarSection]()
}

protocol TransactionsPresentor: AnyObject {
  func didUpdate(days: [Int])
  func didUpdateTransactions(atIndexPaths indexPaths: [IndexPath])
  func didUpdateAll()
}

typealias CategoriesSummary = [(category: TransactionCategory, amount: Float)]

class TransactionsController: TransactionsDataSource {
  private let storeManager = StoreManager()
  private(set) var transactions: [Transaction]
  private var index: TransactionsIndex!
  
  weak var presentor: TransactionsPresentor?
  weak var syncManager: P2PSyncManager?
  
  init() {
    transactions = storeManager.loadTransactions().sorted { $0.date < $1.date }
    index = buildTableIndex(transactions)
  }
  
  // For unit-tests
  init(withTransactions transactions: [Transaction]) {
    self.transactions = transactions.sorted { $0.date < $1.date }
    index = buildTableIndex(transactions)
  }
  
  func numberOfTransactions() -> Int {
    return transactions.count
  }
  
  func numberOfMonths() -> Int {
    return index.months.count
  }
  
  func numberOfDays(inMonth month: Int) -> Int {
    let first = index.months[month].first
    let firstOfNext = index.months[month].firstOfNext
    return index.days.filter { $0.first >= first && $0.first < firstOfNext }.count
  }
  
  func totalNumberOfDays() -> Int {
    return index.days.count
  }
  
  func numberOfTransactions(forDay day: Int) -> Int {
    return index.days[day].length
  }
  
  func date(forDay day: Int) -> Date {
    let transactionIndex = index.days[day].first
    return transactions[transactionIndex].date
  }
  
  func totalAmount(forMonth month: Int) -> Float {
    let monthSection = index.months[month]
    let range = monthSection.first..<monthSection.firstOfNext
    return transactions[range].reduce(0) { $0 + $1.amount }
  }
  
  func totalAmount(forDay day: Int) -> Float {
    let daySection = index.days[day]
    let indexRange = daySection.first..<daySection.firstOfNext
    return transactions[indexRange].reduce(0.0) { $0 + $1.amount }
  }
  
  func totalAmountForToday() -> Float {
    for (i, daySection) in index.days.enumerated() {
      let date = transactions[daySection.first].date
      if Calendar.current.isDate(date, inSameDayAs: Date()) {
        return totalAmount(forDay: i)
      }
    }
    return 0
  }
  
  func totalAmountForCurrentMonth() -> Float {
    let thisMonthTransactions = transactions.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    return thisMonthTransactions.reduce(0) { $0 + $1.amount }
  }
  
  func categoriesSummary(forMonth month: Int) -> CategoriesSummary {
    let monthSection = index.months[month]
    let monthRange = monthSection.first..<monthSection.firstOfNext
    
    var categoryToAmount = [TransactionCategory: Float]()
    for transaction in transactions[monthRange] {
      if let currentAmount = categoryToAmount[transaction.category] {
        categoryToAmount[transaction.category] = currentAmount + transaction.amount
      } else {
        categoryToAmount[transaction.category] = transaction.amount
      }
    }
    return categoryToAmount.keys.map{ (category: $0, amount: categoryToAmount[$0]!) }.sorted{ $0.amount > $1.amount }
  }
  
  var syncTransactions: [Transaction] {
    return transactions
  }
  
  func transaction(forDay day: Int, withIndex transactionIndex: Int) -> Transaction {
    let i = index.days[day].first + transactionIndex
    return transactions[i]
  }
  
  func removeTransaction(inDay day: Int, withIndex transactionIndex: Int) {
    let indexToRemove = index.days[day].first + transactionIndex
    transactions.remove(at: indexToRemove)
    
    if index.days[day].length == 1 { // we deleted the last transaction for this day
      rebuiltIndexAndNotify()
    } else {
      rebuiltIndexAndNotify(aboutDays: [day])
    }
  }
  
  func updateNameInTransactionsFromThisDevice(toNewName name: String) {
//    for transaction in transactions {
      // FIXME
//      if transaction.isCreatedOnCurrentDevice {
//        transaction.authorName = name
//        transaction.modifiedDate = Date()
//      }
//    }
//    rebuiltIndexAndNotify()
  }
  
  private func rebuiltIndexAndNotify(aboutDays days: [Int]? = nil) {
    index = buildTableIndex(transactions)
    if let days = days {
      presentor?.didUpdate(days: days)
    } else {
      presentor?.didUpdateAll()
    }
    storeManager.save(transactions: transactions)
  }
  
  private func buildTableIndex(_ transactions: [Transaction]) -> TransactionsIndex {
    var index = TransactionsIndex()
    guard transactions.count > 0 else { return index }
    
    var lastDayDate = transactions[0].date
    var daySectionFirst = 0
    var lastMonthDate = transactions[0].date
    var monthSectionFirst = 0
    
    for (i, t) in transactions.enumerated() {
      if i == 0 { continue }
      
      if !Calendar.current.isDate(lastDayDate, inSameDayAs: t.date) {
        let daySection = CalendarSection(first: daySectionFirst, length: i - daySectionFirst)
        index.days.append(daySection)
        daySectionFirst = i
        lastDayDate = t.date
        
        if !Calendar.current.isDate(lastMonthDate, equalTo: t.date, toGranularity: .month) {
          let monthSection = CalendarSection(first: monthSectionFirst, length: i - monthSectionFirst)
          index.months.append(monthSection)
          monthSectionFirst = i
          lastMonthDate = t.date
        }
      }
    }
    
    let daySection = CalendarSection(first: daySectionFirst, length: transactions.count - daySectionFirst)
    index.days.append(daySection)
    let monthSection = CalendarSection(first: monthSectionFirst, length: transactions.count - monthSectionFirst)
    index.months.append(monthSection)
    return index
  }
  
  private func insertWithSort(transaction newTransaction: Transaction) {
    for (i, transaction) in transactions.enumerated() {
      if newTransaction.date < transaction.date {
        transactions.insert(newTransaction, at: i)
        return
      }
    }
    transactions.insert(newTransaction, at: transactions.count)
  }
}

extension TransactionsController: TransactionUpdateDelegate {
  func add(transaction: Transaction) {
    insertWithSort(transaction: transaction)
    rebuiltIndexAndNotify()
  }
  
  func update(transaction: Transaction) {
    guard let transactionIndex = transactions.index(where: { $0.hash == transaction.hash }) else { return }
    transactions[transactionIndex] = transaction
    
    for (i, daySection) in index.days.enumerated() {
      if transactionIndex < daySection.firstOfNext {
        rebuiltIndexAndNotify(aboutDays: [i])
        break
      }
    }
  }
}

extension TransactionsController: MergeDelegate {
  func mergeDone(updatedTransactions transactions: [Transaction]) {
    self.transactions = transactions
    rebuiltIndexAndNotify()
  }
}

// CSV export / import
extension TransactionsController {
  private var dateFormatString: String {
    return "yyyy-MM-dd_HH:mm:ss.SSS"
  }
  
  func exportDataAsCSV() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = dateFormatString
    
    var csv = "transaction date;creation date;author;category;amount\n"
    for t in transactions {
      let createdDate = dateFormatter.string(from: t.createdDate)
      let transactionDate = dateFormatter.string(from: t.date)
      csv += "\(transactionDate);\(createdDate);\(t.authorName);\(t.category.name);\(t.amount)\n"
    }
    return csv
  }
  
  enum ImportMode {
    case merge
    case replace
  }
  
  enum ImportResult {
    case success(String)
    case failure(String)
    
    var title: String {
      switch self {
      case .success:
        return "Import finished"
      case .failure:
        return "Import failed"
      }
    }
    
    var message: String {
      switch self {
      case .success(let text):
        return text
      case .failure(let text):
        return text
      }
    }
  }
  
  func importDataFromCSV(csv: String?, mode: ImportMode) -> ImportResult {
    let failureResult = ImportResult.failure("""
        Incorrect CSV format.
        Export your existing data to have an example.
    """)
    guard let csv = csv else { return failureResult }
    
    var importedTransactions = [Transaction]()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = dateFormatString
    for (i, line) in csv.components(separatedBy: "\n").enumerated() {
      if i == 0 { continue } // Skip title line
      guard line.count > 0 else { continue }
      let components = line.components(separatedBy: ";")
      guard components.count == 5 else { return failureResult }
      let author = components[2]
      let categoryName = components[3]
      guard let transactionDate = dateFormatter.date(from: components[0]),
        let creationDate = dateFormatter.date(from: components[1]),
        author.count > 0,
        let category = TransactionCategory(name: categoryName),
        let amount = Float(components[4]),
        amount > 0
        else { continue }
      
      let transaction = Transaction(amount: amount, category: category, authorName: author,
                                    transactionDate: transactionDate, creationDate: creationDate)
      importedTransactions.append(transaction)
    }
    guard importedTransactions.count > 0 else { return failureResult }
    
    switch mode {
    case .merge:
      transactions = Merger().merge(local: transactions, remote: importedTransactions, previousSyncTransactions: [])
    case .replace:
      transactions = importedTransactions.sorted { $0.date < $1.date }
    }
    rebuiltIndexAndNotify()
    return .success("Successfully imported \(importedTransactions.count) transactions")
  }
}
