#!/bin/bash
set -e

# Get current timestamp in Europe/Amsterdam timezone
timestamp=$(TZ="Europe/Amsterdam" date +%Y%m%d_%H%M%S)
echo "[INFO] Started Docker entrypoint at ${timestamp}"

# Function to send notifications to Slack if webhook URL is set
notify_slack() {
  if [ -n "$SLACK_WEBHOOK_URL" ]; then
    curl -s -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"$1\"}" \
      "$SLACK_WEBHOOK_URL" > /dev/null
  fi
}

# Trap errors and notify Slack if any command fails
trap 'notify_slack "❌ Simulation failed at ${timestamp}"' ERR

# Prepare working directory
mkdir -p /work && cd /work

# Download simulation script from GCS bucket
echo "[INFO] Downloading ${SCRIPT_FILE}..."
gsutil cp "${SCRIPT_BUCKET%/}/${SCRIPT_FILE}" "$SCRIPT_FILE"

# Run the simulation script using R
echo "[INFO] Running ${SCRIPT_FILE}..."
Rscript "$SCRIPT_FILE"

# Prepend timestamp column to each CSV result file
echo "[INFO] Prepending timestamp column to CSVs..."
awk -v ts="$timestamp" 'BEGIN{FS=OFS=","} NR==1{print "timestamp",$0} NR>1{print ts,$0}' "${RESULTS_FILE}" > "tmp_${RESULTS_FILE}"
mv "tmp_${RESULTS_FILE}" "${RESULTS_FILE}"

# Define file paths for GCS destinations
GCS_RESULTS_FILE="${RESULT_BUCKET%/}/${timestamp}_${RESULTS_FILE}"
GCS_LOG_FILE="${LOG_BUCKET%/}/${timestamp}_${LOG_FILE}"
GCS_SCRIPT_ARCHIVE="${SCRIPT_ARCHIVE_BUCKET%/}/${timestamp}_${SCRIPT_FILE}"

# Upload results and logs to Google Cloud Storage
echo "[INFO] Uploading results to GCS..."
gsutil cp "$RESULTS_FILE" "$GCS_RESULTS_FILE"
gsutil cp "$LOG_FILE" "$GCS_LOG_FILE"
gsutil cp "$SCRIPT_FILE" "$GCS_SCRIPT_ARCHIVE"

# Upload results to BigQuery tables
echo "[INFO] Uploading results to BigQuery..."
bq load --project_id="$PROJECT_ID" --source_format=CSV --skip_leading_rows=1 \
  --field_delimiter="," --replace=false \
  --schema="$BQ_TABLE_SCHEMA" \
  "${BQ_DATASET}.${BQ_TABLE}" "$RESULTS_FILE"

# Notify Slack of successful completion
notify_slack "✅ Simulation completed successfully at ${timestamp}"
echo "[INFO] All uploads completed successfully. Shutting down Docker entrypoint."
