import Foundation

/// Connects to the MaclaqueDaemon Unix socket and receives JSON events.
final class SocketClient {
    let socketPath: String
    var onEvent: ((DaemonEvent) -> Void)?
    var onConnected: ((Bool) -> Void)?

    private var socketFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.maclaque.socketclient", qos: .userInteractive)
    private var buffer = Data()
    private var reconnectTimer: DispatchSourceTimer?

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    func connect() {
        queue.async { [weak self] in
            self?.doConnect()
        }
    }

    private func doConnect() {
        // Clean up previous connection
        disconnect()

        socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            scheduleReconnect()
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathLen = MemoryLayout.size(ofValue: addr.sun_path)
        socketPath.withCString { ptr in
            withUnsafeMutableBytes(of: &addr.sun_path) { pathBuf in
                let dest = pathBuf.baseAddress!.assumingMemoryBound(to: CChar.self)
                strncpy(dest, ptr, pathLen - 1)
            }
        }

        let result = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.connect(socketFD, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard result == 0 else {
            debugLog("[SocketClient] connect failed: errno=\(errno) (\(String(cString: strerror(errno))))")
            close(socketFD)
            socketFD = -1
            scheduleReconnect()
            return
        }

        debugLog("[SocketClient] Connected to daemon!")
        onConnected?(true)
        buffer = Data()

        // Read events asynchronously
        readSource = DispatchSource.makeReadSource(fileDescriptor: socketFD, queue: queue)
        readSource?.setEventHandler { [weak self] in
            self?.readData()
        }
        readSource?.setCancelHandler { [weak self] in
            if let fd = self?.socketFD, fd >= 0 {
                close(fd)
                self?.socketFD = -1
            }
            self?.onConnected?(false)
            self?.scheduleReconnect()
        }
        readSource?.resume()
    }

    private func readData() {
        var buf = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(socketFD, &buf, buf.count)

        if bytesRead <= 0 {
            readSource?.cancel()
            return
        }

        buffer.append(contentsOf: buf[0..<bytesRead])

        // Parse newline-delimited JSON
        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = buffer[buffer.startIndex..<newlineIndex]
            buffer = Data(buffer[buffer.index(after: newlineIndex)...])

            if let event = try? JSONDecoder().decode(DaemonEvent.self, from: Data(lineData)) {
                onEvent?(event)
            }
        }
    }

    private func scheduleReconnect() {
        reconnectTimer?.cancel()
        reconnectTimer = DispatchSource.makeTimerSource(queue: queue)
        reconnectTimer?.schedule(deadline: .now() + 2.0)
        reconnectTimer?.setEventHandler { [weak self] in
            self?.doConnect()
        }
        reconnectTimer?.resume()
    }

    /// Send a config update to the daemon
    func sendConfig(sensitivity: Float, cooldown: Double) {
        queue.async { [weak self] in
            guard let self = self, self.socketFD >= 0 else { return }
            let json = "{\"type\":\"config\",\"sensitivity\":\(sensitivity),\"cooldown\":\(cooldown)}\n"
            let data = Array(json.utf8)
            data.withUnsafeBufferPointer { buf in
                _ = Darwin.write(self.socketFD, buf.baseAddress!, buf.count)
            }
            debugLog("[SocketClient] Sent config: sensitivity=\(sensitivity) cooldown=\(cooldown)")
        }
    }

    func disconnect() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
        readSource?.cancel()
        readSource = nil
    }

    deinit {
        disconnect()
    }
}
