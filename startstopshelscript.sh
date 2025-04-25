#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Read parameters passed as environment variables from the pipeline task
# We expect ACTION and TARGET_SELECTION env vars to be set by the task's 'env:' block
PARAM_ACTION="$ACTION"
PARAM_TARGET_SELECTION="$TARGET_SELECTION"
# AWSREGION should be available automatically from pipeline variables or passed via env:
PARAM_AWS_REGION="$AWSREGION"

# Validate required environment variables were passed
if [ -z "$PARAM_ACTION" ] || [ -z "$PARAM_TARGET_SELECTION" ] || [ -z "$PARAM_AWS_REGION" ]; then
  echo "##[error]Required environment variables (ACTION, TARGET_SELECTION, AWSREGION) were not correctly passed to the script."
  echo "ACTION: $PARAM_ACTION"
  echo "TARGET_SELECTION: $PARAM_TARGET_SELECTION"
  echo "AWSREGION: $PARAM_AWS_REGION"
  exit 1
fi

echo "Script executing with Action: $PARAM_ACTION"
echo "Target Selection Key: $PARAM_TARGET_SELECTION"
echo "Target AWS Region: $PARAM_AWS_REGION"

# Determine the Variable Group variable name to look up based on the selection
# This logic assumes your Variable Group names follow the pattern:
# - 'AllServers_InstanceIds' for the 'AllServers' selection
# - '<Selection>_InstanceId' for specific server selections
if [ "$PARAM_TARGET_SELECTION" == "AllServers" ]; then
  VAR_NAME_TO_LOOKUP="AllServers_InstanceIds"
else
  VAR_NAME_TO_LOOKUP="${PARAM_TARGET_SELECTION}_InstanceId"
fi

# Convert the logical variable name to the expected environment variable name format
# Azure DevOps typically makes VG variables available as uppercase env vars
# It also replaces characters like '.' and '-' with '_'
# We assume our VG names are already like 'App1_WebServer01_InstanceId'
ENV_VAR_NAME=$(echo "$VAR_NAME_TO_LOOKUP" | tr '[:lower:]' '[:upper:]')

echo "Looking for environment variable: $ENV_VAR_NAME (derived from Variable Group)"

# Retrieve the instance IDs from the environment variable (populated by the Variable Group)
# Using printenv is a reliable way to get the value
TARGET_INSTANCE_IDS=$(printenv "$ENV_VAR_NAME")

# Validate if the instance IDs were found
if [ -z "$TARGET_INSTANCE_IDS" ]; then
  echo "##[error]Could not find Instance ID(s) in Variable Group variable '$ENV_VAR_NAME' for target selection '$PARAM_TARGET_SELECTION'. Please check the Variable Group and ensure the variable exists and matches the selection key."
  echo "Available environment variables (check for your expected variable):"
  printenv | sort # Print all env vars for debugging
  exit 1
fi

echo "Found Instance ID(s): $TARGET_INSTANCE_IDS"

# Construct and execute the AWS CLI command
echo "Executing: aws ec2 ${PARAM_ACTION}-instances --instance-ids ${TARGET_INSTANCE_IDS} --region ${PARAM_AWS_REGION}"

# The AWSShellScript task should handle AWS authentication context automatically
aws ec2 ${PARAM_ACTION}-instances --instance-ids ${TARGET_INSTANCE_IDS} --region ${PARAM_AWS_REGION}

echo "AWS CLI command executed successfully for action '$PARAM_ACTION' on '$PARAM_TARGET_SELECTION'."

