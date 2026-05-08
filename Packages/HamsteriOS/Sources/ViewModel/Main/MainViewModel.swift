//
//  File.swift
//
//
//  Created by morse on 2023/7/7.
//

import Combine
import Foundation

public class MainViewModel: ObservableObject {
  public let subViewSubject = PassthroughSubject<SettingsSubView, Never>()
  public var subViewPublished: AnyPublisher<SettingsSubView, Never> {
    subViewSubject.eraseToAnyPublisher()
  }

  public func navigation(_ subView: SettingsSubView) {
    subViewSubject.send(subView)
  }
}
