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
      return "Import finished"
    case .failure:
      return "Import failed"
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

class CSVImportExportHandler: Exporter {
  var generateCSV: GenerateCSVCallback?
  var importer: CSVCompatible?
  
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
    
    let handleImportResult = { (result: CSVImportResult) in
      let alertController = UIAlertController(title: result.title, message: result.message, preferredStyle: .alert)
      let okAction = UIAlertAction(title: "Ok", style: .default)
      alertController.addAction(okAction)
      presentor.present(alertController, animated: true)
      
      removeImportedFile()
    }
    
    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
      removeImportedFile()
    }
    let mergeAction = UIAlertAction(title: "Merge", style: .default) { [weak self] _ in
      let csv = try? String(contentsOf: fileURL)
      guard let result = self?.importer?.importDataFromCSV(csv: csv, mode: .merge) else { return }
      handleImportResult(result)
    }
    
    let message = "Please choose how to add transactions from \"\(fileURL.lastPathComponent)\" to your existing transactions"
    let alertController = UIAlertController(title: "Choose CSV import mode", message: message, preferredStyle: .actionSheet)
    [cancelAction, mergeAction].forEach { alertController.addAction($0) }
    
    guard let isEmpty = importer?.isEmpty() else { return }
    if !isEmpty {
      let replaceAction = UIAlertAction(title: "Replace", style: .destructive) { [weak self] _ in
        let csv = try? String(contentsOf: fileURL)
        guard let result = self?.importer?.importDataFromCSV(csv: csv, mode: .replace) else { return }
        handleImportResult(result)
      }
      alertController.addAction(replaceAction)
    }
    
    presentor.present(alertController, animated: true)
  }
}
