# Getting Started

## Prerequisites

Before building your Node Consensus Network (NCN), you'll need:

- A Unix-based operating system (macOS, Linux)
- Rust and Cargo installed (minimum version 1.81)
- Solana CLI tools (minimum version 1.16)
- SPL Token CLI (`spl-token-cli`)
- Basic familiarity with Solana program development
- A local test validator environment (airdrop will fund accounts locally)

## Quick Start (Automatic Local Setup)

To bootstrap a complete local environment (validator + configs + NCN + 3 operators + token + vault + handshakes + delegations), run:

```bash
./run.sh
```

See `README.md` for details about what this script does and the generated artifacts (for example, `setup_summary.txt` and `handshake_commands.sh`).

## Install the Jito Restaking CLI

The `jito-restaking-cli` is your primary tool for managing NCNs, Vaults, and Operators. Install it from source:

```bash
# Clone the repository
git clone https://github.com/jito-foundation/restaking.git

# Navigate to the project directory
cd restaking

# Build and install the CLI tool
cargo build --release
cargo install --path ./cli --bin jito-restaking-cli
```

Verify installation with:

```bash
jito-restaking-cli --version
```

You should see a version string printed, confirming successful installation.

## Configure Your Solana Environment

Set up your Solana CLI to work with a local test validator:

```bash
# Configure Solana CLI to use the local test validator
solana config set --url l

# Check your configuration
solana config get
```

Fund your wallet with local SOL:

```bash
# Request an airdrop (can be repeated if needed)
solana airdrop 100
```

## Initialize Program Configs (once per cluster)

Initialize the program configs used by the CLI:

```bash
jito-restaking-cli restaking config initialize
jito-restaking-cli vault config initialize 100 3ogGQ7nFX6nCa9bkkZ6hwud6VaEQCekCCmNj6ZoWh8MF
```

# Creating Admin Keypairs

You will be creating new on-chain accounts (NCN, Vault, Operator). These are program-derived accounts with specific seeds and bump values, but they are controlled by your wallet as the admin. It's best to generate vanity keypairs for each role so you can easily identify them.

Generate keypairs using the following commands:

### NCN Admin Keypair

This keypair will control your Node Consensus Network and define the rules of your off-chain service. The NCN admin has authority to add/remove supported Vaults and Operators, set slashing conditions, and manage network parameters.

```bash
solana-keygen new --outfile "keys/ncn/ncn-admin.json" --no-bip39-passphrase
solana airdrop 100 --keypair "keys/ncn/ncn-admin.json"
```

### Vault Admin Keypair

This keypair will control your Vault account, which manages staked tokens and issues VRTs. The Vault admin decides which NCNs to support and which Operators receive stake delegations. They also manage token deposits/withdrawals and enforce slashing conditions.

```bash
solana-keygen new --outfile "keys/vault/vault-admin.json" --no-bip39-passphrase
solana airdrop 100 --keypair "keys/vault/vault-admin.json"
```

### Operator Admin Keypair

This keypair represents a node runner in your network. The Operator admin controls which NCNs they serve and which Vaults they accept stake from. They also manage their operator fee and withdrawal of rewards. This account is typically linked to a Solana validator through its voter key.

```bash
solana-keygen new --outfile "keys/operators/operator1-admin.json" --no-bip39-passphrase
solana-keygen new --outfile "keys/operators/operator2-admin.json" --no-bip39-passphrase
solana-keygen new --outfile "keys/operators/operator3-admin.json" --no-bip39-passphrase
solana airdrop 100 --keypair "keys/operators/operator1-admin.json"
solana airdrop 100 --keypair "keys/operators/operator2-admin.json"
solana airdrop 100 --keypair "keys/operators/operator3-admin.json"
```

## Initializing On-Chain Accounts

After creating your admin keypairs, the next step is to initialize the actual on-chain accounts for your Node Consensus Network (NCN), Operators, and Vault. These accounts will form the backbone of your restaking ecosystem.

### Understanding Account Initialization

Before creating your components, it's important to understand the relationship between them:

1. **NCNs**, **Vaults**, and **Operators** are on-chain program accounts PDAs
2. Each account has one or more admin authorities that control it
3. These accounts don't directly hold funds (except for Vaults, which custody staked assets)
4. They primarily serve as registries and coordination points in the restaking ecosystem

In the next sections, we'll walk through initializing each component individually, then connecting them through the "opt-in handshake" process.

### Initialize Your NCN

The NCN account defines the rules and governance of your off-chain network. It will track which Operators and Vaults are part of your ecosystem.

```bash
jito-restaking-cli restaking ncn initialize --signer ./keys/ncn/ncn-admin.json
```

This command creates your NCN account. Please note that the Vault and Operator admin addresses returned here are onchain admin addresses set in the NCN account. They are not the same as the user keypairs used to register operators/vaults.

After successful initialization, the CLI will output your NCN information. For example:

```bash

[2025-04-27T16:54:19Z INFO  jito_restaking_cli::restaking_handler] Initializing NCN: C5xRZSJM2nQf2X67eyNrjVXey3FUc41UN1LbSiiuPX73
[2025-04-27T16:54:35Z INFO  jito_restaking_cli] Transaction confirmed: PA4YsCTCB7Vc7c6PDsdX9tzfaPnmGE9NtDgNx57tzqszKTnWG5HW9sv29pgbwQATKFQSWL3Dr2o8o3QyB5CNPky
[2025-04-27T16:54:35Z INFO  jito_restaking_cli::restaking_handler] 
Ncn Account
    
    ━━━ Basic Information ━━━
      Base: ExA9bvbfYxDHUaqHSpHE1DT9MMp962XC1JjokQXNdKZh
      Index: 278
      Bump: 255
    
    ━━━ Admin Authorities ━━━
      Admin: ncnNJKxwFrQZryGuca1LjEKPfgKsrRqfQKR58SbCptE
      Operator Admin: ncnNJKxwFrQZryGuca1LjEKPfgKsrRqfQKR58SbCptE
      Vault Admin: ncnNJKxwFrQZryGuca1LjEKPfgKsrRqfQKR58SbCptE
      Slasher Admin: ncnNJKxwFrQZryGuca1LjEKPfgKsrRqfQKR58SbCptE
      Delegate Admin: ncnNJKxwFrQZryGuca1LjEKPfgKsrRqfQKR58SbCptE
      Metadata Admin: ncnNJKxwFrQZryGuca1LjEKPfgKsrRqfQKR58SbCptE
      Weight Table Admin: ncnNJKxwFrQZryGuca1LjEKPfgKsrRqfQKR58SbCptE
      NCN Program Admin: ncnNJKxwFrQZryGuca1LjEKPfgKsrRqfQKR58SbCptE
    
    ━━━ Statistics ━━━
      Operator Count: 0
      Vault Count: 0
      Slasher Count: 0
```

Take note of the address listed here: `Initializing NCN: C5xRZSJM2nQf2X67eyNrjVXey3FUc41UN1LbSiiuPX73`. This is the NCN PDA or the **NCN Account Address**, you will need this accounts later.

### Initialize Your Operators

Operators are the entities that run nodes for your network. Each Operator account tracks its participation in various NCNs and the stake it receives from Vaults.

```bash
jito-restaking-cli restaking operator initialize 1000 --signer ./keys/operators/operator1-admin.json
```

The parameter `1000` represents the operator fee in basis points (10%). This is the percentage of rewards the operator will take for running nodes in your network.

Similar to the previous initialization, the Vault and Operator admin addresses returned here are onchain admin addresses set in the NCN account.

After initialization, the CLI will output your Operator information, for example:

```bash
[2025-04-27T17:03:09Z INFO  jito_restaking_cli::restaking_handler] Initializing Operator: 4tCqA4TcZinAtCcyyZNSMTcF8SrBypQakUw91qHicdwJ
[2025-04-27T17:03:11Z INFO  jito_restaking_cli] Transaction confirmed: SbUwaY9BniwrPCsUqqidLkg6ZUeuwMeRPkdu3JMvPTsdjqBXhg2ZoTLWoCgFA7aZwe11Y23kdVVyZ79wyYR4Gon
[2025-04-27T17:03:11Z INFO  jito_restaking_cli::restaking_handler] 
Operator Account
    
    ━━━ Basic Information ━━━
      Base: 7tTw8pzgXvfdSRetg9RCuQGD4n2wbRJJMtaZNYKU51RM
      Index: 381
      Bump: 250
    
    ━━━ Admin Authorities ━━━
      Admin: opeye8FCeGQoAJWoXRMj5H76AjHRpgrdsAHV738DEtk
      NCN Admin: opeye8FCeGQoAJWoXRMj5H76AjHRpgrdsAHV738DEtk
      Vault Admin: opeye8FCeGQoAJWoXRMj5H76AjHRpgrdsAHV738DEtk
      Delegate Admin: opeye8FCeGQoAJWoXRMj5H76AjHRpgrdsAHV738DEtk
      Metadata Admin: opeye8FCeGQoAJWoXRMj5H76AjHRpgrdsAHV738DEtk
      Voter: opeye8FCeGQoAJWoXRMj5H76AjHRpgrdsAHV738DEtk
    
    ━━━ Statistics ━━━
      NCN Count: 0
      Vault Count: 0
      Operator Fee BPS: 1000
```

Take note: `Initializing Operator: 4tCqA4TcZinAtCcyyZNSMTcF8SrBypQakUw91qHicdwJ`, This is the **Operator Account Address**, you will need this accounts later.

You can initialize multiple Operators for your network, each with its own admin keypair and fee structure.

### Initialize Your Vault

Before initializing a Vault, you need a token that it will manage.

For development purposes, you can create a new SPL token:

```bash
spl-token create-token
```

This will output your token's address, for example:

```bash
Creating token EiH4TYMKcuLTRCauE3YS1psRZjgqcdNhCDRbQDHmTFvi under program TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA

Address:  EiH4TYMKcuLTRCauE3YS1psRZjgqcdNhCDRbQDHmTFvi
Decimals:  9

Signature: 66F2h4jEt8ykDXd6uT44CTrzZHvpYFNbzSkc6dsYveAvpx9iHS4bHFCXpM5i7StZjZLwC4recb6nukAgvw64JiZG
```

---

Next, you need to set up your Vault’s token account and mint tokens to it.

First, create the Vault’s associated token account (ATA):

```bash
spl-token create-account <TOKEN_ADDRESS> \
  --owner ./keys/vault/vault-admin.json \
  --fee-payer ~/.config/solana/id.json
```

Then mint tokens into the Vault's token account:

```bash
spl-token mint <TOKEN_ADDRESS> 100 \
  --recipient-owner ./keys/vault/vault-admin.json \
  --fee-payer ~/.config/solana/id.json

```

You should also make sure the Vault’s keypair has enough SOL to cover transaction fees:

```bash
solana transfer ./keys/vault/vault-admin.json 0.01 \
  --from ~/.config/solana/id.json \
  --allow-unfunded-recipient
```

---

Now you can initialize the Vault:

```bash
jito-restaking-cli \
    --signer ./keys/vault/vault-admin.json \
    vault vault initialize '<TOKEN_ADDRESS>' 1000 1000 1000 9 1000000000
```

The parameters are:

- `<TOKEN_ADDRESS>`: Your SPL token address
- Deposit fee in basis points (10%)
- Withdrawal fee in basis points (10%)
- Reward fee in basis points (10%)
- Token decimals (9)
- Initial token amount to lock in the Vault in the smallest unit (e.g., 1 token with 9 decimals is `1_000_000_000`)

---

The CLI will output key Vault information:

- **Vault Address**: Where your vault state lives, take a note of this address **(Vault Account Address)**, you will need it later
- **VRT Token Mint**: The new SPL token that represents shares in your vault
- **Supported Mint**: The original token your vault is managing
- **Tokens Deposited**: How many tokens initially locked
- **Admin Addresses**: (Admin, Operator Admin, Fee Admin, etc.)

```
Vault Address: 2EfCBXdAME796aD6geSAvVV8vFffCCjyfNPedkTibR1z
VRT Mint: 7Tp2Ss5cdpZU9XXdUoCLZQm7qNPD4c9QRazGE35bipFd
Supported Mint: EiH4TYMKcuLTRCauE3YS1psRZjgqcdNhCDRbQDHmTFvi
Tokens Deposited: 100000000000
Deposit Fee BPS: 1000
Withdrawal Fee BPS: 1000
Reward Fee BPS: 1000
Admin Address: vaucPnwnvyEvyQHSgjr3m7oqGZXC5tLdvhvimnqHkfj
```

You’ll also see a full breakdown of additional fields like:

- NCN Count
- Operator Count
- Staked Amount
- Cooling Down Amount
- Fee Admin
- Program Fee

---

### What Happens During Initialization?

When you initialize these accounts:

1. **Vault Initialization**:

    Creates a program-derived account (PDA) that holds your Vault's state, initializes a new VRT token mint, and locks the initial token amount into the Vault.

2. **VRT Token Mint**:

    Mints the Vault Receipt Token that users will receive when they deposit assets into your Vault.

### Next Steps: The Opt-In Handshake

After initializing all three components, they need to establish relationships with each other through an "opt-in handshake" process. This ensures that all participants explicitly consent to work together.

## Opt-In Handshake Process

After registering your NCN, Operators, and Vault, the next step is establishing secure connections between these components. The opt-in handshake ensures that all parties explicitly consent to working together, creating a network of trust.

## Overview of the Handshake Process

The handshake happens in several stages:

1. NCN establishes connections with Operators and Vaults
2. Operators establish connections with the NCN and Vaults
3. Vaults establish connections with the NCN and Operators

Each connection requires initialization and then a "warm up" activation step to complete.

> **Note:** Throughout this handshake process, you'll see `<VAULT_ADDRESS>` used as a placeholder. This should be replaced with the actual vault address that's generated during vault initialization (example: '4wmTjgjB4SDgh4mxUtmpYhoGqFi9ECNZmdmuEH7K99JA'). This address is different from the vault admin keypair's public key.

## NCN Opt-ins

### NCN to Operator Connections

First, initialize the connection state between your NCN and each Operator:

```bash
# Initialize NCN Operator State
jito-restaking-cli restaking ncn initialize-ncn-operator-state \
    "<NCN_ACCOUNT_ADDRESS>" \
    "<OPERATOR_ACCOUNT_ADDRESS>" \
    --signer ./keys/ncn/ncn-admin.json # NCN Admin keypair
```

You will see something similar to this returned:

```bash
[2025-04-27T17:06:56Z INFO  jito_restaking_cli::restaking_handler] Initializing NCN Operator State
[2025-04-27T17:06:58Z INFO  jito_restaking_cli] Transaction confirmed: 2MRpcgVYwrW3D1eUX5D2qk6NcUjJKC6gGxQ77FWCAknBVNdtL3J2QKtJxiNkyP4kq2pE9qDPgH9YmxQtckeHNrC6
[2025-04-27T17:06:58Z INFO  jito_restaking_cli::restaking_handler] 
    Ncn Operator State Account
    
    ━━━ Basic Information ━━━
      NCN: C5xRZSJM2nQf2X67eyNrjVXey3FUc41UN1LbSiiuPX73
      Operator: 4tCqA4TcZinAtCcyyZNSMTcF8SrBypQakUw91qHicdwJ
      Index: 0
      Bump: 255
    
    ━━━ NCN State ━━━
      NCN Opt-In Added: 336284366
      NCN Opt-In Removed: 336284366
    
    ━━━ Operator State ━━━
      Operator Opt-In Added: 336284366
      Operator Opt-In Removed: 336284366
```

Next, warm up (activate) the connection:

```bash
# Warm Up NCN Operator State
jito-restaking-cli \
    restaking ncn ncn-warmup-operator \
    "<NCN_ACCOUNT_ADDRESS>" \   # NCN PDA (the actual NCN account)
    "<OPERATOR_ACCOUNT_ADDRESS>" \   # Operator PDA (the actual Operator account)
    --signer ./keys/ncn/ncn-admin.json   # NCN Admin keypair (signer)
```

You will see something similar to this returned:

```bash
[2025-04-27T17:08:24Z INFO  jito_restaking_cli::restaking_handler] NCN Warmup Operator
[2025-04-27T17:08:26Z INFO  jito_restaking_cli] Transaction confirmed: Bqh9t63QoEx6HQxrxHSqoiEmPJgZNVxLQ3ZN4aaivTsTAT1k6joJghLpMBnpLy1xuem537ahpStuj3ypmrUT7B7
[2025-04-27T17:08:27Z INFO  jito_restaking_cli::restaking_handler] 
    Ncn Operator State Account
    
    ━━━ Basic Information ━━━
      NCN: C5xRZSJM2nQf2X67eyNrjVXey3FUc41UN1LbSiiuPX73
      Operator: 4tCqA4TcZinAtCcyyZNSMTcF8SrBypQakUw91qHicdwJ
      Index: 0
      Bump: 255
    
    ━━━ NCN State ━━━
      NCN Opt-In Added: 336284596
      NCN Opt-In Removed: 336284366
    
    ━━━ Operator State ━━━
      Operator Opt-In Added: 336284366
      Operator Opt-In Removed: 336284366
```

### NCN to Vault Connection

Initialize the connection between your NCN and Vault:

```bash
jito-restaking-cli \
    restaking ncn initialize-ncn-vault-ticket \
    "<NCN_ACCOUNT_ADDRESS>" \ # NCN PDA (the actual NCN account)
    "<VAULT_ACCOUNT_ADDRESS>" \ # Vault PDA (the actual Vault account)
    --signer ./keys/ncn/ncn-admin.json # NCN Admin keypair (signer)
```

Warm up (activate) the connection:

```bash
jito-restaking-cli \
    restaking ncn warmup-ncn-vault-ticket \
    "<NCN_ACCOUNT_ADDRESS>" \ 
    "<VAULT_ACCOUNT_ADDRESS>" \ 
    --signer ./keys/ncn/ncn-admin.json # NCN Admin keypair (signer)

```

## Operator Opt-ins

### Operator to NCN Connections

Warm up the connection from the Operator's side:

```bash
jito-restaking-cli \
    restaking operator operator-warmup-ncn \
    "<OPERATOR_ACCOUNT_ADDRESS>" \
    "<NCN_ACCOUNT_ADDRESS>" \ 
    --signer <OPERATOR_ADMIN_KEYPAIR> # e.g., ./keys/operators/operator1-admin.json
```

### Operator to Vault Connections

Initialize the connection between Operator and Vault:

```bash
jito-restaking-cli \
    restaking operator initialize-operator-vault-ticket \
    "<OPERATOR_ACCOUNT_ADDRESS>" \
    "<VAULT_ACCOUNT_ADDRESS>" \ 
    --signer <OPERATOR_ADMIN_KEYPAIR> # e.g., ./keys/operators/operator1-admin.json
```

Warm up the connection:

```bash
jito-restaking-cli \
    restaking operator warmup-operator-vault-ticket \
    "<OPERATOR_ACCOUNT_ADDRESS>" \
    "<VAULT_ACCOUNT_ADDRESS>" \ 
    --signer <OPERATOR_ADMIN_KEYPAIR> # e.g., ./keys/operators/operator1-admin.json
```

## Vault Opt-ins

### Vault to NCN Connection

Initialize the connection between Vault and NCN:

```bash
jito-restaking-cli \                                       
    vault vault initialize-vault-ncn-ticket \
    "<VAULT_ACCOUNT_ADDRESS>" \
    "<NCN_ACCOUNT_ADDRESS>" \
    --signer ./keys/vault/vault-admin.json # Vault Admin Keypair
```

Warm up the connection:

```bash
jito-restaking-cli \
    vault vault warmup-vault-ncn-ticket \
    "<VAULT_ACCOUNT_ADDRESS>" \
    "<NCN_ACCOUNT_ADDRESS>" \
    --signer ./keys/vault/vault-admin.json # Vault Admin Keypair
```

### Vault to Operator Connections

Before delegating assets, prepare the token infrastructure (assuming you have a working vault):

```bash
# Create an Associated Token Account (ATA) of your token for your local wallet
spl-token create-account "<TOKEN_ADDRESS>"

# output: Creating account FaY23zYBHDhLAxaBtmMawWeRfinRj2VVnmgGg4gy4y8k

# output: Signature: 4rZriwz2vPgHdiPUEA4qcwQAyKVxfQmKeBu264TX1xpiz8RPT1pcd2Ukp9TxxP5gNQm3i9BnGRcYxHkZMgFB5wjp

# Mint tokens for your local wallet
spl-token mint "<TOKEN_ADDRESS>" 3000

# Mint Vault Receipt Tokens (VRTs) (i.e deposit stake to the vault)
jito-restaking-cli vault vault mint-vrt "<VAULT_ADDRESS>" 3000000000000 0

# Update the vault balance before operator delegations
jito-restaking-cli vault vault update-vault-balance "<VAULT_ADDRESS>" --signer ./keys/vault/vault-admin.json
```

The parameters are:

- `<VAULT_ADDRESS>`: the vault that you want to deposit to, in this case the vault that you initiated earlier
- Amount of the deposit in the smallest token unite (so for 3000 tokens of 9 decimals it will be 3_000_000_000_000)
- Minimum amount of VRT out

Notice that we didn’t include a signer here, because your local wallet is suppose to deposit this amount of tokens to the vault

Initialize delegation to an Operator:

```bash
# Initialize Operator Delegation
jito-restaking-cli \
    vault vault initialize-operator-delegation \
    "<VAULT_ACCOUNT_ADDRESS>" \
    "<OPERATOR_ACCOUNT_ADDRESS>" \
    --signer ./keys/vault/vault-admin.json
```

Results:

```bash
[2025-04-28T14:58:29Z INFO  jito_restaking_cli::vault_handler] Initializing vault operator delegation
[2025-04-28T14:58:31Z INFO  jito_restaking_cli] Transaction confirmed: FfbXgWZdmpnMGJMbjv8euSqTUjHNwFkaSUx7YHStDUe9knX6mLYt1jVACkE3zANFMTJkgsJgUBzoofzHKnrEJ4x
[2025-04-28T14:58:31Z INFO  jito_restaking_cli::vault_handler] 
    Vault Operator Delegation Account
    
    ━━━ Basic Information ━━━
      Vault: 2EfCBXdAME796aD6geSAvVV8vFffCCjyfNPedkTibR1z
      Operator: 4tCqA4TcZinAtCcyyZNSMTcF8SrBypQakUw91qHicdwJ
      Last Update Slot: 336483046
      Index: 0
      Bump: 254
    
    ━━━ Delegation State ━━━
      Enqueued for Cooldown Amount: 0
      Cooling Down Amount: 0
      Staked Amount: 0
```

Finally, delegate actual tokens to the Operator:

```bash
# Delegate To Operator
jito-restaking-cli \
    vault vault delegate-to-operator \
    "<VAULT_ACCOUNT_ADDRESS>" \
    "<OPERATOR_ACCOUNT_ADDRESS>" \
    500000000000 \
    --signer ./keys/vault/vault-admin.json
```

The parameters are:

- `<VAULT_ADDRESS>`: the vault that you will delegate stake, in this case the vault that you initiated earlier
- `<OPERATOR_ADDRESS>`: the operator that you want to delegate to, in this case the operator that you initiated earlier
- Amount in the smallest token unit (for 500 tokens with 9 decimals it is `500_000_000_000`)

Results:

```bash
[2025-04-28T15:00:11Z INFO  jito_restaking_cli::vault_handler] Delegating to operator
[2025-04-28T15:00:16Z INFO  jito_restaking_cli] Transaction confirmed: tCKYXr7w43WudBjeKUtb6BXLbSnceeSGgqJg1wpseUZirtjAmQgKAuYcNavVQ6Aw4eKKP2ZLJKdYMnvewQvhx74
[2025-04-28T15:00:16Z INFO  jito_restaking_cli::vault_handler] 
    Vault Operator Delegation Account
    
    ━━━ Basic Information ━━━
      Vault: 2EfCBXdAME796aD6geSAvVV8vFffCCjyfNPedkTibR1z
      Operator: 4tCqA4TcZinAtCcyyZNSMTcF8SrBypQakUw91qHicdwJ
      Last Update Slot: 336483046
      Index: 0
      Bump: 254
    
    ━━━ Delegation State ━━━
      Enqueued for Cooldown Amount: 0
      Cooling Down Amount: 0
      Staked Amount: 100
    
[2025-04-28T15:00:16Z INFO  jito_restaking_cli::vault_handler] Delegated 100 tokens to 4tCqA4TcZinAtCcyyZNSMTcF8SrBypQakUw91qHicdwJ

```

## Understanding the Handshake Process

This multi-step opt-in process ensures that:

1. **Mutual Consent**: All three parties (NCN, Operator, and Vault) must explicitly agree to work together
2. **Security by Design**: No component can unilaterally force another to participate
3. **Clear Boundaries**: The initialization and warm-up steps create distinct on-chain records of these relationships
4. **Flexible Participation**: Components can participate in multiple relationships (e.g., one Operator can serve multiple NCNs)

This handshake architecture allows for a dynamic ecosystem where:

- NCNs can support multiple tokens through different vaults
- Operators can serve multiple NCNs simultaneously
- Vaults can delegate to different operators based on performance or other criteria

## Troubleshooting Handshake Issues

If you encounter errors during the handshake process:

1. **Check Account Existence**: Ensure all accounts exist and were properly initialized
2. **Verify Addresses**: Double-check that you're using the correct addresses for each component
3. **Sequence Matters**: Follow the initialization and warm-up steps in the correct order
4. **Funding**: Ensure all accounts have sufficient SOL for transaction fees

## Next Steps

- For a fully automated local workflow, use `./run.sh` (see `README.md`).
- Review generated artifacts like `setup_summary.txt` and `handshake_commands.sh` for addresses and exact commands used by the scripts.
