import Foundation
import Network

/// Minimal loopback HTTP/1.1 server that receives Claude Code HTTP hooks.
///
/// Claude Code POSTs each hook's JSON input and waits for the response body, which lets
/// `PermissionRequest` hooks be answered from the notch. Everything runs on the main queue:
/// traffic is a handful of tiny requests per turn.
final class ClaudeHookServer {
    struct Request {
        var method: String
        var path: String
        var headers: [String: String]
        var body: Data
    }

    struct Response {
        var status: Int = 200
        var body = Data()
        var contentType = "application/json"

        static let empty = Response()
        static func json(_ object: Any) -> Response {
            let data = (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
            return Response(body: data)
        }
    }

    enum State: Equatable {
        case stopped
        case listening(port: UInt16)
        case failed(String)
    }

    var onStateChange: ((State) -> Void)?
    private(set) var state: State = .stopped {
        didSet { onStateChange?(state) }
    }

    private let handler: (Request) async -> Response
    private var listener: NWListener?
    /// A relaunch can briefly overlap the old instance; retry the bind for a few seconds.
    private var bindRetries = 0
    private var retryTask: Task<Void, Never>?
    private var connections: [ObjectIdentifier: NWConnection] = [:]

    init(handler: @escaping (Request) async -> Response) {
        self.handler = handler
    }

    func start(port: UInt16) {
        stop()
        bindRetries = 0
        bind(port: port)
    }

    private func bind(port: UInt16) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            state = .failed("Invalid port \(port)")
            return
        }
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: nwPort)
            let listener = try NWListener(using: parameters)
            listener.stateUpdateHandler = { [weak self] newState in
                guard let self else { return }
                switch newState {
                case .ready:
                    self.state = .listening(port: port)
                case .failed(let error):
                    self.listener?.cancel()
                    self.listener = nil
                    if case .posix(.EADDRINUSE) = error, self.bindRetries < 12 {
                        self.bindRetries += 1
                        self.retryTask = Task { [weak self] in
                            try? await Task.sleep(for: .milliseconds(500))
                            guard !Task.isCancelled else { return }
                            self?.bind(port: port)
                        }
                        return
                    }
                    self.state = .failed(error.localizedDescription)
                case .cancelled:
                    if case .failed = self.state { return }
                    self.state = .stopped
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func stop() {
        retryTask?.cancel()
        retryTask = nil
        listener?.cancel()
        listener = nil
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        state = .stopped
    }

    // MARK: Connections

    private func accept(_ connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        connections[key] = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.connections[key] = nil
            default:
                break
            }
        }
        connection.start(queue: .main)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }

            if buffer.count > 8 * 1024 * 1024 {
                self.send(Response(status: 413), on: connection)
                return
            }
            if let request = Self.parse(buffer) {
                let task = Task { @MainActor in
                    let response = await self.handler(request)
                    guard !Task.isCancelled else { return }
                    self.send(response, on: connection)
                }
                // If Claude gives up (Esc, Ctrl-C, hook timeout) the socket closes: stop waiting.
                self.watchForHangUp(connection, task: task)
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receive(on: connection, buffer: buffer)
            }
        }
    }

    private func watchForHangUp(_ connection: NWConnection, task: Task<Void, Never>) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] data, _, isComplete, error in
            if isComplete || error != nil {
                task.cancel()
            } else if data != nil {
                // Unexpected extra bytes (pipelining); keep listening for the close.
                self?.watchForHangUp(connection, task: task)
            }
        }
    }

    private func send(_ response: Response, on connection: NWConnection) {
        let reason = switch response.status {
        case 200: "OK"
        case 400: "Bad Request"
        case 404: "Not Found"
        case 413: "Payload Too Large"
        case 415: "Unsupported Media Type"
        default: "Status"
        }
        var head = "HTTP/1.1 \(response.status) \(reason)\r\n"
        head += "Content-Type: \(response.contentType)\r\n"
        head += "Content-Length: \(response.body.count)\r\n"
        head += "Connection: close\r\n\r\n"
        var payload = Data(head.utf8)
        payload.append(response.body)
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    /// Returns a request once the headers and the full `Content-Length` body have arrived.
    static func parse(_ buffer: Data) -> Request? {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = buffer.range(of: separator) else { return nil }
        guard let headerText = String(data: buffer[buffer.startIndex..<headerRange.lowerBound], encoding: .utf8) else {
            return nil
        }
        var lines = headerText.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return nil }
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        let bodyStart = headerRange.upperBound
        let contentLength = max(0, Int(headers["content-length"] ?? "") ?? 0)
        guard buffer.count - bodyStart >= contentLength else { return nil }
        let body = buffer[bodyStart..<(bodyStart + contentLength)]

        return Request(
            method: String(requestLine[0]),
            path: String(requestLine[1]),
            headers: headers,
            body: Data(body)
        )
    }
}
