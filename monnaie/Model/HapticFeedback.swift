//
//  VibroFeedback.swift
//  monnaie
//
//  Created by Anton Vronskii on 2018/12/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

enum HapticFeedbackType {
  case success
  case warning
  case failure
  case selectionChanged
  case interfaceBump
}

class HapticFeedbackMapper {
  var settings: Settings? {
    didSet {
      vibro.settings = settings
    }
  }
  private let vibro = HapticFeedback()
  
  lazy var monthSwitched: MonthSwitchedCallback = { [weak self] _ in
    self?.vibro.provideFeedback(ofType: .selectionChanged)
  }
  
  lazy var bladeSwitched: GuillotineBladeStateCallback = { [weak self] _ in
    self?.vibro.provideFeedback(ofType: .interfaceBump)
  }
  
  lazy var transactionAdded: TransactionAddedCallback = { [weak self] in
    self?.vibro.provideFeedback(ofType: .success)
  }
  
  lazy var transactionEditingOccured: EditingCallback = { [weak self] event in
    switch event {
    case .started:
      self?.vibro.provideFeedback(ofType: .interfaceBump)
    case .commited:
      self?.vibro.provideFeedback(ofType: .success)
    }
  }
  
  lazy var transactionDeleted: DeleteRequestedCallback = { [weak self] in
    self?.vibro.provideFeedback(ofType: .success)
  }
  
  lazy var tabSwitched: TabSwitchedCallback = { [weak self] _, _ in
    self?.vibro.provideFeedback(ofType: .interfaceBump)
  }
  
  lazy var currencyChanged = { [weak self] in
//    self?.vibro.provideFeedback(ofType: .selectionChanged)
  }
  
  lazy var importEventOccured: ImportEventCallback = { [weak self] type in
    switch type {
    case .initiated:
      self?.vibro.provideFeedback(ofType: .warning)
    case .success:
      self?.vibro.provideFeedback(ofType: .success)
    case .failed:
      self?.vibro.provideFeedback(ofType: .failure)
    }
  }
}

class HapticFeedback {
  var settings: Settings?
  private let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
  private let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
  private let uiFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
  private let successFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
  
  init() {
    // I guess it doesn't make sense prepare them too early but won't hurt
    notificationFeedbackGenerator.prepare()
    selectionFeedbackGenerator.prepare()
    successFeedbackGenerator.prepare()
    uiFeedbackGenerator.prepare()
  }
  
  func provideFeedback(ofType type: HapticFeedbackType) {
    guard let hapticEnabled = settings?.hapticEnabled else { return }
    guard hapticEnabled else { return }
    
    switch type {
    case .success:
//      notificationFeedbackGenerator.notificationOccurred(.success)
      successFeedbackGenerator.impactOccurred()
    case .warning:
      notificationFeedbackGenerator.notificationOccurred(.warning)
    case .failure:
      notificationFeedbackGenerator.notificationOccurred(.error)
    case .selectionChanged:
      selectionFeedbackGenerator.selectionChanged()
    case .interfaceBump:
      uiFeedbackGenerator.impactOccurred()
    }
  }
}
