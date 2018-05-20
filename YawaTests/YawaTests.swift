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

  override func setUp() {
    super.setUp()
    
    let data = [
      [[2018, 5, 3], TransactionCategory.cafe, "Jimmy", 1026],
      [[2018, 5, 3], TransactionCategory.grocery, "Jimmy", 800],
      [[2018, 5, 3], TransactionCategory.cafe, "Leya", 2400],
      
      [[2018, 5, 1], TransactionCategory.grocery, "Jimmy", 430],
      [[2018, 5, 1], TransactionCategory.bills, "Jimmy", 88],
      [[2018, 5, 1], TransactionCategory.grocery, "Leya", 2040],
      [[2018, 5, 1], TransactionCategory.grocery, "Jimmy", 1000],
      
      [[2018, 4, 30], TransactionCategory.grocery, "Leya", 1156],
      [[2018, 4, 30], TransactionCategory.grocery, "Leya", 1900]
    ]
    
    let transactions: [Transaction] = data.map {
      var dateComponents = DateComponents()
      let dateValues = $0[0] as! [Int]
      dateComponents.year = dateValues[0]
      dateComponents.month = dateValues[1]
      dateComponents.day = dateValues[2]
      let date = Calendar(identifier: .gregorian).date(from: dateComponents)!
      
      let amount = Float($0[3] as! Int)
      let category = $0[1] as! TransactionCategory
      let name = $0[2] as! String
      
      return Transaction(amount: amount, category: category, author: name, date: date, comment: nil)
    }
    dataProvider = TransactionsController(withTransactions: transactions)
  }

  override func tearDown() {
    super.tearDown()
  }
  
  func testDaysCount() {
    XCTAssert(dataProvider.numberOfDays == 3, "Wrong numberOfDays in TransactionsController")
  }
  
  func testTransactionsCount() {
    XCTAssert(dataProvider.numberOfTransactions(forDay: 0) == 3, "Wrong number of transactions for day 0")
    XCTAssert(dataProvider.numberOfTransactions(forDay: 1) == 4, "Wrong number of transactions for day 1")
    XCTAssert(dataProvider.numberOfTransactions(forDay: 2) == 2, "Wrong number of transactions for day 2")
  }
  
  func testDailyAmount() {
    let totalAmounts: [Float] = [4226, 3558, 3056]
    for (i, amount) in totalAmounts.enumerated() {
      XCTAssert(dataProvider.totalAmount(forDay: i) == amount, "Wrong amount for day \(i)")
    }
  }
  
  func testCurrentMonthAmount() {
    XCTAssert(dataProvider.totalAmountForCurrentMonth() == 7784, "Wrong current month total amount")
  }
  
  func testDaysDeterminedCorrectly() {
    let dates: [Date] = [
      [2018, 5, 3],
      [2018, 5, 1],
      [2018, 4, 30]
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
}
