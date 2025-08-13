#!/bin/bash

# ======================================================================
# JITO RESTAKING NETWORK COMPLETE SETUP SCRIPT
# ======================================================================
# This script sets up a complete Jito Restaking Network environment including:
# 1. Environment prerequisites validation
# 2. Solana local validator configuration
# 3. Keypair generation
# 4. Program configuration initialization (restaking + vault)
# 5. Network Component Node (NCN) initialization
# 6. Operator initialization (3 operators)
# 7. SPL token creation and management
# 8. Vault initialization with token support
# 9. Complete opt-in handshake between all components
# 10. Token delegation setup
# ======================================================================

set -e # Exit on any error to ensure setup integrity

# ======================================================================
# CONFIGURATION CONSTANTS
# ======================================================================
MIN_SOL_BALANCE=10 # Minimum SOL balance required for operations
RETRY_TIMEOUT=5    # Initial timeout for retry operations (with exponential backoff)

# ======================================================================
# TERMINAL OUTPUT COLORS
# ======================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ======================================================================
# LOGGING FUNCTIONS
# ======================================================================
# Standardized logging functions with color-coded output for better visibility
# and consistent formatting throughout the script execution.

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

# ======================================================================
# ERROR HANDLING SYSTEM
# ======================================================================
# Comprehensive error handling that captures context, logs details, and
# provides debugging information when the script encounters failures.

handle_error() {
	local exit_code=$1
	local line_number=$2
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	log_error "Script failed at line $line_number with exit code $exit_code"
	log_error "Timestamp: $timestamp"
	log_error "Current working directory: $(pwd)"
	log_error "Last command in history: $(history | tail -1)"

	# Create logs directory if it doesn't exist
	mkdir -p logs

	# Log comprehensive error details to file for debugging
	{
		echo "===== SETUP SCRIPT ERROR LOG ====="
		echo "Timestamp: $timestamp"
		echo "Exit code: $exit_code"
		echo "Line number: $line_number"
		echo "Working directory: $(pwd)"
		echo "Last command: $(history | tail -1)"
		echo "Environment variables:"
		env | sort
		echo "==================================="
	} >>logs/error.log

	log_error "Error details logged to logs/error.log"
	log_error "Please check the error log and retry the setup process"
	exit $exit_code
}

trap 'handle_error $? $LINENO' ERR

# Function to log command execution details
log_command_execution() {
	local command="$1"
	local exit_code="$2"
	local output="$3"
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	{
		echo "===== COMMAND LOG ====="
		echo "Timestamp: $timestamp"
		echo "Command: $command"
		echo "Exit code: $exit_code"
		echo "Output:"
		echo "$output"
		echo "======================"
		echo ""
	} >>logs/commands.log
}

# Function to check balance and airdrop if needed
check_and_fund_keypair() {
	local keypair_path="$1"
	local keypair_name="$2"

	# Get current balance
	local balance
	local balance_output
	balance_output=$(solana balance --keypair "$keypair_path" 2>&1)
	local balance_exit_code=$?

	log_command_execution "solana balance --keypair $keypair_path" "$balance_exit_code" "$balance_output"

	if [[ $balance_exit_code -ne 0 ]]; then
		log_error "Failed to get balance for $keypair_name"
		log_error "Error output: $balance_output"
		balance="0"
	else
		balance=$(echo "$balance_output" | awk '{print $1}')
	fi

	# Convert balance to integer for comparison (remove decimal part)
	local balance_int
	balance_int=$(echo "$balance" | cut -d'.' -f1)

	if [[ "$balance_int" -lt "$MIN_SOL_BALANCE" ]]; then
		log_info "$keypair_name has $balance SOL (less than $MIN_SOL_BALANCE), requesting airdrop..."

		retry_command "solana airdrop 100 --keypair '$keypair_path'" "SOL"

		local new_balance
		new_balance=$(solana balance --keypair "$keypair_path" | awk '{print $1}')
		log_success "$keypair_name funded, new balance: $new_balance SOL"
	else
		log_info "$keypair_name has sufficient balance: $balance SOL (>= $MIN_SOL_BALANCE), skipping airdrop"
	fi
}

# Retry function with configurable timeout and exponential backoff
retry_command() {
	local max_attempts=5
	local delay=${RETRY_TIMEOUT:-2}
	local attempt=1
	local command="$1"
	local success_pattern="$2"

	echo "Attempting command: $command"

	while [ $attempt -le $max_attempts ]; do
		log_info "Attempt $attempt/$max_attempts: $command"

		if output=$(eval "$command" 2>&1); then
			local cmd_exit_code=$?
			log_command_execution "$command" "$cmd_exit_code" "$output"

			if [[ -n "$success_pattern" && "$output" =~ $success_pattern ]] || [[ -z "$success_pattern" ]]; then
				log_success "Command succeeded on attempt $attempt"
				echo "$output"
				return 0
			else
				log_error "Command output did not match expected pattern '$success_pattern'"
				log_error "Actual output: $output"
			fi
		else
			local cmd_exit_code=$?
			log_command_execution "$command" "$cmd_exit_code" "$output"
			log_error "Command execution failed with exit code $cmd_exit_code"
			log_error "Error output: $output"
		fi

		if [ $attempt -eq $max_attempts ]; then
			log_error "Command failed after $max_attempts attempts"
			log_error "Final error output: $output"
			return 1
		fi

		log_warning "Attempt $attempt failed, retrying in ${delay}s..."
		log_warning "Error was: $output"

		# Wait before retrying
		sleep $delay

		# Exponential backoff: double the delay for next attempt
		delay=$((delay * 2))
		attempt=$((attempt + 1))
	done
}

# ======================================================================
# PREREQUISITES VALIDATION
# ======================================================================
# Validates that all required tools and dependencies are installed before
# proceeding with the setup. This prevents failures during setup execution.

check_prerequisites() {
	log_info "=== STEP 1: CHECKING SYSTEM PREREQUISITES ==="
	log_info "Validating all required tools are installed and accessible..."

	# Check Rust compiler - Required for building Solana programs
	log_info "Checking Rust compiler availability..."
	if ! command -v rustc &>/dev/null; then
		log_error "Rust is not installed. Please install Rust first."
		log_info "Install from: https://rustup.rs/"
		exit 1
	fi
	log_success "Rust found: $(rustc --version)"

	# Check Cargo package manager - Required for Rust project management
	log_info "Checking Cargo package manager..."
	if ! command -v cargo &>/dev/null; then
		log_error "Cargo is not installed. Please install Cargo first."
		exit 1
	fi
	log_success "Cargo found: $(cargo --version)"

	# Check Solana CLI - Core tool for Solana blockchain interactions
	log_info "Checking Solana CLI installation..."
	if ! command -v solana &>/dev/null; then
		log_error "Solana CLI is not installed. Please install Solana CLI first."
		log_info "Install from: https://docs.solana.com/cli/install-solana-cli-tools"
		exit 1
	fi
	log_success "Solana CLI found: $(solana --version)"

	# Check SPL Token CLI - Required for token operations
	log_info "Checking SPL Token CLI..."
	if ! command -v spl-token &>/dev/null; then
		log_error "SPL Token CLI is not installed. Please install it first."
		log_info "Install with: cargo install spl-token-cli"
		exit 1
	fi
	log_success "SPL Token CLI found"

	# Check Solana Keygen - Required for keypair generation
	log_info "Checking Solana Keygen utility..."
	if ! command -v solana-keygen &>/dev/null; then
		log_error "Solana Keygen is not installed. Please install it first."
		exit 1
	fi
	log_success "Solana Keygen found"

	# Check Jito Restaking CLI - Core tool for restaking operations
	log_info "Checking Jito Restaking CLI..."
	if ! command -v jito-restaking-cli &>/dev/null; then
		log_error "Jito Restaking CLI is not installed. Please install it first."
		log_info "Install it from https://github.com/jito-foundation/restaking"
		exit 1
	fi
	log_success "Jito Restaking CLI found: $(jito-restaking-cli --version)"

	log_success "All prerequisites validated successfully!"
}

# ======================================================================
# SOLANA ENVIRONMENT CONFIGURATION
# ======================================================================
# Configures Solana CLI to connect to the local test validator and ensures
# the default wallet has sufficient SOL for transaction fees.

configure_solana() {
	log_info "=== STEP 2: CONFIGURING SOLANA ENVIRONMENT ==="
	log_info "Setting up Solana CLI to connect to local test validator..."

	# Configure Solana CLI to use local test validator (localhost)
	log_info "Setting Solana RPC URL to localhost (local test validator)..."

	solana config set --url l

	# Display current configuration for verification
	log_info "Current Solana configuration:"
	solana config get
	log_success "Solana CLI configured for local test validator"

	# Ensure the default wallet has sufficient SOL for operations
	log_info "Validating default wallet has sufficient SOL for transaction fees..."
	local balance
	balance=$(solana balance 2>/dev/null | awk '{print $1}' || echo "0")
	local balance_int
	balance_int=$(echo "$balance" | cut -d'.' -f1)

	log_info "Current default wallet balance: $balance SOL"

	if [[ "$balance_int" -lt "$MIN_SOL_BALANCE" ]]; then
		log_info "Wallet balance ($balance SOL) is below minimum required ($MIN_SOL_BALANCE SOL)"
		log_info "Requesting SOL airdrop from local test validator..."

		retry_command "solana airdrop 100" "SOL"

		balance=$(solana balance | awk '{print $1}')
		log_success "Default wallet funded successfully! New balance: $balance SOL"
	else
		log_success "Default wallet has sufficient balance: $balance SOL (>= $MIN_SOL_BALANCE SOL)"
	fi

	log_success "Solana environment configuration completed!"
}

# ======================================================================
# DIRECTORY STRUCTURE SETUP
# ======================================================================
# Creates the necessary directory structure for storing keypairs, logs,
# and other generated files during the setup process.

create_directories() {
	log_info "=== STEP 3: SETTING UP DIRECTORY STRUCTURE ==="
	log_info "Creating directories for keypairs, logs, and configuration files..."

	# Create directory for Network Component Node (NCN) keypairs and data
	log_info "Creating NCN directory for Network Component Node files..."
	mkdir -p keys/ncn

	# Create directory for Vault-related keypairs and configurations
	log_info "Creating Vault directory for vault administration files..."
	mkdir -p keys/vault

	# Create directory for Operator keypairs
	log_info "Creating Operators directory for operator administration files..."
	mkdir -p keys/operators

	# Create logs directory for command execution and error logging
	log_info "Creating logs directory for execution tracking..."
	mkdir -p logs

	log_success "Directory structure created successfully!"
	log_info "Created directories:"
	log_info "  - keys/ncn/        (NCN keypairs and pubkeys)"
	log_info "  - keys/vault/      (Vault admin keypairs and addresses)"
	log_info "  - keys/operators/  (Operator admin)"
	log_info "  - logs/            (Execution logs and error tracking)"
}

# ======================================================================
# KEYPAIR GENERATION AND FUNDING
# ======================================================================
# Generates all necessary Solana keypairs for NCN, Vault, and Operators,
# Also ensures all keypairs have sufficient SOL for operations.

generate_keypairs() {
	log_info "=== STEP 4: GENERATING AND FUNDING KEYPAIRS ==="
	log_info "Creating Solana keypairs for all network components and ensuring proper funding..."

	# ============================================
	# NCN (Network Component Node) Admin Keypair
	# ============================================
	log_info "Processing NCN admin keypair..."
	if [[ -f "keys/ncn/ncn-admin.json" ]]; then
		log_warning "NCN admin keypair already exists, skipping generation"
		log_info "Verifying existing NCN admin keypair funding..."
		check_and_fund_keypair "keys/ncn/ncn-admin.json" "NCN admin keypair"
	else
		log_info "Generating new NCN admin keypair (no passphrase)..."

		retry_command "solana-keygen new --outfile 'keys/ncn/ncn-admin.json' --no-bip39-passphrase" "Wrote new keypair"

		log_info "Funding newly created NCN admin keypair..."
		check_and_fund_keypair "keys/ncn/ncn-admin.json" "NCN admin keypair"
		log_success "NCN admin keypair generated and funded successfully"
	fi

	# ================================
	# Vault Admin Keypair
	# ================================
	log_info "Processing Vault admin keypair..."
	if [[ -f "keys/vault/vault-admin.json" ]]; then
		log_warning "Vault admin keypair already exists, skipping generation"
		log_info "Verifying existing Vault admin keypair funding..."
		check_and_fund_keypair "keys/vault/vault-admin.json" "Vault admin keypair"
	else
		log_info "Generating new Vault admin keypair (no passphrase)..."

		retry_command "solana-keygen new --outfile 'keys/vault/vault-admin.json' --no-bip39-passphrase --force" "Wrote new keypair"

		log_info "Funding newly created Vault admin keypair..."
		check_and_fund_keypair "keys/vault/vault-admin.json" "Vault admin keypair"
		log_success "Vault admin keypair generated and funded successfully"
	fi

	# ===================================================
	# Operator Admin Keypairs (Solana)
	# ===================================================
	log_info "Processing 3 Operator keypairs..."
	for i in {1..3}; do
		log_info "--- Processing Operator $i ---"

		# Generate Solana admin keypair for operator transactions
		log_info "Processing Operator $i Solana admin keypair..."
		if [[ -f "keys/operators/operator$i-admin.json" ]]; then
			log_warning "Operator $i admin keypair already exists, skipping generation"
			log_info "Verifying existing Operator $i admin keypair funding..."
			check_and_fund_keypair "keys/operators/operator$i-admin.json" "Operator $i admin keypair"
		else
			log_info "Generating new Operator $i admin keypair (no passphrase)..."

			retry_command "solana-keygen new --outfile 'keys/operators/operator$i-admin.json' --no-bip39-passphrase --force" "Wrote new keypair"

			log_info "Funding newly created Operator $i admin keypair..."
			check_and_fund_keypair "keys/operators/operator$i-admin.json" "Operator $i admin keypair"
			log_success "Operator $i admin keypair generated and funded successfully"
		fi

	done

	log_success "All keypairs generated and funded successfully!"
	log_info "Generated keypairs summary:"
	log_info "  - NCN admin keypair:       keys/ncn/ncn-admin.json"
	log_info "  - Vault admin keypair:     keys/vault/vault-admin.json"
}

# ======================================================================
# PROGRAM CONFIGURATION INITIALIZATION
# ======================================================================
# Initializes the core program configurations for both Jito Restaking
# and Vault programs. This must be done before any network components
# can be created or operated.

initialize_configs() {
	log_info "=== STEP 5: INITIALIZING PROGRAM CONFIGURATIONS ==="
	log_info "Setting up core program configs required for restaking operations..."

	# =====================================
	# Initialize Restaking Program Config
	# =====================================
	log_info "Initializing Jito Restaking program configuration..."
	log_info "This config enables NCN and Operator functionality on the network"

	retry_command "jito-restaking-cli restaking config initialize" "Transaction confirmed"

	log_success "Restaking program configuration initialized successfully"

	# ===============================
	# Initialize Vault Program Config
	# ===============================
	log_info "Initializing Jito Vault program configuration..."
	log_info "This config enables Vault operations and token management"
	log_info "Using fee configuration: 100 basis points, fee wallet: 3ogGQ7nFX6nCa9bkkZ6hwud6VaEQCekCCmNj6ZoWh8MF"

	retry_command "jito-restaking-cli vault config initialize 100 3ogGQ7nFX6nCa9bkkZ6hwud6VaEQCekCCmNj6ZoWh8MF" "Transaction confirmed"

	log_success "Vault program configuration initialized successfully"
	log_success "All program configurations initialized! Network is ready for component creation."
}

# ======================================================================
# NETWORK COMPONENT NODE (NCN) INITIALIZATION
# ======================================================================
# Creates a new Network Component Node which acts as the central coordinator
# for the restaking network, managing connections with operators and vaults.

initialize_ncn() {
	log_info "=== STEP 6: INITIALIZING NETWORK COMPONENT NODE (NCN) ==="
	log_info "Creating NCN to serve as the network coordinator for restaking operations..."

	log_info "Executing NCN initialization using admin keypair..."
	log_info "Admin keypair: ./keys/ncn/ncn-admin.json"

	# Execute NCN initialization command and capture output
	local output
	output=$(retry_command "jito-restaking-cli restaking ncn initialize --signer ./keys/ncn/ncn-admin.json" "Initializing NCN:")

	# Extract the NCN public key from command output
	log_info "Extracting NCN public key from initialization output..."
	local ncn_pubkey
	ncn_pubkey=$(echo "$output" | grep "Initializing NCN:" | awk '{print $NF}')

	# Validate that we successfully extracted the pubkey
	if [[ -z "$ncn_pubkey" ]]; then
		log_error "Failed to extract NCN public key from initialization output"
		log_error "Command output was: $output"
		return 1
	fi

	# Save NCN pubkey to file for future reference
	log_info "Saving NCN public key to file for future operations..."
	echo "$ncn_pubkey" >./keys/ncn/ncn_pubkey.txt
	log_success "NCN public key saved to: ./keys/ncn/ncn_pubkey.txt"

	log_success "NCN initialized successfully!"
	log_info "NCN Public Key: $ncn_pubkey"
	log_info "NCN will coordinate connections between operators and vaults"

	# Store in global variable for use by other functions
	NCN_PUBKEY="$ncn_pubkey"
}

# ======================================================================
# OPERATOR INITIALIZATION
# ======================================================================
# Creates 3 operators that will provide services to the restaking network.
# Each operator has a bond amount and can accept delegated stake from vaults.

initialize_operators() {
	log_info "=== STEP 7: INITIALIZING NETWORK OPERATORS ==="
	log_info "Creating 3 operators to provide services in the restaking network..."

	# Array to store operator pubkeys for later use
	declare -a OPERATOR_PUBKEYS

	# Initialize each operator with specific bond amount
	for i in {1..3}; do
		log_info "--- Initializing Operator $i ---"
		log_info "Bond amount: 1000 units"
		log_info "Admin keypair: ./keys/operators/operator$i-admin.json"

		# Execute operator initialization with bond amount
		local output
		output=$(retry_command "jito-restaking-cli restaking operator initialize 1000 --signer './keys/operators/operator$i-admin.json'" "Initializing Operator:")

		# Extract operator public key from command output
		log_info "Extracting Operator $i public key from initialization output..."
		local operator_pubkey
		operator_pubkey=$(echo "$output" | grep "Initializing Operator:" | awk '{print $NF}')

		# Validate pubkey extraction was successful
		if [[ -z "$operator_pubkey" ]]; then
			log_error "Failed to extract Operator $i public key from initialization output"
			log_error "Command output was: $output"
			return 1
		fi

		# Save operator pubkey to file for future reference
		log_info "Saving Operator $i public key to file..."
		echo "$operator_pubkey" >"./keys/operators/operator$i-pubkey.txt"
		log_success "Operator $i public key saved to: ./keys/operators/operator$i-pubkey.txt"

		log_success "Operator $i initialized successfully!"
		log_info "Operator $i Public Key: $operator_pubkey"
		log_info "Operator $i can now accept stake delegations and provide services"

		# Store in array for potential future use
		OPERATOR_PUBKEYS[$i]="$operator_pubkey"
	done

	log_success "All 3 operators initialized successfully!"
	log_info "Operators can now participate in the restaking network and accept delegations"
}

# ======================================================================
# SPL TOKEN CREATION AND SETUP
# ======================================================================
# Creates an SPL token that will be used by the vault for deposit/withdrawal
# operations. The token represents the underlying asset being restaked.

create_spl_token() {
	log_info "=== STEP 8: CREATING SPL TOKEN FOR VAULT OPERATIONS ==="
	log_info "Setting up SPL token to represent the underlying restaked asset..."

	# Create new SPL token
	log_info "Creating new SPL token using default wallet as mint authority..."
	local output
	output=$(retry_command "spl-token create-token" "Creating token")

	# Extract token mint address from command output
	log_info "Extracting token mint address from creation output..."
	local token_address
	token_address=$(echo "$output" | grep "Address:" | awk '{print $2}')

	# Validate token address extraction
	if [[ -z "$token_address" ]]; then
		log_error "Failed to extract token mint address from creation output"
		log_error "Command output was: $output"
		return 1
	fi

	# Save token address for future reference
	log_info "Saving token mint address to file..."
	echo "$token_address" >./keys/vault/token_address.txt
	log_success "SPL token created successfully!"
	log_info "Token Mint Address: $token_address"
	log_info "Token mint address saved to: ./keys/vault/token_address.txt"

	# Store in global variable for use by other functions
	TOKEN_ADDRESS="$token_address"

	# Create token account for vault admin to hold tokens
	log_info "Creating associated token account for vault admin..."
	log_info "This account will hold the tokens owned by the vault admin"

	retry_command "spl-token create-account $token_address --owner ./keys/vault/vault-admin.json" "Creating account"

	log_success "Token account created for vault admin"

	# Mint initial token supply to vault admin
	log_info "Minting initial token supply to vault admin..."
	log_info "Mint amount: 1,000,000 tokens"

	retry_command "spl-token mint $token_address 1000000 --recipient-owner ./keys/vault/vault-admin.json" "Signature:"

	log_success "Tokens minted successfully to vault admin"

	log_success "SPL token setup completed successfully!"
	log_info "Vault can now use this token for deposit/withdrawal operations"
}

# Initialize Vault
initialize_vault() {
	log_info "Initializing Vault..."

	# Load TOKEN_ADDRESS if not set
	if [[ -z "$TOKEN_ADDRESS" && -f "./keys/vault/token_address.txt" ]]; then
		TOKEN_ADDRESS=$(cat ./keys/vault/token_address.txt)
		log_info "Loaded token address from file: $TOKEN_ADDRESS"
	fi

	echo "Using Token Address: $TOKEN_ADDRESS"

	local output
	output=$(retry_command "jito-restaking-cli --signer ./keys/vault/vault-admin.json vault vault initialize '$TOKEN_ADDRESS' 1000 1000 1000 9 1000000000" "Initializing Vault at address:")

	# Extract vault address
	local vault_address
	vault_address=$(echo "$output" | grep "Initializing Vault at address:" | awk '{print $NF}')

	if [[ -z "$vault_address" ]]; then
		log_error "Failed to extract vault address from output"
		log_error "Full output: $output"
		return 1
	fi

	echo "$vault_address" >./keys/vault/vault_address.txt
	log_success "Vault initialized with address: $vault_address"

	# Save to global variable
	VAULT_ADDRESS="$vault_address"
}

# Load existing addresses from files
load_addresses() {
	log_info "Loading addresses from existing files..."

	# Load NCN pubkey
	if [[ -f "./keys/ncn/ncn_pubkey.txt" ]]; then
		NCN_PUBKEY=$(cat ./keys/ncn/ncn_pubkey.txt)
		log_info "Loaded NCN pubkey: $NCN_PUBKEY"
	else
		log_warning "NCN pubkey file not found"
	fi

	# Load TOKEN_ADDRESS
	if [[ -f "./keys/vault/token_address.txt" ]]; then
		TOKEN_ADDRESS=$(cat ./keys/vault/token_address.txt)
		log_info "Loaded token address: $TOKEN_ADDRESS"
	else
		log_warning "Token address file not found"
	fi

	# Load VAULT_ADDRESS
	if [[ -f "./keys/vault/vault_address.txt" ]]; then
		VAULT_ADDRESS=$(cat ./keys/vault/vault_address.txt)
		log_info "Loaded vault address: $VAULT_ADDRESS"
	else
		log_warning "Vault address file not found"
	fi
}

# Perform opt-in handshake
perform_handshake() {
	log_info "Starting opt-in handshake process - executing and logging commands..."

	# Load addresses if not already set
	load_addresses

	# Create handshake commands file
	local commands_file="handshake_commands.sh"
	{
		echo "#!/bin/bash"
		echo ""
		echo "# Jito Restaking Network Handshake Commands"
		echo "# Generated and executed on: $(date)"
		echo "# "
		echo "# NCN Address: $NCN_PUBKEY"
		echo "# Vault Address: $VAULT_ADDRESS"
		echo "# Token Address: $TOKEN_ADDRESS"
		echo ""
		echo "set -e  # Exit on any error"
		echo ""
		echo "# Colors for output"
		echo "GREEN='\\033[0;32m'"
		echo "NC='\\033[0m' # No Color"
		echo ""
		echo "echo_success() {"
		echo "    echo -e \"\${GREEN}[SUCCESS]\${NC} \$1\""
		echo "}"
		echo ""
	} >"$commands_file"

	log_info "Executing NCN to Operator connections..."
	# NCN to Operator connections
	for i in {1..3}; do
		local operator_pubkey
		operator_pubkey=$(cat "./keys/operators/operator$i-pubkey.txt")

		# Log to file
		{
			echo "# NCN to Operator $i connections"
			echo "echo \"Connecting NCN to Operator $i...\""
			echo "jito-restaking-cli restaking ncn initialize-ncn-operator-state '$NCN_PUBKEY' '$operator_pubkey' --signer ./keys/ncn/ncn-admin.json"
			echo "echo \"Sleeping 4 seconds before warmup...\""
			echo "sleep 4"
			echo "jito-restaking-cli restaking ncn ncn-warmup-operator '$NCN_PUBKEY' '$operator_pubkey' --signer ./keys/ncn/ncn-admin.json"
			echo "echo \"Sleeping 4 seconds before operator warmup...\""
			echo "sleep 4"
			echo "jito-restaking-cli restaking operator operator-warmup-ncn '$operator_pubkey' '$NCN_PUBKEY' --signer ./keys/operators/operator$i-admin.json"
			echo "echo_success \"NCN to Operator $i connection established\""
			echo ""
		} >>"$commands_file"

		# Execute commands
		log_info "Connecting NCN to Operator $i..."

		retry_command "jito-restaking-cli restaking ncn initialize-ncn-operator-state '$NCN_PUBKEY' '$operator_pubkey' --signer ./keys/ncn/ncn-admin.json" "Transaction confirmed"

		log_info "Sleeping 4 seconds before warmup..."
		sleep 4

		retry_command "jito-restaking-cli restaking ncn ncn-warmup-operator '$NCN_PUBKEY' '$operator_pubkey' --signer ./keys/ncn/ncn-admin.json" "Transaction confirmed"

		log_info "Sleeping 4 seconds before operator warmup..."
		sleep 4

		retry_command "jito-restaking-cli restaking operator operator-warmup-ncn '$operator_pubkey' '$NCN_PUBKEY' --signer ./keys/operators/operator$i-admin.json" "Transaction confirmed"

		log_success "NCN to Operator $i connection established"
	done

	log_info "Executing NCN to Vault connections..."
	# NCN to Vault connection
	{
		echo "# NCN to Vault connection"
		echo "echo \"Connecting NCN to Vault...\""
		echo "jito-restaking-cli restaking ncn initialize-ncn-vault-ticket '$NCN_PUBKEY' '$VAULT_ADDRESS' --signer ./keys/ncn/ncn-admin.json"
		echo "echo \"Sleeping 4 seconds before warmup...\""
		echo "sleep 4"
		echo "jito-restaking-cli restaking ncn warmup-ncn-vault-ticket '$NCN_PUBKEY' '$VAULT_ADDRESS' --signer ./keys/ncn/ncn-admin.json"
		echo "echo_success \"NCN to Vault connection established\""
		echo ""
	} >>"$commands_file"

	# Execute commands
	log_info "Connecting NCN to Vault..."
	retry_command "jito-restaking-cli restaking ncn initialize-ncn-vault-ticket '$NCN_PUBKEY' '$VAULT_ADDRESS' --signer ./keys/ncn/ncn-admin.json" "Transaction confirmed"

	log_info "Sleeping 4 seconds before warmup..."
	sleep 4

	retry_command "jito-restaking-cli restaking ncn warmup-ncn-vault-ticket '$NCN_PUBKEY' '$VAULT_ADDRESS' --signer ./keys/ncn/ncn-admin.json" "Transaction confirmed"
	log_success "NCN to Vault connection established"

	log_info "Executing Operator to Vault connections..."
	# Operator to NCN and Vault connections
	for i in {1..3}; do
		local operator_pubkey
		operator_pubkey=$(cat "./keys/operators/operator$i-pubkey.txt")

		# Log to file
		{
			echo "# Operator $i to Vault connection"
			echo "echo \"Connecting Operator $i to Vault...\""
			echo "jito-restaking-cli restaking operator initialize-operator-vault-ticket '$operator_pubkey' '$VAULT_ADDRESS' --signer ./keys/operators/operator$i-admin.json"
			echo "echo \"Sleeping 4 seconds before warmup...\""
			echo "sleep 4"
			echo "jito-restaking-cli restaking operator warmup-operator-vault-ticket '$operator_pubkey' '$VAULT_ADDRESS' --signer ./keys/operators/operator$i-admin.json"
			echo "echo_success \"Operator $i connections established\""
			echo ""
		} >>"$commands_file"

		# Execute commands
		log_info "Connecting Operator $i to Vault..."
		retry_command "jito-restaking-cli restaking operator initialize-operator-vault-ticket '$operator_pubkey' '$VAULT_ADDRESS' --signer ./keys/operators/operator$i-admin.json" "Transaction confirmed"

		log_info "Sleeping 4 seconds before warmup..."
		sleep 4

		retry_command "jito-restaking-cli restaking operator warmup-operator-vault-ticket '$operator_pubkey' '$VAULT_ADDRESS' --signer ./keys/operators/operator$i-admin.json" "Transaction confirmed"
		log_success "Operator $i connections established"
	done

	log_info "Executing Vault updates and connections..."
	# Update vault configuration before connections
	{
		echo "# Vault to NCN connection"
		echo "echo \"Connecting Vault to NCN...\""
		echo "jito-restaking-cli vault vault initialize-vault-ncn-ticket '$VAULT_ADDRESS' '$NCN_PUBKEY' --signer ./keys/vault/vault-admin.json"
		echo "echo \"Sleeping 4 seconds before warmup...\""
		echo "sleep 4"
		echo "jito-restaking-cli vault vault warmup-vault-ncn-ticket '$VAULT_ADDRESS' '$NCN_PUBKEY' --signer ./keys/vault/vault-admin.json"
		echo "echo_success \"Vault to NCN connection established\""
		echo ""
	} >>"$commands_file"

	# Execute commands

	log_info "Connecting Vault to NCN..."
	retry_command "jito-restaking-cli vault vault initialize-vault-ncn-ticket '$VAULT_ADDRESS' '$NCN_PUBKEY' --signer ./keys/vault/vault-admin.json" "Transaction confirmed"

	log_info "Sleeping 4 seconds before warmup..."
	sleep 4

	retry_command "jito-restaking-cli vault vault warmup-vault-ncn-ticket '$VAULT_ADDRESS' '$NCN_PUBKEY' --signer ./keys/vault/vault-admin.json" "Transaction confirmed"
	log_success "Vault to NCN connection established"

	log_info "Executing token infrastructure setup..."
	# Setup token infrastructure and delegation
	{
		echo "# Setup token infrastructure"
		echo "echo \"Setting up token infrastructure...\""
		echo "spl-token create-account '$TOKEN_ADDRESS'"
		echo "spl-token mint '$TOKEN_ADDRESS' 3000"
		echo "jito-restaking-cli vault vault mint-vrt '$VAULT_ADDRESS' 3000000000000 0"
		echo ""

		echo "# Update vault before operator delegations"
		echo "echo \"Updating vault configuration for operator delegations...\""
		echo "jito-restaking-cli vault vault update-vault-balance '$VAULT_ADDRESS' --signer ./keys/vault/vault-admin.json"
		echo "echo_success \"Vault updated for operator delegations\""
		echo ""
	} >>"$commands_file"

	# Execute commands
	log_info "Setting up token infrastructure..."
	retry_command "spl-token create-account '$TOKEN_ADDRESS'" "Creating account"
	retry_command "spl-token mint '$TOKEN_ADDRESS' 3000" "Signature:"
	retry_command "jito-restaking-cli vault vault mint-vrt '$VAULT_ADDRESS' 3000000000000 0" "Transaction confirmed"

	log_info "Updating vault configuration for operator delegations..."
	retry_command "jito-restaking-cli vault vault update-vault-balance '$VAULT_ADDRESS' --signer ./keys/vault/vault-admin.json" "Transaction confirmed"
	log_success "Vault updated for operator delegations"

	log_info "Executing operator delegations..."
	# Initialize and delegate to operators
	for i in {1..3}; do
		local operator_pubkey
		operator_pubkey=$(cat "./keys/operators/operator$i-pubkey.txt")

		# Log to file
		{
			echo "# Setting up delegation to Operator $i"
			echo "echo \"Setting up delegation to Operator $i...\""
			echo "jito-restaking-cli vault vault initialize-operator-delegation '$VAULT_ADDRESS' '$operator_pubkey' --signer ./keys/vault/vault-admin.json"
			echo "jito-restaking-cli vault vault delegate-to-operator '$VAULT_ADDRESS' '$operator_pubkey' 500000000000 --signer ./keys/vault/vault-admin.json"
			echo "echo_success \"Delegation to Operator $i completed\""
			echo ""
		} >>"$commands_file"

		# Execute commands
		log_info "Setting up delegation to Operator $i..."
		retry_command "jito-restaking-cli vault vault initialize-operator-delegation '$VAULT_ADDRESS' '$operator_pubkey' --signer ./keys/vault/vault-admin.json" "Transaction confirmed"
		retry_command "jito-restaking-cli vault vault delegate-to-operator '$VAULT_ADDRESS' '$operator_pubkey' 500000000000 --signer ./keys/vault/vault-admin.json" "Transaction confirmed"
		log_success "Delegation to Operator $i completed"
	done

	{
		echo "echo \"All handshake commands completed successfully!\""
	} >>"$commands_file"

	# Make the file executable
	chmod +x "$commands_file"

	log_success "Handshake commands executed and logged to: $commands_file"
	log_info "Command script saved for future reference: ./$commands_file"

	# Display summary of what was completed
	echo ""
	echo "========================="
	echo "HANDSHAKE EXECUTION SUMMARY"
	echo "========================="
	echo "✅ All commands executed successfully!"
	echo "📝 Commands also logged to: $commands_file"
	echo ""
	echo "Completed operations:"
	echo "• NCN to Operator connections (3 operators)"
	echo "• NCN to Vault connection"
	echo "• Operator to Vault connections (3 operators)"
	echo "• Vault configuration updates"
	echo "• Vault to NCN connection"
	echo "• Token infrastructure setup"
	echo "• Operator delegations (500 tokens each)"
	echo ""
	echo "Addresses used:"
	echo "• NCN: $NCN_PUBKEY"
	echo "• Vault: $VAULT_ADDRESS"
	echo "• Token: $TOKEN_ADDRESS"
	for i in {1..3}; do
		local operator_pubkey=$(cat "./keys/operators/operator$i-pubkey.txt")
		echo "• Operator $i: $operator_pubkey"
	done
	echo "========================="
}

# Final validation and reporting
validate_setup() {
	log_info "Validating setup..."

	# Check all key files exist and contain data
	local files=(
		"./keys/ncn/ncn_pubkey.txt"
		"./keys/vault/vault_address.txt"
		"./keys/vault/token_address.txt"
		"./keys/operators/operator1-pubkey.txt"
		"./keys/operators/operator2-pubkey.txt"
		"./keys/operators/operator3-pubkey.txt"
	)

	for file in "${files[@]}"; do
		if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
			log_error "Validation failed: $file is missing or empty"
			return 1
		fi
	done

	log_success "All key files validated"

	# Generate summary report
	cat >setup_summary.txt <<EOF
Jito Restaking Network Setup Summary
=====================================
Setup completed on: $(date)

NCN Address: $(cat ./keys/ncn/ncn_pubkey.txt)
Vault Address: $(cat ./keys/vault/vault_address.txt)
Token Address: $(cat ./keys/vault/token_address.txt)

Operators:
- Operator 1: $(cat ./keys/operators/operator1-pubkey.txt)
- Operator 2: $(cat ./keys/operators/operator2-pubkey.txt)
- Operator 3: $(cat ./keys/operators/operator3-pubkey.txt)


All components have been initialized and connected through the opt-in handshake process.
Token delegation has been set up with 500 tokens delegated to each operator.

Key Files Location:
- NCN Admin: ./keys/ncn/ncn-admin.json
- Vault Admin: ./keys/vault/vault-admin.json
- Operator Admins: ./keys/operators/operator{1,2,3}-admin.json

Network is ready for testing and development.
EOF

	log_success "Setup summary saved to setup_summary.txt"
}

# ======================================================================
# MAIN EXECUTION FUNCTION
# ======================================================================
# Orchestrates the complete setup process by executing all steps in the
# correct order. Tracks timing and provides comprehensive status reporting.

main() {
	local start_time=$(date +%s)

	echo ""
	echo "======================================================================="
	echo "           JITO RESTAKING NETWORK COMPLETE SETUP"
	echo "======================================================================="
	log_info "🚀 Starting comprehensive Jito Restaking Network setup process..."
	log_info "⏰ Start time: $(date)"
	log_info "📂 Working directory: $(pwd)"
	echo ""

	# ======================================================================
	# SETUP EXECUTION SEQUENCE
	# ======================================================================
	# Each step builds upon the previous ones and must complete successfully
	# before proceeding to ensure a fully functional restaking network.

	# STEP 1: Validate environment and dependencies
	check_prerequisites

	# STEP 2: Configure Solana CLI for local test validator
	configure_solana

	# STEP 3: Create directory structure for organized file management
	create_directories

	# STEP 4: Generate all necessary keypairs and ensure proper funding
	generate_keypairs

	# STEP 5: Initialize core program configurations (critical prerequisite)
	initialize_configs

	# STEP 6: Initialize Network Component Node (network coordinator)
	initialize_ncn

	# STEP 7: Initialize 3 operators (service providers)
	initialize_operators

	# STEP 8: Create and configure SPL token for vault operations
	create_spl_token

	# STEP 9: Initialize vault with token support
	initialize_vault

	# STEP 10: Execute complete opt-in handshake and token delegations
	perform_handshake

	# STEP 11: Generate final validation and summary report
	validate_setup

	# ======================================================================
	# SETUP COMPLETION AND REPORTING
	# ======================================================================

	local end_time=$(date +%s)
	local duration=$((end_time - start_time))

	echo ""
	echo "======================================================================="
	echo "                    SETUP COMPLETED SUCCESSFULLY!"
	echo "======================================================================="
	log_success "🎉 Complete Jito Restaking Network setup finished successfully!"
	log_success "⏱️  Total execution time: ${duration} seconds"
	log_info "📋 Detailed setup summary available in: setup_summary.txt"
	log_info "📝 Command execution logs available in: logs/commands.log"

	# Display comprehensive summary from generated file
	echo ""
	if [[ -f "setup_summary.txt" ]]; then
		cat setup_summary.txt
	else
		log_warning "Setup summary file not found, but setup completed successfully"
	fi

	echo ""
	echo "🚀 Your Jito Restaking Network is ready for testing and development!"
	echo "======================================================================="
}

# Run main function
main "$@"
