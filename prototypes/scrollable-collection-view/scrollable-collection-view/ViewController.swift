//
//  ViewController.swift
//  scrollable-collection-view
//
//  Created by Anton Vronskii on 2018/11/23.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class Cell: UICollectionViewCell {
  @IBOutlet weak var label: UILabel!
}

class ViewController: UIViewController {
  @IBOutlet weak var scroll: UIScrollView!
  @IBOutlet weak var collection: UICollectionView!
  
  private var cellsCount = 10
  private let margin: CGFloat = 10
  private let cellWidth: CGFloat = 75
  private var hideProgress: CGFloat = 1

  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
  }
  
  func setup() {
    scroll.contentSize = CGSize(width: 1, height: 2 * scroll.frame.height - collection.frame.height - 16)
  }
  
  func updated(progress: CGFloat) {
//    let fullOffset = CGFloat(cellsCount) * (cellWidth + margin) - margin - collection.frame.width
//    collection.contentOffset.x = progress * fullOffset
    collection.contentOffset.x = progress * (cellWidth + margin)
    collection.contentInset.left = -progress * (cellWidth + margin)
    hideProgress = 1 - progress
//    for i in 0..<cellsCount {
//      let indexPath = IndexPath(row: i, section: 0)
//      guard let cell = collection.cellForItem(at: indexPath) else { continue }
//      
//      if i == 0 {
//        cell.alpha = hideProgress
//      } else if i == 1 {
//        cell.alpha = 1
//      } else {
//        cell.alpha = 1 - hideProgress
//      }
//    }
    collection.reloadData()
  }
}

extension ViewController: UIScrollViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let progress = scroll.contentOffset.y / (scroll.contentSize.height - scroll.frame.height)
    updated(progress: progress)
  }
}

extension ViewController: UICollectionViewDataSource {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return cellsCount
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let reuseID = "cell"
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseID, for: indexPath) as! Cell
    cell.label.text = "\(indexPath.row)"
    if indexPath.row == 0 {
      cell.backgroundColor = .red
      cell.alpha = hideProgress
    } else if indexPath.row == 1 {
      cell.backgroundColor = .green
      cell.alpha = 1
    } else {
      cell.alpha = 1 - hideProgress
      cell.backgroundColor = .blue
    }
    return cell
  }
}
