#!/bin/bash
# Update values here
project_name="BrowserStack Cucumber TestNG"  # Replace with your project name
build_name="$BROWSERSTACK_BUILD_NAME"  # Replace with your build name use $BROWSERSTACK_BUILD_NAME if you use the BrowserStack Jenkins Plugin

# Read secrets from environment variables
username="$BROWSERSTACK_USERNAME" 
access_key="$BROWSERSTACK_ACCESS_KEY" 

max_attempts=20 # Replace with your max retry attempt
build_tags="{Insert Value Here}" # Optional - Replace with custom build tags if any
# Script Functions - REFRAIN FROM MODIFYING THE SCRIPT BELOW 
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
# Fetch and sanitize the JSON response
if [ -n "$sanitized_build_tags" ]; then
  response=$(curl -s --retry 3 --connect-timeout 10 -u "$username:$access_key" "https://api-automation.browserstack.com/ext/v1/builds/latest?project_name=$sanitized_project_name&build_name=$sanitized_build_name&user_name=$username&build_tags=$sanitized_build_tags")
else
  response=$(curl -s --retry 3 --connect-timeout 10 -u "$username:$access_key" "https://api-automation.browserstack.com/ext/v1/builds/latest?project_name=$sanitized_project_name&build_name=$sanitized_build_name&user_name=$username")
fi
response=$(echo "$response" | perl -pe 's/([[:cntrl:]])/sprintf("\\x{%02X}", ord($1))/eg')
local build_uuid=$(echo "$response" | jq -r '.build_id')
echo "$build_uuid"
}
# Function to hit Quality Gates API and get the result
get_quality_gate_result() {
quality_gate_result=$(curl -s -H --retry 3 --connect-timeout 10 -u "$username:$access_key" https://api-automation.browserstack.com/ext/v1/quality-gates/$build_uuid)
echo "$quality_gate_result"
}
# Function to poll the API until the results of the Quality Gate are received
poll_quality_gate_api() {
local attempt=0
local max_time=600
local total_time=0
while [[ $attempt -lt $max_attempts ]] && [[ $total_time -lt max_time ]]; do
quality_gate_result=$(get_quality_gate_result "$1" "$2" "$build_uuid")
local result=$(echo "$quality_gate_result" | jq -r '.status')
if [ "$result" != "running" ]; then
echo "$quality_gate_result"
exit 0
fi
sleep 30 # Poll every 30 seconds
((attempt++))
total_time=$((attempt * 30))  # Total elapsed time in seconds
done
echo "Timed out waiting for Quality Gate results"
exit 1
}
# Function to assert the API response and throw pass/fail exit code
assert_quality_gate_result() {
local result=$(echo "$quality_gate_result" | jq -r '.status')
# Replace the condition below with the actual condition to determine pass/fail
if [ "$result" == "passed" ]; then
echo "Quality Gate passed"
exit 0
else
echo "Quality Gate failed"
exit 1
fi
}
# Quality Gates API Poll
build_uuid=\$(get_latest_build_uuid)
sleep 20
quality_gate_result=\$(poll_quality_gate_api)
echo "Quality Gate Result: \$quality_gate_result"
assert_quality_gate_result
