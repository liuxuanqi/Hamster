import Foundation
import HamsterKit

public protocol IRimeNotificationDelegate: AnyObject {
    func onChangeMode(_ mode: String)
    func onLoadingSchema(_ schema: String)
}

public class IRimeTraits: @unchecked Sendable {
    public var sharedDataDir: String = ""
    public var userDataDir: String = ""

    public init() {}
}

public class IRimeStatus: @unchecked Sendable {
    public var schemaId: String = ""
    public var schemaName: String = ""
    public var isASCIIMode: Bool = false
    public var isComposing: Bool = false
    public var isSimplified: Bool = true

    public init() {}
}

public class IRimeMenu: @unchecked Sendable {
    public var pageSize: Int32 = 5
    public var pageNo: Int32 = 0
    public var isLastPage: Bool = true
    public var highlightedCandidateIndex: Int32 = 0
    public var numCandidates: Int32 = 0
    public var selectKeys: String = ""
    public var candidates: [CandidateWord] = []

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
    public var labels: [String]? = nil

    public init() {
        self.menu = IRimeMenu()
        self.composition = IRimeComposition()
    }
}
