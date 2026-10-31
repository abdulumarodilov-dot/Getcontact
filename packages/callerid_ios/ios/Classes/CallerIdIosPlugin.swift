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

  /// Extension'ning bundle ID'si: asosiy ilova ID + ".CallDirectory".
  /// Qayta imzolashda (AltStore, Sideloadly) asosiy ID o'zgarsa ham
  /// extension ID shunga mos o'zgaradi — shuning uchun doim hisoblaymiz.
  private var extensionId: String {
    (Bundle.main.bundleIdentifier ?? "") + ".CallDirectory"
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
      var info: [String: Any] = [
        "container": CallerIdIosPlugin.containerURL() != nil,
        "extensionId": extensionId,
      ]
      CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(
        withIdentifier: extensionId
      ) { status, error in
        DispatchQueue.main.async {
          switch status {
          case .enabled: info["enabled"] = "enabled"
          case .disabled: info["enabled"] = "disabled"
          default: info["enabled"] = "unknown"
          }
          if let error = error {
            info["error"] = CallerIdIosPlugin.describe(error)
          }
          result(info)
        }
      }

    case "reload":
      CXCallDirectoryManager.sharedInstance.reloadExtension(
        withIdentifier: extensionId
      ) { error in
        DispatchQueue.main.async {
          if let error = error {
            result(CallerIdIosPlugin.describe(error))
          } else {
            result(nil)  // muvaffaqiyat
          }
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
