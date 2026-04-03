import Foundation

/// Unix domain socket server that sends JSON events to the Maclaque app.
/// Protocol: newline-delimited JSON messages.
final class SocketServer {
    static let socketPath = "/var/run/maclaque.sock"

    private var serverFD: Int32 = -1
    private var clientFDs: [Int32] = []
    private var clientReadSources: [Int32: DispatchSourceRead] = [:]
    private var clientBuffers: [Int32: Data] = [:]
    private let queue = DispatchQueue(label: "com.maclaque.socket", qos: .userInteractive)
    private let clientLock = NSLock()
    private var acceptSource: DispatchSourceRead?

    /// Called when a client sends a config update
    var onConfig: ((_ sensitivity: Float, _ cooldown: Double) -> Void)?

    func start() throws {
        // Remove stale socket file
        unlink(SocketServer.socketPath)

        // Create Unix domain socket
        serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            throw SocketError.createFailed(errno)
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathLen = MemoryLayout.size(ofValue: addr.sun_path)
        SocketServer.socketPath.withCString { ptr in
            withUnsafeMutableBytes(of: &addr.sun_path) { pathBuf in
                let dest = pathBuf.baseAddress!.assumingMemoryBound(to: CChar.self)
                strncpy(dest, ptr, pathLen - 1)
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverFD, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            throw SocketError.bindFailed(errno)
        }

        // Make socket accessible to non-root app
        chmod(SocketServer.socketPath, 0o666)

        guard listen(serverFD, 5) == 0 else {
            throw SocketError.listenFailed(errno)
        }

        // Accept connections asynchronously
        acceptSource = DispatchSource.makeReadSource(fileDescriptor: serverFD, queue: queue)
        acceptSource?.setEventHandler { [weak self] in
            self?.acceptClient()
        }
        acceptSource?.resume()

        print("[SocketServer] Listening on \(SocketServer.socketPath)")
    }

    private func acceptClient() {
        var clientAddr = sockaddr_un()
        var addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

        let clientFD = withUnsafeMutablePointer(to: &clientAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                accept(serverFD, sockaddrPtr, &addrLen)
            }
        }

        guard clientFD >= 0 else { return }

        clientLock.lock()
        clientFDs.append(clientFD)
        clientBuffers[clientFD] = Data()
        clientLock.unlock()

        // Listen for incoming messages from this client (config updates)
        let readSource = DispatchSource.makeReadSource(fileDescriptor: clientFD, queue: queue)
        readSource.setEventHandler { [weak self] in
            self?.readFromClient(clientFD)
        }
        readSource.setCancelHandler { [weak self] in
            self?.removeClient(clientFD)
        }
        readSource.resume()

        clientLock.lock()
        clientReadSources[clientFD] = readSource
        clientLock.unlock()

        print("[SocketServer] Client connected (fd=\(clientFD))")
    }

    private func readFromClient(_ fd: Int32) {
        var buf = [UInt8](repeating: 0, count: 4096)
        let bytesRead = Darwin.read(fd, &buf, buf.count)

        guard bytesRead > 0 else {
            clientLock.lock()
            clientReadSources[fd]?.cancel()
            clientLock.unlock()
            return
        }

        clientLock.lock()
        clientBuffers[fd, default: Data()].append(contentsOf: buf[0..<bytesRead])
        var buffer = clientBuffers[fd]!
        clientLock.unlock()

        // Parse newline-delimited JSON
        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = Data(buffer[buffer.startIndex..<newlineIndex])
            buffer = Data(buffer[buffer.index(after: newlineIndex)...])

            if let msg = try? JSONDecoder().decode(ConfigMessage.self, from: lineData),
               msg.type == "config" {
                print("[SocketServer] Config received: sensitivity=\(msg.sensitivity ?? -1) cooldown=\(msg.cooldown ?? -1)")
                if let s = msg.sensitivity, let c = msg.cooldown {
                    onConfig?(s, c)
                }
            }
        }

        clientLock.lock()
        clientBuffers[fd] = buffer
        clientLock.unlock()
    }

    private func removeClient(_ fd: Int32) {
        clientLock.lock()
        clientFDs.removeAll { $0 == fd }
        clientReadSources.removeValue(forKey: fd)
        clientBuffers.removeValue(forKey: fd)
        clientLock.unlock()
        close(fd)
        print("[SocketServer] Client disconnected (fd=\(fd))")
    }

    /// Send a JSON event to all connected clients
    func send(event: DaemonEvent) {
        guard let data = try? JSONEncoder().encode(event),
              let json = String(data: data, encoding: .utf8) else { return }

        let message = json + "\n"
        let messageData = Array(message.utf8)

        clientLock.lock()
        let activeFDs = clientFDs
        clientLock.unlock()

        var deadFDs: [Int32] = []

        for fd in activeFDs {
            let written = messageData.withUnsafeBufferPointer { buf in
                Darwin.write(fd, buf.baseAddress!, buf.count)
            }
            if written <= 0 {
                deadFDs.append(fd)
                close(fd)
            }
        }

        if !deadFDs.isEmpty {
            clientLock.lock()
            clientFDs.removeAll { deadFDs.contains($0) }
            clientLock.unlock()
        }
    }

    func stop() {
        acceptSource?.cancel()
        acceptSource = nil

        clientLock.lock()
        for (_, source) in clientReadSources { source.cancel() }
        clientReadSources.removeAll()
        clientBuffers.removeAll()
        for fd in clientFDs { close(fd) }
        clientFDs.removeAll()
        clientLock.unlock()

        if serverFD >= 0 {
            close(serverFD)
            serverFD = -1
        }
        unlink(SocketServer.socketPath)
    }

    deinit { stop() }
}

// ── Event types ────────────────────────────────────────────────────────
struct DaemonEvent: Codable {
    let type: String      // "slap", "usb", "lid"
    let intensity: Float? // 0.0-1.0 for slap events
    let action: String?   // "plug"/"unplug" for USB, "opened"/"closed" for lid
}

/// Config message received from the app (app → daemon)
struct ConfigMessage: Codable {
    let type: String
    let sensitivity: Float?
    let cooldown: Double?
}

// ── Errors ─────────────────────────────────────────────────────────────
enum SocketError: Error, LocalizedError {
    case createFailed(Int32)
    case bindFailed(Int32)
    case listenFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .createFailed(let e):  return "Socket create failed: \(String(cString: strerror(e)))"
        case .bindFailed(let e):    return "Socket bind failed: \(String(cString: strerror(e)))"
        case .listenFailed(let e):  return "Socket listen failed: \(String(cString: strerror(e)))"
        }
    }
}
