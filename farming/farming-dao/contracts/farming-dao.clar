(define-data-var farmer-count uint u0)
(define-map farmers principal (tuple (registered uint)))
(define-map contributions principal (tuple (amount uint))) ;;  VALID
(define-map proposals uint
  {
    description: (string-ascii 100),
    amount: uint,
    votes-for: uint,
    votes-against: uint,
    executed: bool
  }
)

(define-data-var proposal-count uint u0)

(define-public (register-farmer)
  (begin
    (map-set farmers tx-sender (tuple (registered u1)))
    (var-set farmer-count (+ (var-get farmer-count) u1))
    (ok (var-get farmer-count))
  )
)

(define-public (contribute (amount uint))
  (begin
    (asserts! (>= amount u1000) (err u402)) ;; optional: require min amount
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    (let (
      (maybe-contrib (map-get? contributions tx-sender))
      (current (if (is-some maybe-contrib)
                   (get amount (unwrap-panic maybe-contrib))
                   u0))
    )
      (map-set contributions tx-sender (tuple (amount (+ current amount))))
    )
    (ok true)
  )
)

(define-public (propose (desc (string-ascii 100)) (amount uint))
  (begin
    (let ((maybe-farmer (map-get? farmers tx-sender)))
      (asserts! (is-some maybe-farmer) (err u403))
      (let ((farmer (unwrap-panic maybe-farmer)))
        (asserts! (is-eq (get registered farmer) u1) (err u403))
      )
    )
    (let ((id (var-get proposal-count)))
      (map-set proposals id {
        description: desc,
        amount: amount,
        votes-for: u0,
        votes-against: u0,
        executed: false
      })
      (var-set proposal-count (+ id u1))
      (ok id)
    )
  )
)

(define-public (vote (id uint) (support bool))
  (begin
    (let ((maybe-farmer (map-get? farmers tx-sender)))
      (asserts! (is-some maybe-farmer) (err u403))
      (let ((farmer (unwrap-panic maybe-farmer)))
        (asserts! (is-eq (get registered farmer) u1) (err u403))
      )
    )
    (let ((proposal (unwrap! (map-get? proposals id) (err u404))))
      (if support
          (map-set proposals id (merge proposal { votes-for: (+ (get votes-for proposal) u1) }))
          (map-set proposals id (merge proposal { votes-against: (+ (get votes-against proposal) u1) }))
      )
      (ok true)
    )
  )
)

(define-public (execute-proposal (id uint))
  (let ((proposal (unwrap! (map-get? proposals id) (err u404))))
    (begin
      (asserts! (is-eq (get executed proposal) false) (err u409))
      (asserts! (> (get votes-for proposal) (get votes-against proposal)) (err u401))
      (map-set proposals id (merge proposal { executed: true }))
      (ok true)
    )
  )
)
