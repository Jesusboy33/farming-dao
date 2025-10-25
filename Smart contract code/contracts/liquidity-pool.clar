;; BetterCoin Liquidity Pool - Advanced AMM with Yield Farming
;; Automated Market Maker with dynamic fees, yield farming, and advanced liquidity management

;; Import BetterCoin trait
(use-trait ft-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u200))
(define-constant ERR-INSUFFICIENT-BALANCE (err u201))
(define-constant ERR-INVALID-AMOUNT (err u202))
(define-constant ERR-SLIPPAGE-TOO-HIGH (err u203))
(define-constant ERR-POOL-NOT-EXISTS (err u204))
(define-constant ERR-INSUFFICIENT-LIQUIDITY (err u205))
(define-constant ERR-UNAUTHORIZED (err u206))
(define-constant ERR-PAUSED (err u207))
(define-constant ERR-DEADLINE-EXCEEDED (err u208))
(define-constant ERR-INVALID-PAIR (err u209))
(define-constant ERR-ZERO-LIQUIDITY (err u210))

;; Pool Constants
(define-constant MINIMUM-LIQUIDITY u1000)
(define-constant FEE-RATE u300) ;; 0.3% = 300/100000
(define-constant PROTOCOL-FEE-RATE u50) ;; 0.05% = 50/100000
(define-constant YIELD-FARM-RATE u500) ;; 0.5% = 500/100000

;; Data Variables
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var protocol-paused bool false)
(define-data-var total-pools uint u0)
(define-data-var protocol-fee-collector principal CONTRACT-OWNER)

;; Pool Information
(define-map pools uint {
  token-a: principal,
  token-b: principal,
  reserve-a: uint,
  reserve-b: uint,
  lp-token-supply: uint,
  fee-rate: uint,
  active: bool,
  created-block: uint,
  last-update: uint
})

(define-map pool-by-tokens 
  { token-a: principal, token-b: principal }
  uint
)

;; Liquidity Provider Information
(define-map lp-positions 
  { pool-id: uint, provider: principal }
  { 
    lp-tokens: uint,
    deposited-a: uint,
    deposited-b: uint,
    rewards-earned: uint,
    last-claim: uint
  }
)

;; Yield Farming
(define-map staking-positions
  { pool-id: uint, user: principal }
  {
    staked-lp: uint,
    reward-debt: uint,
    deposit-block: uint
  }
)

(define-map pool-rewards uint {
  reward-per-block: uint,
  total-staked: uint,
  acc-reward-per-share: uint,
  last-reward-block: uint
})

;; Trading History
(define-map trade-history
  { pool-id: uint, trader: principal, block: uint }
  {
    token-in: principal,
    token-out: principal,
    amount-in: uint,
    amount-out: uint,
    fee-paid: uint
  }
)

;; Price Oracle
(define-map price-cumulative uint {
  price-a-cumulative: uint,
  price-b-cumulative: uint,
  last-update-time: uint
})

;; Authorization
(define-private (is-contract-owner (user principal))
  (is-eq user (var-get contract-owner))
)

(define-private (is-protocol-paused)
  (var-get protocol-paused)
)

;; Utility Functions
(define-private (sqrt (x uint))
  ;; Simple integer square root using Newton's method
  (if (<= x u1)
    x
    (let ((initial-guess (/ x u2)))
      (sqrt-helper x initial-guess)
    )
  )
)

(define-private (sqrt-helper (x uint) (guess uint))
  (let ((new-guess (/ (+ guess (/ x guess)) u2)))
    (if (< (abs-diff new-guess guess) u1)
      new-guess
      (sqrt-helper x new-guess)
    )
  )
)

(define-private (abs-diff (a uint) (b uint))
  (if (>= a b) (- a b) (- b a))
)

(define-private (min (a uint) (b uint))
  (if (<= a b) a b)
)

(define-private (max (a uint) (b uint))
  (if (>= a b) a b)
)

;; AMM Pricing Functions
(define-private (get-amount-out (amount-in uint) (reserve-in uint) (reserve-out uint) (fee-rate uint))
  (let (
    (amount-in-with-fee (- amount-in (/ (* amount-in fee-rate) u100000)))
    (numerator (* amount-in-with-fee reserve-out))
    (denominator (+ reserve-in amount-in-with-fee))
  )
    (/ numerator denominator)
  )
)

(define-private (get-amount-in (amount-out uint) (reserve-in uint) (reserve-out uint) (fee-rate uint))
  (let (
    (numerator (* reserve-in amount-out))
    (denominator (- reserve-out amount-out))
    (amount-in (/ numerator denominator))
    (fee-multiplier (+ u100000 fee-rate))
  )
    (/ (* amount-in fee-multiplier) u100000)
  )
)

;; Pool Management Functions
(define-public (create-pool 
  (token-a <ft-trait>) 
  (token-b <ft-trait>) 
  (initial-a uint) 
  (initial-b uint)
)
  (let (
    (pool-id (+ (var-get total-pools) u1))
    (token-a-principal (contract-of token-a))
    (token-b-principal (contract-of token-b))
  )
    (asserts! (not (is-protocol-paused)) ERR-PAUSED)
    (asserts! (> initial-a u0) ERR-INVALID-AMOUNT)
    (asserts! (> initial-b u0) ERR-INVALID-AMOUNT)
    (asserts! (not (is-eq token-a-principal token-b-principal)) ERR-INVALID-PAIR)
    
    ;; Check if pool already exists
    (asserts! (is-none (map-get? pool-by-tokens { token-a: token-a-principal, token-b: token-b-principal })) ERR-POOL-NOT-EXISTS)
    (asserts! (is-none (map-get? pool-by-tokens { token-a: token-b-principal, token-b: token-a-principal })) ERR-POOL-NOT-EXISTS)
    
    ;; Transfer tokens from user
    (try! (contract-call? token-a transfer initial-a tx-sender (as-contract tx-sender) none))
    (try! (contract-call? token-b transfer initial-b tx-sender (as-contract tx-sender) none))
    
    ;; Calculate initial LP tokens (geometric mean)
    (let ((initial-lp (sqrt (* initial-a initial-b))))
      (asserts! (>= initial-lp MINIMUM-LIQUIDITY) ERR-ZERO-LIQUIDITY)
      
      ;; Create pool
      (map-set pools pool-id {
        token-a: token-a-principal,
        token-b: token-b-principal,
        reserve-a: initial-a,
        reserve-b: initial-b,
        lp-token-supply: initial-lp,
        fee-rate: FEE-RATE,
        active: true,
        created-block: block-height,
        last-update: block-height
      })
      
      (map-set pool-by-tokens 
        { token-a: token-a-principal, token-b: token-b-principal } 
        pool-id
      )
      
      ;; Set LP position for creator
      (map-set lp-positions 
        { pool-id: pool-id, provider: tx-sender }
        {
          lp-tokens: initial-lp,
          deposited-a: initial-a,
          deposited-b: initial-b,
          rewards-earned: u0,
          last-claim: block-height
        }
      )
      
      ;; Initialize yield farming
      (map-set pool-rewards pool-id {
        reward-per-block: u1000000, ;; 0.01 BETT per block
        total-staked: u0,
        acc-reward-per-share: u0,
        last-reward-block: block-height
      })
      
      ;; Update state
      (var-set total-pools pool-id)
      
      (print { 
        op: "create-pool", 
        pool-id: pool-id, 
        token-a: token-a-principal, 
        token-b: token-b-principal,
        initial-a: initial-a,
        initial-b: initial-b,
        lp-tokens: initial-lp
      })
      
      (ok pool-id)
    )
  )
)

(define-public (add-liquidity 
  (pool-id uint)
  (token-a <ft-trait>)
  (token-b <ft-trait>)
  (amount-a-desired uint)
  (amount-b-desired uint)
  (amount-a-min uint)
  (amount-b-min uint)
  (deadline uint)
)
  (begin
    (asserts! (not (is-protocol-paused)) ERR-PAUSED)
    (asserts! (<= block-height deadline) ERR-DEADLINE-EXCEEDED)
    
    (let (
      (pool (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-EXISTS))
      (reserve-a (get reserve-a pool))
      (reserve-b (get reserve-b pool))
      (lp-supply (get lp-token-supply pool))
    )
      (asserts! (get active pool) ERR-POOL-NOT-EXISTS)
      (asserts! (> amount-a-desired u0) ERR-INVALID-AMOUNT)
      (asserts! (> amount-b-desired u0) ERR-INVALID-AMOUNT)
      
      ;; Calculate optimal amounts
      (let (
        (amount-b-optimal (/ (* amount-a-desired reserve-b) reserve-a))
        (amount-a-optimal (/ (* amount-b-desired reserve-a) reserve-b))
        (amount-a-final (if (<= amount-b-optimal amount-b-desired)
                         amount-a-desired
                         amount-a-optimal))
        (amount-b-final (if (<= amount-b-optimal amount-b-desired)
                         amount-b-optimal
                         amount-b-desired))
      )
        (asserts! (>= amount-a-final amount-a-min) ERR-SLIPPAGE-TOO-HIGH)
        (asserts! (>= amount-b-final amount-b-min) ERR-SLIPPAGE-TOO-HIGH)
        
        ;; Calculate LP tokens to mint
        (let ((lp-tokens (min 
                           (/ (* amount-a-final lp-supply) reserve-a)
                           (/ (* amount-b-final lp-supply) reserve-b))))
          
          ;; Transfer tokens from user
          (try! (contract-call? token-a transfer amount-a-final tx-sender (as-contract tx-sender) none))
          (try! (contract-call? token-b transfer amount-b-final tx-sender (as-contract tx-sender) none))
          
          ;; Update pool reserves
          (map-set pools pool-id (merge pool {
            reserve-a: (+ reserve-a amount-a-final),
            reserve-b: (+ reserve-b amount-b-final),
            lp-token-supply: (+ lp-supply lp-tokens),
            last-update: block-height
          }))
          
          ;; Update LP position
          (let ((existing-position (default-to 
                                     { lp-tokens: u0, deposited-a: u0, deposited-b: u0, rewards-earned: u0, last-claim: block-height }
                                     (map-get? lp-positions { pool-id: pool-id, provider: tx-sender }))))
            (map-set lp-positions 
              { pool-id: pool-id, provider: tx-sender }
              {
                lp-tokens: (+ (get lp-tokens existing-position) lp-tokens),
                deposited-a: (+ (get deposited-a existing-position) amount-a-final),
                deposited-b: (+ (get deposited-b existing-position) amount-b-final),
                rewards-earned: (get rewards-earned existing-position),
                last-claim: (get last-claim existing-position)
              }
            )
          )
          
          (print { 
            op: "add-liquidity", 
            pool-id: pool-id, 
            amount-a: amount-a-final,
            amount-b: amount-b-final,
            lp-tokens: lp-tokens,
            provider: tx-sender
          })
          
          (ok { lp-tokens: lp-tokens, amount-a: amount-a-final, amount-b: amount-b-final })
        )
      )
    )
  )
)

(define-public (remove-liquidity
  (pool-id uint)
  (token-a <ft-trait>)
  (token-b <ft-trait>)
  (lp-tokens uint)
  (amount-a-min uint)
  (amount-b-min uint)
  (deadline uint)
)
  (begin
    (asserts! (not (is-protocol-paused)) ERR-PAUSED)
    (asserts! (<= block-height deadline) ERR-DEADLINE-EXCEEDED)
    (asserts! (> lp-tokens u0) ERR-INVALID-AMOUNT)
    
    (let (
      (pool (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-EXISTS))
      (position (unwrap! (map-get? lp-positions { pool-id: pool-id, provider: tx-sender }) ERR-INSUFFICIENT-BALANCE))
      (reserve-a (get reserve-a pool))
      (reserve-b (get reserve-b pool))
      (lp-supply (get lp-token-supply pool))
    )
      (asserts! (get active pool) ERR-POOL-NOT-EXISTS)
      (asserts! (>= (get lp-tokens position) lp-tokens) ERR-INSUFFICIENT-BALANCE)
      
      ;; Calculate amounts to return
      (let (
        (amount-a (/ (* lp-tokens reserve-a) lp-supply))
        (amount-b (/ (* lp-tokens reserve-b) lp-supply))
      )
        (asserts! (>= amount-a amount-a-min) ERR-SLIPPAGE-TOO-HIGH)
        (asserts! (>= amount-b amount-b-min) ERR-SLIPPAGE-TOO-HIGH)
        
        ;; Transfer tokens to user
        (try! (as-contract (contract-call? token-a transfer amount-a tx-sender tx-sender none)))
        (try! (as-contract (contract-call? token-b transfer amount-b tx-sender tx-sender none)))
        
        ;; Update pool reserves
        (map-set pools pool-id (merge pool {
          reserve-a: (- reserve-a amount-a),
          reserve-b: (- reserve-b amount-b),
          lp-token-supply: (- lp-supply lp-tokens),
          last-update: block-height
        }))
        
        ;; Update LP position
        (if (is-eq lp-tokens (get lp-tokens position))
          ;; Remove entire position
          (map-delete lp-positions { pool-id: pool-id, provider: tx-sender })
          ;; Update position
          (map-set lp-positions 
            { pool-id: pool-id, provider: tx-sender }
            (merge position {
              lp-tokens: (- (get lp-tokens position) lp-tokens),
              deposited-a: (- (get deposited-a position) (/ (* (get deposited-a position) lp-tokens) (get lp-tokens position))),
              deposited-b: (- (get deposited-b position) (/ (* (get deposited-b position) lp-tokens) (get lp-tokens position)))
            })
          )
        )
        
        (print { 
          op: "remove-liquidity", 
          pool-id: pool-id, 
          lp-tokens: lp-tokens,
          amount-a: amount-a,
          amount-b: amount-b,
          provider: tx-sender
        })
        
        (ok { amount-a: amount-a, amount-b: amount-b })
      )
    )
  )
)

;; Trading Functions
(define-public (swap-exact-tokens-for-tokens
  (pool-id uint)
  (token-in <ft-trait>)
  (token-out <ft-trait>)
  (amount-in uint)
  (amount-out-min uint)
  (deadline uint)
)
  (begin
    (asserts! (not (is-protocol-paused)) ERR-PAUSED)
    (asserts! (<= block-height deadline) ERR-DEADLINE-EXCEEDED)
    (asserts! (> amount-in u0) ERR-INVALID-AMOUNT)
    
    (let (
      (pool (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-EXISTS))
      (token-in-principal (contract-of token-in))
      (token-out-principal (contract-of token-out))
    )
      (asserts! (get active pool) ERR-POOL-NOT-EXISTS)
      
      ;; Determine which token is A and B
      (let (
        (is-a-to-b (is-eq token-in-principal (get token-a pool)))
        (reserve-in (if is-a-to-b (get reserve-a pool) (get reserve-b pool)))
        (reserve-out (if is-a-to-b (get reserve-b pool) (get reserve-a pool)))
        (amount-out (get-amount-out amount-in reserve-in reserve-out (get fee-rate pool)))
      )
        (asserts! (>= amount-out amount-out-min) ERR-SLIPPAGE-TOO-HIGH)
        (asserts! (< amount-out reserve-out) ERR-INSUFFICIENT-LIQUIDITY)
        
        ;; Calculate fees
        (let (
          (fee-amount (/ (* amount-in (get fee-rate pool)) u100000))
          (protocol-fee (/ (* fee-amount PROTOCOL-FEE-RATE) FEE-RATE))
          (lp-fee (- fee-amount protocol-fee))
        )
          ;; Transfer tokens
          (try! (contract-call? token-in transfer amount-in tx-sender (as-contract tx-sender) none))
          (try! (as-contract (contract-call? token-out transfer amount-out tx-sender tx-sender none)))
          
          ;; Update reserves
          (if is-a-to-b
            (map-set pools pool-id (merge pool {
              reserve-a: (+ reserve-in amount-in),
              reserve-b: (- reserve-out amount-out),
              last-update: block-height
            }))
            (map-set pools pool-id (merge pool {
              reserve-a: (- reserve-out amount-out),
              reserve-b: (+ reserve-in amount-in),
              last-update: block-height
            }))
          )
          
          ;; Record trade
          (map-set trade-history 
            { pool-id: pool-id, trader: tx-sender, block: block-height }
            {
              token-in: token-in-principal,
              token-out: token-out-principal,
              amount-in: amount-in,
              amount-out: amount-out,
              fee-paid: fee-amount
            }
          )
          
          (print { 
            op: "swap", 
            pool-id: pool-id, 
            token-in: token-in-principal,
            token-out: token-out-principal,
            amount-in: amount-in,
            amount-out: amount-out,
            fee: fee-amount,
            trader: tx-sender
          })
          
          (ok amount-out)
        )
      )
    )
  )
)

;; Yield Farming Functions
(define-public (stake-lp-tokens (pool-id uint) (amount uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR-PAUSED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (let (
      (position (unwrap! (map-get? lp-positions { pool-id: pool-id, provider: tx-sender }) ERR-INSUFFICIENT-BALANCE))
      (staking-pos (default-to 
                     { staked-lp: u0, reward-debt: u0, deposit-block: block-height }
                     (map-get? staking-positions { pool-id: pool-id, user: tx-sender })))
      (pool-reward (unwrap! (map-get? pool-rewards pool-id) ERR-POOL-NOT-EXISTS))
    )
      (asserts! (>= (get lp-tokens position) amount) ERR-INSUFFICIENT-BALANCE)
      
      ;; Update pool rewards
      (try! (update-pool-rewards pool-id))
      
      ;; Calculate pending rewards
      (let (
        (acc-reward (get acc-reward-per-share pool-reward))
        (pending-rewards (- (/ (* (get staked-lp staking-pos) acc-reward) u1000000000000)
                           (get reward-debt staking-pos)))
      )
        ;; Update staking position
        (map-set staking-positions
          { pool-id: pool-id, user: tx-sender }
          {
            staked-lp: (+ (get staked-lp staking-pos) amount),
            reward-debt: (/ (* (+ (get staked-lp staking-pos) amount) acc-reward) u1000000000000),
            deposit-block: block-height
          }
        )
        
        ;; Update pool total staked
        (map-set pool-rewards pool-id
          (merge pool-reward {
            total-staked: (+ (get total-staked pool-reward) amount)
          })
        )
        
        (print { 
          op: "stake-lp", 
          pool-id: pool-id, 
          amount: amount,
          pending-rewards: pending-rewards,
          user: tx-sender
        })
        
        (ok true)
      )
    )
  )
)

(define-public (unstake-lp-tokens (pool-id uint) (amount uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR-PAUSED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (let (
      (staking-pos (unwrap! (map-get? staking-positions { pool-id: pool-id, user: tx-sender }) ERR-INSUFFICIENT-BALANCE))
      (pool-reward (unwrap! (map-get? pool-rewards pool-id) ERR-POOL-NOT-EXISTS))
    )
      (asserts! (>= (get staked-lp staking-pos) amount) ERR-INSUFFICIENT-BALANCE)
      
      ;; Update pool rewards
      (try! (update-pool-rewards pool-id))
      
      ;; Calculate pending rewards
      (let (
        (acc-reward (get acc-reward-per-share pool-reward))
        (pending-rewards (- (/ (* (get staked-lp staking-pos) acc-reward) u1000000000000)
                           (get reward-debt staking-pos)))
      )
        ;; Update staking position
        (if (is-eq amount (get staked-lp staking-pos))
          (map-delete staking-positions { pool-id: pool-id, user: tx-sender })
          (map-set staking-positions
            { pool-id: pool-id, user: tx-sender }
            {
              staked-lp: (- (get staked-lp staking-pos) amount),
              reward-debt: (/ (* (- (get staked-lp staking-pos) amount) acc-reward) u1000000000000),
              deposit-block: (get deposit-block staking-pos)
            }
          )
        )
        
        ;; Update pool total staked
        (map-set pool-rewards pool-id
          (merge pool-reward {
            total-staked: (- (get total-staked pool-reward) amount)
          })
        )
        
        (print { 
          op: "unstake-lp", 
          pool-id: pool-id, 
          amount: amount,
          pending-rewards: pending-rewards,
          user: tx-sender
        })
        
        (ok pending-rewards)
      )
    )
  )
)

(define-private (update-pool-rewards (pool-id uint))
  (let (
    (pool-reward (unwrap! (map-get? pool-rewards pool-id) ERR-POOL-NOT-EXISTS))
    (blocks-passed (- block-height (get last-reward-block pool-reward)))
    (total-staked (get total-staked pool-reward))
  )
    (if (and (> blocks-passed u0) (> total-staked u0))
      (let (
        (reward-amount (* blocks-passed (get reward-per-block pool-reward)))
        (reward-per-share (/ (* reward-amount u1000000000000) total-staked))
      )
        (map-set pool-rewards pool-id
          (merge pool-reward {
            acc-reward-per-share: (+ (get acc-reward-per-share pool-reward) reward-per-share),
            last-reward-block: block-height
          })
        )
        (ok true)
      )
      (begin
        (map-set pool-rewards pool-id
          (merge pool-reward { last-reward-block: block-height })
        )
        (ok true)
      )
    )
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

(define-public (toggle-protocol-pause)
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-OWNER-ONLY)
    (var-set protocol-paused (not (var-get protocol-paused)))
    (ok (var-get protocol-paused))
  )
)

(define-public (emergency-withdraw (pool-id uint) (token <ft-trait>) (amount uint))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-OWNER-ONLY)
    (try! (as-contract (contract-call? token transfer amount tx-sender tx-sender none)))
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-pool (pool-id uint))
  (map-get? pools pool-id)
)

(define-read-only (get-lp-position (pool-id uint) (provider principal))
  (map-get? lp-positions { pool-id: pool-id, provider: provider })
)

(define-read-only (get-staking-position (pool-id uint) (user principal))
  (map-get? staking-positions { pool-id: pool-id, user: user })
)

(define-read-only (get-pool-rewards (pool-id uint))
  (map-get? pool-rewards pool-id)
)

(define-read-only (get-trade-history (pool-id uint) (trader principal) (block uint))
  (map-get? trade-history { pool-id: pool-id, trader: trader, block: block })
)

(define-read-only (get-total-pools)
  (var-get total-pools)
)

(define-read-only (calculate-swap-output (pool-id uint) (token-in principal) (amount-in uint))
  (match (map-get? pools pool-id)
    pool (let (
      (is-a-to-b (is-eq token-in (get token-a pool)))
      (reserve-in (if is-a-to-b (get reserve-a pool) (get reserve-b pool)))
      (reserve-out (if is-a-to-b (get reserve-b pool) (get reserve-a pool)))
    )
      (ok (get-amount-out amount-in reserve-in reserve-out (get fee-rate pool)))
    )
    ERR-POOL-NOT-EXISTS
  )
)

(define-read-only (get-pending-rewards (pool-id uint) (user principal))
  (match (map-get? staking-positions { pool-id: pool-id, user: user })
    staking-pos (match (map-get? pool-rewards pool-id)
      pool-reward (let (
        (blocks-passed (- block-height (get last-reward-block pool-reward)))
        (total-staked (get total-staked pool-reward))
        (current-acc (get acc-reward-per-share pool-reward))
        (new-acc (if (and (> blocks-passed u0) (> total-staked u0))
                   (+ current-acc (/ (* (* blocks-passed (get reward-per-block pool-reward)) u1000000000000) total-staked))
                   current-acc))
      )
        (ok (- (/ (* (get staked-lp staking-pos) new-acc) u1000000000000)
               (get reward-debt staking-pos)))
      )
      ERR-POOL-NOT-EXISTS
    )
    (ok u0)
  )
)