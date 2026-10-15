import Flutter
import UIKit
import LocalAuthentication

class HardwareServiceHandler {
  static let CHANNEL = "com.intelliattend.faculty/hardware"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: CHANNEL,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler(handle)
  }

  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAutoTimeEnabled":
      // iOS does not expose a public API for auto time setting.
      // Security relies on server-anchored clock drift detection instead.
      result(true)

    case "isAutoTimeZoneEnabled":
      // On iOS 16+ the time zone automatic setting is not publicly queryable.
      // We rely on the timezone offset check in Dart (IST enforcement).
      result(true)

    case "getMonotonicTime":
      let uptime = ProcessInfo.processInfo.systemUptime
      // systemUptime is in seconds (TimeInterval = Double), convert to ms
      result(Int(uptime * 1000))

    case "openDateSettings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        if UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
          result(true)
        } else {
          result(false)
        }
      } else {
        result(false)
      }

    case "generateKeyPair":
      generateKey(result: result)

    case "signPayload":
      guard let args = call.arguments as? [String: Any],
            let data = args["data"] as? String else {
        result(nil)
        return
      }
      signPayload(data: data, result: result)

    case "getPublicKey":
      getPublicKey(result: result)

    case "isKeyPairGenerated":
      isKeyPairGenerated(result: result)

    case "deleteKeyPair":
      deleteKeyPair(result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Keychain-backed Key Management

  private static let keyTag = "com.intelliattend.faculty.hardwareKey"

  private static func generateKey(result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let attributes: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        kSecAttrKeySizeInBits as String: 256,
        kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
        kSecPrivateKeyAttrs as String: [
          kSecAttrIsPermanent as String: true,
          kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
          kSecAttrAccessControl as String: SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .privateKeyUsage,
            nil
          )!,
        ] as [String: Any],
      ]

      var error: Unmanaged<CFError>?
      guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
        result(false)
        return
      }
      result(true)
    }
  }

  private static func signPayload(data: String, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let query: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
        kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
        kSecReturnRef as String: true,
      ]

      var item: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      guard status == errSecSuccess, let privateKey = item as? SecKey else {
        result(nil)
        return
      }

      let algorithm: SecKeyAlgorithm = .ecdsaSignatureMessageX962SHA256
      guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
        result(nil)
        return
      }

      var signError: Unmanaged<CFError>?
      guard let signature = SecKeyCreateSignature(
        privateKey,
        algorithm,
        data.data(using: .utf8)! as CFData,
        &signError
      ) as? Data else {
        result(nil)
        return
      }

      result(signature.base64EncodedString())
    }
  }

  private static func getPublicKey(result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let query: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
        kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
        kSecReturnRef as String: true,
      ]

      var item: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      guard status == errSecSuccess, let privateKey = item as? SecKey else {
        result(nil)
        return
      }

      guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
        result(nil)
        return
      }

      var error: Unmanaged<CFError>?
      guard let data = SecKeyCopyExternalRepresentation(publicKey, &error) as? Data else {
        result(nil)
        return
      }

      result(data.base64EncodedString())
    }
  }

  private static func isKeyPairGenerated(result: @escaping FlutterResult) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
      kSecReturnRef as String: false,
    ]
    let status = SecItemCopyMatching(query as CFDictionary, nil)
    result(status == errSecSuccess)
  }

  private static func deleteKeyPair(result: @escaping FlutterResult) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
    ]
    SecItemDelete(query as CFDictionary)
    result(true)
  }
}
