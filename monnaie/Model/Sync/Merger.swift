//
//  File.swift
//  monnaie
//
//  Created by Anton Vronskii on 2018/10/13.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation

struct Merger {
  private func mostRecentTransaction(t1: Transaction, t2: Transaction) -> Transaction {
    if t1.modifiedDate > t2.modifiedDate {
      return t1
    } else {
      return t2
    }
  }
  
  func merge(local: [Transaction], remote: [Transaction], previousSyncTransactions: [Int]) -> [Transaction] {
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
        } // else — was in local last time but not here anymore — deleted, should not be added to final merged results
      }
    }
    
    // Check local ones that not processed yet
    for transaction in local.filter({ !processedTransactions.contains($0.hash) }) {
      if !previousSyncTransactions.contains(transaction.hash) {
        merged.append(transaction)
      }
    }
    
    merged.sort{ $0.date < $1.date }
    return merged
  }
}
