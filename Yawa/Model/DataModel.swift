//
//  Transaction.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation

enum TransactionCategory: Int, CustomStringConvertible {
  case grocery
  case cafe
  case other
  
  var description: String {
    switch self {
    case .grocery:
      return "Grocery"
    case .cafe:
      return "Cafe"
    case .other:
      return "Other"
    }
  }
}

struct Transaction {
  let amount: Float
  let category: TransactionCategory
  let author: String
  let date: Date
}
