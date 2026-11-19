#!/usr/bin/env bash
# Live CPU/GPU power draw in watts, one "key value" pair per line.
# CPU: Intel RAPL energy counters (read via a narrowly scoped sudoers rule).
# GPU: nvidia-smi power.draw, or amdgpu hwmon power1_average as a fallback.

shopt -s nullglob

RAPL_PKG=/sys/class/powercap/intel-rapl:0/energy_uj
RAPL_CORE=/sys/class/powercap/intel-rapl:0:0/energy_uj
RAPL_RANGE=/sys/class/powercap/intel-rapl:0/max_energy_range_uj

read_uj() {
  local value
  if value=$(sudo -n cat "$1" 2>/dev/null) && [[ "$value" =~ ^[0-9]+$ ]]; then
    printf '%s' "$value"
  else
    return 1
  fi
}

# Microjoules over microseconds is watts. The RAPL counter wraps at
# max_energy_range_uj, so a negative delta means one wrap happened.
sample_uj() {
  local path=$1 first second start end delta span maximum
  first=$(read_uj "$path") || return 1
  start=$(date +%s%6N)
  sleep 1
  second=$(read_uj "$path") || return 1
  end=$(date +%s%6N)
  delta=$((second - first))
  if ((delta < 0)); then
    maximum=$(cat "$RAPL_RANGE" 2>/dev/null) || return 1
    delta=$((delta + maximum))
  fi
  span=$((end - start))
  ((span > 0)) || return 1
  awk -v d="$delta" -v t="$span" 'BEGIN { printf "%.1f\n", d / t }'
}

gpu_watts() {
  local value
  if command -v nvidia-smi >/dev/null 2>&1; then
    value=$(LC_ALL=C nvidia-smi --id=0 --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null | head -1)
    if [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      awk -v v="$value" 'BEGIN { printf "%.1f\n", v }'
      return 0
    fi
  fi
  for sensor in /sys/class/drm/card*/device/hwmon/hwmon*/power1_average; do
    [[ -r "$sensor" ]] || continue
    value=$(<"$sensor")
    [[ "$value" =~ ^[0-9]+$ ]] || continue
    awk -v v="$value" 'BEGIN { printf "%.1f\n", v / 1000000 }'
    return 0
  done
  return 1
}

for pair in "package $RAPL_PKG" "core $RAPL_CORE"; do
  set -- $pair
  if value=$(sample_uj "$2"); then
    printf '%s %s\n' "$1" "$value"
  fi
done

if value=$(gpu_watts); then
  printf 'gpu %s\n' "$value"
fi
