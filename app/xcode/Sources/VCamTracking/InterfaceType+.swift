import Network

public extension NWInterface.InterfaceType {
    var ipv4: String? {
        names.lazy.compactMap(address(name:)).first
    }

    private var names: [String] {
        switch self {
        case .wifi:
            return ["en0", "en1"]
        case .wiredEthernet:
            return ["en2", "en3", "en4"]
        case .cellular:
            return ["pdp_ip0", "pdp_ip1", "pdp_ip2", "pdp_ip3"]
        default:
            return []
        }
    }

    private func address(name: String) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer {
            freeifaddrs(ifaddr)
        }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            guard let address = interface.ifa_addr else { continue }

            guard address.pointee.sa_family == UInt8(AF_INET),
                  name == String(cString: interface.ifa_name) else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(
                address,
                socklen_t(address.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                socklen_t(0),
                NI_NUMERICHOST
            ) == 0 else { continue }
            return String(utf8String: hostname)
        }

        return nil
    }
}
