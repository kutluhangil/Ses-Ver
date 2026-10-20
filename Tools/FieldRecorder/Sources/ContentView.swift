import SwiftUI

struct ContentView: View {
    @Bindable var recorder: RecorderController

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                Section("Oturum") {
                    field("Oturum (ör. S2)", $recorder.form.oturum)
                    field("Nokta (ör. P10)", $recorder.form.nokta)
                    field("Operatör", $recorder.form.operatorAdi)
                }
                Section("Verici") {
                    field("Model (ör. iPhone 13)", $recorder.form.model)
                    field("iOS (verici)", $recorder.form.ios, numeric: true)
                    field("Ses %", $recorder.form.sesYuzde, numeric: true)
                    Picker("Kılıf", selection: $recorder.form.kilif) {
                        ForEach(["yok", "silikon", "sert", "cüzdan"], id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented).frame(minHeight: 56)
                    Picker("Yönelim", selection: $recorder.form.yonelim) {
                        ForEach(["hoparlör yukarı", "ekran aşağı", "yan", "kutu içinde"], id: \.self) { Text($0).tag($0) }
                    }
                    .frame(minHeight: 56)
                    field("outputGain", $recorder.form.outputGain, numeric: true)
                }
                Section("Konum ve dinleyici") {
                    Picker("Moloz tipi", selection: $recorder.form.molozTipi) {
                        ForEach(["M1", "M2", "M3"], id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented).frame(minHeight: 56)
                    field("Derinlik (m)", $recorder.form.derinlikM, numeric: true)
                    field("Dinleyici yatay (m)", $recorder.form.dinleyiciYatayM, numeric: true)
                    field("Dinleyici yükseklik (m)", $recorder.form.dinleyiciYukseklikM, numeric: true)
                }
                Section("Ortam") {
                    field("Gürültü dB(A) LAeq 30 sn", $recorder.form.gurultuDBA, numeric: true)
                    field("Sıcaklık (°C)", $recorder.form.sicaklikC, numeric: true)
                    field("Not", $recorder.form.not)
                }
                Section("Dışa aktar") {
                    Text("Oturum \(recorder.form.oturum): \(recorder.sessionFiles.count) dosya")
                    if recorder.sessionFiles.isEmpty {
                        Text("Henüz dosya yok").foregroundStyle(.secondary)
                    } else {
                        ShareLink(items: recorder.sessionFiles) {
                            Label("Oturum dosyalarını paylaş (AirDrop / Dosyalar)", systemImage: "square.and.arrow.up")
                                .frame(minHeight: 56)
                        }
                    }
                }
            }
            .navigationTitle("SV Kayıt")
            .scrollDismissesKeyboard(.interactively)
            .disabled(recorder.isRecording)
            .safeAreaInset(edge: .bottom) { controls }
            .onChange(of: recorder.form.oturum) { recorder.refreshFiles() }
        }
    }

    private var statusSection: some View {
        Section {
            Text(recorder.status).font(.headline)
            if recorder.isRecording {
                Text(String(format: "%.1f sn", recorder.elapsed))
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
            }
            if !recorder.lastSaved.isEmpty { Text(recorder.lastSaved).font(.footnote.monospaced()) }
            ForEach(recorder.warnings, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Toggle("Kalibrasyon: 94 dB kalibratör tonu (10 sn)", isOn: $recorder.calibrationMode)
                .disabled(recorder.isRecording)
                .frame(minHeight: 56)
            Button(action: recorder.toggle) {
                Text(recorder.isRecording ? "DURDUR" : (recorder.calibrationMode ? "KALİBRASYON KAYDI" : "KAYDET"))
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, minHeight: 72)
            }
            .buttonStyle(.borderedProminent)
            .tint(recorder.isRecording ? .gray : .red)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.bar)
    }

    private func field(_ title: String, _ text: Binding<String>, numeric: Bool = false) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            TextField("", text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(numeric ? .numbersAndPunctuation : .default)
                .autocorrectionDisabled()
                .frame(maxWidth: 180)
        }
        .frame(minHeight: 56)
    }
}
