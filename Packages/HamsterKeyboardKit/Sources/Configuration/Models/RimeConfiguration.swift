//
//  RimeConfiguration.swift
//
//
//  Created by morse on 2023/6/30.
//

import Foundation

/// RIME 偏好设置
public struct RimeConfiguration: Codable, Hashable {
  /// 最大候选字数量
  public var maximumNumberOfCandidateWords: Int?

  /// 简繁切换对应的键
  public var keyValueOfSwitchSimplifiedAndTraditional: String?

  public init(maximumNumberOfCandidateWords: Int? = nil, keyValueOfSwitchSimplifiedAndTraditional: String? = nil) {
    self.maximumNumberOfCandidateWords = maximumNumberOfCandidateWords
    self.keyValueOfSwitchSimplifiedAndTraditional = keyValueOfSwitchSimplifiedAndTraditional
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.maximumNumberOfCandidateWords = try container.decodeIfPresent(Int.self, forKey: .maximumNumberOfCandidateWords)
    self.keyValueOfSwitchSimplifiedAndTraditional = try container.decodeIfPresent(String.self, forKey: .keyValueOfSwitchSimplifiedAndTraditional)
  }

  enum CodingKeys: CodingKey {
    case maximumNumberOfCandidateWords
    case keyValueOfSwitchSimplifiedAndTraditional
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(self.maximumNumberOfCandidateWords, forKey: .maximumNumberOfCandidateWords)
    try container.encodeIfPresent(self.keyValueOfSwitchSimplifiedAndTraditional, forKey: .keyValueOfSwitchSimplifiedAndTraditional)
  }
}
