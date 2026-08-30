import Foundation
import Testing
@testable import MoneySnap

@MainActor
struct TodaySnapPresentationTests {
    @Test
    func tiltingThePhoneDirectsThePileWithoutUnboundedGravity() {
        let tilted = TodayCanvasPhysics.gravity(deviceX: 0.5, deviceY: -0.75)
        let clamped = TodayCanvasPhysics.gravity(deviceX: 4, deviceY: -4)

        #expect(tilted.dx == 4)
        #expect(tilted.dy == -6)
        #expect(clamped.dx == 8)
        #expect(clamped.dy == -8)
    }

    @Test
    func largerAmountsProduceLargerReadablePhysicsCards() throws {
        let largest = TodaySnapEntry(
            id: UUID(),
            category: .food,
            amount: try KrwAmount(18_900),
            artwork: .food
        )
        let smaller = TodaySnapEntry(
            id: UUID(),
            category: .transportation,
            amount: try KrwAmount(2_800),
            artwork: nil
        )

        let largestSize = TodayCanvasLayout.physicsCardSize(
            for: largest,
            maximumAmount: largest.amount
        )
        let smallerSize = TodayCanvasLayout.physicsCardSize(
            for: smaller,
            maximumAmount: largest.amount
        )

        #expect(largestSize == CGSize(width: 154, height: 112))
        #expect(smallerSize.width < largestSize.width)
        #expect(smallerSize.height < largestSize.height)
    }

    @Test
    func selectingAVisibleSnapResolvesTheSameDetailContent() async throws {
        let viewModel = TodaySnapViewModel(client: VisualTestSupport.snapJournalClient)
        await viewModel.load()
        let selectedID = try #require(VisualTestSupport.homeSummary.featuredEntryIDs.first)

        let detail = try #require(viewModel.detailPresentation(for: selectedID))

        #expect(detail.entry.id == selectedID)
        #expect(detail.entry.amount.value == 18_900)
        #expect(detail.day == VisualTestSupport.homeSummary.day)
        #expect(viewModel.detailPresentation(for: UUID()) == nil)
    }
}
