#!/bin/bash
# Samples whole-system power, GPU utilization, and CPU and memory of ScreenCrop and WindowServer.
# Usage: scripts/bench.sh [seconds] [label]
set -euo pipefail

seconds=${1:-60}
label=${2:-sample}
interval=2
samples=$((seconds / interval + 1))
topfile=$(mktemp)
trap '/bin/rm -f "$topfile"' EXIT

top -l "$samples" -s "$interval" -stats command,cpu,mem,power >"$topfile" &
toppid=$!

# SystemLoad is the battery controller's whole-system power in mW, on battery or on the charger.
watts=0 gpu=0 n=0
for _ in $(seq 2 "$samples"); do
    sleep "$interval"
    load=$(ioreg -rn AppleSmartBattery -w0 | grep -oE '"SystemLoad"=[0-9]+' | cut -d= -f2)
    util=$(ioreg -r -c IOAccelerator -d 1 -w0 | grep -oE '"Device Utilization %"=[0-9]+' | head -1 | cut -d= -f2)
    watts=$((watts + ${load:-0})) gpu=$((gpu + ${util:-0})) n=$((n + 1))
done
wait "$toppid"

printf "%-14s %-12s %8s %8s %8s\n" "$label" "item" "cpu%" "power" "mem"
printf "%-14s %-12s %8.1f %8s %8s\n" "$label" "system W" "$(echo "$watts / $n / 1000" | bc -l)" "" ""
printf "%-14s %-12s %8d %8s %8s\n" "$label" "gpu %" "$((gpu / n))" "" ""
# top's first sample has no CPU delta, so it is skipped.
awk -v label="$label" '
    /^Processes:/ { n++ }
    n > 1 && ($1 == "ScreenCrop" || $1 == "WindowServer") {
        cpu[$1] += $2; power[$1] += $4; count[$1]++; mem[$1] = $3
    }
    END {
        for (p in count)
            printf "%-14s %-12s %8.1f %8.1f %8s\n", label, p, cpu[p] / count[p], power[p] / count[p], mem[p]
    }' "$topfile"
