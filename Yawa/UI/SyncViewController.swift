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
  var delegate: TransactionsUpdateDelegate?
  var transactionsToSync: [Transaction]!
  private var dataSent = false
  
  @IBOutlet var syncStatusLabel: UILabel!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    syncManager.delegate = self
    syncManager.prepareSync()
  }
  
  @IBAction func cancel() {
    self.dismiss(animated: true, completion: nil)
  }
}

extension SyncViewController: SyncDelegate {
  func readyToSync() {
    print("Ready to sync")
    let data = NSKeyedArchiver.archivedData(withRootObject: transactionsToSync)
    syncManager.send(data: data)
    dataSent = true
    
    DispatchQueue.main.async { [unowned self] in
      self.syncStatusLabel.text = "Syncing..."
    }
  }
  
  func receive(data: Data) {
    guard let peerTransactions = NSKeyedUnarchiver.unarchiveObject(with: data) as? [Transaction] else {
      print("Failed to unarchive transactions from peer")
      DispatchQueue.main.async { [unowned self] in
        self.syncStatusLabel.text = "Sync failed. Reopen this view"
      }
      return
    }
    
    var allTransactions = [Transaction]()
    allTransactions.append(contentsOf: peerTransactions)
    allTransactions.append(contentsOf: transactionsToSync)
    allTransactions = Array(Set(allTransactions))
    allTransactions.sort { $0.date < $1.date }
    delegate?.reset(transactionsTo: allTransactions)
    
    if !dataSent {
      let data = NSKeyedArchiver.archivedData(withRootObject: transactionsToSync)
      syncManager.send(data: data)
      DispatchQueue.main.async { [unowned self] in
        self.dataSent = true
      }
    }
    
    DispatchQueue.main.async { [unowned self] in
      self.syncStatusLabel.text = "Sync is finished"
    }
  }
}
