import CallKit
import Flutter
import UIKit

/// Asosiy ilova tomoni: umumiy papka (App Group) yo'lini beradi,
/// extension holatini tekshiradi va uni qayta yuklaydi.
///
/// Ma'lumot faylini Dart o'zi yozadi (`containerPath` ichiga),
/// keyin `reload` chaqiriladi va iOS extension'ni ishga tushiradi.
public class CallerIdIosPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "getcontact/callerid_ios", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(CallerIdIosPlugin(), channel: channel)
  }

  /// Bo'laklar (extension'lar) soni.
  /// DIQQAT: tool/ios/add_call_directory.rb dagi PARTS va Dart'dagi
  /// CallerIdIos.parts bilan bir xil bo'lishi shart.
  static let parts = 4

  /// N-bo'lak extension'ining bundle ID'si: asosiy ilova ID +
  /// ".CallDirectory" (1-bo'lak) yoki ".CallDirectoryN".
  /// Qayta imzolashda (AltStore, Sideloadly) asosiy ID o'zgarsa ham
  /// extension ID shunga mos o'zgaradi — shuning uchun doim hisoblaymiz.
  private func extensionId(_ part: Int) -> String {
    let base = (Bundle.main.bundleIdentifier ?? "") + ".CallDirectory"
    return part == 1 ? base : base + String(part)
  }

  /// Umumiy papka. Avval AltStore/SideStore yozgan haqiqiy guruh nomlari
  /// (ALTAppGroups), keyin standart "group.<bundle id>".
  static func containerURL() -> URL? {
    var groups: [String] = []
    if let alt = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] {
      groups.append(contentsOf: alt)
    }
    if let id = Bundle.main.bundleIdentifier {
      groups.append("group." + id)
    }
    for g in groups {
      if let url = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: g)
      {
        return url
      }
    }
    return nil
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {

    case "containerPath":
      result(CallerIdIosPlugin.containerURL()?.path)

    case "status":
      // To'rttala extension holatini so'raymiz, javoblar kelgach qaytaramiz
      var states = [String](repeating: "unknown", count: Self.parts)
      var firstError: String?
      let group = DispatchGroup()
      for part in 1...Self.parts {
        group.enter()
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(
          withIdentifier: extensionId(part)
        ) { status, error in
          DispatchQueue.main.async {
            switch status {
            case .enabled: states[part - 1] = "enabled"
            case .disabled: states[part - 1] = "disabled"
            default: states[part - 1] = "unknown"
            }
            if let error = error, firstError == nil {
              firstError = CallerIdIosPlugin.describe(error)
            }
            group.leave()
          }
        }
      }
      group.notify(queue: .main) {
        var info: [String: Any] = [
          "container": CallerIdIosPlugin.containerURL() != nil,
          "parts": Self.parts,
          "states": states,
          "enabledCount": states.filter { $0 == "enabled" }.count,
        ]
        if let e = firstError { info["error"] = e }
        result(info)
      }

    case "reload":
      // Argument — bo'lak raqami (1…parts)
      let part = (call.arguments as? Int) ?? 1
      CXCallDirectoryManager.sharedInstance.reloadExtension(
        withIdentifier: extensionId(part)
      ) { error in
        DispatchQueue.main.async {
          guard let error = error else {
            result(["ok": true])
            return
          }
          // O'chirilgan extension — xato emas, ogohlantirish: foydalanuvchi
          // uni Sozlamalarda yoqqanda iOS ro'yxatni o'zi yuklaydi.
          let ns = error as NSError
          let disabled =
            ns.domain == CXErrorCodeCallDirectoryManagerError.errorDomain
            && ns.code == CXErrorCodeCallDirectoryManagerError.Code.extensionDisabled.rawValue
          result([
            "ok": false,
            "disabled": disabled,
            "message": CallerIdIosPlugin.describe(error),
          ])
        }
      }

    case "keepAwake":
      // Uzoq tayyorlash vaqtida ekran o'chib, ilova to'xtab qolmasin
      UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
      result(nil)

    case "openSettings":
      if #available(iOS 13.4, *) {
        CXCallDirectoryManager.sharedInstance.openSettings { _ in }
        result(true)
      } else {
        result(false)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// CallKit xatolarini foydalanuvchiga tushunarli matnga aylantiradi.
  static func describe(_ error: Error) -> String {
    let ns = error as NSError
    if ns.domain == CXErrorCodeCallDirectoryManagerError.errorDomain,
      let code = CXErrorCodeCallDirectoryManagerError.Code(rawValue: ns.code)
    {
      switch code {
      case .noExtensionFound:
        return "Extension topilmadi — ilova to'g'ri o'rnatilmagan"
      case .extensionDisabled:
        return "Extension o'chirilgan — Sozlamalarda yoqing"
      case .currentlyLoading:
        return "Ro'yxat hozir yuklanmoqda, biroz kuting"
      case .loadingInterrupted:
        return "Yuklash to'xtab qoldi (xotira yetmadi yoki fayl o'qilmadi)"
      case .entriesOutOfOrder:
        return "Raqamlar tartibi buzilgan"
      case .duplicateEntries:
        return "Takroriy raqamlar bor"
      case .maximumEntriesExceeded:
        return "Raqamlar soni iOS chegarasidan oshib ketdi"
      default:
        return "CallKit xatosi \(ns.code)"
      }
    }
    return error.localizedDescription
  }
}
