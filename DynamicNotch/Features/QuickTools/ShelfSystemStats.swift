import Foundation
import Combine
import Darwin

struct ShelfCPUSample: Equatable {
    let user: UInt64, system: UInt64, idle: UInt64, nice: UInt64
    var total: UInt64 { user + system + idle + nice }
    func utilization(since previous: Self) -> Double? {
        guard total > previous.total, idle >= previous.idle else { return nil }
        let delta = total - previous.total
        return min(1, max(0, 1 - Double(idle - previous.idle) / Double(delta)))
    }
}

struct ShelfNetworkCounter: Equatable {
    let received: UInt64
    let sent: UInt64
    static func rates(current: [String: Self], previous: [String: Self], seconds: Double) -> (Double, Double)? {
        guard seconds > 0, seconds.isFinite else { return nil }
        var received: UInt64 = 0, sent: UInt64 = 0, matched = false
        for (id, value) in current {
            guard let old = previous[id], value.received >= old.received, value.sent >= old.sent else { continue }
            received += value.received - old.received; sent += value.sent - old.sent; matched = true
        }
        return matched ? (Double(received) / seconds, Double(sent) / seconds) : nil
    }
}

@MainActor
final class ShelfSystemStats: ObservableObject {
    static let shared = ShelfSystemStats()
    @Published private(set) var cpu: Double?
    @Published private(set) var memory: Double?
    @Published private(set) var usedMemoryBytes: UInt64?
    @Published private(set) var swapBytes: UInt64?
    @Published private(set) var pressure: Int?
    @Published private(set) var download: Double?
    @Published private(set) var upload: Double?
    @Published private(set) var freeDiskBytes: Int64?
    @Published private(set) var history: [Double] = []
    @Published private(set) var networkHistory: [Double] = []
    @Published private(set) var sampledAt: Date?
    let totalMemoryBytes = ProcessInfo.processInfo.physicalMemory
    private var previous: ShelfCPUSample?
    private var previousNetwork: [String: ShelfNetworkCounter]?
    private var previousTime: TimeInterval?
    private var lastDiskSample: TimeInterval?
    private var consumers = Set<UUID>()
    private var sampler: Task<Void, Never>?
    var consumerCount: Int { consumers.count }
    func acquire(_ id: UUID) {
        consumers.insert(id)
        guard sampler == nil else { return }
        previous = nil; previousNetwork = nil; previousTime = nil
        sampler = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.sample()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }
    func release(_ id: UUID) {
        consumers.remove(id)
        if consumers.isEmpty { sampler?.cancel(); sampler = nil; previous = nil; previousNetwork = nil; previousTime = nil }
    }
    func sample() {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count) }
        }
        if result == KERN_SUCCESS {
            let ticks = info.cpu_ticks
            let current = ShelfCPUSample(user: UInt64(ticks.0), system: UInt64(ticks.1), idle: UInt64(ticks.2), nice: UInt64(ticks.3))
            cpu = previous.flatMap { current.utilization(since: $0) }; previous = current
            if let cpu { history.append(cpu); history = Array(history.suffix(40)) }
        } else { cpu = nil; previous = nil }
        var vm = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let vmResult = withUnsafeMutablePointer(to: &vm) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) { host_statistics64(host, HOST_VM_INFO64, $0, &vmCount) }
        }
        if vmResult == KERN_SUCCESS {
            let used = (UInt64(vm.active_count) + UInt64(vm.wire_count) + UInt64(vm.compressor_page_count)) * UInt64(vm_kernel_page_size)
            usedMemoryBytes = min(totalMemoryBytes, used)
            memory = totalMemoryBytes > 0 ? min(1, Double(used) / Double(totalMemoryBytes)) : nil
        } else { memory = nil; usedMemoryBytes = nil }
        var swap = xsw_usage(); var swapSize = MemoryLayout<xsw_usage>.size
        swapBytes = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 ? swap.xsu_used : nil
        var level: Int32 = 0; var levelSize = MemoryLayout<Int32>.size
        pressure = sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &levelSize, nil, 0) == 0 ? Int(level) : nil
        let now = ProcessInfo.processInfo.systemUptime
        let counters = networkCounters()
        let rates = counters.flatMap { values in previousNetwork.flatMap { old in previousTime.flatMap { ShelfNetworkCounter.rates(current: values, previous: old, seconds: now - $0) } } }
        download = rates?.0; upload = rates?.1
        previousNetwork = counters; previousTime = now
        if let download { networkHistory.append(download); networkHistory = Array(networkHistory.suffix(40)) }
        // Disk capacity changes slowly; avoid querying the volume on every tick.
        if lastDiskSample == nil || now - (lastDiskSample ?? 0) >= 30 {
            lastDiskSample = now
            freeDiskBytes = (try? FileManager.default.homeDirectoryForCurrentUser.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage
        }
        sampledAt = .now
    }
    private func networkCounters() -> [String: ShelfNetworkCounter]? {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0 else { return nil }
        defer { freeifaddrs(addresses) }
        var values: [String: ShelfNetworkCounter] = [:]
        var cursor = addresses
        while let item = cursor {
            let interface = item.pointee
            defer { cursor = interface.ifa_next }
            let name = String(cString: interface.ifa_name)
            guard name.hasPrefix("en"), interface.ifa_flags & UInt32(IFF_UP) != 0,
                  interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK), let data = interface.ifa_data else { continue }
            let stats = data.assumingMemoryBound(to: if_data.self).pointee
            values[name] = ShelfNetworkCounter(received: UInt64(stats.ifi_ibytes), sent: UInt64(stats.ifi_obytes))
        }
        return values
    }
    static func bytes(_ value: UInt64?) -> String {
        value.map { ByteCountFormatter.string(fromByteCount: Int64(clamping: $0), countStyle: .memory) } ?? "—"
    }
    static func rate(_ value: Double?) -> String {
        guard let value, value.isFinite, value >= 0 else { return "—" }
        if value >= 1_000_000 { return String(format: "%.1f MB/s", value / 1_000_000) }
        return String(format: "%.0f KB/s", value / 1000)
    }
}
