import Foundation
import SystemConfiguration

@objc public enum NetworkStatus: Int {
    case notReachable
    case reachable
    case reachableViaWWAN
}

@objc public class Reachability: NSObject {
    @objc public static let shared: Reachability = Reachability()
    
    @objc public var status: NetworkStatus = .notReachable
    @objc public var statusChangeBlock: ((NetworkStatus) -> ())?
    
    @objc public override init() {
        super.init()
        
        var address = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        address.sin_len = UInt8(MemoryLayout.size(ofValue: address))
        address.sin_family = sa_family_t(AF_INET)
        if let defaultRouteReachability = withUnsafePointer(to: &address, { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { SCNetworkReachabilityCreateWithAddress(nil, $0) }}) {
            let enabled = SCNetworkReachabilitySetCallback(defaultRouteReachability, { (_, flags, _) in
                let old = Reachability.shared.status
                if flags.contains(.reachable) && !(flags.contains(.connectionRequired)) {
                    Reachability.shared.status = flags.contains(.isWWAN) ? .reachableViaWWAN : .reachable
                } else {
                    Reachability.shared.status = .notReachable
                }
                if old != Reachability.shared.status {
                    Reachability.shared.statusChangeBlock?(Reachability.shared.status)
                }
            }, nil)
            if enabled {
                SCNetworkReachabilityScheduleWithRunLoop(defaultRouteReachability, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            }
            var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
            if SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) == false {
                status = .notReachable
            }
            if flags.contains(.reachable) && !(flags.contains(.connectionRequired)) {
                status = flags.contains(.isWWAN) ? .reachableViaWWAN : .reachable
            }
        }
    }
    
    @objc public func set(statusChangeBlock: @escaping (NetworkStatus) -> ()) {
        self.statusChangeBlock = statusChangeBlock
    }
}
