# CrossBorder Payments DApp — FIN 510 Group Assignment

A cross-border remittance demonstration built on Ethereum-compatible infrastructure. A single smart contract records user KYC, manages in-contract balances, applies a configurable platform fee, and captures every transaction with its exchange rate — all queryable from a lightweight ethers.js frontend that runs inside VS Code's Live Server.

---

## Environment-driven workflow

Use the new `.env` workflow (FractionalEstate-style) so Ganache and deployment settings are centralized.

```bash
cp .env.example .env
npm install
npm run compile
npm run deploy:ganache
npm run sync:abi
npm run generate:frontend-config
```

`CrossBorderPayments` now deploys with constructor args pulled from `.env`:
- `FEE_BASIS_POINTS`
- `TREASURY_ADDRESS` (falls back to deployer if empty)
- `MINIMUM_INVESTMENT`

The frontend now reads runtime settings from `frontend/env-config.js` (generated from `.env`).

---

## Deliverables

| Task | File(s) |
|------|---------|
| **1. Smart Contract** | `contracts/CrossBorderPayments.sol` (+ generated `CrossBorderPayments.abi.json`) |
| **2. Sequence Diagram** | `docs/sequence_diagram.svg` (rendered) &nbsp;·&nbsp; `docs/sequence_diagram.mmd` (Mermaid source — editable in Lucidchart / mermaid.live) |
| **3. Frontend + Interaction** | `frontend/index.html` (single-file ethers.js v6 DApp) |

---

## Repository Layout

```
cross-border-dapp/
├── contracts/
│   ├── CrossBorderPayments.sol          ← Task 1: the contract
│   └── CrossBorderPayments.abi.json     ← ABI (also embedded in frontend)
├── docs/
│   ├── sequence_diagram.svg             ← Task 2: rendered diagram
│   └── sequence_diagram.mmd             ← Mermaid source for editing
├── frontend/
│   └── index.html                       ← Task 3: the DApp UI
└── README.md
```

---

## Prerequisites

Install these on every team member's laptop before the demo:

1. **[Ganache](https://archive.trufflesuite.com/ganache/)** (GUI is easiest) — local Ethereum blockchain simulator. Runs on `http://127.0.0.1:7545` by default.
2. **[MetaMask](https://metamask.io/)** browser extension — wallet + signer.
3. **[VS Code](https://code.visualstudio.com/)** with the **Live Server** extension (by Ritwick Dey) — serves the HTML frontend.
4. A modern Chrome/Brave/Firefox browser.

Node.js (v18+) is now recommended so you can deploy with Hardhat using `.env` settings. Remix remains optional.

---

## Part A — Deploy the Smart Contract

### Step 1. Start Ganache

Open Ganache → **Quickstart Ethereum**. You'll see 10 funded accounts, each with 100 ETH. Note the **RPC SERVER** URL (usually `HTTP://127.0.0.1:7545`) and the **NETWORK ID** (`5777` for GUI, `1337` for CLI).

### Step 2. Add the Ganache network to MetaMask

MetaMask → profile icon → **Settings → Networks → Add a network → Add manually**:

| Field | Value |
|---|---|
| Network name | `Ganache` |
| New RPC URL | `http://127.0.0.1:7545` |
| Chain ID | `5777` *(or `1337` if you run Ganache CLI)* |
| Currency symbol | `ETH` |

Switch MetaMask's active network to **Ganache**.

### Step 3. Import two Ganache accounts into MetaMask

Pick any two accounts from the Ganache window and click the **key icon** next to each to reveal the private key. In MetaMask, click the account icon → **Add account or hardware wallet → Import account → Private Key**, paste, and import. Rename them `Sender (ZM)` and `Recipient (TZ)` so you don't lose track during the demo.

### Step 4. Deploy via Remix

1. Go to **[remix.ethereum.org](https://remix.ethereum.org/)**.
2. In the file explorer, create a new file `CrossBorderPayments.sol` and paste in the contents of `contracts/CrossBorderPayments.sol`.
3. Switch to the **Solidity Compiler** tab → set compiler to **0.8.20** → **Compile CrossBorderPayments.sol**. No warnings should appear beyond a routine gas-optimization notice.
4. Switch to the **Deploy & Run Transactions** tab:
   - **Environment** → **Injected Provider — MetaMask** (Remix will prompt MetaMask to connect; choose your `Sender (ZM)` account).
   - Confirm **Account** shows the Ganache address.
   - In the **Deploy** box, enter a constructor argument of `50` (= 0.50% platform fee, in basis points).
   - Click **Deploy** → MetaMask pops up → **Confirm**.
5. After the transaction mines, the deployed contract appears under **Deployed Contracts**. Click the **copy** icon to grab its address — you'll paste this into the frontend.

> **Alternative: native Truffle in VS Code.** If your instructor requires the VS Code + Truffle path, run `npm install -g truffle`, create a Truffle project with the contract, and deploy with `truffle migrate --network development`. The frontend works identically — just paste the Truffle-reported contract address.

---

## Part B — Launch the Frontend

1. Open the project folder in **VS Code**.
2. Right-click `frontend/index.html` → **Open with Live Server**. Your browser opens at something like `http://127.0.0.1:5500/frontend/index.html`.
3. Click **Connect Wallet** (top-right). MetaMask prompts — approve the connection with your `Sender (ZM)` account.
4. Paste the **deployed contract address** from Remix into the "Contract Address" field and click **Load**. The UI will confirm the fee rate (0.50%) in the activity log.

The frontend persists the contract address in `localStorage`, so subsequent reloads auto-connect.

---

## Part C — Demo Walkthrough (Two-User Transaction)

Run this as your submission video / live demo:

### 1. Register the sender
In the **Register** card:
- Name: `Martin Milanzi`
- Country: `Zambia`
- Currency: `ZMW`

Click **Register On-Chain** → MetaMask → **Confirm**. Ganache's "Transactions" tab now shows a new transaction hitting `registerUser`.

### 2. Register the recipient
In MetaMask, switch to the `Recipient (TZ)` account. Reload the page, re-connect, and register as:
- Name: `Elitumaini Swai`
- Country: `Tanzania`
- Currency: `TZS`

### 3. Fund the sender's in-contract wallet (optional)
Switch MetaMask back to the sender. In the **Funds** card, enter `5` ETH → **Deposit**. The "In-Contract Balance" updates to `5.0000 ETH`.

### 4. Send a cross-border payment
In the **Send Payment** card, fill in:
- Recipient: paste the **recipient's Ganache address**
- Amount: `1` ETH
- FX Rate (local per 1 ETH): `9200000.00` *(example ZMW→TZS equivalent rate)*
- Memo: `Q1 school fees`

Watch the preview panel compute: `0.005 ETH fee · 0.995 ETH delivered · ≈ 9,154,000 TZS`. Click **Sign & Send** → MetaMask → **Confirm**.

### 5. Verify on both sides

**On Ganache:** the "Blocks" tab shows a new mined block; the "Transactions" tab shows the `sendPayment` call; the sender's ETH balance drops by 1 ETH + gas; the contract's balance rises by 0.005 ETH (the fee accrued to the owner).

**On the DApp:** the Transaction History table now shows the new row with direction `SENT`, counterparty's short address, ETH amount, local-currency equivalent (using the recorded rate), fee, timestamp, and memo.

**Switch MetaMask to the recipient** → reload the frontend → the same transaction appears in *their* history tagged `RECEIVED`, and the recipient's in-contract balance reads `0.995 ETH`. They can now **Withdraw** any portion back to their EOA — simulating the off-ramp to local currency.

---

## Function Reference

Callable from the frontend and from Remix's deployed-contracts panel:

| Function | Type | Purpose |
|---|---|---|
| `registerUser(name, country, currencyCode)` | tx | One-time KYC |
| `deposit()` `payable` | tx | Pre-fund the in-contract wallet |
| `sendPayment(recipient, grossAmount, exchangeRate, note)` `payable` | tx | Execute a remittance |
| `withdraw(amount)` | tx | Off-ramp to recipient's EOA |
| `checkBalance(address)` | view | In-contract ETH balance |
| `getMyBalance()` | view | Balance of caller |
| `getMyTransactionIds()` | view | Indices of caller's transactions |
| `getTransaction(id)` | view | Full transaction struct |
| `getConvertedAmount(id)` | view | Value in recipient-currency × 1e6 |
| `getTransactionCount()` | view | Total transactions ever recorded |
| `setFeeBasisPoints(new)` | tx · owner-only | Adjust fee, capped at 5% |

**Events** (subscribed to live by the frontend): `UserRegistered`, `Deposited`, `Withdrawn`, `PaymentSent`, `PaymentReceived`, `FeeUpdated`.

---

## Design Notes

- **Fees in basis points.** `feeBasisPoints = 50` means 0.50%. The contract caps this at `MAX_FEE_BP = 500` (5%) even for the owner — a guardrail against unilateral rate hikes that would harm existing users.
- **Exchange rate is stored, not enforced.** The sender supplies the ZMW-per-ETH (or TZS-per-ETH, etc.) rate at transaction time, scaled by `1e6` to preserve 6 decimal places in integer math. A production version would pull this from a Chainlink price oracle; for the assignment the caller passes it explicitly and the contract persists it so the historical record is auditable.
- **Internal ledger vs. raw ETH.** `balances` is a contract-internal ledger — funds only leave the contract when `withdraw()` is called. This lets senders pre-fund once and issue many cheap payments, mirroring how a real remittance corridor works (the operator warehouses liquidity; beneficiaries cash out on demand).
- **Gas-aware history.** The frontend reads each user's personal transaction index (`getMyTransactionIds`) rather than scanning the whole array, so history lookups stay O(n) in your own transactions, not the platform's.
- **Event-driven UI.** All four core events trigger live frontend refreshes, so a second browser window logged in as the recipient will see the incoming payment appear without a manual refresh.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| MetaMask shows "wrong network" | Switch MetaMask to the `Ganache` network you added in Part A · Step 2. |
| `nonce too high` in MetaMask after restarting Ganache | MetaMask → **Settings → Advanced → Clear activity tab data** for the Ganache account. |
| `execution reverted: Sender not registered` | Run **Register On-Chain** first, then retry your action. |
| Frontend says `Cannot read properties of null` | You skipped the **Load** step after pasting the contract address. |
| Events never fire in the UI | Live Server must run over `http://`, not `file://`. Ethers.js v6 needs an HTTP origin for wallet event subscriptions. |

---

## Team Split Suggestion

Use this to divide work if you're presenting in a team:

- **Contract author** — owns `CrossBorderPayments.sol`, explains `sendPayment`'s fee math + storage layout in the demo.
- **Architecture lead** — owns the sequence diagram, walks the graders through the end-to-end transactional flow.
- **Frontend engineer** — owns `index.html`, drives the live demo, handles MetaMask account switching.

— Martin T. Milanzi · FIN 510 Blockchain & Cryptocurrencies
