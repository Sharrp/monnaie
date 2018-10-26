//
//  MergeController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/06/23.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation

protocol MergeDelegate: AnyObject {
  func mergeDone(replacingTransactions: [Transaction])
}

protocol SyncTransactionsDataSource: AnyObject {
  func syncTransactions() -> [Transaction]
}

// Responsible for coordinating sync-related data operations: data preparation and merge
class SyncController {
  weak var mergeDelegate: MergeDelegate?
  weak var dataSource: SyncTransactionsDataSource?
  weak var dataSender: SyncDataSender?
  
  private let syncHistoryManager = SyncHistoryManager()
}

extension SyncController: SyncDataDelegate {
  func startSync(withBuddy buddy: SyncBuddy) {
    guard let transactions = dataSource?.syncTransactions() else { return }
    let syncData = SyncData(transactions: transactions, mode: .merge)
    dataSender?.send(data: syncData.archived(), toBuddy: buddy)
  }
  
  func receive(data: Data, fromBuddy buddy: SyncBuddy) {
    guard let syncData = SyncData(data: data) else { return }
    
    let transactions: [Transaction]
    switch syncData.mode {
    case .merge:
      guard let transactionsToSync = dataSource?.syncTransactions() else { return }
      let previousSyncTransactions = syncHistoryManager.transactionsListAtPreviousSync(forDeviceID: buddy.deviceID)
      transactions = Merger().merge(local: transactionsToSync,
                           remote: syncData.transactions,
                           previousSyncTransactions: previousSyncTransactions)

      // Send merged data back
      let syncData = SyncData(transactions: transactions, mode: .update)
      dataSender?.send(data: syncData.archived(), toBuddy: buddy)
    case .update:
      transactions = syncData.transactions
    }
    
    mergeDelegate?.mergeDone(replacingTransactions: transactions)
    let thisSyncTransactionsList = transactions.map { $0.hash }
    syncHistoryManager.update(transactionsList: thisSyncTransactionsList, forDeviceID: buddy.deviceID)
    dataSender?.allDataSent(toBuddy: buddy)
  }
}
