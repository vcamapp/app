import Foundation

/// The bundled openrpc.json: the single source of the public API contract.
/// `rpc.discover` serves it as-is, and the generated code is produced from it.
package enum APISpecification {
    package static let data: Data = {
        guard let url = Bundle.module.url(forResource: "openrpc", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            fatalError("openrpc.json is missing from the bundle")
        }
        return data
    }()

    package static let apiVersion: String = {
        struct Document: Decodable {
            struct Info: Decodable {
                let version: String
            }
            let info: Info
        }
        guard let document = try? JSONDecoder().decode(Document.self, from: data) else {
            fatalError("openrpc.json in the bundle is corrupted")
        }
        return document.info.version
    }()
}
