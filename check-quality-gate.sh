#!/bin/bash
# Update values here
project_name="BrowserStack Cucumber TestNG"
build_name="$BROWSERSTACK_BUILD_NAME"

# Read secrets from environment variables
username="$BROWSERSTACK_USERNAME"
access_key="$BROWSERSTACK_ACCESS_KEY"

max_attempts=20
build_tags=""

# --- Print initial config to stderr ---
echo "[DEBUG] --- Initial Configuration ---" >&2
echo "[DEBUG] Project Name: $project_name" >&2
echo "[DEBUG] Build Name (from env): $build_name" >&2
echo "[DEBUG] Username: $username" >&2
echo "[DEBUG] Build Tags: $build_tags" >&2
echo "[DEBUG] ---------------------------" >&2

# Script Functions
sanitize_name() {
    local name="$1"
    echo "$name" | sed 's/ /%20/g'
}

get_latest_build_uuid() {
    local sanitized_project_name=$(sanitize_name "$project_name")
    local sanitized_build_name=$(sanitize_name "$build_name")

    echo "[DEBUG] Sanitized Project Name: $sanitized_project_name" >&2
    echo "[DEBUG] Sanitized Build Name: $sanitized_build_name" >&2

    # REMOVED user_name parameter for a more reliable query
    local url="https://api-automation.browserstack.com/ext/v1/builds/latest?project_name=$sanitized_project_name&build_name=$sanitized_build_name"
    echo "[DEBUG] Querying URL: $url" >&2
    
    # Fetch the JSON response. This goes to stdout.
    curl -s --retry 3 --connect-timeout 10 -u "$username:$access_key" "$url"
}

get_quality_gate_result() {
    echo "[DEBUG] Checking Quality Gate for Build UUID: $build_uuid" >&2
    local qg_url="https://api-automation.browserstack.com/ext/v1/quality-gates/$build_uuid"
    echo "[DEBUG] Querying Quality Gate URL: $qg_url" >&2
    
    # Fetch the JSON response. This goes to stdout.
    curl -s -H --retry 3 --connect-timeout 10 -u "$username:$access_key" "$qg_url"
}

# --- Main Script Execution ---
build_uuid_json=$(get_latest_build_uuid)
echo "[DEBUG] Raw API Response for Build UUID: $build_uuid_json" >&2

sanitized_response=$(echo "$build_uuid_json" | perl -pe 's/[^[:print:]\n]//g')
build_uuid=$(echo "$sanitized_response" | jq -r '.build_id')
echo "[DEBUG] Extracted Build UUID: $build_uuid" >&2

if [ "$build_uuid" == "null" ] || [ -z "$build_uuid" ]; then
    echo "[ERROR] Failed to retrieve a valid Build UUID. Check API response above." >&2
    exit 1
fi

sleep 20

# Polling loop
attempt=0
while [[ $attempt -lt $max_attempts ]]; do
    echo "[DEBUG] Polling attempt #$((attempt + 1))..." >&2
    quality_gate_result_json=$(get_quality_gate_result)
    echo "[DEBUG] Raw Quality Gate Response: $quality_gate_result_json" >&2
    
    result=$(echo "$quality_gate_result_json" | jq -r '.status')
    echo "[DEBUG] Current status is: '$result'" >&2
    
    if [ "$result" != "running" ]; then
        break
    fi
    sleep 30
    ((attempt++))
done

echo "Final Quality Gate Result: $quality_gate_result_json"

if [ "$result" == "passed" ]; then
    echo "Quality Gate passed" >&2
    exit 0
else
    echo "Quality Gate failed" >&2
    exit 1
fi
