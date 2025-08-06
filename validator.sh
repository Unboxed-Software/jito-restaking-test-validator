#!/bin/bash

PROGRAM_DIR="./programs/"

# Validator command
COMMAND="solana-test-validator \
  --url https://api.mainnet-beta.solana.com\
  --bpf-program cmtDvXumGCrqC1Age74AVPhSRVXJMd8PJS91L8KbNCK ${PROGRAM_DIR}spl_account_compression.so\
  --bpf-program noopb9bkMVfRPU8AsbpTUg8AQkHtKwMYZiFUjNRtMmV ${PROGRAM_DIR}spl_noop.so\
  --bpf-program ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL ${PROGRAM_DIR}spl_associated_token_account.so\
  --bpf-program RestkWeAVL8fRGgzhfeoqFhsqKRchg6aa1XrcH96z4Q ${PROGRAM_DIR}jito_restaking.so\
  --bpf-program Vau1t6sLNxnzB7ZDsef8TLbPLfyZMYXH8WTNqUdm9g8 ${PROGRAM_DIR}jito_vault.so\
  --clone ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL\
  --clone Vau1t6sLNxnzB7ZDsef8TLbPLfyZMYXH8WTNqUdm9g8 \
  --clone RestkWeAVL8fRGgzhfeoqFhsqKRchg6aa1XrcH96z4Q \
  --clone cmtDvXumGCrqC1Age74AVPhSRVXJMd8PJS91L8KbNCK \
  --clone noopb9bkMVfRPU8AsbpTUg8AQkHtKwMYZiFUjNRtMmV \
  --account-dir ./accounts/
  --reset"

# Append any additional arguments passed to the script
for arg in "$@"; do
	COMMAND+=" $arg"
done

# Execute the command
eval $COMMAND
