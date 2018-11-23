//
//  SyncViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit
import MultipeerConnectivity

extension Notification.Name {
  static let syncDidDismiss = Notification.Name("syncDidDismiss")
}

// Responsible for setting up all the pieces requried for sync
class SyncViewController: UIViewController {
  let syncManager = P2PSyncManager()
  weak var nameDelegate: SyncNameUpdateDelegate?
  weak var mergeDelegate: MergeDelegate?
  weak var transactionsDataSource: SyncTransactionsDataSource?
  
  private let syncController = SyncController()
  
  @IBOutlet weak var syncStatusLabel: UILabel!
  @IBOutlet weak var nameChangeMessageLabel: UILabel!
  
  @IBOutlet weak var peersTableView: UITableView!
  private var buddies = [SyncBuddy]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    display(name: Settings.main.syncName)
    syncManager.presentor = self
    syncManager.dataDelegate = syncController
    
    syncController.mergeDelegate = mergeDelegate
    syncController.dataSender = syncManager
    syncController.dataSource = transactionsDataSource
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
    self.syncStatusLabel.text = newStatus
  }
  
  func updated(availableBuddies: [SyncBuddy]) {
    buddies = availableBuddies
    peersTableView.reloadData()
  }
  
  func syncRequestReceived(fromBuddy buddy: SyncBuddy, handler: @escaping SyncRequestHandler) {
    let alert = UIAlertController(title: "Sync request",
                                message: "Do you want to sync with \(buddy.name)?",
                         preferredStyle: .alert)
    let noAction = UIAlertAction(title: "No", style: .default) { [weak self] _ in
      handler(false)
      self?.updateStatus(to: "You declined sync request")
    }
    alert.addAction(noAction)
    let yesAction = UIAlertAction(title: "Yes", style: .default) { _ in
      handler(true)
    }
    alert.addAction(yesAction)
    self.present(alert, animated: true, completion: nil)
  }
  
  func requestDeclined(byBuddy buddy: SyncBuddy) {
    updateStatus(to: "\(buddy.name) declined sync request")
  }
  
  func syncInProgress(withBuddy buddy: SyncBuddy) {
    updateStatus(to: "Syncing with \(buddy.name)")
  }
  
  func syncFinished(withBuddy: SyncBuddy) {
    updateStatus(to: "Sync finished")
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      self?.dismissWithNotification()
    }
  }
  
  func sync(withBuddy: SyncBuddy, failedWithMessage message: String) {
    updateStatus(to: "Sync failed: \(message)")
  }
}

extension SyncViewController: SyncNameUpdateDelegate {
  func display(name: String) {
    nameChangeMessageLabel.text = """
    We sign your transactions with "\(name)".
    Feel free to change your name here 👇
    """
  }
  
  func nameUpdated(from oldName: String, to newName: String) {
    display(name: newName)
    nameDelegate?.nameUpdated(from: oldName, to: newName)
    syncManager.deviceNameUpdated(toName: newName)
  }
}

extension SyncViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return buddies.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cellID = "peerCellID"
    let cell: UITableViewCell
    if let dequeuedCell = tableView.dequeueReusableCell(withIdentifier: cellID) {
      cell = dequeuedCell
    } else {
      cell = UITableViewCell(style: .default, reuseIdentifier: cellID)
    }
    
    cell.textLabel?.text = buddies[indexPath.row].name
    return cell
  }
}

extension SyncViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let buddy = buddies[indexPath.row]
    syncManager.inviteToSync(buddy: buddy)
    updateStatus(to: "Waiting a response from \(buddy.name)")
  }
}
