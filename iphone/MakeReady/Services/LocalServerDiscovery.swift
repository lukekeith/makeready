//
//  LocalServerDiscovery.swift
//  MakeReady
//
//  Discovers local development servers on the network using Bonjour/mDNS.
//  This allows physical iOS devices to connect to dev servers running on a Mac.
//
//  Two services are discovered:
//    _makeready._tcp        → API server (Express, default port 3010)
//    _makeready-client._tcp → Client server (Laravel, default port 8000)
//

import Foundation
import Network
import Combine

/// Discovers MakeReady development servers on the local network using Bonjour/mDNS
class LocalServerDiscovery: ObservableObject {

    // MARK: - Singleton

    static let shared = LocalServerDiscovery()

    // MARK: - Persistence Keys

    private static let cachedAPIURLKey = "bonjour.cachedAPIURL"
    private static let cachedClientURLKey = "bonjour.cachedClientURL"

    // MARK: - Published Properties

    /// The discovered API server URL (e.g., "http://192.168.1.100:3010")
    /// Falls back to the last cached value from a previous discovery.
    @Published private(set) var serverURL: String? {
        didSet {
            if let url = serverURL {
                UserDefaults.standard.set(url, forKey: Self.cachedAPIURLKey)
            }
        }
    }

    /// The discovered client server URL (e.g., "http://192.168.1.100:8000")
    /// Falls back to the last cached value from a previous discovery.
    @Published private(set) var clientURL: String? {
        didSet {
            if let url = clientURL {
                UserDefaults.standard.set(url, forKey: Self.cachedClientURLKey)
            }
        }
    }

    /// Cached API URL from a previous Bonjour discovery session.
    /// Available immediately on launch, unlike live discovery.
    var cachedServerURL: String? {
        UserDefaults.standard.string(forKey: Self.cachedAPIURLKey)
    }

    /// Cached client URL from a previous Bonjour discovery session.
    /// Available immediately on launch, unlike live discovery.
    var cachedClientURL: String? {
        UserDefaults.standard.string(forKey: Self.cachedClientURLKey)
    }

    /// Whether we are currently searching for servers
    @Published private(set) var isSearching: Bool = false

    /// Error message if discovery fails
    @Published private(set) var errorMessage: String?

    // MARK: - Private Properties

    private var apiBrowser: NWBrowser?
    private var clientBrowser: NWBrowser?
    private let queue = DispatchQueue(label: "com.makeready.localserverdiscovery")
    private let apiServiceType = "_makeready._tcp"
    private let clientServiceType = "_makeready-client._tcp"

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
        guard apiBrowser == nil && clientBrowser == nil else { return }

        isSearching = true
        errorMessage = nil

        apiBrowser = createBrowser(for: apiServiceType) { [weak self] url in
            self?.serverURL = url
            self?.checkSearchComplete()
            print("📡 LocalServerDiscovery: Discovered API server at \(url)")
        }

        clientBrowser = createBrowser(for: clientServiceType) { [weak self] url in
            self?.clientURL = url
            self?.checkSearchComplete()
            print("📡 LocalServerDiscovery: Discovered client server at \(url)")
        }
    }

    /// Stop browsing for local servers
    func stopBrowsing() {
        apiBrowser?.cancel()
        apiBrowser = nil
        clientBrowser?.cancel()
        clientBrowser = nil
        isSearching = false
        print("📡 LocalServerDiscovery: Stopped browsing")
    }

    /// Manually refresh the search
    func refresh() {
        stopBrowsing()
        serverURL = nil
        clientURL = nil
        startBrowsing()
    }

    // MARK: - Private Methods

    private func checkSearchComplete() {
        if serverURL != nil && clientURL != nil {
            isSearching = false
        }
    }

    private func createBrowser(for serviceType: String, onDiscovered: @escaping (String) -> Void) -> NWBrowser {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browserDescriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: "local.")
        let browser = NWBrowser(for: browserDescriptor, using: parameters)

        browser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleStateUpdate(state, serviceType: serviceType)
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            DispatchQueue.main.async {
                self?.handleResultsChanged(results: results, serviceType: serviceType, onDiscovered: onDiscovered)
            }
        }

        browser.start(queue: queue)
        print("📡 LocalServerDiscovery: Started browsing for \(serviceType)")
        return browser
    }

    private func handleStateUpdate(_ state: NWBrowser.State, serviceType: String) {
        switch state {
        case .ready:
            print("📡 LocalServerDiscovery: Browser ready (\(serviceType))")

        case .failed(let error):
            print("📡 LocalServerDiscovery: Browser failed (\(serviceType)) - \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isSearching = false

        case .cancelled:
            print("📡 LocalServerDiscovery: Browser cancelled (\(serviceType))")

        case .waiting(let error):
            print("📡 LocalServerDiscovery: Browser waiting (\(serviceType)) - \(error.localizedDescription)")

        case .setup:
            print("📡 LocalServerDiscovery: Browser setting up (\(serviceType))")

        @unknown default:
            break
        }
    }

    private func handleResultsChanged(results: Set<NWBrowser.Result>, serviceType: String, onDiscovered: @escaping (String) -> Void) {
        for result in results {
            switch result.endpoint {
            case .service(let name, let type, let domain, _):
                print("📡 LocalServerDiscovery: Found service - \(name) (\(type).\(domain))")
                resolveService(result: result, onDiscovered: onDiscovered)

            default:
                break
            }
        }

        if results.isEmpty {
            print("📡 LocalServerDiscovery: No services found for \(serviceType)")
        }
    }

    private func resolveService(result: NWBrowser.Result, onDiscovered: @escaping (String) -> Void) {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        // Create a connection to resolve the service's address
        let connection = NWConnection(to: result.endpoint, using: parameters)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                // Get the resolved endpoint
                if let endpoint = connection.currentPath?.remoteEndpoint {
                    self?.extractAddress(from: endpoint, onDiscovered: onDiscovered)
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

    private func extractAddress(from endpoint: NWEndpoint, onDiscovered: @escaping (String) -> Void) {
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
                    onDiscovered(url)
                }
            }

        default:
            break
        }
    }
}
