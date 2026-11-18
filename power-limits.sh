#!/usr/bin/env bash

for zone in /sys/class/powercap/intel-rapl:[0-9]*; do
  [[ -r "$zone/name" ]] || continue
  [[ $(<"$zone/name") == package-* ]] || continue
  for name in "$zone"/constraint_*_name; do
    [[ -r "$name" ]] || continue
    case $(<"$name") in
      long_term) key=cpuLong ;;
      short_term) key=cpuShort ;;
      *) continue ;;
    esac
    limit=${name%_name}_power_limit_uw
    [[ -r "$limit" ]] && printf '%s %s\n' "$key" "$(<"$limit")"
  done
  break
done

if command -v nvidia-smi >/dev/null 2>&1; then
  LC_ALL=C nvidia-smi --id=0 --query-gpu=power.limit,power.default_limit --format=csv,noheader,nounits 2>/dev/null |
    awk -F, '{ if ($1+0>0) print "gpu", $1+0; else if ($2+0>0) print "gpuDefault", $2+0 }'
else
  for sensor in /sys/class/drm/card*/device/hwmon/hwmon*; do
    [[ -r "$sensor/name" && -r "$sensor/power1_cap" ]] || continue
    [[ $(<"$sensor/name") == amdgpu ]] || continue
    printf 'gpuMicrowatts %s\n' "$(<"$sensor/power1_cap")"
    break
  done
fi
