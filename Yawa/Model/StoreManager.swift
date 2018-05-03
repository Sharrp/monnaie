//
//  StoreManager.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation

struct StoreManager {
  private let fileName = "dump.data"
  private var filePath: String {
    return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/" + fileName
  }
  
  func loadTransactions() -> [Transaction] {
    if let transactions = NSKeyedUnarchiver.unarchiveObject(withFile: filePath) as? [Transaction] {
      return transactions
    }
    return []
  }
  
  func save(transactions: [Transaction]) {
    NSKeyedArchiver.archiveRootObject(transactions, toFile: filePath)
  }
}
