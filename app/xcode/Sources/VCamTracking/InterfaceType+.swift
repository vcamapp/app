//
//  InterfaceType+.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/01/21.
//

import Network

public extension NWInterface.InterfaceType {
    var ipv4: String? { address(family: AF_INET) }
    var ipv6: String? { address(family: AF_INET6) }

    private var names: [String] {
        switch self {
        case .wifi:
            return ["en0"]
        case .wiredEthernet:
            return ["en2", "en3", "en4"]
        case .cellular:
            return ["pdp_ip0", "pdp_ip1", "pdp_ip2", "pdp_ip3"]
        default:
            return []
        }
    }

    func address(family: Int32) -> String? {
        names.lazy
            .compactMap {
                address(family: family, name: $0)
            }
            .first
    }

    func address(family: Int32, name: String) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer {
            freeifaddrs(ifaddr)
        }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            guard addrFamily == UInt8(family), name == String(cString: interface.ifa_name) else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                socklen_t(0),
                NI_NUMERICHOST
            )
            return String(cString: hostname)
        }

        return nil
    }
}
