//
//  ViewController.swift
//  split-table
//
//  Created by Anton Vronskii on 2018/10/04.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
  private let animationDuration = 1.5
  private var imageViews = [UIImageView]()
  
  @IBOutlet weak var tableView: UITableView!
  private let names = ["Hersilia", "Minerva", "Pollux", "Silvanus", "Mars", "Silvia", "Italus", "Amulius", "Jupiter", "Salacia", "Venus", "Juventas", "Romulus", "Flora", "Cardea", "Remus", "Summanus", "Dido", "Larunda", "Tatius", "Aries", "Pax", "Vesta", "Cupid", "Vulcan"]
  private var animator = UIViewPropertyAnimator()

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    mergeTableViewBack()
  }
  
  private func mergeTableViewBack() {
    animator = UIViewPropertyAnimator(duration: animationDuration, curve: .easeIn) { [unowned self] in
      self.imageViews.forEach {
        $0.transform = .identity
      }
    }
    animator.addCompletion {  [unowned self] (_: UIViewAnimatingPosition) in
      self.imageViews.forEach {
        $0.removeFromSuperview()
      }
      self.imageViews = [UIImageView]()
      self.tableView.isHidden = false
    }
    animator.startAnimation()
  }
}

extension ViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return names.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.textLabel?.text = names[indexPath.row]
    cell.backgroundColor = UIColor.green.withAlphaComponent(0.3)
    return cell
  }
}

extension ViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    // create an image of tableview
    let tableImage = tableView.asImage()
    let scaleFactor = tableImage.size.width / view.frame.width
    
    // split it into 3 parts
    guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
    guard let topImage = tableImage.horizontalSlice(yStart: 0, sliceHeight: scaleFactor * (selectedCell.frame.origin.y - tableView.contentOffset.y)) else { return }
    guard let cellImage = tableImage.horizontalSlice(yStart: scaleFactor * (selectedCell.frame.origin.y - tableView.contentOffset.y), sliceHeight: scaleFactor * (selectedCell.frame.height - tableView.contentOffset.y)) else { return }
    guard let bottomImage = tableImage.horizontalSlice(yStart: scaleFactor * (selectedCell.frame.maxY - tableView.contentOffset.y), sliceHeight: scaleFactor * (tableView.frame.height - tableView.contentOffset.y) - scaleFactor * (selectedCell.frame.maxY - tableView.contentOffset.y)) else { return }
    
    // position all 3 on a view
    var nextOriginY: CGFloat = tableView.frame.minY
    for image in [topImage, cellImage, bottomImage] {
      let imageView = UIImageView(image: image)
      imageView.frame.origin = CGPoint(x: 0, y: nextOriginY)
      imageView.frame.size = imageView.frame.size.applying(CGAffineTransform(scaleX: 1 / scaleFactor, y: 1 / scaleFactor))
      view.addSubview(imageView)
      imageViews.append(imageView)
      nextOriginY = imageView.frame.maxY
    }
    
    // hide real view
    tableView.isHidden = true
    
    // find y translactions for all the parts
    let topTranslation = -(imageViews[0].frame.origin.y + imageViews[0].frame.height)
    let bottomTranslation = view.frame.height - imageViews[2].frame.minY
    
    let cellOriginInMainView = tableView.convert(selectedCell.frame.origin, to: view)
    let cellTranslation = view.center.y - (cellOriginInMainView.y + selectedCell.frame.height / 2)
    
    // animate
    animator = UIViewPropertyAnimator(duration: animationDuration, curve: .easeIn) { [unowned self] in
      self.imageViews[0].transform = CGAffineTransform(translationX: 0, y: topTranslation)
      self.imageViews[1].transform = CGAffineTransform(translationX: 0, y: cellTranslation)
      self.imageViews[2].transform = CGAffineTransform(translationX: 0, y: bottomTranslation)
    }
    animator.startAnimation()
  }
}

extension UIView {
  func asImage() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    let scaledBounds = bounds.applying(CGAffineTransform(scaleX: format.scale, y: format.scale))
    let renderer = UIGraphicsImageRenderer(bounds: scaledBounds, format: format)
    return renderer.image { rendererContext in
      layer.render(in: rendererContext.cgContext)
    }
  }
}

extension UIImage {
  func horizontalSlice(yStart: CGFloat, sliceHeight: CGFloat) -> UIImage? {
    guard let cgImage = cgImage else { return nil }
    let cropRect = CGRect(x: 0, y: yStart, width: size.width, height: sliceHeight)
    guard let croppedImage = cgImage.cropping(to: cropRect) else { return nil }
    return UIImage(cgImage: croppedImage, scale: 1, orientation: imageOrientation)
  }
}
