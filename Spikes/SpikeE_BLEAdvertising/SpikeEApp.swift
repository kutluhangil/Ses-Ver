import CoreBluetooth
import SwiftUI

/// Spike (e): Arka planda BLE reklamı (kurban) ve başka bir iPhone'dan tespit (kurtarıcı).
/// Aynı uygulama iki cihaza kurulur; biri "Reklamcı", diğeri "Tarayıcı" rolünü seçer.
///
/// [Kesin] Arka planda yerel ad reklam edilmez ve tüm servis UUID'leri "overflow" alanına taşınır;
/// yalnızca o UUID'yi açıkça tarayan iOS cihazları görür. Kaynak: developer.apple.com/documentation/
/// corebluetooth/cbperipheralmanager/startadvertising(_:)
@main
struct SpikeEApp: App {
    init() {
        MainActor.assumeIsolated {
            SystemObservers.install()
            RunMarker.markLaunch()
        }
    }

    var body: some Scene {
        WindowGroup {
            SpikeHarnessView(title: "Spike E · BLE") {
                BLESection()
            }
        }
    }
}

enum BLEIDs {
    /// Spike'a özel servis UUID'si (ürün UUID'si DEĞİL).
    static var service: CBUUID { CBUUID(string: "5E5F0E10-5E5F-4E5F-9E5F-5E5F0E100001") }
    static var payload: CBUUID { CBUUID(string: "5E5F0E10-5E5F-4E5F-9E5F-5E5F0E100002") }
    static let restoreID = "sesver.spike.e.peripheral"
}

/// Kurban rolü. `bluetooth-peripheral` arka plan modu + durum geri yükleme.
@MainActor
final class Advertiser: NSObject, CBPeripheralManagerDelegate {
    static let shared = Advertiser()
    private var manager: CBPeripheralManager?
    private(set) var isAdvertising = false
    /// 32 bit örnek yük (signal-v0 W biçiminde, sabit). Bağlantıda GATT'tan okunur.
    private let word: UInt32 = 0x7F20_4A00

    func start() {
        if manager == nil {
            manager = CBPeripheralManager(delegate: self, queue: .main, options: [
                CBPeripheralManagerOptionRestoreIdentifierKey: BLEIDs.restoreID,
            ])
        } else {
            startAdvertisingIfReady()
        }
    }

    func stop() {
        manager?.stopAdvertising()
        isAdvertising = false
        SpikeLog.shared.log("ble_adv_stopped")
    }

    private func startAdvertisingIfReady() {
        guard let manager, manager.state == .poweredOn else { return }
        let ch = CBMutableCharacteristic(
            type: BLEIDs.payload, properties: [.read],
            value: withUnsafeBytes(of: word.bigEndian) { Data($0) }, permissions: [.readable])
        let svc = CBMutableService(type: BLEIDs.service, primary: true)
        svc.characteristics = [ch]
        manager.removeAllServices()
        manager.add(svc)
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BLEIDs.service],
            CBAdvertisementDataLocalNameKey: "SV-7F2",
        ])
    }

    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let state = peripheral.state.rawValue
        MainActor.assumeIsolated {
            SpikeLog.shared.log("ble_peripheral_state", [("state", "\(state)")])
            startAdvertisingIfReady()
        }
    }

    nonisolated func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        let err = error.map { "\($0)" } ?? "nil"
        MainActor.assumeIsolated {
            isAdvertising = (err == "nil")
            SpikeLog.shared.log("ble_adv_started", [("error", err)] + SystemObservers.snapshot())
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        let keys = dict.keys.sorted().joined(separator: ",")
        MainActor.assumeIsolated {
            SpikeLog.shared.log("ble_peripheral_restored", [("keys", keys)])
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        let central = request.central.identifier.uuidString
        MainActor.assumeIsolated {
            SpikeLog.shared.log("ble_read_request", [("central", central)] + SystemObservers.snapshot())
        }
    }
}

/// Kurtarıcı rolü (ön planda). Belirli servis UUID'sini tarar, RSSI'yi loglar, bağlanıp yükü okur.
@MainActor
final class Scanner: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = Scanner()
    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var firstSeen: [UUID: Date] = [:]
    private(set) var lastRSSI: [UUID: Int] = [:]
    private var readOnConnect = true

    func start(readPayload: Bool) {
        readOnConnect = readPayload
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else {
            scanIfReady()
        }
    }

    func stop() {
        central?.stopScan()
        SpikeLog.shared.log("ble_scan_stopped")
    }

    private func scanIfReady() {
        guard let central, central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: [BLEIDs.service], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
        ])
        SpikeLog.shared.log("ble_scan_started")
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state.rawValue
        MainActor.assumeIsolated {
            SpikeLog.shared.log("ble_central_state", [("state", "\(state)")])
            scanIfReady()
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        let id = peripheral.identifier
        let rssi = RSSI.intValue
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "-"
        let inMain = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.contains(BLEIDs.service) ?? false
        let inOverflow = (advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID])?.contains(BLEIDs.service) ?? false
        nonisolated(unsafe) let p = peripheral
        MainActor.assumeIsolated {
            lastRSSI[id] = rssi
            if firstSeen[id] == nil {
                firstSeen[id] = Date()
                peripherals[id] = p
                p.delegate = self
                SpikeLog.shared.log("ble_first_seen", [("id", id.uuidString), ("rssi", "\(rssi)"), ("name", name),
                                                       ("svcInMain", "\(inMain)"), ("svcInOverflow", "\(inOverflow)")])
                if readOnConnect { central.connect(p) }
            }
            // Her keşfi loglamak çok gürültülü; RSSI özetini kalp atışı yazar. Ad/alan değişimi yine loglanır.
            SpikeLog.shared.log("ble_seen", [("id", String(id.uuidString.prefix(8))), ("rssi", "\(rssi)"),
                                             ("name", name), ("main", "\(inMain)"), ("overflow", "\(inOverflow)")])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        nonisolated(unsafe) let p = peripheral
        MainActor.assumeIsolated {
            SpikeLog.shared.log("ble_connected", [("id", p.identifier.uuidString)])
            p.discoverServices([BLEIDs.service])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let err = error.map { "\($0)" } ?? "nil"
        MainActor.assumeIsolated { SpikeLog.shared.log("ble_connect_failed", [("error", err)]) }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        nonisolated(unsafe) let p = peripheral
        MainActor.assumeIsolated {
            guard let svc = p.services?.first(where: { $0.uuid == BLEIDs.service }) else { return }
            p.discoverCharacteristics([BLEIDs.payload], for: svc)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        nonisolated(unsafe) let p = peripheral
        nonisolated(unsafe) let s = service
        MainActor.assumeIsolated {
            guard let ch = s.characteristics?.first(where: { $0.uuid == BLEIDs.payload }) else { return }
            p.readValue(for: ch)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let hex = characteristic.value?.map { String(format: "%02X", $0) }.joined() ?? "nil"
        let id = peripheral.identifier.uuidString
        nonisolated(unsafe) let p = peripheral
        MainActor.assumeIsolated {
            SpikeLog.shared.log("ble_payload_read", [("id", id), ("hex", hex)])
            central?.cancelPeripheralConnection(p)
        }
    }
}

struct BLESection: View {
    @State private var readPayload = true

    var body: some View {
        Section("Reklamcı (kurban cihazı)") {
            Button("Reklamı başlat") { Advertiser.shared.start() }
            Button("Reklamı durdur") { Advertiser.shared.stop() }
            Text("Arka plan testi için ayrıca yukarıdan işaret sesini de başlatıp/başlatmadan deneyin (plan §e).")
                .font(.footnote)
        }
        Section("Tarayıcı (kurtarıcı cihazı, ön planda)") {
            Toggle("Bağlanıp yükü oku", isOn: $readPayload)
            Button("Taramayı başlat") { Scanner.shared.start(readPayload: readPayload) }
            Button("Taramayı durdur") { Scanner.shared.stop() }
        }
    }
}
