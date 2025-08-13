#!/bin/bash

set -e # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
	echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
	echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
	echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if solana-test-validator is running
check_validator_running() {
	if pgrep -f "solana-test-validator" >/dev/null; then
		return 0
	else
		return 1
	fi
}

# Function to wait for validator to be ready
wait_for_validator() {
	local max_wait=60 # Maximum wait time in seconds
	local wait_time=0

	log_info "Waiting for solana-test-validator to be ready..."

	while [ $wait_time -lt $max_wait ]; do
		if solana cluster-version -ul >/dev/null 2>&1; then
			log_success "Solana test validator is ready!"
			return 0
		fi

		sleep 2
		wait_time=$((wait_time + 2))
		echo -n "."
	done

	log_error "Timeout waiting for solana-test-validator to be ready"
	return 1
}

main() {
	log_info "Starting run.sh execution sequence..."

	pkill -f solana-test-validator &

	# Step 1: Run validator.sh - This starts the Solana test validator with required programs
	log_info "Step 1: Running validator.sh to start Solana test validator..."
	if [ -f "./validator.sh" ]; then
		chmod +x ./validator.sh
		log_info "Starting validator.sh in screen session named 'validator'"
		screen -dmS validator ./validator.sh &
		VALIDATOR_PID=$!
		log_info "validator.sh started with PID: $VALIDATOR_PID"
		log_info "The validator will run with Jito restaking and vault programs loaded"
	else
		log_error "validator.sh not found!"
		exit 1
	fi

	# Step 2: Wait for solana-test-validator to be running
	log_info "Step 2: Waiting for solana-test-validator to start..."
	sleep 5 # Initial wait to allow validator process to initialize

	# Wait for validator to be ready and accepting RPC connections
	log_info "Checking if validator is ready to accept RPC connections..."
	if ! wait_for_validator; then
		log_error "Failed to start solana-test-validator"
		exit 1
	fi

	# Step 3: Check if validator is running by running solana cluster-version
	# This command queries the validator's version to confirm it's responding to RPC calls
	log_info "Step 3: Verifying solana-test-validator is running and responding..."
	if solana cluster-version -ul; then
		log_success "Solana test validator is confirmed running and responding to RPC calls"
	else
		log_error "Solana test validator verification failed - not responding to RPC calls"
		exit 1
	fi

	# Step 4: Run setup-testing-env.sh and wait until it ends
	# This script sets up the testing environment, creates accounts, and initializes required state
	log_info "Step 4: Running setup-testing-env.sh to initialize testing environment..."
	if [ -f "./setup-testing-env.sh" ]; then
		chmod +x ./setup-testing-env.sh
		log_info "Executing setup-testing-env.sh - this may take several minutes"
		log_info "This will create test accounts, fund them, and set up initial program state"
		if ./setup-testing-env.sh; then
			log_success "setup-testing-env.sh completed successfully - testing environment is ready"
		else
			log_error "setup-testing-env.sh failed - testing environment setup incomplete"
			exit 1
		fi
	else
		log_error "setup-testing-env.sh not found!"
		exit 1
	fi

	# Step 5: Wait for 30 seconds to make sure solana-test-validator finalizes everything and snapshots it
	# This allows the validator to process all transactions and create a stable snapshot
	wait_time=40
	log_info "Step 5: Waiting $wait_time seconds for solana-test-validator to finalize and snapshot..."
	log_info "This ensures all setup transactions are processed and the ledger is stable"
	sleep $wait_time
	log_success "Finalization wait completed - validator state is now stable"

	# Step 6: Run rerun-validator.sh with parameter epoch*2 and keep logs printing on screen
	# 432000 slots = approximately one full Solana epoch forward in time
	slots_per_epoch=432000
	log_info "Step 6: Running rerun-validator.sh with parameter $((slots_per_epoch * 2)) (two epochs forward)..."
	if [ -f "./rerun-validator.sh" ]; then
		chmod +x ./rerun-validator.sh
		log_info "Executing: ./rerun-validator.sh $((slots_per_epoch * 2))"
		log_info "This will advance the validator by $((slots_per_epoch * 2)) slots (approximately two epochs)"
		log_info "Logs will be displayed on screen..."
		./rerun-validator.sh $((slots_per_epoch * 2))
	else
		log_error "rerun-validator.sh not found!"
		exit 1
	fi

	log_success "All steps completed successfully!"
}

# Execute main function
main "$@"
