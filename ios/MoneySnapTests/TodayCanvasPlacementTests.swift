import Foundation
import SpriteKit
import Testing
@testable import MoneySnap

struct TodayCanvasPlacementTests {
    @Test @MainActor
    func tappingCardCaptionOpensDetailWithoutMovingTheCard() throws {
        let entry = TodaySnapEntry(id: UUID(), category: .food, amount: try KrwAmount(18_900))
        var selected: UUID?
        let scene = TodaySnapPhysicsScene(entries: [entry]) { selected = $0 }
        scene.didMove(to: SKView())
        let card = try #require(scene.children.first { $0.name == "snap:\(entry.id.uuidString)" })
        let start = card.position
        let captionPoint = CGPoint(x: start.x + 35, y: start.y - 35)

        scene.beginInteraction(at: captionPoint)
        scene.endInteraction(at: captionPoint)

        #expect(card.position == start)
        #expect(card.physicsBody?.isDynamic == true)
        #expect(selected == entry.id)
    }

    @Test @MainActor
    func draggedCardKeepsTheGrabOffsetAndFallsWhenReleased() throws {
        let entry = TodaySnapEntry(id: UUID(), category: .food, amount: try KrwAmount(18_900))
        let scene = TodaySnapPhysicsScene(entries: [entry]) { _ in }
        scene.didMove(to: SKView())
        let card = try #require(scene.children.first { $0.name == "snap:\(entry.id.uuidString)" })
        let start = card.position
        let grab = CGPoint(x: start.x + 20, y: start.y - 10)
        let moved = CGPoint(x: grab.x + 30, y: grab.y - 20)

        scene.beginInteraction(at: grab)
        scene.moveInteraction(to: moved)
        #expect(card.position == CGPoint(x: start.x + 30, y: start.y - 20))
        #expect(card.physicsBody?.isDynamic == false)

        scene.endInteraction(at: moved)
        #expect(card.physicsBody?.isDynamic == true)
        #expect(card.physicsBody?.velocity == .zero)
    }

    @Test @MainActor
    func replayRecreatesCardsAtTheTopWithTheSameEntries() throws {
        let entry = TodaySnapEntry(id: UUID(), category: .food, amount: try KrwAmount(18_900))
        let scene = TodaySnapPhysicsScene(entries: [entry]) { _ in }
        scene.didMove(to: SKView())
        let oldCard = try #require(scene.children.first { $0.name == "snap:\(entry.id.uuidString)" })
        oldCard.position = CGPoint(x: 90, y: 90)

        scene.replayDrop()

        let newCard = try #require(scene.children.first { $0.name == "snap:\(entry.id.uuidString)" })
        #expect(newCard !== oldCard)
        #expect(newCard.position.y > 90)
        #expect(scene.physicsWorld.gravity == TodayCanvasPhysics.defaultGravity)
    }

    @Test @MainActor
    func physicsCardUsesPhotoAndFloatingAmountChip() throws {
        let entry = TodaySnapEntry(id: UUID(), category: .food, amount: try KrwAmount(18_900), artwork: .food)
        let scene = TodaySnapPhysicsScene(entries: [entry]) { _ in }
        scene.didMove(to: SKView())
        let card = try #require(scene.children.first { $0.name == "snap:\(entry.id.uuidString)" })

        #expect(card.childNode(withName: "photo") != nil)
        #expect(card.childNode(withName: "amount-chip") != nil)
        #expect(card.childNode(withName: "card-surface") == nil)
    }

    @Test
    func restCentersMatchTheReviewedHomeCanvas() {
        let width: CGFloat = 393

        #expect(TodayCanvasPlacement.restCenter(index: 0, canvasWidth: width) == CGPoint(x: width * 0.357, y: 276))
        #expect(TodayCanvasPlacement.restCenter(index: 1, canvasWidth: width) == CGPoint(x: width * 0.736, y: 303))
        #expect(TodayCanvasPlacement.restCenter(index: 2, canvasWidth: width) == CGPoint(x: width * 0.256, y: 354))
    }

    @Test
    func physicsPlayAreaStaysAboveTheRecordButton() {
        let buttonTop = TodayCanvasPlacement.recordButtonCenterY - TodayCanvasPlacement.recordButtonHeight / 2

        #expect(TodayCanvasPlacement.physicsFloorY < buttonTop)
        #expect(TodayCanvasPlacement.physicsFloorY > 300)
        #expect(TodayCanvasPlacement.dropY > TodayCanvasPlacement.physicsCeilingY)
    }

    @Test
    func droppedBodiesStartFullyBelowTheCeiling() {
        for size in [CGSize(width: 48, height: 48), CGSize(width: 120, height: 120)] {
            let radius = TodayCanvasPlacement.collisionRadius(size: size)
            let y = TodayCanvasPlacement.dropCenterY(size: size)
            #expect(y - radius > TodayCanvasPlacement.physicsCeilingY)
            #expect(y + radius < TodayCanvasPlacement.physicsFloorY)
        }
    }

    @Test
    func livePhysicsSizesShrinkSoManySnapsCanShareTheCanvas() throws {
        let large = TodaySnapEntry(
            id: UUID(),
            category: .food,
            amount: try KrwAmount(18_900)
        )
        let small = TodaySnapEntry(
            id: UUID(),
            category: .cafe,
            amount: try KrwAmount(2_800)
        )
        let few = TodayCanvasPlacement.physicsSize(
            for: large,
            maximumAmount: large.amount,
            count: 2
        )
        let many = TodayCanvasPlacement.physicsSize(
            for: large,
            maximumAmount: large.amount,
            count: 6
        )
        let cheaper = TodayCanvasPlacement.physicsSize(
            for: small,
            maximumAmount: large.amount,
            count: 2
        )

        #expect(few.width <= 97)
        #expect(few.width >= 88)
        #expect(many.width < few.width)
        #expect(cheaper.width < few.width)
        #expect(many.width >= 44)
    }

    @Test
    func packedCentersStayInsideThePhysicsPlayArea() {
        let size = CGSize(width: 97, height: 97)
        for index in 0..<6 {
            let center = TodayCanvasPlacement.packedCenter(
                index: index,
                count: 6,
                canvasWidth: 393,
                size: size
            )
            #expect(center.y > TodayCanvasPlacement.physicsCeilingY)
            #expect(center.y + size.height / 2 <= TodayCanvasPlacement.physicsFloorY)
            #expect(center.x > 20)
            #expect(center.x < 373)
        }
    }

    @Test
    func physicsDropStartsAboveTheRestingCanvas() {
        let id = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let drop = TodayCanvasPlacement.pose(
            id: id,
            index: 0,
            canvasWidth: 393,
            motion: .physics,
            isNew: true
        )
        let rest = TodayCanvasPlacement.pose(
            id: id,
            index: 0,
            canvasWidth: 393,
            motion: .physics,
            isNew: false
        )

        #expect(drop.center.y < TodayCanvasPlacement.physicsFloorY)
        #expect(drop.center.y > TodayCanvasPlacement.physicsCeilingY)
        #expect(rest.center.y < TodayCanvasPlacement.physicsFloorY)
        #expect(rest.center.y > TodayCanvasPlacement.physicsCeilingY)
    }

    @Test
    func recordButtonMatchesTheReviewedHomePlacement() {
        #expect(TodayCanvasPlacement.recordButtonCenterY == 435)
        #expect(TodayCanvasPlacement.recordButtonWidth == 164)
        #expect(TodayCanvasPlacement.recordButtonHeight == 65)
        #expect(TodayCanvasPlacement.physicsFloorY < TodayCanvasPlacement.recordButtonCenterY - TodayCanvasPlacement.recordButtonHeight / 2)
    }

    @Test
    func hiddenAmountSnapsUseAFixedImageSize() throws {
        let hidden = TodaySnapEntry(
            id: UUID(),
            category: .food,
            amount: try KrwAmount(1),
            revealsAmount: false
        )
        let visible = TodaySnapEntry(
            id: UUID(),
            category: .food,
            amount: try KrwAmount(18_900)
        )

        #expect(
            TodayCanvasPlacement.physicsSize(
                for: hidden,
                maximumAmount: visible.amount,
                count: 2
            ) == CGSize(width: 79, height: 79)
        )
        #expect(
            TodayCanvasPlacement.physicsSize(
                for: visible,
                maximumAmount: visible.amount,
                count: 2
            ).width <= 97
        )
        #expect(
            TodayCanvasPlacement.physicsSize(
                for: visible,
                maximumAmount: visible.amount,
                count: 2
            ).width >= 88
        )
    }

    @Test
    func liveFloatUsesCruiseSpeedInsteadOfFreezingInPlace() {
        #expect(TodayCanvasPlacement.floatCruiseSpeed >= 18)
        #expect(TodayCanvasPlacement.floatCruiseSpeed < TodayCanvasPlacement.floatSpeedLimit)
        #expect(TodayCanvasPlacement.floatSpeedLimit >= 50)
        #expect(TodayCanvasDrift.spring == 0.05)
        #expect(TodayCanvasDrift.wallBounce == -0.9)
    }

    @Test
    func collisionRadiusMatchesTheVisibleToken() {
        let size = CGSize(width: 80, height: 60)
        #expect(TodayCanvasPlacement.collisionRadius(size: size) == 40)
    }

    @Test
    func reduceMotionAndVisualHomeKeepRestingCoordinates() {
        let id = UUID()
        let reduced = TodayCanvasPlacement.pose(
            id: id,
            index: 0,
            canvasWidth: 393,
            motion: .staticRest,
            isNew: true
        )

        #expect(reduced.center == CGPoint(x: 393 * 0.357, y: 276))
        #expect(
            TodayCanvasPlacement.motion(
                reduceMotion: true,
                visualScenario: nil
            ) == .staticRest
        )
        #expect(
            TodayCanvasPlacement.motion(
                reduceMotion: false,
                visualScenario: "home"
            ) == .staticRest
        )
        #expect(
            TodayCanvasPlacement.motion(
                reduceMotion: false,
                visualScenario: nil
            ) == .physics
        )
    }
}
