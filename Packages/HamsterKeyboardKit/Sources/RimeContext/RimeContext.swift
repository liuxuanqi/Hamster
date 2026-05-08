//
//  RimeContext.swift
//
//
//  Created by morse on 2023/6/30.
//

import Combine
import Foundation
import HamsterKit
import OSLog
import SimeEngine
import SimeSession

/// RIME 运行时上下文
public class RimeContext {
  /// 最大候选词数量
  public private(set) lazy var maximumNumberOfCandidateWords: Int = 100

  /// 是否使用 IRimeContext 中分页信息
  public private(set) lazy var useContextPaging = false

  private static let wanxiangSchema = RimeSchema(schemaId: "wanxiang", schemaName: "万象")

  /// rime 输入方案列表
  public private(set) lazy var schemas: [RimeSchema] = [Self.wanxiangSchema]

  /// rime 用户选择方案列表
  public lazy var selectSchemas: [RimeSchema] = [Self.wanxiangSchema]

  /// 当前输入方案
  public var currentSchema: RimeSchema? { Self.wanxiangSchema }

  /// 上次使用输入方案
  public var latestSchema: RimeSchema? { nil }

  /// 用户输入键值
  public var userInputKey: String = "" {
    didSet {
      userInputKeySubject.send(userInputKey)
    }
  }

  private let userInputKeySubject = PassthroughSubject<String, Never>()
  public var userInputKeyPublished: AnyPublisher<String, Never> {
    userInputKeySubject.eraseToAnyPublisher()
  }

  /// 待上屏文字
  public private(set) lazy var commitText: String = ""

  /// T9拼音（sime 不支持 T9，直接返回 preedit）
  @MainActor
  public var t9UserInputKey: String {
    rimeContext?.composition.preedit ?? ""
  }

  /// rime option 选项对应的值的缓存
  private var optionValueCache: [String: [Bool: String]] = [:]

  /// 字母模式
  @MainActor
  public lazy var asciiMode: Bool = false

  /// 候选字
  @MainActor @Published
  public var suggestions: [CandidateSuggestion] = []

  @MainActor @Published
  public var rimeContext: IRimeContext? = nil

  /// rime option
  @MainActor @Published
  public var optionState: String? = nil

  /// 划动分页模式下，当前页码，从 0 开始
  public lazy var pageIndex: Int = 0

  /// 根据页码计算首个候选文字索引
  public var candidateIndex: Int {
    pageIndex * maximumNumberOfCandidateWords
  }

  public init() {}

  func setMaximumNumberOfCandidateWords(_ count: Int) {
    self.maximumNumberOfCandidateWords = count
  }

  func setUseContextPaging(_ state: Bool) {
    self.useContextPaging = state
  }
}

// MARK: methods

public extension RimeContext {
  /// RIME Context 状态重置
  @MainActor
  func reset() {
    self.pageIndex = 0
    self.userInputKey = ""
    self.suggestions.removeAll(keepingCapacity: false)
    Rime.shared.cleanComposition()
  }

  func resetCommitText() {
    self.commitText = ""
  }

  @MainActor
  func setAsciiMode(_ model: Bool) {
    self.asciiMode = model
  }

  /// 引擎启动
  func start() async {
    Rime.shared.setNotificationDelegate(self)

    Rime.shared.start(Rime.createTraits(
      sharedSupportDir: FileManager.appGroupSharedSupportDirectoryURL.path,
      userDataDir: FileManager.appGroupUserDataDirectoryURL.path
    ))

    setupRimeInputSchema()
    await setAsciiMode(Rime.shared.isAsciiMode())
  }

  /// RIME 关闭
  /// 注意：仅用于键盘扩展调用
  func shutdown() {
    Rime.shared.shutdown()
  }

  var isRunning: Bool {
    Rime.shared.isRunning()
  }
}

// MARK: - RIME 引擎相关操作

public extension RimeContext {
  /// 设置用户输入方案
  func setupRimeInputSchema() {
    Logger.statistics.info("setupRimeInputSchema: single schema (wanxiang)")
  }

  /// 切换最近一次输入方案
  @MainActor
  func switchLatestInputSchema() {
    self.reset()
  }

  /// 触发 RIME 的 switcher（sime 单方案，无操作）
  @MainActor
  func switcher() {}

  /// 根据索引选择候选字
  @MainActor
  func selectCandidate(index: Int) {
    _ = Rime.shared.selectCandidate(index: index)
    syncContext()
  }

  /// 中英切换
  @MainActor
  func switchEnglishChinese() {
    self.reset()
    self.asciiMode.toggle()
    Rime.shared.asciiMode(asciiMode)
  }
}

// MARK: implementation IRimeNotificationDelegate

extension RimeContext: IRimeNotificationDelegate {
  @MainActor
  public func onChangeMode(_ option: String) {
    Logger.statistics.info("HamsterRimeNotification: onChangeMode, mode: \(option)")

    let optionState = !option.hasPrefix("!")
    let optionName = optionState ? option : String(option.dropFirst())

    if optionValueCache[optionName] == nil {
      optionValueCache[optionName] = [
        true: Rime.shared.getStateLabel(option: optionName, state: true, abbreviated: true),
        false: Rime.shared.getStateLabel(option: optionName, state: false, abbreviated: true),
      ]
    }

    // 中英模式
    if option.hasSuffix("ascii_mode") {
      self.setAsciiMode(optionState)
    }

    // 设置 rime option 对应的值
    self.optionState = optionValueCache[optionName]?[optionState]
  }

  @MainActor
  public func onLoadingSchema(_ loadSchema: String) {
    Logger.statistics.info("onLoadingSchema: \(loadSchema) (ignored, single schema)")
  }
}

// MARK: - 文字输入处理

public extension RimeContext {
  /**
   RIME引擎尝试处理输入文字
   */
  @MainActor
  func tryHandleInputText(_ text: String) -> Bool {
    // 由rime处理全部符号
    let handled = Rime.shared.inputKey(text)

    // 处理失败则返回 inputText
    guard handled else { return false }

    self.syncContext()

    return true
  }

  func getInputKeys() -> String {
    Rime.shared.getInputKeys()
  }

  /**
   RIME引擎尝试处理输入编码
   */
  @MainActor
  func tryHandleInputCode(_ code: Int32, modifier: Int32 = 0) -> Bool {
    // 由rime处理全部符号
    let handled = Rime.shared.inputKeyCode(code, modifier: modifier)
    // 处理失败则返回 inputText
    guard handled else { return false }

    self.syncContext()

    return true
  }

  /// 同步context: 主要是获取当前引擎提供的候选文字, 同时更新rime published属性 userInputKey
  @MainActor
  func syncContext() {
    self.pageIndex = 0
    self.rimeContext = Rime.shared.context()
    let userInputText = rimeContext?.composition?.preedit ?? ""
    let commitText = Rime.shared.getCommitText()
    var candidates = [CandidateSuggestion]()
    if !useContextPaging {
      var highlightIndex = 0
      if let menu = rimeContext?.menu {
        highlightIndex = Int(menu.pageSize * menu.pageNo + menu.highlightedCandidateIndex)
      }
      candidates = self.candidateListLimit(index: candidateIndex, highlightIndex: highlightIndex, count: maximumNumberOfCandidateWords)
    }

    // Logger.statistics.debug("syncContext: userInputText = \(userInputText), commitText = \(commitText)")

    // 查看输入法状态
    let status = Rime.shared.status()

    // 注意：commitText 值的修改需要在修改 userInputKey 之前，
    // 因为 userInputKey 是 @Published，观测其值时会用到 commitText，所以如果 commitText 值修改滞后，会造成读取 commitText 不正确

    // 如果输入状态不是待组字阶段, 则重置输入法
    if !status.isComposing {
      self.commitText = commitText
      self.reset()
      return
    }

    // 注意赋值顺序
    self.userInputKey = userInputText
    self.commitText = commitText
    self.suggestions = candidates
  }

  /// 分页：下一页
  @MainActor
  func nextPage() {
    self.pageIndex += 1
    var highlightIndex = 0
    if let menu = rimeContext?.menu {
      highlightIndex = Int(menu.pageSize * menu.pageNo + menu.highlightedCandidateIndex)
    }
    let candidates = self.candidateListLimit(index: candidateIndex, highlightIndex: highlightIndex, count: maximumNumberOfCandidateWords)
    if !candidates.isEmpty {
      self.suggestions.append(contentsOf: candidates)
    } else {
      self.pageIndex -= 1
    }
  }

  /// 获取候选列表
  func candidateListLimit(index: Int, highlightIndex: Int, count: Int) -> [CandidateSuggestion] {
    // TODO: 最大候选文字数量
    let candidates = Rime.shared.candidateListWithIndex(index: index, andCount: count)
    var result: [CandidateSuggestion] = []
    // 候选文字首个索引
    let candidateIndex = self.candidateIndex
    for (index, candidate) in candidates.enumerated() {
      let index = candidateIndex + index
      let suggestion = CandidateSuggestion(
        index: index,
        label: "\(index + 1)",
        text: candidate.text,
        title: candidate.text,
        isAutocomplete: index == highlightIndex,
        subtitle: candidate.comment
      )
      result.append(suggestion)
    }
    return result
  }

  @MainActor
  func deleteBackward() {
    _ = Rime.shared.inputKeyCode(XK_BackSpace)
    self.syncContext()
  }

  /// 删除用户输入，且不需要同步 RIME 上下文
  /// 注意：此方法是 T9 拼音用来做删除操作的
  @MainActor
  func deleteBackwardNotSync() {
    _ = Rime.shared.inputKeyCode(XK_BackSpace)
  }

  @MainActor
  func inputKeyNotSync(_ text: String) -> Bool {
    Rime.shared.inputKey(text)
  }

  @MainActor
  func getCaretPosition() -> Int {
    Rime.shared.getCaretPosition()
  }

  @MainActor
  func setCaretPosition(_ position: Int) {
    Rime.shared.setCaretPosition(position)
  }

  @MainActor
  func getContext() -> IRimeContext {
    Rime.shared.context()
  }
}

// MARK: - T9 拼音处理（stub — sime 不支持 T9）

public extension RimeContext {
  @MainActor
  func getPinyinCandidates() -> [String] { [] }
}
