import Foundation
import CoreBluetooth
import BeaconKit

public enum SesVerBLE: Sendable {
    public static var serviceUUID: CBUUID { CBUUID(string: "A6E00001-5E50-4E10-9E10-5E5056455201") }
    public static var payloadCharUUID: CBUUID { CBUUID(string: "A6E00002-5E50-4E10-9E10-5E5056455201") }
}

@MainActor
public final class BLEAdvertiser: NSObject, ObservableObject, @preconcurrency CBPeripheralManagerDelegate {
    public static let shared = BLEAdvertiser()

    @Published public private(set) var isAdvertising: Bool = false
    private var peripheralManager: CBPeripheralManager?
    private var currentPayload: PayloadV1?

    private override init() {
        super.init()
    }

    public func start(payload: PayloadV1) {
        self.currentPayload = payload
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
        } else if peripheralManager?.state == .poweredOn {
            advertise()
        }
    }

    public func stop() {
        peripheralManager?.stopAdvertising()
        isAdvertising = false
    }

    private func advertise() {
        guard let pm = peripheralManager, pm.state == .poweredOn else { return }

        let char = CBMutableCharacteristic(
            type: SesVerBLE.payloadCharUUID,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
        let service = CBMutableService(type: SesVerBLE.serviceUUID, primary: true)
        service.characteristics = [char]
        pm.removeAllServices()
        pm.add(service)

        pm.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [SesVerBLE.serviceUUID],
            CBAdvertisementDataLocalNameKey: "SV-\(String(format: "%03X", currentPayload?.id ?? 0))"
        ])
        isAdvertising = true
    }

    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn && currentPayload != nil {
            advertise()
        } else {
            isAdvertising = false
        }
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == SesVerBLE.payloadCharUUID {
            if let payload = currentPayload {
                var val = UInt32(payload.packed24).bigEndian
                request.value = Data(bytes: &val, count: 4)
                peripheral.respond(to: request, withResult: .success)
            } else {
                peripheral.respond(to: request, withResult: .attributeNotFound)
            }
        }
    }
}
