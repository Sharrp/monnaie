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

class ViewController: UIViewController {
  private let storeManager = StoreManager()
  private var transactions = [Transaction]()
  
  @IBOutlet var tableView: UITableView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    transactions = storeManager.loadTransactions()
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
    tableView.reloadData()
    storeManager.save(transactions: transactions)
  }
}

extension ViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return transactions.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cellID = "transactionCell"
    let cell: UITableViewCell
    if let dequeuedCell = tableView.dequeueReusableCell(withIdentifier: cellID) {
      cell = dequeuedCell
    } else {
      cell = UITableViewCell(style: .subtitle, reuseIdentifier: cellID)
    }
    
    let transaction = transactions[indexPath.row]
    cell.textLabel?.text = "\(transaction.category): \(transaction.amount)"
    var detailsText = "\(transaction.author), \(transaction.date)"
    if let comment = transaction.comment, comment.count > 0 {
      detailsText += ", " + comment
    }
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
