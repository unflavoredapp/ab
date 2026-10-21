import CoreGraphics

/// Shared movement tuning and geometry constants for AIRBLADE's third-person controller.
/// These values are expressed in the existing tactical map's world units.
enum AirbladePhysics {
    static let playerRadius: CGFloat = 14
    static let playerHeight: CGFloat = 78

    static let gravity: CGFloat = 720
    static let jumpImpulse: CGFloat = 250
    static let wallJumpImpulse: CGFloat = 290

    static let maxWallRunDuration: CGFloat = 1.1
    static let wallRunSpeed: CGFloat = 240
    static let wallProbeDistance: CGFloat = 26
    static let wallContactDistance: CGFloat = 25
    static let wallRunVerticalDamping: CGFloat = 0.9
    static let wallRunLift: CGFloat = 6

    static let wallJumpLockout: CGFloat = 0.35
    static let wallJumpDashDuration: CGFloat = 0.22
    static let wallJumpGrace: CGFloat = 0.25
}
