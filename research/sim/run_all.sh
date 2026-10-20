#!/usr/bin/env bash
# F0-3 simülasyonunun tamamını sırayla yeniden üretir (depo kökünden çalıştırın).
#   bash research/sim/run_all.sh
set -euo pipefail
cd "$(dirname "$0")"
PY=../.venv/bin/python
start=$(date +%s)
$PY calibrate_threshold.py      # eşik kalibrasyonu (beyaz gürültü, 2 sa/durum)
$PY run_pd_fer.py               # Pd / FER eğrileri (200 deneme/nokta)
$PY run_gain.py                 # işleme kazancı ve 3 chirp birleştirme
$PY run_false_alarm.py          # yanlış alarm (beyaz, pembe, şantiye; 3 sa/durum)
$PY run_cpu.py                  # tek çekirdek CPU
$PY plot_report.py              # grafikler + results/summary.json
echo "toplam $(( $(date +%s) - start )) s"
