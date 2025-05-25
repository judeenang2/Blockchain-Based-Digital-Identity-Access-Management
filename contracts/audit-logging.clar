;; Audit Logging Contract
;; Records access activities and maintains audit trails

(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_LOG_NOT_FOUND (err u501))

;; Data structures
(define-map audit-logs
  { log-id: uint }
  {
    user-id: (string-ascii 64),
    resource-id: (string-ascii 64),
    action: (string-ascii 64),
    timestamp: uint,
    ip-address: (string-ascii 45),
    user-agent: (string-ascii 256),
    result: bool,
    details: (string-ascii 512)
  }
)

(define-map user-activity-summary
  { user-id: (string-ascii 64) }
  {
    total-accesses: uint,
    successful-accesses: uint,
    failed-accesses: uint,
    last-activity: uint
  }
)

(define-data-var log-counter uint u0)

;; Read-only functions
(define-read-only (get-audit-log (log-id uint))
  (map-get? audit-logs { log-id: log-id })
)

(define-read-only (get-user-activity (user-id (string-ascii 64)))
  (map-get? user-activity-summary { user-id: user-id })
)

(define-read-only (get-total-logs)
  (var-get log-counter)
)

;; Public functions
(define-public (log-access-attempt
  (user-id (string-ascii 64))
  (resource-id (string-ascii 64))
  (action (string-ascii 64))
  (ip-address (string-ascii 45))
  (user-agent (string-ascii 256))
  (result bool)
  (details (string-ascii 512))
)
  (let ((log-id (var-get log-counter)))
    ;; Create audit log entry
    (map-set audit-logs
      { log-id: log-id }
      {
        user-id: user-id,
        resource-id: resource-id,
        action: action,
        timestamp: block-height,
        ip-address: ip-address,
        user-agent: user-agent,
        result: result,
        details: details
      }
    )

    ;; Update user activity summary
    (let ((current-summary (default-to
      { total-accesses: u0, successful-accesses: u0, failed-accesses: u0, last-activity: u0 }
      (map-get? user-activity-summary { user-id: user-id })
    )))
      (map-set user-activity-summary
        { user-id: user-id }
        {
          total-accesses: (+ (get total-accesses current-summary) u1),
          successful-accesses: (if result
            (+ (get successful-accesses current-summary) u1)
            (get successful-accesses current-summary)
          ),
          failed-accesses: (if result
            (get failed-accesses current-summary)
            (+ (get failed-accesses current-summary) u1)
          ),
          last-activity: block-height
        }
      )
    )

    ;; Increment counter
    (var-set log-counter (+ log-id u1))
    (ok log-id)
  )
)

(define-public (log-authentication-event
  (user-id (string-ascii 64))
  (action (string-ascii 64))
  (result bool)
  (details (string-ascii 512))
)
  (log-access-attempt
    user-id
    "authentication"
    action
    "0.0.0.0"
    "system"
    result
    details
  )
)

(define-public (log-authorization-event
  (user-id (string-ascii 64))
  (resource-id (string-ascii 64))
  (action (string-ascii 64))
  (result bool)
  (details (string-ascii 512))
)
  (log-access-attempt
    user-id
    resource-id
    action
    "0.0.0.0"
    "system"
    result
    details
  )
)

;; Query functions for audit reports
(define-read-only (get-user-success-rate (user-id (string-ascii 64)))
  (match (map-get? user-activity-summary { user-id: user-id })
    summary (if (> (get total-accesses summary) u0)
      (/ (* (get successful-accesses summary) u100) (get total-accesses summary))
      u0
    )
    u0
  )
)
