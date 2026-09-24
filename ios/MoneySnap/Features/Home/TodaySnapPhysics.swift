import CoreMotion
import SpriteKit
import SwiftUI
import UIKit

struct TodaySnapPhysicsCanvas: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let entries: [TodaySnapEntry]
    let onSelect: (TodaySnapEntry.ID) -> Void
    let dropGeneration: Int
    let onHoldChanged: (Bool) -> Void
    @State private var scene: TodaySnapPhysicsScene
    @State private var dragCount = 0

    init(
        entries: [TodaySnapEntry],
        onSelect: @escaping (TodaySnapEntry.ID) -> Void,
        dropGeneration: Int = 0,
        onHoldChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.entries = entries
        self.onSelect = onSelect
        self.dropGeneration = dropGeneration
        self.onHoldChanged = onHoldChanged
        _scene = State(initialValue: TodaySnapPhysicsScene(
            entries: entries,
            onSelect: onSelect
        ))
    }

    var body: some View {
        Group {
            if reduceMotion {
                StaticSnapPile(entries: entries, onSelect: onSelect)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                ZStack {
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .accessibilityIdentifier("home.physics-canvas")
                        .accessibilityValue("이동 \(dragCount)회, 낙하 \(dropGeneration + 1)회")
                    accessibilityBridge
                }
            }
        }
        .onChange(of: entries) { _, updatedEntries in
            scene.replaceEntries(updatedEntries)
        }
        .onChange(of: dropGeneration) { _, _ in scene.replayDrop() }
        .onAppear {
            scene.onHoldChanged = onHoldChanged
            scene.onDragComplete = { dragCount += 1 }
        }
    }

    private var accessibilityBridge: some View {
        HStack(spacing: 0) {
            ForEach(entries) { entry in
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel("\(entry.category.title), \(entry.amount.value.wonText)")
                    .accessibilityIdentifier("home.placeholder.featured.\(entry.id.uuidString.lowercased())")
            }
        }
        .allowsHitTesting(false)
    }
}

final class TodaySnapPhysicsScene: SKScene {
    private let motionManager = CMMotionManager()
    private let onSelect: (TodaySnapEntry.ID) -> Void
    private var entries: [TodaySnapEntry]
    private weak var draggedNode: SKNode?
    private var touchOrigin = CGPoint.zero
    private var cardOrigin = CGPoint.zero
    private var originalZPosition: CGFloat = 0
    private var isDragging = false
    var onHoldChanged: (Bool) -> Void = { _ in }
    var onDragComplete: () -> Void = {}

    init(
        entries: [TodaySnapEntry],
        onSelect: @escaping (TodaySnapEntry.ID) -> Void
    ) {
        self.entries = entries
        self.onSelect = onSelect
        super.init(size: CGSize(width: 393, height: 310))
        scaleMode = .resizeFill
        backgroundColor = .clear
        physicsWorld.gravity = TodayCanvasPhysics.defaultGravity
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        rebuildScene()
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates()
    }

    override func willMove(from view: SKView) {
        motionManager.stopDeviceMotionUpdates()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        rebuildScene()
    }

    override func update(_ currentTime: TimeInterval) {
        guard let gravity = motionManager.deviceMotion?.gravity else { return }
        let isFlat = abs(gravity.x) + abs(gravity.y) < 0.2
        physicsWorld.gravity = isFlat
            ? TodayCanvasPhysics.defaultGravity
            : TodayCanvasPhysics.gravity(deviceX: gravity.x, deviceY: gravity.y)
    }

    func replaceEntries(_ entries: [TodaySnapEntry]) {
        guard self.entries != entries else { return }
        self.entries = entries
        rebuildScene()
    }

    func replayDrop() { rebuildScene() }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        beginInteraction(at: touch.location(in: self))
    }

    func beginInteraction(at point: CGPoint) {
        guard let node = cardNode(at: point) else { return }
        draggedNode = node
        touchOrigin = point
        cardOrigin = node.position
        originalZPosition = node.zPosition
        isDragging = false
        onHoldChanged(true)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        moveInteraction(to: touch.location(in: self))
    }

    func moveInteraction(to point: CGPoint) {
        guard let node = draggedNode else { return }
        let dx = point.x - touchOrigin.x
        let dy = point.y - touchOrigin.y
        guard isDragging || hypot(dx, dy) >= 10 else { return }
        if !isDragging {
            isDragging = true
            node.physicsBody?.isDynamic = false
            node.physicsBody?.velocity = .zero
            node.zPosition = 100
        }
        node.position = clamped(CGPoint(x: cardOrigin.x + dx, y: cardOrigin.y + dy), for: node)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        endInteraction(at: touch.location(in: self))
    }

    func endInteraction(at point: CGPoint) {
        guard let node = draggedNode else { return }
        if isDragging {
            moveInteraction(to: point)
            node.physicsBody?.isDynamic = true
            node.physicsBody?.velocity = .zero
            node.zPosition = originalZPosition
            onDragComplete()
        } else if let name = node.name,
                  let id = UUID(uuidString: String(name.dropFirst("snap:".count))) {
            onSelect(id)
        }
        draggedNode = nil
        isDragging = false
        onHoldChanged(false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDragging {
            draggedNode?.physicsBody?.isDynamic = true
            draggedNode?.physicsBody?.velocity = .zero
            draggedNode?.zPosition = originalZPosition
        }
        draggedNode = nil
        isDragging = false
        onHoldChanged(false)
    }

    private func rebuildScene() {
        guard size.width > 100, size.height > 100 else { return }
        draggedNode = nil
        isDragging = false
        onHoldChanged(false)
        removeAllChildren()
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(
            x: 5,
            y: 5,
            width: size.width - 10,
            height: size.height - 10
        ))
        physicsBody?.friction = 0.42

        guard let maximumAmount = entries.map(\.amount).max() else { return }
        let xOffsets: [CGFloat] = [-56, 24, 66, -16, 48, -42]
        let rotations: [CGFloat] = [0.08, -0.07, 0.04, -0.1, 0.06, -0.03]

        for (index, entry) in entries.prefix(6).enumerated() {
            let cardSize = TodayCanvasLayout.physicsCardSize(
                for: entry,
                maximumAmount: maximumAmount
            )
            let card = makeCard(for: entry, size: cardSize)
            let halfWidth = cardSize.width / 2
            card.position = CGPoint(
                x: min(size.width - halfWidth - 8, max(halfWidth + 8, size.width / 2 + xOffsets[index])),
                y: max(cardSize.height / 2 + 12, size.height - 48 - CGFloat(index * 24))
            )
            card.zRotation = rotations[index]
            card.zPosition = CGFloat(index + 1)
            addChild(card)
        }
    }

    private func makeCard(for entry: TodaySnapEntry, size: CGSize) -> SKNode {
        let card = SKNode()
        card.name = "snap:\(entry.id.uuidString)"
        let isPortrait = size.height > size.width
        let hasPhoto = entry.artwork != nil || entry.previewJPEG != nil
        let mediaSize = isPortrait
            ? CGSize(width: size.width * 0.7, height: size.height * 0.74)
            : CGSize(width: size.width, height: size.height * 0.78)
        if let artwork = entry.artwork {
            let crop = artworkNode(named: artwork.rawValue, size: mediaSize)
            crop.name = "photo"
            crop.position.y = isPortrait ? 14 : 12
            crop.zRotation = isPortrait ? -0.13 : 0.13
            card.addChild(crop)
        } else if let jpeg = entry.previewJPEG, let image = UIImage(data: jpeg) {
            let crop = artworkNode(image: image, size: mediaSize)
            crop.name = "photo"
            crop.position.y = isPortrait ? 14 : 12
            crop.zRotation = isPortrait ? -0.13 : 0.13
            card.addChild(crop)
        }
        if entry.revealsAmount {
            let chipPosition = CGPoint(x: hasPhoto ? min(14, size.width / 8) : 0, y: hasPhoto ? -size.height / 2 + 23 : 0)
            let chip = SKShapeNode(rectOf: CGSize(width: 112, height: 50), cornerRadius: 15)
            chip.name = "amount-chip"
            chip.fillColor = UIColor.white.withAlphaComponent(0.68)
            chip.strokeColor = UIColor.white.withAlphaComponent(0.58)
            chip.lineWidth = 1
            chip.position = chipPosition
            chip.zRotation = hasPhoto ? (isPortrait ? -0.14 : 0.12) : -0.07
            let category = SKLabelNode(fontNamed: "NotoSansKR-Medium")
            category.text = entry.category.title
            category.fontSize = 9
            category.fontColor = UIColor(MoneySnapVisualSystem.secondaryText)
            category.horizontalAlignmentMode = .center
            category.verticalAlignmentMode = .center
            category.position.y = -11
            chip.addChild(category)

            let amount = SKLabelNode(fontNamed: "NotoSansKR-Bold")
            amount.text = entry.amount.value.wonText
            amount.fontSize = 17
            amount.fontColor = UIColor(MoneySnapVisualSystem.priceText)
            amount.horizontalAlignmentMode = .center
            amount.verticalAlignmentMode = .center
            amount.position.y = 7
            chip.addChild(amount)
            card.addChild(chip)
        }

        card.physicsBody = SKPhysicsBody(rectangleOf: size)
        card.physicsBody?.density = 0.72
        card.physicsBody?.friction = 0.46
        card.physicsBody?.restitution = 0.2
        card.physicsBody?.linearDamping = 0.38
        card.physicsBody?.angularDamping = 0.46
        card.physicsBody?.allowsRotation = true
        card.isAccessibilityElement = true
        card.accessibilityLabel = "\(entry.category.title), \(entry.amount.value.wonText)"
        card.accessibilityHint = "두 번 탭하여 Snap 상세 보기"
        return card
    }

    private func artworkNode(named name: String, size: CGSize) -> SKCropNode {
        artworkNode(image: UIImage(named: name) ?? UIImage(), size: size)
    }

    private func artworkNode(image: UIImage, size: CGSize) -> SKCropNode {
        let crop = SKCropNode()
        let mask = SKShapeNode(rectOf: size, cornerRadius: size.height > size.width ? 14 : 19)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask

        let sprite = SKSpriteNode(texture: SKTexture(image: image))
        if let textureSize = sprite.texture?.size(), textureSize.width > 0, textureSize.height > 0 {
            let scale = max(size.width / textureSize.width, size.height / textureSize.height)
            sprite.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        } else {
            sprite.size = size
        }
        crop.addChild(sprite)
        return crop
    }

    private func cardNode(at point: CGPoint) -> SKNode? {
        for candidate in nodes(at: point) {
            var current: SKNode? = candidate
            while let node = current {
                if node.name?.hasPrefix("snap:") == true { return node }
                current = node.parent
            }
        }
        return nil
    }

    private func clamped(_ point: CGPoint, for node: SKNode) -> CGPoint {
        let width = node.physicsBody == nil ? CGFloat(44) : node.calculateAccumulatedFrame().width
        let height = node.physicsBody == nil ? CGFloat(44) : node.calculateAccumulatedFrame().height
        return CGPoint(
            x: min(size.width - width / 2 - 6, max(width / 2 + 6, point.x)),
            y: min(size.height - height / 2 - 6, max(height / 2 + 6, point.y))
        )
    }

}

private struct StaticSnapPile: View {
    let entries: [TodaySnapEntry]
    let onSelect: (TodaySnapEntry.ID) -> Void

    var body: some View {
        let visibleEntries = Array(entries.prefix(3))
        let maximumAmount = visibleEntries.map(\.amount).max()

        ZStack {
            ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                Button {
                    onSelect(entry.id)
                } label: {
                    FeaturedSnapCard(
                        entry: entry,
                        imageSize: maximumAmount.map {
                            TodayCanvasLayout.imageSize(for: entry, maximumAmount: $0)
                        } ?? .zero,
                        layout: index.isMultiple(of: 2) ? .landscape : .portrait
                    )
                }
                .buttonStyle(.plain)
                .rotationEffect(.degrees([4, -5, 2][index]))
                .offset(x: [-62, 48, 6][index], y: [-26, 12, 58][index])
                .accessibilityLabel("\(entry.category.title), \(entry.amount.value.wonText)")
                .accessibilityHint("Snap 상세 보기")
            }
        }
    }
}
