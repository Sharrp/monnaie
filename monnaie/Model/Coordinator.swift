//
//  Coordinator.swift
//  monnaie
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
  private let settings = Settings()
  
  private(set) var isInitialized = false
  weak var guillotineViewController: GuillotineViewController?
  weak var projectionsViewController: ProjectionsViewController?
  weak var editTransactionController: EditTransactionViewController?
  
  // Assumes that all view controller variables are set
  func appDidFinishLaunching() {
    // History & summary need monthSwitch so it's set up first
    monthSwitch.view = projectionsViewController?.monthSwitchView
    monthSwitch.dataService = dataService
    monthSwitch.settings = settings
    monthSwitch.selectLastMonth()
    
    history.dataService = dataService
    history.getSelectedMonth = monthSwitch.getSelectedMonth
    history.settings = settings
    summary.getSelectedMonth = monthSwitch.getSelectedMonth
    summary.dataService = dataService
    summary.settings = settings
    
    monthSwitch.subscribe(callback: history.monthChanged)
    monthSwitch.subscribe(callback: summary.monthChanged)
    editTransactionController?.delegate = addViewModel
    
    dataService.subscribe(callback: monthSwitch.dataServiceUpdated)
    dataService.subscribe(callback: history.dataServiceUpdated)
    dataService.subscribe(callback: summary.dataServiceUpdated)
    
    guillotineViewController?.subscribeToCancel(callback: addViewModel.guillotineCancel)
    guillotineViewController?.subscribeToCancel(callback: editViewModel.guillotineCancel)
    guillotineViewController?.subscribeForScroll(callback: monthSwitch.bladeScroll)
    guillotineViewController?.subscribeForBladeState(callback: monthSwitch.bladeStateSwitch)
    guillotineViewController?.subscribeForScroll(callback: editTransactionController?.bladeScroll)
    guillotineViewController?.subscribeForBladeState(callback: editTransactionController?.bladeStateSwitch)
    guillotineViewController?.subscribeForScroll(callback: projectionsViewController?.bladeScroll)
    guillotineViewController?.subscribeForBladeState(callback: projectionsViewController?.bladeStateSwitch)
    
    settings.subscribe(callback: monthSwitch.currencyChanged, forSetting: .currency)
    settings.subscribe(callback: history.currencyChanged, forSetting: .currency)
    settings.subscribe(callback: summary.currencyChanged, forSetting: .currency)
    settings.subscribe(callback: editTransactionController?.currencyChanged, forSetting: .currency)
    
    addViewModel.dataService = dataService
    addViewModel.guillotine = guillotineViewController
    addViewModel.viewController = editTransactionController
    addViewModel.settings = settings
    addViewModel.didFinishLaunching()
    
    editViewModel.dataService = dataService
    editViewModel.guillotine = guillotineViewController
    
    history.editor = editViewModel
    
    // Only after all assigned projections are ready
    projectionsViewController?.projectors = [history, summary]
    projectionsViewController?.settings = settings
    editTransactionController?.settings = settings
    
    csvHandler.generateCSV = { [weak self] in self?.dataService.exportDataAsCSV() }
    csvHandler.importer = dataService
    projectionsViewController?.exporter = csvHandler
    
    isInitialized = true
  }
  
  func importCSV(fileURL: URL) {
    guard let vc = guillotineViewController else { return }
    csvHandler.importCSV(fileURL: fileURL, presentor: vc)
  }
}
