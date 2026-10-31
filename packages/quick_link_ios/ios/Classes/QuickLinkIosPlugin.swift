import Flutter
import UIKit

/// `getcontact://...` havolalarini qabul qilib, Dart'ga uzatadi.
///
/// Flutter 3.38+ shablonida ilova UIScene bilan ishlaydi:
///   • ilova YOPIQ bo'lsa, havola `scene(_:willConnectTo:options:)` ichida
///     (`connectionOptions.urlContexts`) keladi;
///   • ilova FONDA bo'lsa — `scene(_:openURLContexts:)` orqali.
/// Eski (scene'siz) shablon uchun `application(_:open:options:)` ham bor.
///
/// Dart hali tayyor bo'lmasa (ilova endi ishga tushyapti), havola
/// saqlab qo'yiladi va Dart "ready" chaqirganda qaytariladi.
public class QuickLinkIosPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {

  private let channel: FlutterMethodChannel
  private var dartReady = false
  private var pending: [String] = []

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "getcontact/links", binaryMessenger: registrar.messenger())
    let instance = QuickLinkIosPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
    registrar.addSceneDelegate(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "ready":
      // Dart tinglashga tayyor: shu paytgacha kelgan havolalarni beramiz
      dartReady = true
      let out = pending
      pending.removeAll()
      result(out)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// true — havola bizniki va qabul qilindi
  @discardableResult
  private func receive(_ url: URL?) -> Bool {
    guard let url = url, url.scheme?.lowercased() == "getcontact" else { return false }
    let s = url.absoluteString
    if dartReady {
      channel.invokeMethod("onLink", arguments: s)
    } else {
      pending.append(s)
    }
    return true
  }

  // ── UIScene: ilova yopiq holatdan havola bilan ochilganda ──
  @objc(scene:willConnectToSession:options:)
  public func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    for ctx in connectionOptions?.urlContexts ?? [] {
      receive(ctx.url)
    }
    // false — scene ulanishini boshqa plaginlar ham ko'rsin
    return false
  }

  // ── UIScene: ilova fonda turganda havola kelganda ──
  @objc(scene:openURLContexts:)
  public func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    var handled = false
    for ctx in URLContexts {
      if receive(ctx.url) { handled = true }
    }
    return handled
  }

  // ── Scene'siz eski shablon ──
  @objc(application:openURL:options:)
  public func application(
    _ app: UIApplication, open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return receive(url)
  }
}
