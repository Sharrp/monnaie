//
//  DataServiceTests.swift
//  monnaieTests
//
//  Created by Anton Vronskii on 2018/05/19.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import XCTest

class DataServiceTests: XCTestCase {
  var dataProvider: DataService!
  
  let calendar = Calendar(identifier: .gregorian)
  var currentMonth: Int!
  var currentYear: Int!
  var yearOfPreviousMonth: Int!
  var previousMonth: Int!
  let previousMonthDay = 28
  var testingDays = [Date]()
  
  override func setUp() {
    super.setUp()
    
    dataProvider = DataService(dbName: "testing")
    
    currentMonth = calendar.component(.month, from: Date.now)
    currentYear =  calendar.component(.year, from: Date.now)
    let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: Date.now)!
    previousMonth = calendar.component(.month, from: previousMonthDate)
    yearOfPreviousMonth = calendar.component(.year, from: previousMonthDate)
    
    let data = [
      [[currentYear, currentMonth, 3], TransactionCategory.cafe, "Jimmy", 1026],
      [[currentYear, currentMonth, 3], TransactionCategory.grocery, "Jimmy", 800],
      [[currentYear, currentMonth, 3], TransactionCategory.cafe, "Leya", 2400],
      
      [[currentYear, currentMonth, 1], TransactionCategory.grocery, "Jimmy", 430],
      [[currentYear, currentMonth, 1], TransactionCategory.bills, "Jimmy", 88],
      [[currentYear, currentMonth, 1], TransactionCategory.grocery, "Leya", 2040],
      [[currentYear, currentMonth, 1], TransactionCategory.grocery, "Jimmy", 1000],
      
      [[yearOfPreviousMonth, previousMonth, previousMonthDay], TransactionCategory.grocery, "Leya", 1156],
      [[yearOfPreviousMonth, previousMonth, previousMonthDay], TransactionCategory.grocery, "Leya", 1900],
      
      [[currentYear, currentMonth, 4], TransactionCategory.bills, "Leya", 1170]
    ]
    
    data.forEach {
      let dateValues = $0[0] as! [Int]
      let nanoseconds = Int((Date.now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)) * 1e9)
      let date = Date(calendar: calendar, year: dateValues[0], month: dateValues[1], day: dateValues[2], nanoseconds: nanoseconds)!
      
      let dayDate = Date(calendar: calendar, year: dateValues[0], month: dateValues[1], day: dateValues[2])!
      if !testingDays.contains(where: { dayDate.isSame(.day, asDate: $0) }) {
        testingDays.append(date)
      }
      
      let amount = Double($0[3] as! Int)
      let category = $0[1] as! TransactionCategory
      let name = $0[2] as! String
      
      let transaction = Transaction(amount: amount, category: category, authorName: name, transactionDate: date)
      dataProvider.add(transaction: transaction)
    }
    testingDays.sort()
  }

  override func tearDown() {
    dataProvider.removeDB()
  }
  
  func testOldestTransactionDate() {
    guard let oldestDate = dataProvider.oldestTransactionDate() else { XCTFail(); return }
    XCTAssertEqual(yearOfPreviousMonth, Calendar.current.component(.year, from: oldestDate))
    XCTAssertEqual(previousMonth, Calendar.current.component(.month, from: oldestDate))
    XCTAssertEqual(previousMonthDay, Calendar.current.component(.day, from: oldestDate))
  }
  
  func testNonEmptyDays() {
    let previousMonthNonEmptyDays = dataProvider.daysWithTransactions(forMonth: testingDays[0])
    XCTAssertEqual(previousMonthNonEmptyDays.count, 1)
    XCTAssertEqual(previousMonthNonEmptyDays[0], previousMonthDay)
    
    let currentMonthNonEmptyDays = dataProvider.daysWithTransactions(forMonth: testingDays[1])
    XCTAssertEqual(currentMonthNonEmptyDays.count, 3)
    let expectedDays = [1, 3, 4]
    for (i, day) in expectedDays.enumerated() {
      XCTAssertEqual(currentMonthNonEmptyDays[i], day)
    }
  }
  
  func testNumberOfTransactions() {
    let expectedCounts = [2, 4, 3, 1]
    for (i, date) in testingDays.enumerated() {
      XCTAssertEqual(expectedCounts[i], dataProvider.numberOfTransactions(onDay: date))
    }
    XCTAssertEqual(0, dataProvider.numberOfTransactions(onDay: Date(calendar: calendar, year: currentYear, month: currentMonth, day: 2)!))
  }

  func testTotalMonthAmount() {
    XCTAssertEqual(3056, dataProvider.totalAmount(forMonth: testingDays.first!))
    XCTAssertEqual(8954, dataProvider.totalAmount(forMonth: testingDays.last!))
    XCTAssertEqual(0, dataProvider.totalAmount(forMonth: Date.distantPast))
  }
  
  func testTotalDayAmount() {
    let expectedAmounts: [Double] = [3056, 3558, 4226, 1170]
    for (i, date) in testingDays.enumerated() {
      XCTAssertEqual(expectedAmounts[i], dataProvider.totalAmount(forDay: date))
    }
    XCTAssertEqual(0, dataProvider.totalAmount(forDay: Date.distantPast))
  }
  
  func testGetTransaction() {
    guard let t1 = dataProvider.transaction(index: 0, forDay: testingDays[1]) else { XCTFail(); return }
    XCTAssertEqual(t1.category, .grocery)
    XCTAssertEqual(t1.authorName, "Jimmy")
    XCTAssertEqual(t1.amount, 430.0)
    
    guard let t2 = dataProvider.transaction(index: 2, forDay: testingDays[2]) else { XCTFail(); return }
    XCTAssertEqual(t2.category, .cafe)
    XCTAssertEqual(t2.authorName, "Leya")
    XCTAssertEqual(t2.amount, 2400.0)
    
    XCTAssertNil(dataProvider.transaction(index: 12402, forDay: testingDays[0]))
    XCTAssertNil(dataProvider.transaction(index: 0, forDay: Date.distantPast))
  }
  
  func testUpdateTransaction() {
    let testingTransaction = { [unowned self] in
      return self.dataProvider.transaction(index: 2, forDay: self.testingDays[1])
    }
    
    guard var t1 = testingTransaction() else { XCTFail(); return }
    let newAmount = 112.0
    let newCategory = TransactionCategory.entertainment
    t1.amount = newAmount
    t1.category = newCategory
    dataProvider.update(transaction: t1)
    
    guard let t2 = testingTransaction() else { XCTFail(); return }
    XCTAssertEqual(t2.category, newCategory)
    XCTAssertEqual(t2.amount, newAmount)
    
    let newAuthor = "Jackie Chan"
    t1.authorName = newAuthor
    dataProvider.update(transaction: t1)
    guard let t3 = testingTransaction() else { XCTFail(); return }
    XCTAssertEqual(t3.authorName, newAuthor)
    
    let day0Transaction0 = dataProvider.transaction(index: 0, forDay: testingDays[0])!
    t1.date = Date(timeInterval: 3600, since: day0Transaction0.date)
    dataProvider.update(transaction: t1)
    XCTAssertEqual(3, dataProvider.numberOfTransactions(onDay: day0Transaction0.date))
    let t1MovedToNewDay = dataProvider.transaction(index: 2, forDay: testingDays[0])
    XCTAssertEqual(t1, t1MovedToNewDay)
  }
  
  func testRemoveTransaction() {
    let indexesToRemove = [0, 2, 2, 0]
    for (i, date) in testingDays.enumerated() {
      let index = indexesToRemove[i]
      guard let transaction = dataProvider.transaction(index: index, forDay: date) else { XCTFail(); return }
      let initialTransactionsCount = dataProvider.numberOfTransactions(onDay: date)
      let initialDayAmount = dataProvider.totalAmount(forDay: date)
      dataProvider.remove(transaction: transaction)
      XCTAssertEqual(initialTransactionsCount - 1, dataProvider.numberOfTransactions(onDay: date))
      XCTAssertEqual(initialDayAmount - transaction.amount, dataProvider.totalAmount(forDay: date))
    }
  }
  
  func testMonthlyReport() {
    let expectedAmounts: [Double] = [3056, 8954]
    let expectedYears = [yearOfPreviousMonth, currentYear]
    let expectedMonths = [previousMonth, currentMonth]
    let reports = dataProvider.monthlyAmounts()
    XCTAssertEqual(reports.count, expectedAmounts.count)
    for (i, report) in reports.enumerated() {
      XCTAssertEqual(report.amount, expectedAmounts[i])
      let givenYear = Calendar.current.component(.year, from: report.monthDate)
      XCTAssertEqual(givenYear, expectedYears[i])
      let givenMonth = Calendar.current.component(.month, from: report.monthDate)
      XCTAssertEqual(givenMonth, expectedMonths[i])
    }
  }
  
  func testSummary() {
    let categories: [TransactionCategory] = [.grocery, .cafe, .bills]
    let totalAmount = [4270.0, 3426, 1258]
    let summary = dataProvider.categoriesSummary(forMonth: testingDays.last!)
    XCTAssertEqual(summary.count, categories.count)
    for (i, category) in categories.enumerated() {
      XCTAssertEqual(category, summary[i].category)
      XCTAssertEqual(totalAmount[i], summary[i].amount)
    }
  }
}
