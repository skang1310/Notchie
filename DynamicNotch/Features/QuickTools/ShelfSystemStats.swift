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

@MainActor
final class ShelfSystemStats: ObservableObject {
    @Published private(set) var cpu: Double?
    @Published private(set) var memory: Double?
    @Published private(set) var history: [Double] = []
    @Published private(set) var sampledAt: Date?
    private var previous: ShelfCPUSample?
    func sample() {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let ticks = info.cpu_ticks
            let current = ShelfCPUSample(user: UInt64(ticks.0), system: UInt64(ticks.1), idle: UInt64(ticks.2), nice: UInt64(ticks.3))
            cpu = previous.flatMap { current.utilization(since: $0) }; previous = current
            if let cpu { history.append(cpu); history = Array(history.suffix(40)) }
        } else { cpu = nil }
        var vm = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let vmResult = withUnsafeMutablePointer(to: &vm) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &vmCount)
            }
        }
        if vmResult == KERN_SUCCESS {
            let usedPages = UInt64(vm.active_count) + UInt64(vm.wire_count) + UInt64(vm.compressor_page_count)
            memory = min(1, Double(usedPages) * Double(vm_kernel_page_size) / Double(ProcessInfo.processInfo.physicalMemory))
        } else { memory = nil }
        sampledAt = .now
    }
}
