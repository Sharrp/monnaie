//
//  ViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/01.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
  private var tap: UITapGestureRecognizer!
  private var longPress: UILongPressGestureRecognizer!
  private let syncManager = SyncManager()
  private let storeManager = StoreManager()
  private var transactions = [Transaction]()
  
  @IBOutlet var tableView: UITableView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    syncManager.delegate = self
    transactions = storeManager.loadTransactions()
    
    tap = UITapGestureRecognizer(target: self, action: #selector(tapHandler(gesture:)))
    view.addGestureRecognizer(tap)
    
    longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressHandler(gesture:)))
    view.addGestureRecognizer(longPress)
  }
  
  @objc func tapHandler(gesture: UITapGestureRecognizer) {
    if gesture.state == .ended {
      guard let data = "I'm \(UIDevice.current.name)".data(using: .utf8) else { return }
      syncManager.send(data: data)
    }
  }
  
  @objc func longPressHandler(gesture: UILongPressGestureRecognizer) {
    if gesture.state == .began {
      syncManager.prepareSync()
    }
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    guard let addTransactionVC = segue.destination as? AddTransactionViewController else { return }
    addTransactionVC.delegate = self
  }
}

extension ViewController: SyncDelegate {
  func readyToSync() {
    print("Ready to send messages")
  }
  
  func receive(data: Data) {
    guard let msg = String(data: data as Data, encoding: .utf8) else { return }
    print("\(UIDevice.current.name) --- \(msg)")
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
    
    let transaction = transactions[transactions.count - indexPath.row - 1]
    cell.textLabel?.text = "\(transaction.category): \(transaction.amount)"
    cell.detailTextLabel?.text = "\(transaction.author), \(transaction.date)"
    return cell
  }
}

extension ViewController: TransactionAdditionDelegate {
  func add(transaction: Transaction) {
    transactions.append(transaction)
    storeManager.save(transactions: transactions)
    tableView.reloadData()
  }
}
