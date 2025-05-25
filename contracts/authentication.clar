;; Authentication Contract
;; Manages secure login processes and session management

(define-constant ERR_INVALID_CREDENTIALS (err u300))
(define-constant ERR_SESSION_EXPIRED (err u301))
(define-constant ERR_USER_NOT_FOUND (err u302))

;; Data structures
(define-map user-credentials
  { user-id: (string-ascii 64) }
  {
    credential-hash: (string-ascii 128),
    public-key: (string-ascii 128),
    trust-level: uint,
    is-active: bool,
    last-login: uint
  }
)

(define-map active-sessions
  { session-id: (string-ascii 64) }
  {
    user-id: (string-ascii 64),
    created-at: uint,
    expires-at: uint,
    is-valid: bool
  }
)

(define-map user-providers
  { user-id: (string-ascii 64), provider-id: (string-ascii 64) }
  { verified-at: uint }
)

;; Constants
(define-constant SESSION_DURATION u144) ;; ~24 hours in blocks

;; Read-only functions
(define-read-only (get-user (user-id (string-ascii 64)))
  (map-get? user-credentials { user-id: user-id })
)

(define-read-only (get-session (session-id (string-ascii 64)))
  (map-get? active-sessions { session-id: session-id })
)

(define-read-only (is-session-valid (session-id (string-ascii 64)))
  (match (map-get? active-sessions { session-id: session-id })
    session (and
      (get is-valid session)
      (> (get expires-at session) block-height)
    )
    false
  )
)

(define-read-only (get-user-trust-level (user-id (string-ascii 64)))
  (match (map-get? user-credentials { user-id: user-id })
    user (get trust-level user)
    u0
  )
)

;; Public functions
(define-public (register-user
  (user-id (string-ascii 64))
  (credential-hash (string-ascii 128))
  (public-key (string-ascii 128))
)
  (begin
    (map-set user-credentials
      { user-id: user-id }
      {
        credential-hash: credential-hash,
        public-key: public-key,
        trust-level: u1,
        is-active: true,
        last-login: u0
      }
    )
    (ok true)
  )
)

(define-public (authenticate-user
  (user-id (string-ascii 64))
  (credential-hash (string-ascii 128))
  (session-id (string-ascii 64))
)
  (let ((user-data (unwrap! (map-get? user-credentials { user-id: user-id }) ERR_USER_NOT_FOUND)))
    (asserts! (is-eq (get credential-hash user-data) credential-hash) ERR_INVALID_CREDENTIALS)
    (asserts! (get is-active user-data) ERR_INVALID_CREDENTIALS)

    ;; Update last login
    (map-set user-credentials
      { user-id: user-id }
      (merge user-data { last-login: block-height })
    )

    ;; Create session
    (map-set active-sessions
      { session-id: session-id }
      {
        user-id: user-id,
        created-at: block-height,
        expires-at: (+ block-height SESSION_DURATION),
        is-valid: true
      }
    )
    (ok session-id)
  )
)

(define-public (logout-user (session-id (string-ascii 64)))
  (begin
    (map-set active-sessions
      { session-id: session-id }
      (merge
        (unwrap! (map-get? active-sessions { session-id: session-id }) ERR_SESSION_EXPIRED)
        { is-valid: false }
      )
    )
    (ok true)
  )
)

(define-public (verify-user-with-provider
  (user-id (string-ascii 64))
  (provider-id (string-ascii 64))
)
  (begin
    (map-set user-providers
      { user-id: user-id, provider-id: provider-id }
      { verified-at: block-height }
    )

    ;; Increase trust level
    (let ((user-data (unwrap! (map-get? user-credentials { user-id: user-id }) ERR_USER_NOT_FOUND)))
      (map-set user-credentials
        { user-id: user-id }
        (merge user-data { trust-level: (+ (get trust-level user-data) u1) })
      )
    )
    (ok true)
  )
)
