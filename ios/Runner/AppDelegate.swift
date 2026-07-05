import Flutter
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let secureCacheChannelName = "com.example.lembretes_app/secure_cache"
  private let secureCacheService = "com.example.lembretes_app.secure_cache"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let secureCacheChannel = FlutterMethodChannel(
        name: secureCacheChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      secureCacheChannel.setMethodCallHandler { [weak self] call, result in
        self?.handleSecureCacheCall(call, result: result)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleSecureCacheCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let key = arguments["key"] as? String,
      !key.isEmpty
    else {
      result(FlutterError(code: "invalid_key", message: "Chave de cache invalida.", details: nil))
      return
    }

    switch call.method {
    case "read":
      result(readSecureCache(key: key))
    case "write":
      guard let value = arguments["value"] as? String else {
        result(FlutterError(code: "invalid_value", message: "Valor de cache invalido.", details: nil))
        return
      }
      let ok = writeSecureCache(key: key, value: value)
      if ok {
        result(nil)
      } else {
        result(FlutterError(code: "secure_cache_error", message: "Falha ao gravar no Keychain.", details: nil))
      }
    case "delete":
      deleteSecureCache(key: key)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func keychainQuery(key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: secureCacheService,
      kSecAttrAccount as String: key,
    ]
  }

  private func readSecureCache(key: String) -> String? {
    var query = keychainQuery(key: key)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  private func writeSecureCache(key: String, value: String) -> Bool {
    deleteSecureCache(key: key)
    guard let data = value.data(using: .utf8) else {
      return false
    }
    var query = keychainQuery(key: key)
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    query[kSecValueData as String] = data
    return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
  }

  private func deleteSecureCache(key: String) {
    SecItemDelete(keychainQuery(key: key) as CFDictionary)
  }
}
