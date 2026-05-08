import Foundation

public typealias RimeSessionId = UInt

public protocol IRimeNotificationDelegate: AnyObject {
    func onDeployStart()
    func onDeploySuccess()
    func onDeployFailure()
    func onChangeMode(_ mode: String)
    func onLoadingSchema(_ schema: String)
}

public class IRimeTraits: @unchecked Sendable {
    public var sharedDataDir: String = ""
    public var userDataDir: String = ""
    public var distributionName: String = ""
    public var distributionCodeName: String = ""
    public var distributionVersion: String = ""
    public var appName: String = ""
    public var modules: [String] = []
    public var minLogLevel: Int32 = 0
    public var logDir: String = ""
    public var prebuiltDataDir: String = ""
    public var stagingDir: String = ""

    public init() {}
}

public class IRimeStatus: @unchecked Sendable {
    public var schemaId: String = ""
    public var schemaName: String = ""
    public var isASCIIMode: Bool = false
    public var isASCIIPunct: Bool = false
    public var isComposing: Bool = false
    public var isDisabled: Bool = false
    public var isFullShape: Bool = false
    public var isSimplified: Bool = true
    public var isTraditional: Bool = false

    public init() {}
}

public class IRimeCandidate: @unchecked Sendable {
    public var text: String = ""
    public var comment: String = ""

    public init() {}
    public init(text: String, comment: String) {
        self.text = text
        self.comment = comment
    }
}

public class IRimeMenu: @unchecked Sendable {
    public var pageSize: Int32 = 5
    public var pageNo: Int32 = 0
    public var isLastPage: Bool = true
    public var highlightedCandidateIndex: Int32 = 0
    public var numCandidates: Int32 = 0
    public var selectKeys: String = ""
    public var candidates: [IRimeCandidate] = []

    public init() {}
}

public class IRimeComposition: @unchecked Sendable {
    public var length: Int32 = 0
    public var cursorPos: Int32 = 0
    public var selStart: Int32 = 0
    public var selEnd: Int32 = 0
    public var preedit: String = ""

    public init() {}
}

public class IRimeContext: @unchecked Sendable {
    public var commitTextPreview: String = ""
    public var menu: IRimeMenu!
    public var composition: IRimeComposition!
    public var labels: [String] = []

    public init() {
        self.menu = IRimeMenu()
        self.composition = IRimeComposition()
    }
}

public class IRimeConfig: @unchecked Sendable {
    public init() {}
    public func getString(_ key: String) -> String? { nil }
    public func getBool(_ key: String) -> Bool { false }
    public func getInt(_ key: String) -> Int32 { 0 }
    public func setInt(_ key: String, value: Int32) -> Bool { false }
    public func getDouble(_ key: String) -> Double { 0 }
    public func close() {}
}

public class IRimeAPI: @unchecked Sendable {
    public init() {}
    public func syncUserData() -> Bool { true }
    public func customize(_ key: String, stringValue value: String) -> Bool { true }
    public func customize(_ key: String, boolValue value: Bool) -> Bool { true }
    public func getCustomize(_ key: String) -> String? { nil }
}
