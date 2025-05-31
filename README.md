# Decentralized Impact-Driven Fund Management Contract

A comprehensive Clarity smart contract for milestone-based funding and transparent resource allocation on the Stacks blockchain. This contract enables decentralized project funding with staged releases, multi-recipient distributions, and robust security mechanisms.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Contract Architecture](#contract-architecture)
- [Installation & Deployment](#installation--deployment)
- [Usage Guide](#usage-guide)
- [API Reference](#api-reference)
- [Security Features](#security-features)
- [Error Codes](#error-codes)
- [Examples](#examples)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Overview

The Decentralized Impact-Driven Fund Management Contract provides a transparent, milestone-based funding mechanism for projects. Contributors can allocate funds that are released incrementally as recipients complete predefined project stages, ensuring accountability and reducing risk.

### Key Benefits

- **Milestone-Based Releases**: Funds released incrementally based on project progress
- **Transparent Allocation**: All funding activities recorded on-chain
- **Multi-Recipient Support**: Split funds across multiple recipients
- **Emergency Recovery**: Dual-approval emergency fund recovery
- **Rate Limiting**: Protection against spam and abuse
- **Comprehensive Audit Trail**: Complete transaction history

## Features

### Core Functionality

#### 🎯 Milestone-Based Funding
- Create resource allocations with predefined project stages
- Stage-by-stage fund release upon administrator approval
- Automatic expiration handling for incomplete projects
- Contributor cancellation with proportional refunds

#### 🔄 Multi-Recipient Distribution
- Split allocations across up to 5 recipients
- Percentage-based distribution (must total 100%)
- Individual recipient validation
- Separate tracking for split allocations

#### ⏰ Time Management
- Configurable project durations (~7 days default)
- Extension capabilities for active projects
- Automatic expiration with refund mechanisms
- Time-bound delegation system

### Advanced Features

#### 🚨 Emergency Recovery
- Dual-approval emergency fund recovery
- Administrator and contributor consent required
- Detailed recovery reason tracking
- Prevents double-spending attacks

#### 📊 Progress Tracking
- Detailed stage progress reporting
- Evidence hash storage for verification
- Progress percentage tracking (0-100%)
- Recipient-controlled progress updates

#### 👥 Delegation System
- Delegate allocation control to trusted parties
- Granular permission system (cancel/extend/increase)
- Time-bound delegations
- Original contributor retains ultimate control

#### 🛡️ Rate Limiting
- Maximum 5 allocations per 24-hour window
- Prevents spam and resource exhaustion
- Contributor-specific tracking
- Automatic window reset

### Security & Administration

#### 🔐 Access Control
- Role-based permissions (Administrator/Contributor/Recipient)
- Secure principal validation
- Authorization checks on all operations
- Contract operational state management

#### 💰 Financial Security
- Comprehensive STX transfer error handling
- Escrow-based fund management
- Precise mathematical calculations
- No loss of funds scenarios

## Contract Architecture

### Data Structures

```clarity
;; Primary resource allocation tracking
ResourceAllocations: {
  resource-id: uint,
  contributor: principal,
  recipient: principal,
  total-amount: uint,
  status: string-ascii,
  creation-timestamp: uint,
  expiration-timestamp: uint,
  project-stages: list,
  approved-stages: uint
}

;; Multi-recipient distribution
SplitResourceAllocations: {
  split-allocation-id: uint,
  contributor: principal,
  recipients: list,
  total-contribution: uint,
  creation-timestamp: uint,
  status: string-ascii
}

;; Emergency recovery system
EmergencyRestorationRequests: {
  resource-id: uint,
  administrator-approved: bool,
  contributor-approved: bool,
  restoration-reason: string-ascii
}
```

### Contract Constants

- `PROJECT_DURATION`: 1008 blocks (~7 days)
- `MAX_DISTRIBUTION_RECIPIENTS`: 5 recipients maximum
- `RATE_LIMIT_WINDOW`: 144 blocks (~24 hours)
- `MAX_ALLOCATIONS_PER_WINDOW`: 5 allocations per window
- `MAX_DURATION_EXTENSION`: 1008 blocks maximum extension

## Installation & Deployment

### Prerequisites

- Clarinet CLI installed
- Stacks wallet with STX for gas fees
- Access to Stacks testnet/mainnet

### Deployment Steps

1. **Clone the repository**
```bash
git clone https://github.com/your-org/decentralized-milestone-funding
cd decentralized-milestone-funding
```

2. **Initialize Clarinet project**
```bash
clarinet new milestone-funding
cd milestone-funding
```

3. **Add the contract**
```bash
# Copy the contract file to contracts/
cp ../decentralized-funding.clar contracts/
```

4. **Configure deployment**
```toml
# Clarinet.toml
[contracts.decentralized-funding]
path = "contracts/decentralized-funding.clar"
```

5. **Deploy to testnet**
```bash
clarinet deploy --testnet
```

## Usage Guide

### Basic Workflow

1. **Create Resource Allocation**
   - Contributor creates allocation with recipient and stages
   - Funds are escrowed in the contract
   - Project timer begins

2. **Track Progress**
   - Recipient reports stage progress
   - Evidence and details recorded on-chain
   - Administrator validates completed stages

3. **Release Funds**
   - Administrator approves completed stages
   - Funds released proportionally
   - Process repeats until completion

4. **Handle Completion/Expiration**
   - Successful completion: All funds released
   - Expiration: Remaining funds refunded
   - Cancellation: Proportional refund issued

### Quick Start Example

```clarity
;; 1. Create a 3-stage project allocation
(contract-call? .decentralized-funding launch-resource-allocation
  'SP1EXAMPLE...RECIPIENT
  u1000000  ;; 1 STX in microSTX
  (list u1 u2 u3))  ;; Three project stages

;; 2. Report progress (as recipient)
(contract-call? .decentralized-funding report-stage-progress
  u1        ;; resource-id
  u0        ;; stage-index
  u100      ;; 100% complete
  "Stage 1: MVP development completed"
  0x1234...)  ;; evidence hash

;; 3. Validate stage (as administrator)
(contract-call? .decentralized-funding validate-project-stage u1)
```

## API Reference

### Public Functions

#### Resource Management

##### `launch-resource-allocation`
Creates a new milestone-based resource allocation.

**Parameters:**
- `recipient: principal` - Project recipient address
- `amount: uint` - Total allocation amount in microSTX
- `project-stages: (list 5 uint)` - List of project stage identifiers

**Returns:** `(response uint uint)` - Resource ID on success

**Example:**
```clarity
(launch-resource-allocation 'SP1ABC...XYZ u5000000 (list u1 u2 u3))
```

##### `validate-project-stage`
Approves a completed project stage and releases funds.

**Parameters:**
- `resource-id: uint` - Allocation identifier

**Returns:** `(response bool uint)` - Success confirmation

**Restrictions:** Administrator only

##### `cancel-resource-allocation`
Cancels allocation and refunds remaining funds.

**Parameters:**
- `resource-id: uint` - Allocation identifier

**Returns:** `(response bool uint)` - Success confirmation

**Restrictions:** Contributor only, before expiration

#### Multi-Recipient Distribution

##### `create-split-resource-allocation`
Creates allocation split across multiple recipients.

**Parameters:**
- `recipients: (list 5 {recipient: principal, allocation-percentage: uint})` - Recipient list with percentages
- `total-amount: uint` - Total allocation amount

**Returns:** `(response uint uint)` - Split allocation ID

**Requirements:** Percentages must sum to 100

#### Progress Tracking

##### `report-stage-progress`
Reports progress on a specific project stage.

**Parameters:**
- `resource-id: uint` - Allocation identifier
- `stage-index: uint` - Stage index (0-based)
- `progress-percentage: uint` - Completion percentage (0-100)
- `stage-details: (string-ascii 200)` - Progress description
- `evidence-hash: (buff 32)` - Evidence verification hash

**Returns:** `(response bool uint)` - Success confirmation

**Restrictions:** Recipient only

#### Emergency Operations

##### `emergency-allocation-recovery`
Initiates emergency fund recovery process.

**Parameters:**
- `resource-id: uint` - Allocation identifier
- `restoration-reason: (string-ascii 100)` - Recovery justification

**Returns:** `(response bool uint)` - Success/pending status

**Requirements:** Both administrator and contributor approval needed

#### Extensions & Modifications

##### `extend-resource-allocation-duration`
Extends project deadline.

**Parameters:**
- `resource-id: uint` - Allocation identifier
- `extension-blocks: uint` - Additional blocks (max 1008)

**Returns:** `(response bool uint)` - Success confirmation

**Restrictions:** Contributor only, before expiration

##### `increase-resource-allocation-amount`
Increases allocation amount.

**Parameters:**
- `resource-id: uint` - Allocation identifier
- `additional-amount: uint` - Additional STX amount

**Returns:** `(response bool uint)` - Success confirmation

**Restrictions:** Contributor only, before expiration

#### Administration

##### `batch-validate-project-stages`
Validates multiple stages in a single transaction.

**Parameters:**
- `resource-ids: (list 10 uint)` - List of allocation IDs

**Returns:** `(response bool uint)` - Batch operation result

**Restrictions:** Administrator only

##### `set-contract-operational-state`
Controls contract operational status.

**Parameters:**
- `new-status: bool` - Operational state flag

**Returns:** `(response bool uint)` - Success confirmation

**Restrictions:** Administrator only

### Read-Only Functions

##### `is-recipient-validated`
Checks if a recipient is validated.

**Parameters:**
- `recipient: principal` - Address to check

**Returns:** `bool` - Validation status

## Security Features

### Access Control Matrix

| Function | Administrator | Contributor | Recipient | Public |
|----------|--------------|-------------|-----------|--------|
| Launch Allocation | ❌ | ✅ | ❌ | ❌ |
| Validate Stage | ✅ | ❌ | ❌ | ❌ |
| Report Progress | ❌ | ❌ | ✅ | ❌ |
| Cancel Allocation | ❌ | ✅ | ❌ | ❌ |
| Emergency Recovery | ✅ | ✅ | ❌ | ❌ |
| Extend Duration | ❌ | ✅ | ❌ | ❌ |
| Increase Amount | ❌ | ✅ | ❌ | ❌ |

### Security Mechanisms

1. **Input Validation**
   - All parameters validated before processing
   - Principal address verification
   - Amount and percentage bounds checking

2. **State Consistency**
   - Allocation status tracking prevents double-spending
   - Timestamp validation for time-bound operations
   - Stage completion verification

3. **Financial Security**
   - Escrow-based fund management
   - Atomic operations with rollback on failure
   - Precise mathematical calculations

4. **Rate Limiting**
   - Per-contributor allocation limits
   - Time-window based restrictions
   - Automatic cleanup of expired windows

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| 200 | `ERROR_UNAUTHORIZED` | Insufficient permissions |
| 201 | `ERROR_RESOURCE_NOT_FOUND` | Allocation doesn't exist |
| 202 | `ERROR_FUNDS_PREVIOUSLY_DISTRIBUTED` | Already processed |
| 203 | `ERROR_TRANSFER_UNSUCCESSFUL` | STX transfer failed |
| 204 | `ERROR_INVALID_RESOURCE_ID` | Invalid allocation ID |
| 205 | `ERROR_INVALID_CONTRIBUTION` | Invalid amount/parameter |
| 206 | `ERROR_INVALID_PROJECT_STAGE` | Invalid stage configuration |
| 207 | `ERROR_PROJECT_EXPIRED` | Allocation has expired |
| 208 | `ERROR_ALREADY_EXPIRED` | Already past deadline |
| 209 | `ERROR_EMERGENCY_RESTORATION_UNAUTHORIZED` | Emergency recovery denied |
| 210 | `ERROR_PROGRESS_ALREADY_RECORDED` | Progress already at 100% |
| 211 | `ERROR_DELEGATION_ALREADY_EXISTS` | Active delegation exists |
| 212 | `ERROR_BATCH_OPERATION_FAILED` | Batch operation error |
| 213 | `ERROR_RATE_LIMIT_EXCEEDED` | Too many allocations |
| 222 | `ERROR_INTERRUPTION_ACTIVE` | Circuit breaker active |
| 223 | `ERROR_INTERRUPTION_TRIGGER_DELAY` | Interruption timing error |
| 224 | `ERROR_EXCESSIVE_RECIPIENTS` | Too many recipients |
| 225 | `ERROR_INVALID_DISTRIBUTION_RATIO` | Percentages don't sum to 100% |

## Examples

### Example 1: Simple Project Funding

```clarity
;; Create a 2-stage development project
(contract-call? .decentralized-funding launch-resource-allocation
  'SP2DEVELOPER...ADDRESS
  u2000000  ;; 2 STX
  (list u1 u2))

;; Developer reports completion of stage 1
(contract-call? .decentralized-funding report-stage-progress
  u1 u0 u100
  "Frontend implementation completed"
  0xabc123...)

;; Administrator validates and releases 50% of funds
(contract-call? .decentralized-funding validate-project-stage u1)
```

### Example 2: Multi-Recipient Split

```clarity
;; Split funding between frontend and backend developers
(contract-call? .decentralized-funding create-split-resource-allocation
  (list 
    { recipient: 'SP1FRONTEND...DEV, allocation-percentage: u60 }
    { recipient: 'SP2BACKEND...DEV, allocation-percentage: u40 })
  u5000000)  ;; 5 STX total
```

### Example 3: Emergency Recovery

```clarity
;; Contributor initiates emergency recovery
(contract-call? .decentralized-funding emergency-allocation-recovery
  u1
  "Recipient unresponsive for 30+ days")

;; Administrator approves recovery
(contract-call? .decentralized-funding emergency-allocation-recovery
  u1
  "Confirmed - recipient account compromised")
```

### Example 4: Project Extension

```clarity
;; Extend project deadline by 3 days
(contract-call? .decentralized-funding extend-resource-allocation-duration
  u1
  u432)  ;; ~3 days in blocks

;; Add additional funding
(contract-call? .decentralized-funding increase-resource-allocation-amount
  u1
  u1000000)  ;; +1 STX
```

## Testing

### Test Coverage Areas

1. **Basic Functionality**
   - Allocation creation and validation
   - Stage progression and fund release
   - Cancellation and refund logic

2. **Edge Cases**
   - Expiration handling
   - Invalid input scenarios
   - Boundary condition testing

3. **Security Testing**
   - Authorization bypass attempts
   - Rate limiting enforcement
   - Emergency recovery scenarios

4. **Integration Testing**
   - Multi-step workflows
   - Batch operations
   - Cross-function interactions

### Running Tests

```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/allocation-tests.ts

# Run with coverage
clarinet test --coverage
```

### Test Structure

```
tests/
├── allocation-basic.test.ts     # Basic allocation operations
├── progress-tracking.test.ts    # Stage progress functionality
├── emergency-recovery.test.ts   # Emergency scenarios
├── multi-recipient.test.ts      # Split allocation testing
├── rate-limiting.test.ts        # Rate limit enforcement
├── security.test.ts             # Security and access control
└── integration.test.ts          # End-to-end workflows
```

## Contributing

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Install dependencies
4. Run tests locally
5. Submit pull request

### Code Standards

- Follow Clarity best practices
- Include comprehensive tests
- Update documentation
- Use descriptive variable names
- Add inline comments for complex logic

### Pull Request Process

1. Ensure all tests pass
2. Update README if needed
3. Add changelog entry
4. Request review from maintainers
5. Address feedback promptly

## Security Considerations

### Known Limitations

1. **Administrator Trust**: System requires trusted administrator for stage validation
2. **Rate Limiting**: Per-contributor limits may not prevent coordinated attacks
3. **Emergency Recovery**: Requires cooperation between administrator and contributor

### Best Practices

1. **Multi-Signature**: Consider multi-sig for administrator functions
2. **Monitoring**: Implement off-chain monitoring for unusual activity
3. **Gradual Rollout**: Start with small allocations to test system behavior
4. **Regular Audits**: Periodic security reviews recommended

## Roadmap

### Version 2.0 Features

- [ ] Multi-signature administrator support
- [ ] Automated stage validation via oracles
- [ ] Reputation system for recipients
- [ ] Cross-chain funding support
- [ ] Advanced analytics dashboard

### Community Features

- [ ] Governance token integration
- [ ] Community voting on disputes
- [ ] Decentralized administrator selection
- [ ] Transparent fee structure

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

### Documentation
- [Clarity Documentation](https://docs.stacks.co/clarity)
- [Stacks Blockchain](https://docs.stacks.co)

**Disclaimer**: This smart contract is provided as-is. Users should conduct their own security audits before deploying to mainnet or handling significant funds. The developers are not responsible for any loss of funds due to contract vulnerabilities or user error.# decentralized-milestone-funding
