//
//  TransactionCell.swift
//  monnaie
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

protocol TransactionComposerDelegate: AnyObject {
  func didSwitch(toMode: TransactionComposerMode, animated: Bool)
  func amountChangedValidity(isValid: Bool)
  func setDateToToday()
}

typealias ModeSwitchAnimation = () -> ()

class TransactionComponserView: UIView {
  weak var delegate: TransactionComposerDelegate?
  
  private let margin: CGFloat = 6
  private let baseSize: CGFloat = 56
  private let amountButtonWidth: CGFloat = 91
  var padding: CGFloat {
    return dateButton.frame.origin.y
  }
  var currency: Currency = Currency.defaultCurrency {
    didSet {
      updatePlaceholder(sign: currency.sign)
      guard let amount = amountInput.text else { return } // assumes there is no sign in the input
      amountLabel.text = currency.sign + amount
    }
  }
  
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
  private let categoryLabel = UILabel()
  
  @IBOutlet weak var dateButton: UIButton!
  
  @IBOutlet weak var dateShadowView: ShadowRoundedView!
  @IBOutlet weak var categoryShadowView: ShadowRoundedView!
  @IBOutlet weak var amountShadowView: ShadowRoundedView!
  
  private(set) var mode: TransactionComposerMode = .waitingForInput
  
  func set(mode: TransactionComposerMode, animated: Bool) {
    set(mode: mode, animated: animated, enableDelegation: false)
  }
  
  private func set(mode: TransactionComposerMode, animated: Bool, enableDelegation: Bool) {
    if mode == .waitingForInput && self.mode != mode {
      amountInput.text = ""
    }
    
    self.mode = mode
    layoutIfNeeded()
    
    var animations = [ModeSwitchAnimation]()
    animations.append(dateButtonAnimation(forMode: mode))
    animations.append(categoryButtonAnimation(forMode: mode))
    animations.append(amountElementsAnimation(forMode: mode))
    
    if animated {
      UIViewPropertyAnimator(duration: Animation.duration, curve: Animation.curve) { [weak self] in
        animations.forEach{ $0() }
        self?.layoutIfNeeded()
      }.startAnimation()
    } else {
      animations.forEach{ $0() }
      layoutIfNeeded()
    }
    
    if enableDelegation {
      delegate?.didSwitch(toMode: mode, animated: animated)
    }
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
    
    let selectedBorderColor = Color.border.cgColor
    categoryButton.layer.borderColor = selectedBorderColor
    categoryLabel.text = TransactionCategory.defaultCategory.name
    categoryLabel.textColor = Color.accentText
    categoryLabel.font = Font.main
    categoryLabel.frame = CGRect(x: 74, y: 14, width: 123, height: 28)
    categoryButton.clipsToBounds = true
    categoryButton.addSubview(categoryLabel)
    
    updatePlaceholder(sign: currency.sign)
    amountInput.layer.anchorPoint = CGPoint(x: 1, y: 0.5)
    amountLabel.layer.anchorPoint = CGPoint(x: 1, y: 0.5)
    amountButton.layer.anchorPoint = CGPoint(x: 1, y: 0.5)
    
    dateButton.layer.borderColor = Color.border.cgColor
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
  
  func display(transaction: Transaction) {
    set(date: transaction.date)
    set(category: transaction.category)
    amountLabel.text = formatMoney(amount: transaction.amount, currency: currency)
    amountInput.text = formatMoney(amount: transaction.amount, currency: currency, symbolEnabled: false)
  }
  
  @IBAction func dateButtonTouched() {
    if mode == .date {
      delegate?.setDateToToday()
      return
    }
    set(mode: .date, animated: true, enableDelegation: true)
  }
  
  @IBAction func categoryButtonTouched() {
    set(mode: .category, animated: true, enableDelegation: true)
  }
  
  @IBAction func amountButtonTouched() {
    set(mode: .amount, animated: true, enableDelegation: true)
  }
  
  func reset(animated: Bool = true) {
    amountInput.text = ""
    set(mode: .waitingForInput, animated: animated, enableDelegation: false)
  }
  
  private func updatePlaceholder(sign: String) {
    let text = "\(sign)0"
    let coloredPlaceholder = NSAttributedString(string: text, attributes: [.foregroundColor: Color.border])
    amountInput.attributedPlaceholder = coloredPlaceholder
  }
  
  func set(date: Date) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMM"
    let month = dateFormatter.string(from: date).uppercased()
    let dayOfMonth = Calendar.current.component(.day, from: date)
    
    let formattedTitle = NSMutableAttributedString(string: "\(dayOfMonth)\n\(month)")
    let font = UIFont.systemFont(ofSize: 16, weight: .bold)
    let range = NSRange(location: 0, length: 2) // 2 = 1 digit + new line or 2 digits
    formattedTitle.addAttribute(.font, value: font, range: range)
    dateButton.setAttributedTitle(formattedTitle, for: .normal)
  }
  
  func set(category: TransactionCategory) {
    categoryButton.setTitle(category.emoji, for: .normal)
    categoryLabel.text = category.name
  }

  private func amountElementsAnimation(forMode mode: TransactionComposerMode) -> ModeSwitchAnimation {
    let scaleFactor: CGFloat = 3
    let downscale = CGAffineTransform(scaleX: 1/scaleFactor, y: 1/scaleFactor)
    return { [weak self] in
      switch mode {
      case .waitingForInput, .amount:
        self?.amountInput.becomeFirstResponder()
        self?.amountInput.transform = .identity
        self?.amountInput.alpha = 1
        self?.amountLabel.transform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        self?.amountLabel.alpha = 0
        self?.amountButton.transform = downscale
        self?.amountButton.alpha = 0
        self?.amountShadowView.transform = downscale
        self?.amountShadowView.alpha = 0
      case .category, .date:
        self?.amountInput.resignFirstResponder()
        self?.amountInput.transform = downscale
        self?.amountInput.alpha = 0
        self?.amountLabel.transform = .identity
        self?.amountLabel.alpha = 1
        self?.amountButton.transform = .identity
        self?.amountButton.alpha = 1
        self?.amountShadowView.transform = .identity
        self?.amountShadowView.alpha = 1
      case .table:
        self?.amountInput.resignFirstResponder()
        self?.amountInput.transform = downscale
        self?.amountInput.alpha = 0
        self?.amountLabel.transform = .identity
        self?.amountLabel.alpha = 1
        self?.amountButton.transform = downscale
        self?.amountButton.alpha = 0
        self?.amountShadowView.transform = downscale
        self?.amountShadowView.alpha = 0
      }
    }
  }
  
  private func categoryButtonAnimation(forMode mode: TransactionComposerMode) -> ModeSwitchAnimation {
    // Constraints should be updated immediately
    switch mode {
    case .waitingForInput:
      self.categoryButtonWidth.constant = baseSize
    case .amount:
      self.categoryButtonWidth.constant = baseSize
    case .date, .category:
      self.categoryButtonWidth.constant = UIScreen.main.bounds.width - 4 * margin - categoryButton.bounds.height - amountButtonWidth
    case .table:
      self.categoryButtonWidth.constant = UIScreen.main.bounds.width - 2 * 8 // fucking new margin
    }
    
    return { [weak self] in
      self?.categoryButton.layer.borderWidth = mode == .category ? 1 : 0
      self?.categoryButton.backgroundColor = mode == .category ? .clear : .white
      self?.categoryButton.alpha = mode == .waitingForInput ? 0 : 1
      self?.categoryShadowView.alpha = mode == .date || mode == .amount || mode == .table ? 1 : 0
      
      guard let strongSelf = self else { return }
      var categoryTitleInset = UIEdgeInsets(top: 0, left: 13, bottom: 0, right: 0)
      let transform: CGAffineTransform
      switch mode {
      case .waitingForInput:
        transform = CGAffineTransform(translationX: -Animation.appearceWithShfit, y: 0)
      case .amount:
        transform = .identity
      case .date:
        transform = .identity
      case .category:
        transform = .identity
      case .table:
        transform = CGAffineTransform(translationX: -strongSelf.baseSize-strongSelf.margin+2, y: 0)
        categoryTitleInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
      }
      self?.categoryButton.transform = transform
      self?.categoryShadowView.transform = transform
      self?.categoryButton.titleEdgeInsets = categoryTitleInset
      
      // Shadow should be animated separately with CABasicAnimation ¯\_(ツ)_/¯
      let shadowAnimation = CABasicAnimation(keyPath: "shadowPath")
      shadowAnimation.fillMode = .forwards
      shadowAnimation.isRemovedOnCompletion = false
      shadowAnimation.duration = Animation.duration
      shadowAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      shadowAnimation.fromValue = UIBezierPath(rect: strongSelf.categoryButton.bounds).cgPath
      var newFrame = strongSelf.categoryButton.bounds
      newFrame.size.width = strongSelf.categoryButtonWidth.constant
      shadowAnimation.toValue = UIBezierPath(rect: newFrame).cgPath
      self?.categoryShadowView.layer.add(shadowAnimation, forKey: "shadowPath")
    }
  }
  
  private func dateButtonAnimation(forMode mode: TransactionComposerMode) -> ModeSwitchAnimation {
    return { [weak self] in
      self?.dateButton.backgroundColor = mode == .date ? .clear : .white
      let isVisible = mode == .category || mode == .date || mode == .amount
      self?.dateButton.alpha = isVisible ? 1 : 0
      self?.dateButton.layer.borderWidth = mode == .date ? 1 : 0
      self?.dateShadowView.alpha = isVisible && mode != .date ? 1 : 0
      
      let transform: CGAffineTransform
      switch mode {
      case .waitingForInput:
        transform = CGAffineTransform(translationX: -Animation.appearceWithShfit, y: 0)
      case .amount, .category, .date:
        transform = .identity
      case .table:
        transform = CGAffineTransform(translationX: -5*Animation.appearceWithShfit, y: 0)
      }
      self?.dateButton.transform = transform
      self?.dateShadowView.transform = transform
    }
  }
  
  @IBAction func amountTextChanged() {
    delegate?.amountChangedValidity(isValid: inputHasValidContent)
    guard let textLength = amountInput.text?.count else { return }
    let nextMode: TransactionComposerMode = textLength > 0 ? .amount : .waitingForInput
    set(mode: nextMode, animated: true, enableDelegation: true)
    if let amount = amount {
      amountLabel.text = formatMoney(amount: amount, currency: currency)
    }
  }
}
