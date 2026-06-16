import Foundation
import Security

protocol RegistryCredentialResolving: Sendable {
    func credentials(for server: String, scheme: String) async throws -> RegistryBrowseCredentials?
}

struct RegistryKeychainCredentialDescriptor: Hashable, Sendable {
    var securityDomain: String?
    var server: String
    var itemClass: String

    func keychainQuery(returnData: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: itemClass,
            kSecAttrServer as String: server,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: returnData,
        ]
        if let securityDomain {
            query[kSecAttrSecurityDomain as String] = securityDomain
        }
        return query
    }
}

enum RegistryCredentialResolverError: LocalizedError, Sendable {
    case unexpectedKeychainData
    case keychainQueryFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedKeychainData:
            return "无法读取 container 登录凭据：钥匙串返回的数据格式不正确。"
        case .keychainQueryFailed(let status):
            return "无法读取 container 登录凭据，请确认已登录并允许钥匙串访问。错误码：\(status)。"
        }
    }
}

struct RegistryKeychainCredentialResolver: RegistryCredentialResolving {
    static let preferredSecurityDomain = "com.apple.container.registry"
    static let compatibilitySecurityDomain = "com.apple.containerization"

    func credentials(for server: String, scheme: String = "https") async throws -> RegistryBrowseCredentials? {
        try Self.lookupCredentials(descriptors: Self.lookupDescriptors(server: server, scheme: scheme))
    }

    static func lookupDescriptor(server: String, scheme: String = "https") throws -> RegistryKeychainCredentialDescriptor {
        try lookupDescriptors(server: server, scheme: scheme)[0]
    }

    static func lookupDescriptors(server: String, scheme: String = "https") throws -> [RegistryKeychainCredentialDescriptor] {
        let endpoint = try RegistryServerEndpoint.resolve(server: server, fallbackScheme: scheme)
        return [
            RegistryKeychainCredentialDescriptor(
                securityDomain: preferredSecurityDomain,
                server: endpoint.server,
                itemClass: kSecClassInternetPassword as String
            ),
            RegistryKeychainCredentialDescriptor(
                securityDomain: nil,
                server: endpoint.server,
                itemClass: kSecClassInternetPassword as String
            ),
            RegistryKeychainCredentialDescriptor(
                securityDomain: compatibilitySecurityDomain,
                server: endpoint.server,
                itemClass: kSecClassInternetPassword as String
            ),
        ]
    }

    private static func lookupCredentials(descriptors: [RegistryKeychainCredentialDescriptor]) throws -> RegistryBrowseCredentials? {
        var firstUnexpectedDataError: RegistryCredentialResolverError?
        for descriptor in descriptors {
            do {
                if let credentials = try lookupCredentials(descriptor: descriptor) {
                    return credentials
                }
            } catch RegistryCredentialResolverError.unexpectedKeychainData {
                firstUnexpectedDataError = firstUnexpectedDataError ?? .unexpectedKeychainData
                continue
            }
        }
        if let firstUnexpectedDataError {
            throw firstUnexpectedDataError
        }
        return nil
    }

    private static func lookupCredentials(descriptor: RegistryKeychainCredentialDescriptor) throws -> RegistryBrowseCredentials? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(descriptor.keychainQuery(returnData: true) as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw RegistryCredentialResolverError.keychainQueryFailed(status)
        }
        guard let fetched = item as? [String: Any],
              let username = fetched[kSecAttrAccount as String] as? String,
              let data = fetched[kSecValueData as String] as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw RegistryCredentialResolverError.unexpectedKeychainData
        }

        return RegistryBrowseCredentials(username: username, password: password)
    }
}
