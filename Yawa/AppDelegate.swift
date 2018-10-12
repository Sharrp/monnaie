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
  private var csvImportURL: URL?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    csvImportURL = launchOptions?[UIApplicationLaunchOptionsKey.url] as? URL // to handle it later in didBecomeActive
    return true
  }
  
  func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
    handleImportCSV(fileURL: url)
    return true
  }
  
  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    guard let fileURL = csvImportURL else { return }
    handleImportCSV(fileURL: fileURL)
  }
  
  private func handleImportCSV(fileURL: URL) {
    guard let rootVC = window?.rootViewController as? GuillotineViewController else { return }
    guard let targetVC = rootVC.bladeViewController as? HistorySummaryViewController else { return }
    let importer = targetVC.dataProvider
    let handleImportResult = { [weak self] (result: TransactionsController.ImportResult) in
      let alertController = UIAlertController(title: result.title, message: result.message, preferredStyle: .alert)
      let okAction = UIAlertAction(title: "Ok", style: .default)
      alertController.addAction(okAction)
      self?.window?.rootViewController?.present(alertController, animated: true)
      
      do {
        try FileManager.default.removeItem(at: fileURL)
      } catch {
        print("Failed deleted imported file: \(error)")
      }
    }
    
    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
    let mergeAction = UIAlertAction(title: "Merge", style: .default) { action in
      let csv = try? String(contentsOf: fileURL)
      let result = importer.importDataFromCSV(csv: csv, mode: .merge)
      handleImportResult(result)
    }
    let replaceAction = UIAlertAction(title: "Replace", style: .destructive) { action in
      let csv = try? String(contentsOf: fileURL)
      let result = importer.importDataFromCSV(csv: csv, mode: .replace)
      handleImportResult(result)
    }
    
    let message = "Please choose how to add transactions from \"\(fileURL.lastPathComponent)\" to your existing transactions"
    let alertController = UIAlertController(title: "Choose CSV import mode", message: message, preferredStyle: .actionSheet)
    [cancelAction, mergeAction, replaceAction].forEach { alertController.addAction($0) }
    window?.rootViewController?.present(alertController, animated: true)
  }
}

