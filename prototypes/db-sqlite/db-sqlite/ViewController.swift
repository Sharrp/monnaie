//
//  ViewController.swift
//  db-sqlite
//
//  Created by Anton Vronskii on 2018/10/14.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
  private let wallet = TransactionsController()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
//    var transaction = Transaction(amount: 1, category: .cafe, authorName: "Antoha", transactionDate: Date())
//    wallet.add(transaction: transaction)
//    let transaction = Transaction(amount: 3, category: .bills, authorName: "Marinka", transactionDate: Date())
//    wallet.add(transaction: transaction)
    
//    wallet.update()
    wallet.readValues()
  }
}

