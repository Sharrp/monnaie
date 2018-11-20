//
//  AppDelegate.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/01.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  private let coordinator = Coordinator()
  private var csvImportURL: URL?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    csvImportURL = launchOptions?[UIApplication.LaunchOptionsKey.url] as? URL // to handle it later in didBecomeActive
    return true
  }
  
  func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    coordinator.importCSV(fileURL: url)
    return true
  }
  
  func applicationDidBecomeActive(_ application: UIApplication) {
    if !coordinator.isInitialized {
      // All these casts should crash immediately for easier debug (there is no case when they can fail legally)
      let guillotineVC = window?.rootViewController as! GuillotineViewController
      let projectionsVC = guillotineVC.bladeViewController as! ProjectionsViewController
      let editVC = guillotineVC.baseViewController as! EditTransactionController
      coordinator.guillotineViewController = guillotineVC
      coordinator.projectionsViewController = projectionsVC
      coordinator.editTransactionController = editVC
      
      coordinator.appDidFinishLaunching()
    }
    
    guard let fileURL = csvImportURL else { return }
    csvImportURL = nil
    coordinator.importCSV(fileURL: fileURL)
  }
}

