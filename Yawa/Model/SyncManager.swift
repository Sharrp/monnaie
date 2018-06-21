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
  
  var name: String {
    return peerID.displayName
  }
  
  public static func == (lhs: SyncBuddy, rhs: SyncBuddy) -> Bool {
    return lhs.peerID == rhs.peerID
  }
}

protocol SyncPresentorDelegate: AnyObject {
  func updated(availableBuddies: [SyncBuddy])
  
  func readyToSync(withPeer: MCPeerID)
}

protocol SyncDataDelegate: AnyObject {
  func receive(data: Data, fromPeer: MCPeerID)
}

class SyncManager: NSObject {
  private let serviceType = "yawasync"
  private let displayNameKey = "displayNameKey"
  private let peerIDKey = "peerIDKey"
  private let emojiKey = "emoji"
  
  private var session: MCSession!
  private var assistant: MCNearbyServiceAdvertiser!
  private var browser: MCNearbyServiceBrowser!
  private var availableToSyncBuddies = [SyncBuddy]()
  
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
    
    setupSession(withPeerID: peerID)
    session.delegate = self
    assistant.delegate = self
    browser.delegate = self
  }
  
  private func setupSession(withPeerID peerID: MCPeerID) {
    session = MCSession(peer: peerID)
    assistant = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
    browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
  }
  
  func prepareSync() {
    assistant.startAdvertisingPeer()
    browser.startBrowsingForPeers()
  }
  
  func inviteToSync(buddy: SyncBuddy) {
    guard availableToSyncBuddies.contains(buddy) else { return }
    browser.invitePeer(buddy.peerID, to: session, withContext: nil, timeout: 5)
  }
  
  func send(data: Data, toPeer peerID: MCPeerID) {
    do {
      try session.send(data, toPeers: [peerID], with: .reliable)
    } catch {
      print("Sending to \(peerID.displayName) error: \(error)")
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
    setupSession(withPeerID: peerID)
    prepareSync()
    Settings.main.devicePeerID = peerID
  }
}

extension SyncManager: MCNearbyServiceBrowserDelegate {
  func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
    print("Found peer: \(peerID)")
    let emoji = info?[emojiKey] ?? "🤑"
    let buddy = SyncBuddy(peerID: peerID, emoji: emoji)
    availableToSyncBuddies.append(buddy)
    presentor?.updated(availableBuddies: availableToSyncBuddies)
  }
  
  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    print("Lost peer: \(peerID)")
    if let index = availableToSyncBuddies.index(where: { $0.peerID == peerID  }) {
      availableToSyncBuddies.remove(at: index)
      presentor?.updated(availableBuddies: availableToSyncBuddies)
    }
  }
  
  func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
    print("Didn't start browsing: \(error)")
  }
}

extension SyncManager: MCSessionDelegate {
  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    DispatchQueue.main.async { [unowned self] in
      self.dataDelegate?.receive(data: data, fromPeer: peerID)
    }
  }
  
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    if state == .connected {
      // Ensure that only one peer initiates sync
      let shouldInitiateSync = peerID.hashValue < session.myPeerID.hashValue
      if shouldInitiateSync {
        presentor?.readyToSync(withPeer: peerID)
      }
    }
  }
  
  func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
  func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
  func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
}

extension SyncManager: MCNearbyServiceAdvertiserDelegate {
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Swift.Void) {
    print("Invitation from: \(peerID.displayName)")
    invitationHandler(true, session)
  }
  
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
    print("didNotStartAdvertisingPeer: \(error)")
  }
}
