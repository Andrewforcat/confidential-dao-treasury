# Confidential DAO Treasury — Private Governance Spending with FHEVM

## 🏛️ Introduction
Confidential DAO Treasury is a privacy-preserving treasury management system powered by Zama’s FHEVM.  
It allows DAOs to allocate funds privately, ensuring sensitive financial decisions are kept confidential while still being verifiable on-chain.  

## 🎯 Motivation
DAOs often face the challenge of transparency vs. confidentiality.  
While transparency builds trust, revealing every treasury move can create risks such as front-running, targeted attacks, or unwanted scrutiny.  
This project provides a **balance**: verifiable spending with hidden details.  

## ✨ Features
- 🔒 **Encrypted spending amounts** — treasury outflows remain private.  
- ✅ **Programmable compliance** — access control and rules encoded in contracts.  
- ⚡ **EVM compatibility** — deployable on Ethereum and L2 networks.  
- 🔗 **DAO-ready** — integrates with governance modules and voting systems.  
- 🧪 **Test coverage** — includes tests for allocation proposals and execution.  

## 📂 Project Structure
confidential-dao-treasury/  
├── contracts/  
│   └── ConfidentialTreasury.sol  
├── test/  
│   └── ConfidentialTreasury.spec.ts  
├── hardhat.config.ts  
├── package.json  
├── .gitignore  
├── LICENSE  
└── README.md  

## 🚀 Getting Started
1) Install dependencies  
   npm install  

2) Compile the contracts  
   npx hardhat compile  

3) Run the test suite  
   npx hardhat test  

## 🔮 Use Cases
- DAOs funding contributors or teams without disclosing amounts.  
- Treasury diversification into assets without front-running.  
- Private grants and donations to external partners.  

## 📝 License
This project is licensed under the MIT License.
