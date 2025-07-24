# 🌾 Farming DAO - Decentralized Cooperative Farming Fund

Farming DAO is a decentralized cooperative funding platform built on the Stacks blockchain using Clarity smart contracts and a React frontend. It enables **smallholder farmers** to register, contribute funds, propose farming-related decisions (like equipment purchases), vote on them, and execute collective actions in a secure, transparent, and democratic way.

---

## 🧠 Purpose

To empower farmers through decentralized collaboration, where they can:
- ✅ Register as verified members (farmers)
- 💰 Contribute micro-funds into a shared pool
- 🗳️ Create and vote on proposals (e.g., equipment purchases, community actions)
- 🛠 Execute approved proposals

This project aims to solve the problem of **access to finance, resources, and democratic governance** for local farming communities.

---

## 🏗 Project Structure

farming-dao/
├── contracts/ # Clarity smart contracts (main logic)
│ └── farming-dao.clar
│
├── tests/ # Tests using Clarinet/TypeScript
│ └── farming-dao_test.ts
│
├── frontend/ # React frontend (Vite-powered)
│ ├── farming-dao/ # Actual Vite project
│ │ ├── src/
│ │ │ ├── App.jsx
│ │ │ └── components/
│ │ │ └── ProposalForm.jsx
│ │ └── index.html, vite.config.js, etc.
│
├── deployments/ # Deployment config (optional)
│ └── testnet-deploy.json
│
├── Clarinet.toml # Clarinet config file
├── README.md # This file
└── .gitignore # Ignore unnecessary files