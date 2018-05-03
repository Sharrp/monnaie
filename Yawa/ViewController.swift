//
//  ViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/01.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
  var tap: UITapGestureRecognizer!
  var longPress: UILongPressGestureRecognizer!
  let syncManager = SyncManager()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    syncManager.delegate = self
    
    tap = UITapGestureRecognizer(target: self, action: #selector(tapHandler(gesture:)))
    view.addGestureRecognizer(tap)
    
    longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressHandler(gesture:)))
    view.addGestureRecognizer(longPress)
  }
  
  @objc func tapHandler(gesture: UITapGestureRecognizer) {
    if gesture.state == .ended {
      guard let data = "I'm \(UIDevice.current.name)".data(using: .utf8) else { return }
      syncManager.send(data: data)
    }
  }
  
  @objc func longPressHandler(gesture: UILongPressGestureRecognizer) {
    if gesture.state == .began {
      syncManager.prepareSync()
    }
  }
}

extension ViewController: SyncDelegate {
  func readyToSync() {
    print("Ready to send messages")
  }
  
  func receive(data: Data) {
    guard let msg = String(data: data as Data, encoding: .utf8) else { return }
    print("\(UIDevice.current.name) --- \(msg)")
  }
}
