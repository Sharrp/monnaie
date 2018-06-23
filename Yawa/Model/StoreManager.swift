//
//  StoreManager.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation

struct StoreManager {
  private let transactionsFileName = "dump.data"
  private let permissionsFileName = "permissions.data"
  
  private func filePath(forName fileName:String) -> String {
    return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/" + fileName
  }
  
  // Transactions
  
  func loadTransactions() -> [Transaction] {
    let path = filePath(forName: transactionsFileName)
    if let transactions = NSKeyedUnarchiver.unarchiveObject(withFile: path) as? [Transaction] {
      return transactions
    }
    return []
  }
  
  func save(transactions: [Transaction]) {
    let path = filePath(forName: transactionsFileName)
    NSKeyedArchiver.archiveRootObject(transactions, toFile: path)
  }
  
  // Permissions

  func loadPermissions() -> [String] {
    let path = filePath(forName: permissionsFileName)
    if let permissions = NSKeyedUnarchiver.unarchiveObject(withFile: path) as? [String] {
      return permissions
    }
    return []
  }
  
  func save(permissions: [String]) {
    let path = filePath(forName: permissionsFileName)
    NSKeyedArchiver.archiveRootObject(permissions, toFile: path)
  }
}
