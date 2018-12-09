//
//  DataService.swift
//  monnaie
//
//  Created by Anton Vronskii on 2018/10/17.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation
import SQLite3

typealias CategoriesSummary = [(category: TransactionCategory, amount: Double)]
typealias DataServiceUpdateCallback = () -> Void

class DataService {
  private var db: OpaquePointer!
  private let transactionsTableName = "transactions"
  private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
  private let dbFileName: String
  private var dbPath: URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(dbFileName + ".sqlite")
  }
  private var dateFormatString = "yyyy-MM-dd_HH:mm:ss.SSSZ"
  
  init(dbName dbFileName: String) {
    self.dbFileName = dbFileName
    guard sqlite3_open(dbPath.path, &db) == SQLITE_OK else { print("error opening database"); return }
    
    let createTableRequest = """
      CREATE TABLE IF NOT EXISTS \(transactionsTableName)
      (createdDate REAL PRIMARY KEY, date REAL, modifiedDate REAL, amount REAL, author TEXT, category TEXT)
    """
    if sqlite3_exec(db, createTableRequest, nil, nil, nil) != SQLITE_OK {
      printError(on: "table creation", db)
    }
  }
  
  deinit {
    sqlite3_close(db)
  }
  
  /// MARK: Subscribers
  
  private var subscribers = [DataServiceUpdateCallback?]()
  
  func subscribe(callback: DataServiceUpdateCallback?) {
    subscribers.append(callback)
  }
  
  private func notifySubscribers() {
    subscribers.forEach{ $0?() }
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
  
  func allDates(ofGranularity granularity: Calendar.Component) -> [Date] {
    let sql = "SELECT date FROM Transactions ORDER BY date ASC"
    var dates = [Date]()
    guard let statement = prepareStatement(sql: sql) else { return dates }
    while sqlite3_step(statement) == SQLITE_ROW {
      let dateTimestamp = sqlite3_column_double(statement, 0)
      let dateCandidate = Date(timeIntervalSince1970: dateTimestamp)
      if !dates.contains(where: { dateCandidate.isSame(granularity, asDate: $0) }) {
        dates.append(dateCandidate)
      }
    }
    sqlite3_finalize(statement)
    return dates
  }
  
  /// MARK: Public
  
  func add(transactions: [Transaction]) {
    sqlite3_exec(db, "BEGIN EXCLUSIVE TRANSACTION", nil, nil, nil)
    let statement = prepareStatement(sql: insertSQL)
    for transaction in transactions {
      bind(transaction: transaction, toStatement: statement)
      if sqlite3_step(statement) != SQLITE_DONE {
        printError(on: "bulk adding", db)
      }
      if sqlite3_reset(statement) != SQLITE_OK {
        printError(on: "reset adding statemtn", db)
      }
    }
    sqlite3_finalize(statement)
    if sqlite3_exec(db, "COMMIT TRANSACTION", nil, nil, nil) != SQLITE_OK {
      printError(on: "commit adding transaction", db)
    }
    notifySubscribers()
  }
  
  func add(transaction: Transaction) {
    let statement = prepareStatement(sql: insertSQL)
    bind(transaction: transaction, toStatement: statement)
    if sqlite3_step(statement) != SQLITE_DONE {
      printError(on: "adding", db)
    }
    sqlite3_finalize(statement)
    notifySubscribers()
  }
  
  func update(transaction: Transaction) {
    let sql = """
      UPDATE \(transactionsTableName)
      SET
        amount='\(transaction.amount)',
        author='\(transaction.authorName)',
        category='\(transaction.category.name)',
        date='\(transaction.date.timeIntervalSince1970)',
        modifiedDate='\(Date.now.timeIntervalSince1970)'
      WHERE createdDate='\(transaction.createdDate.timeIntervalSince1970)'
    """
    let statement = prepareStatement(sql: sql)
    if sqlite3_step(statement) != SQLITE_DONE {
      printError(on: "updating", db)
    }
    sqlite3_finalize(statement)
    notifySubscribers()
  }
  
  func remove(transaction: Transaction) {
    let sql = "DELETE FROM \(transactionsTableName) WHERE createdDate='\(transaction.createdDate.timeIntervalSince1970)'"
    let statement = prepareStatement(sql: sql)
    if sqlite3_step(statement) != SQLITE_DONE {
      printError(on: "removing", db)
    }
    sqlite3_finalize(statement)
    notifySubscribers()
  }
  
  func isEmpty() -> Bool {
    let sql = "SELECT count(*) FROM \(transactionsTableName)"
    let count = sqlIntValue(sql: sql) ?? 0
    return count == 0
  }
  
  func transaction(index: Int, forDay dayDate: Date) -> Transaction? {
    let condition = conditionForDate(inRange: dayDate.timestampRangeForDay())
    let sql = "SELECT * FROM \(transactionsTableName) WHERE \(condition) ORDER BY date ASC LIMIT 1 OFFSET \(index)"
    let statement = prepareStatement(sql: sql)
    guard sqlite3_step(statement) == SQLITE_ROW else {
      print("\n\(dayDate): \(index) is NIL\n")
      return nil
    }
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
    let condition = conditionForDate(inRange: monthDate.timestampRangeForMonth())
    let sql = "SELECT date FROM \(transactionsTableName) WHERE \(condition) ORDER BY date ASC"
    guard let statement = prepareStatement(sql: sql) else { return [] }
    var timestampsForMonth = [TimeInterval]()
    while sqlite3_step(statement) == SQLITE_ROW {
      timestampsForMonth.append(sqlite3_column_double(statement, 0))
    }
    sqlite3_finalize(statement)
    
    var nonEmptyDays = [Int]()
    for timestamp in timestampsForMonth {
      let day = Calendar.current.component(.day, from: Date(timeIntervalSince1970: timestamp))
      if !nonEmptyDays.contains(day) {
        nonEmptyDays.append(day)
      }
    }
    return nonEmptyDays
  }
  
  func numberOfTransactions(onDay dayDate: Date) -> Int {
    let condition = conditionForDate(inRange: dayDate.timestampRangeForDay())
    let sql = "SELECT count(*) FROM \(transactionsTableName) WHERE \(condition)"
    return sqlIntValue(sql: sql) ?? 0
  }
  
  func totalAmount(forMonth monthDate: Date) -> Double {
    let condition = conditionForDate(inRange: monthDate.timestampRangeForMonth())
    let sql = "SELECT sum(amount) FROM \(transactionsTableName) WHERE \(condition)"
    return sqlDoubleValue(sql: sql) ?? 0
  }
  
  func totalAmount(forDay dayDate: Date) -> Double {
    let condition = conditionForDate(inRange: dayDate.timestampRangeForDay())
    let sql = "SELECT sum(amount) FROM \(transactionsTableName) WHERE \(condition)"
    return sqlDoubleValue(sql: sql) ?? 0
  }
  
  func monthlyAmounts() -> [MonthReport] {
    var reports = [MonthReport]()
    for monthDate in allDates(ofGranularity: .month) {
      let amount = totalAmount(forMonth: monthDate)
      reports.append(MonthReport(monthDate: monthDate, amount: amount))
    }
    return reports
  }
  
  func categoriesSummary(forMonth monthDate: Date) -> CategoriesSummary {
    let condition = conditionForDate(inRange: monthDate.timestampRangeForMonth())
    let sql = """
      SELECT category, sum(amount)
      FROM \(transactionsTableName)
      WHERE \(condition)
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
    notifySubscribers()
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
  
  private func conditionForDate(inRange timestamps: TimestampRange) -> String {
    return "date>=\(timestamps.start) AND date<\(timestamps.end)"
  }
  
  private var insertSQL: String {
    return "INSERT INTO \(transactionsTableName) (createdDate, date, modifiedDate, amount, author, category) VALUES (?, ?, ?, ?, ?, ?)"
  }
  
  private func bind(transaction: Transaction, toStatement statement: OpaquePointer?) {
    guard sqlite3_bind_double(statement, 1, transaction.createdDate.timeIntervalSince1970) == SQLITE_OK else { printError(on: "binding", db); return }
    guard sqlite3_bind_double(statement, 2, transaction.date.timeIntervalSince1970) == SQLITE_OK else { printError(on: "binding", db); return }
    guard sqlite3_bind_double(statement, 3, transaction.modifiedDate.timeIntervalSince1970) == SQLITE_OK else { printError(on: "binding", db); return }
    guard sqlite3_bind_double(statement, 4, Double(transaction.amount)) == SQLITE_OK else { printError(on: "binding", db); return }
    guard sqlite3_bind_text(statement, 5, transaction.authorName, -1, SQLITE_TRANSIENT) == SQLITE_OK else { printError(on: "binding", db); return }
    guard sqlite3_bind_text(statement, 6, transaction.category.name, -1, SQLITE_TRANSIENT) == SQLITE_OK else { printError(on: "binding", db); return }
  }
  
  // MARK: Generic helpers
  
  private func components(ofDate date: Date) -> (year: Int, month: Int, day: Int) {
    let day = Calendar.current.component(.day, from: date)
    let month = Calendar.current.component(.month, from: date)
    let year = Calendar.current.component(.year, from: date)
    return (year, month, day)
  }
  
  private func getTransaction(withStatement statement: OpaquePointer?) -> Transaction? {
    let categoryName = String(cString: sqlite3_column_text(statement, 5))
    guard let category = TransactionCategory(exportName: categoryName) else { return nil }
    
    let createdDateTimestamp = sqlite3_column_double(statement, 0)
    let createdDate = Date(timeIntervalSince1970: createdDateTimestamp)
    let dateTimestamp = sqlite3_column_double(statement, 1)
    let date = Date(timeIntervalSince1970: dateTimestamp)
    let modifiedDateTimestamp = sqlite3_column_double(statement, 2)
    let modifiedDate = Date(timeIntervalSince1970: modifiedDateTimestamp)
    
    let amount = sqlite3_column_double(statement, 3)
    let author = String(cString: sqlite3_column_text(statement, 4))
    return Transaction(amount: amount, category: category, authorName: author,
                       transactionDate: date, creationDate: createdDate, modifiedDate: modifiedDate)
  }
}

extension DataService: SyncTransactionsDataSource {
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

extension DataService: MergeDelegate {
  func mergeDone(replacingTransactions transactions: [Transaction]) {
    removeAll()
    add(transactions: transactions)
  }
}

extension DataService: CSVCompatible {
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
  
  func importDataFromCSV(csv: String?, mode: CSVImportMode) -> CSVImportResult {
    let failureResult = CSVImportResult.failure("""
        Incorrect CSV format.
        Export your existing data to have an example.
    """)
    guard let csv = csv else { return failureResult }
    
    var importedTransactions = [Transaction]()
    let dateFormatter = DateFormatter() // TODO: vsscanf() should be faster (date from string is the slowest part here)
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
    notifySubscribers()
    return .success("Successfully imported \(importedTransactions.count) transactions")
  }
}
