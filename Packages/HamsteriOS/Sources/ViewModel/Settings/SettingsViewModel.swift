//
//  SettingViewModel.swift
//  Hamster
//
//  Created by morse on 2023/6/13.
//

import Combine
import HamsterKeyboardKit
import HamsterKit
import OSLog
import ProgressHUD
import UIKit

public class SettingsViewModel: ObservableObject {
  private var cancelable = Set<AnyCancellable>()
  private unowned let mainViewModel: MainViewModel

  private let resetUISettingsSubject = PassthroughSubject<() -> Void, Never>()
  public var resetUISettingsPublished: AnyPublisher<() -> Void, Never> {
    resetUISettingsSubject.eraseToAnyPublisher()
  }

  private let exportConfigurationSubject = PassthroughSubject<URL, Never>()
  public var exportConfigurationPublished: AnyPublisher<URL, Never> {
    exportConfigurationSubject.eraseToAnyPublisher()
  }

  init(mainViewModel: MainViewModel) {
    self.mainViewModel = mainViewModel
  }

  public var enableColorSchema: Bool {
    get {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.enableColorSchema ?? false
    }
    set {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.enableColorSchema = newValue
      HamsterAppDependencyContainer.shared.applicationConfiguration.keyboard?.enableColorSchema = newValue
    }
  }

  /// 设置选项
  public lazy var sections: [SettingSectionModel] = {
    let sections = [
      SettingSectionModel(title: "键盘相关", items: [
        .init(
          icon: UIImage(systemName: "keyboard")!,
          text: "键盘设置",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in
            self.mainViewModel.subViewSubject.send(.keyboardSettings)
          }
        ),
        .init(
          icon: UIImage(systemName: "paintpalette")!,
          text: "键盘配色",
          accessoryType: .disclosureIndicator,
          navigationLinkLabel: { [unowned self] in enableColorSchema ? "启用" : "禁用" },
          navigationAction: { [unowned self] in
            self.mainViewModel.subViewSubject.send(.colorSchema)
          }
        ),
        .init(
          icon: UIImage(systemName: "speaker.wave.3")!,
          text: "按键音与震动",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in
            self.mainViewModel.subViewSubject.send(.feedback)
          }
        ),
      ]),
      .init(
        footer: "重置通过界面修改的配置项。\n注意：不包含新增/修改配置文件中的配置项。",
        items: [
          .init(text: "重置界面设置", textTintColor: .systemRed, type: .button, buttonAction: { [unowned self] in
            self.resetUISettingsSubject.send {
              HamsterAppDependencyContainer.shared.resetAppConfiguration()
            }
          }),
        ]),
      .init(
        footer: "导出通过界面修改的配置项。",
        items: [
          .init(text: "导出界面设置", type: .button, buttonAction: { [unowned self] in
            let appConfig = HamsterAppDependencyContainer.shared.applicationConfiguration
            let url = FileManager.hamsterAppConfigFileOnUserData
            do {
              try HamsterConfigurationRepositories.shared.saveToYAML(config: appConfig, path: url)
              self.exportConfigurationSubject.send(url)
            } catch {
              await ProgressHUD.failed("导出设置失败")
            }
          }),
        ]),
    ]
    return sections
  }()
}

extension SettingsViewModel {
  /// 启动加载数据
  func loadAppData() async throws {
    // 判断应用是否首次运行
    guard UserDefaults.standard.isFirstRunning else { return }

    await ProgressHUD.animate("初次启动，正在初始化……", interaction: false)

    do {
      try FileManager.initSandboxSharedSupportDirectory(override: true)
      try FileManager.initSandboxUserDataDirectory(override: true, unzip: false)
      try FileManager.initSandboxBackupDirectory(override: true)
      try FileManager.syncSandboxSharedSupportDirectoryToAppGroup(override: true)
    } catch {
      Logger.statistics.error("rime init file directory error: \(error.localizedDescription)")
      throw error
    }

    // 修改应用首次运行标志
    UserDefaults.standard.isFirstRunning = false

    await ProgressHUD.success("初始化完成", interaction: false, delay: 1.5)
  }
}
