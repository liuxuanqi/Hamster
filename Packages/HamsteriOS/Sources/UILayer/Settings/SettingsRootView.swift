//
//  SettingsRootView.swift
//
//
//  Created by morse on 2023/7/5.
//

import HamsterUIKit
import UIKit

public class SettingsRootView: NibLessView {
  // MARK: properties

  let settingsViewModel: SettingsViewModel

  lazy var tableView: UITableView = {
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    tableView.register(SettingTableViewCell.self, forCellReuseIdentifier: SettingTableViewCell.identifier)
    tableView.register(ButtonTableViewCell.self, forCellReuseIdentifier: ButtonTableViewCell.identifier)
    tableView.contentInsetAdjustmentBehavior = .automatic
    tableView.dataSource = self
    tableView.delegate = self
    tableView.translatesAutoresizingMaskIntoConstraints = false
    return tableView
  }()

  // MARK: method

  init(frame: CGRect = .zero, settingsViewModel: SettingsViewModel) {
    self.settingsViewModel = settingsViewModel
    super.init(frame: frame)
    constructViewHierarchy()
    activateViewConstraints()
  }

  override public func constructViewHierarchy() {
    addSubview(tableView)
  }

  override public func activateViewConstraints() {
    tableView.fillSuperview()
  }
}

extension SettingsRootView: UITableViewDelegate {
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: false)
    let setting = settingsViewModel.sections[indexPath.section].items[indexPath.row]
    if setting.type == .navigation {
      setting.navigationAction?()
    } else if setting.type == .button {
      Task {
        try? await setting.buttonAction?()
      }
    }
  }
}

extension SettingsRootView: UITableViewDataSource {
  public func numberOfSections(in tableView: UITableView) -> Int {
    return settingsViewModel.sections.count
  }

  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return settingsViewModel.sections[section].items.count
  }

  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let settings = settingsViewModel.sections[indexPath.section].items[indexPath.row]

    if settings.type == .button {
      let cell = tableView.dequeueReusableCell(withIdentifier: ButtonTableViewCell.identifier, for: indexPath)
      guard let cell = cell as? ButtonTableViewCell else { return cell }
      cell.updateWithSettingItem(settings)
      return cell
    }

    let cell = tableView.dequeueReusableCell(withIdentifier: SettingTableViewCell.identifier, for: indexPath)
    guard let cell = cell as? SettingTableViewCell else { return cell }
    cell.updateWithSettingItem(settings)
    return cell
  }

  public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    settingsViewModel.sections[section].footer
  }
}
