import Foundation
import SceneKit

/**
 * Extremely compact binary representation of objects, suitable for frequent network transmission.
 */

protocol DataConvertible {
    init?(dataWrapper: DataWrapper)
    var data: Data { get }
}

extension DataConvertible {
    init?(dataWrapper: DataWrapper) {
        guard dataWrapper.count >= MemoryLayout<Self>.size else { return nil }
        let data = dataWrapper.read(MemoryLayout<Self>.size)
        self = data.withUnsafeBytes { $0.pointee }
    }

    var data: Data {
        var value = self
        return Data(buffer: UnsafeBufferPointer(start: &value, count: 1))
    }
}

extension UInt8: DataConvertible {}
extension Int16: DataConvertible {}
extension Int: DataConvertible {}
extension Float: DataConvertible {}
extension Double: DataConvertible {}
extension float3: DataConvertible {}
extension float4: DataConvertible {}

extension Array: DataConvertible {
    var data: Data {
        var values = self
        return Data(buffer: UnsafeBufferPointer(start: &values, count: count))
    }

    init?(dataWrapper: DataWrapper, count: Int) {
        guard dataWrapper.count >= MemoryLayout<Iterator.Element>.stride * count else { return nil }
        self.init(data: dataWrapper.read(MemoryLayout<Iterator.Element>.stride * count))
    }

    init?(data: Data) {
        self = data.withUnsafeBytes {
            [Iterator.Element](UnsafeBufferPointer(start: $0, count: data.count/MemoryLayout<Iterator.Element>.stride))
        }
    }
}
extension Packet: DataConvertible {
    static let minimumSizeInBytes = 4

    init?(dataWrapper: DataWrapper) {
        guard dataWrapper.count >= Packet.minimumSizeInBytes,
            let sequence = Int16(dataWrapper: dataWrapper),
            let compactCount = UInt8(dataWrapper: dataWrapper),
            let compactUpdates = [CompactNodeState](dataWrapper: dataWrapper, count: Int(compactCount)),
            let fullCount = UInt8(dataWrapper: dataWrapper),
            let fullUpdates = [FullNodeState](dataWrapper: dataWrapper, count: Int(fullCount)) else { return nil }

        self.sequence = sequence
        self.updatesCompact = compactUpdates
        self.updatesFull = fullUpdates
    }

    var data: Data {
        let mutableData = NSMutableData()
        mutableData.append(sequence.data)
        mutableData.append(UInt8(updatesCompact.count).data)
        mutableData.append(updatesCompact.data)
        mutableData.append(UInt8(updatesFull.count).data)
        mutableData.append(updatesFull.data)
        return mutableData as Data
    }
}

extension FullNodeState: DataConvertible {
    static let sizeInBytes = 66

    init?(dataWrapper: DataWrapper) {
        guard dataWrapper.count == FullNodeState.sizeInBytes,
            let id = Int16(dataWrapper: dataWrapper),
            let position = float3(dataWrapper: dataWrapper),
            let eulerAngles = float3(dataWrapper: dataWrapper),
            let linearVelocity = float3(dataWrapper: dataWrapper),
            let angularVelocity = float4(dataWrapper: dataWrapper) else { return nil }

        self.id = id
        self.position = position
        self.eulerAngles = eulerAngles
        self.linearVelocity = linearVelocity
        self.angularVelocity = angularVelocity
    }

    var data: Data {
        let mutableData = NSMutableData()
        mutableData.append(id.data)
        mutableData.append(position.data)
        mutableData.append(eulerAngles.data)
        mutableData.append(linearVelocity.data)
        mutableData.append(angularVelocity.data)
        return mutableData as Data
    }
}

extension CompactNodeState: DataConvertible {
    static let sizeInBytes = 34

    init?(dataWrapper: DataWrapper) {
        guard dataWrapper.count >= CompactNodeState.sizeInBytes,
            let id = Int16(dataWrapper: dataWrapper),
            let position = float3(dataWrapper: dataWrapper),
            let eulerAngles = float3(dataWrapper: dataWrapper) else { return nil }

        self.id = id
        self.position = position
        self.eulerAngles = eulerAngles
    }

    var data: Data {
        let mutableData = NSMutableData()
        mutableData.append(id.data)
        mutableData.append(position.data)
        mutableData.append(eulerAngles.data)
        return mutableData as Data
    }
}

class DataWrapper {
    let underlying: Data
    var cursor = 0

    init(_ underlying: Data) {
        self.underlying = underlying
    }

    func read(_ count: Int) -> Data {
        let result = underlying.subdata(in: cursor..<cursor+count)
        cursor += count
        return result
    }

    var count: Int {
        return underlying.count - cursor
    }
}
