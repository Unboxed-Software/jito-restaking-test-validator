#!/bin/bash

if [ -z "$1" ]; then
	echo "Usage: $0 <number>"
	exit 1
fi

# Get current slot number
current_slot=$(solana slot -ul)
if ! [[ "$current_slot" =~ ^[0-9]+$ ]]; then
	echo "Failed to get current slot. Output: $current_slot"
	exit 2
fi

# Calculate new value for -w
new_w=$((current_slot + $1))

pkill -f solana-test-validator
sleep 1
solana-test-validator -w "$new_w"
