import Foundation
import Network

/// Minimal loopback-only HTTP listener that receives Claude Code hook events.
///
/// Only requests carrying the `X-Notchhaven-Client` header are accepted, which
/// makes drive-by POSTs from web pages fail their CORS preflight.
final class ClaudeEventServer: @unchecked Sendable {
    static let port: UInt16 = 26540
    static let clientHeader = "x-notchhaven-client"
    private static let maxRequestBytes = 64 * 1024

    private let queue = DispatchQueue(label: "notchhaven.claude.server")
    private var listener: NWListener?
    private let onEvent: @Sendable (Data) -> Void

    init(onEvent: @escaping @Sendable (Data) -> Void) {
        self.onEvent = onEvent
    }

    func start() {
        guard listener == nil else { return }

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(
            host: .ipv4(.loopback),
            port: NWEndpoint.Port(rawValue: Self.port)!
        )

        guard let listener = try? NWListener(using: parameters) else { return }
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return connection.cancel() }

            var buffer = buffer
            if let data { buffer.append(data) }

            if buffer.count > Self.maxRequestBytes || error != nil {
                return self.respond(on: connection, status: "413 Payload Too Large")
            }

            switch Self.parse(buffer) {
            case .needMore:
                if isComplete { connection.cancel() } else { self.receive(on: connection, buffer: buffer) }
            case .rejected:
                self.respond(on: connection, status: "403 Forbidden")
            case .request(let body):
                self.onEvent(body)
                self.respond(on: connection, status: "204 No Content")
            }
        }
    }

    private func respond(on connection: NWConnection, status: String) {
        let response = "HTTP/1.1 \(status)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    enum ParseResult {
        case needMore
        case rejected
        case request(body: Data)
    }

    static func parse(_ buffer: Data) -> ParseResult {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerEnd = buffer.range(of: separator) else { return .needMore }

        let headerText = String(decoding: buffer[..<headerEnd.lowerBound], as: UTF8.self)
        var lines = headerText.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst()

        guard requestLine.hasPrefix("POST /event ") else { return .rejected }

        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].lowercased()
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }

        guard headers[clientHeader] != nil,
              let length = headers["content-length"].flatMap(Int.init),
              length >= 0, length <= maxRequestBytes else { return .rejected }

        let body = buffer[headerEnd.upperBound...]
        guard body.count >= length else { return .needMore }
        return .request(body: Data(body.prefix(length)))
    }
}
