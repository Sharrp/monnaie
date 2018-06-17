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

class TransactionsController {
  private let storeManager = StoreManager()
  private var transactions: [Transaction]
  private var index: TransactionsIndex!
  weak var presentor: TransactionsPresentor?
  
  init() {
    transactions = storeManager.loadTransactions().sorted { $0.date < $1.date }
    index = buildTableIndex(transactions)
  }
  
  // For unit-tests
  init(withTransactions transactions: [Transaction]) {
    self.transactions = transactions.sorted { $0.date < $1.date }
    index = buildTableIndex(transactions)
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
    for transaction in transactions {
      if transaction.isCreatedOnCurrentDevice {
        transaction.authorName = name
        transaction.modifiedDate = Date()
      }
    }
    rebuiltIndexAndNotify()
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
    guard let transactionIndex = transactions.index(where: { $0.hashValue == transaction.hashValue }) else { return }
    transactions[transactionIndex] = transaction
    
    for (i, daySection) in index.days.enumerated() {
      if transactionIndex < daySection.firstOfNext {
        rebuiltIndexAndNotify(aboutDays: [i])
        break
      }
    }
  }
}

extension TransactionsController: SyncUpdateDelegate {
  func reset(transactionsTo transactions: [Transaction]) {
    self.transactions = transactions
    rebuiltIndexAndNotify()
  }
}
