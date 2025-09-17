#!/bin/bash
# Update values here
project_name="BrowserStack Cucumber TestNG"
build_name="azure-BrowserStack_Platform_SDK-CI-355"

# Read secrets from environment variables
username="$BROWSERSTACK_USERNAME"
access_key="$BROWSERSTACK_ACCESS_KEY"

max_attempts=20
build_tags="" # Optional

# --- Redirect debug logs to stderr to avoid corrupting JSON variables ---
exec 3>&1 # Save original stdout
exec 1>&2 # Redirect stdout to stderr for debug logs

echo "[DEBUG] --- Initial Configuration ---"
echo "[DEBUG] Project Name: $project_name"
echo "[DEBUG] Build Name (from env): $build_name"
echo "[DEBUG] Username: $username"
echo "[DEBUG] Build Tags: $build_tags"
echo "[DEBUG] ---------------------------"

# Script Functions
sanitize_name() {
    local name="$1"
    sanitized_name=$(echo "$name" | sed 's/ /%20/g')
    echo "$sanitized_name"
}

get_latest_build_uuid() {
    local sanitized_project_name=$(sanitize_name "$project_name")
    local sanitized_build_name=$(sanitize_name "$build_name")

    echo "[DEBUG] Sanitized Project Name: $sanitized_project_name"
    echo "[DEBUG] Sanitized Build Name: $sanitized_build_name"

    # REMOVED user_name parameter for a more reliable query
    local url="https://api-automation.browserstack.com/ext/v1/builds/latest?project_name=$sanitized_project_name&build_name=$sanitized_build_name"

    echo "[DEBUG] Querying URL: $url"
    
    # Fetch the JSON response and send it to the original stdout
    response=$(curl -s --retry 3 --connect-timeout 10 -u "$username:$access_key" "$url")
    echo "$response" >&3
}

get_quality_gate_result() {
    echo "[DEBUG] Checking Quality Gate for Build UUID: $build_uuid"
    local qg_url="https://api-automation.browserstack.com/ext/v1/quality-gates/$build_uuid"
    echo "[DEBUG] Querying Quality Gate URL: $qg_url"

    # Fetch the JSON response and send it to the original stdout
    quality_gate_result=$(curl -s -H --retry 3 --connect-timeout 10 -u "$username:$access_key" "$qg_url")
    echo "$quality_gate_result" >&3
}

# --- Main Script Execution ---

# Restore stdout for the main logic
exec 1>&3

build_uuid_json=$(get_latest_build_uuid)
echo "[DEBUG] Raw API Response for Build UUID: $build_uuid_json"
sanitized_response=$(echo "$build_uuid_json" | perl -pe 's/[^[:print:]]//g')
build_uuid=$(echo "$sanitized_response" | jq -r '.build_id')
echo "[DEBUG] Extracted Build UUID: $build_uuid"

if [ "$build_uuid" == "null" ] || [ -z "$build_uuid" ]; then
    echo "[ERROR] Failed to retrieve a valid Build UUID. Please check the project and build names in the logs above." >&2
    exit 1
fi

sleep 20

# Polling loop
attempt=0
while [[ $attempt -lt $max_attempts ]]; do
    echo "[DEBUG] Polling attempt #$((attempt + 1))..." >&2
    quality_gate_result_json=$(get_quality_gate_result)
    result=$(echo "$quality_gate_result_json" | jq -r '.status')
    echo "[DEBUG] Current status is: '$result'" >&2
    if [ "$result" != "running" ]; then
        break
    fi
    sleep 30
    ((attempt++))
done

if [ "$result" != "passed" ]; then
    echo "Final Quality Gate Result: $quality_gate_result_json"
    echo "Quality Gate failed" >&2
    exit 1
else
    echo "Final Quality Gate Result: $quality_gate_result_json"
    echo "Quality Gate passed" >&2
    exit 0
fi
