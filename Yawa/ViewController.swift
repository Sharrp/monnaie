import UIKit
import MultipeerConnectivity

class ViewController: UIViewController {
  
  let serviceType = "LCOC-Chat"
  
  var browser : MCBrowserViewController!
  var assistant : MCAdvertiserAssistant!
  var session : MCSession!
  var peerID: MCPeerID!
  let appStartDate = Date()
  
  var tap: UITapGestureRecognizer!
  var longPress: UILongPressGestureRecognizer!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.peerID = MCPeerID(displayName: UIDevice.current.name)
    self.session = MCSession(peer: peerID)
    self.session.delegate = self
    
    // create the browser viewcontroller with a unique service name
    self.browser = MCBrowserViewController(serviceType: serviceType,
                                           session: self.session)
    
    self.browser.delegate = self;
    
    self.assistant = MCAdvertiserAssistant(serviceType:serviceType,
                                           discoveryInfo:nil, session:self.session)
    
    // tell the assistant to start advertising our fabulous chat
    self.assistant.start()
    
    tap = UITapGestureRecognizer(target: self, action: #selector(self.tapHandler(gesture:)))
    view.addGestureRecognizer(tap)
    
    longPress = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressHandler(gesture:)))
    view.addGestureRecognizer(longPress)
  }
  
  @objc func tapHandler(gesture: UITapGestureRecognizer) {
    if gesture.state == .ended {
      sendChat()
    }
  }
  
  @objc func longPressHandler(gesture: UILongPressGestureRecognizer) {
    if gesture.state == .ended {
      showBrowser()
    }
  }
  
  func sendChat() {
    // Bundle up the text in the message field, and send it off to all
    // connected peers
    
    let text = "bulka \(Date().timeIntervalSince(appStartDate))"
    let data = text.data(using: .utf8, allowLossyConversion: false)!
    
//    self.session.sendData(msg, toPeers: self.session.connectedPeers, withMode: MCSessionSendDataMode.Unreliable, error: &error)
    do {
      try session.send(data, toPeers: session.connectedPeers, with: .reliable)
    } catch {
      print("Sending error: \(error)")
    }
    
    self.updateChat(text: text, fromPeer: self.peerID)
  }
  
  // Appends some text to the chat view
  func updateChat(text: String, fromPeer peerID: MCPeerID) {
    let name : String
    
    switch peerID {
    case self.peerID:
      name = "Me"
    default:
      name = peerID.displayName
    }
    
    // Add the name to the message and display it
    print("\(name): \(text)")
  }
  
  func showBrowser() {
    // Show the browser vziew controller
    self.present(self.browser, animated: true, completion: nil)
  }
}

extension ViewController: MCBrowserViewControllerDelegate {
  func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
    // Called when the browser view controller is dismissed (ie the Done
    // button was tapped)
    self.dismiss(animated: true, completion: nil)
  }
  
  func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
    // Called when the browser view controller is cancelled
    self.dismiss(animated: true, completion: nil)
  }
}

extension ViewController: MCSessionDelegate {
  public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    // Called when a peer sends an NSData to us
    DispatchQueue.main.async { [unowned self] in
      guard let msg = String(data: data as Data, encoding: .utf8) else { return }
      self.updateChat(text: msg, fromPeer: peerID)
    }
  }
  
  public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) { }
  public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
  public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
  public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
}
