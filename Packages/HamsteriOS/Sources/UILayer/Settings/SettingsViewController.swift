//
//  SettingsViewController.swift
//
//  Created by morse on 2023/6/12.
//

import Combine
import HamsterKit
import HamsterUIKit
import ProgressHUD
import UIKit

public class SettingsViewController: NibLessViewController, UIDocumentPickerDelegate {
  private var settingsViewModel: SettingsViewModel
  private var subscriptions = Set<AnyCancellable>()

  init(settingsViewModel: SettingsViewModel) {
    self.settingsViewModel = settingsViewModel
    super.init()
  }
}

// MARK: override UIViewController

public extension SettingsViewController {
  override func loadView() {
    title = "输入法设置"
    view = SettingsRootView(settingsViewModel: settingsViewModel)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    settingsViewModel.resetUISettingsPublished
      .receive(on: DispatchQueue.main)
      .sink { [unowned self] callback in
        self.alertConfirm(alertTitle: "重置 UI 设置", message: "确认重置 UI 交互生成的设置吗？", confirmTitle: "确定", confirmCallback: {
          callback()
          ProgressHUD.success("重置成功", interaction: false, delay: 1.5)
        })
      }
      .store(in: &subscriptions)

    settingsViewModel.exportConfigurationPublished
      .receive(on: DispatchQueue.main)
      .sink { [unowned self] exportURL in
        let pickerVC = UIDocumentPickerViewController(forExporting: [exportURL])
        pickerVC.modalPresentationStyle = .formSheet
        pickerVC.shouldShowFileExtensions = true
        pickerVC.delegate = self
        present(pickerVC, animated: true)
      }
      .store(in: &subscriptions)
  }

}
