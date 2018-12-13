//
//  MergerTests.swift
//  monnaieTests
//
//  Created by Anton Vronskii on 2018/10/13.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import XCTest

class MergerTests: XCTestCase {
  private var local: DataService!
  private let localAuthor = "Localler"
  private var remote: DataService!
  private let remoteAuthor = "Remoter"
  private var expected: DataService! // used sometimes to load expected results from CSV
  private let merger = Merger()
  private var previousSync: [Int]!
  
  func importCSV(fileName: String, intoControlller controller: DataService) {
    monnaieTests.importCSV(bundle: Bundle(for: type(of: self)), fileName: fileName, intoControlller: controller)
  }

  override func setUp() {
    local = DataService(dbName: "local")
    remote = DataService(dbName: "remote")
    expected = DataService(dbName: "expected")
    
    importCSV(fileName: "initial", intoControlller: local)
    importCSV(fileName: "initial", intoControlller: remote)
    previousSync = local.syncTransactions().map{ $0.hash }
  }

  override func tearDown() {
    local.removeDB()
    remote.removeDB()
    expected.removeDB()
  }
  
  // MARK: Trivial cases

  func testLocalInitiatedProperly() {
    XCTAssert(local.syncTransactions().count == 5, "Wrong number of transactions in local controller")
  }
  
  func testBothAreEmpty() {
    let merged = Merger().merge(local: [], remote: [], previousSyncTransactions: [])
    XCTAssert(merged.count == 0)
  }
  
  func testRemoteIsEmpty() {
    let merged = Merger().merge(local: local.syncTransactions(), remote: [], previousSyncTransactions: [])
    XCTAssert(merged == local.syncTransactions())
  }
  
  func testLocalIsEmpty() {
    let merged = Merger().merge(local: [], remote: remote.syncTransactions(), previousSyncTransactions: [])
    XCTAssert(merged == remote.syncTransactions())
  }
  
  func testNoChangesSinceLastSync() {
    let merged = Merger().merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    XCTAssert(merged == local.syncTransactions())
  }
  
  // MARK: Atomic changes
  
  func testCreatedLocal() {
    let newTransaction = Transaction(amount: 12, category: .cafe, authorName: localAuthor, transactionDate: Date.now)
    local.add(transaction: newTransaction)
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    XCTAssert(merged == local.syncTransactions())
  }
  
  func testCreatedRemote() {
    let newTransaction = Transaction(amount: 12, category: .cafe, authorName: remoteAuthor, transactionDate: Date.now)
    remote.add(transaction: newTransaction)
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    XCTAssert(merged == remote.syncTransactions())
  }
  
  func testCreatedBoth() {
    let newLocalDate = Date(timeIntervalSinceNow: -1200)
    let newLocalTransaction = Transaction(amount: 12, category: .cafe, authorName: localAuthor, transactionDate: newLocalDate, creationDate: newLocalDate)
    let newRemoteDate = Date.now
    let newRemoteTransaction = Transaction(amount: 23, category: .entertainment, authorName: remoteAuthor, transactionDate: newRemoteDate, creationDate: newRemoteDate)
    local.add(transaction: newLocalTransaction)
    remote.add(transaction: newRemoteTransaction)
    
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    var expectedTransactions = local.syncTransactions()
    expectedTransactions.append(newRemoteTransaction)
    XCTAssert(merged == expectedTransactions)
  }
  
  func testUpdatedLocal() {
    Thread.sleep(forTimeInterval: 0.01) // so we will have different modifiedDate
    let index = 2
    let transaction = local.syncTransactions()[index]
    transaction.amount += 200
    let expectedAmount = transaction.amount
    local.update(transaction: transaction)
    
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    XCTAssert(merged == local.syncTransactions())
    XCTAssert(merged[index].amount == expectedAmount)
  }
  
  func testUpdatedRemote() {
    Thread.sleep(forTimeInterval: 0.01)
    let index = 3
    let transaction = remote.syncTransactions()[index]
    let newCategory = TransactionCategory.bills
    XCTAssert(transaction.category != newCategory)
    transaction.category = newCategory
    remote.update(transaction: transaction)
    
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    XCTAssert(merged == remote.syncTransactions())
    XCTAssert(merged[index].category == newCategory)
  }
  
  // Remote and location devices change different transactions
  func testUpdatedBoth() {
    Thread.sleep(forTimeInterval: 0.01)
    let localTransaction = local.syncTransactions()[4]
    localTransaction.date = localTransaction.date.addingTimeInterval(-3600)
    local.update(transaction: localTransaction)
    
    let remoteTransaction = remote.syncTransactions()[1]
    remoteTransaction.date = remoteTransaction.date.addingTimeInterval(2 * Date.secondsPerDay)
    remote.update(transaction: remoteTransaction)
    
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    
    importCSV(fileName: "updated-both", intoControlller: expected)
    XCTAssert(merged == expected.syncTransactions())
  }
  
  func testDeletedLocal() {
    guard let transaction = local.transaction(withIndex: 0, forDayIndex: 0) else { XCTFail(); return }
    local.remove(transaction: transaction)
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    XCTAssert(merged == local.syncTransactions())
    XCTAssertNotEqual(local.syncTransactions(), remote.syncTransactions())
  }
  
  func testDeletedRemote() {
    let secondDay = remote.allDates(ofGranularity: .day)[1]
    guard let transaction = remote.transaction(index: 0, forDay: secondDay) else { XCTFail(); return }
    remote.remove(transaction: transaction)
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    XCTAssert(merged == remote.syncTransactions())
    XCTAssert(local.syncTransactions() != remote.syncTransactions())
  }
  
  // Remote and location devices deleted different transactions
  func testeDeletedBoth() {
    guard let localTranscation = local.transaction(withIndex: 1, forDayIndex: 0) else { XCTFail(); return }
    guard let remoteTranscation = remote.transaction(withIndex: 0, forDayIndex: 1) else { XCTFail(); return }
    local.remove(transaction: localTranscation)
    remote.remove(transaction: remoteTranscation)
    XCTAssert(local.syncTransactions() != remote.syncTransactions())
    
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    importCSV(fileName: "deleted-both", intoControlller: expected)
    XCTAssert(merged == expected.syncTransactions())
  }
  
  // MARK: Conflicts
  // Remote and location devices make operations on the same transaction
  
  func testConflictUpdatedBoth() {
    let index = 0
    Thread.sleep(forTimeInterval: 0.01)
    let localTransaction = local.syncTransactions()[index]
    localTransaction.date = localTransaction.date.addingTimeInterval(-1200)
    local.update(transaction: localTransaction)
    
    Thread.sleep(forTimeInterval: 0.01) // so the remote version is newer and we expect it in merged list
    let remoteTransaction = remote.syncTransactions()[index]
    let expectedDate = remoteTransaction.date.addingTimeInterval(-5000)
    remoteTransaction.date = expectedDate
    remote.update(transaction: remoteTransaction)
    XCTAssert(local.syncTransactions()[index].date != remote.syncTransactions()[index].date)
    
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    XCTAssert(merged == remote.syncTransactions())
    XCTAssert(merged[index].date == expectedDate)
  }
  
  func testeConflictDeletedBoth() {
    guard let localTranscation = local.transaction(withIndex: 1, forDayIndex: 0) else { XCTFail(); return }
    guard let remoteTranscation = remote.transaction(withIndex: 1, forDayIndex: 0) else { XCTFail(); return }
    local.remove(transaction: localTranscation)
    remote.remove(transaction: remoteTranscation)
    XCTAssert(local.syncTransactions() == remote.syncTransactions())
    
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    XCTAssert(merged == local.syncTransactions())
  }
  
  func testConflictLocalUpdateRemoteDelete() {
    guard let transaction = local.transaction(withIndex: 1, forDayIndex: 0) else { XCTFail(); return }
    transaction.amount += 200
    local.update(transaction: transaction)
    remote.remove(transaction: transaction)
    
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    XCTAssert(merged == remote.syncTransactions())
  }
  
  func testConflictLocalDeleteRemoteUpdate() {
    guard let transaction = local.transaction(withIndex: 0, forDayIndex: 1) else { XCTFail(); return }
    local.remove(transaction: transaction)
    transaction.amount += 200
    remote.update(transaction: transaction)
    
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    XCTAssert(merged == local.syncTransactions())
  }
  
  // MARK: Real-life cases
  
  func testInitialNoCollision() {
    importCSV(fileName: "real-life-initial-remote", intoControlller: remote)
    importCSV(fileName: "real-life-no-collision", intoControlller: expected)
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: [])
    XCTAssert(merged == expected.syncTransactions())
  }
  
  func testRealLifeComplex() {
    // Add
    let newLocalDate = local.syncTransactions()[1].date.addingTimeInterval(Date.secondsPerDay - 2 * 3600)
    let newLocalTransaction = Transaction(amount: 10, category: .grocery, authorName: localAuthor, transactionDate: newLocalDate, creationDate: newLocalDate)
    local.add(transaction: newLocalTransaction)
    
    let newRemoteDate = remote.syncTransactions()[3].date.addingTimeInterval(3 * 3600)
    let newRemoteTransaction = Transaction(amount: 200, category: .other, authorName: remoteAuthor, transactionDate: newRemoteDate, creationDate: newRemoteDate)
    remote.add(transaction: newRemoteTransaction)
    
    // Update
    Thread.sleep(forTimeInterval: 0.01)
    var localTransaction = local.syncTransactions()[0]
    localTransaction.amount = 30
    local.update(transaction: localTransaction)
    
    localTransaction = local.syncTransactions()[1]
    localTransaction.category = .grocery
    local.update(transaction: localTransaction)
    
    Thread.sleep(forTimeInterval: 0.01)
    var remoteTransaction = remote.syncTransactions()[1]
    remoteTransaction.amount = 45
    remote.update(transaction: remoteTransaction)
    
    remoteTransaction = remote.syncTransactions()[3]
    remoteTransaction.category = .entertainment
    remote.update(transaction: remoteTransaction)
    
    // Delete
    guard let localTransactionToDelete = local.transaction(withIndex: 1, forDayIndex: 2) else { XCTFail(); return }
    guard let remoteTransactionToDelete = remote.transaction(withIndex: 2, forDayIndex: 0) else { XCTFail(); return }
    local.remove(transaction: localTransactionToDelete)
    remote.remove(transaction: remoteTransactionToDelete)
    
    importCSV(fileName: "real-life-complex", intoControlller: expected)
    let merged = merger.merge(local: local.syncTransactions(), remote: remote.syncTransactions(), previousSyncTransactions: previousSync)
    XCTAssert(merged == expected.syncTransactions())
  }
}

extension DataService {
  func transaction(withIndex index: Int, forDayIndex dayIndex: Int) -> Transaction? {
    let day = allDates(ofGranularity: .day)[dayIndex]
    return transaction(index: index, forDay: day)
  }
}
