import Foundation

/**
 * A packet is a collection of state updates with a sequence id. We fake a "monotonically"
 * increasing clock using Int16s to save bits. Wrapping happens infrequently.
 */

struct Packet: Equatable, Comparable {
    static let maxInputsPerPacket = 32
    static let maxStateUpdatesPerPacket = 64

    let sequence: Int16
    let updatesCompact: [CompactNodeState]
    let updatesFull: [FullNodeState]

    init(sequence: Int16, updates: [NodeState]) {
        var updatesCompact = [CompactNodeState]()
        var updatesFull = [FullNodeState]()
        for update in updates {
            switch update {
            case let update as CompactNodeState:
                updatesCompact.append(update)
            case let update as FullNodeState:
                updatesFull.append(update)
            default: ()
            }
        }
        self.sequence = sequence
        self.updatesCompact = updatesCompact
        self.updatesFull = updatesFull
    }

    var updates: [NodeState] {
        return (updatesCompact as [NodeState]) + (updatesFull as [NodeState])
    }

    static func ==(lhs: Packet, rhs: Packet) -> Bool {
        return lhs.sequence == rhs.sequence &&
            lhs.updates == rhs.updates
    }

    static func <(lhs: Packet, rhs: Packet) -> Bool {
        return lhs.sequence < rhs.sequence
    }
}

// Mark: - PriorityAccumulator

/**
 * Since we probably can't send every object state in every packet, each object has a priority
 * associated with it. It increases every time the clock increments `update()`. Objects also
 * have an `intrinsicPriority` which allows certain objects to accumulate priority more quickly.
 */

protocol HasPriority {
    var intrinsicPriority: Float { get }
}

class PriorityAccumulator {
    var priorities = [Float](repeating: 0, count: Int(Int16.max))

    func update() {
        for registered in registry {
            if let prioritized = registered.value as? HasPriority {
                let id = registered.id
                priorities[Int(id)] = priorities[Int(id)] + prioritized.intrinsicPriority
            }
        }
    }

    func top(_ count: Int) -> [Registered] {
        let sorted = registry.sorted { (item1, item2) -> Bool in
            let id1 = item1.id
            let id2 = item2.id
            return priorities[Int(id1)] > priorities[Int(id2)]
        }
        var result = [Registered]()
        for registered in sorted[0..<min(count, sorted.count)] {
            let id = registered.id
            priorities[Int(id)] = 0
            result.append(registered)
        }
        return result
    }
}

// MARK: - JitterBuffer

/**
 * And on the receiving side, the JitterBuffer ensures packets are sent to the application in order
 * and once per-frame.
 */

class JitterBuffer {
    var buffer: [Packet?]
    let minDelay: Int

    var lastReceived: Int16 = -1
    var count = 0

    init(capacity: Int, minDelay: Int = 5) {
        assert(minDelay >= 0)

        self.buffer = [Packet?](repeating: nil, count: capacity)
        self.minDelay = minDelay
    }

    func push(_ packet: Packet) {
        buffer[Int(packet.sequence) % buffer.count] = packet
        lastReceived = max(packet.sequence, lastReceived)
    }

    subscript(sequence: Int) -> Packet? {
        let sequence = sequence - minDelay
        guard sequence >= 0 else { return nil }
        guard sequence <= lastReceived else { return nil }

        return buffer[sequence % buffer.count]
    }
}
