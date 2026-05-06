import Foundation
import HamsterKit
import os
import SimeEngine

public class Rime {
    private let logger = Logger(
        subsystem: "com.ihsiao.apps.hamster.RimeKit",
        category: "Rime"
    )

    public static let shared: Rime = .init()

    private var inputEngine: InputEngine?
    private var isFirstRun = true
    private var traits: IRimeTraits?
    private var session: RimeSessionId = 0
    private var currentInputSchema: String = "mspy"
    private var currentSimplifiedModeKey: String = ""
    private var currentSimplifiedModeValue: Bool = false
    private var asciiMode: Bool = false
    private var commitBuffer: String = ""

    private let rimeAPI = IRimeAPI()

    private weak var notificationDelegate: IRimeNotificationDelegate?

    private init() {}

    public func API() -> IRimeAPI {
        return rimeAPI
    }

    public static func createTraits(sharedSupportDir: String, userDataDir: String, models: [String] = []) -> IRimeTraits {
        let traits = IRimeTraits()
        traits.sharedDataDir = sharedSupportDir
        traits.userDataDir = userDataDir
        traits.distributionCodeName = "TianShu"
        traits.distributionName = "TianShu"
        traits.distributionVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        traits.appName = "rime.Hamster"
        if !models.isEmpty {
            traits.modules = models
        }
        return traits
    }

    public func setNotificationDelegate(_ delegate: IRimeNotificationDelegate) {
        notificationDelegate = delegate
    }

    public func setupRime(sharedSupportDir: String, userDataDir: String) {
        setupRime(Self.createTraits(sharedSupportDir: sharedSupportDir, userDataDir: userDataDir))
    }

    public func setupRime(_ traits: IRimeTraits) {
        if isFirstRun {
            isFirstRun = false
        }
    }

    public func initialize(_ traits: IRimeTraits? = nil) {}

    public func start(_ traits: IRimeTraits? = nil, maintenance: Bool = false, fullCheck: Bool = false) {
        if let traits = traits {
            setupRime(traits)
        }
        self.traits = traits

        if maintenance, let userDir = traits?.userDataDir, !userDir.isEmpty {
            let buildDir = URL(fileURLWithPath: userDir).appendingPathComponent("build")
            try? FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
        }

        loadEngine()
    }

    public func deploy(_ traits: IRimeTraits? = nil) -> Bool {
        notificationDelegate?.onDeployStart()
        notificationDelegate?.onDeploySuccess()
        return true
    }

    public func isRunning() -> Bool {
        return session != 0
    }

    public func shutdown() {
        inputEngine = nil
        session = 0
    }

    public func getSession() -> RimeSessionId {
        return session
    }

    public func createSession() {
        if !isRunning() {
            loadEngine()
            session = 1
        }
    }

    public func restSession() {
        inputEngine?.reset()
        commitBuffer = ""
    }

    public func openSchema(schema: String) -> IRimeConfig {
        IRimeConfig()
    }

    public func simplifiedChineseMode(key: String) -> Bool {
        return currentSimplifiedModeValue
    }

    public func setSimplifiedChineseMode(key: String, value: Bool) {
        currentSimplifiedModeKey = key
        currentSimplifiedModeValue = value
    }

    public func inputKey(_ key: String) -> Bool {
        createSession()
        guard let engine = inputEngine, let char = key.first, key.count == 1 else { return false }

        if char == " " {
            if let text = engine.commit() {
                commitBuffer = text
                return true
            }
            return false
        }

        // Punctuation while composing → commit first candidate + append punctuation
        let isComposing = !engine.preedit().isEmpty
        if isComposing && !char.isLetter && char != ";" {
            let committed = engine.commit() ?? ""
            let mapped = Self.mapPunctuation(char)
            commitBuffer = committed + mapped
            return true
        }

        commitBuffer = ""
        return engine.processKey(char)
    }

    private static func mapPunctuation(_ char: Character) -> String {
        switch char {
        case ",": return "\u{FF0C}"
        case ".": return "\u{3002}"
        case "?": return "\u{FF1F}"
        case "!": return "\u{FF01}"
        case ":": return "\u{FF1A}"
        case "\"": return "\u{201C}"
        case "'": return "\u{2018}"
        case "(": return "\u{FF08}"
        case ")": return "\u{FF09}"
        default: return String(char)
        }
    }

    public func inputKeyCode(_ keycode: Int32, modifier: Int32 = 0) -> Bool {
        createSession()
        guard let engine = inputEngine else { return false }

        if keycode == XK_BackSpace {
            engine.backspace()
            commitBuffer = ""
            return true
        }

        if keycode == XK_Return || keycode == XK_KP_Enter {
            let raw = engine.rawInput()
            if !raw.isEmpty {
                commitBuffer = raw
                engine.reset()
                return true
            }
            return false
        }

        if keycode == XK_Escape {
            engine.reset()
            commitBuffer = ""
            return true
        }

        if keycode >= XK_space && keycode <= 0x7e && modifier == 0 {
            let char = Character(UnicodeScalar(UInt32(keycode))!)
            return inputKey(String(char))
        }

        return false
    }

    public func replaceInputKeys(_ inputKeys: String, startPos: Int, count: Int) -> Bool {
        return false
    }

    public func candidateList() -> [CandidateWord] {
        guard let engine = inputEngine else { return [] }
        return engine.candidates().map {
            CandidateWord(text: $0.word, comment: $0.pinyin)
        }
    }

    public func isAsciiMode() -> Bool {
        return asciiMode
    }

    public func asciiMode(_ value: Bool) {
        asciiMode = value
        notificationDelegate?.onChangeMode(value ? "ascii_mode" : "!ascii_mode")
    }

    public func getCandidate(index: Int, count: Int) -> [IRimeCandidate] {
        guard let engine = inputEngine else { return [] }
        let all = engine.candidates()
        let end = min(index + count, all.count)
        guard index < all.count else { return [] }
        return all[index..<end].map { IRimeCandidate(text: $0.word, comment: $0.pinyin) }
    }

    public func selectCandidate(index: Int) -> Bool {
        guard let engine = inputEngine else { return false }
        guard let word = engine.select(index: index) else { return false }
        commitBuffer = word
        return true
    }

    public func candidateListWithIndex(index: Int, andCount count: Int) -> [CandidateWord] {
        guard let engine = inputEngine else { return [] }
        let all = engine.candidates()
        let end = min(index + count, all.count)
        guard index < all.count else { return [] }
        return all[index..<end].map { CandidateWord(text: $0.word, comment: $0.pinyin) }
    }

    public func getInputKeys() -> String {
        return inputEngine?.preedit() ?? ""
    }

    public func getCommitText() -> String {
        let text = commitBuffer
        commitBuffer = ""
        return text
    }

    public func cleanComposition() {
        inputEngine?.reset()
        commitBuffer = ""
    }

    public func status() -> IRimeStatus {
        let s = IRimeStatus()
        s.schemaId = currentInputSchema
        s.schemaName = "微软双拼"
        s.isASCIIMode = asciiMode
        s.isComposing = !(inputEngine?.preedit().isEmpty ?? true)
        s.isSimplified = true
        return s
    }

    public func context() -> IRimeContext {
        let ctx = IRimeContext()
        guard let engine = inputEngine else { return ctx }

        let preedit = engine.preedit()
        if !preedit.isEmpty {
            ctx.composition.preedit = preedit
            ctx.composition.length = Int32(preedit.count)
            ctx.composition.cursorPos = Int32(preedit.count)

            let candidates = engine.candidates()
            ctx.menu.numCandidates = Int32(candidates.count)
            ctx.menu.pageSize = 5
            ctx.menu.pageNo = 0
            ctx.menu.isLastPage = candidates.count <= 5
            ctx.menu.highlightedCandidateIndex = 0
            if !candidates.isEmpty {
                ctx.commitTextPreview = candidates[0].word
            }
        }

        return ctx
    }

    public func getSchemas() -> [RimeSchema] {
        return [RimeSchema(schemaId: "mspy", schemaName: "微软双拼")]
    }

    public func currentSchema() -> RimeSchema? {
        return RimeSchema(schemaId: currentInputSchema, schemaName: "微软双拼")
    }

    public func setSchema(_ schemaId: String) -> Bool {
        createSession()
        currentInputSchema = schemaId
        return true
    }

    public func getAvailableRimeSchemas() -> [RimeSchema] {
        return [RimeSchema(schemaId: "mspy", schemaName: "微软双拼")]
    }

    public func getSelectedRimeSchema() -> [RimeSchema] {
        return [RimeSchema(schemaId: "mspy", schemaName: "微软双拼")]
    }

    public func selectRimeSchemas(_ schemas: [String]) -> Bool {
        return true
    }

    public func getHotkeys() -> String {
        return "f4"
    }

    public func getCaretPosition() -> Int {
        return inputEngine?.preedit().count ?? 0
    }

    public func setCaretPosition(_ position: Int) {}

    public func getConfigFileValue(configFileName: String, key: String) -> String? {
        return nil
    }

    public func getStateLabel(option: String, state: Bool, abbreviated: Bool) -> String {
        if option == "ascii_mode" {
            return state ? "英" : "中"
        }
        return state ? "ON" : "OFF"
    }

    // MARK: - Private

    private func loadEngine() {
        guard inputEngine == nil else { return }
        guard let dictURL = findDict("wanxiang"),
              let englishURL = findDict("wanxiang_english") else {
            logger.warning("SimeEngine: dict files not found, engine not loaded")
            return
        }
        do {
            inputEngine = try InputEngine(dictURL: dictURL, englishURL: englishURL)
        } catch {
            logger.error("SimeEngine init failed: \(error.localizedDescription)")
        }
    }

    private func findDict(_ name: String) -> URL? {
        let sharedDir = traits?.sharedDataDir ?? ""
        if !sharedDir.isEmpty {
            let url = URL(fileURLWithPath: sharedDir).appendingPathComponent("\(name).dict.bin")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        let userDir = traits?.userDataDir ?? ""
        if !userDir.isEmpty {
            let url = URL(fileURLWithPath: userDir).appendingPathComponent("\(name).dict.bin")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "dict.bin") {
            return url
        }
        return nil
    }
}

extension Rime {
    private static let asciiModeKey = "ascii_mode"
    private static let simplifiedChineseKey = "simplification"
}
