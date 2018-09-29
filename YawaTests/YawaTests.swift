//
//  YawaTests.swift
//  YawaTests
//
//  Created by Anton Vronskii on 2018/05/19.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import XCTest

class YawaTransactionsControllerTests: XCTestCase {
  var dataProvider: TransactionsController!
  var transactions: [Transaction]!
  
  let calendar = Calendar(identifier: .gregorian)
  var currentMonth: Int!
  var currentYear: Int!
  var previousMonth: Int!
  var yearOfPreviousMonth: Int!
  
  override func setUp() {
    super.setUp()
    
    currentMonth = calendar.component(.month, from: Date())
    currentYear =  calendar.component(.year, from: Date())
    let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: Date())!
    previousMonth = calendar.component(.month, from: previousMonthDate)
    yearOfPreviousMonth = calendar.component(.year, from: previousMonthDate)
    
    let data = [
      [[yearOfPreviousMonth, previousMonth, 28], TransactionCategory.grocery, "Leya", 1156],
      [[yearOfPreviousMonth, previousMonth, 28], TransactionCategory.grocery, "Leya", 1900],
      
      [[currentYear, currentMonth, 1], TransactionCategory.grocery, "Jimmy", 430],
      [[currentYear, currentMonth, 1], TransactionCategory.bills, "Jimmy", 88],
      [[currentYear, currentMonth, 1], TransactionCategory.grocery, "Leya", 2040],
      [[currentYear, currentMonth, 1], TransactionCategory.grocery, "Jimmy", 1000],
      
      [[currentYear, currentMonth, 3], TransactionCategory.cafe, "Jimmy", 1026],
      [[currentYear, currentMonth, 3], TransactionCategory.grocery, "Jimmy", 800],
      [[currentYear, currentMonth, 3], TransactionCategory.cafe, "Leya", 2400],
      
      [[currentYear, currentMonth, 4], TransactionCategory.bills, "Leya", 1170]
    ]
    
    transactions = data.map {
      var dateComponents = DateComponents()
      let dateValues = $0[0] as! [Int]
      dateComponents.year = dateValues[0]
      dateComponents.month = dateValues[1]
      dateComponents.day = dateValues[2]
      let date = calendar.date(from: dateComponents)!
      
      let amount = Float($0[3] as! Int)
      let category = $0[1] as! TransactionCategory
      let name = $0[2] as! String
      
      return Transaction(amount: amount, category: category, authorName: name, date: date)
    }
    dataProvider = TransactionsController(withTransactions: transactions)
  }

  override func tearDown() {
    super.tearDown()
  }
  
  func testNumberOfMonths() {
    XCTAssert(dataProvider.numberOfMonths() == 2)
  }
  
  func testDaysInMonthCount() {
    var expected = 1
    var given = dataProvider.numberOfDays(inMonth: 0)
    XCTAssert(given == expected)
    
    expected = 3
    given = dataProvider.numberOfDays(inMonth: 1)
    XCTAssert(given == expected)
  }
  
  func testTotalDaysCount() {
    XCTAssert(dataProvider.totalNumberOfDays() == 4, "Wrong numberOfDays in TransactionsController")
  }
  
  func testTransactionsCount() {
    XCTAssert(dataProvider.numberOfTransactions(forDay: 0) == 2, "Wrong number of transactions for day 0")
    XCTAssert(dataProvider.numberOfTransactions(forDay: 1) == 4, "Wrong number of transactions for day 1")
    XCTAssert(dataProvider.numberOfTransactions(forDay: 2) == 3, "Wrong number of transactions for day 2")
    XCTAssert(dataProvider.numberOfTransactions(forDay: 3) == 1, "Wrong number of transactions for day 3")
  }
  
  func testTotalMonthAmount() {
    XCTAssert(dataProvider.totalAmount(forMonth: 0) == 3056)
    XCTAssert(dataProvider.totalAmount(forMonth: 1) == 8954)
  }
  
  func testDailyAmount() {
    let totalAmounts: [Float] = [3056, 3558, 4226, 1170]
    for (i, amount) in totalAmounts.enumerated() {
      let given = dataProvider.totalAmount(forDay: i)
      XCTAssert(given == amount, "testDailyAmount: \(i), \(amount) expected, \(given) given")
    }
  }
  
  func testCurrentMonthAmount() {
    XCTAssert(dataProvider.totalAmountForCurrentMonth() == 8954, "Wrong current month total amount")
  }
  
  func testDaysDeterminedCorrectly() {
    let dates: [Date] = [
      [yearOfPreviousMonth, previousMonth, 28],
      [currentYear, currentMonth, 1],
      [currentYear, currentMonth, 3],
      [currentYear, currentMonth, 4]
    ].map {
      var components = DateComponents()
      components.year = $0[0]
      components.month = $0[1]
      components.day = $0[2]
      return Calendar(identifier: .gregorian).date(from: components)!
    }
    
    for (i, date) in dates.enumerated() {
      let providerDate = dataProvider.date(forDay: i)
      XCTAssert(Calendar.current.compare(date, to: providerDate, toGranularity: .day) == .orderedSame, "Wrong day with index \(i)")
    }
  }
  
  func testConsistencyAfterRemovalTheOnlyTransactionInADay() {
    let previousDaysAmount = dataProvider.totalNumberOfDays()
    dataProvider.removeTransaction(inDay: 3, withIndex: 0)
    let given = dataProvider.totalNumberOfDays()
    let expected = previousDaysAmount - 1
    XCTAssert(given == expected, "testConsistencyAfterRemovalTheOnlyTransactionInADay: \(expected) expected, \(given) given")
  }
  
  func testCategoriesSummary() {
    let currentMonth = dataProvider.numberOfMonths() - 1
    let summary = dataProvider.categoriesSummary(forMonth: currentMonth)
    
    let expectedAmounts: [Float] = [4270, 3426, 1258]
    let expectedCategories: [TransactionCategory] = [.grocery, .cafe, .bills]
    
    XCTAssert(summary.count == expectedCategories.count, "Expected \(expectedCategories.count) categories in summary")
    for i in 0..<expectedCategories.count {
      XCTAssert(summary[i].amount == expectedAmounts[i], "Wrong amount for category \(i). Expected: \(expectedAmounts[i]), given: \(summary[i].amount)")
      XCTAssert(summary[i].category == expectedCategories[i], "Wrong category at index \(i). Expected: \(summary[i].category), given: \(expectedCategories[i])")
    }
  }
}
