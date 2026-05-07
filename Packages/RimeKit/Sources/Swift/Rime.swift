import Foundation
import HamsterKit
import os
import SimeEngine
import SimeSession

public class Rime {
    private let logger = Logger(
        subsystem: "com.ihsiao.apps.hamster.RimeKit",
        category: "Rime"
    )

    public static let shared: Rime = .init()

    private var session: SimeSession?
    private var isFirstRun = true
    private var traits: IRimeTraits?
    private var currentInputSchema: String = "mspy"
    private var commitBuffer: String = ""

    private weak var notificationDelegate: IRimeNotificationDelegate?

    private let rimeAPI = IRimeAPI()

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

        loadSession()
    }

    public func deploy(_ traits: IRimeTraits? = nil) -> Bool {
        notificationDelegate?.onDeployStart()
        notificationDelegate?.onDeploySuccess()
        return true
    }

    public func isRunning() -> Bool {
        return session != nil
    }

    public func shutdown() {
        session = nil
    }

    public func getSession() -> RimeSessionId {
        return session != nil ? 1 : 0
    }

    public func createSession() {
        if session == nil {
            loadSession()
        }
    }

    public func restSession() {
        session?.reset()
        session?.engine.clearHistory()
        commitBuffer = ""
    }

    public func openSchema(schema: String) -> IRimeConfig {
        IRimeConfig()
    }

    public func simplifiedChineseMode(key: String) -> Bool {
        return false
    }

    public func setSimplifiedChineseMode(key: String, value: Bool) {}

    public func inputKey(_ key: String) -> Bool {
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

    public func inputKeyCode(_ keycode: Int32, modifier: Int32 = 0) -> Bool {
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

    public func replaceInputKeys(_ inputKeys: String, startPos: Int, count: Int) -> Bool {
        return false
    }

    public func candidateList() -> [CandidateWord] {
        guard let session = session else { return [] }
        return session.candidates.map {
            CandidateWord(text: $0.word, comment: $0.pinyin)
        }
    }

    public func isAsciiMode() -> Bool {
        return session?.asciiMode ?? false
    }

    public func asciiMode(_ value: Bool) {
        session?.asciiMode = value
        notificationDelegate?.onChangeMode(value ? "ascii_mode" : "!ascii_mode")
    }

    public func getCandidate(index: Int, count: Int) -> [IRimeCandidate] {
        guard let session = session else { return [] }
        while index + count > session.candidates.count && session.hasMore {
            session.loadMore()
        }
        let all = session.candidates
        let end = min(index + count, all.count)
        guard index < all.count else { return [] }
        return all[index..<end].map { IRimeCandidate(text: $0.word, comment: $0.pinyin) }
    }

    public func selectCandidate(index: Int) -> Bool {
        guard let session = session else { return false }
        let result = session.handle(.select(index))
        if case .committed(let text) = result {
            commitBuffer = text
            return true
        }
        return result == .updated
    }

    public func candidateListWithIndex(index: Int, andCount count: Int) -> [CandidateWord] {
        guard let session = session else { return [] }
        while index + count > session.candidates.count && session.hasMore {
            session.loadMore()
        }
        let all = session.candidates
        let end = min(index + count, all.count)
        guard index < all.count else { return [] }
        return all[index..<end].map { CandidateWord(text: $0.word, comment: $0.pinyin) }
    }

    public func getInputKeys() -> String {
        return session?.preedit ?? ""
    }

    public func getCommitText() -> String {
        let text = commitBuffer
        commitBuffer = ""
        return text
    }

    public func cleanComposition() {
        session?.reset()
        session?.engine.clearHistory()
        commitBuffer = ""
    }

    public func status() -> IRimeStatus {
        let s = IRimeStatus()
        s.schemaId = currentInputSchema
        s.schemaName = "微软双拼"
        s.isASCIIMode = session?.asciiMode ?? false
        s.isComposing = !(session?.preedit.isEmpty ?? true) || (session?.hasSuggestions ?? false)
        s.isSimplified = true
        return s
    }

    public func context() -> IRimeContext {
        let ctx = IRimeContext()
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
        return session?.preedit.count ?? 0
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

    private func loadSession() {
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
            let engine = try InputEngine(dictURL: dictURL, englishURL: englishURL, userDictPath: userDictPath, bigramURL: bigramURL)
            session = SimeSession(engine: engine)
        } catch {
            logger.error("SimeEngine init failed: \(error.localizedDescription)")
        }
    }

    private func findDict(_ name: String) -> URL? {
        return findFile(name, ext: "dict.bin")
    }

    private func findFile(_ name: String, ext: String) -> URL? {
        let sharedDir = traits?.sharedDataDir ?? ""
        if !sharedDir.isEmpty {
            let base = URL(fileURLWithPath: sharedDir)
            let url = base.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            let schemaURL = base.appendingPathComponent("schemas/wanxiang/\(name).\(ext)")
            if FileManager.default.fileExists(atPath: schemaURL.path) {
                return schemaURL
            }
        }
        let userDir = traits?.userDataDir ?? ""
        if !userDir.isEmpty {
            let url = URL(fileURLWithPath: userDir).appendingPathComponent("\(name).\(ext)")
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
