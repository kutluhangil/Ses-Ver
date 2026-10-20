import AppIntents
import Foundation
#if !WIDGET_EXTENSION
import UIKit
#endif

// Spike (a), (b), (h) ortak niyetleri.
//
// [Kesin] `AudioPlaybackIntent` ve `LiveActivityIntent` niyetlerini sistem UYGULAMA sürecinde çalıştırır
// (widget/kontrol uzantısında değil). Kaynak: developer.apple.com/documentation/widgetkit/
// adding-interactivity-to-widgets-and-live-activities. Bu yüzden dosya hem uygulamaya hem kontrol
// uzantısına derlenir; uzantıda `perform()` gövdesi boştur (`WIDGET_EXTENSION` koşulu).
//
// [Kesin] `authenticationPolicy` varsayılanı `.alwaysAllowed`: niyet kilitliyken de çalışabilir.
// Kaynak: developer.apple.com/documentation/appintents/appintent/authenticationpolicy

/// Kilitliyken çalışması hedeflenen başlatma niyeti (Eylem Düğmesi, kontrol, Siri).
struct StartBeaconIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Sinyali başlat"
    static let description = IntentDescription("Ses Ver spike: işaret sesini başlatır.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    /// iOS 26+: uygulamayı öne getirmeden arka planda çalış (openAppWhenRun'ın yerini aldı).
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        try BeaconIntentRunner.start(source: "StartBeaconIntent/alwaysAllowed")
        #endif
        return .result()
    }
}

/// (b) karşılaştırması: kimlik doğrulama isteyen başlatma.
struct StartBeaconAuthIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Sinyali başlat (kimlik doğrulamalı)"
    static let description = IntentDescription("Ses Ver spike: requiresAuthentication varyantı.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        try BeaconIntentRunner.start(source: "StartBeaconAuthIntent/requiresAuthentication")
        #endif
        return .result()
    }
}

/// Spike durdurma niyeti. Ürün K7 (3 sn basılı tut) yalnızca uygulama içi; burada test kolaylığı için var.
struct StopBeaconIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Sinyali durdur"
    static let description = IntentDescription("Ses Ver spike: işaret sesini durdurur.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        SpikeLog.shared.log("intent_perform", [("intent", "StopBeaconIntent")] + SystemObservers.snapshot())
        ChirpEngine.shared.stop(reason: "StopBeaconIntent")
        #endif
        return .result()
    }
}

#if !WIDGET_EXTENSION
@MainActor
enum BeaconIntentRunner {
    static func start(source: String) throws {
        SystemObservers.install()
        let signpost = SpikeLog.shared.signposter.beginInterval("intent-perform")
        defer { SpikeLog.shared.signposter.endInterval("intent-perform", signpost) }
        // protectedData=false + appState=background → cihaz kilitliyken, uygulama açılmadan çalıştı kanıtı.
        SpikeLog.shared.log("intent_perform", [("intent", source)] + SystemObservers.snapshot())
        do {
            try ChirpEngine.shared.start(reason: source)
            Heartbeat.start()
        } catch {
            SpikeLog.shared.log("intent_engine_start_failed", [("intent", source), ("error", "\(error)")])
            throw error
        }
    }
}
#endif
