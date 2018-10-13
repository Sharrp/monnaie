//
//  YawaMergerTests.swift
//  YawaTests
//
//  Created by Anton Vronskii on 2018/10/13.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import XCTest

func ==(lhs: [Transaction], rhs: [Transaction]) -> Bool {
  guard lhs.count == rhs.count else { return false }
  for i in 0..<lhs.count {
    if lhs[i] != rhs[i] { return false }
  }
  return true
}

class YawaMergerTests: XCTestCase {
  private let local = TransactionsController()
  private let localAuthor = "Местный"
  private let remote = TransactionsController()
  private let remoteAuthor = "Дальний"
  private let expected = TransactionsController() // used sometimes to load expected results from CSV
  private let merger = Merger()
  private var previousSync: [Int]!
  
  private func importCSV(fileName: String, intoControlller controller: TransactionsController) {
    guard let path = Bundle(for: type(of: self)).path(forResource: fileName, ofType: "csv") else { XCTFail(); return }
    guard let csv = try? String(contentsOfFile: path) else { XCTFail(); return }
    let result = controller.importDataFromCSV(csv: csv, mode: .replace)
    switch result {
    case .success:
      break
    case .failure(let message):
      XCTFail("Unsuccessful import of \(fileName).csv: \(message)")
    }
  }

  override func setUp() {
    importCSV(fileName: "initial", intoControlller: local)
    importCSV(fileName: "initial", intoControlller: remote)
    previousSync = local.transactions.map{ $0.hash }
  }

  override func tearDown() {
      // Put teardown code here. This method is called after the invocation of each test method in the class.
  }
  
  // MARK: Trivial cases

  func testLocalInitiatedProperly() {
    XCTAssert(local.transactions.count == 5, "Wrong number of transactions in local controller")
  }
  
  func testBothAreEmpty() {
    let merged = Merger().merge(local: [], remote: [], previousSyncTransactions: [])
    XCTAssert(merged.count == 0)
  }
  
  func testRemoteIsEmpty() {
    let merged = Merger().merge(local: local.transactions, remote: [], previousSyncTransactions: [])
    XCTAssert(merged == local.transactions)
  }
  
  func testLocalIsEmpty() {
    let merged = Merger().merge(local: [], remote: remote.transactions, previousSyncTransactions: [])
    XCTAssert(merged == remote.transactions)
  }
  
  func testNoChangesSinceLastSync() {
    let merged = Merger().merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    XCTAssert(merged == local.transactions)
  }
  
  // MARK: Atomic changes
  
  func testCreatedLocal() {
    let newTransaction = Transaction(amount: 12, category: .cafe, authorName: localAuthor, transactionDate: Date())
    local.add(transaction: newTransaction)
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    XCTAssert(merged == local.transactions)
  }
  
  func testCreatedRemote() {
    let newTransaction = Transaction(amount: 12, category: .cafe, authorName: remoteAuthor, transactionDate: Date())
    remote.add(transaction: newTransaction)
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    XCTAssert(merged == remote.transactions)
  }
  
  func testCreatedBoth() {
    let newLocalTransaction = Transaction(amount: 12, category: .cafe, authorName: localAuthor, transactionDate: Date(), creationDate: Date(timeIntervalSinceNow: -1200))
    let newRemoteTransaction = Transaction(amount: 23, category: .entertainment, authorName: remoteAuthor, transactionDate: Date(), creationDate: Date())
    local.add(transaction: newLocalTransaction)
    remote.add(transaction: newRemoteTransaction)
    
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    var expectedTransactions = local.transactions
    expectedTransactions.append(newRemoteTransaction)
    XCTAssert(merged == expectedTransactions)
  }
  
  func testUpdatedLocal() {
    Thread.sleep(forTimeInterval: 0.01) // so we will have different modifiedDate
    let index = 2
    let transaction = local.transactions[index]
    transaction.amount += 200
    let expectedAmount = transaction.amount
    local.update(transaction: transaction)
    
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    XCTAssert(merged == local.transactions)
    XCTAssert(merged[index].amount == expectedAmount)
  }
  
  func testUpdatedRemote() {
    Thread.sleep(forTimeInterval: 0.01)
    let index = 3
    let transaction = remote.transactions[index]
    let newCategory = TransactionCategory.bills
    XCTAssert(transaction.category != newCategory)
    transaction.category = newCategory
    remote.update(transaction: transaction)
    
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    XCTAssert(merged == remote.transactions)
    XCTAssert(merged[index].category == newCategory)
  }
  
  // Remote and location devices change different transactions
  func testUpdatedBoth() {
    Thread.sleep(forTimeInterval: 0.01)
    let localTransaction = local.transactions[4]
    localTransaction.date = localTransaction.date.addingTimeInterval(-3600)
    local.update(transaction: localTransaction)
    
    let remoteTransaction = remote.transactions[1]
    remoteTransaction.date = remoteTransaction.date.addingTimeInterval(2 * 86400)
    remote.update(transaction: remoteTransaction)
    
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    
    importCSV(fileName: "updated-both", intoControlller: expected)
    XCTAssert(merged == expected.transactions)
  }
  
  func testDeletedLocal() {
    local.removeTransaction(inDay: 0, withIndex: 0)
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    XCTAssert(merged == local.transactions)
    XCTAssert(local.transactions != remote.transactions)
  }
  
  func testDeletedRemote() {
    remote.removeTransaction(inDay: 1, withIndex: 0)
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    XCTAssert(merged == remote.transactions)
    XCTAssert(local.transactions != remote.transactions)
  }
  
  // Remote and location devices delete different transactions
  func testeDeletedBoth() {
    local.removeTransaction(inDay: 0, withIndex: 1)
    remote.removeTransaction(inDay: 1, withIndex: 0)
    XCTAssert(local.transactions != remote.transactions)
    
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    importCSV(fileName: "deleted-both", intoControlller: expected)
    XCTAssert(merged == expected.transactions)
  }
  
  // MARK: Conflicts
  // Remote and location devices make operations on the same transaction
  
  func testConflictUpdatedBoth() {
    let index = 0
    Thread.sleep(forTimeInterval: 0.01)
    let localTransaction = local.transactions[index]
    localTransaction.date = localTransaction.date.addingTimeInterval(-1200)
    local.update(transaction: localTransaction)
    
    Thread.sleep(forTimeInterval: 0.01) // so the remote version is newer and we expect it in merged list
    let remoteTransaction = remote.transactions[index]
    let expectedDate = remoteTransaction.date.addingTimeInterval(-5000)
    remoteTransaction.date = expectedDate
    remote.update(transaction: remoteTransaction)
    XCTAssert(local.transactions[index].date != remote.transactions[index].date)
    
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    XCTAssert(merged == remote.transactions)
    XCTAssert(merged[index].date == expectedDate)
  }
  
  func testeConflictDeletedBoth() {
    local.removeTransaction(inDay: 0, withIndex: 1)
    remote.removeTransaction(inDay: 0, withIndex: 1)
    XCTAssert(local.transactions == remote.transactions)
    
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    XCTAssert(merged == local.transactions)
  }
  
  func testConflictLocalUpdateRemoteDelete() {
    let transaction = local.transaction(forDay: 0, withIndex: 1)
    transaction.amount += 200
    local.update(transaction: transaction)
    remote.removeTransaction(inDay: 0, withIndex: 1)
    
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    XCTAssert(merged == remote.transactions)
  }
  
  func testConflictLocalDeleteRemoteUpdate() {
    local.removeTransaction(inDay: 1, withIndex: 0)
    let transaction = remote.transaction(forDay: 1, withIndex: 0)
    transaction.amount += 200
    remote.update(transaction: transaction)
    
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    XCTAssert(merged == local.transactions)
  }
  
  // MARK: Real-life cases
  
  func testInitialNoCollision() {
    importCSV(fileName: "real-life-initial-remote", intoControlller: remote)
    importCSV(fileName: "real-life-no-collision", intoControlller: expected)
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: [])
    XCTAssert(merged == expected.transactions)
  }
  
  func testRealLifeComplex() {
    // Add
    let newLocalDate = local.transactions[1].date.addingTimeInterval(86400 - 2 * 3600)
    let newLocalTransaction = Transaction(amount: 10, category: .grocery, authorName: localAuthor, transactionDate: newLocalDate, creationDate: newLocalDate)
    local.add(transaction: newLocalTransaction)
    
    let newRemoteDate = remote.transactions[3].date.addingTimeInterval(3 * 3600)
    let newRemoteTransaction = Transaction(amount: 200, category: .other, authorName: remoteAuthor, transactionDate: newRemoteDate, creationDate: newRemoteDate)
    remote.add(transaction: newRemoteTransaction)
    
    // Update
    Thread.sleep(forTimeInterval: 0.01)
    var localTransaction = local.transactions[0]
    localTransaction.amount = 30
    local.update(transaction: localTransaction)
    
    localTransaction = local.transactions[1]
    localTransaction.category = .grocery
    local.update(transaction: localTransaction)
    
    Thread.sleep(forTimeInterval: 0.01)
    var remoteTransaction = remote.transactions[1]
    remoteTransaction.amount = 45
    remote.update(transaction: remoteTransaction)
    
    remoteTransaction = remote.transactions[3]
    remoteTransaction.category = .entertainment
    remote.update(transaction: remoteTransaction)
    
    // Delete
    local.removeTransaction(inDay: 2, withIndex: 1)
    remote.removeTransaction(inDay: 0, withIndex: 2)
    
    importCSV(fileName: "real-life-complex", intoControlller: expected)
    let merged = merger.merge(local: local.transactions, remote: remote.transactions, previousSyncTransactions: previousSync)
    XCTAssert(merged == expected.transactions)
  }
}
