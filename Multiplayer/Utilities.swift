import Foundation
import SceneKit

extension SCNMaterial {
    static func material(withDiffuse diffuse: Any?, respondsToLighting: Bool = true) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = diffuse
        material.isDoubleSided = true
        if respondsToLighting {
            material.locksAmbientWithDiffuse = true
        } else {
            material.ambient.contents = UIColor.black
            material.lightingModel = .constant
            material.emission.contents = diffuse
        }
        return material
    }
}

// MARK: - Simple geometries

func createAxesNode(quiverLength: CGFloat, quiverThickness: CGFloat) -> SCNNode {
    let quiverThickness = (quiverLength / 50.0) * quiverThickness
    let chamferRadius = quiverThickness / 2.0

    let xQuiverBox = SCNBox(width: quiverLength, height: quiverThickness, length: quiverThickness, chamferRadius: chamferRadius)
    xQuiverBox.materials = [SCNMaterial.material(withDiffuse: UIColor.red, respondsToLighting: false)]
    let xQuiverNode = SCNNode(geometry: xQuiverBox)
    xQuiverNode.position = SCNVector3Make(Float(quiverLength / 2.0), 0.0, 0.0)

    let yQuiverBox = SCNBox(width: quiverThickness, height: quiverLength, length: quiverThickness, chamferRadius: chamferRadius)
    yQuiverBox.materials = [SCNMaterial.material(withDiffuse: UIColor.green, respondsToLighting: false)]
    let yQuiverNode = SCNNode(geometry: yQuiverBox)
    yQuiverNode.position = SCNVector3Make(0.0, Float(quiverLength / 2.0), 0.0)

    let zQuiverBox = SCNBox(width: quiverThickness, height: quiverThickness, length: quiverLength, chamferRadius: chamferRadius)
    zQuiverBox.materials = [SCNMaterial.material(withDiffuse: UIColor.blue, respondsToLighting: false)]
    let zQuiverNode = SCNNode(geometry: zQuiverBox)
    zQuiverNode.position = SCNVector3Make(0.0, 0.0, Float(quiverLength / 2.0))

    let quiverNode = SCNNode()
    quiverNode.addChildNode(xQuiverNode)
    quiverNode.addChildNode(yQuiverNode)
    quiverNode.addChildNode(zQuiverNode)
    quiverNode.name = "Axes"
    return quiverNode
}

extension float3x3 {
    init(float4x4: float4x4) {
        let column0 = float3 ( float4: float4x4.columns.0 )
        let column1 = float3 ( float4: float4x4.columns.1 )
        let column2 = float3 ( float4: float4x4.columns.2 )

        self.init(column0, column1, column2)
    }
}

extension float3 {
    init(float4: simd_float4) {
        self.init(float4.x, float4.y, float4.z)
    }
}

extension float4x4 {
    init(float3x3: simd_float3x3) {
        let column0 = float4 ( float3: float3x3.columns.0 )
        let column1 = float4 ( float3: float3x3.columns.1 )
        let column2 = float4 ( float3: float3x3.columns.2 )
        let identity3 = simd_float4(x: 0, y: 0, z: 0, w: 1)

        self.init(column0, column1, column2, identity3)
    }
}

extension float4 {
    init(float3: simd_float3) {
        self.init(float3.x, float3.y, float3.z, 0)
    }
}
