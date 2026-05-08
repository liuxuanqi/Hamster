//
//  HamsterAppDependencyContainer.swift
//
//
//  Created by morse on 2023/7/5.
//

import Foundation
import HamsterKeyboardKit
import HamsterKit
import OSLog
import UIKit

/// Hamster 应用依赖注入容器
/// 通过此容器，为对象注入依赖
open class HamsterAppDependencyContainer {
  /// 单例
  public static let shared = HamsterAppDependencyContainer()

  // MARK: Long-lived 依赖属性

  public let rimeContext: RimeContext
  public let mainViewModel: MainViewModel

  public lazy var settingsViewModel: SettingsViewModel = {
    SettingsViewModel(mainViewModel: mainViewModel)
  }()

  public lazy var keyboardSettingsViewModel: KeyboardSettingsViewModel = {
    KeyboardSettingsViewModel()
  }()

  /// 应用配置
  public var configuration: HamsterConfiguration {
    didSet {
      Task {
        do {
          Logger.statistics.debug("hamster configuration didSet")
          try HamsterConfigurationRepositories.shared.saveToUserDefaults(configuration)
          let plistDir = FileManager.appGroupUserDataDirectoryURL.appendingPathComponent("build")
          if !FileManager.default.fileExists(atPath: plistDir.path) {
            try FileManager.default.createDirectory(at: plistDir, withIntermediateDirectories: true)
          }
          try HamsterConfigurationRepositories.shared.saveToPropertyList(
            config: configuration,
            path: plistDir.appendingPathComponent("hamster.plist")
          )
        } catch {
          Logger.statistics.error("hamster configuration didSet error: \(error.localizedDescription)")
        }
      }
    }
  }

  /// 在 app 内设置的的配置项
  public var applicationConfiguration: HamsterConfiguration = {
    if let config = try? HamsterConfigurationRepositories.shared.loadAppConfigurationFromUserDefaults() {
      return config
    }
    var config = HamsterConfiguration(
      general: GeneralConfiguration(),
      toolbar: KeyboardToolbarConfiguration(
        heightOfToolbar: 58,
        heightOfCodingArea: 20,
        codingAreaFontSize: 20,
        candidateWordFontSize: 20
      ),
      keyboard: KeyboardConfiguration(enableEmbeddedInputMode: false),
      rime: RimeConfiguration(),
      swipe: KeyboardSwipeConfiguration(distanceThreshold: 80),
      keyboards: nil
    )
    config.keyboard?.keyboardRowHeight = 58
    return config
  }() {
    didSet {
      do {
        try HamsterConfigurationRepositories.shared.saveAppConfigurationToUserDefaults(applicationConfiguration)
      } catch {
        Logger.statistics.error("hamster app configuration set error: \(error.localizedDescription)")
      }
    }
  }

  public var defaultConfiguration: HamsterConfiguration? {
    do {
      return try HamsterConfigurationRepositories.shared.loadFromUserDefaultsOnDefault()
    } catch {
      Logger.statistics.error("loadFromUserDefaultsOnDefault() error: \(error)")
      return nil
    }
  }

  private init() {
    self.rimeContext = RimeContext()
    self.mainViewModel = MainViewModel()

    if UserDefaults.standard.isFirstRunning {
      do {
        try FileManager.initSandboxSharedSupportDirectory(override: true)
        let hamsterConfiguration = try HamsterConfigurationRepositories.shared.loadFromYAML(FileManager.hamsterConfigFileOnSandboxSharedSupport)
        try HamsterConfigurationRepositories.shared.saveToUserDefaultsOnDefault(hamsterConfiguration)
        self.configuration = hamsterConfiguration
        // didSet not fired during init — explicitly write plist
        let plistDir = FileManager.appGroupUserDataDirectoryURL.appendingPathComponent("build")
        if !FileManager.default.fileExists(atPath: plistDir.path) {
          try FileManager.default.createDirectory(at: plistDir, withIntermediateDirectories: true)
        }
        try HamsterConfigurationRepositories.shared.saveToPropertyList(
          config: hamsterConfiguration,
          path: plistDir.appendingPathComponent("hamster.plist")
        )
        try HamsterConfigurationRepositories.shared.saveToUserDefaults(hamsterConfiguration)
      } catch {
        self.configuration = HamsterConfiguration()
        Logger.statistics.error("init SharedSupport error: \(error.localizedDescription)")
      }
      return
    }

    do {
      self.configuration = try HamsterConfigurationRepositories.shared.loadFromUserDefaults()
      let plistPath = FileManager.appGroupUserDataDirectoryURL.appendingPathComponent("build/hamster.plist")
      if !FileManager.default.fileExists(atPath: plistPath.path) {
        let plistDir = plistPath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: plistDir.path) {
          try FileManager.default.createDirectory(at: plistDir, withIntermediateDirectories: true)
        }
        try HamsterConfigurationRepositories.shared.saveToPropertyList(
          config: configuration,
          path: plistPath
        )
      }
    } catch {
      Logger.statistics.error("load configuration from UserDefault error: \(error.localizedDescription)")
      if let hamsterConfiguration = try? HamsterConfigurationRepositories.shared.loadFromYAML(FileManager.hamsterConfigFileOnSandboxSharedSupport) {
        self.configuration = hamsterConfiguration
      } else {
        self.configuration = HamsterConfiguration()
      }
    }
  }

  public func resetAppConfiguration() {
    HamsterConfigurationRepositories.shared.resetAppConfiguration()
    var config = HamsterConfiguration(
      general: GeneralConfiguration(),
      toolbar: KeyboardToolbarConfiguration(
        heightOfToolbar: 58,
        heightOfCodingArea: 20,
        codingAreaFontSize: 20,
        candidateWordFontSize: 20
      ),
      keyboard: KeyboardConfiguration(enableEmbeddedInputMode: false),
      rime: RimeConfiguration(),
      swipe: KeyboardSwipeConfiguration(distanceThreshold: 80),
      keyboards: nil
    )
    config.keyboard?.keyboardRowHeight = 58
    HamsterAppDependencyContainer.shared.applicationConfiguration = config
    if let configuration = try? HamsterConfigurationRepositories.shared.loadConfiguration() {
      HamsterAppDependencyContainer.shared.configuration = configuration
    }
  }

  public func resetHamsterConfiguration() {
    HamsterConfigurationRepositories.shared.resetConfiguration()
  }
}

extension HamsterAppDependencyContainer: KeyboardSettingsSubViewControllerFactory {
  func makeNumberNineGridSettingsViewController() -> NumberNineGridSettingsViewController {
    NumberNineGridSettingsViewController(keyboardSettingsViewModel: keyboardSettingsViewModel)
  }

  func makeSymbolSettingsViewController() -> SymbolSettingsViewController {
    SymbolSettingsViewController(keyboardSettingsViewModel: keyboardSettingsViewModel)
  }

  func makeSymbolKeyboardSettingsViewController() -> SymbolKeyboardSettingsViewController {
    SymbolKeyboardSettingsViewController(keyboardSettingsViewModel: keyboardSettingsViewModel)
  }

  func makeToolbarSettingsViewController() -> ToolbarSettingsViewController {
    ToolbarSettingsViewController(keyboardSettingsViewModel: keyboardSettingsViewModel)
  }

  func makeKeyboardLayoutViewController() -> KeyboardLayoutViewController {
    KeyboardLayoutViewController(keyboardSettingsViewModel: keyboardSettingsViewModel)
  }

  func makeSpaceSettingsViewController() -> SpaceSettingsViewController {
    SpaceSettingsViewController(keyboardSettingsViewModel: keyboardSettingsViewModel)
  }
}

extension HamsterAppDependencyContainer: KeyboardColorViewModelFactory {
  func makeKeyboardColorViewModel() -> KeyboardColorViewModel {
    KeyboardColorViewModel()
  }
}

extension HamsterAppDependencyContainer: KeyboardFeedbackViewModelFactory {
  func makeKeyboardFeedbackViewModel() -> KeyboardFeedbackViewModel {
    KeyboardFeedbackViewModel()
  }
}

extension HamsterAppDependencyContainer: SubViewControllerFactory {
  public func makeRootController() -> MainViewController {
    MainViewController(mainViewModel: mainViewModel, subViewControllerFactory: self)
  }

  public func makeSettingsViewController() -> SettingsViewController {
    SettingsViewController(settingsViewModel: settingsViewModel)
  }

  func makeKeyboardSettingsViewController() -> KeyboardSettingsViewController {
    KeyboardSettingsViewController(
      keyboardSettingsViewModel: keyboardSettingsViewModel,
      keyboardSettingsSubViewControllerFactory: self
    )
  }

  func makeKeyboardColorViewController() -> KeyboardColorViewController {
    KeyboardColorViewController(keyboardColorViewModelFactory: self)
  }

  func makeKeyboardFeedbackViewController() -> KeyboardFeedbackViewController {
    KeyboardFeedbackViewController(keyboardFeedbackViewModelFactory: self)
  }
}
