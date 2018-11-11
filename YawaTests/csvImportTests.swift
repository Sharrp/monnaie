//
//  csvImportTests.swift
//  YawaTests
//
//  Created by Anton Vronskii on 2018/11/11.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import XCTest

func importCSV(bundle: Bundle, fileName: String, intoControlller controller: TransactionsController) {
  guard let path = bundle.path(forResource: fileName, ofType: "csv") else { XCTFail(); return }
  guard let csv = try? String(contentsOfFile: path) else { XCTFail(); return }
  let result = controller.importDataFromCSV(csv: csv, mode: .replace)
  switch result {
  case .success:
    break
  case .failure(let message):
    XCTFail("Unsuccessful import of \(fileName).csv: \(message)")
  }
}

class csvImportTests: XCTestCase {
  private var dataProvider: TransactionsController!
  private let monthDate = Date(timeIntervalSince1970: 1541934821) // Somewhere in November 2018
  private var testingDays: [Date]!
  private let emptyDay = Date(timeIntervalSince1970: 1541679833) // Nov 8, 2018
  
  override func setUp() {
    super.setUp()
    
    dataProvider = TransactionsController()
    importCSV(bundle: Bundle(for: type(of: self)), fileName: "csv-import", intoControlller: dataProvider)
    testingDays = dataProvider.allDates(ofGranularity: .day)
  }
  
  override func tearDown() {
    dataProvider.removeDB()
  }
  
  func testNonEmptyDays() {
    let expectedNonEmptyDays = [3, 4, 5, 11]
    let nonEmptyDays = dataProvider.daysWithTransactions(forMonth: monthDate)
    XCTAssertEqual(nonEmptyDays.count, expectedNonEmptyDays.count)
    for (i, day) in nonEmptyDays.enumerated() {
      XCTAssertEqual(day, expectedNonEmptyDays[i])
    }
  }
  
  func testOldestTransactionDate() {
    guard let oldestDate = dataProvider.oldestTransactionDate() else { XCTFail(); return }
    XCTAssertEqual(2018, Calendar.current.component(.year, from: oldestDate))
    XCTAssertEqual(10, Calendar.current.component(.month, from: oldestDate))
    XCTAssertEqual(1, Calendar.current.component(.day, from: oldestDate))
  }
  
  
  func testNumberOfTransactions() {
    let expectedCounts = [1, 1, 2, 3, 1]
    for (i, date) in testingDays.enumerated() {
      XCTAssertEqual(expectedCounts[i], dataProvider.numberOfTransactions(onDay: date))
    }
    XCTAssertEqual(0, dataProvider.numberOfTransactions(onDay: emptyDay))
  }

  func testTotalMonthAmount() {
    XCTAssertEqual(972, dataProvider.totalAmount(forMonth: testingDays.first!))
    XCTAssertEqual(8289, dataProvider.totalAmount(forMonth: testingDays.last!))
    XCTAssertEqual(0, dataProvider.totalAmount(forMonth: Date.distantPast))
  }

  func testTotalDayAmount() {
    let expectedAmounts: [Double] = [972, 972, 2088, 4249, 980]
    for (i, date) in testingDays.enumerated() {
      XCTAssertEqual(expectedAmounts[i], dataProvider.totalAmount(forDay: date))
    }
    XCTAssertEqual(0, dataProvider.totalAmount(forDay: emptyDay))
  }

  func testGetTransaction() {
    guard let t1 = dataProvider.transaction(index: 0, forDay: testingDays[1]) else { XCTFail(); return }
    XCTAssertEqual(t1.category, .grocery)
    XCTAssertEqual(t1.authorName, "Буся")
    XCTAssertEqual(t1.amount, 972.0)

    guard let t2 = dataProvider.transaction(index: 2, forDay: testingDays[3]) else { XCTFail(); return }
    XCTAssertEqual(t2.category, .cafe)
    XCTAssertEqual(t2.authorName, "Буся")
    XCTAssertEqual(t2.amount, 1980.0)

    XCTAssertNil(dataProvider.transaction(index: 12402, forDay: testingDays[0]))
    XCTAssertNil(dataProvider.transaction(index: 0, forDay: emptyDay))
  }

  func testUpdateTransaction() {
    let testingTransaction = { [unowned self] in
      return self.dataProvider.transaction(index: 1, forDay: self.testingDays[2])
    }

    guard let t1 = testingTransaction() else { XCTFail(); return }
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

    guard let beforeDateChange = testingTransaction() else { XCTFail(); return }
    t1.date = Date(timeInterval: 6 * 3600, since: beforeDateChange.date)
    dataProvider.update(transaction: t1)
    XCTAssertEqual(4, dataProvider.numberOfTransactions(onDay: t1.date))
    XCTAssertEqual(1, dataProvider.numberOfTransactions(onDay: beforeDateChange.date))
    guard let t1MovedToNewDay = dataProvider.transaction(index: 0, forDay: testingDays[3]) else { XCTFail(); return }
    XCTAssertEqual(t1, t1MovedToNewDay)
  }

  func testRemoveTransaction() {
    let indexesToRemove = [0, 0, 1, 2, 0]
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
    let expectedAmounts = [972.0, 8289.0]
    let expectedYears = [2018, 2018]
    let expectedMonths = [10, 11]
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
    let categories: [TransactionCategory] = [.cafe, .grocery, .transport]
    let totalAmount = [6068.0, 1952, 269]
    let summary = dataProvider.categoriesSummary(forMonth: testingDays.last!)
    XCTAssertEqual(summary.count, categories.count)
    for (i, category) in categories.enumerated() {
      XCTAssertEqual(category, summary[i].category)
      XCTAssertEqual(totalAmount[i], summary[i].amount)
    }
  }

}
