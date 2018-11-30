//
//  CategorySelection.swift
//  monnaie
//
//  Created by Anton Vronskii on 2018/09/29.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

protocol CategorySelectionDelegate {
  func didSelect(category: TransactionCategory)
}

class CategoriesProvider: NSObject, UICollectionViewDataSource {
  private let categories = TransactionCategory.allCases()
  var delegate: CategorySelectionDelegate?
  var selectedCategory = TransactionCategory.defaultCategory
  private let margin: CGFloat = 6
  private let cellHeight: CGFloat = 107
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return categories.count
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let reuseID = "categoryCell"
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseID, for: indexPath) as! CategoryCell
    cell.layer.cornerRadius = 8
    let category = categories[indexPath.row]
    cell.emojiLabel.text = category.emoji
    cell.titleLabel.text = category.name
    return cell
  }
}

extension CategoriesProvider: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    selectedCategory = categories[indexPath.row]
    delegate?.didSelect(category: categories[indexPath.row])
  }
}

extension CategoriesProvider: UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let cellWidth = (collectionView.frame.width - margin) / 3 - margin
    return CGSize(width: cellWidth, height: cellHeight)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    return UIEdgeInsets(top: 0, left: margin, bottom: margin, right: margin)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return margin
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
    return margin
  }
}

class CategoryCell: UICollectionViewCell {
  @IBOutlet weak var emojiLabel: UILabel!
  @IBOutlet weak var titleLabel: UILabel!
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
    selectedBackgroundView = UIView(frame: bounds)
    selectedBackgroundView?.backgroundColor = UIColor.white.withAlphaComponent(0.3)
  }
}
