#!/usr/bin/env bash
set -uo pipefail

# Omarchy Doctor collector
# Output protocol: status<TAB>title<TAB>summary<TAB>suggested-command
# status is one of: ok warn bad info

emit() {
  local status="$1" title="$2" summary="$3" command="${4:-}"
  summary=${summary//$'\t'/ }
  summary=${summary//$'\n'/ }
  command=${command//$'\t'/ }
  command=${command//$'\n'/ }
  printf '%s\t%s\t%s\t%s\n' "$status" "$title" "$summary" "$command"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

check_failed_services() {
  if ! command_exists systemctl; then
    emit info "Services" "systemd tools are not available." ""
    return
  fi
  local failed count
  failed=$(systemctl --failed --no-legend --plain 2>/dev/null || true)
  if [[ -z "$failed" ]]; then
    emit ok "Services" "No failed systemd units." "systemctl --failed"
  else
    count=$(printf '%s\n' "$failed" | sed '/^[[:space:]]*$/d' | wc -l)
    emit bad "Services" "$count failed systemd unit(s) need attention." "systemctl --failed"
  fi
}

check_journal() {
  if ! command_exists journalctl; then
    emit info "Journal" "journalctl is not available." ""
    return
  fi
  local errors count
  errors=$(journalctl -p 3 -b --no-pager --output=short-monotonic -n 50 2>/dev/null || true)
  errors=$(printf '%s\n' "$errors" | grep -v '^-- No entries --$' || true)
  if [[ -z "$errors" ]]; then
    emit ok "Journal" "No priority 3 or higher errors found this boot." "journalctl -p 3 -b"
  else
    count=$(printf '%s\n' "$errors" | sed '/^[[:space:]]*$/d' | wc -l)
    if (( count >= 10 )); then
      emit bad "Journal" "$count high priority journal entries were found this boot." "journalctl -p 3 -b"
    else
      emit warn "Journal" "$count high priority journal entr$( (( count == 1 )) && printf 'y' || printf 'ies' ) found this boot." "journalctl -p 3 -b"
    fi
  fi
}

check_disk() {
  local line pct avail mount
  line=$(df -P / 2>/dev/null | tail -n 1 || true)
  if [[ -z "$line" ]]; then
    emit info "Storage" "Could not read root filesystem usage." "df -h /"
    return
  fi
  pct=$(awk '{gsub(/%/,"",$5); print $5}' <<<"$line")
  avail=$(df -hP / 2>/dev/null | tail -n 1 | awk '{print $4}')
  mount=$(awk '{print $6}' <<<"$line")
  if (( pct >= 95 )); then
    emit bad "Storage" "Root filesystem is ${pct}% full with ${avail} available." "df -h ${mount}"
  elif (( pct >= 85 )); then
    emit warn "Storage" "Root filesystem is ${pct}% full with ${avail} available." "df -h ${mount}"
  else
    emit ok "Storage" "Root filesystem is ${pct}% full with ${avail} available." "df -h ${mount}"
  fi
}

check_memory() {
  local total avail used_pct swap_total swap_free swap_used_pct
  total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
  avail=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
  if (( total > 0 )); then
    used_pct=$(( (total - avail) * 100 / total ))
  else
    used_pct=0
  fi
  swap_total=$(awk '/SwapTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
  swap_free=$(awk '/SwapFree:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
  swap_used_pct=0
  if (( swap_total > 0 )); then
    swap_used_pct=$(( (swap_total - swap_free) * 100 / swap_total ))
  fi
  if (( used_pct >= 92 || swap_used_pct >= 80 )); then
    emit warn "Memory" "Memory usage is ${used_pct}%; swap usage is ${swap_used_pct}%." "free -h"
  else
    emit ok "Memory" "Memory usage is ${used_pct}%; swap usage is ${swap_used_pct}%." "free -h"
  fi
}

check_temperature() {
  local max_temp raw
  max_temp=""
  if command_exists sensors; then
    raw=$(sensors 2>/dev/null || true)
    max_temp=$(printf '%s\n' "$raw" | grep -Eo '\+[0-9]+([.][0-9]+)?°C' | tr -d '+°C' | sort -nr | head -n1 || true)
  fi
  if [[ -z "$max_temp" ]]; then
    local f val c
    for f in /sys/class/thermal/thermal_zone*/temp; do
      [[ -r "$f" ]] || continue
      val=$(cat "$f" 2>/dev/null || true)
      [[ "$val" =~ ^[0-9]+$ ]] || continue
      c=$(( val / 1000 ))
      if [[ -z "$max_temp" || $c -gt ${max_temp%.*} ]]; then max_temp="$c"; fi
    done
  fi
  if [[ -z "$max_temp" ]]; then
    emit info "Temperature" "No readable hardware temperature sensor was found." "sensors"
    return
  fi
  local whole=${max_temp%.*}
  if (( whole >= 95 )); then
    emit bad "Temperature" "Highest reported temperature is ${max_temp}°C." "sensors"
  elif (( whole >= 85 )); then
    emit warn "Temperature" "Highest reported temperature is ${max_temp}°C." "sensors"
  else
    emit ok "Temperature" "Highest reported temperature is ${max_temp}°C." "sensors"
  fi
}

check_nvidia() {
  local has_nvidia=0
  if command_exists lspci && lspci 2>/dev/null | grep -qi 'NVIDIA'; then has_nvidia=1; fi
  if command_exists nvidia-smi; then
    local info temp util mem_used mem_total driver
    info=$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,driver_version --format=csv,noheader,nounits 2>/dev/null | head -n1 || true)
    if [[ -n "$info" ]]; then
      IFS=',' read -r temp util mem_used mem_total driver <<<"$info"
      temp=$(xargs <<<"$temp"); util=$(xargs <<<"$util"); mem_used=$(xargs <<<"$mem_used"); mem_total=$(xargs <<<"$mem_total"); driver=$(xargs <<<"$driver")
      if [[ "$temp" =~ ^[0-9]+$ ]] && (( temp >= 90 )); then
        emit bad "NVIDIA" "GPU ${temp}°C, ${util}% load, ${mem_used}/${mem_total} MiB VRAM, driver ${driver}." "nvidia-smi"
      elif [[ "$temp" =~ ^[0-9]+$ ]] && (( temp >= 82 )); then
        emit warn "NVIDIA" "GPU ${temp}°C, ${util}% load, ${mem_used}/${mem_total} MiB VRAM, driver ${driver}." "nvidia-smi"
      else
        emit ok "NVIDIA" "GPU ${temp}°C, ${util}% load, ${mem_used}/${mem_total} MiB VRAM, driver ${driver}." "nvidia-smi"
      fi
      return
    fi
  fi
  if (( has_nvidia )); then
    emit bad "NVIDIA" "NVIDIA hardware is present but nvidia-smi could not query the driver." "nvidia-smi"
  else
    emit info "NVIDIA" "No NVIDIA GPU detected." ""
  fi
}

check_battery() {
  local bat=""
  for candidate in /sys/class/power_supply/BAT*; do
    [[ -d "$candidate" ]] && { bat="$candidate"; break; }
  done
  if [[ -z "$bat" ]]; then
    emit info "Battery" "No laptop battery detected." ""
    return
  fi
  local capacity status health=""
  capacity=$(cat "$bat/capacity" 2>/dev/null || echo '?')
  status=$(cat "$bat/status" 2>/dev/null || echo 'Unknown')
  if [[ -r "$bat/energy_full" && -r "$bat/energy_full_design" ]]; then
    local full design
    full=$(cat "$bat/energy_full" 2>/dev/null || echo 0)
    design=$(cat "$bat/energy_full_design" 2>/dev/null || echo 0)
    if (( design > 0 )); then health=$(( full * 100 / design )); fi
  elif [[ -r "$bat/charge_full" && -r "$bat/charge_full_design" ]]; then
    local full design
    full=$(cat "$bat/charge_full" 2>/dev/null || echo 0)
    design=$(cat "$bat/charge_full_design" 2>/dev/null || echo 0)
    if (( design > 0 )); then health=$(( full * 100 / design )); fi
  fi
  local msg="Battery is ${capacity}% and ${status}."
  [[ -n "$health" ]] && msg+=" Estimated health is ${health}% of design capacity."
  if [[ -n "$health" && $health -lt 60 ]]; then
    emit warn "Battery" "$msg" "upower -i $(upower -e 2>/dev/null | grep BAT | head -n1)"
  else
    emit ok "Battery" "$msg" "upower -d"
  fi
}

check_network() {
  local default_route dns_ok
  default_route=$(ip route show default 2>/dev/null | head -n1 || true)
  if [[ -z "$default_route" ]]; then
    emit bad "Network" "No default network route is configured." "ip route"
    return
  fi
  dns_ok=0
  if command_exists getent && getent ahostsv4 example.com >/dev/null 2>&1; then dns_ok=1; fi
  if (( dns_ok )); then
    local iface
    iface=$(awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' <<<"$default_route")
    emit ok "Network" "Default route is active${iface:+ on $iface}; DNS resolution works." "ip route; resolvectl status"
  else
    emit warn "Network" "A default route exists, but DNS resolution failed." "resolvectl status"
  fi
}

check_packages() {
  if ! command_exists pacman; then
    emit info "Packages" "pacman was not found, so Arch package health was skipped." ""
    return
  fi
  local bad_count orphans
  bad_count=$(pacman -Qk 2>/dev/null | grep -vc '0 missing files' || true)
  orphans=$(pacman -Qtdq 2>/dev/null | wc -l || true)
  if (( bad_count > 0 )); then
    emit warn "Packages" "$bad_count installed package(s) report missing files; $orphans orphan package(s) found." "pacman -Qk; pacman -Qtdq"
  elif (( orphans > 25 )); then
    emit warn "Packages" "Package files look intact; $orphans orphan package(s) are installed." "pacman -Qtdq"
  else
    emit ok "Packages" "Package files look intact; $orphans orphan package(s) found." "pacman -Qk"
  fi
}

check_storage_health() {
  if ! command_exists smartctl; then
    emit info "Drive health" "smartctl is not installed, so SMART health was skipped." "sudo pacman -S smartmontools"
    return
  fi
  local dev result
  dev=$(lsblk -dnpo NAME,TYPE 2>/dev/null | awk '$2=="disk" {print $1; exit}')
  if [[ -z "$dev" ]]; then
    emit info "Drive health" "No physical disk was found for a SMART check." "lsblk"
    return
  fi
  result=$(smartctl -H "$dev" 2>/dev/null | grep -Ei 'overall-health|SMART Health Status' | tail -n1 || true)
  if grep -Eqi 'PASSED|OK' <<<"$result"; then
    emit ok "Drive health" "SMART reports the primary disk as healthy." "sudo smartctl -a $dev"
  elif [[ -n "$result" ]]; then
    emit bad "Drive health" "SMART did not report a clean health result for $dev." "sudo smartctl -a $dev"
  else
    emit info "Drive health" "SMART data for $dev requires additional permission or is unavailable." "sudo smartctl -a $dev"
  fi
}

check_audio() {
  if command_exists wpctl; then
    local status
    status=$(wpctl status 2>/dev/null || true)
    if [[ -n "$status" ]]; then
      emit ok "Audio" "PipeWire and WirePlumber are responding." "wpctl status"
    else
      emit warn "Audio" "wpctl is installed but did not return a PipeWire status." "systemctl --user status pipewire wireplumber"
    fi
  elif command_exists pactl && pactl info >/dev/null 2>&1; then
    emit ok "Audio" "The PulseAudio compatible audio server is responding." "pactl info"
  else
    emit warn "Audio" "No responding PipeWire or PulseAudio control interface was found." "systemctl --user status pipewire wireplumber"
  fi
}

check_bluetooth() {
  if ! command_exists bluetoothctl; then
    emit info "Bluetooth" "bluetoothctl is not installed." ""
    return
  fi
  local show
  show=$(bluetoothctl show 2>/dev/null || true)
  if [[ -z "$show" ]]; then
    emit info "Bluetooth" "No Bluetooth controller is currently available." "bluetoothctl show"
  elif grep -q 'Powered: yes' <<<"$show"; then
    emit ok "Bluetooth" "Bluetooth controller is present and powered on." "bluetoothctl show"
  else
    emit info "Bluetooth" "Bluetooth controller is present but powered off." "bluetoothctl show"
  fi
}

check_wifi() {
  if command_exists nmcli; then
    local state
    state=$(nmcli -t -f WIFI general 2>/dev/null | head -n1 || true)
    if [[ "$state" == "enabled" ]]; then
      emit ok "WiFi" "NetworkManager reports WiFi enabled." "nmcli device status"
    elif [[ "$state" == "disabled" ]]; then
      emit info "WiFi" "NetworkManager reports WiFi disabled." "nmcli radio wifi"
    else
      emit info "WiFi" "WiFi state could not be determined from NetworkManager." "nmcli device status"
    fi
  else
    emit info "WiFi" "NetworkManager CLI is not available." "ip link"
  fi
}

check_crashes() {
  if ! command_exists coredumpctl; then
    emit info "Crashes" "coredumpctl is not available." ""
    return
  fi
  local count
  count=$(coredumpctl --since today --no-pager --no-legend 2>/dev/null | sed '/^[[:space:]]*$/d' | wc -l || true)
  if (( count >= 5 )); then
    emit bad "Crashes" "$count core dump(s) were recorded since midnight." "coredumpctl --since today"
  elif (( count > 0 )); then
    emit warn "Crashes" "$count core dump(s) were recorded since midnight." "coredumpctl --since today"
  else
    emit ok "Crashes" "No core dumps recorded since midnight." "coredumpctl --since today"
  fi
}

check_shell() {
  local shell_errors=""
  if command_exists journalctl; then
    shell_errors=$(journalctl --user -b --no-pager -n 300 2>/dev/null | grep -Ei 'omarchy-shell|quickshell' | grep -Ei 'error|failed|warning|qml' | tail -n 30 || true)
  fi
  if [[ -n "$shell_errors" ]]; then
    local count
    count=$(printf '%s\n' "$shell_errors" | wc -l)
    emit warn "Omarchy shell" "$count recent Omarchy or Quickshell warning/error line(s) found in the user journal." "journalctl --user -b | grep -Ei 'omarchy-shell|quickshell'"
  else
    emit ok "Omarchy shell" "No recent Omarchy or Quickshell errors found in the user journal." "journalctl --user -b | grep -Ei 'omarchy-shell|quickshell'"
  fi
}

check_failed_services
check_journal
check_disk
check_memory
check_temperature
check_nvidia
check_battery
check_network
check_packages
check_storage_health
check_audio
check_bluetooth
check_wifi
check_crashes
check_shell
