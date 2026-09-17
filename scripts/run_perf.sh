#!/usr/bin/env bash
#
# run_perf.sh - run the directed testbenches with Icarus Verilog and print the
# performance counters (cycles, retired, load-use stalls, taken branches) plus
# the CPI for each test.
#
# Usage:  scripts/run_perf.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

RTL=(
  rtl/mips_pipeline.v
  rtl/pc.v
  rtl/control.v
  rtl/alu_control.v
  rtl/alu.v
  rtl/regfile.v
  rtl/sign_extend.v
  rtl/shift_left2.v
  rtl/hazard.v
  rtl/forward.v
)
TESTS=(tb_pipeline_cpu tb_branch_cpu tb_jal_cpu tb_isa_ext tb_bubble_sort tb_fibonacci)
OUT=/tmp/mips_perf
mkdir -p "$OUT"

printf '%-18s %8s %8s %8s %8s %6s\n' test cycles retired stalls taken CPI
printf '%-18s %8s %8s %8s %8s %6s\n' ------------------ -------- -------- ------ ----- ----
for tb in "${TESTS[@]}"; do
  iverilog -g2012 -o "$OUT/$tb.out" "sim/$tb.v" "${RTL[@]}"
  log=$(vvp "$OUT/$tb.out")

  status=$(grep -oE 'PASS|FAIL' <<<"$log" | head -1 || true)
  perf=$(grep -oE 'cycles=[0-9]+ retired=[0-9]+ load_use_stalls=[0-9]+ taken_branches=[0-9]+' <<<"$log" || true)

  if [[ -z "$perf" ]]; then
    printf '%-18s %s\n' "$tb" "(${status:-no result}; no counters)"
    continue
  fi

  cyc=${perf#cycles=};      cyc=${cyc%% *}
  ret=${perf#*retired=};    ret=${ret%% *}
  st=${perf#*load_use_stalls=}; st=${st%% *}
  tk=${perf#*taken_branches=};  tk=${tk%% *}
  cpi=$(awk -v c="$cyc" -v r="$ret" 'BEGIN { printf "%.2f", c / r }')

  printf '%-18s %8s %8s %8s %8s %6s  %s\n' "$tb" "$cyc" "$ret" "$st" "$tk" "$cpi" "$status"
done
