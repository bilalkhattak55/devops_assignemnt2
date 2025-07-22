#!/bin/bash

# Default refresh rate (seconds)
REFRESH=10
LOG_FILE="health_alerts.log"
FILTER="all"

# Color codes
RED="\e[91m"
YELLOW="\e[93m"
GREEN="\e[92m"
BLUE="\e[94m"
RESET="\e[0m"

trap "clear; exit" SIGINT

draw_bar() {
  local percent=$1
  local bar=""
  for ((i = 0; i < percent / 2; i++)); do
    bar+="█"
  done
  for ((i = percent / 2; i < 50; i++)); do
    bar+="░"
  done
  echo -n "$bar"
}

get_color_label() {
  local value=$1
  local warn=$2
  local crit=$3

  if (( value >= crit )); then
    echo -e "${RED}[CRITICAL]${RESET}"
  elif (( value >= warn )); then
    echo -e "${YELLOW}[WARNING]${RESET}"
  else
    echo -e "${GREEN}[OK]${RESET}"
  fi
}

while true; do
  clear
  HOST=$(hostname)
  DATE=$(date +"%Y-%m-%d %H:%M:%S")
  UPTIME=$(uptime -p)

  CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
  CPU_INT=${CPU_LOAD%.*}
  CPU_BAR=$(draw_bar $CPU_INT)
  CPU_STATUS=$(get_color_label $CPU_INT 60 80)
  TOP_CPU=$(ps -eo comm,%cpu --sort=-%cpu | head -4 | tail -n3)

  MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
  MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
  MEM_PERCENT=$((100 * MEM_USED / MEM_TOTAL))
  MEM_BAR=$(draw_bar $MEM_PERCENT)
  MEM_STATUS=$(get_color_label $MEM_PERCENT 60 80)
  MEM_FREE=$(free -m | awk '/Mem:/ {print $4}')
  MEM_BUFF=$(free -m | awk '/Mem:/ {print $6}')
  MEM_CACHE=$(free -m | awk '/Mem:/ {print $7}')

  DISK_DATA=$(df -h | grep -E '^/dev' | awk '{printf "%-8s %3d%% %s\n", $6, $5+0, $1}')
  
  NET_IN=$(cat /proc/net/dev | awk '/eth0/ {print $2}')
  NET_OUT=$(cat /proc/net/dev | awk '/eth0/ {print $10}')
  sleep 1
  NET_IN_2=$(cat /proc/net/dev | awk '/eth0/ {print $2}')
  NET_OUT_2=$(cat /proc/net/dev | awk '/eth0/ {print $10}')
  NET_IN_MB=$(((NET_IN_2 - NET_IN)/1024/1024))
  NET_OUT_MB=$(((NET_OUT_2 - NET_OUT)/1024/1024))

  # LOG anomalies
  TS=$(date +"%H:%M:%S")
  if (( CPU_INT > 80 )); then
    echo "[$TS] CPU usage exceeded 80% ($CPU_INT%)" >> $LOG_FILE
  fi
  if (( MEM_PERCENT > 75 )); then
    echo "[$TS] Memory usage exceeded 75% ($MEM_PERCENT%)" >> $LOG_FILE
  fi

  # HEADER
  echo -e "${BLUE}╔════════════ SYSTEM HEALTH MONITOR v1.0 ════════════╗  [R]efresh rate: ${REFRESH}s${RESET}"
  echo -e "║ Hostname: $HOST           Date: ${DATE} ║  [F]ilter: ${FILTER^}"
  echo -e "║ Uptime: $UPTIME                                 ║  [Q]uit"
  echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════╝${RESET}"
  echo

  # CPU
  if [[ $FILTER == "all" || $FILTER == "cpu" ]]; then
    echo -e "CPU USAGE: ${CPU_INT}% ${CPU_BAR} $CPU_STATUS"
    echo -e "  Process: $TOP_CPU"
    echo
  fi

  # Memory
  if [[ $FILTER == "all" || $FILTER == "mem" ]]; then
    echo -e "MEMORY: ${MEM_USED}MB/${MEM_TOTAL}MB (${MEM_PERCENT}%) ${MEM_BAR} $MEM_STATUS"
    echo -e "  Free: ${MEM_FREE}MB | Cache: ${MEM_CACHE}MB | Buffers: ${MEM_BUFF}MB"
    echo
  fi

  # Disk
  if [[ $FILTER == "all" || $FILTER == "disk" ]]; then
    echo -e "DISK USAGE:"
    while IFS= read -r line; do
      mount=$(echo $line | awk '{print $1}')
      usage=$(echo $line | awk '{print $2}')
      bar=$(draw_bar $usage)
      status=$(get_color_label $usage 70 85)
      echo -e "  $mount : ${usage}% ${bar} $status"
    done <<< "$DISK_DATA"
    echo
  fi

  # Network
  if [[ $FILTER == "all" || $FILTER == "net" ]]; then
    echo -e "NETWORK:"
    echo -e "  eth0 (in) : ${NET_IN_MB} MB/s $(draw_bar $((NET_IN_MB*5))) ${GREEN}[OK]${RESET}"
    echo -e "  eth0 (out): ${NET_OUT_MB} MB/s $(draw_bar $((NET_OUT_MB*5))) ${GREEN}[OK]${RESET}"
    echo
  fi

  # Load average
  echo -e "LOAD AVERAGE: $(uptime | awk -F'load average: ' '{print $2}')"
  echo
  echo "RECENT ALERTS:"
  tail -n 5 $LOG_FILE 2>/dev/null
  echo
  echo "Press 'h' for help, 'q' to quit, 'r' to change refresh rate, 'f' to filter"
  
  # Keyboard input
  read -t $REFRESH -n 1 key
  case $key in
    q) clear; exit ;;
    r)
      echo -ne "\nEnter new refresh rate (in seconds): "
      read new_rate
      REFRESH=$new_rate
      ;;
    f)
      echo -ne "\nFilter (all/cpu/mem/disk/net): "
      read new_filter
      FILTER=$new_filter
      ;;
    h)
      echo -e "\nCommands:\n  q - Quit\n  r - Change refresh rate\n  f - Filter by section"
      sleep 2
      ;;
  esac
done

