/*-
 * ---license-start
 * eu-digital-green-certificates / dgca-wallet-app-ios
 * ---
 * Copyright (C) 2021 T-Systems International GmbH and all other contributors
 * ---
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * ---license-end
 */
//
//  CertificateViewer.swift
//  DGCAWallet
//
//  Created by Yannick Spreen on 4/19/21.
//

import Foundation
import UIKit
import FloatingPanel
import SwiftDGC
import PDFKit

class CertificateViewerVC: UIViewController {
  private enum Constants {
    static let showValidityController = "showValidityController"
    static let embedCertPagesController = "embedCertPagesController"
  }
  
  @IBOutlet weak var headerBackground: UIView!
  @IBOutlet weak var nameLabel: UILabel!
  @IBOutlet weak var dismissButton: UIButton!
  @IBOutlet weak var cancelButton: UIButton!
  @IBOutlet weak var cancelButtonConstraint: NSLayoutConstraint!
  @IBOutlet weak var checkValidityButton: UIButton!
  
  var hCert: HCert?
  var tan: String?
  weak var childDismissedDelegate: CertViewerDelegate?
  public var isSaved = true
  var newCertAdded = false


  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    setupInterface()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)

    Brightness.reset()
    childDismissedDelegate?.childDismissed(newCertAdded)
  }

  func setupInterface() {
    guard let hCert = hCert else { return }
      
    nameLabel.text = hCert.fullName
    if !isSaved {
      dismissButton.setTitle(l10n("btn.save"), for: .normal)
      checkValidityButton.isHidden = true
    } else {
      checkValidityButton.isHidden = false
    }
    headerBackground.backgroundColor = isSaved ? .blue : .grey10
    nameLabel.textColor = isSaved ? .white : .black
    cancelButton.alpha = isSaved ? 0 : 1
    cancelButtonConstraint.priority = .init(isSaved ? 997 : 999)
    checkValidityButton.setTitle(l10n("button_check_validity"), for: .normal)
    view.layoutIfNeeded()
  }

  @IBAction func closeButtonClick() {
    if isSaved {
       dismiss(animated: true, completion: nil)
    }
    saveCert()
  }

  @IBAction func cancelButtonClick() {
    dismiss(animated: true, completion: nil)
  }

  @IBAction func checkValidityAction(_ sender: Any) {
    self.performSegue(withIdentifier: Constants.showValidityController, sender: nil)
  }
  
  func saveCert() {
    showInputDialog(title: l10n("tan.confirm.title"), subtitle: l10n("tan.confirm.text"), actionTitle: l10n("btn.confirm"), inputPlaceholder: l10n("tan.confirm.placeholder") ) { [weak self] in
      guard let cert = self?.hCert else { return }
        
      GatewayConnection.claim(cert: cert, with: $0) { success, newTan in
        if success {
          guard let cert = self?.hCert else { return }
            
          LocalData.add(cert, with: newTan)
          self?.newCertAdded = true
          self?.showAlert(title: l10n("tan.confirm.success.title"), subtitle: l10n("tan.confirm.success.text")) { _ in
            self?.dismiss(animated: true, completion: nil)
          }
        } else {
          self?.showAlert(title: l10n("tan.confirm.fail.title"), subtitle: l10n("tan.confirm.fail.text")
          )
        }
      }
    }
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    switch segue.identifier {
    case Constants.showValidityController:
      guard let checkController = segue.destination as? CheckValidityVC else { return }
      checkController.setupCheckValidity(with: hCert)
      
    case Constants.embedCertPagesController:
      guard let childController = segue.destination as? CertPagesVC else { return }
      childController.embeddingVC = self

    default:
      break
    }
  }
  
  @IBAction func shareAction(_ sender: Any) {
    let menuActionSheet =  UIAlertController(title: l10n("share.qr.code"), message: l10n("want.share"),
        preferredStyle: .actionSheet)
    menuActionSheet.addAction(UIAlertAction(title: l10n("image.export"), style: .default, handler: { [weak self] _ in
          self?.shareQRCodeLikeImage()
        }))
    menuActionSheet.addAction(UIAlertAction(title: l10n("pdf.export"), style: .default, handler: { [weak self] _ in
          self?.shareQrCodeLikePDF()
        }))
    menuActionSheet.addAction(UIAlertAction(title: l10n("cancel"), style: .cancel, handler: nil))
    present(menuActionSheet, animated: true, completion: nil)
  }
}

extension CertificateViewerVC {
  private func shareQRCodeLikeImage() {
    guard let hCert = hCert, let savedImage = hCert.qrCode else { return }
      
    let imageToShare = [ savedImage ]
    let activityViewController = UIActivityViewController(activityItems: imageToShare as [Any],
      applicationActivities: nil)
    activityViewController.popoverPresentationController?.sourceView = self.view // so that iPads won't crash
    self.present(activityViewController, animated: true, completion: nil)
  }
  private func shareQrCodeLikePDF() {
    guard let hCert = hCert, let savedImage = hCert.qrCode else { return }
      
    let pdfDocument = PDFDocument()
    let pdfPage = PDFPage(image: savedImage)
    pdfDocument.insert(pdfPage!, at: 0)
    let data = pdfDocument.dataRepresentation()
    let pdfToShare = [ data ]
    let activityViewController = UIActivityViewController(activityItems: pdfToShare as [Any],
      applicationActivities: nil)
    activityViewController.popoverPresentationController?.sourceView = self.view // so that iPads won't crash
    self.present(activityViewController, animated: true, completion: nil)
  }
}
