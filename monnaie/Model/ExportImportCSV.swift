//
//  ExportImportCSV.swift
//  monnaie
//
//  Created by Anton Vronskii on 2018/11/17.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

typealias GenerateCSVCallback = () -> String?

protocol CSVCompatible {
  func isEmpty() -> Bool
  func exportDataAsCSV() -> String
  func importDataFromCSV(csv: String?, mode: CSVImportMode) -> CSVImportResult
}

enum CSVImportMode {
  case merge
  case replace
}

enum CSVImportResult {
  case success(String)
  case failure(String)
  
  var title: String {
    switch self {
    case .success:
      return NSLocalizedString("Import finished", comment: "Import finished successfully")
    case .failure:
      return NSLocalizedString("Import failed", comment: "Import failed")
    }
  }
  
  var message: String {
    switch self {
    case .success(let text):
      return text
    case .failure(let text):
      return text
    }
  }
}

protocol Exporter: AnyObject {
  func exportAll(presentor: UIViewController)
}

typealias ImportEventCallback = (ImportEvent) -> Void

enum ImportEvent {
  case initiated
  case success
  case failed
}

class CSVImportExportHandler: Exporter {
  var generateCSV: GenerateCSVCallback?
  var importer: CSVCompatible?
  
  private var callbacks = [ImportEventCallback?]()
  func subscribeForImportEvents(callback: ImportEventCallback?) {
    callbacks.append(callback)
  }
  
  private func notifySubscribers(event: ImportEvent) {
    callbacks.forEach{ $0?(event) }
  }
  
  func exportAll(presentor: UIViewController) {
    guard let csv = generateCSV?() else { return }
    let filename = NSTemporaryDirectory() + "export-finances-\(Date.now).csv".replacingOccurrences(of: " ", with: "_")
    do {
      try csv.write(toFile: filename, atomically: true, encoding: String.Encoding.utf8)
      let fileURL = URL(fileURLWithPath: filename)
      let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
      activityVC.completionWithItemsHandler = { _, completed, _, _ in
        guard completed else { return }
        // Clean entire directory instead of one file
        // in case any of previous exports were interrupted after file creation but before shraing is finished
        FileManager.default.removeFiles(fromDirectory: NSTemporaryDirectory())
      }
      presentor.present(activityVC, animated: true)
    } catch {
      print("Cannot write export file: \(error)")
    }
  }
  
  func importCSV(fileURL: URL, presentor: UIViewController) {
    let removeImportedFile = {
      do {
        try FileManager.default.removeItem(at: fileURL)
      } catch {
        print("Failed deleted imported file: \(error)")
      }
    }
    
    let handleImportResult = { [weak self] (result: CSVImportResult) in
      let alertController = UIAlertController(title: result.title, message: result.message, preferredStyle: .alert)
      let okAction = UIAlertAction(title: "Ok", style: .default)
      alertController.addAction(okAction)
      presentor.present(alertController, animated: true)
      
      switch result {
      case .success:
        self?.notifySubscribers(event: .success)
      case .failure:
        self?.notifySubscribers(event: .failed)
      }
      
      removeImportedFile()
    }
    
    let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel button title")
    let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
      removeImportedFile()
    }
    let mergeTitle = NSLocalizedString("Merge", comment: "Merge csv import option")
    let mergeAction = UIAlertAction(title: mergeTitle, style: .default) { [weak self] _ in
      let csv = try? String(contentsOf: fileURL)
      guard let result = self?.importer?.importDataFromCSV(csv: csv, mode: .merge) else { return }
      handleImportResult(result)
    }
    
    let alertTitle = NSLocalizedString("Choose CSV import mode", comment: "Title of csv import mode alert")
    let messagePart1 = NSLocalizedString("Choose how to add transactions from", comment: "Part 1 of ")
    let messagePart2 = NSLocalizedString("to your existing transactions", comment: "Part 2 of ")
    let message = messagePart1 + " \"\(fileURL.lastPathComponent)\" " + messagePart2
    let alertController = UIAlertController(title: alertTitle, message: message, preferredStyle: .actionSheet)
    [cancelAction, mergeAction].forEach { alertController.addAction($0) }
    
    guard let isEmpty = importer?.isEmpty() else { return }
    if !isEmpty {
      let replaceTitle = NSLocalizedString("Replace", comment: "Replace csv import option")
      let replaceAction = UIAlertAction(title: replaceTitle, style: .destructive) { [weak self] _ in
        let csv = try? String(contentsOf: fileURL)
        guard let result = self?.importer?.importDataFromCSV(csv: csv, mode: .replace) else { return }
        handleImportResult(result)
      }
      alertController.addAction(replaceAction)
    }
    
    presentor.present(alertController, animated: true)
    notifySubscribers(event: .initiated)
  }
}
