//
//  SceneDelegate.swift
//  Hamster
//
//  Created by morse on 2023/6/5.
//

import HamsteriOS
import HamsterKit
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate, UISceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }

    if window == nil {
      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = HamsterAppDependencyContainer.shared.makeRootController()
      self.window = window
      window.makeKeyAndVisible()
    }

    if let url = connectionOptions.urlContexts.first?.url {
      let components = url.lastPathComponent
      if let subView = SettingsSubView(rawValue: components) {
        HamsterAppDependencyContainer.shared.mainViewModel.navigation(subView)
      }
    }
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let windowScene = (scene as? UIWindowScene) else { return }

    if window == nil {
      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = HamsterAppDependencyContainer.shared.makeRootController()
      self.window = window
      window.makeKeyAndVisible()
    }

    if let url = URLContexts.first?.url {
      let components = url.lastPathComponent
      if let subView = SettingsSubView(rawValue: components) {
        HamsterAppDependencyContainer.shared.mainViewModel.navigation(subView)
      }
    }
  }

  func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
    completionHandler(true)
  }

  func sceneDidDisconnect(_ scene: UIScene) {}
  func sceneDidBecomeActive(_ scene: UIScene) {}
  func sceneWillResignActive(_ scene: UIScene) {}
  func sceneWillEnterForeground(_ scene: UIScene) {}
  func sceneDidEnterBackground(_ scene: UIScene) {}
}
