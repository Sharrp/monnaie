//
//  MergeController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/06/23.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation

protocol MergeDelegate: AnyObject {
  func mergeDone(updatedTransactions: [Transaction])
}

protocol TransactionsDataSource: AnyObject {
  var transactions: [Transaction] { get }
}

// Responsible for coordinating sync-related data operations: data preparation and merge
class SyncController {
  weak var mergeDelegate: MergeDelegate?
  weak var dataSource: TransactionsDataSource?
  weak var dataSender: SyncDataSender?
  
  private let syncHistoryManager = SyncHistoryManager()
}

extension SyncController: SyncDataDelegate {
  func canStartSync(withBuddy buddy: SyncBuddy) {
    guard let transactions = dataSource?.transactions else { return }
    let syncData = SyncData(transactions: transactions, mode: .merge)
    dataSender?.send(data: syncData.archived(), toBuddy: buddy)
  }
  
  func receive(data: Data, fromBuddy buddy: SyncBuddy) {
    guard let syncData = SyncData(data: data) else { return }
    
    let transactions: [Transaction]
    switch syncData.mode {
    case .merge:
      guard let transactionsToSync = dataSource?.transactions else { return }
      let previousSyncTransactions = syncHistoryManager.transactionsListAtPreviousSync(forDeviceID: buddy.deviceID)
      transactions = merge(local: transactionsToSync,
                           remote: syncData.transactions,
                           previousSyncTransactions: previousSyncTransactions)

      // Send merged data back
      let syncData = SyncData(transactions: transactions, mode: .update)
      dataSender?.send(data: syncData.archived(), toBuddy: buddy)
    case .update:
      transactions = syncData.transactions
    }
    
    mergeDelegate?.mergeDone(updatedTransactions: transactions)
    let thisSyncTransactionsList = transactions.map { $0.hash }
    syncHistoryManager.update(transactionsList: thisSyncTransactionsList, forDeviceID: buddy.deviceID)
    dataSender?.allDataSent(toBuddy: buddy)
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
      localIndex[transaction.hash] = index
    }
    var processedTransactions = [Int]()

    // Check remote
    for transaction in remote {
      if let indexOfLocalCopy = localIndex[transaction.hash] {
        let localCopy = local[indexOfLocalCopy]
        merged.append(mostRecentTransaction(t1: localCopy, t2: transaction))
        processedTransactions.append(localCopy.hash)
      } else {
        // Wasn't in local last time so it's new one created on remote
        if !previousSyncTransactions.contains(transaction.hash) {
          merged.append(transaction)
          processedTransactions.append(transaction.hash)
        }
      }
    }

    // Check local ones that not processed yet
    for transaction in local.filter({ !processedTransactions.contains($0.hash) }) {
      if !previousSyncTransactions.contains(transaction.hash) {
        merged.append(transaction)
      }
    }

    return merged.sorted { $0.date < $1.date }
  }
}
