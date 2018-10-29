//
//  TransactionCell.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/10/27.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

enum TransactionComposerMode: Int {
  case waitingForInput
  case amount
  case category
  case date
  case table
}

protocol TransactionComposerDelegate {
  func didSwitch(toMode: TransactionComposerMode)
  func amountChangedValidity(isValid: Bool)
}

typealias ModeSwitchAnimation = () -> ()

class TransactionComponserView: UIView {
  var delegate: TransactionComposerDelegate?
  private var animator = UIViewPropertyAnimator()
  
  private let margin: CGFloat = 6
  private let baseSize: CGFloat = 56
  private let amountButtonWidth: CGFloat = 89
  
  @IBOutlet weak var amountInput: UITextField!
  @IBOutlet weak var amountInputRightMargin: NSLayoutConstraint!
  @IBOutlet weak var amountLabel: UILabel!
  @IBOutlet weak var amountLabelRightMargin: NSLayoutConstraint!
  @IBOutlet weak var amountButton: UIButton!
  @IBOutlet weak var amountButtonRightMargin: NSLayoutConstraint!
  private var didAnchorPointCorrection = false
  
  @IBOutlet weak var categoryButton: UIButton!
  @IBOutlet weak var categoryButtonLeftMargin: NSLayoutConstraint!
  @IBOutlet weak var categoryButtonWidth: NSLayoutConstraint!
  
  @IBOutlet weak var dateButton: UIButton!
  
  private(set) var mode: TransactionComposerMode = .waitingForInput
  
  func set(mode: TransactionComposerMode, animated: Bool = true) {
    self.mode = mode
    layoutIfNeeded()
    
    var animations = [ModeSwitchAnimation]()
    animations.append(dateButtonAnimation(forMode: mode))
    animations.append(categoryButtonAnimation(forMode: mode))
    animations.append(amountElementsAnimation(forMode: mode))
    
    if animated {
      let animator = UIViewPropertyAnimator(duration: 0.3, curve: .easeInOut, animations: nil)
      animator.addAnimations { [weak self] in
        animations.forEach{ $0() }
        self?.layoutIfNeeded()
      }
      animator.startAnimation()
    } else {
      animations.forEach{ $0() }
      layoutIfNeeded()
    }
    delegate?.didSwitch(toMode: mode)
  }
  
  var amount: Double? {
    return (amountInput.text as NSString?)?.doubleValue
  }
  
  private var inputHasValidContent: Bool {
    guard let value = amount else { return false }
    return value > 0
  }
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
    let selectedBorderColor = UIColor(hex: 0xe6e6e6).cgColor
    categoryButton.layer.borderColor = selectedBorderColor
    
    let coloredPlaceholder = NSAttributedString(string: "¥0", attributes: [.foregroundColor: UIColor(white: 1.0, alpha: 0.3)])
    amountInput.attributedPlaceholder = coloredPlaceholder
    amountInput.layer.anchorPoint = CGPoint(x: 1, y: 0.5)
    amountLabel.layer.anchorPoint = CGPoint(x: 1, y: 0.5)
    amountButton.layer.anchorPoint = CGPoint(x: 1, y: 0.5)
    
    dateButton.layer.borderColor = selectedBorderColor
    dateButton.titleLabel?.numberOfLines = 2
    dateButton.titleLabel?.textAlignment = .center
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    // That's because I need to change anchor point of amount label and input
    // to scale them appropriately during transition
    // anchor points affects positions since Auto-Layout assumes
    // That anchor point is in the center of the view
    if !didAnchorPointCorrection {
      amountInputRightMargin.constant -= amountInput.frame.width / 2
      amountLabelRightMargin.constant -= amountLabel.frame.width / 2
      amountButtonRightMargin.constant -= amountButton.frame.width / 2
      didAnchorPointCorrection = true
    }
  }
  
  @IBAction func dateButtonTouched() {
    set(mode: .date)
  }
  
  @IBAction func categoryButtonTouched() {
    set(mode: .category)
  }
  
  @IBAction func amountButtonTouched() {
    set(mode: .amount)
  }
  
  func reset() {
    amountInput.text = ""
    set(mode: .waitingForInput)
  }
  
  func set(date: Date) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMM"
    let month = dateFormatter.string(from: date).uppercased()
    let dayOfMonth = Calendar.current.component(.day, from: date)
    
    let formattedTitle = NSMutableAttributedString(string: "\(dayOfMonth)\n\(month)")
    let font = UIFont.systemFont(ofSize: 11, weight: .regular)
    let range = NSRange(location: formattedTitle.length - 3, length: 3)
    formattedTitle.addAttribute(.font, value: font, range: range)
    dateButton.setAttributedTitle(formattedTitle, for: .normal)
  }
  
  func set(category: TransactionCategory) {
    categoryButton.setTitle(category.emoji, for: .normal)
  }

  private func amountElementsAnimation(forMode mode: TransactionComposerMode) -> ModeSwitchAnimation {
    let scaleFactor: CGFloat = 3
    let downscale = CGAffineTransform(scaleX: 1/scaleFactor, y: 1/scaleFactor)
    return { [unowned self] in
      switch mode {
      case .waitingForInput, .amount:
        self.amountInput.becomeFirstResponder()
        self.amountInput.transform = .identity
        self.amountInput.alpha = 1
        self.amountLabel.transform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        self.amountLabel.alpha = 0
        self.amountButton.transform = downscale
        self.amountButton.alpha = 0
      case .category, .date:
        self.amountInput.resignFirstResponder()
        self.amountInput.transform = downscale
        self.amountInput.alpha = 0
        self.amountLabel.transform = .identity
        self.amountLabel.alpha = 1
        self.amountButton.transform = .identity
        self.amountButton.alpha = 1
      case .table:
        break
      }
    }
  }
  
  private func categoryButtonAnimation(forMode mode: TransactionComposerMode) -> ModeSwitchAnimation {
    // Constraints should be updated immeditely
    switch mode {
    case .waitingForInput:
      self.categoryButtonWidth.constant = baseSize
    case .amount:
      self.categoryButtonWidth.constant = baseSize
    case .date, .category:
      self.categoryButtonWidth.constant = UIScreen.main.bounds.width - 4 * margin - categoryButton.bounds.height - amountButtonWidth
    case .table:
      break
    }
    
    let xShiftWhenHidden = -2 * (baseSize + margin) - margin
    return { [unowned self] in
      self.categoryButton.layer.borderWidth = mode == .category ? 1 : 0
      self.categoryButton.backgroundColor = mode == .category ? .clear : .white
      
      switch mode {
      case .waitingForInput:
        self.categoryButton.transform = CGAffineTransform(translationX: xShiftWhenHidden, y: 0)
        self.categoryButtonWidth.constant = self.baseSize
      case .amount:
        self.categoryButton.transform = .identity
        self.categoryButtonWidth.constant = self.baseSize
      case .date:
        self.categoryButton.transform = .identity
        self.categoryButtonWidth.constant = UIScreen.main.bounds.width - 4 * self.margin - self.categoryButton.bounds.height - self.amountButtonWidth
      case .category:
        self.categoryButton.transform = .identity
        self.categoryButtonWidth.constant = UIScreen.main.bounds.width - 4 * self.margin - self.categoryButton.bounds.height - self.amountButtonWidth
      case .table:
        break
      }
    }
  }
  
  private func dateButtonAnimation(forMode mode: TransactionComposerMode) -> ModeSwitchAnimation {
    let xShiftWhenHidden = -2 * (baseSize + margin) - margin
    return { [weak self] in
      self?.dateButton.layer.borderWidth = mode == .date ? 1 : 0
      self?.dateButton.backgroundColor = mode == .date ? .clear : .white
      
      switch mode {
      case .waitingForInput:
        self?.dateButton.transform = CGAffineTransform(translationX: xShiftWhenHidden, y: 0)
      case .amount, .category:
        self?.dateButton.transform = .identity
      case .date:
        self?.dateButton.transform = .identity
      case .table:
        break
      }
    }
  }
  
  @IBAction func amountTextChanged() {
    delegate?.amountChangedValidity(isValid: inputHasValidContent)
    guard let textLength = amountInput.text?.count else { return }
    let nextMode: TransactionComposerMode = textLength > 0 ? .amount: .waitingForInput
    set(mode: nextMode)
    if let amount = amount {
      amountLabel.text = formatMoney(amount: amount, currency: .JPY)
    }
  }
}
