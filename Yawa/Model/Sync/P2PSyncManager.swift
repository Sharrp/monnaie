//
//  SyncManager.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit
import MultipeerConnectivity

struct SyncBuddy: Equatable {
  let peerID: MCPeerID
  let emoji: String
  let deviceID: String
  
  var name: String {
    return peerID.displayName
  }
  
  public static func == (lhs: SyncBuddy, rhs: SyncBuddy) -> Bool {
    return lhs.peerID == rhs.peerID
  }
}

// Incapsulates objects data need to request sync and respond to it
// As well as data send during sync
enum SyncRequestMode: Int {
  case requested
  case declined
  case active
}

class SyncRequest: NSObject, NSCoding {
  let mode: SyncRequestMode
  let deviceID: String
  let data: Data?
  
  init(mode: SyncRequestMode, data: Data? = nil) {
    self.mode = mode
    deviceID = deviceUniqueIdentifier()
    self.data = data
    
    super.init()
  }
  
  required init(coder decoder: NSCoder) {
    let modeValue = decoder.decodeInteger(forKey: "mode")
    mode = SyncRequestMode(rawValue: modeValue)!
    deviceID = decoder.decodeObject(forKey: "deviceID") as! String
    data = decoder.decodeObject(forKey: "data") as? Data
  }
  
  func encode(with coder: NSCoder) {
    coder.encode(mode.rawValue, forKey: "mode")
    coder.encode(deviceID, forKey: "deviceID")
    coder.encode(data, forKey: "data")
  }
  
  func archived() -> Data {
    return NSKeyedArchiver.archivedData(withRootObject: self)
  }
}

typealias SyncRequestHandler = (Bool) -> Void

protocol SyncPresentorDelegate: AnyObject {
  func updated(availableBuddies: [SyncBuddy])
  
  func syncRequestReceived(fromBuddy: SyncBuddy, handler: @escaping SyncRequestHandler)
  func requestDeclined(byBuddy: SyncBuddy)
  
  func syncInProgress(withBuddy: SyncBuddy)
  func syncFinished(withBuddy: SyncBuddy)
  func sync(withBuddy: SyncBuddy, failedWithMessage: String)
}

protocol SyncDataDelegate: AnyObject {
  func canStartSync(withBuddy buddy: SyncBuddy)
  func receive(data: Data, fromBuddy: SyncBuddy)
}

protocol SyncDataSender: AnyObject {
  func send(data: Data, toBuddy: SyncBuddy)
  func allDataSent(toBuddy: SyncBuddy)
}

class P2PSyncManager: NSObject {
  private let serviceType = "yawasync"
  private let displayNameKey = "displayNameKey"
  private let peerIDKey = "peerIDKey"
  private let emojiKey = "emoji"
  
  private var session: MCSession!
  private var assistant: MCNearbyServiceAdvertiser!
  private var browser: MCNearbyServiceBrowser!
  private var availableToSyncBuddies = [SyncBuddy]()
  private let permissionsManager = SyncPermissionsManager()
  
  private var peerIDhashToDeviceID = [Int: String]()
  
  weak var presentor: SyncPresentorDelegate?
  weak var dataDelegate: SyncDataDelegate?

  override init() {
    super.init()
    
    let peerID: MCPeerID
    if let savedPeerID = Settings.main.devicePeerID {
      peerID = savedPeerID
    } else {
      peerID = MCPeerID(displayName: Settings.main.syncName)
      Settings.main.devicePeerID = peerID
    }
    
    initializeForSync(asPeerID: peerID)
  }
  
  private func initializeForSync(asPeerID peerID: MCPeerID) {
    session = MCSession(peer: peerID)
    let info = ["deviceID": deviceUniqueIdentifier()]
    assistant = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: info, serviceType: serviceType)
    browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
    
    session.delegate = self
    assistant.delegate = self
    browser.delegate = self
    
    assistant.startAdvertisingPeer()
    browser.startBrowsingForPeers()
  }
  
  private func buddy(withPeerID peerID: MCPeerID) -> SyncBuddy? {
    return availableToSyncBuddies.first(where: { $0.peerID == peerID })
  }
  
  func inviteToSync(buddy: SyncBuddy) {
    guard availableToSyncBuddies.contains(buddy) else { return }
    permissionsManager.allowSync(withDeviceID: buddy.deviceID)
    let request = SyncRequest(mode: .requested)
    transfer(data: request.archived(), toPeer: buddy.peerID)
  }
  
  private func transfer(data: Data, toPeer peerID: MCPeerID) {
    do {
      try session.send(data, toPeers: [peerID], with: .reliable)
    } catch {
      print("\nSending to \(peerID.displayName) error: \(error)\n")
    }
  }
  
  func stopSync() {
    session.disconnect()
    browser.stopBrowsingForPeers()
    assistant.stopAdvertisingPeer()
  }
  
  func deviceNameUpdated(toName name: String) {
    stopSync()
    let peerID = MCPeerID(displayName: name)
    Settings.main.devicePeerID = peerID
    initializeForSync(asPeerID: peerID)
  }
}

extension P2PSyncManager: SyncDataSender {
  func send(data: Data, toBuddy buddy: SyncBuddy) {
    let request = SyncRequest(mode: .active, data: data)
    transfer(data: request.archived(), toPeer: buddy.peerID)
  }
  
  func allDataSent(toBuddy buddy: SyncBuddy) {
    DispatchQueue.main.async { [weak self] in
      self?.presentor?.syncFinished(withBuddy: buddy)
    }
  }
}

extension P2PSyncManager: MCNearbyServiceBrowserDelegate {
  func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
    print("\nFound peer: \(peerID)\n")
    if let deviceID = info?["deviceID"] {
      peerIDhashToDeviceID[peerID.hash] = deviceID
    }
    let context = ["deviceID": deviceUniqueIdentifier()]
    let data = NSKeyedArchiver.archivedData(withRootObject: context)
    browser.invitePeer(peerID, to: session, withContext: data, timeout: 5)
  }
  
  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    print("\nLost peer: \(peerID)\n")
    if let index = availableToSyncBuddies.index(where: { $0.peerID == peerID  }) {
      availableToSyncBuddies.remove(at: index)
      DispatchQueue.main.async { [weak self] in
        guard let buddies = self?.availableToSyncBuddies else { return }
        self?.presentor?.updated(availableBuddies: buddies)
      }
    }
  }
  
  func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
    print("\nDidn't start browsing for peers: \(error)\n")
  }
}

extension P2PSyncManager: MCSessionDelegate {
  private func startSync(withBuddy buddy: SyncBuddy) {
    DispatchQueue.main.async { [weak self] in
      self?.presentor?.syncInProgress(withBuddy: buddy)
    }
    dataDelegate?.canStartSync(withBuddy: buddy)
  }
  
  private func handle(syncRequest request: SyncRequest, forBuddy buddy: SyncBuddy) {
    if permissionsManager.isAllowedToSync(withDeviceID: request.deviceID) {
      startSync(withBuddy: buddy)
    } else {
      let handler = { [weak self] (allowed: Bool) in
        if allowed {
          self?.permissionsManager.allowSync(withDeviceID: request.deviceID)
          self?.startSync(withBuddy: buddy)
        } else {
          let request = SyncRequest(mode: .declined)
          self?.transfer(data: request.archived(), toPeer: buddy.peerID)
        }
      }
      DispatchQueue.main.async { [weak self] in
        self?.presentor?.syncRequestReceived(fromBuddy: buddy, handler: handler)
      }
    }
  }
  
  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    guard let buddy = buddy(withPeerID: peerID) else { return }
    guard let request = NSKeyedUnarchiver.unarchiveObject(with: data) as? SyncRequest else {
      print("Failed to unarchive sync request from peer")
      DispatchQueue.main.async { [weak self] in
        self?.presentor?.sync(withBuddy: buddy, failedWithMessage: "Sync failed. Reopen this view")
      }
      return
    }
    
    switch request.mode {
    case .requested:
      handle(syncRequest: request, forBuddy: buddy)
    case .declined:
      DispatchQueue.main.async { [weak self] in
        self?.presentor?.requestDeclined(byBuddy: buddy)
      }
    case .active:
      guard let receivedData = request.data else { return }
      DispatchQueue.main.async { [weak self] in
        self?.presentor?.syncInProgress(withBuddy: buddy)
      }
      dataDelegate?.receive(data: receivedData, fromBuddy: buddy)
    }
  }
  
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    if state == .connected {
      guard let deviceID = peerIDhashToDeviceID[peerID.hash] else { return }
      let buddy = SyncBuddy(peerID: peerID, emoji: "🤑", deviceID: deviceID)
      availableToSyncBuddies.append(buddy)
      
      // Auto-sync
      if permissionsManager.isAllowedToSync(withDeviceID: deviceID) {
        // Ensure that only one peer initiates sync
        let shouldInitiateSync = peerID.hash < session.myPeerID.hash
        if shouldInitiateSync {
          startSync(withBuddy: buddy)
        }
        return
      }
    } else if state == .notConnected {
      guard let removeIndex = availableToSyncBuddies.index(where: { $0.peerID == peerID }) else { return }
      availableToSyncBuddies.remove(at: removeIndex)
    }
    DispatchQueue.main.async { [weak self] in
      guard let buddies = self?.availableToSyncBuddies else { return }
      self?.presentor?.updated(availableBuddies: buddies)
    }
  }
  
  func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
  func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
  func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
}

extension P2PSyncManager: MCNearbyServiceAdvertiserDelegate {
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext contextData: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Swift.Void) {
    if let contextData = contextData,
      let context = NSKeyedUnarchiver.unarchiveObject(with: contextData) as? [String: String],
      let deviceID = context["deviceID"] {
      peerIDhashToDeviceID[peerID.hash] = deviceID
    }
    invitationHandler(true, session)
  }
  
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
    print("\ndidNotStartAdvertisingPeer: \(error)\n")
  }
}
