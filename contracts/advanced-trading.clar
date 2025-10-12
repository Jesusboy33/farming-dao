;; Advanced Trading Engine - Limit Orders, Market Making, and Price Discovery
;; Sophisticated trading system with order book, limit orders, and automated market making

;; Import BetterCoin trait
(use-trait ft-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u300))
(define-constant ERR-INSUFFICIENT-BALANCE (err u301))
(define-constant ERR-INVALID-AMOUNT (err u302))
(define-constant ERR-INVALID-PRICE (err u303))
(define-constant ERR-ORDER-NOT-EXISTS (err u304))
(define-constant ERR-UNAUTHORIZED (err u305))
(define-constant ERR-PAUSED (err u306))
(define-constant ERR-DEADLINE-EXCEEDED (err u307))
(define-constant ERR-ORDER-EXPIRED (err u308))
(define-constant ERR-INVALID-PAIR (err u309))
(define-constant ERR-SLIPPAGE-TOO-HIGH (err u310))
(define-constant ERR-MARKET-CLOSED (err u311))

;; Order Types
(define-constant ORDER-TYPE-MARKET u1)
(define-constant ORDER-TYPE-LIMIT u2)
(define-constant ORDER-TYPE-STOP-LOSS u3)
(define-constant ORDER-TYPE-TAKE-PROFIT u4)

;; Order Status
(define-constant ORDER-STATUS-OPEN u1)
(define-constant ORDER-STATUS-FILLED u2)
(define-constant ORDER-STATUS-CANCELLED u3)
(define-constant ORDER-STATUS-PARTIAL u4)

;; Trading Parameters
(define-constant MIN-ORDER-SIZE u1000000) ;; 0.01 tokens
(define-constant MAX-ORDER-SIZE u100000000000000) ;; 1M tokens
(define-constant MAKER-FEE u150) ;; 0.15%
(define-constant TAKER-FEE u250) ;; 0.25%
(define-constant PRICE-PRECISION u100000000) ;; 8 decimal places

;; Data Variables
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var trading-paused bool false)
(define-data-var order-counter uint u0)
(define-data-var total-trading-pairs uint u0)
(define-data-var fee-collector principal CONTRACT-OWNER)

;; Trading Pairs
(define-map trading-pairs uint {
  base-token: principal,
  quote-token: principal,
  active: bool,
  min-price: uint,
  max-price: uint,
  price-increment: uint,
  volume-24h: uint,
  last-price: uint,
  created-block: uint
})

(define-map pair-by-tokens 
  { base: principal, quote: principal }
  uint
)

;; Order Book
(define-map orders uint {
  trader: principal,
  pair-id: uint,
  order-type: uint,
  side: bool, ;; true for buy, false for sell
  amount: uint,
  filled-amount: uint,
  price: uint,
  status: uint,
  created-block: uint,
  expires-block: (optional uint),
  stop-price: (optional uint),
  fee-paid: uint
})

;; Order Book Levels (Price -> Total Amount)
(define-map order-book-bids 
  { pair-id: uint, price: uint }
  { total-amount: uint, order-count: uint }
)

(define-map order-book-asks
  { pair-id: uint, price: uint }
  { total-amount: uint, order-count: uint }
)

;; Market Making
(define-map market-makers uint {
  maker: principal,
  pair-id: uint,
  bid-price: uint,
  ask-price: uint,
  bid-amount: uint,
  ask-amount: uint,
  spread: uint,
  active: bool,
  rewards-earned: uint
})

(define-data-var mm-counter uint u0)

;; Price History for TWAP calculation
(define-map price-history
  { pair-id: uint, block: uint }
  { price: uint, volume: uint, timestamp: uint }
)

;; User Statistics
(define-map trader-stats principal {
  total-volume: uint,
  total-trades: uint,
  maker-volume: uint,
  taker-volume: uint,
  fees-paid: uint,
  last-trade-block: uint
})

;; Pair Statistics
(define-map pair-stats uint {
  total-volume: uint,
  total-trades: uint,
  high-24h: uint,
  low-24h: uint,
  open-24h: uint,
  last-update: uint
})

;; Authorization Functions
(define-private (is-contract-owner (user principal))
  (is-eq user (var-get contract-owner))
)

(define-private (is-trading-paused)
  (var-get trading-paused)
)

;; Utility Functions
(define-private (calculate-fee (amount uint) (fee-rate uint))
  (/ (* amount fee-rate) u100000)
)

(define-private (is-valid-price (price uint) (pair-id uint))
  (match (map-get? trading-pairs pair-id)
    pair (and 
      (>= price (get min-price pair))
      (<= price (get max-price pair))
      (is-eq (mod price (get price-increment pair)) u0))
    false
  )
)

(define-private (update-order-book-level (pair-id uint) (price uint) (amount uint) (is-buy bool) (is-add bool))
  (let (
    (book-map (if is-buy order-book-bids order-book-asks))
    (current-level (default-to { total-amount: u0, order-count: u0 } 
                                (if is-buy 
                                  (map-get? order-book-bids { pair-id: pair-id, price: price })
                                  (map-get? order-book-asks { pair-id: pair-id, price: price }))))
  )
    (if is-buy
      (if is-add
        (map-set order-book-bids 
          { pair-id: pair-id, price: price }
          { 
            total-amount: (+ (get total-amount current-level) amount),
            order-count: (+ (get order-count current-level) u1)
          })
        (if (> (get total-amount current-level) amount)
          (map-set order-book-bids 
            { pair-id: pair-id, price: price }
            { 
              total-amount: (- (get total-amount current-level) amount),
              order-count: (- (get order-count current-level) u1)
            })
          (map-delete order-book-bids { pair-id: pair-id, price: price })
        )
      )
      (if is-add
        (map-set order-book-asks 
          { pair-id: pair-id, price: price }
          { 
            total-amount: (+ (get total-amount current-level) amount),
            order-count: (+ (get order-count current-level) u1)
          })
        (if (> (get total-amount current-level) amount)
          (map-set order-book-asks 
            { pair-id: pair-id, price: price }
            { 
              total-amount: (- (get total-amount current-level) amount),
              order-count: (- (get order-count current-level) u1)
            })
          (map-delete order-book-asks { pair-id: pair-id, price: price })
        )
      )
    )
  )
)

;; Trading Pair Management
(define-public (create-trading-pair 
  (base-token <ft-trait>)
  (quote-token <ft-trait>)
  (min-price uint)
  (max-price uint)
  (price-increment uint)
)
  (let (
    (pair-id (+ (var-get total-trading-pairs) u1))
    (base-principal (contract-of base-token))
    (quote-principal (contract-of quote-token))
  )
    (asserts! (is-contract-owner tx-sender) ERR-OWNER-ONLY)
    (asserts! (not (is-eq base-principal quote-principal)) ERR-INVALID-PAIR)
    (asserts! (> min-price u0) ERR-INVALID-PRICE)
    (asserts! (> max-price min-price) ERR-INVALID-PRICE)
    (asserts! (> price-increment u0) ERR-INVALID-PRICE)
    
    ;; Check if pair already exists
    (asserts! (is-none (map-get? pair-by-tokens { base: base-principal, quote: quote-principal })) ERR-INVALID-PAIR)
    
    ;; Create trading pair
    (map-set trading-pairs pair-id {
      base-token: base-principal,
      quote-token: quote-principal,
      active: true,
      min-price: min-price,
      max-price: max-price,
      price-increment: price-increment,
      volume-24h: u0,
      last-price: (/ (+ min-price max-price) u2), ;; Mid-price as initial
      created-block: block-height
    })
    
    (map-set pair-by-tokens 
      { base: base-principal, quote: quote-principal }
      pair-id
    )
    
    ;; Initialize pair statistics
    (map-set pair-stats pair-id {
      total-volume: u0,
      total-trades: u0,
      high-24h: u0,
      low-24h: u340282366920938463463374607431768211455, ;; Max uint
      open-24h: (/ (+ min-price max-price) u2),
      last-update: block-height
    })
    
    (var-set total-trading-pairs pair-id)
    
    (print { 
      op: "create-pair", 
      pair-id: pair-id, 
      base-token: base-principal, 
      quote-token: quote-principal 
    })
    
    (ok pair-id)
  )
)

;; Order Management
(define-public (place-limit-order
  (pair-id uint)
  (base-token <ft-trait>)
  (quote-token <ft-trait>)
  (side bool) ;; true for buy, false for sell
  (amount uint)
  (price uint)
  (expires-block (optional uint))
)
  (begin
    (asserts! (not (is-trading-paused)) ERR-PAUSED)
    (asserts! (>= amount MIN-ORDER-SIZE) ERR-INVALID-AMOUNT)
    (asserts! (<= amount MAX-ORDER-SIZE) ERR-INVALID-AMOUNT)
    (asserts! (is-valid-price price pair-id) ERR-INVALID-PRICE)
    
    (let (
      (pair (unwrap! (map-get? trading-pairs pair-id) ERR-INVALID-PAIR))
      (order-id (+ (var-get order-counter) u1))
      (required-balance (if side (* amount price) amount))
      (token-for-balance (if side quote-token base-token))
    )
      (asserts! (get active pair) ERR-MARKET-CLOSED)
      
      ;; Check expiration
      (match expires-block
        exp-block (asserts! (> exp-block block-height) ERR-ORDER-EXPIRED)
        true
      )
      
      ;; Check user balance
      (let ((user-balance (unwrap-panic (contract-call? token-for-balance get-balance tx-sender))))
        (asserts! (>= user-balance required-balance) ERR-INSUFFICIENT-BALANCE)
        
        ;; Lock tokens (transfer to contract)
        (try! (contract-call? token-for-balance transfer required-balance tx-sender (as-contract tx-sender) none))
        
        ;; Create order
        (map-set orders order-id {
          trader: tx-sender,
          pair-id: pair-id,
          order-type: ORDER-TYPE-LIMIT,
          side: side,
          amount: amount,
          filled-amount: u0,
          price: price,
          status: ORDER-STATUS-OPEN,
          created-block: block-height,
          expires-block: expires-block,
          stop-price: none,
          fee-paid: u0
        })
        
        ;; Update order book
        (update-order-book-level pair-id price amount side true)
        
        ;; Update counters
        (var-set order-counter order-id)
        
        ;; Try to match order immediately
        (try! (match-order order-id))
        
        (print { 
          op: "place-order", 
          order-id: order-id, 
          pair-id: pair-id, 
          side: side, 
          amount: amount, 
          price: price 
        })
        
        (ok order-id)
      )
    )
  )
)

(define-public (place-market-order
  (pair-id uint)
  (base-token <ft-trait>)
  (quote-token <ft-trait>)
  (side bool) ;; true for buy, false for sell
  (amount uint)
  (max-slippage uint) ;; in basis points (100 = 1%)
)
  (begin
    (asserts! (not (is-trading-paused)) ERR-PAUSED)
    (asserts! (>= amount MIN-ORDER-SIZE) ERR-INVALID-AMOUNT)
    (asserts! (<= amount MAX-ORDER-SIZE) ERR-INVALID-AMOUNT)
    
    (let (
      (pair (unwrap! (map-get? trading-pairs pair-id) ERR-INVALID-PAIR))
      (order-id (+ (var-get order-counter) u1))
      (market-price (get last-price pair))
      (max-price (if side 
                   (+ market-price (/ (* market-price max-slippage) u10000))
                   (- market-price (/ (* market-price max-slippage) u10000))))
    )
      (asserts! (get active pair) ERR-MARKET-CLOSED)
      
      ;; Create market order (will be matched immediately)
      (map-set orders order-id {
        trader: tx-sender,
        pair-id: pair-id,
        order-type: ORDER-TYPE-MARKET,
        side: side,
        amount: amount,
        filled-amount: u0,
        price: market-price,
        status: ORDER-STATUS-OPEN,
        created-block: block-height,
        expires-block: none,
        stop-price: none,
        fee-paid: u0
      })
      
      (var-set order-counter order-id)
      
      ;; Execute market order
      (try! (execute-market-order order-id base-token quote-token max-slippage))
      
      (print { 
        op: "market-order", 
        order-id: order-id, 
        pair-id: pair-id, 
        side: side, 
        amount: amount 
      })
      
      (ok order-id)
    )
  )
)

(define-public (cancel-order (order-id uint))
  (let ((order (unwrap! (map-get? orders order-id) ERR-ORDER-NOT-EXISTS)))
    (asserts! (is-eq (get trader order) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status order) ORDER-STATUS-OPEN) ERR-ORDER-NOT-EXISTS)
    
    ;; Update order status
    (map-set orders order-id (merge order { status: ORDER-STATUS-CANCELLED }))
    
    ;; Update order book
    (let (
      (remaining-amount (- (get amount order) (get filled-amount order)))
    )
      (update-order-book-level 
        (get pair-id order) 
        (get price order) 
        remaining-amount 
        (get side order) 
        false
      )
    )
    
    ;; Return locked tokens
    (let (
      (pair (unwrap! (map-get? trading-pairs (get pair-id order)) ERR-INVALID-PAIR))
      (remaining-amount (- (get amount order) (get filled-amount order)))
      (locked-amount (if (get side order) 
                       (* remaining-amount (get price order)) 
                       remaining-amount))
    )
      ;; Return tokens based on side
      (if (get side order)
        ;; Buy order - return quote tokens
        (try! (as-contract (contract-call? 
          (unwrap-panic (contract-call? quote-token get-symbol)) 
          transfer locked-amount tx-sender (get trader order) none)))
        ;; Sell order - return base tokens
        (try! (as-contract (contract-call? 
          (unwrap-panic (contract-call? base-token get-symbol))
          transfer locked-amount tx-sender (get trader order) none)))
      )
    )
    
    (print { op: "cancel-order", order-id: order-id })
    (ok true)
  )
)

;; Order Matching Engine
(define-private (match-order (order-id uint))
  (let ((order (unwrap! (map-get? orders order-id) ERR-ORDER-NOT-EXISTS)))
    (if (is-eq (get order-type order) ORDER-TYPE-MARKET)
      (ok true) ;; Market orders handled separately
      (try! (match-limit-order order-id))
    )
  )
)

(define-private (match-limit-order (order-id uint))
  (let ((order (unwrap! (map-get? orders order-id) ERR-ORDER-NOT-EXISTS)))
    ;; Simple matching logic - in production would need more sophisticated matching
    (if (get side order)
      ;; Buy order - look for matching sell orders
      (try! (find-matching-sells order-id))
      ;; Sell order - look for matching buy orders
      (try! (find-matching-buys order-id))
    )
  )
)

(define-private (find-matching-sells (buy-order-id uint))
  ;; Simplified - in production would iterate through order book
  (ok true)
)

(define-private (find-matching-buys (sell-order-id uint))
  ;; Simplified - in production would iterate through order book
  (ok true)
)

(define-private (execute-market-order 
  (order-id uint) 
  (base-token <ft-trait>)
  (quote-token <ft-trait>)
  (max-slippage uint)
)
  (let ((order (unwrap! (map-get? orders order-id) ERR-ORDER-NOT-EXISTS)))
    ;; Simplified market order execution
    ;; In production, this would match against order book
    (let (
      (pair (unwrap! (map-get? trading-pairs (get pair-id order)) ERR-INVALID-PAIR))
      (market-price (get last-price pair))
      (fee-amount (calculate-fee (get amount order) TAKER-FEE))
    )
      ;; Execute trade at market price
      (if (get side order)
        ;; Buy order
        (let (
          (quote-amount-needed (* (get amount order) market-price))
          (total-cost (+ quote-amount-needed fee-amount))
        )
          (try! (contract-call? quote-token transfer total-cost tx-sender (as-contract tx-sender) none))
          (try! (as-contract (contract-call? base-token transfer (get amount order) tx-sender (get trader order) none)))
        )
        ;; Sell order
        (let (
          (quote-amount-received (* (get amount order) market-price))
          (net-received (- quote-amount-received fee-amount))
        )
          (try! (contract-call? base-token transfer (get amount order) tx-sender (as-contract tx-sender) none))
          (try! (as-contract (contract-call? quote-token transfer net-received tx-sender (get trader order) none)))
        )
      )
      
      ;; Update order status
      (map-set orders order-id (merge order {
        status: ORDER-STATUS-FILLED,
        filled-amount: (get amount order),
        fee-paid: fee-amount
      }))
      
      ;; Update price and statistics
      (try! (update-pair-price (get pair-id order) market-price (get amount order)))
      
      (ok true)
    )
  )
)

;; Market Making Functions
(define-public (register-market-maker
  (pair-id uint)
  (bid-price uint)
  (ask-price uint)
  (bid-amount uint)
  (ask-amount uint)
)
  (begin
    (asserts! (not (is-trading-paused)) ERR-PAUSED)
    (asserts! (is-some (map-get? trading-pairs pair-id)) ERR-INVALID-PAIR)
    (asserts! (< bid-price ask-price) ERR-INVALID-PRICE)
    (asserts! (is-valid-price bid-price pair-id) ERR-INVALID-PRICE)
    (asserts! (is-valid-price ask-price pair-id) ERR-INVALID-PRICE)
    
    (let ((mm-id (+ (var-get mm-counter) u1)))
      (map-set market-makers mm-id {
        maker: tx-sender,
        pair-id: pair-id,
        bid-price: bid-price,
        ask-price: ask-price,
        bid-amount: bid-amount,
        ask-amount: ask-amount,
        spread: (- ask-price bid-price),
        active: true,
        rewards-earned: u0
      })
      
      (var-set mm-counter mm-id)
      
      (print { op: "register-mm", mm-id: mm-id, pair-id: pair-id })
      (ok mm-id)
    )
  )
)

;; Price and Statistics Updates
(define-private (update-pair-price (pair-id uint) (new-price uint) (volume uint))
  (let (
    (pair (unwrap! (map-get? trading-pairs pair-id) ERR-INVALID-PAIR))
    (stats (default-to {
      total-volume: u0,
      total-trades: u0,
      high-24h: u0,
      low-24h: u340282366920938463463374607431768211455,
      open-24h: new-price,
      last-update: block-height
    } (map-get? pair-stats pair-id)))
  )
    ;; Update pair with new price
    (map-set trading-pairs pair-id (merge pair {
      last-price: new-price,
      volume-24h: (+ (get volume-24h pair) volume)
    }))
    
    ;; Update statistics
    (map-set pair-stats pair-id (merge stats {
      total-volume: (+ (get total-volume stats) volume),
      total-trades: (+ (get total-trades stats) u1),
      high-24h: (max (get high-24h stats) new-price),
      low-24h: (min (get low-24h stats) new-price),
      last-update: block-height
    }))
    
    ;; Record price history
    (map-set price-history 
      { pair-id: pair-id, block: block-height }
      { price: new-price, volume: volume, timestamp: block-height }
    )
    
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

(define-public (toggle-trading-pause)
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-OWNER-ONLY)
    (var-set trading-paused (not (var-get trading-paused)))
    (ok (var-get trading-paused))
  )
)

(define-public (set-pair-active (pair-id uint) (active bool))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-OWNER-ONLY)
    (let ((pair (unwrap! (map-get? trading-pairs pair-id) ERR-INVALID-PAIR)))
      (map-set trading-pairs pair-id (merge pair { active: active }))
      (ok true)
    )
  )
)

;; Read-only Functions
(define-read-only (get-trading-pair (pair-id uint))
  (map-get? trading-pairs pair-id)
)

(define-read-only (get-order (order-id uint))
  (map-get? orders order-id)
)

(define-read-only (get-order-book-level (pair-id uint) (price uint) (is-bid bool))
  (if is-bid
    (map-get? order-book-bids { pair-id: pair-id, price: price })
    (map-get? order-book-asks { pair-id: pair-id, price: price })
  )
)

(define-read-only (get-market-maker (mm-id uint))
  (map-get? market-makers mm-id)
)

(define-read-only (get-trader-stats (trader principal))
  (map-get? trader-stats trader)
)

(define-read-only (get-pair-stats (pair-id uint))
  (map-get? pair-stats pair-id)
)

(define-read-only (get-price-history (pair-id uint) (block uint))
  (map-get? price-history { pair-id: pair-id, block: block })
)

(define-read-only (calculate-twap (pair-id uint) (blocks-back uint))
  ;; Time-weighted average price calculation
  (let (
    (current-block block-height)
    (start-block (if (> current-block blocks-back) (- current-block blocks-back) u0))
  )
    ;; Simplified TWAP - in production would need to iterate through price history
    (match (map-get? trading-pairs pair-id)
      pair (ok (get last-price pair))
      ERR-INVALID-PAIR
    )
  )
)

(define-read-only (get-best-bid-ask (pair-id uint))
  ;; Return best bid and ask prices
  ;; Simplified - would need to iterate through order book in production
  (match (map-get? trading-pairs pair-id)
    pair (ok { 
      best-bid: (- (get last-price pair) (get price-increment pair)),
      best-ask: (+ (get last-price pair) (get price-increment pair))
    })
    ERR-INVALID-PAIR
  )
)

(define-read-only (estimate-market-impact (pair-id uint) (side bool) (amount uint))
  ;; Estimate price impact of a market order
  ;; Simplified calculation
  (match (map-get? trading-pairs pair-id)
    pair (let (
      (current-price (get last-price pair))
      (impact-factor (/ amount u1000000)) ;; Simplified impact calculation
    )
      (ok (if side
        (+ current-price impact-factor)
        (- current-price impact-factor)
      ))
    )
    ERR-INVALID-PAIR
  )
)

(define-read-only (get-total-pairs)
  (var-get total-trading-pairs)
)

(define-read-only (get-total-orders)
  (var-get order-counter)
)

(define-read-only (is-trading-active)
  (not (var-get trading-paused))
)