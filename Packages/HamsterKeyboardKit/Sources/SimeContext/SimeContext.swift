//
//  SimeContext.swift
//
//  Created by morse on 2023/6/30.
//

import Combine
import Foundation
import HamsterKit
import OSLog
import SimeEngine
import SimeSession

/// 输入法运行时上下文
public class SimeContext {
  private let logger = Logger(
    subsystem: "com.ihsiao.apps.hamster.keyboard",
    category: "SimeContext"
  )

  /// 最大候选词数量
  public private(set) lazy var maximumNumberOfCandidateWords: Int = 100

  private static let wanxiangSchema = RimeSchema(schemaId: "wanxiang", schemaName: "万象")

  /// 当前输入方案
  public var currentSchema: RimeSchema? { Self.wanxiangSchema }

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

  /// 字母模式
  @MainActor
  public lazy var asciiMode: Bool = false

  /// 候选字
  @MainActor @Published
  public var suggestions: [CandidateSuggestion] = []

  @MainActor @Published
  public var rimeContext: ISimeContext? = nil

  /// rime option
  @MainActor @Published
  public var optionState: String? = nil

  /// 划动分页模式下，当前页码，从 0 开始
  public lazy var pageIndex: Int = 0

  /// 根据页码计算首个候选文字索引
  public var candidateIndex: Int {
    pageIndex * maximumNumberOfCandidateWords
  }

  // MARK: - Engine state

  private var session: SimeSession?
  private var commitBuffer: String = ""
  private var sharedDataDir: String = ""
  private var userDataDir: String = ""

  public init() {}

  func setMaximumNumberOfCandidateWords(_ count: Int) {
    self.maximumNumberOfCandidateWords = count
  }
}

// MARK: - Engine lifecycle

public extension SimeContext {
  /// 引擎启动
  func start() async {
    self.sharedDataDir = FileManager.appGroupSharedSupportDirectoryURL.path
    self.userDataDir = FileManager.appGroupUserDataDirectoryURL.path
    loadSession()
    await setAsciiMode(session?.asciiMode ?? false)
  }

  /// 引擎关闭
  func shutdown() {
    session = nil
  }

  var isRunning: Bool {
    session != nil
  }
}

// MARK: - Input handling

public extension SimeContext {
  @MainActor
  func tryHandleInputText(_ text: String) -> Bool {
    let handled = inputKey(text)
    guard handled else { return false }
    self.syncContext()
    return true
  }

  @MainActor
  func tryHandleInputCode(_ code: Int32, modifier: Int32 = 0) -> Bool {
    let handled = inputKeyCode(code, modifier: modifier)
    guard handled else { return false }
    self.syncContext()
    return true
  }

  func getInputKeys() -> String {
    session?.preedit ?? ""
  }

  /// 根据索引选择候选字
  @MainActor
  func selectCandidate(index: Int) {
    guard let session = session else { return }
    let result = session.handle(.select(index))
    if case .committed(let text) = result {
      commitBuffer = text
    }
    syncContext()
  }

  /// 中英切换
  @MainActor
  func switchEnglishChinese() {
    self.reset()
    self.asciiMode.toggle()
    session?.asciiMode = asciiMode
    let mode = asciiMode ? "ascii_mode" : "!ascii_mode"
    onChangeMode(mode)
  }

  @MainActor
  func deleteBackward() {
    _ = inputKeyCode(XK_BackSpace)
    self.syncContext()
  }

  @MainActor
  func deleteBackwardNotSync() {
    _ = inputKeyCode(XK_BackSpace)
  }

  @MainActor
  func inputKeyNotSync(_ text: String) -> Bool {
    inputKey(text)
  }

  @MainActor
  func getCaretPosition() -> Int {
    session?.preedit.count ?? 0
  }

  @MainActor
  func setCaretPosition(_ position: Int) {}

  @MainActor
  func getContext() -> ISimeContext {
    buildContext()
  }

  func candidateListWithIndex(index: Int, andCount count: Int) -> [CandidateWord] {
    guard let session = session else { return [] }
    while index + count > session.candidates.count && session.hasMore {
      session.loadMore()
    }
    let all = session.candidates
    let end = min(index + count, all.count)
    guard index < all.count else { return [] }
    return all[index..<end].map { CandidateWord(text: $0.word, comment: $0.pinyin) }
  }
}

// MARK: - Context sync

public extension SimeContext {
  /// RIME Context 状态重置
  @MainActor
  func reset() {
    self.pageIndex = 0
    self.userInputKey = ""
    self.suggestions.removeAll(keepingCapacity: false)
    session?.reset()
    session?.engine.clearHistory()
    commitBuffer = ""
  }

  func resetCommitText() {
    self.commitText = ""
  }

  @MainActor
  func setAsciiMode(_ value: Bool) {
    self.asciiMode = value
  }

  /// 同步context
  @MainActor
  func syncContext() {
    self.pageIndex = 0
    self.rimeContext = buildContext()
    let userInputText = rimeContext?.composition?.preedit ?? ""
    let commitText = getCommitText()
    var candidates = [CandidateSuggestion]()

    var highlightIndex = 0
    if let menu = rimeContext?.menu {
      highlightIndex = Int(menu.pageSize * menu.pageNo + menu.highlightedCandidateIndex)
    }
    candidates = self.candidateListLimit(index: candidateIndex, highlightIndex: highlightIndex, count: maximumNumberOfCandidateWords)

    let isComposing = !(session?.preedit.isEmpty ?? true) || (session?.hasSuggestions ?? false)

    if !isComposing {
      self.commitText = commitText
      self.reset()
      return
    }

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
    let candidates = candidateListWithIndex(index: index, andCount: count)
    var result: [CandidateSuggestion] = []
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
}

// MARK: - Notification delegate (self)

extension SimeContext: IRimeNotificationDelegate {
  @MainActor
  public func onChangeMode(_ option: String) {
    let optionState = !option.hasPrefix("!")
    if option.hasSuffix("ascii_mode") {
      self.setAsciiMode(optionState)
      self.optionState = optionState ? "英" : "中"
    }
  }

  @MainActor
  public func onLoadingSchema(_ loadSchema: String) {}
}

// MARK: - Legacy compatibility stubs

public extension SimeContext {
  /// switcher（单方案，无操作）
  @MainActor
  func switcher() {}

  /// 切换输入方案（单方案，只 reset）
  @MainActor
  func switchLatestInputSchema() {
    self.reset()
  }

  func setupRimeInputSchema() {}

  @MainActor
  func getPinyinCandidates() -> [String] { [] }
}

// MARK: - Private engine methods

private extension SimeContext {
  func inputKey(_ key: String) -> Bool {
    createSession()
    guard let session = session, let char = key.first, key.count == 1 else { return false }

    if char == " " {
      let result = session.handle(.commit)
      if case .committed(let text) = result {
        commitBuffer = text
        return true
      }
      return false
    }

    if !char.isLetter && char != ";" {
      let result = session.handle(.punctuation(char))
      if case .committed(let text) = result {
        commitBuffer = text
        return true
      }
      return false
    }

    commitBuffer = ""
    let result = session.handle(.key(char))
    return result != .passThrough
  }

  func inputKeyCode(_ keycode: Int32, modifier: Int32 = 0) -> Bool {
    createSession()
    guard let session = session else { return false }

    if keycode == XK_BackSpace {
      let result = session.handle(.backspace)
      commitBuffer = ""
      return result != .passThrough
    }

    if keycode == XK_Return || keycode == XK_KP_Enter {
      let result = session.handle(.commitRaw)
      if case .committed(let text) = result {
        commitBuffer = text
        return true
      }
      return false
    }

    if keycode == XK_Escape {
      session.handle(.clearSession)
      commitBuffer = ""
      return true
    }

    if keycode >= XK_space && keycode <= 0x7e && modifier == 0 {
      let char = Character(UnicodeScalar(UInt32(keycode))!)
      return inputKey(String(char))
    }

    return false
  }

  func getCommitText() -> String {
    let text = commitBuffer
    commitBuffer = ""
    return text
  }

  func buildContext() -> ISimeContext {
    let ctx = ISimeContext()
    guard let session = session else { return ctx }

    let preedit = session.preedit
    let hasCandidates = !preedit.isEmpty || session.hasSuggestions
    if hasCandidates {
      ctx.composition.preedit = preedit
      ctx.composition.length = Int32(preedit.count)
      ctx.composition.cursorPos = Int32(preedit.count)

      let candidates = session.candidates
      ctx.menu.numCandidates = Int32(candidates.count)
      ctx.menu.pageSize = 5
      ctx.menu.pageNo = 0
      ctx.menu.isLastPage = !session.hasMore && candidates.count <= 5
      ctx.menu.highlightedCandidateIndex = 0
      if !candidates.isEmpty {
        ctx.commitTextPreview = candidates[0].word
      }
    }

    return ctx
  }

  func createSession() {
    if session == nil {
      loadSession()
    }
  }

  func loadSession() {
    guard session == nil else { return }
    guard let dictURL = findDict("wanxiang"),
          let englishURL = findDict("wanxiang_english") else {
      logger.warning("SimeEngine: dict files not found, engine not loaded")
      return
    }
    do {
      let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
      let userDictPath = docsDir.appendingPathComponent("user.db").path
      let bigramURL = findFile("wanxiang", ext: "bigram.bin")
      let wordBigramURL = findFile("wanxiang", ext: "wordbigram.bin")
      let engine = try InputEngine(dictURL: dictURL, englishURL: englishURL, userDictPath: userDictPath, bigramURL: bigramURL, wordBigramURL: wordBigramURL)
      session = SimeSession(engine: engine)
    } catch {
      logger.error("SimeEngine init failed: \(error.localizedDescription)")
    }
  }

  func findDict(_ name: String) -> URL? {
    findFile(name, ext: "dict.bin")
  }

  func findFile(_ name: String, ext: String) -> URL? {
    if !sharedDataDir.isEmpty {
      let base = URL(fileURLWithPath: sharedDataDir)
      let url = base.appendingPathComponent("\(name).\(ext)")
      if FileManager.default.fileExists(atPath: url.path) {
        return url
      }
      let schemaURL = base.appendingPathComponent("schemas/wanxiang/\(name).\(ext)")
      if FileManager.default.fileExists(atPath: schemaURL.path) {
        return schemaURL
      }
    }
    if !userDataDir.isEmpty {
      let url = URL(fileURLWithPath: userDataDir).appendingPathComponent("\(name).\(ext)")
      if FileManager.default.fileExists(atPath: url.path) {
        return url
      }
    }
    if let url = Bundle.main.url(forResource: name, withExtension: ext) {
      return url
    }
    return nil
  }
}
