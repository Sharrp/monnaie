//
//  ViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/01.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
  @IBOutlet weak var tableView: UITableView!
  private let dateFormatter = DateFormatter()
  private let dataProvider = TransactionsController()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    dataProvider.presentor = self
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let transactionVC = segue.destination as? TransactionViewController {
      transactionVC.delegate = dataProvider
      transactionVC.dismissCardSubscriber = self
      transactionVC.cardHeight = view.frame.height - 70
      
      if segue.identifier == "editTransaction" {
        guard let indexPath = tableView.indexPathForSelectedRow else { return }
        transactionVC.transaction = dataProvider.transaction(forDay: indexPath.section, withIndex: indexPath.row)
      }
    } else if let syncVC = segue.destination as? SyncViewController {
      syncVC.delegate = dataProvider
      syncVC.transactionsToSync = dataProvider.syncTransactions
      syncVC.nameDelegate = self
    }
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
    
    // Monthly amount in the first section
    if section == 0 {
      let monthlyAmount = dataProvider.totalAmountForCurrentMonth()
      title += ". Total: " + formatMoney(amount: monthlyAmount, currency: .JPY)
    }
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
    var detailsText = ""
    if transaction.author != Settings.main.syncName {
      detailsText = "\(transaction.author)"
    }
    if let comment = transaction.comment, comment.count > 0 {
      if detailsText.count > 0 { // we've already added author
        detailsText += ": "
      }
      detailsText += comment
    }
    cell.amountLabel.text = formatMoney(amount: transaction.amount, currency: .JPY)
    cell.detailTextLabel?.text = detailsText
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
    Settings.main.syncName = name
    dataProvider.updateNameInTransactionsFromThisDevice(toNewName: name)
  }
}

extension ViewController: TransactionsPresentor {
  func didUpdate(days: [Int]) {
    DispatchQueue.main.async { [unowned self] in
      let sections = IndexSet(days)
      self.tableView.reloadSections(sections, with: .automatic)
    }
  }
  
  func didUpdateTransactions(atIndexPaths indexPaths: [IndexPath]) {
    DispatchQueue.main.async { [unowned self] in
      self.tableView.reloadRows(at: indexPaths, with: .automatic)
    }
  }
  
  func didUpdateAll() {
    DispatchQueue.main.async { [unowned self] in
      self.tableView.reloadData()
    }
  }
}

extension ViewController: DismissCardSubscriber {
  func cardDismissed() {
    print("Dismissed, I'm ViewController")
  }
}
