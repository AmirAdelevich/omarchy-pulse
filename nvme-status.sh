#!/usr/bin/env bash

shopt -s nullglob

read_value() {
  local value
  if IFS= read -r value 2>/dev/null < "$1"; then
    printf '%s' "${value//[[:cntrl:]]/ }"
  fi
}

for drive in /sys/class/nvme/nvme[0-9]*; do
  sensors=("$drive"/hwmon*/temp1_input)
  sensor=${sensors[0]%_input}
  temperature=
  warning=
  critical=
  alarm=
  if [[ -n "$sensor" ]]; then
    temperature=$(read_value "${sensor}_input")
    warning=$(read_value "${sensor}_max")
    critical=$(read_value "${sensor}_crit")
    alarm=$(read_value "${sensor}_alarm")
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${drive##*/}" \
    "$(read_value "$drive/model")" "$(read_value "$drive/state")" \
    "$temperature" "$warning" "$critical" "$alarm"
done
