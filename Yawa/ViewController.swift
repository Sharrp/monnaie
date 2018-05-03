import UIKit
import MultipeerConnectivity

class ViewController: UIViewController {
  
  let serviceType = "yawasync"
  let displayNameKey = "displayNameKey"
  let peerIDKey = "peerIDKey"
  
  var browser : MCNearbyServiceBrowser!
  var assistant: MCNearbyServiceAdvertiser!
  var session : MCSession!
  var myPeerID: MCPeerID!
  let appStartDate = Date()
  
  var tap: UITapGestureRecognizer!
  var longPress: UILongPressGestureRecognizer!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let displayName = UIDevice.current.name
    let oldDisplayName = UserDefaults.standard.string(forKey: displayNameKey)
    
    if oldDisplayName == displayName {
      guard let peerIDData = UserDefaults.standard.data(forKey: peerIDKey) else {
        print("Getting peerIDData from UserDefaults failed")
        return
      }
      guard let archivedPeerID = NSKeyedUnarchiver.unarchiveObject(with: peerIDData) as? MCPeerID else {
        print("Unarchiving peerIDData failed")
        return
      }
      myPeerID = archivedPeerID
    } else {
      myPeerID = MCPeerID(displayName: displayName)
      let peerIDData = NSKeyedArchiver.archivedData(withRootObject: myPeerID)
      UserDefaults.standard.set(peerIDData, forKey: peerIDKey)
      UserDefaults.standard.set(displayName, forKey: displayNameKey)
      UserDefaults.standard.synchronize()
    }
    
    session = MCSession(peer: myPeerID)
    session.delegate = self
    
    browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
    browser.delegate = self
    
    assistant = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
    assistant.delegate = self
    assistant.startAdvertisingPeer()
    
    tap = UITapGestureRecognizer(target: self, action: #selector(tapHandler(gesture:)))
    view.addGestureRecognizer(tap)
    
    longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressHandler(gesture:)))
    view.addGestureRecognizer(longPress)
  }
  
  @objc func tapHandler(gesture: UITapGestureRecognizer) {
    if gesture.state == .ended {
      sendChat()
    }
  }
  
  @objc func longPressHandler(gesture: UILongPressGestureRecognizer) {
    if gesture.state == .began {
      print("\(myPeerID.displayName) started browsing")
      browser.startBrowsingForPeers()
    }
  }
  
  func sendChat() {
    let text = "\(UIDevice.current.model) \(Date().timeIntervalSince(appStartDate))"
    let data = text.data(using: .utf8, allowLossyConversion: false)!
    
    do {
      try session.send(data, toPeers: session.connectedPeers, with: .reliable)
      print("Message sent from \(myPeerID.displayName)")
    } catch {
      print("Sending error: \(error)")
    }
  }
  
  func updateChat(text: String, fromPeer peerID: MCPeerID) {
    print("\(peerID.displayName): \(text)")
  }
}

extension ViewController: MCNearbyServiceBrowserDelegate {
  public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
    print("Found peer: \(peerID)")
    browser.invitePeer(peerID, to: session, withContext: nil, timeout: 5)
  }
  
  public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    print("Lost peer: \(peerID)")
  }
  
  public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
    print("Didn't start browsing: \(error)")
  }
}

extension ViewController: MCSessionDelegate {
  public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    // Called when a peer sends an NSData to us
    DispatchQueue.main.async { [unowned self] in
      guard let msg = String(data: data as Data, encoding: .utf8) else { return }
      self.updateChat(text: msg, fromPeer: self.myPeerID)
    }
  }
  
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) { }
  func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
  public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
  public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
}

extension ViewController: MCNearbyServiceAdvertiserDelegate {
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Swift.Void) {
    print("Invitation from: \(peerID.displayName)")
    invitationHandler(true, session)
  }
  
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
    print("didNotStartAdvertisingPeer: \(error)")
  }
}
