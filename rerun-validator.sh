#!/bin/bash

# Script to restart solana-test-validator and advance it forward by a specified number of slots
# This is useful for testing time-dependent functionality in Solana programs

# Log function for consistent output
log_info() {
	echo "[RERUN-VALIDATOR] $1"
}

log_error() {
	echo "[RERUN-VALIDATOR ERROR] $1" >&2
}

# Check if slot advancement parameter is provided
if [ -z "$1" ]; then
	log_error "Missing required parameter: number of slots to advance"
	echo "Usage: $0 <number>"
	echo "Example: $0 432000  # Advances validator by ~1 epoch (432000 slots)"
	exit 1
fi

log_info "Starting validator restart and slot advancement process..."

# Get current slot number from the running validator
log_info "Getting current slot number from validator..."
current_slot=$(solana slot -ul)
if ! [[ "$current_slot" =~ ^[0-9]+$ ]]; then
	log_error "Failed to get current slot number. Output: $current_slot"
	log_error "Make sure solana-test-validator is running and responding to RPC calls"
	exit 2
fi

log_info "Current slot: $current_slot"

# Calculate new slot target for validator restart
# The -w flag tells the validator to start from a specific slot number
slots_to_advance=$1
new_w=$((current_slot + slots_to_advance))

log_info "Slots to advance: $slots_to_advance"
log_info "Target slot after restart: $new_w"
log_info "This will simulate advancing time by approximately $(($slots_to_advance / 432)) epochs"

# Kill the current validator process
log_info "Stopping current solana-test-validator process..."
if pkill -f solana-test-validator; then
	log_info "Successfully sent kill signal to validator"
else
	log_info "No validator process found or already stopped"
fi

# Wait for process to fully terminate
log_info "Waiting for validator to fully terminate..."
sleep 1

# Restart validator with new slot position
log_info "Restarting solana-test-validator at slot $new_w..."
log_info "The validator will start from the target slot, effectively 'jumping forward' in time"
log_info "This simulates the passage of time without waiting for actual slot progression"

# Start the validator with the calculated slot position
# The -w flag specifies the starting slot (warp to slot)
solana-test-validator -w "$new_w"
