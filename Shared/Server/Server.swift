// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import Foundation
import NIOSSL
import NIOTLS
import Vapor

struct AppData {
    public var id: String
    public var version: Int
    public var name: String
}

class Installer: Identifiable, ObservableObject {
    let id: UUID
    let app: Application
    var package: URL
    let port = Int.random(in: 4000 ... 8000)
    let metadata: AppData

    enum Status {
        case ready
        case sendingManifest
        case sendingPayload
        case completed(Result<Void, Error>)
        case broken(Error)
    }

    @Published var status: Status = .ready

    var needsShutdown = false

    init(path packagePath: URL?, metadata: AppData) throws {
        let id: UUID = .init()
        self.id = id
        self.metadata = metadata
        self.package = packagePath ?? URL(fileURLWithPath: "")
        app = try Self.setupApp(port: port)

        configureRoutes()
        
        try app.server.start()
        needsShutdown = true
        Debug.shared.log(message: "Server started: Port \(port) for \(Self.sni)")
    }
    
    // Configure app routes
    private func configureRoutes() {
        app.get("*") { [weak self] req in
            guard let self else { return Response(status: .badGateway) }
            return self.handleRequest(req)
        }

        app.get("i") { [weak self] _ -> Response in
            guard let self = self else { return Response(status: .badGateway) }
            return self.generateInstallResponse()
        }
    }
    
    // Handle request based on path
    private func handleRequest(_ req: Request) -> Response {
        switch req.url.path {
        case "/ping":
            return Response(status: .ok, body: .init(string: "pong"))
        case "/", "/index.html":
            return Response(
                status: .ok,
                version: req.version,
                headers: ["Content-Type": "text/html"],
                body: .init(string: indexHtml)
            )
        case plistEndpoint.path:
            DispatchQueue.main.async { [weak self] in
                self?.status = .sendingManifest
            }
            return Response(
                status: .ok,
                version: req.version,
                headers: ["Content-Type": "text/xml"],
                body: .init(data: installManifestData)
            )
        case displayImageSmallEndpoint.path:
            DispatchQueue.main.async { [weak self] in
                self?.status = .sendingManifest
            }
            return Response(
                status: .ok,
                version: req.version,
                headers: ["Content-Type": "image/png"],
                body: .init(data: displayImageSmallData)
            )
        case displayImageLargeEndpoint.path:
            DispatchQueue.main.async { [weak self] in
                self?.status = .sendingManifest
            }
            return Response(
                status: .ok,
                version: req.version,
                headers: ["Content-Type": "image/png"],
                body: .init(data: displayImageLargeData)
            )
        case payloadEndpoint.path:
            DispatchQueue.main.async { [weak self] in
                self?.status = .sendingPayload
            }
            return req.fileio.streamFile(at: self.package.path) { [weak self] result in
                DispatchQueue.main.async {
                    self?.status = .completed(result)
                }
            }
        default:
            return Response(status: .notFound)
        }
    }
    
    // Generate install response for the "i" endpoint
    private func generateInstallResponse() -> Response {
        let baseUrl = Preferences.onlinePath ?? Preferences.defaultInstallPath
        let urlParams = [
            "bundleid=\(metadata.id)",
            "name=\(metadata.name)",
            "version=\(metadata.version)",
            "fetchurl=\(payloadEndpoint.absoluteString)"
        ].joined(separator: "&")
        
        let encodedParams = urlParams.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let testUrl = "itms-services://?action=download-manifest&url=\(baseUrl)/genPlist?\(encodedParams)"
        
        let html = """
        <script type="text/javascript">window.location="\(testUrl)"</script>
        """

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/html")

        return Response(status: .ok, headers: headers, body: .init(string: html))
    }

    deinit {
        shutdownServer()
    }

    func shutdownServer() {
        Debug.shared.log(message: "Server is shutting down!")
        if needsShutdown {
            needsShutdown = false
            app.server.shutdown()
            app.shutdown()
        }
    }
}

extension Installer {
    private static let env: Environment = {
        var env: Environment
        do {
            env = try Environment.detect()
            try LoggingSystem.bootstrap(from: &env)
        } catch {
            Debug.shared.log(message: "Error setting up environment: \(error.localizedDescription)", type: .error)
            // Default to development environment as fallback
            env = .development
        }
        return env
    }()

    static func setupApp(port: Int) throws -> Application {
        let app = Application(env)

        app.threadPool = .init(numberOfThreads: 1)

        if !Preferences.userSelectedServer {
            do {
                app.http.server.configuration.tlsConfiguration = try Self.setupTLS()
            } catch {
                Debug.shared.log(message: "TLS setup failed: \(error)", type: .error)
                throw error
            }
        }
        
        app.http.server.configuration.hostname = Self.sni
        Debug.shared.log(message: self.sni)
        app.http.server.configuration.tcpNoDelay = true

        app.http.server.configuration.address = .hostname("0.0.0.0", port: port)
        app.http.server.configuration.port = port

        app.routes.defaultMaxBodySize = "128mb"
        app.routes.caseInsensitive = false

        return app
    }
}
