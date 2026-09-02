//  ContentSession.swift
//  FoofoilExtensionKit
//
//  Created by tolg on 2026/8/25.

import Foundation

public enum SessionPresentation: Codable, Equatable, Sendable {
    case text(titleKey: String, body: String)
    case unavailable(titleKey: String, messageKey: String)

    private enum CodingKeys: String, CodingKey { case kind, titleKey, body, messageKey }
    private enum Kind: String, Codable { case text, unavailable }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .text:
            self = .text(
                titleKey: try container.decode(String.self, forKey: .titleKey),
                body: try container.decode(String.self, forKey: .body)
            )
        case .unavailable:
            self = .unavailable(
                titleKey: try container.decode(String.self, forKey: .titleKey),
                messageKey: try container.decode(String.self, forKey: .messageKey)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let titleKey, let body):
            try container.encode(Kind.text, forKey: .kind)
            try container.encode(titleKey, forKey: .titleKey)
            try container.encode(body, forKey: .body)
        case .unavailable(let titleKey, let messageKey):
            try container.encode(Kind.unavailable, forKey: .kind)
            try container.encode(titleKey, forKey: .titleKey)
            try container.encode(messageKey, forKey: .messageKey)
        }
    }
}

public struct CommandDescriptor: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let titleLocalizationKey: String
    /// 设备名等外部动态值不走本地化；普通宿主 chrome 继续使用 localization key。
    public var displayTitle: String?
    /// 指向同一命令集合中的父命令；宿主据此构造原生子菜单。
    public var parentID: String?
    public var symbolName: String?
    public var keyEquivalent: String?
    public var modifierFlags: UInt
    public var isEnabled: Bool
    public var isChecked: Bool

    public init(
        id: String,
        titleLocalizationKey: String,
        displayTitle: String? = nil,
        parentID: String? = nil,
        symbolName: String? = nil,
        keyEquivalent: String? = nil,
        modifierFlags: UInt = 0,
        isEnabled: Bool = true,
        isChecked: Bool = false
    ) {
        self.id = id
        self.titleLocalizationKey = titleLocalizationKey
        self.displayTitle = displayTitle
        self.parentID = parentID
        self.symbolName = symbolName
        self.keyEquivalent = keyEquivalent
        self.modifierFlags = modifierFlags
        self.isEnabled = isEnabled
        self.isChecked = isChecked
    }
}

public struct NegotiatedCapability: Codable, Equatable, Sendable {
    public let declaration: ExtensionCapabilityDeclaration
    public var state: ExtensionCapabilityState
    public var failureMessage: String?

    public init(
        declaration: ExtensionCapabilityDeclaration,
        state: ExtensionCapabilityState,
        failureMessage: String? = nil
    ) {
        self.declaration = declaration
        self.state = state
        self.failureMessage = failureMessage
    }
}

public struct ContentSession: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let extensionID: String?
    public let providerID: String
    public let request: ContentRequest
    public var presentation: SessionPresentation
    public var capabilities: [NegotiatedCapability]
    public var commands: [CommandDescriptor]
    public var navigatorContributions: [NavigatorContribution]
    public var mediaPlayback: MediaPlaybackSnapshot?
    public var playbackQueue: MediaPlaybackQueueSnapshot?
    public var audioDeviceSelection: AudioDeviceSelectionSnapshot?
    public var stateReference: String?

    public init(
        id: UUID = UUID(),
        extensionID: String?,
        providerID: String,
        request: ContentRequest,
        presentation: SessionPresentation,
        capabilities: [NegotiatedCapability] = [],
        commands: [CommandDescriptor] = [],
        navigatorContributions: [NavigatorContribution] = [],
        mediaPlayback: MediaPlaybackSnapshot? = nil,
        playbackQueue: MediaPlaybackQueueSnapshot? = nil,
        audioDeviceSelection: AudioDeviceSelectionSnapshot? = nil,
        stateReference: String? = nil
    ) {
        self.id = id
        self.extensionID = extensionID
        self.providerID = providerID
        self.request = request
        self.presentation = presentation
        self.capabilities = capabilities
        self.commands = commands
        self.navigatorContributions = navigatorContributions
        self.mediaPlayback = mediaPlayback
        self.playbackQueue = playbackQueue
        self.audioDeviceSelection = audioDeviceSelection
        self.stateReference = stateReference
    }

    private enum CodingKeys: String, CodingKey {
        case id, extensionID, providerID, request, presentation, capabilities, commands
        case navigatorContributions, mediaPlayback, playbackQueue, audioDeviceSelection, stateReference
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        extensionID = try container.decodeIfPresent(String.self, forKey: .extensionID)
        providerID = try container.decode(String.self, forKey: .providerID)
        request = try container.decode(ContentRequest.self, forKey: .request)
        presentation = try container.decode(SessionPresentation.self, forKey: .presentation)
        capabilities = try container.decodeIfPresent([NegotiatedCapability].self, forKey: .capabilities) ?? []
        commands = try container.decodeIfPresent([CommandDescriptor].self, forKey: .commands) ?? []
        // Phase 0 早期 Session 没有导航贡献；缺失字段必须保持可恢复。
        navigatorContributions = try container.decodeIfPresent(
            [NavigatorContribution].self,
            forKey: .navigatorContributions
        ) ?? []
        mediaPlayback = try container.decodeIfPresent(MediaPlaybackSnapshot.self, forKey: .mediaPlayback)
        playbackQueue = try container.decodeIfPresent(MediaPlaybackQueueSnapshot.self, forKey: .playbackQueue)
        audioDeviceSelection = try container.decodeIfPresent(
            AudioDeviceSelectionSnapshot.self,
            forKey: .audioDeviceSelection
        )
        stateReference = try container.decodeIfPresent(String.self, forKey: .stateReference)
    }
}

public enum ContentProviderError: LocalizedError, Equatable {
    case unavailable(String)
    case unsupportedRequest
    case sessionCreationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let provider): "Provider unavailable: \(provider)"
        case .unsupportedRequest: "The provider does not support this request."
        case .sessionCreationFailed(let message): message
        }
    }
}
