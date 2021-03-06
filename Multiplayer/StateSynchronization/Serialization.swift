import Foundation
import SceneKit

/**
 * Compact binary representation of objects, suitable for frequent network transmission.
 */

protocol DataConvertible {
    init(dataWrapper: DataWrapper)
    var data: Data { get }
}

protocol SimpleDataConvertible: DataConvertible {}

extension SimpleDataConvertible {
    init(dataWrapper: DataWrapper) {
        guard dataWrapper.count >= MemoryLayout<Self>.size else { fatalError("invalid number of bytes") }
        let data = dataWrapper.read(MemoryLayout<Self>.size)
        self = data.withUnsafeBytes { $0.pointee }
    }

    var data: Data {
        var value = self
        return Data(buffer: UnsafeBufferPointer(start: &value, count: 1))
    }
}

extension UInt8: SimpleDataConvertible {}
extension UInt16: SimpleDataConvertible {}
extension Int: SimpleDataConvertible {}
extension Float: SimpleDataConvertible {}
extension Double: SimpleDataConvertible {}
extension float3: SimpleDataConvertible {}
extension float4: SimpleDataConvertible {}

extension Array where Iterator.Element: DataConvertible {
    var data: Data {
        let data = NSMutableData()
        for item in self {
            data.append(item.data)
        }
        return data as Data
    }

    init(dataWrapper: DataWrapper, count: Int) {
        self = [Iterator.Element]()
        for _ in 0..<count {
            let item = Iterator.Element.self.init(dataWrapper: dataWrapper)
            self.append(item)
        }
    }
}

extension Packet: DataConvertible {
    static let minimumSizeInBytes = 5

    init(dataWrapper: DataWrapper) {
        guard dataWrapper.count >= Packet.minimumSizeInBytes else { fatalError("bad min size") }
        let sequence = UInt16(dataWrapper: dataWrapper)
        let inputsCount = UInt8(dataWrapper: dataWrapper)
        let inputs = [Input](dataWrapper: dataWrapper, count: Int(inputsCount))
        let compactCount = UInt8(dataWrapper: dataWrapper)
        let compactUpdates = [CompactNodeState](dataWrapper: dataWrapper, count: Int(compactCount))
        let fullCount = UInt8(dataWrapper: dataWrapper)
        let fullUpdates = [FullNodeState](dataWrapper: dataWrapper, count: Int(fullCount))

        self.sequence = sequence
        self.inputs = inputs
        self.updatesCompact = compactUpdates
        self.updatesFull = fullUpdates
    }

    var data: Data {
        let mutableData = NSMutableData()
        mutableData.append(sequence.data)
        mutableData.append(UInt8(inputs.count).data)
        mutableData.append(inputs.data)
        mutableData.append(UInt8(updatesCompact.count).data)
        mutableData.append(updatesCompact.data)
        mutableData.append(UInt8(updatesFull.count).data)
        mutableData.append(updatesFull.data)
        return mutableData as Data
    }
}

extension FullNodeState: DataConvertible {
    static let sizeInBytes = 66

    init(dataWrapper: DataWrapper) {
        guard dataWrapper.count >= FullNodeState.sizeInBytes else { fatalError("invalid number of bytes" )}
        let id = UInt16(dataWrapper: dataWrapper)
        let position = float3(dataWrapper: dataWrapper)
        let orientation = float4(dataWrapper: dataWrapper)
        let linearVelocity = float3(dataWrapper: dataWrapper)
        let angularVelocity = float4(dataWrapper: dataWrapper)

        self.id = id
        self.position = position
        self.orientation = orientation
        self.linearVelocity = linearVelocity
        self.angularVelocity = angularVelocity
    }

    var data: Data {
        let mutableData = NSMutableData()
        mutableData.append(id.data)
        mutableData.append(position.data)
        mutableData.append(orientation.data)
        mutableData.append(linearVelocity.data)
        mutableData.append(angularVelocity.data)
        return mutableData as Data
    }
}

extension CompactNodeState: DataConvertible {
    static let sizeInBytes = 34

    init(dataWrapper: DataWrapper) {
        guard dataWrapper.count >= CompactNodeState.sizeInBytes else { fatalError("Invalid number of bytes") }
        let id = UInt16(dataWrapper: dataWrapper)
        let position = float3(dataWrapper: dataWrapper)
        let orientation = float4(dataWrapper: dataWrapper)

        self.id = id
        self.position = position
        self.orientation = orientation
    }

    var data: Data {
        let mutableData = NSMutableData()
        mutableData.append(id.data)
        mutableData.append(position.data)
        mutableData.append(orientation.data)
        return mutableData as Data
    }
}

@objc extension UIColor {
    static let sizeInBytes = 4

    convenience init(dataWrapper: DataWrapper) {
        let red = UInt8(dataWrapper: dataWrapper)
        let green = UInt8(dataWrapper: dataWrapper)
        let blue = UInt8(dataWrapper: dataWrapper)
        let alpha = UInt8(dataWrapper: dataWrapper)
        self.init(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: CGFloat(alpha) / 255)
    }

    convenience init(dataWrapper: DataWrapper, r: Double, g: Double , b: Double , alpha: Double) {
        self.init(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(alpha))
    }

    var data: Data {
        let mutableData = NSMutableData()
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        mutableData.append(UInt8(red * 255).data)
        mutableData.append(UInt8(green * 255).data)
        mutableData.append(UInt8(blue * 255).data)
        return mutableData as Data
    }
}

extension Input: DataConvertible {
    static let minimumSizeInBytes = 3

    init(dataWrapper: DataWrapper) {
        guard dataWrapper.count >= Input.minimumSizeInBytes else { fatalError("Invalid number of bytes") }
        let sequence = UInt16(dataWrapper: dataWrapper)
        let inputCount = UInt8(dataWrapper: dataWrapper)
        var datas = [Data]()
        for _ in 0..<inputCount {
            let count = UInt8(dataWrapper: dataWrapper)
            let data = dataWrapper.read(Int(count))
            datas.append(data)
        }

        self.sequence = sequence
        self.underlying = datas
    }

    var data: Data {
        let mutableData = NSMutableData()
        mutableData.append(sequence.data)
        mutableData.append(UInt8(underlying.count).data)
        for datum in underlying {
            mutableData.append(UInt8(datum.count).data)
            mutableData.append(datum)
        }
        return mutableData as Data
    }
}

public class DataWrapper: NSObject {
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
