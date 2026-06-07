import SwiftUI
import SceneKit

struct SkyView: View {
    @ObservedObject var monitor: TelemetryMonitor
    
    var body: some View {
        VStack(spacing: 30) {
            Text("3D Obstruction Map")
                .font(.largeTitle)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let map = monitor.obstructionMap {
                if map.numRows > 0 && map.numCols > 0 {
                    SceneView(
                        scene: makeScene(from: map),
                        options: [.allowsCameraControl, .autoenablesDefaultLighting]
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                    
                    HStack(spacing: 20) {
                        Label("Clear Sky", systemImage: "circle.fill")
                            .foregroundColor(Color(nsColor: .cyan))
                        Label("Obstructed", systemImage: "circle.fill")
                            .foregroundColor(Color(nsColor: .red))
                        Text("(Drag to rotate, Pinch to zoom)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                } else {
                    Text("Obstruction map data is empty.")
                        .foregroundColor(.secondary)
                }
            } else {
                VStack {
                    ProgressView()
                    Text("Waiting for 3D obstruction data...")
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(40)
    }
    
    private func makeScene(from map: SpaceX_API_Device_DishGetObstructionMapResponse) -> SCNScene {
        let scene = SCNScene()
        
        // 1. Central Dish Node
        let dishNode = SCNNode()
        
        let mount = SCNCylinder(radius: 0.2, height: 1.0)
        mount.firstMaterial?.diffuse.contents = NSColor.gray
        let mountNode = SCNNode(geometry: mount)
        mountNode.position = SCNVector3(0, -0.5, 0)
        dishNode.addChildNode(mountNode)
        
        let face = SCNBox(width: 2.0, height: 0.1, length: 1.4, chamferRadius: 0.05)
        face.firstMaterial?.diffuse.contents = NSColor.white
        let faceNode = SCNNode(geometry: face)
        faceNode.eulerAngles = SCNVector3(Float.pi / 6, 0, 0) // Tilt the dish up
        dishNode.addChildNode(faceNode)
        
        scene.rootNode.addChildNode(dishNode)
        
        // 2. Sky Dome Node
        let dome = SCNSphere(radius: 10.0)
        dome.segmentCount = 64
        
        let texture = generateTexture(from: map)
        let material = SCNMaterial()
        material.diffuse.contents = texture
        material.isDoubleSided = true
        material.transparency = 0.7 // Make it glass-like to see the dish inside
        material.blendMode = .alpha
        dome.firstMaterial = material
        
        let domeNode = SCNNode(geometry: dome)
        // Optionally rotate the dome so it aligns properly with the scene (adjust if needed)
        scene.rootNode.addChildNode(domeNode)
        
        // 3. Lighting
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(0, 10, 10)
        scene.rootNode.addChildNode(lightNode)
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = NSColor(white: 0.2, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLightNode)
        
        // 4. Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 4, 15)
        let constraint = SCNLookAtConstraint(target: dishNode)
        constraint.isGimbalLockEnabled = true
        cameraNode.constraints = [constraint]
        scene.rootNode.addChildNode(cameraNode)
        
        return scene
    }
    
    private func generateTexture(from map: SpaceX_API_Device_DishGetObstructionMapResponse) -> NSImage {
        let width = Int(map.numCols)
        let height = Int(map.numRows)
        let outHeight = height * 2 // Double height to constrain data to top hemisphere
        
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: outHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ) else {
            return NSImage()
        }
        
        // Initialize with transparent pixels
        for y in 0..<outHeight {
            for x in 0..<width {
                bitmapRep.setColor(NSColor.clear, atX: x, y: y)
            }
        }
        
        // Fill the top hemisphere
        for row in 0..<height {
            for col in 0..<width {
                let index = row * width + col
                if index < map.snr.count {
                    let snr = map.snr[index]
                    
                    var color: NSColor
                    if snr > 0 {
                        // Clear sky
                        color = NSColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.4)
                    } else {
                        // Obstructed
                        color = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.8)
                    }
                    
                    // Row 0 is zenith (top), Row `height-1` is horizon
                    bitmapRep.setColor(color, atX: col, y: row)
                }
            }
        }
        
        let image = NSImage(size: NSSize(width: width, height: outHeight))
        image.addRepresentation(bitmapRep)
        return image
    }
}
