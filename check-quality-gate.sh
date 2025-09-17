#!/bin/bash
# Update values here
project_name="BrowserStack Cucumber TestNG"
build_name="azure-BrowserStack_Platform_SDK-CI-355"

# Read secrets from environment variables
username="$BROWSERSTACK_USERNAME"
access_key="$BROWSERSTACK_ACCESS_KEY"

max_attempts=20
build_tags="" # Optional

echo "[DEBUG] --- Initial Configuration ---"
echo "[DEBUG] Project Name: $project_name"
echo "[DEBUG] Build Name (from env): $build_name"
echo "[DEBUG] Username: $username"
echo "[DEBUG] Build Tags: $build_tags"
echo "[DEBUG] ---------------------------"

# Script Functions
# Function to sanitize project and build names
sanitize_name() {
    local name="$1"
    sanitized_name=$(echo "$name" | sed 's/ /%20/g')
    echo "$sanitized_name"
}

# Function to get the UUID of the latest build
get_latest_build_uuid() {
    local sanitized_project_name=$(sanitize_name "$project_name")
    local sanitized_build_name=$(sanitize_name "$build_name")
    local sanitized_build_tags=$(sanitize_name "$build_tags")

    echo "[DEBUG] Sanitized Project Name: $sanitized_project_name"
    echo "[DEBUG] Sanitized Build Name: $sanitized_build_name"

    local url="https://api-automation.browserstack.com/ext/v1/builds/latest?project_name=$sanitized_project_name&build_name=$sanitized_build_name&user_name=$username"
    if [ -n "$sanitized_build_tags" ]; then
        url="$url&build_tags=$sanitized_build_tags"
    fi

    echo "[DEBUG] Querying URL: $url"
    
    # Fetch the JSON response
    response=$(curl -s --retry 3 --connect-timeout 10 -u "$username:$access_key" "$url")
    
    echo "[DEBUG] Raw API Response for Build UUID: $response"

    # Use perl to strip ALL non-printable control characters that can break jq.
    local sanitized_response=$(echo "$response" | perl -pe 's/[^[:print:]]//g')
    
    # Use the corrected "sanitized_response" variable
    local build_uuid=$(echo "$sanitized_response" | jq -r '.build_id')
    echo "[DEBUG] Extracted Build UUID: $build_uuid"
    echo "$build_uuid"
}

# Function to hit Quality Gates API and get the result
get_quality_gate_result() {
    echo "[DEBUG] Checking Quality Gate for Build UUID: $build_uuid"
    local qg_url="https://api-automation.browserstack.com/ext/v1/quality-gates/$build_uuid"
    echo "[DEBUG] Querying Quality Gate URL: $qg_url"
    quality_gate_result=$(curl -s -H --retry 3 --connect-timeout 10 -u "$username:$access_key" "$qg_url")
    echo "[DEBUG] Raw Quality Gate Response: $quality_gate_result"
    echo "$quality_gate_result"
}

# Function to poll the API until the results of the Quality Gate are received
poll_quality_gate_api() {
    local attempt=0
    local max_time=600
    local total_time=0
    while [[ $attempt -lt $max_attempts ]] && [[ $total_time -lt max_time ]]; do
        echo "[DEBUG] Polling attempt #$((attempt + 1))..."
        quality_gate_result=$(get_quality_gate_result "$1" "$2" "$build_uuid")
        local result=$(echo "$quality_gate_result" | jq -r '.status')
        echo "[DEBUG] Current status is: '$result'"
        if [ "$result" != "running" ]; then
            echo "$quality_gate_result"
            exit 0
        fi
        sleep 30
        ((attempt++))
        total_time=$((attempt * 30))
    done
    echo "Timed out waiting for Quality Gate results"
    exit 1
}

# Function to assert the API response and throw pass/fail exit code
assert_quality_gate_result() {
    local result=$(echo "$quality_gate_result" | jq -r '.status')
    if [ "$result" == "passed" ]; then
        echo "Quality Gate passed"
        exit 0
    else
        echo "Quality Gate failed"
        exit 1
    fi
}

# --- Main Script Execution ---
build_uuid=$(get_latest_build_uuid)
if [ "$build_uuid" == "null" ] || [ -z "$build_uuid" ]; then
    echo "[ERROR] Failed to retrieve a valid Build UUID. Please check the project and build names in the logs above."
    exit 1
fi

sleep 20
quality_gate_result=$(poll_quality_gate_api)
echo "Final Quality Gate Result: $quality_gate_result"
assert_quality_gate_result
