import Foundation
import Testing
import FoofoilExtensionABI
import FoofoilExtensionKit

struct ContractTests {
    private var currentArchitecture: String {
        ExtensionSystemRequirements.currentArchitecture
    }

    private func fixtureURL(_ name: String) throws -> URL {
        try #require(ExtensionKitResources.fixture(named: name))
    }

    @Test func validatesManifestFixtureAndNegotiatesHighestCommonAPI() throws {
        let url = try fixtureURL("TestExtensionManifest")
        let manifest = try ExtensionManifestValidator.decodeAndValidate(Data(contentsOf: url))

        #expect(manifest.id == "app.foofoil.extension.test")
        #expect(manifest.providers.map(\.id) == ["test.content", "test.audio-enhancer"])
        #expect(manifest.providers.last?.contentFamily == .audio)
        #expect(manifest.capabilities.map(\.id).contains(ExtensionCapabilityIdentifier.navigator))
        #expect(ExtensionAPI.negotiate(with: manifest.extensionAPI) == 1)

        let incompatibleURL = try fixtureURL("IncompatibleExtensionManifest")
        #expect(throws: ExtensionManifestError.incompatibleAPI) {
            try ExtensionManifestValidator.decodeAndValidate(Data(contentsOf: incompatibleURL))
        }
    }

    @Test func abiV1HeaderKeepsVersionedBoundary() {
        #expect(FOOFOIL_EXTENSION_API_V1 == ExtensionAPI.v1)
        #expect(MemoryLayout<FoofoilExtensionInterfaceV1>.size > MemoryLayout<UInt32>.size)
    }

    @Test func rejectsOverrideWithoutFallbackAndDuplicateCapability() {
        let invalidOverride = ExtensionManifest(
            id: "app.foofoil.extension.invalid",
            name: "Invalid",
            version: "1.0.0",
            extensionAPI: .init(min: 1, max: 1),
            system: .init(minMacOS: "15.0", architectures: [currentArchitecture]),
            providers: [
                .init(
                    id: "invalid.override",
                    role: .override,
                    contentTypes: [.init(extensions: ["mp3"], strategy: .fileExtension)]
                )
            ],
            capabilities: []
        )
        #expect(throws: ExtensionManifestError.invalidProvider("invalid.override")) {
            try ExtensionManifestValidator.validate(invalidOverride)
        }

        let duplicateCapability = ExtensionManifest(
            id: "app.foofoil.extension.invalid",
            name: "Invalid",
            version: "1.0.0",
            extensionAPI: .init(min: 1, max: 1),
            system: .init(minMacOS: "15.0", architectures: [currentArchitecture]),
            providers: [],
            capabilities: [
                .init(id: "ui.commands", scope: .presentation),
                .init(id: "ui.commands", scope: .presentation)
            ]
        )
        #expect(throws: ExtensionManifestError.duplicateCapability("ui.commands")) {
            try ExtensionManifestValidator.validate(duplicateCapability)
        }
    }

    @Test func contentRequestRoundTripsAllV1KindsAndBookmarks() throws {
        let bookmark = Data([1, 2, 3, 4])
        let first = ExtensionResource(url: URL(fileURLWithPath: "/tmp/one.foo"), securityScopedBookmark: bookmark)
        let second = ExtensionResource(url: URL(fileURLWithPath: "/tmp/two.foo"))
        let requests: [ContentRequest] = [
            .singleFile(first),
            .fileCollection([first, second]),
            .restoredSession(extensionID: "app.foofoil.extension.test", stateReference: "state-1")
        ]

        for request in requests {
            let encoded = try JSONEncoder().encode(request)
            #expect(try JSONDecoder().decode(ContentRequest.self, from: encoded) == request)
        }
    }

    @Test func capabilityNegotiationChecksContractScopeVersionAndDependencies() {
        let declarations: [ExtensionCapabilityDeclaration] = [
            .init(id: ExtensionCapabilityIdentifier.commandProvider, scope: .presentation),
            .init(id: ExtensionCapabilityIdentifier.navigator, scope: .presentation),
            .init(
                id: ExtensionCapabilityIdentifier.visualization,
                scope: .session,
                dependencies: [ExtensionCapabilityIdentifier.commandProvider]
            ),
            .init(id: ExtensionCapabilityIdentifier.audioEffects, contractVersion: 2, scope: .session),
            .init(id: "future.unknown", scope: .session)
        ]
        let result = CapabilityNegotiator.negotiate(declarations)

        #expect(result.accepted.map(\.declaration.id) == [
            ExtensionCapabilityIdentifier.commandProvider,
            ExtensionCapabilityIdentifier.navigator,
            ExtensionCapabilityIdentifier.visualization
        ])
        #expect(result.rejected.map(\.reason).contains(.unsupportedContractVersion))
        #expect(result.rejected.map(\.reason).contains(.unsupportedIdentifier))
    }

    @Test func navigatorContractRoundTripsAndRejectsInvalidHierarchyAndActions() throws {
        let contribution = NavigatorContribution(
            id: "document.outline",
            titleLocalizationKey: "Outline",
            style: .outline,
            items: [
                NavigatorItem(id: "chapter", title: "Chapter"),
                NavigatorItem(id: "section", parentID: "chapter", title: "Section")
            ],
            selectedItemIDs: ["section"],
            allowedActions: [.activate, .move],
            revision: 4
        )
        try NavigatorContributionValidator.validate(contribution)
        let decoded = try JSONDecoder().decode(
            NavigatorContribution.self,
            from: JSONEncoder().encode(contribution)
        )
        #expect(decoded == contribution)

        let action = NavigatorAction(
            contributionID: contribution.id,
            kind: .move,
            itemIDs: ["section"],
            movePosition: .end
        )
        try NavigatorContributionValidator.validate(action, in: contribution)
        #expect(try JSONDecoder().decode(NavigatorAction.self, from: JSONEncoder().encode(action)) == action)

        let missingParent = NavigatorContribution(
            id: "missing-parent",
            titleLocalizationKey: "Outline",
            style: .outline,
            items: [NavigatorItem(id: "child", parentID: "missing", title: "Child")]
        )
        #expect(throws: NavigatorContributionError.missingParent(itemID: "child", parentID: "missing")) {
            try NavigatorContributionValidator.validate(missingParent)
        }

        let cycle = NavigatorContribution(
            id: "cycle",
            titleLocalizationKey: "Outline",
            style: .outline,
            items: [
                NavigatorItem(id: "a", parentID: "b", title: "A"),
                NavigatorItem(id: "b", parentID: "a", title: "B")
            ]
        )
        #expect(throws: NavigatorContributionError.hierarchyCycle("a")) {
            try NavigatorContributionValidator.validate(cycle)
        }
    }

    @Test func contentSessionDecodesPreNavigatorPhaseZeroState() throws {
        let session = ContentSession(
            extensionID: "app.foofoil.extension.test",
            providerID: "test.content",
            request: .singleFile(.init(url: URL(fileURLWithPath: "/tmp/Test.foo"))),
            presentation: .text(titleKey: "Test Extension", body: "legacy")
        )
        let encoded = try JSONEncoder().encode(session)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "navigatorContributions")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(ContentSession.self, from: legacyData)
        #expect(decoded.navigatorContributions.isEmpty)
        #expect(decoded.providerID == session.providerID)
        #expect(decoded.mediaPlayback == nil)
    }
}
