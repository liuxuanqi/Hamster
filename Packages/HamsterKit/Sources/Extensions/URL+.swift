//
//  File.swift
//
//
//  Created by morse on 2023/7/4.
//

import Foundation
import os

public extension URL {
  /// 获取制定URL下文件或目录URL
  func getFilesAndDirectories() -> [URL] {
    do {
      return try FileManager.default.contentsOfDirectory(
        at: self,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
      )
    } catch {
      Logger.statistics.error("Error getting files and directories - \(error.localizedDescription)")
      return []
    }
  }

  /// 获取指定URL的文件内容
  func getStringFromFile() -> String? {
    guard let data = FileManager.default.contents(atPath: path) else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }
}
