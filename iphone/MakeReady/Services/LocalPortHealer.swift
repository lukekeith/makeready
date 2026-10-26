//
//  LocalPortHealer.swift
//  MakeReady
//
//  Keeps the app pointed at the right local Express API port when the
//  environment is set to "Local". Dev server ports often move within a small
//  range; this validates the configured port and, if it isn't answering as a
//  MakeReady server, probes the window [base ... base+rangeSize] and the default
//  port's window, and adopts the lowest port whose /health reports
//  `service == "makeready"`.
//
//  Only meaningful for Local (dev) builds — it's a no-op otherwise.
//

import Foundation

enum LocalPortHealer {

    /// How many ports above the base to probe (base ... base + rangeSize).
    static let rangeSize = 10

    /// Per-probe timeout. Local network, so this can be short.
    private static let timeout: TimeInterval = 1.0

    enum Outcome: Equatable {
        case healthy(Int)   // configured port already responds as MakeReady
        case healed(Int)    // switched to a different working port
        case notFound(base: Int)  // nothing in the window answered as MakeReady
        case skipped        // not applicable (not Local, no host to probe, etc.)
    }

    /// Validate the configured API port and, if needed, heal it by probing the
    /// surrounding range. Safe to call repeatedly.
    @discardableResult
    static func heal() async -> Outcome {
        guard AppConfiguration.devMode, AppConfiguration.selectedEnvironment == .local else {
            return .skipped
        }
        guard let host = localHost() else { return .skipped }
        guard let base = Int(AppConfiguration.localAPIPort) else { return .skipped }

        // Fast path: configured port is already a MakeReady server.
        if await isMakeReady(host: host, port: base) {
            return .healthy(base)
        }

        // Probe the rest of the window, plus the default port's window, concurrently and adopt
        // the lowest match — a port saved from another server (the agent-walk server on 3110)
        // must not strand the app above the dev server on 3010.
        let candidates = candidatePorts(base: base, defaultPort: Int(AppConfiguration.defaultAPIPort))
        if let port = await firstMakeReadyPort(host: host, ports: candidates) {
            AppConfiguration.localAPIPort = String(port)
            print("🔌 LocalPortHealer: API port healed \(base) → \(port) on \(host)")
            return .healed(port)
        }

        print("🔌 LocalPortHealer: no MakeReady server found in \(base)…\(base + rangeSize) on \(host)")
        return .notFound(base: base)
    }

    /// The ports to probe once `base` fails: `base+1 … base+rangeSize`, and the default port's
    /// window `defaultPort … defaultPort+rangeSize`, ascending, without `base` itself.
    static func candidatePorts(base: Int, defaultPort: Int?) -> [Int] {
        var ports = Set((base + 1)...(base + rangeSize))
        if let defaultPort { ports.formUnion(defaultPort...(defaultPort + rangeSize)) }
        ports.remove(base)
        return ports.sorted()
    }

    // MARK: - Host resolution

    /// The host to probe — the user-entered IP on a physical device, loopback
    /// on the simulator. Returns nil when there's nothing to probe.
    private static func localHost() -> String? {
        #if targetEnvironment(simulator)
        return "127.0.0.1"
        #else
        if let ip = AppConfiguration.localServerIP, !ip.isEmpty { return ip }
        return nil
        #endif
    }

    // MARK: - Probing

    /// Probe all ports concurrently; return the lowest port that identifies as
    /// MakeReady (deterministic, prefers the bottom of the range).
    private static func firstMakeReadyPort(host: String, ports: [Int]) async -> Int? {
        await withTaskGroup(of: Int?.self) { group in
            for port in ports {
                group.addTask {
                    await isMakeReady(host: host, port: port) ? port : nil
                }
            }
            var best: Int?
            for await match in group {
                if let port = match, best == nil || port < best! {
                    best = port
                }
            }
            return best
        }
    }

    /// True only if `http://host:port/health` returns 200 with `service: "makeready"`.
    private static func isMakeReady(host: String, port: Int) async -> Bool {
        guard let url = URL(string: "http://\(host):\(port)/health") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
            return (json["service"] as? String) == "makeready"
        } catch {
            return false
        }
    }
}
