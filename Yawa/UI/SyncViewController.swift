//
//  SyncViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class SyncViewController: UIViewController {
  private let syncManager = SyncManager()
  private let syncHistoryManager = SyncHistoryManager()
  var delegate: TransactionsUpdateDelegate?
  var transactionsToSync: [Transaction]!
  
  @IBOutlet var syncStatusLabel: UILabel!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    syncManager.delegate = self
    syncManager.prepareSync()
  }
  
  @IBAction func cancel() {
    syncManager.stopSync()
    self.dismiss(animated: true, completion: nil)
  }
}

extension SyncViewController: SyncDelegate {
  private func updateStatus(to newStatus: String) {
    DispatchQueue.main.async { [unowned self] in
      self.syncStatusLabel.text = newStatus
    }
  }
  
  func readyToSync() {
    let syncData = SyncData(transactions: transactionsToSync, mode: .merge)
    let data = NSKeyedArchiver.archivedData(withRootObject: syncData)
    syncManager.send(data: data)
    updateStatus(to: "Syncing...")
  }
  
  func receive(data: Data) {
    guard let syncData = NSKeyedUnarchiver.unarchiveObject(with: data) as? SyncData else {
      print("Failed to unarchive transactions from peer")
      updateStatus(to: "Sync failed. Reopen this view")
      return
    }
    
    let transactions: [Transaction]
    if syncData.mode == .merge {
      let previousSyncTransactions = syncHistoryManager.transactionsListAtPreviousSync(forDeviceID: syncData.deviceID)
      transactions = merge(local: transactionsToSync,
                          remote: syncData.transactions,
        previousSyncTransactions: previousSyncTransactions)
    } else { // merged data received
      transactions = syncData.transactions
    }
    delegate?.reset(transactionsTo: transactions)
    let thisSyncTransactionsList = transactions.map { $0.hashValue }
    syncHistoryManager.update(transactionsList: thisSyncTransactionsList, forDeviceID: syncData.deviceID)
    
    updateStatus(to: "Sync is finished")
  }
  
  private func mostRecentTransaction(t1: Transaction, t2: Transaction) -> Transaction {
    if t1.modifiedDate > t2.modifiedDate {
      return t1
    } else {
      return t2
    }
  }
  
  private func merge(local: [Transaction], remote: [Transaction], previousSyncTransactions: [Int]) -> [Transaction] {
    var merged = [Transaction]()
    
    // Build index for local transactions
    var localIndex = [Int: Int]()
    for (index, transaction) in local.enumerated() {
      localIndex[transaction.hashValue] = index
    }
    var processedTransactions = [Int]()
    
    // Check remote
    for transaction in remote {
      if let indexOfLocalCopy = localIndex[transaction.hashValue] {
        let localCopy = local[indexOfLocalCopy]
        merged.append(mostRecentTransaction(t1: localCopy, t2: transaction))
        processedTransactions.append(localCopy.hashValue)
      } else {
        // Wasn't in local last time so it's new one created on remote
        if !previousSyncTransactions.contains(transaction.hashValue) {
          merged.append(transaction)
          processedTransactions.append(transaction.hashValue)
        }
      }
    }
    
    // Check local ones that not processed yet
    for transaction in local.filter({ !processedTransactions.contains($0.hashValue) }) {
      if !previousSyncTransactions.contains(transaction.hashValue) {
        merged.append(transaction)
      }
    }
    
    return merged
  }
}
