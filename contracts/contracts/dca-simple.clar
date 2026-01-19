;; DCA Simple - MVP

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PLAN-NOT-FOUND (err u101))
(define-constant ERR-TOO-EARLY (err u102))
(define-constant ERR-PLAN-INACTIVE (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))

;; Data Variables
(define-data-var plan-counter uint u0)

;; Maps
(define-map plans
  { plan-id: uint }
  {
    owner: principal,
    amount-per-purchase: uint,
    interval-blocks: uint,
    next-purchase-block: uint,
    total-purchases: uint,
    active: bool,
    created-at: uint
  }
)

;; Read-only functions
(define-read-only (get-plan (plan-id uint))
  (map-get? plans { plan-id: plan-id })
)

(define-read-only (get-plan-counter)
  (ok (var-get plan-counter))
)

(define-read-only (is-ready-to-execute (plan-id uint))
  (match (get-plan plan-id)
    plan (ok (and 
      (get active plan)
      (>= stacks-block-height (get next-purchase-block plan))
    ))
    (ok false)
  )
)

;; Public functions

;; Create a new DCA plan
(define-public (create-plan
    (amount-per-purchase uint)
    (interval-blocks uint)
  )
  (let
    (
      (new-plan-id (+ (var-get plan-counter) u1))
    )
    ;; Validate
    (asserts! (> amount-per-purchase u0) ERR-INVALID-AMOUNT)
    (asserts! (> interval-blocks u0) ERR-INVALID-AMOUNT)
    
    ;; Store plan
    (map-set plans
      { plan-id: new-plan-id }
      {
        owner: tx-sender,
        amount-per-purchase: amount-per-purchase,
        interval-blocks: interval-blocks,
        next-purchase-block: (+ stacks-block-height interval-blocks),
        total-purchases: u0,
        active: true,
        created-at: stacks-block-height
      }
    )
    
    ;; Increment counter
    (var-set plan-counter new-plan-id)
    
    (ok new-plan-id)
  )
)

;; Execute a purchase (manual for MVP)
(define-public (execute-purchase (plan-id uint))
  (let
    (
      (plan (unwrap! (get-plan plan-id) ERR-PLAN-NOT-FOUND))
    )
    ;; Checks
    (asserts! (get active plan) ERR-PLAN-INACTIVE)
    (asserts! (>= stacks-block-height (get next-purchase-block plan)) ERR-TOO-EARLY)
    
    ;; Update plan
    (map-set plans
      { plan-id: plan-id }
      (merge plan {
        next-purchase-block: (+ stacks-block-height (get interval-blocks plan)),
        total-purchases: (+ (get total-purchases plan) u1)
      })
    )
    
    ;; TODO: Add actual swap logic later
    
    (ok (+ (get total-purchases plan) u1))
  )
)

;; Toggle plan active status
(define-public (toggle-plan (plan-id uint))
  (let
    (
      (plan (unwrap! (get-plan plan-id) ERR-PLAN-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get owner plan)) ERR-NOT-AUTHORIZED)
    
    (map-set plans
      { plan-id: plan-id }
      (merge plan { active: (not (get active plan)) })
    )
    
    (ok (not (get active plan)))
  )
)