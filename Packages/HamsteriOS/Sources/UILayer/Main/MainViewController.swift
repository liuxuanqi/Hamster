//
//  File.swift
//
//
//  Created by morse on 2023/7/5.
//

import Combine
import HamsterUIKit
import UIKit

protocol SubViewControllerFactory {
  func makeSettingsViewController() -> SettingsViewController
  func makeKeyboardSettingsViewController() -> KeyboardSettingsViewController
  func makeKeyboardColorViewController() -> KeyboardColorViewController
  func makeKeyboardFeedbackViewController() -> KeyboardFeedbackViewController
}

open class MainViewController: UISplitViewController {
  private let mainViewModel: MainViewModel
  private let subViewControllerFactory: SubViewControllerFactory
  private let settingsViewController: SettingsViewController

  private lazy var keyboardSettingsViewController: KeyboardSettingsViewController
    = subViewControllerFactory.makeKeyboardSettingsViewController()

  private lazy var keyboardColorViewController: KeyboardColorViewController
    = subViewControllerFactory.makeKeyboardColorViewController()

  private lazy var keyboardFeedbackViewController: KeyboardFeedbackViewController
    = subViewControllerFactory.makeKeyboardFeedbackViewController()

  private lazy var primaryNavigationViewController: UINavigationController = {
    let vc = UINavigationController(rootViewController: settingsViewController)
    return vc
  }()

  private lazy var secondaryNavigationViewController: UINavigationController = {
    let vc = UINavigationController(rootViewController: keyboardSettingsViewController)
    return vc
  }()

  private var subscriptions = Set<AnyCancellable>()

  init(mainViewModel: MainViewModel, subViewControllerFactory: SubViewControllerFactory) {
    self.mainViewModel = mainViewModel
    self.subViewControllerFactory = subViewControllerFactory
    self.settingsViewController = subViewControllerFactory.makeSettingsViewController()

    super.init(style: .doubleColumn)
    self.delegate = self
    self.presentsWithGesture = false
    self.preferredDisplayMode = .twoBesideSecondary
    self.preferredSplitBehavior = .tile
    self.displayModeButtonVisibility = .never
    self.showsSecondaryOnlyButton = false
    self.setViewController(primaryNavigationViewController, for: .primary)
    self.setViewController(secondaryNavigationViewController, for: .secondary)
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - override UIViewController

extension MainViewController {
  override open func viewDidLoad() {
    super.viewDidLoad()

    mainViewModel.subViewPublished
      .receive(on: DispatchQueue.main)
      .sink { [unowned self] in
        self.navigationResponse(to: $0)
      }
      .store(in: &subscriptions)
  }
}

// MARK: - implementation UISplitViewControllerDelegate

extension MainViewController: UISplitViewControllerDelegate {
  public func splitViewController(_ svc: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
    return .primary
  }
}

// MARK: - custom method

extension MainViewController {
  func navigationResponse(to subView: SettingsSubView) {
    switch subView {
    case .keyboardSettings:
      presentViewController(keyboardSettingsViewController)
    case .colorSchema:
      presentViewController(keyboardColorViewController)
    case .feedback:
      presentViewController(keyboardFeedbackViewController)
    case .main:
      primaryNavigationViewController.popToRootViewController(animated: false)
    default:
      return
    }
  }

  private func presentViewController(_ vc: UIViewController) {
    primaryNavigationViewController.popToRootViewController(animated: false)
    if isCollapsed {
      primaryNavigationViewController.pushViewController(vc, animated: true)
      return
    }
    secondaryNavigationViewController.viewControllers = [vc]
  }
}
