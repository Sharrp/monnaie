//
//  Coordinator.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/11/17.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation

class Coordinator {
  private let dataService = DataService(dbName: "production")
  private let history = HistoryViewModel()
  private let summary = SummaryViewModel()
  private let monthSwitch = MonthSwitchViewModel()
  private let addViewModel = AddTransactionViewModel()
  private let editViewModel = EditTransactionViewModel()
  private let csvHandler = CSVImportExportHandler()
  
  private(set) var isInitialized = false
  weak var guillotineViewController: GuillotineViewController?
  weak var projectionsViewController: ProjectionsViewController?
  weak var editTransactionController: EditTransactionController?
  
  // Assumes that all view controller variables are set
  func appDidFinishLaunching() {
    // History & summary need monthSwitch so it's set up first
    monthSwitch.collectionView = projectionsViewController?.monthSwitcherCollectionView
    monthSwitch.dataService = dataService
    monthSwitch.selectLastMonth()
    
    history.dataService = dataService
    history.getSelectedMonth = { [weak self] in self?.monthSwitch.selectedMonth }
    summary.getSelectedMonth = { [weak self] in self?.monthSwitch.selectedMonth }
    summary.transactionsController = dataService
    
    monthSwitch.subscribe(callback: history.monthChanged)
    monthSwitch.subscribe(callback: summary.monthChanged)
    
    editTransactionController?.delegate = addViewModel
    
    dataService.subscribe(callback: history.dataServiceUpdated)
    dataService.subscribe(callback: summary.dataServiceUpdated)
    dataService.subscribe(callback: monthSwitch.dataServiceUpdated)
    
    guillotineViewController?.subscribeToCancel(callback: addViewModel.guillotineCancel)
    guillotineViewController?.subscribeToCancel(callback: editViewModel.guillotineCancel)
    
    addViewModel.dataService = dataService
    addViewModel.guillotine = guillotineViewController
    addViewModel.viewController = editTransactionController
    addViewModel.didFinishLaunching()
    
    editViewModel.dataService = dataService
    editViewModel.guillotine = guillotineViewController
    
    history.editor = editViewModel
    
    // Only after all assigned projections are ready
    projectionsViewController?.projectors = [history, summary]
    
    csvHandler.presentor = guillotineViewController
    csvHandler.generateCSV = { [weak self] in self?.dataService.exportDataAsCSV() }
    csvHandler.importer = dataService
    
    isInitialized = true
  }
  
  func importCSV(fileURL: URL) {
    csvHandler.importCSV(fileURL: fileURL)
  }
}
