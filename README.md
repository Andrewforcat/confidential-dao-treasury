# Confidential DAO Treasury — Private Governance Spending with FHEVM

A demo showing how a DAO can manage treasury privately using Zama’s FHEVM.

## Features
- Encrypted treasury balance (`euint64`)
- Proposals with encrypted spend amounts
- YES voting with a quorum to approve spending
- Fail-closed execution: if requested > treasury → executed = 0
- Recipient and owner can decrypt the executed amount; only owner decrypts the treasury

## Tech
Solidity + FHEVM, Hardhat, TypeScript, Ethers v6.

## Quickstart
```bash
npm i
npx hardhat test
