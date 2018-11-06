//
//  TransactionsController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/10/17.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation
import SQLite3

protocol TransactionsPresentor: AnyObject {
  func didUpdate(days: [Date])
  func didUpdateAll()
}

typealias CategoriesSummary = [(category: TransactionCategory, amount: Double)]

class TransactionsController: TransactionUpdateDelegate {
  weak var presentor: TransactionsPresentor?
  
  var db: OpaquePointer!
  private let transactionsTableName = "transactions"
  private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
  private let dbFileName: String
  private var dbPath: URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(dbFileName + ".sqlite")
  }
  private var dateFormatString = "yyyy-MM-dd_HH:mm:ss.SSS"
  private var sqlDateFarmatString = "yyyy-MM-dd"
  
  init(dbName dbFileName: String = "testing") {
    self.dbFileName = dbFileName
    guard sqlite3_open(dbPath.path, &db) == SQLITE_OK else { print("error opening database"); return }
    
    let createTableRequest = """
      CREATE TABLE IF NOT EXISTS \(transactionsTableName)
      (createdDate REAL PRIMARY KEY, date REAL, dateString, modifiedDate REAL, amount REAL, author TEXT, category TEXT)
    """
    if sqlite3_exec(db, createTableRequest, nil, nil, nil) != SQLITE_OK {
      printError(on: "table creation", db)
    }
  }
  
  deinit {
    sqlite3_close(db)
  }
  
  /// MARK: Testing
  
  func removeDB() {
    do {
      sqlite3_close(db)
      try FileManager.default.removeItem(at: dbPath)
    } catch {
      print("Removing DB error: \(error)")
    }
  }
  
  func allDates() -> [Date] {
    let sql = "SELECT date FROM Transactions ORDER BY date ASC"
    var dates = [Date]()
    guard let statement = prepareStatement(sql: sql) else { return dates }
    while sqlite3_step(statement) == SQLITE_ROW {
      let dateTimestamp = sqlite3_column_double(statement, 0)
      let dateCandidate = Date(timeIntervalSince1970: dateTimestamp)
      if !dates.contains(where: { dateCandidate.isSame(granularity: .day, asDate: $0) }) {
        dates.append(dateCandidate)
      }
    }
    sqlite3_finalize(statement)
    return dates
  }
  
  /// MARK: Public
  
  func add(transaction: Transaction) {
    let sql = "INSERT INTO \(transactionsTableName) (createdDate, date, dateString, modifiedDate, amount, author, category) VALUES (?, ?, ?, ?, ?, ?, ?)"
    let statement = prepareStatement(sql: sql)
    guard sqlite3_bind_double(statement, 1, transaction.createdDate.timeIntervalSince1970) == SQLITE_OK else { printError(on: "binding", db); return }
    guard sqlite3_bind_double(statement, 2, transaction.date.timeIntervalSince1970) == SQLITE_OK else { printError(on: "binding", db); return }
    
    let dateString = DateFormatter(dateFormat: sqlDateFarmatString).string(from: transaction.date)
    guard sqlite3_bind_text(statement, 3, dateString, -1, SQLITE_TRANSIENT) == SQLITE_OK else { printError(on: "binding", db); return }
    guard sqlite3_bind_double(statement, 4, transaction.modifiedDate.timeIntervalSince1970) == SQLITE_OK else { printError(on: "binding", db); return }
    guard sqlite3_bind_double(statement, 5, Double(transaction.amount)) == SQLITE_OK else { printError(on: "binding", db); return }
    guard sqlite3_bind_text(statement, 6, transaction.authorName, -1, SQLITE_TRANSIENT) == SQLITE_OK else { printError(on: "binding", db); return }
    guard sqlite3_bind_text(statement, 7, transaction.category.name, -1, SQLITE_TRANSIENT) == SQLITE_OK else { printError(on: "binding", db); return }
    
    if sqlite3_step(statement) != SQLITE_DONE {
      printError(on: "binding", db)
    }
    sqlite3_finalize(statement)
    notifyPresentor(aboutDays: [transaction.date])
  }
  
  func update(transaction: Transaction) {
    let dateString = DateFormatter(dateFormat: sqlDateFarmatString).string(from: transaction.date)
    let sql = """
    UPDATE \(transactionsTableName)
    SET amount='\(transaction.amount)',
    author='\(transaction.authorName)',
    category='\(transaction.category.name)',
    date='\(transaction.date.timeIntervalSince1970)', dateString='\(dateString)',
    modifiedDate='\(Date().timeIntervalSince1970)'
    WHERE createdDate='\(transaction.createdDate.timeIntervalSince1970)'
    """
    let statement = prepareStatement(sql: sql)
    if sqlite3_step(statement) != SQLITE_DONE {
      printError(on: "updating", db)
    }
    sqlite3_finalize(statement)
    notifyPresentor(aboutDays: [transaction.date])
  }
  
  func remove(transaction: Transaction) {
    let sql = "DELETE FROM \(transactionsTableName) WHERE createdDate='\(transaction.createdDate.timeIntervalSince1970)'"
    let statement = prepareStatement(sql: sql)
    if sqlite3_step(statement) != SQLITE_DONE {
      printError(on: "removing", db)
    }
    sqlite3_finalize(statement)
    notifyPresentor(aboutDays: [transaction.date])
  }
  
  func isEmpty() -> Bool {
    let sql = "SELECT count(*) FROM \(transactionsTableName)"
    let count = sqlIntValue(sql: sql) ?? 0
    return count == 0
  }
  
  func transaction(index: Int, forDay dayDate: Date) -> Transaction? {
    let dateString = DateFormatter(dateFormat: sqlDateFarmatString).string(from: dayDate)
    let sql = "SELECT * FROM \(transactionsTableName) WHERE dateString='\(dateString)' ORDER BY date ASC LIMIT 1 OFFSET \(index)"
    let statement = prepareStatement(sql: sql)
    guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
    let transaction = getTransaction(withStatement: statement)
    sqlite3_finalize(statement)
    return transaction
  }
  
  func oldestTransactionDate() -> Date? {
    let sql = "SELECT date FROM \(transactionsTableName) ORDER BY date ASC LIMIT 1"
    guard let timestamp = sqlDoubleValue(sql: sql) else { return nil }
    return Date(timeIntervalSince1970: timestamp)
  }
  
  func daysWithTransactions(forMonth monthDate: Date) -> [Int] {
    let monthName = name(ofMonth: monthDate)
    let sql = "SELECT strftime('%d', dateString) FROM \(transactionsTableName) WHERE strftime('%Y%m', dateString)='\(monthName)' GROUP BY dateString ORDER BY date ASC"
    guard let statement = prepareStatement(sql: sql) else { return [] }
    var nonEmptyDays = [Int]()
    while sqlite3_step(statement) == SQLITE_ROW {
      nonEmptyDays.append(Int(sqlite3_column_int(statement, 0)))
    }
    sqlite3_finalize(statement)
    return nonEmptyDays
  }
  
  func numberOfTransactions(onDay dayDate: Date) -> Int {
    let dateString = DateFormatter(dateFormat: sqlDateFarmatString).string(from: dayDate)
    let sql = "SELECT count(*) FROM \(transactionsTableName) WHERE dateString='\(dateString)'"
    return sqlIntValue(sql: sql) ?? 0
  }
  
  func totalAmount(forMonth monthDate: Date) -> Double {
    let monthName = name(ofMonth: monthDate)
    let sql = "SELECT sum(amount) FROM \(transactionsTableName) WHERE strftime('%Y%m', dateString)='\(monthName)'"
    return sqlDoubleValue(sql: sql) ?? 0
  }
  
  func totalAmount(forDay dayDate: Date) -> Double {
    let dateString = DateFormatter(dateFormat: sqlDateFarmatString).string(from: dayDate)
    let sql = "SELECT sum(amount) FROM \(transactionsTableName) WHERE dateString='\(dateString)'"
    return sqlDoubleValue(sql: sql) ?? 0
  }
  
  func monthlyAmounts() -> [MonthReport] {
    let sql = "SELECT date, sum(amount) FROM \(transactionsTableName) GROUP BY strftime('%Y%m', dateString) ORDER BY date ASC"
    guard let statement = prepareStatement(sql: sql) else { return [] }
    var reports = [MonthReport]()
    while sqlite3_step(statement) == SQLITE_ROW {
      let monthDate = Date(timeIntervalSince1970: sqlite3_column_double(statement, 0))
      let amount = sqlite3_column_double(statement, 1)
      reports.append(MonthReport(monthDate: monthDate, amount: amount))
    }
    sqlite3_finalize(statement)
    return reports
  }
  
  func categoriesSummary(forMonth monthDate: Date) -> CategoriesSummary {
    let (year, month, _) = components(ofDate: monthDate)
    let monthName = String(format: "%d%02d", year, month)
    let sql = """
      SELECT category, sum(amount)
      FROM \(transactionsTableName)
      WHERE strftime('%Y%m', dateString)='\(monthName)'
      GROUP BY category ORDER BY sum(amount) DESC
    """
    guard let statement = prepareStatement(sql: sql) else { return [] }
    var summary = CategoriesSummary()
    while sqlite3_step(statement) == SQLITE_ROW {
      let categoryName = String(cString: sqlite3_column_text(statement, 0))
      guard let category = TransactionCategory(exportName: categoryName) else { continue }
      let amount = sqlite3_column_double(statement, 1)
      summary.append((category: category, amount: amount))
    }
    sqlite3_finalize(statement)
    return summary
  }
  
  func changeOnwer(from oldName: String, to newName: String) {
    let sql = "UPDATE \(transactionsTableName) SET author='\(newName)' WHERE author='\(oldName)'"
    let statement = prepareStatement(sql: sql)
    guard sqlite3_step(statement) == SQLITE_DONE else { printError(on: "renaming", db); return }
    sqlite3_finalize(statement)
    notifyPresentor()
  }
  
  // MARK: SQLite helpers
  
  private func printError(on operation: String, _ db: OpaquePointer) {
    let errmsg = String(cString: sqlite3_errmsg(db)!)
    print("DB error (\(operation)): \(errmsg)")
  }
  
  private func prepareStatement(sql: String) -> OpaquePointer? {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      printError(on: "preparing", db)
      return nil
    }
    return statement
  }
  
  private func sqlIntValue(sql: String) -> Int? {
    guard let statement = prepareStatement(sql: sql) else { return nil }
    guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
    let value = Int(sqlite3_column_int(statement, 0))
    sqlite3_finalize(statement)
    return value
  }
  
  private func sqlDoubleValue(sql: String) -> Double? {
    guard let statement = prepareStatement(sql: sql) else { return nil }
    guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
    let value = sqlite3_column_double(statement, 0)
    sqlite3_finalize(statement)
    return value
  }
  
  private func removeAll() {
    let sql = "DELETE FROM \(transactionsTableName)"
    let statement = prepareStatement(sql: sql)
    if sqlite3_step(statement) != SQLITE_DONE {
      printError(on: "removing", db)
    }
    sqlite3_finalize(statement)
  }
  
  // MARK: Generic helpers
  
  private func name(ofMonth monthDate: Date) -> String {
    let (year, month, _) = components(ofDate: monthDate)
    return String(format: "%d%02d", year, month)
  }
  
  private func components(ofDate date: Date) -> (year: Int, month: Int, day: Int) {
    let day = Calendar.current.component(.day, from: date)
    let month = Calendar.current.component(.month, from: date)
    let year = Calendar.current.component(.year, from: date)
    return (year, month, day)
  }
  
  private func getTransaction(withStatement statement: OpaquePointer?) -> Transaction? {
    let categoryName = String(cString: sqlite3_column_text(statement, 6))
    guard let category = TransactionCategory(exportName: categoryName) else { return nil }
    
    let createdDateTimestamp = sqlite3_column_double(statement, 0)
    let createdDate = Date(timeIntervalSince1970: createdDateTimestamp)
    let dateTimestamp = sqlite3_column_double(statement, 1)
    let date = Date(timeIntervalSince1970: dateTimestamp)
    let modifiedDateTimestamp = sqlite3_column_double(statement, 3)
    let modifiedDate = Date(timeIntervalSince1970: modifiedDateTimestamp)
    
    let amount = sqlite3_column_double(statement, 4)
    let author = String(cString: sqlite3_column_text(statement, 5))
    return Transaction(amount: amount, category: category, authorName: author,
                       transactionDate: date, creationDate: createdDate, modifiedDate: modifiedDate)
  }
  
  internal func notifyPresentor(aboutDays days: [Date]? = nil) {
    if let days = days {
      presentor?.didUpdate(days: days)
    } else {
      presentor?.didUpdateAll()
    }
  }
}

extension TransactionsController: SyncTransactionsDataSource {
  func syncTransactions() -> [Transaction] {
    let sql = "SELECT * FROM \(transactionsTableName) ORDER BY date ASC "
    let statement = prepareStatement(sql: sql)
    var transactions = [Transaction]()
    while sqlite3_step(statement) == SQLITE_ROW {
      guard let transaction = getTransaction(withStatement: statement) else { continue }
      transactions.append(transaction)
    }
    sqlite3_finalize(statement)
    return transactions
  }
}

extension TransactionsController: MergeDelegate {
  func mergeDone(replacingTransactions transactions: [Transaction]) {
    removeAll()
    for transaction in transactions {
      add(transaction: transaction)
    }
    notifyPresentor()
  }
}

extension TransactionsController {
  func exportDataAsCSV() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = dateFormatString
    
    var csv = "transaction date;creation date;author;category;amount\n"
    for t in syncTransactions() {
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
        let category = TransactionCategory(exportName: categoryName),
        let amount = Double(components[4]),
        amount > 0
        else { continue }
      
      let transaction = Transaction(amount: amount, category: category, authorName: author,
                                    transactionDate: transactionDate, creationDate: creationDate)
      importedTransactions.append(transaction)
    }
    guard importedTransactions.count > 0 else { return failureResult }
    
    switch mode {
    case .merge:
      let transactions = Merger().merge(local: syncTransactions(), remote: importedTransactions, previousSyncTransactions: [])
      mergeDone(replacingTransactions: transactions)
    case .replace:
      mergeDone(replacingTransactions: importedTransactions)
    }
    notifyPresentor()
    return .success("Successfully imported \(importedTransactions.count) transactions")
  }
}
