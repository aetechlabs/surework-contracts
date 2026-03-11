# SureWork Smart Contracts

> Decentralized escrow smart contracts for the SureWork freelancing platform

## Overview

This repository contains the Solidity smart contracts that power SureWork's decentralized escrow system. Built on Ethereum-compatible blockchains (Polygon, Arbitrum, Base), these contracts ensure secure, trustless payments between clients and freelancers.

## Features

- **Escrow Management**: Secure fund locking until work completion
- **Multi-Token Support**: Compatible with any ERC20 token (USDC, USDT, DAI)
- **Dispute Resolution**: Built-in arbitration system
- **Platform Fees**: Configurable fee system (default 2.5%)
- **Role-Based Access**: Admin and Arbiter roles for governance
- **Event Emission**: Comprehensive logging for off-chain indexing

## Smart Contracts

### SureWorkEscrow.sol

Main escrow contract with the following functions:

- `createGig()` - Create a new gig with escrow terms
- `fundGig()` - Lock funds in escrow (ERC20)
- `submitWork()` - Freelancer submits deliverable
- `approveWork()` - Client approves and releases payment
- `raiseDispute()` - Initiate dispute resolution
- `resolveDispute()` - Admin resolves disputes

**Deployed Addresses:**
- Local (Hardhat): `0x5FbDB2315678afecb367f032d93F642f64180aa3`
- Polygon Mumbai: _Coming soon_
- Polygon Mainnet: _Coming soon_

## Tech Stack

- **Solidity**: ^0.8.20
- **Hardhat**: Development environment
- **OpenZeppelin**: Security-audited contract libraries
- **ethers.js**: Ethereum interactions
- **TypeScript**: Type-safe testing

## Installation

```bash
# Install dependencies
npm install

# Compile contracts
npm run compile

# Run tests
npm test

# Get test coverage
npm run coverage
```

## Development

### Local Development

```bash
# Start local blockchain
npm run node

# Deploy to local network
npm run deploy:local

# Run tests
npm test
```

### Testnet Deployment

1. Update `.env` with your private key and RPC URLs:

```env
PRIVATE_KEY=your_private_key_here
POLYGON_MUMBAI_RPC_URL=https://rpc-mumbai.maticvigil.com
POLYGONSCAN_API_KEY=your_api_key
```

2. Deploy to testnet:

```bash
npm run deploy:testnet
```

### Mainnet Deployment

```bash
npm run deploy:mainnet
```

## Testing

Comprehensive test suite covering:

- Gig creation and funding
- Work submission and approval
- Payment distribution with fees
- Dispute scenarios
- Access control
- Security (reentrancy, overflow)

Run tests:

```bash
npm test
```

## Contract Architecture

```
SureWorkEscrow
├── Gig Management
│   ├── createGig()
│   ├── fundGig()
│   └── cancelGig()
├── Work Flow
│   ├── submitWork()
│   └── approveWork()
└── Dispute Resolution
    ├── raiseDispute()
    └── resolveDispute()
```

## Events

```solidity
event GigCreated(uint256 indexed gigId, address indexed client, address indexed freelancer, uint256 amount)
event GigFunded(uint256 indexed gigId, uint256 amount)
event WorkSubmitted(uint256 indexed gigId, address indexed freelancer)
event GigCompleted(uint256 indexed gigId, uint256 amountPaid, uint256 fee)
event GigDisputed(uint256 indexed gigId, address indexed initiator)
event DisputeResolved(uint256 indexed gigId, address indexed winner, uint256 amount)
```

## Security

- ✅ OpenZeppelin contracts for security
- ✅ ReentrancyGuard on all state-changing functions
- ✅ SafeERC20 for token transfers
- ✅ Role-based access control
- ✅ Comprehensive test coverage
- ⏳ Audit pending

## Networks

| Network | Chain ID | Status |
|---------|----------|--------|
| Hardhat Local | 31337 | ✅ Deployed |
| Polygon Mumbai | 80001 | 🔄 Coming Soon |
| Polygon Mainnet | 137 | 🔄 Coming Soon |
| Arbitrum One | 42161 | 🔄 Coming Soon |
| Base | 8453 | 🔄 Coming Soon |

## Gas Optimization

- Function visibility optimized
- Storage vs memory usage optimized
- Batch operations where possible
- Estimated gas costs:
  - Create Gig: ~150,000 gas
  - Fund Gig: ~80,000 gas
  - Approve Work: ~100,000 gas

## License

MIT

## Related Repositories

- **Backend**: [surework-backend](https://github.com/aetechlabs/surework-backend)
- **Mobile App**: [surework-mobile](https://github.com/aetechlabs/surework-mobile)

## Support

For issues and questions:
- Open an issue in this repository
- Contact: dev@aetechlabs.com

---

Built with ❤️ by [AeTechLabs](https://github.com/aetechlabs)
