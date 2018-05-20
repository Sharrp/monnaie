//
//  TransactionsController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/19.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation

private struct DaySection {
  let first: Int
  let length: Int
  
  var firstOfNext: Int {
    return first + length
  }
}

protocol TransactionsPresentor: AnyObject {
  func didUpdate(days: [Int])
  func didUpdateTransactions(atIndexPaths indexPaths: [IndexPath])
  func didUpdateAll()
}

class TransactionsController {
  private let storeManager = StoreManager()
  private var transactions: [Transaction]
  private var daysIndex = [DaySection]() // each item is the first transaction in its day
  weak var presentor: TransactionsPresentor?
  
  init() {
    transactions = storeManager.loadTransactions()
    daysIndex = buildTableIndex(transactions)
  }
  
  // For unit-tests
  init(withTransactions transactions: [Transaction]) {
    self.transactions = transactions.sorted { $0.date > $1.date }
    daysIndex = buildTableIndex(transactions)
  }
  
  var numberOfDays: Int {
    return daysIndex.count
  }
  
  func date(forDay day: Int) -> Date {
    let transactionIndex = daysIndex[day].first
    return transactions[transactionIndex].date
  }
  
  func numberOfTransactions(forDay day: Int) -> Int {
    return daysIndex[day].length
  }
  
  func totalAmount(forDay day: Int) -> Float {
    let daySection = daysIndex[day]
    let indexRange = daySection.first..<daySection.firstOfNext
    return transactions[indexRange].reduce(0.0) { $0 + $1.amount }
  }
  
  func totalAmountForCurrentMonth() -> Float {
    let thisMonthTransactions = transactions.filter { Calendar.current.isDate($0.date, equalTo: transactions[0].date, toGranularity: .month) }
    return thisMonthTransactions.reduce(0) { $0 + $1.amount }
  }
  
  var syncTransactions: [Transaction] {
    return transactions
  }
  
  func transaction(forDay day: Int, withIndex transactionIndex: Int) -> Transaction {
    let index = daysIndex[day].first + transactionIndex
    return transactions[index]
  }
  
  func removeTransaction(inDay day: Int, withIndex transactionIndex: Int) {
    let index = daysIndex[day].first + transactionIndex
    transactions.remove(at: index)
    rebuiltIndexAndNotify(aboutDays: [day])
  }
  
  func updateNameInTransactionsFromThisDevice(toNewName name: String) {
//    rebuiltIndexAndNotify()
  }
  
  private func rebuiltIndexAndNotify(aboutDays days: [Int]? = nil) {
    daysIndex = buildTableIndex(transactions)
    if let days = days {
      presentor?.didUpdate(days: days)
    } else {
      presentor?.didUpdateAll()
    }
    storeManager.save(transactions: transactions)
  }
  
  private func buildTableIndex(_ transactions: [Transaction]) -> [DaySection] {
    var index = [DaySection]()
    var lastDay = Date.distantFuture
    var sectionFirstIndex = -1
    for (i, t) in transactions.enumerated() {
      if !Calendar.current.isDate(lastDay, inSameDayAs: t.date) {
        if sectionFirstIndex != -1 {
          let newSection = DaySection(first: sectionFirstIndex, length: i-sectionFirstIndex)
          index.append(newSection)
        }
        sectionFirstIndex = i
        lastDay = t.date
      }
    }
    if transactions.count > 0 {
      let newSection = DaySection(first: sectionFirstIndex, length: transactions.count-sectionFirstIndex)
      index.append(newSection)
    }
    return index
  }
  
  private func insertWithSort(transaction newTransaction: Transaction) {
    for (i, transaction) in transactions.enumerated() {
      if newTransaction.date > transaction.date {
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
    
    for (i, daySection) in daysIndex.enumerated() {
      if transactionIndex < daySection.firstOfNext {
        rebuiltIndexAndNotify(aboutDays: [i])
      }
    }
  }
}

extension TransactionsController: SyncUpdateDelegate {
  func reset(transactionsTo transactions: [Transaction]) {
    self.transactions = transactions
  }
}
