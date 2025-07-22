
#!/bin/bash

# Check for file argument
if [ $# -ne 1 ]; then
  echo "Usage: $0 <log_file_path>"
  exit 1
fi

LOG_FILE="$1"

# Validate file exists
if [ ! -f "$LOG_FILE" ]; then
  echo "File not found: $LOG_FILE"
  exit 2
fi

# Variables
NOW=$(date +"%Y-%m-%d %H:%M:%S")
NOW_FILENAME=$(date +"%Y%m%d_%H%M%S")
FILE_SIZE_BYTES=$(stat -c%s "$LOG_FILE")
FILE_SIZE_MB=$(echo "scale=1; $FILE_SIZE_BYTES / (1024*1024)" | bc)

# Count messages
ERROR_COUNT=$(grep -c "ERROR" "$LOG_FILE")
WARNING_COUNT=$(grep -c "WARNING" "$LOG_FILE")
INFO_COUNT=$(grep -c "INFO" "$LOG_FILE")

# Top 5 error messages (excluding timestamp)
TOP_ERRORS=$(grep "ERROR" "$LOG_FILE" | sed -E 's/^[^]]*\] //' | sort | uniq -c | sort -nr | head -5)

# First and last error messages
FIRST_ERROR=$(grep "ERROR" "$LOG_FILE" | head -1)
LAST_ERROR=$(grep "ERROR" "$LOG_FILE" | tail -1)

# Error frequency by hour
declare -A hour_buckets

for hour in 00 04 08 12 16 20; do
  hour_buckets[$hour]=0
done

while IFS= read -r line; do
  if [[ "$line" =~ ERROR ]]; then
    ts=$(echo "$line" | grep -oE '\[([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2})' | cut -d' ' -f2)
    if [[ "$ts" ]]; then
      case $ts in
        00|01|02|03) ((hour_buckets[00]++)) ;;
        04|05|06|07) ((hour_buckets[04]++)) ;;
        08|09|10|11) ((hour_buckets[08]++)) ;;
        12|13|14|15) ((hour_buckets[12]++)) ;;
        16|17|18|19) ((hour_buckets[16]++)) ;;
        20|21|22|23) ((hour_buckets[20]++)) ;;
      esac
    fi
  fi
done < "$LOG_FILE"

# Output
REPORT="log_analysis_$NOW_FILENAME.txt"

{
echo "===== LOG FILE ANALYSIS REPORT ====="
echo "File: $LOG_FILE"
echo "Analyzed on: $NOW"
echo "Size: ${FILE_SIZE_MB}MB ($FILE_SIZE_BYTES bytes)"
echo
echo "MESSAGE COUNTS:"
echo "ERROR: $ERROR_COUNT messages"
echo "WARNING: $WARNING_COUNT messages"
echo "INFO: $INFO_COUNT messages"
echo
echo "TOP 5 ERROR MESSAGES:"
echo "$TOP_ERRORS" | sed 's/^/ /'
echo
echo "ERROR TIMELINE:"
echo "First error: $FIRST_ERROR"
echo "Last error:  $LAST_ERROR"
echo
echo "Error frequency by hour:"
for hour in 00 04 08 12 16 20; do
  count=${hour_buckets[$hour]}
  bar=$(printf "%*s" $((count / 2)) "" | tr ' ' '█')
  echo "$hour-$(printf "%02d" $((10#$hour + 4))): $bar ($count)"
done
echo
echo "Report saved to: $REPORT"
} | tee "$REPORT"
