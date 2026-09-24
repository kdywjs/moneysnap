import Foundation
import PhotosUI
import SwiftUI
import UIKit

struct AppShellView: View {
    @Binding var selectedTab: AppTab
    @State private var tabRouter = TabRouter()
    @State private var presentedSheet: AppSheet?
    @State private var showsRecordSource = false
    @State private var showsRecordInput = false
    @State private var showsCamera = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var capturedImage: UIImage?
    @State private var showsPhotoError = false
    @State private var activeRecordModel: SnapCaptureModel?
    @State private var presentsMenu = false
    @State private var pendingShare: SnapRecordReceipt?
    @State private var todayViewModel: TodaySnapViewModel
    @State private var homeDropGeneration = 0
    @State private var shareGroups: [MoneySnapGroup] = []
    private let authentication: AuthenticationModel
    private let snapJournalClient: any SnapJournalClient
    private let groupClient: any GroupClient
    private let mediaClient: (any MediaClient)?
    private let initialCaptureModel: SnapCaptureModel?

    init(
        selectedTab: Binding<AppTab>,
        authentication: AuthenticationModel,
        snapJournalClient: any SnapJournalClient,
        groupClient: any GroupClient = UnavailableGroupClient(),
        mediaClient: (any MediaClient)? = nil,
        initialCaptureModel: SnapCaptureModel? = nil
    ) {
        _selectedTab = selectedTab
        _todayViewModel = State(initialValue: TodaySnapViewModel(client: snapJournalClient, media: mediaClient))
        _presentedSheet = State(initialValue: initialCaptureModel == nil ? nil : .record)
        self.authentication = authentication
        self.snapJournalClient = snapJournalClient
        self.groupClient = groupClient
        self.mediaClient = mediaClient
        self.initialCaptureModel = initialCaptureModel
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                ForEach(AppTab.allCases.filter { $0 != .add }) { tab in
                    NavigationStack(path: tabRouter.binding(for: tab)) {
                        rootView(for: tab)
                            .navigationDestination(for: AppRoute.self) { route in
                                switch route {
                                case let .snapDetail(id):
                                    SnapDetailView(
                                        model: SnapDetailModel(
                                            snapID: id,
                                            client: snapJournalClient,
                                            media: mediaClient
                                        ),
                                        onChanged: { detail in
                                            todayViewModel.replace(detail)
                                        },
                                        onDeleted: {
                                            todayViewModel.remove(id)
                                            tabRouter.router(for: tab).path.removeAll()
                                            Task { await todayViewModel.refresh() }
                                        }
                                    )
                                }
                            }
                    }
                    .environment(tabRouter.router(for: tab))
                    .tabItem { tab.label }
                    .tag(tab)
                }
            }
            .toolbar(.hidden, for: .tabBar)

            if tabRouter.router(for: selectedTab).path.isEmpty {
                MoneySnapTabBar(selectedTab: $selectedTab) { tab in
                    if tab == .add {
                        showsRecordSource = true
                    } else {
                        selectedTab = tab
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 21)
                .transition(.opacity)
            }

            if presentsMenu {
                MoneySnapSidebar(
                    selectedTab: selectedTab,
                    onSelectTab: { tab in
                        presentsMenu = false
                        selectedTab = tab
                    },
                    onHelp: {
                        presentsMenu = false
                        presentedSheet = .help
                    },
                    onClose: { presentsMenu = false }
                )
            }

            if showsRecordSource {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .onTapGesture { showsRecordSource = false }
                    .transition(.opacity)
                recordSourceMenu
                    .padding(.bottom, 126)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: showsRecordSource)
        .background(Color.white.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .bottom)
        .sheet(item: $presentedSheet, onDismiss: presentPendingShare) { sheet in
            switch sheet {
            case .record:
                recordCaptureView
            case .help:
                HelpGuideView()
            case let .share(receipt):
                ShareAfterSaveView(
                    groups: shareGroups,
                    onShare: { groupID in
                        Task {
                            try? await groupClient.share(
                                snapID: receipt.id,
                                groupID: groupID,
                                mutationID: UUID().uuidString.lowercased()
                            )
                            presentedSheet = nil
                        }
                    },
                    onSkip: { presentedSheet = nil }
                )
            }
        }
        .fullScreenCover(isPresented: $showsCamera, onDismiss: finishCamera) {
            CameraPicker(
                onImage: { image in
                    capturedImage = image
                    showsCamera = false
                },
                onCancel: { showsCamera = false }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showsRecordInput, onDismiss: {
            activeRecordModel = nil
            presentPendingShare()
        }) {
            if let activeRecordModel {
                SnapCaptureView(model: activeRecordModel) { receipt, jpeg in
                    apply(receipt, previewJPEG: jpeg)
                }
            }
        }
        .onChange(of: photoItems) { _, items in
            Task { await loadPhotos(items) }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            if oldTab != .home && newTab == .home { homeDropGeneration += 1 }
        }
        .alert("사진을 열 수 없어요", isPresented: $showsPhotoError) {
            Button("확인") {}
        } message: {
            Text("다른 사진을 선택하거나 사진 없이 기록해 주세요.")
        }
        .task(id: selectedTab) {
            shareGroups = GroupCanvasOrder.apply((try? await groupClient.list().groups) ?? [])
        }
        .onAppear {
            if initialCaptureModel != nil {
                presentedSheet = .record
            }
        }
    }

    @ViewBuilder
    private func rootView(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            TodaySnapView(
                viewModel: todayViewModel,
                onRecord: { showsRecordSource = true },
                onOpen: { id in
                    tabRouter.router(for: .home).navigate(to: .snapDetail(id: id))
                },
                onMenu: { presentsMenu = true },
                groups: shareGroups,
                groupClient: groupClient,
                media: mediaClient,
                dropGeneration: homeDropGeneration,
                onRefresh: { homeDropGeneration += 1 }
            )
        case .group:
            GroupListView(client: groupClient)
        case .archive:
            ArchiveView(
                client: snapJournalClient,
                onMenu: { presentsMenu = true }
            ) { id in
                tabRouter.router(for: .archive).navigate(to: .snapDetail(id: id))
            }
        case .profile:
            MySettingsView(
                authentication: authentication,
                summaryClient: URLSessionAccountSummaryClient(
                    baseURL: URL(string: "https://moneysnap-server.ansandy.co.kr")!,
                    accessToken: { try await authentication.accessTokenForRequest() }
                ),
                groupClient: groupClient,
                onMenu: { presentsMenu = true }
            )
        default:
            PlaceholderView(
                title: tab.title,
                systemImage: tab.systemImage
            )
        }
    }

    private var recordSourceMenu: some View {
        HStack(alignment: .bottom, spacing: 14) {
            Button {
                activeRecordModel = makeCaptureModel()
                showsRecordSource = false
                showsCamera = true
            } label: {
                sourceVisual("촬영", symbol: "camera", dark: true)
            }
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            .accessibilityIdentifier("record.source.camera")
            .offset(y: 18)

            PhotosPicker(selection: $photoItems, maxSelectionCount: 3, matching: .images) {
                sourceVisual("앨범", symbol: "photo")
            }
            .accessibilityIdentifier("record.source.album")

            Button {
                let model = makeCaptureModel()
                model.skipPhotos()
                activeRecordModel = model
                showsRecordSource = false
                showsRecordInput = true
            } label: {
                sourceVisual("사진 없음", symbol: "arrow.right")
            }
            .accessibilityIdentifier("record.source.none")
            .offset(y: 18)
        }
        .buttonStyle(.plain)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    nonisolated private func sourceVisual(_ title: String, symbol: String, dark: Bool = false) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(dark ? Color.white : MoneySnapVisualSystem.ink)
                .frame(width: 60, height: 60)
                .background(dark ? MoneySnapVisualSystem.charcoal : Color.white, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 12, y: 10)
            Text(title)
                .font(.moneySnap(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 74, height: 96)
    }

    private func finishCamera() {
        defer { capturedImage = nil }
        guard let capturedImage else {
            activeRecordModel = nil
            showsRecordSource = true
            return
        }
        guard let jpeg = try? JpegNormalizer.normalize(capturedImage),
              let activeRecordModel else {
            activeRecordModel = nil
            showsRecordSource = true
            showsPhotoError = true
            return
        }
        activeRecordModel.attach([jpeg])
        showsRecordInput = true
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var photos: [NormalizedJpeg] = []
        for item in items.prefix(3) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = try? JpegNormalizer.normalize(image) else { continue }
            photos.append(jpeg)
        }
        guard !photos.isEmpty else {
            if !items.isEmpty { showsPhotoError = true }
            return
        }
        let model = makeCaptureModel()
        model.attach(photos)
        activeRecordModel = model
        photoItems = []
        showsRecordSource = false
        showsRecordInput = true
    }

    @ViewBuilder
    private var recordCaptureView: some View {
        SnapCaptureView(
            model: initialCaptureModel ?? makeCaptureModel(),
            onSaved: { receipt, jpeg in apply(receipt, previewJPEG: jpeg) }
        )
    }

    private func apply(_ receipt: SnapRecordReceipt, previewJPEG: Data? = nil) {
        _ = todayViewModel.apply(receipt, previewJPEG: previewJPEG)
        selectedTab = .home
        Task { await todayViewModel.refresh() }
        if !shareGroups.isEmpty {
            pendingShare = receipt
        }
    }

    private func presentPendingShare() {
        guard let pendingShare else { return }
        self.pendingShare = nil
        presentedSheet = .share(pendingShare)
    }

    private func makeCaptureModel() -> SnapCaptureModel {
        #if DEBUG
        if ProcessInfo.processInfo.environment["MONEYSNAP_FEATURE_SCENARIO"] != nil {
            return SnapCaptureModel(
                record: { try await snapJournalClient.record($0) },
                now: { Date(timeIntervalSince1970: 1_786_582_800) },
                timeZone: { TimeZone(identifier: "Asia/Seoul")! }
            )
        }
        #endif
        let journal = snapJournalClient
        let photoPublisher: (@Sendable (NormalizedJpeg) async throws -> UUID)?
        if let mediaClient {
            photoPublisher = { jpeg in try await mediaClient.publish(jpeg) }
        } else {
            photoPublisher = nil
        }
        return SnapCaptureModel(
            record: { command in try await journal.record(command) },
            allowsPhotos: true,
            publishPhoto: photoPublisher
        )
    }
}

private enum AppSheet: Identifiable {
    case record
    case help
    case share(SnapRecordReceipt)

    var id: String {
        switch self {
        case .record:
            "record"
        case .help:
            "help"
        case let .share(receipt):
            "share-\(receipt.id.uuidString)"
        }
    }
}

private struct ShareAfterSaveView: View {
    let groups: [MoneySnapGroup]
    let onShare: (UUID) -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            List(groups) { group in
                Button(group.name) { onShare(group.id) }
                    .frame(minWidth: 44, minHeight: 44)
            }
            .navigationTitle("그룹에 공유")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("건너뛰기", action: onSkip)
                        .accessibilityIdentifier("share.skip")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private extension AppTab {
    @ViewBuilder
    var label: some View {
        Label(title, systemImage: systemImage)
    }
}

#if DEBUG
#Preview {
    AppShellView(
        selectedTab: .constant(.home),
        authentication: VisualTestSupport.authenticatedModel(),
        snapJournalClient: VisualTestSupport.snapJournalClient
    )
}
#endif
