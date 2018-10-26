//
//  TransactionsController.swift
//  db-sqlite
//
//  Created by Anton Vronskii on 2018/10/14.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation
import SQLite3

class TransactionsControllerDB {
  var db: OpaquePointer!
  private let transactionsTableName = "Transactions"
  private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
  private let fileName: String
  private var dbPath: URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName + ".sqlite")
  }
  
  init(name fileName: String = "testing") {
    self.fileName = fileName
    // open database
    if sqlite3_open(dbPath.path, &db) != SQLITE_OK {
      print("error opening database")
    }
    print(dbPath)
    
    let createTableRequest = """
      CREATE TABLE IF NOT EXISTS \(transactionsTableName)
      (createdDate REAL PRIMARY KEY, transactionDate REAL, modifiedDate REAL, amount REAL, author TEXT, category TEXT)
    """
    if sqlite3_exec(db, createTableRequest, nil, nil, nil) != SQLITE_OK {
      let errmsg = String(cString: sqlite3_errmsg(db)!)
      print("error creating table: \(errmsg)")
    }
  }
  
  func removeDB() {
    do {
      try FileManager.default.removeItem(at: dbPath)
    } catch {
      print("Removing DB error: \(error)")
    }
  }
  
  private func printErrorMessage(_ db: OpaquePointer, operation: String) {
    let errmsg = String(cString: sqlite3_errmsg(db)!)
    print("DB error (\(operation)): \(errmsg)")
    return
  }
  
  func add(transaction: Transaction) {
    var statement: OpaquePointer?
    let sql = "INSERT INTO \(transactionsTableName) (createdDate, transactionDate, modifiedDate, amount, author, category) VALUES (?, ?, ?, ?, ?, ?)"
    
    if sqlite3_prepare(db, sql, -1, &statement, nil) != SQLITE_OK {
      printErrorMessage(db, operation: "preparing")
      return
    }
    
    //binding the parameters
    if sqlite3_bind_double(statement, 1, transaction.createdDate.timeIntervalSince1970) != SQLITE_OK {
      printErrorMessage(db, operation: "binding")
      return
    }
    if sqlite3_bind_double(statement, 2, transaction.date.timeIntervalSince1970) != SQLITE_OK {
      printErrorMessage(db, operation: "binding")
      return
    }
    if sqlite3_bind_double(statement, 3, transaction.modifiedDate.timeIntervalSince1970) != SQLITE_OK {
      printErrorMessage(db, operation: "binding")
      return
    }
    if sqlite3_bind_double(statement, 4, Double(transaction.amount)) != SQLITE_OK {
      printErrorMessage(db, operation: "binding")
      return
    }
    if sqlite3_bind_text(statement, 5, transaction.authorName, -1, SQLITE_TRANSIENT) != SQLITE_OK {
      printErrorMessage(db, operation: "binding")
      return
    }
    if sqlite3_bind_text(statement, 6, transaction.category.name, -1, SQLITE_TRANSIENT) != SQLITE_OK {
      printErrorMessage(db, operation: "binding")
      return
    }
    
    if sqlite3_step(statement) != SQLITE_DONE {
      printErrorMessage(db, operation: "inserting")
    }
  }
  
  func readValues(){
    let queryString = "SELECT * FROM \(transactionsTableName)"
    var statement: OpaquePointer?
    
    //preparing the query
    if sqlite3_prepare(db, queryString, -1, &statement, nil) != SQLITE_OK{
      printErrorMessage(db, operation: "reading")
      return
    }
    
    //traversing through all the records
    while(sqlite3_step(statement) == SQLITE_ROW){
      let createdDateTimestamp = sqlite3_column_double(statement, 0)
      let dateTimestamp = sqlite3_column_double(statement, 1)
      let modifiedDateTimestamp = sqlite3_column_double(statement, 1)
      let amount = sqlite3_column_double(statement, 3)
      let author = String(cString: sqlite3_column_text(statement, 4))
      let category = String(cString: sqlite3_column_text(statement, 5))
      
      print(createdDateTimestamp, dateTimestamp, amount, author, category)
    }
    
  }
  
//  func update(transaction: Transaction) {
  func update() {
    let sql = "UPDATE \(transactionsTableName) SET amount='\(99)' WHERE createdDate='\(1539732487.890922)'"
    var statement: OpaquePointer?
    if sqlite3_prepare(db, sql, -1, &statement, nil) != SQLITE_OK{
      printErrorMessage(db, operation: "updating")
      return
    }
    if sqlite3_step(statement) != SQLITE_DONE {
      printErrorMessage(db, operation: "inserting")
    }
  }
  
  
  // 1 - Prepare for testing
  // Init empty db with testing file
  // Fill up db with add()
  // function to remote db file (when test case ended)
  
  // 2 - main test cases
//  func transaction(forDay day: Int, withIndex transactionIndex: Int) -> Transaction { }
//  func numberOfTransactions() -> Int { }
//  func numberOfMonths() -> Int { }
//  func numberOfDays(inMonth month: Int) -> Int { }
//  func totalNumberOfDays() -> Int { }
//  func numberOfTransactions(forDay day: Int) -> Int { }
//
//  func date(forDay day: Int) -> Date { }
//  func totalAmount(forMonth month: Int) -> Float { }

//  func categoriesSummary(forMonth month: Int) -> CategoriesSummary { }
//  func removeTransaction(inDay day: Int, withIndex transactionIndex: Int) { }
}
