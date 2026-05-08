//
//  RimeDeployIntent.swift
//  Hamster
//
//  Created by morse on 22/6/2023.
//

import AppIntents
import HamsteriOS
import HamsterKit
import OSLog

@available(iOS 16.0, *)
struct RimeDeployIntent: AppIntent {
  static var title: LocalizedStringResource = "重新部署"

  static var openAppWhenRun: Bool {
    return true
  }

  static var authenticationPolicy: IntentAuthenticationPolicy {
    .requiresAuthentication
  }

  static var description = IntentDescription("天枢 - 重新部署")

  @MainActor
  func perform() async throws -> some ReturnsValue {
    return .result()
  }
}
