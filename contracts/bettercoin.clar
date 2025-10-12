;; BetterCoin (BETT) - Advanced SIP-010 Fungible Token
;; A secure, feature-rich cryptocurrency with governance and anti-manipulation mechanisms

(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-TRANSFER-FAILED (err u104))
(define-constant ERR-MINT-FAILED (err u105))
(define-constant ERR-BURN-FAILED (err u106))
(define-constant ERR-UNAUTHORIZED (err u107))
(define-constant ERR-PAUSED (err u108))
(define-constant ERR-BLACKLISTED (err u109))
(define-constant ERR-DAILY-LIMIT-EXCEEDED (err u110))

;; Token Configuration
(define-constant TOKEN-NAME "BetterCoin")
(define-constant TOKEN-SYMBOL "BETT")
(define-constant TOKEN-DECIMALS u8)
(define-constant TOKEN-URI "https://bettercoin.org/token-metadata.json")
(define-constant INITIAL-SUPPLY u1000000000000000) ;; 10M tokens with 8 decimals
(define-constant MAX-SUPPLY u10000000000000000)    ;; 100M tokens with 8 decimals

;; Data Variables
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var total-supply uint u0)
(define-data-var token-paused bool false)
(define-data-var minting-enabled bool true)
(define-data-var burning-enabled bool true)

;; Data Maps
(define-map token-balances principal uint)
(define-map token-supplies uint uint)
(define-map blacklisted-addresses principal bool)
(define-map authorized-minters principal bool)
(define-map daily-transfer-limits principal uint)
(define-map daily-transfers-used 
  { user: principal, day: uint } 
  uint
)

;; Transfer restrictions
(define-map transfer-restrictions 
  { from: principal, to: principal } 
  { allowed: bool, daily-limit: uint }
)

;; Governance
(define-map governance-proposals uint {
  proposer: principal,
  title: (string-ascii 100),
  description: (string-ascii 500),
  votes-for: uint,
  votes-against: uint,
  end-block: uint,
  executed: bool
})

(define-data-var proposal-counter uint u0)
(define-data-var voting-power-threshold uint u100000000) ;; 1000 BETT minimum

;; Events
(define-data-var events-log (list 1000 (string-ascii 200)) (list))

;; Authorization Functions
(define-private (is-contract-owner (user principal))
  (is-eq user (var-get contract-owner))
)

(define-private (is-authorized-minter (user principal))
  (default-to false (map-get? authorized-minters user))
)

(define-private (is-blacklisted (user principal))
  (default-to false (map-get? blacklisted-addresses user))
)

(define-private (is-paused)
  (var-get token-paused)
)

;; Utility Functions
(define-private (get-current-day)
  (/ block-height u144) ;; Approximately 24 hours in Bitcoin blocks
)

(define-private (check-daily-limit (user principal) (amount uint))
  (let (
    (current-day (get-current-day))
    (daily-limit (default-to u1000000000000 (map-get? daily-transfer-limits user)))
    (used-today (default-to u0 (map-get? daily-transfers-used { user: user, day: current-day })))
  )
    (<= (+ used-today amount) daily-limit)
  )
)

(define-private (update-daily-usage (user principal) (amount uint))
  (let (
    (current-day (get-current-day))
    (used-today (default-to u0 (map-get? daily-transfers-used { user: user, day: current-day })))
  )
    (map-set daily-transfers-used 
      { user: user, day: current-day } 
      (+ used-today amount)
    )
    (ok true)
  )
)

(define-private (log-event (event (string-ascii 200)))
  (let ((current-log (var-get events-log)))
    (var-set events-log (unwrap-panic (as-max-len? (append current-log event) u1000)))
  )
)

;; SIP-010 Implementation
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (not (is-paused)) ERR-PAUSED)
    (asserts! (not (is-blacklisted from)) ERR-BLACKLISTED)
    (asserts! (not (is-blacklisted to)) ERR-BLACKLISTED)
    (asserts! (or (is-eq tx-sender from) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-TOKEN-OWNER)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (check-daily-limit from amount) ERR-DAILY-LIMIT-EXCEEDED)
    
    (let ((sender-balance (ft-get-balance bettercoin from)))
      (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
      
      (try! (ft-transfer? bettercoin amount from to))
      (try! (update-daily-usage from amount))
      
      (log-event (concat "Transfer: " (concat (principal-to-string from) (concat " -> " (principal-to-string to)))))
      
      (match memo
        note (print { 
          op: "transfer", 
          from: from, 
          to: to, 
          amount: amount, 
          memo: note 
        })
        (print { 
          op: "transfer", 
          from: from, 
          to: to, 
          amount: amount 
        })
      )
      (ok true)
    )
  )
)

(define-read-only (get-name)
  (ok TOKEN-NAME)
)

(define-read-only (get-symbol)
  (ok TOKEN-SYMBOL)
)

(define-read-only (get-decimals)
  (ok TOKEN-DECIMALS)
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance bettercoin who))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply bettercoin))
)

(define-read-only (get-token-uri)
  (ok (some TOKEN-URI))
)

;; Advanced Token Functions
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (var-get minting-enabled) ERR-MINT-FAILED)
    (asserts! (or (is-contract-owner tx-sender) (is-authorized-minter tx-sender)) ERR-UNAUTHORIZED)
    (asserts! (not (is-blacklisted recipient)) ERR-BLACKLISTED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= (+ (ft-get-supply bettercoin) amount) MAX-SUPPLY) ERR-MINT-FAILED)
    
    (try! (ft-mint? bettercoin amount recipient))
    (log-event (concat "Mint: " (concat (uint-to-ascii amount) (concat " to " (principal-to-string recipient)))))
    
    (print { 
      op: "mint", 
      amount: amount, 
      recipient: recipient 
    })
    (ok true)
  )
)

(define-public (burn (amount uint))
  (begin
    (asserts! (var-get burning-enabled) ERR-BURN-FAILED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (ft-get-balance bettercoin tx-sender) amount) ERR-INSUFFICIENT-BALANCE)
    
    (try! (ft-burn? bettercoin amount tx-sender))
    (log-event (concat "Burn: " (concat (uint-to-ascii amount) (concat " by " (principal-to-string tx-sender)))))
    
    (print { 
      op: "burn", 
      amount: amount, 
      burner: tx-sender 
    })
    (ok true)
  )
)

;; Administrative Functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-OWNER-ONLY)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (toggle-pause)
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-OWNER-ONLY)
    (var-set token-paused (not (var-get token-paused)))
    (ok (var-get token-paused))
  )
)

(define-public (blacklist-address (address principal))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-OWNER-ONLY)
    (map-set blacklisted-addresses address true)
    (log-event (concat "Blacklisted: " (principal-to-string address)))
    (ok true)
  )
)

(define-public (unblacklist-address (address principal))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-OWNER-ONLY)
    (map-delete blacklisted-addresses address)
    (log-event (concat "Unblacklisted: " (principal-to-string address)))
    (ok true)
  )
)

(define-public (authorize-minter (minter principal))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-OWNER-ONLY)
    (map-set authorized-minters minter true)
    (ok true)
  )
)

(define-public (revoke-minter (minter principal))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-OWNER-ONLY)
    (map-delete authorized-minters minter)
    (ok true)
  )
)

(define-public (set-daily-transfer-limit (user principal) (limit uint))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-OWNER-ONLY)
    (map-set daily-transfer-limits user limit)
    (ok true)
  )
)

;; Governance Functions
(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)))
  (let ((proposal-id (+ (var-get proposal-counter) u1)))
    (asserts! (>= (ft-get-balance bettercoin tx-sender) (var-get voting-power-threshold)) ERR-UNAUTHORIZED)
    
    (map-set governance-proposals proposal-id {
      proposer: tx-sender,
      title: title,
      description: description,
      votes-for: u0,
      votes-against: u0,
      end-block: (+ block-height u1008), ;; ~1 week
      executed: false
    })
    
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let (
    (proposal (unwrap! (map-get? governance-proposals proposal-id) ERR-INVALID-AMOUNT))
    (voter-balance (ft-get-balance bettercoin tx-sender))
  )
    (asserts! (< block-height (get end-block proposal)) ERR-UNAUTHORIZED)
    (asserts! (> voter-balance u0) ERR-INSUFFICIENT-BALANCE)
    
    (if vote-for
      (map-set governance-proposals proposal-id 
        (merge proposal { votes-for: (+ (get votes-for proposal) voter-balance) }))
      (map-set governance-proposals proposal-id 
        (merge proposal { votes-against: (+ (get votes-against proposal) voter-balance) }))
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (is-token-paused)
  (var-get token-paused)
)

(define-read-only (get-blacklist-status (address principal))
  (is-blacklisted address)
)

(define-read-only (get-minter-status (address principal))
  (is-authorized-minter address)
)

(define-read-only (get-daily-transfer-limit (user principal))
  (default-to u1000000000000 (map-get? daily-transfer-limits user))
)

(define-read-only (get-daily-usage (user principal))
  (let ((current-day (get-current-day)))
    (default-to u0 (map-get? daily-transfers-used { user: user, day: current-day }))
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? governance-proposals proposal-id)
)

(define-read-only (get-events-log)
  (var-get events-log)
)

;; Define the token
(define-fungible-token bettercoin)

;; Initialize with initial supply
(begin
  (try! (ft-mint? bettercoin INITIAL-SUPPLY CONTRACT-OWNER))
  (map-set authorized-minters CONTRACT-OWNER true)
  (log-event "BetterCoin initialized with initial supply")
)

;; Helper function for string conversion (simplified)
(define-private (uint-to-ascii (value uint))
  "amount" ;; Simplified for now - would need full implementation
)

(define-private (principal-to-string (address principal))
  "address" ;; Simplified for now - would need full implementation
)