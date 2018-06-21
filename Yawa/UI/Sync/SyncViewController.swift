//
//  SyncViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit
import MultipeerConnectivity

protocol SyncUpdateDelegate: AnyObject {
  func reset(transactionsTo transactions: [Transaction])
}

extension Notification.Name {
  static let syncDidDismiss = Notification.Name("syncDidDismiss")
}

class SyncViewController: UIViewController {
  private let syncManager = SyncManager()
  private let syncHistoryManager = SyncHistoryManager()
  weak var delegate: SyncUpdateDelegate?
  weak var nameDelegate: SyncNameUpdateDelegate?
  var transactionsToSync: [Transaction]!
  
  @IBOutlet weak var syncStatusLabel: UILabel!
  @IBOutlet weak var nameChangeMessageLabel: UILabel!
  
  @IBOutlet weak var peersTableView: UITableView!
  private var peers = [SyncBuddy]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    display(name: Settings.main.syncName)
    syncManager.presentor = self
    syncManager.dataDelegate = self
    syncManager.prepareSync()
  }
  
  private func dismissWithNotification() {
    self.dismiss(animated: true, completion: nil)
    NotificationCenter.default.post(name: .syncDidDismiss, object: nil)
  }
  
  @IBAction func cancel() {
    syncManager.stopSync()
    dismissWithNotification()
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    guard segue.identifier == "name-edit" else { return }
    guard let vc = segue.destination as? SyncNameViewController else { return }
    vc.delegate = self
  }
}

extension SyncViewController: SyncPresentorDelegate {
  private func updateStatus(to newStatus: String) {
    DispatchQueue.main.async { [unowned self] in
      self.syncStatusLabel.text = newStatus
    }
  }
  
  func updated(availableBuddies: [SyncBuddy]) {
    peers = availableBuddies
    peersTableView.reloadData()
  }
  
  func readyToSync(withPeer peerID: MCPeerID) {
    let syncData = SyncData(transactions: transactionsToSync, mode: .merge)
    let data = NSKeyedArchiver.archivedData(withRootObject: syncData)
    syncManager.send(data: data, toPeer: peerID)
    updateStatus(to: "Syncing with \(peerID.displayName)")
  }
}

extension SyncViewController: SyncDataDelegate {
  func receive(data: Data, fromPeer peerID: MCPeerID) {
    guard let syncData = NSKeyedUnarchiver.unarchiveObject(with: data) as? SyncData else {
      print("Failed to unarchive transactions from peer")
      updateStatus(to: "Sync failed. Reopen this view")
      return
    }
    
    let transactions: [Transaction]
    switch syncData.mode {
    case .merge:
      let previousSyncTransactions = syncHistoryManager.transactionsListAtPreviousSync(forDeviceID: syncData.deviceID)
      transactions = merge(local: transactionsToSync,
                           remote: syncData.transactions,
                           previousSyncTransactions: previousSyncTransactions)
      
      // Send merged data back
      let syncData = SyncData(transactions: transactions, mode: .update)
      let data = NSKeyedArchiver.archivedData(withRootObject: syncData)
      syncManager.send(data: data, toPeer: peerID)
    case .update:
      transactions = syncData.transactions
    }
    
    delegate?.reset(transactionsTo: transactions)
    let thisSyncTransactionsList = transactions.map { $0.hashValue }
    syncHistoryManager.update(transactionsList: thisSyncTransactionsList, forDeviceID: syncData.deviceID)
    updateStatus(to: "Sync is finished")
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      guard let strongSelf = self else { return }
      strongSelf.dismissWithNotification()
    }
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
    
    return merged.sorted { $0.date < $1.date }
  }
}

extension SyncViewController: SyncNameUpdateDelegate {
  func display(name: String) {
    nameChangeMessageLabel.text = """
    We sign your transactions with "\(name)".
    Feel free to change your name here 👇
    """
  }
  
  func nameUpdated(toName name: String) {
    display(name: name)
    nameDelegate?.nameUpdated(toName: name)
    syncManager.deviceNameUpdated(toName: name)
  }
}

extension SyncViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return peers.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cellID = "peerCellID"
    let cell: UITableViewCell
    if let dequeuedCell = tableView.dequeueReusableCell(withIdentifier: cellID) {
      cell = dequeuedCell
    } else {
      cell = UITableViewCell(style: .default, reuseIdentifier: cellID)
    }
    
    cell.textLabel?.text = peers[indexPath.row].name
    return cell
  }
}

extension SyncViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    syncManager.inviteToSync(buddy: peers[indexPath.row])
  }
}
