#!/bin/bash

# Capture output to variable
output=$(jito-restaking-cli restaking ncn initialize --signer ./keys/ncn/ncn-admin.json 2>&1)
# Extract pubkey and save
ncn_pubkey=$(echo "$output" | grep "Initializing NCN:" | awk '{print $NF}')
echo "$ncn_pubkey" >./keys/ncn/ncn_pubkey.txt
echo "NCN pubkey saved to ncn_pubkey.txt"
# Log NCN pubkey
echo "Extracted NCN pubkey: $ncn_pubkey"

for ((i = 1; i < 4; i++)); do
	output=$(jito-restaking-cli restaking operator initialize 1000 --signer "./keys/operators/operator$i-admin.json" 2>&1)
	operator_pubkey=$(echo "$output" | grep "Initializing Operator:" | awk '{print $NF}')
	echo "$ncn_pubkey" >"./keys/operators/operator$i-pubkey.txt"
	echo "Operator $i pubkey saved to operator$i-pubkey.txt"
	echo "Extracted Operator $i pubkey: $operator_pubkey"
done
