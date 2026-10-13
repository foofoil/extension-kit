import Foundation

/// 帧只通过 IOSurface 的数字 ID 共享，不传递 Swift/AppKit 对象。ID 随会话关闭失效，不能用于历史恢复。
public struct VideoPresentationSnapshot: Codable, Equatable, Sendable {
    public var surfaceID: UInt32
    public var width: Int
    public var height: Int
    public var revision: UInt64
    public init(surfaceID: UInt32, width: Int, height: Int, revision: UInt64) {
        self.surfaceID = surfaceID; self.width = width; self.height = height; self.revision = revision
    }
}
