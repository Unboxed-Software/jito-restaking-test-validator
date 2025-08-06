# Jito Restaking Protocol Test Environment

## 📋 Prerequisites

Before running this environment, ensure you have the following installed:

### 1. Rust Programming Language

```bash
# Install Rust and Cargo (minimum version 1.81)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Verify installation
rustc --version
cargo --version
```

### 2. Solana CLI Tools

```bash
# Install Solana CLI (minimum version 1.16)
sh -c "$(curl -sSfL https://release.solana.com/v1.18.26/install)"

# Add to PATH (add this to your shell profile)
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Verify installation
solana --version
```

### 3. SPL Token CLI

```bash
# Install SPL Token CLI
cargo install spl-token-cli

# Verify installation
spl-token --version
```

### 4. Jito Restaking CLI

```bash
# Clone the Jito Restaking repository
git clone https://github.com/jito-foundation/restaking.git
cd restaking

# Build and install the CLI tool
cargo build --release
cargo install --path ./cli --bin jito-restaking-cli

# Verify installation
jito-restaking-cli --version
```

### 5. Additional Tools

```bash
# Install screen (for running validator in background)
# macOS
brew install screen

# Ubuntu/Debian
sudo apt-get install screen

# Verify installation
screen --version
```

## 🚀 Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/Unboxed-Software/jito-restaking-test-validator.git
cd jito-restaking-test-validator
chmod +x *.sh
```

### 2. Run the Complete Setup

```bash
./run.sh
```

This single command will:

1. Start the Solana test validator with all required programs
2. Initialize the complete restaking network
3. Set up 3 operators with proper handshakes
4. Create a vault and delegate tokens
5. Advance the validator by two epochs for all the connections to warm-up

## 📁 Repository Structure

```
├── README.md                    # This documentation
├── docs.md                     # Detailed setup documentation
├── run.sh                      # Main orchestration script
├── validator.sh                # Solana test validator startup
├── rerun-validator.sh          # Time advancement script
├── setup-testing-env.sh        # Complete network initialization
├── programs/                   # Solana program binaries
│   ├── jito_restaking.so       # Main restaking program
│   ├── jito_vault.so           # Vault management program
│   ├── spl_account_compression.so
│   ├── spl_associated_token_account.so
│   └── spl_noop.so
```

## 🔧 Script Details

### `run.sh` - Main Orchestration

The primary script that coordinates the entire setup process:

1. **Validator Startup**: Launches `validator.sh` in a screen session
2. **Health Check**: Waits for validator to be ready and responding
3. **Environment Setup**: Runs `setup-testing-env.sh` to initialize the network
4. **Stabilization**: Allows 30 seconds for transaction finalization
5. **Time Advancement**: Uses `rerun-validator.sh` to jump forward one epoch

### `validator.sh` - Solana Test Validator

Configures and starts the Solana test validator with:

- Connection to mainnet for account cloning
- Pre-loaded Jito restaking and vault programs
- SPL programs (token, compression, noop)
- Fresh ledger state with `--reset` flag

### `setup-testing-env.sh` - Network Initialization

Comprehensive setup script that:

- Validates environment prerequisites
- Generates Solana and BN254 keypairs for all components
- Initializes NCN with proper configuration
- Creates and initializes 3 operators
- Sets up SPL token and vault
- Performs complete opt-in handshake process
- Delegates tokens to operators

### `rerun-validator.sh` - Time Simulation

Utility script for testing time-dependent functionality:

- Gets current validator slot
- Kills existing validator process
- Restarts validator at a future slot position
- Effectively "jumps forward" in time without waiting

## 🔑 Generated Assets

After successful execution, you'll have:

### Keypairs

- **NCN Admin**: `./keys/ncn/ncn-admin.json`
- **Vault Admin**: `./keys/vault/vault-admin.json`
- **Operator Admins**: `./keys/operators/operator{1,2,3}-admin.json`
- **BN254 Keypairs**: For cryptographic operations (private keys and public key sets)

### Addresses

All important addresses are saved in `setup_summary.txt`:

- NCN Address
- Vault Address
- Token Address
- Individual Operator Addresses

## 🧪 Testing and Development

### Using the Environment

Once setup is complete, you can:

1. **Query Network State**:

   ```bash
   # Check validator status
   solana cluster-version -ul
   
   # Check account balances
   solana balance -ul
   ```

3. **Test Time-Dependent Features**:

   ```bash
   # Advance by specific number of slots
   ./rerun-validator.sh 100000  # ~100k slots forward
   
   # Advance by full epoch
   ./rerun-validator.sh 432000  # ~1 epoch forward
   ```

## 🚨 Troubleshooting

### Common Issues

**Validator Won't Start**

- Check if port 8899 is available: `lsof -i :8899`
- Ensure programs exist in `./programs/` directory
- Check validator logs in `./test-ledger/validator.log`
- Kill any existing validator processes: `pkill -f solana-test-validator`

**Time Advancement Issues**

- Ensure validator is running before calling `rerun-validator.sh`
- Check if `solana slot -ul` returns valid number
- Verify RPC connection with `solana cluster-version -ul`
- Re run the script

### Log Files

- **Validator Logs**: `./test-ledger/validator.log`
- **Command Logs**: `./logs/commands.log`
- **Setup Summary**: `./setup_summary.txt`

## 📖 Additional Resources

- [Jito Restaking Documentation](https://jito-foundation.gitbook.io/restaking)
- [Solana Documentation](https://docs.solana.com/)
- [Jito Foundation GitHub](https://github.com/jito-foundation/restaking)

