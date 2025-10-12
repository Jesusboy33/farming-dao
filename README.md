# BetterCoin DEX - Advanced Decentralized Exchange on Stacks

![BetterCoin Logo](./frontend/public/logo512.png)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Stacks](https://img.shields.io/badge/Built%20on-Stacks-purple.svg)](https://www.stacks.co/)
[![Clarity](https://img.shields.io/badge/Smart%20Contracts-Clarity-orange.svg)](https://clarity-lang.org/)
[![React](https://img.shields.io/badge/Frontend-React-blue.svg)](https://reactjs.org/)

The most advanced decentralized exchange on Stacks blockchain featuring AI-powered trading insights, sophisticated liquidity management, yield farming, and governance mechanisms.

## 🌟 Key Features

### 🪙 Advanced Token (BetterCoin - BETT)
- **SIP-010 Compliant**: Full compatibility with Stacks ecosystem
- **Governance**: Community-driven decision making through proposals and voting
- **Security Features**: Blacklist protection, daily transfer limits, pause functionality
- **Anti-Manipulation**: Advanced mechanisms to prevent market manipulation
- **Burn & Mint**: Controlled supply management with authorized minters

### 🔄 Sophisticated Trading Engine
- **Limit Orders**: Set precise entry and exit points
- **Market Orders**: Instant execution at current market prices
- **Order Book**: Full order book implementation with bid/ask spreads
- **Market Making**: Automated market making with rewards
- **Price Discovery**: Advanced pricing mechanisms and TWAP calculations
- **Stop Loss/Take Profit**: Risk management tools

### 💧 Advanced Liquidity Management
- **AMM Protocol**: Automated Market Maker with dynamic fees
- **Liquidity Pools**: Create and manage trading pairs
- **Yield Farming**: Earn rewards by staking LP tokens
- **Slippage Protection**: Advanced slippage control mechanisms
- **Impermanent Loss Protection**: Minimize IL with sophisticated algorithms

### 🤖 AI Trading Assistant
- **Market Analysis**: Real-time market sentiment and trend analysis
- **Trading Recommendations**: AI-powered buy/sell/hold recommendations
- **Portfolio Optimization**: Intelligent portfolio management suggestions
- **Risk Assessment**: Advanced risk analysis and management advice
- **Natural Language**: Chat-based interface for easy interaction

### 🎯 Modern Web Interface
- **Wallet Integration**: Seamless Stacks wallet connectivity
- **Real-time Updates**: Live market data and portfolio tracking
- **Responsive Design**: Works perfectly on desktop and mobile
- **Dark/Light Mode**: Customizable themes
- **Advanced Charts**: TradingView-style charting capabilities

## 🏗️ Architecture Overview

```
BetterCoin DEX Architecture
├── Smart Contracts (Clarity)
│   ├── bettercoin.clar          # Main token contract
│   ├── liquidity-pool.clar      # AMM and liquidity management
│   └── advanced-trading.clar    # Order book and trading engine
├── Frontend (React + TypeScript)
│   ├── Components
│   │   ├── TradingInterface     # Advanced trading UI
│   │   ├── LiquidityInterface   # Pool management
│   │   ├── PortfolioView        # Portfolio tracking
│   │   └── TradingChatbot       # AI assistant
│   ├── Hooks
│   │   ├── useStacksAuth        # Wallet authentication
│   │   ├── useContract          # Contract interactions
│   │   └── useMarketData        # Real-time data
│   └── Services
│       ├── ContractService      # Blockchain interactions
│       ├── MarketDataService    # Price feeds
│       └── AIService            # Trading recommendations
└── Testing Suite
    ├── Contract Tests           # Comprehensive Clarity tests
    ├── Integration Tests        # Full stack testing
    └── Security Tests           # Security vulnerability tests
```

## 🚀 Quick Start

### Prerequisites

- **Node.js** (v16 or higher)
- **Clarinet** (latest version)
- **Stacks Wallet** (Hiro Wallet or Xverse)
- **Git**

### 1. Clone the Repository

```bash
git clone https://github.com/your-repo/bettercoin-dex.git
cd bettercoin-dex
```

### 2. Install Dependencies

```bash
# Install Clarinet dependencies
npm install

# Install frontend dependencies
cd frontend
npm install
cd ..
```

### 3. Setup Environment

```bash
# Copy environment template
cp .env.example .env

# Configure your environment variables
# REACT_APP_NETWORK=testnet
# REACT_APP_CONTRACT_ADDRESS=your_contract_address
```

### 4. Deploy Smart Contracts

```bash
# Check contracts
clarinet check

# Run tests
clarinet test

# Deploy to testnet
clarinet deploy --testnet
```

### 5. Start Frontend Development Server

```bash
cd frontend
npm start
```

The application will be available at `http://localhost:3000`

## 📋 Smart Contract Details

### BetterCoin Token (BETT)

The core token contract implementing SIP-010 with advanced features:

```clarity
;; Key Functions
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
(define-public (mint (amount uint) (recipient principal))
(define-public (burn (amount uint))
(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)))
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
```

**Features:**
- Total Supply: 100M BETT (max), 10M initial
- Decimals: 8
- Governance: Token-weighted voting
- Security: Blacklist, pause, daily limits
- Events: Comprehensive logging system

### Liquidity Pool Contract

Advanced AMM with yield farming capabilities:

```clarity
;; Key Functions
(define-public (create-pool (token-a <ft-trait>) (token-b <ft-trait>) (initial-a uint) (initial-b uint))
(define-public (add-liquidity (...))
(define-public (remove-liquidity (...))
(define-public (swap-exact-tokens-for-tokens (...))
(define-public (stake-lp-tokens (pool-id uint) (amount uint))
```

**Features:**
- 0.3% trading fees
- Yield farming rewards
- Slippage protection
- Price oracles
- Emergency pause functionality

### Advanced Trading Contract

Sophisticated order book and trading engine:

```clarity
;; Key Functions
(define-public (create-trading-pair (...))
(define-public (place-limit-order (...))
(define-public (place-market-order (...))
(define-public (cancel-order (order-id uint))
(define-public (register-market-maker (...))
```

**Features:**
- Order book management
- Market and limit orders
- Stop loss/take profit
- Market making rewards
- TWAP price calculations

## 🧪 Testing

### Running Contract Tests

```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/bettercoin_test.ts

# Check contracts
clarinet check
```

### Test Coverage

Our test suite covers:
- ✅ Token functionality (transfers, minting, burning)
- ✅ Governance mechanisms
- ✅ Liquidity pool operations
- ✅ Trading engine functionality
- ✅ Security features
- ✅ Edge cases and error handling
- ✅ Integration scenarios

### Frontend Testing

```bash
cd frontend
npm test
```

## 🔐 Security Features

### Smart Contract Security

1. **Access Controls**: Role-based permissions for critical functions
2. **Pause Mechanism**: Emergency stop functionality
3. **Blacklist Protection**: Prevent malicious actors
4. **Daily Limits**: Rate limiting for large transfers
5. **Slippage Protection**: Prevent sandwich attacks
6. **Reentrancy Guards**: Protection against reentrancy attacks

### Frontend Security

1. **Wallet Integration**: Secure connection to Stacks wallets
2. **Input Validation**: Client-side validation for all inputs
3. **HTTPS Only**: Secure communication protocols
4. **CSP Headers**: Content Security Policy implementation
5. **Rate Limiting**: API rate limiting protection

## 💡 AI Trading Assistant

The AI Trading Assistant provides intelligent insights and recommendations:

### Features
- **Market Analysis**: Real-time sentiment and technical analysis
- **Trading Signals**: Buy/sell/hold recommendations with confidence scores
- **Risk Assessment**: Portfolio risk analysis and suggestions
- **Natural Language**: Chat-based interface for easy interaction
- **Learning Algorithm**: Adapts to market conditions and user preferences

### Supported Queries
- "Should I buy BETT right now?"
- "What's the current market analysis?"
- "How's my portfolio performing?"
- "What are the risks?"
- "How can I earn yield?"

## 📊 Yield Farming

### How to Farm BETT Rewards

1. **Provide Liquidity**: Add liquidity to supported pools
2. **Stake LP Tokens**: Stake your LP tokens in farming pools
3. **Earn Rewards**: Receive BETT tokens as rewards
4. **Compound**: Reinvest rewards for compound growth

### Current Farming Pools

| Pool | APY | Rewards |
|------|-----|---------|
| BETT/STX | 25-35% | BETT |
| BETT/USDC | 20-30% | BETT |
| BETT/BTC | 15-25% | BETT |

## 🏛️ Governance

BetterCoin features a robust governance system:

### Voting Process

1. **Proposal Creation**: Minimum 1000 BETT required
2. **Voting Period**: 7 days (1008 blocks)
3. **Execution**: Automatic execution if passed
4. **Voting Power**: 1 BETT = 1 Vote

### Governance Areas

- Protocol parameters (fees, limits)
- New feature implementations
- Treasury management
- Emergency responses
- Partnership proposals

## 🔧 API Documentation

### Contract Interactions

```typescript
// Connect to contract
import { BetterCoinService } from './services/ContractService';

const service = new BetterCoinService(network);

// Transfer tokens
await service.transfer(amount, recipient);

// Add liquidity
await service.addLiquidity(tokenA, tokenB, amountA, amountB);

// Place order
await service.placeLimitOrder(pairId, side, amount, price);
```

### Market Data API

```typescript
// Get market data
const marketData = await MarketDataService.getMarketData('BETT');

// Get portfolio data
const portfolio = await MarketDataService.getPortfolio(userAddress);
```

## 🤝 Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Code Standards

- **Clarity**: Follow Stacks/Clarity best practices
- **TypeScript**: Use strict TypeScript configuration
- **Testing**: Maintain 90%+ test coverage
- **Documentation**: Update docs for new features
- **Security**: Follow security best practices

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Stacks Foundation** for the amazing blockchain platform
- **Clarity Language** for secure smart contract development
- **Hiro Tools** for excellent development tooling
- **Open Source Community** for inspiration and support

## 📞 Support

- **Discord**: [Join our community](https://discord.gg/bettercoin)
- **Telegram**: [BetterCoin Chat](https://t.me/bettercoin)
- **Email**: support@bettercoin.org
- **GitHub Issues**: For bug reports and feature requests

## 🗺️ Roadmap

### Phase 1 (Current) - Core DEX ✅
- [x] Token contract with governance
- [x] Liquidity pools and AMM
- [x] Advanced trading engine
- [x] AI trading assistant
- [x] Web interface

### Phase 2 - Advanced Features 🚧
- [ ] Cross-chain bridges
- [ ] Options trading
- [ ] Lending/borrowing
- [ ] NFT marketplace integration
- [ ] Mobile app

### Phase 3 - Ecosystem Expansion 📅
- [ ] DAO treasury management
- [ ] Grant programs
- [ ] Developer SDK
- [ ] Third-party integrations
- [ ] Institutional features

---

**Built with ❤️ on Stacks Blockchain**

*BetterCoin DEX - Making DeFi Better, One Trade at a Time*