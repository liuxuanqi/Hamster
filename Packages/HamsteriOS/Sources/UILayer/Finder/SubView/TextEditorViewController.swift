//
//  TextEditViewController.swift
//  Hamster
//
//  Created by morse on 2023/6/14.
//

import HamsterKit
import HamsterUIKit
import OSLog
import ProgressHUD
import UIKit

/// 文件编辑器
class TextEditorViewController: NibLessViewController {
  let fileURL: URL
  let enableEditorState: Bool

  init(fileURL: URL, enableEditorState: Bool = true, isLineWrappingEnabled: Bool = true) {
    self.fileURL = fileURL
    self.enableEditorState = enableEditorState
    super.init(nibName: nil, bundle: nil)
  }

  lazy var textView: UITextView = {
    let tv = UITextView()
    tv.translatesAutoresizingMaskIntoConstraints = false
    tv.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
    tv.backgroundColor = .systemBackground
    tv.autocorrectionType = .no
    tv.autocapitalizationType = .none
    return tv
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    title = fileURL.lastPathComponent
    view.backgroundColor = .systemBackground

    let fileContent = (try? String(contentsOfFile: fileURL.path)) ?? ""
    textView.text = fileContent
    textView.isEditable = enableEditorState

    view.addSubview(textView)
    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: view.topAnchor),
      textView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
      textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    if enableEditorState {
      let saveItem = UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(saveFileContent))
      navigationItem.rightBarButtonItem = saveItem
    }
  }

  @objc func saveFileContent() {
    let fileContent = textView.text ?? ""
    do {
      try fileContent.write(toFile: fileURL.path, atomically: true, encoding: .utf8)
      ProgressHUD.success("保存成功")
      navigationController?.popViewController(animated: true)
    } catch {
      Logger.statistics.debug("TextEditorView save error: \(error.localizedDescription)")
      ProgressHUD.failed("保存失败", delay: 1.5)
    }
  }
}
