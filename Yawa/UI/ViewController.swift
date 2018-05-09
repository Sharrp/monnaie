//
//  ViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/01.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

protocol TransactionsUpdateDelegate {
  func reset(transactionsTo transactions: [Transaction])
}

struct TimelineSection {
  let firstItemInList: Int
  let numberOfItems: Int
}

class ViewController: UIViewController {
  private let storeManager = StoreManager()
  private var transactions = [Transaction]()
  
  @IBOutlet var tableView: UITableView!
  private var tableIndex = [TimelineSection]()
  private let dateFormatter = DateFormatter()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    
    transactions = storeManager.loadTransactions()
    tableIndex = buildTableIndex(transactions)
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "addTransaction" {
      guard let addTransactionVC = segue.destination as? TransactionViewController else { return }
      addTransactionVC.delegate = self
    } else if segue.identifier == "editTransaction" {
      guard let transactionVC = segue.destination as? TransactionViewController else { return }
      guard let indexPath = tableView.indexPathForSelectedRow else { return }
      transactionVC.transaction = transactions[indexPath.row]
      transactionVC.delegate = self
    } else if segue.identifier == "sync" {
      guard let syncVC = segue.destination as? SyncViewController else { return }
      syncVC.delegate = self
      syncVC.transactionsToSync = transactions
    }
  }
  
  private func sortUpdateAndSave() {
    transactions.sort{ $0.date > $1.date }
    tableIndex = buildTableIndex(transactions)
    tableView.reloadData()
    storeManager.save(transactions: transactions)
  }
  
  private func buildTableIndex(_ transactions: [Transaction]) -> [TimelineSection] {
    var index = [TimelineSection]()
    var lastDay = Date.distantFuture
    var sectionFirstIndex = -1
    for (i, t) in transactions.enumerated() {
      if !Calendar.current.isDate(lastDay, inSameDayAs: t.date) {
        if sectionFirstIndex != -1 {
          let newSection = TimelineSection(firstItemInList: sectionFirstIndex, numberOfItems: i-sectionFirstIndex)
          index.append(newSection)
        }
        sectionFirstIndex = i
        lastDay = t.date
      }
    }
    if transactions.count > 0 {
      let newSection = TimelineSection(firstItemInList: sectionFirstIndex, numberOfItems: transactions.count-sectionFirstIndex)
      index.append(newSection)
    }
    return index
  }
}

extension ViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return tableIndex.count
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return tableIndex[section].numberOfItems
  }
  
  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    let transactionIndex = tableIndex[section].firstItemInList
    let transaction = transactions[transactionIndex]
    
    if Calendar.current.isDate(transaction.date, inSameDayAs: Date()) {
      return "Today"
    } else if Calendar.current.isDate(transaction.date, inSameDayAs: Date(timeIntervalSinceNow: -86400)) {
      return "Yesterday"
    }
    return dateFormatter.string(from: transaction.date)
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cellID = "transactionCell"
    let cell: TransactionCell
    if let dequeuedCell = tableView.dequeueReusableCell(withIdentifier: cellID) as? TransactionCell {
      cell = dequeuedCell
    } else {
      cell = TransactionCell(style: .subtitle, reuseIdentifier: cellID)
    }
    
    let transactionIndex = tableIndex[indexPath.section].firstItemInList + indexPath.row
    let transaction = transactions[transactionIndex]
    cell.textLabel?.text = "\(transaction.category)"
    var detailsText = "\(transaction.author)"
    if let comment = transaction.comment, comment.count > 0 {
      detailsText += ": " + comment
    }
    cell.amountLabel.text = NSString(format: "¥%.0f", transaction.amount) as String
    cell.detailTextLabel?.text = detailsText
    return cell
  }
  
  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    guard editingStyle == .delete else { return }
    transactions.remove(at: indexPath.row)
    sortUpdateAndSave()
  }
}

extension ViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    performSegue(withIdentifier: "editTransaction", sender: self)
  }
}

extension ViewController: TransactionDelegate {
  func add(transaction: Transaction) {
    transactions.append(transaction)
    sortUpdateAndSave()
  }
  
  func update(transaction: Transaction) {
    guard let index = transactions.index(where: { $0.hashValue == transaction.hashValue }) else { return }
    transactions[index] = transaction
    sortUpdateAndSave()
  }
}

extension ViewController: TransactionsUpdateDelegate {
  func reset(transactionsTo transactions: [Transaction]) {
    self.transactions = transactions
    sortUpdateAndSave()
  }
}
