//
//  HamsterConfigurationRepositories.swift
//
//
//  Created by morse on 2023/7/3.
//

import Foundation
import os
// import ZippyJSON

/// Hamster 配置存储
/// 单例
/// * 支持从 PropertyList 文件读取配置
/// * 支持从 UserDefault 读取配置
/// * 支持将配置存储到 UserDefault 中
public class HamsterConfigurationRepositories {
  public static let shared = HamsterConfigurationRepositories()

  private init() {}

  public func saveToPropertyList(config: HamsterConfiguration, path: URL) throws {
    let data = try PropertyListEncoder().encode(config)
    try? FileManager.default.removeItem(at: path)
    FileManager.default.createFile(atPath: path.path, contents: data)
  }

  public func loadFromPropertyList(_ path: URL) throws -> HamsterConfiguration {
    let data = try Data(contentsOf: path)
    return try PropertyListDecoder().decode(HamsterConfiguration.self, from: data)
  }

  public func saveToJSON(config: HamsterConfiguration, path: URL) throws {
    let data = try JSONEncoder().encode(config)
    try? FileManager.default.removeItem(at: path)
    FileManager.default.createFile(atPath: path.path, contents: data)
  }

  /// 在 UserDefaults 中保存应用配置
  public func saveToUserDefaults(_ config: HamsterConfiguration) throws {
    try saveToUserDefaults(config, key: Self.hamsterConfigurationKey)
  }

  /// 在 UserDefaults 中保存应用配置
  /// 注意: 这里的保存项是作为应用的默认配置，用于还原用户修改配置项
  public func saveToUserDefaultsOnDefault(_ config: HamsterConfiguration) throws {
    try saveToUserDefaults(config, key: Self.defaultHamsterConfigurationKey)
  }

  private func saveToUserDefaults(_ config: HamsterConfiguration, key: String) throws {
    let data = try JSONEncoder().encode(config)
    UserDefaults.hamster.setValue(data, forKey: key)
  }

  private func loadConfigFromUserDefaults(key: String) throws -> HamsterConfiguration {
    guard let data = UserDefaults.hamster.data(forKey: key) else { throw "load HamsterConfiguration from UserDefault is empty." }
    return try JSONDecoder().decode(HamsterConfiguration.self, from: data)
    // return try ZippyJSONDecoder().decode(HamsterConfiguration.self, from: data)
  }

  /// 从 UserDefaults 中获取应用配置
  /// 注意：这里的配置项是应用当前最新的配置选项，可能会在用户变更某些配置时被修改
  /// 如果需要使用配置项的默认值，需要调用 loadFromUserDefaultsOnDefault() 方法
  public func loadFromUserDefaults() throws -> HamsterConfiguration {
    try loadConfigFromUserDefaults(key: Self.hamsterConfigurationKey)
  }

  /// 从 UserDefaults 中获取应用默认配置
  /// 注意：这里是配置文件的原始值，用于还原某些已经被修改的配置项
  public func loadFromUserDefaultsOnDefault() throws -> HamsterConfiguration {
    try loadConfigFromUserDefaults(key: Self.defaultHamsterConfigurationKey)
  }

  /// 从 UserDefaults 中删除应用配置
  public func removeFromUserDefaults() {
    UserDefaults.hamster.removeObject(forKey: Self.hamsterConfigurationKey)
  }

  /// 按优先级读取配置文件
  public func loadConfiguration() throws -> HamsterConfiguration {
    let plistPath = FileManager.hamsterConfigFileOnSandboxSharedSupport.deletingLastPathComponent().appendingPathComponent("hamster.plist")
    return try loadFromPropertyList(plistPath)
  }

  /// 清空应用配置（包含默认的应用配置）
  public func resetConfiguration() {
    UserDefaults.hamster.removeObject(forKey: Self.hamsterConfigurationKey)
    UserDefaults.hamster.removeObject(forKey: Self.defaultHamsterConfigurationKey)
  }
}

public extension HamsterConfigurationRepositories {
  /// 应用配置key
  static let hamsterConfigurationKey = "com.ihsiao.apps.Hamster.configuration.keys.hamsterConfig"
  /// 默认应用配置key
  static let defaultHamsterConfigurationKey = "com.ihsiao.apps.Hamster.configuration.keys.defaultHamsterConfig"

  /// 将 str 中的中文 unicode 编码 \uXXXX 转化为人类可读的
  static func transform(_ str: String) throws -> String {
    guard let transformStr = str.applyingTransform(StringTransform(rawValue: "Any-Hex/Java"), reverse: true) else {
      throw "String transform error."
    }
    return transformStr
  }
}
