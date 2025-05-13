#!/usr/bin/env bash
set -xe

# Set arguments
TARGET_STACK_SET_NAME=$1 # The name of the target CloudFormation StackSet
PRIMARY_REGION=$2        # The primary region to execute commands against
START_FROM_STACK=81      # Starting from stack 81
SOURCE_ARNS_FILE="./artifacts/AWS-Landing-Zone-Baseline-MaintanceWindowCreation/source_stack_set_instance_arns.txt"

# Validate required arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <target-stack-set-name> <primary-region>"
    echo "Example: $0 my-target-stackset us-east-1"
    exit 1
fi

# Check if source ARNs file exists
if [ ! -f "$SOURCE_ARNS_FILE" ]; then
    echo "Error: Source ARNs file not found at $SOURCE_ARNS_FILE"
    exit 1
fi

# Function to import stacks in batches
import_stacks_in_batches() {
    local stack_arns=($1)    # Convert space-separated string to array
    local start_position=$2
    local batch_size=10
    local total_stacks=${#stack_arns[@]}
    local batches=$(( (total_stacks + batch_size - 1) / batch_size ))
    
    # Calculate starting batch
    local start_batch=$(( (start_position - 1) / batch_size ))
    local start_index=$(( (start_batch * batch_size) ))
    
    printf "Total stacks to import: %s\n" "$total_stacks"
    printf "Starting from stack number: %s (batch %s)\n" "$start_position" "$((start_batch + 1))"
    printf "Will process %s remaining batches\n" "$((batches - start_batch))"
    
    for ((i = start_index; i < total_stacks; i += batch_size)); do
        local batch_arns=()
        
        # Get next batch of ARNs (up to 10)
        for ((j = i; j < i + batch_size && j < total_stacks; j++)); do
            batch_arns+=("${stack_arns[j]}")
        done
        
        printf "Processing batch %s of %s (stacks %s to %s)\n" \
            "$(((i/batch_size)+1))" "$batches" "$((i+1))" "$((i+${#batch_arns[@]}))"
        
        # Convert array to space-separated string for AWS CLI
        local batch_arns_string="${batch_arns[*]}"
        
        # Import batch of stacks
        IMPORT_OPERATION=$(aws cloudformation import-stacks-to-stack-set \
            --stack-set-name "$TARGET_STACK_SET_NAME" \
            --stack-ids $batch_arns_string \
            --region "$PRIMARY_REGION")
        
        IMPORT_OPERATION_ID=$(echo "$IMPORT_OPERATION" | jq -r '.OperationId')
        printf 'Operation ID: %s \n' "$IMPORT_OPERATION_ID"
        
        # Wait for import operation to complete
        while [[ "$(aws cloudformation describe-stack-set-operation \
            --stack-set-name "$TARGET_STACK_SET_NAME" \
            --operation-id "$IMPORT_OPERATION_ID" \
            --region "$PRIMARY_REGION" | \
            jq -r '.StackSetOperation | .Status')" != "FAILED" && \
            "$(aws cloudformation describe-stack-set-operation \
            --stack-set-name "$TARGET_STACK_SET_NAME" \
            --operation-id "$IMPORT_OPERATION_ID" \
            --region "$PRIMARY_REGION" | \
            jq -r '.StackSetOperation | .Status')" != "SUCCEEDED" ]]; do
            printf "Waiting for import operation to complete.\n" 
            sleep 20
        done
        
        # Check operation status and print any failures
        OPERATION_STATUS=$(aws cloudformation describe-stack-set-operation \
            --stack-set-name "$TARGET_STACK_SET_NAME" \
            --operation-id "$IMPORT_OPERATION_ID" \
            --region "$PRIMARY_REGION" | \
            jq -r '.StackSetOperation | .Status')
        
        printf 'Batch import operation completed with status: %s\n' "$OPERATION_STATUS"
        if [ "$OPERATION_STATUS" = "FAILED" ]; then
            aws cloudformation describe-stack-set-operation \
                --stack-set-name "$TARGET_STACK_SET_NAME" \
                --operation-id "$IMPORT_OPERATION_ID" \
                --region "$PRIMARY_REGION" | \
                jq -r '.StackSetOperation | .StatusReason'
            printf "Failed to import batch. Exiting...\n"
            exit 1
        fi
        
        # Add delay between batches
        if ((i + batch_size < total_stacks)); then
            printf "Waiting 30 seconds before processing next batch...\n"
            sleep 30
        fi
    done
}

# Read stack ARNs from file
STACK_ARNS=$(cat "$SOURCE_ARNS_FILE")

# Import stacks starting from position 81
if [[ -n "$STACK_ARNS" ]]; then
    printf "Starting import operation from stack number %s\n" "$START_FROM_STACK"
    import_stacks_in_batches "$STACK_ARNS" "$START_FROM_STACK"
    printf "Completed importing stacks to the %s stack set.\n" "$TARGET_STACK_SET_NAME"
else
    printf "No stack ARNs found in the file.\n"
    exit 1
fi
