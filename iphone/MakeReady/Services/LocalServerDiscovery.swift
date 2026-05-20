//
//  LocalServerDiscovery.swift
//  MakeReady
//
//  Discovers the local development server on the network using Bonjour/mDNS.
//  This allows physical iOS devices to connect to the dev server running on a Mac.
//

import Foundation
import Network
import Combine

/// Discovers MakeReady development servers on the local network using Bonjour/mDNS
class LocalServerDiscovery: ObservableObject {

    // MARK: - Singleton

    static let shared = LocalServerDiscovery()

    // MARK: - Published Properties

    /// The discovered server URL (e.g., "http://192.168.1.100:3010")
    /// Port is taken from the Bonjour-advertised service, not hardcoded.
    @Published private(set) var serverURL: String?

    /// Whether we are currently searching for a server
    @Published private(set) var isSearching: Bool = false

    /// Error message if discovery fails
    @Published private(set) var errorMessage: String?

    // MARK: - Private Properties

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.makeready.localserverdiscovery")
    private let serviceType = "_makeready._tcp"

    // MARK: - Initialization

    private init() {
        // Only start discovery for Xcode builds on physical devices
        #if !targetEnvironment(simulator)
        // Check if this is an Xcode build (has embedded.mobileprovision)
        let isXcodeBuild = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
        // Also not TestFlight (sandbox receipt)
        let sandboxReceiptURL = Bundle.main.bundleURL.appendingPathComponent("_MASReceipt/sandboxReceipt")
        let isTestFlight = FileManager.default.fileExists(atPath: sandboxReceiptURL.path)

        if isXcodeBuild && !isTestFlight {
            startBrowsing()
        }
        #endif
    }

    deinit {
        stopBrowsing()
    }

    // MARK: - Public Methods

    /// Start browsing for local servers
    func startBrowsing() {
        guard browser == nil else { return }

        isSearching = true
        errorMessage = nil

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browserDescriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: "local.")
        browser = NWBrowser(for: browserDescriptor, using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleStateUpdate(state)
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            DispatchQueue.main.async {
                self?.handleResultsChanged(results: results)
            }
        }

        browser?.start(queue: queue)
        print("📡 LocalServerDiscovery: Started browsing for \(serviceType)")
    }

    /// Stop browsing for local servers
    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        isSearching = false
        print("📡 LocalServerDiscovery: Stopped browsing")
    }

    /// Manually refresh the search
    func refresh() {
        stopBrowsing()
        serverURL = nil
        startBrowsing()
    }

    // MARK: - Private Methods

    private func handleStateUpdate(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            print("📡 LocalServerDiscovery: Browser ready")

        case .failed(let error):
            print("📡 LocalServerDiscovery: Browser failed - \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isSearching = false

        case .cancelled:
            print("📡 LocalServerDiscovery: Browser cancelled")
            isSearching = false

        case .waiting(let error):
            print("📡 LocalServerDiscovery: Browser waiting - \(error.localizedDescription)")

        case .setup:
            print("📡 LocalServerDiscovery: Browser setting up")

        @unknown default:
            break
        }
    }

    private func handleResultsChanged(results: Set<NWBrowser.Result>) {
        for result in results {
            switch result.endpoint {
            case .service(let name, let type, let domain, _):
                print("📡 LocalServerDiscovery: Found service - \(name) (\(type).\(domain))")
                resolveService(result: result)

            default:
                break
            }
        }

        if results.isEmpty {
            print("📡 LocalServerDiscovery: No services found")
        }
    }

    private func resolveService(result: NWBrowser.Result) {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        // Create a connection to resolve the service's address
        let connection = NWConnection(to: result.endpoint, using: parameters)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                // Get the resolved endpoint
                if let endpoint = connection.currentPath?.remoteEndpoint {
                    self?.extractAddress(from: endpoint)
                }
                connection.cancel()

            case .failed(let error):
                print("📡 LocalServerDiscovery: Failed to resolve - \(error.localizedDescription)")
                connection.cancel()

            case .cancelled:
                break

            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    private func extractAddress(from endpoint: NWEndpoint) {
        switch endpoint {
        case .hostPort(let host, let resolvedPort):
            var ipAddress: String?

            switch host {
            case .ipv4(let address):
                // Convert IPv4 to string using the debugDescription
                // Format: "IPv4Address(x.x.x.x)" or just the IP
                let description = String(describing: address)
                // Extract IP from description if needed
                if let range = description.range(of: #"\d+\.\d+\.\d+\.\d+"#, options: .regularExpression) {
                    ipAddress = String(description[range])
                } else {
                    ipAddress = description
                }

            case .ipv6(let address):
                // Skip link-local IPv6 addresses, prefer IPv4
                let bytes = withUnsafeBytes(of: address.rawValue) { Array($0) }
                // Check if it's a link-local address (fe80::)
                if bytes[0] == 0xfe && bytes[1] == 0x80 {
                    print("📡 LocalServerDiscovery: Skipping link-local IPv6 address")
                    return
                }
                // Format IPv6 address
                var parts: [String] = []
                for i in stride(from: 0, to: 16, by: 2) {
                    let value = UInt16(bytes[i]) << 8 | UInt16(bytes[i + 1])
                    parts.append(String(value, radix: 16))
                }
                ipAddress = "[\(parts.joined(separator: ":"))]"

            case .name(let hostname, _):
                ipAddress = hostname

            @unknown default:
                break
            }

            if let ip = ipAddress {
                let url = "http://\(ip):\(resolvedPort.rawValue)"
                DispatchQueue.main.async {
                    self.serverURL = url
                    self.isSearching = false
                    print("📡 LocalServerDiscovery: Discovered server at \(url)")
                }
            }

        default:
            break
        }
    }
}
