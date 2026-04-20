// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CrossBorderPayments
 * @notice A simple smart contract that simulates cross-border remittances on-chain.
 *         Users register with a country and local currency, deposit ETH, and send
 *         payments to other registered users. The contract applies a configurable
 *         fee (in basis points), records an exchange rate for the recipient's local
 *         currency, and persists every transaction so the frontend can display a
 *         full audit trail.
 *
 * @dev    Exchange rates are supplied by the sender and stored as `rate * 1e6`
 *         (e.g. 22.50 ZMW per 1 USD-equivalent ETH unit => 22_500_000). In a
 *         production system the rate would come from a price oracle such as
 *         Chainlink; for the assignment the caller passes it explicitly.
 */
contract CrossBorderPayments {
    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    address public owner;
    uint256 public feeBasisPoints;       // 50 = 0.50%, 100 = 1.00%, max 500 (5%)
    uint256 public constant MAX_FEE_BP = 500;

    struct User {
        string  name;
        string  country;       // e.g. "Zambia"
        string  currencyCode;  // ISO 4217, e.g. "ZMW", "USD", "TZS"
        bool    registered;
    }

    struct Transaction {
        uint256 id;
        address sender;
        address recipient;
        uint256 amount;             // net amount delivered to recipient, in wei
        uint256 fee;                // fee paid, in wei
        string  senderCountry;
        string  recipientCountry;
        string  recipientCurrency;
        uint256 exchangeRate;       // rate * 1e6 (recipient-currency per 1 ETH-unit)
        uint256 timestamp;
        string  note;               // optional memo ("school fees", etc.)
    }

    mapping(address => User)      public users;
    mapping(address => uint256)   public balances;      // in-contract ledger (wei)
    mapping(address => uint256[]) private userTxIds;    // per-user tx index
    Transaction[] public transactions;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event UserRegistered(address indexed user, string country, string currencyCode);
    event Deposited(address indexed user, uint256 amount, uint256 newBalance);
    event Withdrawn(address indexed user, uint256 amount, uint256 newBalance);
    event PaymentSent(
        uint256 indexed txId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 fee,
        uint256 exchangeRate
    );
    event PaymentReceived(
        uint256 indexed txId,
        address indexed recipient,
        uint256 amount,
        string  recipientCurrency
    );
    event FeeUpdated(uint256 oldFeeBp, uint256 newFeeBp);

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyRegistered() {
        require(users[msg.sender].registered, "Sender not registered");
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @param _feeBasisPoints initial fee in basis points (50 = 0.50%).
     */
    constructor(uint256 _feeBasisPoints) {
        require(_feeBasisPoints <= MAX_FEE_BP, "Fee exceeds 5% cap");
        owner = msg.sender;
        feeBasisPoints = _feeBasisPoints;
    }

    // -------------------------------------------------------------------------
    // Registration
    // -------------------------------------------------------------------------

    /**
     * @notice Register the caller as a user of the platform.
     * @dev Re-registration is blocked to keep country/currency immutable after
     *      first onboarding — mirrors real-world KYC reality.
     */
    function registerUser(
        string calldata _name,
        string calldata _country,
        string calldata _currencyCode
    ) external {
        require(!users[msg.sender].registered, "Already registered");
        require(bytes(_name).length > 0, "Name required");
        require(bytes(_country).length > 0, "Country required");
        require(bytes(_currencyCode).length > 0, "Currency required");

        users[msg.sender] = User({
            name:         _name,
            country:      _country,
            currencyCode: _currencyCode,
            registered:   true
        });

        emit UserRegistered(msg.sender, _country, _currencyCode);
    }

    // -------------------------------------------------------------------------
    // Deposit / Withdraw
    // -------------------------------------------------------------------------

    /**
     * @notice Deposit ETH into the in-contract wallet so it can be used for
     *         multiple future sendPayment calls without re-approving each time.
     */
    function deposit() external payable onlyRegistered {
        require(msg.value > 0, "Deposit must be > 0");
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value, balances[msg.sender]);
    }

    /**
     * @notice Withdraw from the in-contract wallet back to the caller's EOA.
     */
    function withdraw(uint256 _amount) external onlyRegistered {
        require(_amount > 0, "Amount must be > 0");
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        balances[msg.sender] -= _amount;
        (bool ok, ) = payable(msg.sender).call{value: _amount}("");
        require(ok, "Withdraw transfer failed");
        emit Withdrawn(msg.sender, _amount, balances[msg.sender]);
    }

    // -------------------------------------------------------------------------
    // Core: Cross-border payment
    // -------------------------------------------------------------------------

    /**
     * @notice Send a cross-border payment. The caller may fund the payment either
     *         by attaching ETH to this call (msg.value > 0) OR by having a
     *         sufficient in-contract balance. If both are supplied, msg.value is
     *         used first and the in-contract balance tops it up.
     *
     * @param _recipient     registered recipient address
     * @param _grossAmount   total amount (wei) to be debited from the sender
     *                       (before fee). Net amount to recipient = gross - fee.
     * @param _exchangeRate  recipient-currency per ETH-unit, scaled by 1e6
     * @param _note          optional memo ("Q1 school fees")
     */
    function sendPayment(
        address _recipient,
        uint256 _grossAmount,
        uint256 _exchangeRate,
        string calldata _note
    ) external payable onlyRegistered {
        require(_recipient != address(0),        "Invalid recipient");
        require(_recipient != msg.sender,        "Cannot send to self");
        require(users[_recipient].registered,    "Recipient not registered");
        require(_grossAmount > 0,                "Amount must be > 0");
        require(_exchangeRate > 0,               "Exchange rate must be > 0");

        // Fund the payment: use msg.value first, then top up from balance.
        if (msg.value < _grossAmount) {
            uint256 shortfall = _grossAmount - msg.value;
            require(balances[msg.sender] >= shortfall, "Insufficient funds");
            balances[msg.sender] -= shortfall;
        } else if (msg.value > _grossAmount) {
            // Refund any overpayment to the sender's in-contract balance.
            balances[msg.sender] += (msg.value - _grossAmount);
        }

        uint256 fee       = (_grossAmount * feeBasisPoints) / 10_000;
        uint256 netAmount = _grossAmount - fee;

        // Credit recipient's in-contract balance, accrue fee to the owner.
        balances[_recipient] += netAmount;
        balances[owner]      += fee;

        // Persist the transaction record.
        uint256 txId = transactions.length;
        transactions.push(Transaction({
            id:                 txId,
            sender:             msg.sender,
            recipient:          _recipient,
            amount:             netAmount,
            fee:                fee,
            senderCountry:      users[msg.sender].country,
            recipientCountry:   users[_recipient].country,
            recipientCurrency:  users[_recipient].currencyCode,
            exchangeRate:       _exchangeRate,
            timestamp:          block.timestamp,
            note:               _note
        }));

        userTxIds[msg.sender].push(txId);
        userTxIds[_recipient].push(txId);

        emit PaymentSent(txId, msg.sender, _recipient, netAmount, fee, _exchangeRate);
        emit PaymentReceived(txId, _recipient, netAmount, users[_recipient].currencyCode);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /**
     * @notice Returns a user's in-contract balance in wei.
     */
    function checkBalance(address _user) external view returns (uint256) {
        return balances[_user];
    }

    /**
     * @notice Convenience wrapper for the connected frontend caller.
     */
    function getMyBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    /**
     * @notice Total number of transactions ever recorded on-chain.
     */
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    /**
     * @notice Returns the list of transaction IDs involving the caller
     *         (either as sender or recipient).
     */
    function getMyTransactionIds() external view returns (uint256[] memory) {
        return userTxIds[msg.sender];
    }

    /**
     * @notice Fetch a single transaction by ID.
     */
    function getTransaction(uint256 _id) external view returns (Transaction memory) {
        require(_id < transactions.length, "Invalid tx id");
        return transactions[_id];
    }

    /**
     * @notice Compute the recipient-currency value of a recorded transaction,
     *         using the exchange rate captured at transaction time.
     * @return value amount in recipient's currency, scaled by 1e6
     */
    function getConvertedAmount(uint256 _id) external view returns (uint256) {
        require(_id < transactions.length, "Invalid tx id");
        Transaction memory t = transactions[_id];
        // amount(wei) * rate(1e6) / 1 ether  => value in local currency * 1e6
        return (t.amount * t.exchangeRate) / 1 ether;
    }

    // -------------------------------------------------------------------------
    // Admin
    // -------------------------------------------------------------------------

    /**
     * @notice Update the platform fee in basis points. Capped at 5%.
     */
    function setFeeBasisPoints(uint256 _newFeeBp) external onlyOwner {
        require(_newFeeBp <= MAX_FEE_BP, "Fee exceeds 5% cap");
        uint256 old = feeBasisPoints;
        feeBasisPoints = _newFeeBp;
        emit FeeUpdated(old, _newFeeBp);
    }

    /**
     * @notice Transfer ownership of the contract.
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid owner");
        owner = _newOwner;
    }

    // Accept plain ETH transfers as implicit deposits for registered users.
    receive() external payable {
        if (users[msg.sender].registered) {
            balances[msg.sender] += msg.value;
            emit Deposited(msg.sender, msg.value, balances[msg.sender]);
        }
    }
}
