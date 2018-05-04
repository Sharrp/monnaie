//
//  SyncManager.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit
import MultipeerConnectivity

protocol SyncDelegate {
  func readyToSync()
  func receive(data: Data)
}

class SyncManager: NSObject {
  private let serviceType = "yawasync"
  private let displayNameKey = "displayNameKey"
  private let peerIDKey = "peerIDKey"
  
  private var myPeerID: MCPeerID!
  private let session: MCSession
  private let assistant: MCNearbyServiceAdvertiser
  private let browser: MCNearbyServiceBrowser
  private var peerFound: MCPeerID?
  
  var delegate: SyncDelegate?
  var isReadyToSync = false

  override init() {
    // Use archived peerID if exists
    let displayName = UIDevice.current.name
    let oldDisplayName = UserDefaults.standard.string(forKey: displayNameKey)
    if oldDisplayName == displayName {
      if let peerIDData = UserDefaults.standard.data(forKey: peerIDKey),
        let archivedPeerID = NSKeyedUnarchiver.unarchiveObject(with: peerIDData) as? MCPeerID {
        myPeerID = archivedPeerID
      }
      else {
        print("Getting peerID from UserDefaults failed")
      }
    }
    
    // Or create a new one if doesn't
    if myPeerID == nil {
      myPeerID = MCPeerID(displayName: displayName)
      let peerIDData = NSKeyedArchiver.archivedData(withRootObject: myPeerID)
      UserDefaults.standard.set(peerIDData, forKey: peerIDKey)
      UserDefaults.standard.set(displayName, forKey: displayNameKey)
      UserDefaults.standard.synchronize()
    }
    
    session = MCSession(peer: myPeerID)
    assistant = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
    browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
    
    super.init()
    
    session.delegate = self
    assistant.delegate = self
    browser.delegate = self
  }
  
  func prepareSync() {
    assistant.startAdvertisingPeer()
    browser.startBrowsingForPeers()
  }
  
  func send(data: Data) {
    guard let peerID = peerFound else { return }
    do {
//      try session.send(data, toPeers: session.connectedPeers, with: .reliable)
      try session.send(data, toPeers: [peerID], with: .reliable)
      print("Message sent from \(myPeerID.displayName)")
    } catch {
      print("Sending error: \(error)")
    }
  }
  
  deinit {
    session.disconnect()
    browser.stopBrowsingForPeers()
    assistant.stopAdvertisingPeer()
  }
}

extension SyncManager: MCNearbyServiceBrowserDelegate {
  func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
    print("Found peer: \(peerID)")
    peerFound = peerID
    browser.invitePeer(peerID, to: session, withContext: nil, timeout: 5)
  }
  
  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    print("Lost peer: \(peerID)")
    if peerFound == peerID {
      peerFound = nil
      isReadyToSync = false
    }
  }
  
  func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
    print("Didn't start browsing: \(error)")
  }
}

extension SyncManager: MCSessionDelegate {
  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    DispatchQueue.main.async { [unowned self] in
      self.delegate?.receive(data: data)
    }
  }
  
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    if state == .connected {
      delegate?.readyToSync()
      isReadyToSync = true
    } else {
      isReadyToSync = false
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
