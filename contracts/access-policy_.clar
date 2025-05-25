;; Access Policy Contract
;; Defines resource access rules and policies

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_POLICY_NOT_FOUND (err u201))
(define-constant ERR_INVALID_POLICY (err u202))

;; Data structures
(define-map access-policies
  { resource-id: (string-ascii 64) }
  {
    required-credentials: (list 10 (string-ascii 64)),
    minimum-trust-level: uint,
    expiry-time: uint,
    is-active: bool
  }
)

(define-map resource-owners
  { resource-id: (string-ascii 64) }
  { owner: principal }
)

;; Read-only functions
(define-read-only (get-policy (resource-id (string-ascii 64)))
  (map-get? access-policies { resource-id: resource-id })
)

(define-read-only (get-resource-owner (resource-id (string-ascii 64)))
  (map-get? resource-owners { resource-id: resource-id })
)

(define-read-only (is-policy-active (resource-id (string-ascii 64)))
  (match (map-get? access-policies { resource-id: resource-id })
    policy (and (get is-active policy) (> (get expiry-time policy) block-height))
    false
  )
)

;; Public functions
(define-public (create-policy
  (resource-id (string-ascii 64))
  (required-credentials (list 10 (string-ascii 64)))
  (minimum-trust-level uint)
  (expiry-time uint)
)
  (begin
    (asserts! (> expiry-time block-height) ERR_INVALID_POLICY)
    (map-set access-policies
      { resource-id: resource-id }
      {
        required-credentials: required-credentials,
        minimum-trust-level: minimum-trust-level,
        expiry-time: expiry-time,
        is-active: true
      }
    )
    (map-set resource-owners
      { resource-id: resource-id }
      { owner: tx-sender }
    )
    (ok true)
  )
)

(define-public (update-policy
  (resource-id (string-ascii 64))
  (required-credentials (list 10 (string-ascii 64)))
  (minimum-trust-level uint)
  (expiry-time uint)
)
  (let ((owner-data (unwrap! (map-get? resource-owners { resource-id: resource-id }) ERR_POLICY_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner owner-data)) ERR_UNAUTHORIZED)
    (asserts! (> expiry-time block-height) ERR_INVALID_POLICY)
    (map-set access-policies
      { resource-id: resource-id }
      {
        required-credentials: required-credentials,
        minimum-trust-level: minimum-trust-level,
        expiry-time: expiry-time,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (deactivate-policy (resource-id (string-ascii 64)))
  (let ((owner-data (unwrap! (map-get? resource-owners { resource-id: resource-id }) ERR_POLICY_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner owner-data)) ERR_UNAUTHORIZED)
    (map-set access-policies
      { resource-id: resource-id }
      (merge
        (unwrap-panic (map-get? access-policies { resource-id: resource-id }))
        { is-active: false }
      )
    )
    (ok true)
  )
)
