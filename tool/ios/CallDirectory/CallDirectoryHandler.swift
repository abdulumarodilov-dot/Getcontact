import CallKit
import Foundation

/// Call Directory extension: iOS qo'ng'iroq kelganda raqamni shu ro'yxatdan
/// topib, ekranda ismni ko'rsatadi.
///
/// Ro'yxatni asosiy ilova yozadi (umumiy papkada `callerid.bin`):
///
///   0   4  "GCCD"
///   4   4  versiya (1), little-endian
///   8   4  N — yozuvlar soni
///   12  8*N      raqamlar (Int64, o'sish tartibida, takrorsiz)
///   ..  4*(N+1)  ism boshlanishlari (UInt32, ismlar blokiga nisbatan)
///   ..           ismlar (UTF-8, ketma-ket)
///
/// Fayl xotiraga "map" qilinadi — millionlab yozuvda ham extension
/// xotira limitidan oshmaydi.
final class CallDirectoryHandler: CXCallDirectoryProvider {

  private static let fileName = "callerid.bin"
  private static let batch = 5_000

  override func beginRequest(with context: CXCallDirectoryExtensionContext) {
    context.delegate = self

    // Har safar ro'yxatni to'liq qaytadan beramiz
    if context.isIncremental {
      context.removeAllIdentificationEntries()
    }

    do {
      try addEntries(to: context)
      context.completeRequest()
    } catch {
      context.cancelRequest(withError: error)
    }
  }

  private func addEntries(to context: CXCallDirectoryExtensionContext) throws {
    guard let dir = Self.containerURL() else {
      // Umumiy papka yo'q — bo'sh ro'yxat bilan tugatamiz
      return
    }
    let url = dir.appendingPathComponent(Self.fileName)
    guard FileManager.default.fileExists(atPath: url.path) else { return }

    let data = try Data(contentsOf: url, options: .alwaysMapped)
    try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
      guard raw.count >= 12,
        raw[0] == 0x47, raw[1] == 0x43, raw[2] == 0x43, raw[3] == 0x44  // "GCCD"
      else { throw Self.err(1, "Fayl formati noto'g'ri") }

      let version = UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: 4, as: UInt32.self))
      guard version == 1 else { throw Self.err(2, "Fayl versiyasi noma'lum") }

      let n = Int(UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: 8, as: UInt32.self)))
      let numbersAt = 12
      let offsetsAt = numbersAt + 8 * n
      let labelsAt = offsetsAt + 4 * (n + 1)
      guard raw.count >= labelsAt else { throw Self.err(3, "Fayl to'liq emas") }

      var i = 0
      while i < n {
        autoreleasepool {
          let end = min(i + Self.batch, n)
          while i < end {
            let number = Int64(
              littleEndian: raw.loadUnaligned(fromByteOffset: numbersAt + 8 * i, as: Int64.self))
            let s = Int(
              UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: offsetsAt + 4 * i, as: UInt32.self)))
            let e = Int(
              UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: offsetsAt + 4 * (i + 1), as: UInt32.self)))

            let a = labelsAt + s
            let b = labelsAt + e
            let label: String
            if a <= b && b <= raw.count {
              label = String(decoding: UnsafeRawBufferPointer(rebasing: raw[a..<b]), as: UTF8.self)
            } else {
              label = ""
            }
            context.addIdentificationEntry(
              withNextSequentialPhoneNumber: number, label: label)
            i += 1
          }
        }
      }
    }
  }

  /// Asosiy ilova bilan bir xil qoida: avval ALTAppGroups, keyin
  /// "group.<asosiy ilova ID>" (extension ID'dan ".CallDirectory" olib tashlanadi).
  static func containerURL() -> URL? {
    var groups: [String] = []
    if let alt = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] {
      groups.append(contentsOf: alt)
    }
    if var id = Bundle.main.bundleIdentifier {
      let suffix = ".CallDirectory"
      if id.hasSuffix(suffix) { id.removeLast(suffix.count) }
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

  private static func err(_ code: Int, _ msg: String) -> NSError {
    NSError(
      domain: "uz.getcontact.CallDirectory", code: code,
      userInfo: [NSLocalizedDescriptionKey: msg])
  }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
  func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
    // Xato asosiy ilovaga reloadExtension natijasi sifatida qaytadi
  }
}
