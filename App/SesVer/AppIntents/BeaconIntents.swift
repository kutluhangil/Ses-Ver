import AppIntents
import Foundation
import BeaconKit
import DeviceServices

public struct StartBeaconIntent: AudioPlaybackIntent {
    public static let title: LocalizedStringResource = "Sinyali Başlat"
    public static let description = IntentDescription("Enkaz altı akustik işaretini başlatır.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        let payload = PayloadV1(
            id: Int.random(in: 1..<0xFFF),
            people: 0,
            injured: 0,
            lifeAge: 0,
            battery: 3,
            mode: 0
        )
        try? AudioSessionCtl.shared.start(payload: payload)
        await NotificationChain.shared.scheduleChain()
        BLEAdvertiser.shared.start(payload: payload)
        return .result()
    }
}

public struct StopBeaconIntent: AppIntent {
    public static let title: LocalizedStringResource = "Sinyali Durdur"
    public static let description = IntentDescription("Akustik işareti durdurur.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        AudioSessionCtl.shared.stop()
        NotificationChain.shared.cancelChain()
        BLEAdvertiser.shared.stop()
        return .result()
    }
}
