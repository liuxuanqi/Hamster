//
//  File.swift
//
//
//  Created by morse on 2023/7/4.
//

import Foundation
import os
import ZIPFoundation

/// FileManager 扩展
public extension FileManager {
  /// 创建文件夹
  /// override: 当目标文件夹存在时，是否覆盖
  /// dst: 目标文件夹URL
  static func createDirectory(override: Bool = false, dst: URL) throws {
    let fm = FileManager.default
    if fm.fileExists(atPath: dst.path) {
      if override {
        try fm.removeItem(atPath: dst.path)
      } else {
        return
      }
    }
    try fm.createDirectory(
      at: dst,
      withIntermediateDirectories: true,
      attributes: nil
    )
  }

  /// 拷贝文件夹
  /// override: 当目标文件夹存在时，是否覆盖
  /// src: 拷贝源 URL
  /// dst: 拷贝地址 URL
  static func copyDirectory(override: Bool = false, src: URL, dst: URL) throws {
    let fm = FileManager.default
    if fm.fileExists(atPath: dst.path) {
      if override {
        try fm.removeItem(atPath: dst.path)
      } else {
        return
      }
    }

    if !fm.fileExists(atPath: dst.deletingLastPathComponent().path) {
      try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
    }
    try fm.copyItem(at: src, to: dst)
  }
}

// MARK: 应用内文件路径及操作

public extension FileManager {
  // AppGroup共享目录
  static var shareURL: URL {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: HamsterConstants.appGroupName)!
      .appendingPathComponent("InputSchema")
  }

  static var sandboxDirectory: URL {
    try! FileManager.default
      .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
  }

  // AppGroup共享下: SharedSupport目录
  static var appGroupSharedSupportDirectoryURL: URL {
    shareURL.appendingPathComponent(
      HamsterConstants.rimeSharedSupportPathName, isDirectory: true
    )
  }

  // AppGroup共享下: userData目录
  static var appGroupUserDataDirectoryURL: URL {
    shareURL.appendingPathComponent(
      HamsterConstants.rimeUserPathName, isDirectory: true
    )
  }

  /// Sandbox/SharedSupport/hamster.yaml 文件
  static var hamsterConfigFileOnSandboxSharedSupport: URL {
    sandboxSharedSupportDirectory.appendingPathComponent("hamster.yaml")
  }

  /// Sandbox/Rime/hamster.app.yaml 文件
  static var hamsterAppConfigFileOnUserData: URL {
    sandboxUserDataDirectory.appendingPathComponent("hamster.app.yaml")
  }

  // 沙盒 Document 目录下 ShareSupport 目录
  static var sandboxSharedSupportDirectory: URL {
    sandboxDirectory
      .appendingPathComponent(HamsterConstants.rimeSharedSupportPathName, isDirectory: true)
  }

  // 沙盒 Document 目录下 userData 目录
  static var sandboxUserDataDirectory: URL {
    sandboxDirectory
      .appendingPathComponent(HamsterConstants.rimeUserPathName, isDirectory: true)
  }

  // 安装包ShareSupport资源目录
  static var appSharedSupportDirectory: URL {
    Bundle.main.bundleURL
      .appendingPathComponent(
        HamsterConstants.rimeSharedSupportPathName, isDirectory: true
      )
  }

  /// 初始沙盒目录下 SharedSupport 目录资源
  static func initSandboxSharedSupportDirectory(override: Bool = false) throws {
    try initSharedSupportDirectory(override: override, dst: sandboxSharedSupportDirectory)
  }

  // 初始化 SharedSupport 目录资源
  private static func initSharedSupportDirectory(override: Bool = false, dst: URL) throws {
    let fm = FileManager()
    if fm.fileExists(atPath: dst.path) {
      if override {
        try fm.removeItem(atPath: dst.path)
      } else {
        return
      }
    }

    if !fm.fileExists(atPath: dst.path) {
      try fm.createDirectory(at: dst, withIntermediateDirectories: true, attributes: nil)
    }

    let src = appSharedSupportDirectory.appendingPathComponent(HamsterConstants.inputSchemaZipFile)

    Logger.statistics.debug("unzip src: \(src), dst: \(dst)")

    // 解压缩输入方案zip文件
    try fm.unzipItem(at: src, to: dst)
  }

  // 初始化沙盒目录下 UserData 目录资源
  static func initSandboxUserDataDirectory(override: Bool = false, unzip: Bool = false) throws {
    try FileManager.createDirectory(
      override: override, dst: sandboxUserDataDirectory
    )

    if unzip {
      let src = appSharedSupportDirectory.appendingPathComponent(HamsterConstants.userDataZipFile)
      try FileManager.default.unzipItem(at: src, to: sandboxUserDataDirectory)
    }
  }

  // 同步 Sandbox 目录下 SharedSupport 目录至 AppGroup 目录
  static func syncSandboxSharedSupportDirectoryToAppGroup(override: Bool = false) throws {
    Logger.statistics.info("rime syncSandboxSharedSupportDirectoryToApGroup: override \(override)")
    try FileManager.copyDirectory(override: override, src: sandboxSharedSupportDirectory, dst: appGroupSharedSupportDirectoryURL)
  }
}
