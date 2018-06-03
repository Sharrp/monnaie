//
//  ViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/01.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

//class ViewController: CardViewController {
class ViewController: UIViewController {
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var totalAmountLabel: UILabel!
  
  private let dateFormatter = DateFormatter()
  let dataProvider = TransactionsController()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    dataProvider.presentor = self
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    
    updateTotal()
  }
}

extension ViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return dataProvider.numberOfDays
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return dataProvider.numberOfTransactions(forDay: section)
  }
  
  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    let day = dataProvider.date(forDay: section)
    var title: String
    if Calendar.current.isDate(day, inSameDayAs: Date()) {
      title = "Today"
    } else if Calendar.current.isDate(day, inSameDayAs: Date(timeIntervalSinceNow: -86400)) {
      title = "Yesterday"
    } else {
      title = dateFormatter.string(from: day)
    }
    
    // Daily amount in each section
    let dailySum = dataProvider.totalAmount(forDay: section)
    title += " — " + formatMoney(amount: dailySum, currency: .JPY)
    
    return title
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cellID = "transactionCell"
    let cell: TransactionCell
    if let dequeuedCell = tableView.dequeueReusableCell(withIdentifier: cellID) as? TransactionCell {
      cell = dequeuedCell
    } else {
      cell = TransactionCell(style: .subtitle, reuseIdentifier: cellID)
    }
    
    let transaction = dataProvider.transaction(forDay: indexPath.section, withIndex: indexPath.row)
    cell.textLabel?.text = "\(transaction.category)"
    cell.amountLabel.text = formatMoney(amount: transaction.amount, currency: .JPY)
    if transaction.authorName != Settings.main.syncName {
      cell.detailTextLabel?.text = "\(transaction.authorName)"
    }
    return cell
  }
  
  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    guard editingStyle == .delete else { return }
    dataProvider.removeTransaction(inDay: indexPath.section, withIndex: indexPath.row)
  }
}

extension ViewController: SyncNameUpdateDelegate {
  func nameUpdated(toName name: String) {
    dataProvider.updateNameInTransactionsFromThisDevice(toNewName: name)
  }
}

extension ViewController: TransactionsPresentor {
  private func updateTotal() {
    let dailySum = dataProvider.totalAmount(forDay: 0)
    var totalString = "Today: " + formatMoney(amount: dailySum, currency: .JPY)
    let monthlyAmount = dataProvider.totalAmountForCurrentMonth()
    totalString += ". Total: " + formatMoney(amount: monthlyAmount, currency: .JPY)
    totalAmountLabel.text = totalString
  }
  
  func didUpdate(days: [Int]) {
    DispatchQueue.main.async { [unowned self] in
      let sections = IndexSet(days)
      self.tableView.reloadSections(sections, with: .automatic)
      self.updateTotal()
    }
  }
  
  func didUpdateTransactions(atIndexPaths indexPaths: [IndexPath]) {
    DispatchQueue.main.async { [unowned self] in
      self.tableView.reloadRows(at: indexPaths, with: .automatic)
      self.updateTotal()
    }
  }
  
  func didUpdateAll() {
    DispatchQueue.main.async { [unowned self] in
      self.tableView.reloadData()
      self.updateTotal()
    }
  }
}

