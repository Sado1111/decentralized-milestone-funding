;; Decentralized-Impact-Driven Fund Management Contract
;; Decentralized milestone-based funding mechanism for transparent resource allocation

;; Core system constants
(define-constant PROTOCOL_ADMINISTRATOR tx-sender)
(define-constant ERROR_UNAUTHORIZED (err u200))
(define-constant ERROR_RESOURCE_NOT_FOUND (err u201))
(define-constant ERROR_FUNDS_PREVIOUSLY_DISTRIBUTED (err u202))
(define-constant ERROR_TRANSFER_UNSUCCESSFUL (err u203))
(define-constant ERROR_INVALID_RESOURCE_ID (err u204))
(define-constant ERROR_INVALID_CONTRIBUTION (err u205))
(define-constant ERROR_INVALID_PROJECT_STAGE (err u206))
(define-constant ERROR_PROJECT_EXPIRED (err u207))
(define-constant PROJECT_DURATION u1008) ;; ~7 days in blocks

;; Resource tracking storage
(define-map ResourceAllocations
  { resource-id: uint }
  {
    contributor: principal,
    recipient: principal,
    total-amount: uint,
    status: (string-ascii 10),
    creation-timestamp: uint,
    expiration-timestamp: uint,
    project-stages: (list 5 uint),
    approved-stages: uint
  }
)

(define-data-var latest-resource-id uint u0)

(define-private (is-valid-recipient (recipient principal))
  (not (is-eq recipient tx-sender))
)

(define-private (is-valid-resource-identifier (resource-id uint))
  (<= resource-id (var-get latest-resource-id))
)

;; Primary contract functions

;; Initialize a new resource allocation
(define-public (launch-resource-allocation (recipient principal) (amount uint) (project-stages (list 5 uint)))
  (let
    (
      (resource-id (+ (var-get latest-resource-id) u1))
      (expiration-point (+ block-height PROJECT_DURATION))
    )
    (asserts! (> amount u0) ERROR_INVALID_CONTRIBUTION)
    (asserts! (is-valid-recipient recipient) ERROR_INVALID_PROJECT_STAGE)
    (asserts! (> (len project-stages) u0) ERROR_INVALID_PROJECT_STAGE)
    (match (stx-transfer? amount tx-sender (as-contract tx-sender))
      success
        (begin
          (map-set ResourceAllocations
            { resource-id: resource-id }
            {
              contributor: tx-sender,
              recipient: recipient,
              total-amount: amount,
              status: "pending",
              creation-timestamp: block-height,
              expiration-timestamp: expiration-point,
              project-stages: project-stages,
              approved-stages: u0
            }
          )
          (var-set latest-resource-id resource-id)
          (ok resource-id)
        )
      error ERROR_TRANSFER_UNSUCCESSFUL
    )
  )
)

;; Authorize and distribute project stage funds
(define-public (validate-project-stage (resource-id uint))
  (begin
    (asserts! (is-valid-resource-identifier resource-id) ERROR_INVALID_RESOURCE_ID)
    (let
      (
        (resource-details (unwrap! (map-get? ResourceAllocations { resource-id: resource-id }) ERROR_RESOURCE_NOT_FOUND))
        (project-stages (get project-stages resource-details))
        (completed-stages (get approved-stages resource-details))
        (recipient (get recipient resource-details))
        (total-allocation (get total-amount resource-details))
        (stage-allocation (/ total-allocation (len project-stages)))
      )
      (asserts! (< completed-stages (len project-stages)) ERROR_FUNDS_PREVIOUSLY_DISTRIBUTED)
      (asserts! (is-eq tx-sender PROTOCOL_ADMINISTRATOR) ERROR_UNAUTHORIZED)
      (match (stx-transfer? stage-allocation (as-contract tx-sender) recipient)
        success
          (begin
            (map-set ResourceAllocations
              { resource-id: resource-id }
              (merge resource-details { approved-stages: (+ completed-stages u1) })
            )
            (ok true)
          )
        error ERROR_TRANSFER_UNSUCCESSFUL
      )
    )
  )
)

;; Refund contributor if project expires without stage completion
(define-public (refund-contributor (resource-id uint))
  (begin
    (asserts! (is-valid-resource-identifier resource-id) ERROR_INVALID_RESOURCE_ID)
    (let
      (
        (resource-details (unwrap! (map-get? ResourceAllocations { resource-id: resource-id }) ERROR_RESOURCE_NOT_FOUND))
        (contributor (get contributor resource-details))
        (total-amount (get total-amount resource-details))
      )
      (asserts! (is-eq tx-sender PROTOCOL_ADMINISTRATOR) ERROR_UNAUTHORIZED)
      (asserts! (> block-height (get expiration-timestamp resource-details)) ERROR_PROJECT_EXPIRED)
      (match (stx-transfer? total-amount (as-contract tx-sender) contributor)
        success
          (begin
            (map-set ResourceAllocations
              { resource-id: resource-id }
              (merge resource-details { status: "refunded" })
            )
            (ok true)
          )
        error ERROR_TRANSFER_UNSUCCESSFUL
      )
    )
  )
)

;; Cancel resource allocation - contributor can cancel before expiration
(define-public (cancel-resource-allocation (resource-id uint))
  (begin
    (asserts! (is-valid-resource-identifier resource-id) ERROR_INVALID_RESOURCE_ID)
    (let
      (
        (resource-details (unwrap! (map-get? ResourceAllocations { resource-id: resource-id }) ERROR_RESOURCE_NOT_FOUND))
        (contributor (get contributor resource-details))
        (total-amount (get total-amount resource-details))
        (completed-stages (get approved-stages resource-details))
        (remaining-amount (- total-amount (* (/ total-amount (len (get project-stages resource-details))) completed-stages)))
      )
      (asserts! (is-eq tx-sender contributor) ERROR_UNAUTHORIZED)
      (asserts! (< block-height (get expiration-timestamp resource-details)) ERROR_PROJECT_EXPIRED)
      (asserts! (is-eq (get status resource-details) "pending") ERROR_FUNDS_PREVIOUSLY_DISTRIBUTED)
      (match (stx-transfer? remaining-amount (as-contract tx-sender) contributor)
        success
          (begin
            (map-set ResourceAllocations
              { resource-id: resource-id }
              (merge resource-details { status: "cancelled" })
            )
            (ok true)
          )
        error ERROR_TRANSFER_UNSUCCESSFUL
      )
    )
  )
)

;; Circuit Interruption Mechanism
(define-constant INTERRUPTION_COOLDOWN u720) ;; ~5 days in blocks
(define-constant ERROR_INTERRUPTION_ACTIVE (err u222))
(define-constant ERROR_INTERRUPTION_TRIGGER_DELAY (err u223))

;; Resource Distribution Splitting Mechanism
(define-constant MAX_DISTRIBUTION_RECIPIENTS u5)
(define-constant ERROR_EXCESSIVE_RECIPIENTS (err u224))
(define-constant ERROR_INVALID_DISTRIBUTION_RATIO (err u225))

(define-map SplitResourceAllocations
  { split-allocation-id: uint }
  {
    contributor: principal,
    recipients: (list 5 { recipient: principal, allocation-percentage: uint }),
    total-contribution: uint,
    creation-timestamp: uint,
    status: (string-ascii 10)
  }
)

(define-data-var latest-split-allocation-id uint u0)

(define-public (create-split-resource-allocation (recipients (list 5 { recipient: principal, allocation-percentage: uint })) (total-amount uint))
  (begin
    (asserts! (> total-amount u0) ERROR_INVALID_CONTRIBUTION)
    (asserts! (> (len recipients) u0) ERROR_INVALID_RESOURCE_ID)
    (asserts! (<= (len recipients) MAX_DISTRIBUTION_RECIPIENTS) ERROR_EXCESSIVE_RECIPIENTS)

    (let
      (
        (total-percentage (fold + (map extract-allocation-percentage recipients) u0))
      )
      (asserts! (is-eq total-percentage u100) ERROR_INVALID_DISTRIBUTION_RATIO)

      (match (stx-transfer? total-amount tx-sender (as-contract tx-sender))
        success
          (let
            (
              (allocation-id (+ (var-get latest-split-allocation-id) u1))
            )
            (map-set SplitResourceAllocations
              { split-allocation-id: allocation-id }
              {
                contributor: tx-sender,
                recipients: recipients,
                total-contribution: total-amount,
                creation-timestamp: block-height,
                status: "pending"
              }
            )
            (var-set latest-split-allocation-id allocation-id)
            (ok allocation-id)
          )
        error ERROR_TRANSFER_UNSUCCESSFUL
      )
    )
  )
)

;; Helper function to extract allocation percentage
(define-private (extract-allocation-percentage (recipient { recipient: principal, allocation-percentage: uint }))
  (get allocation-percentage recipient)
)

;; Contract Administration Controls
(define-data-var contract-operational-status bool false)

(define-public (set-contract-operational-state (new-status bool))
  (begin
    (asserts! (is-eq tx-sender PROTOCOL_ADMINISTRATOR) ERROR_UNAUTHORIZED)
    (ok new-status)
  )
)

;; Recipient Verification Registry
(define-map ApprovedRecipients
  { recipient: principal }
  { validated: bool }
)

;; Validate recipient status
(define-read-only (is-recipient-validated (recipient principal))
  (default-to false (get validated (map-get? ApprovedRecipients { recipient: recipient })))
)

;; Extend resource allocation duration
(define-constant ERROR_ALREADY_EXPIRED (err u208))
(define-constant MAX_DURATION_EXTENSION u1008) 

(define-public (extend-resource-allocation-duration (resource-id uint) (extension-blocks uint))
  (begin
    (asserts! (is-valid-resource-identifier resource-id) ERROR_INVALID_RESOURCE_ID)
    (asserts! (<= extension-blocks MAX_DURATION_EXTENSION) ERROR_INVALID_CONTRIBUTION)
    (let
      (
        (resource-details (unwrap! (map-get? ResourceAllocations { resource-id: resource-id }) ERROR_RESOURCE_NOT_FOUND))
        (contributor (get contributor resource-details))
        (current-expiration (get expiration-timestamp resource-details))
      )
      (asserts! (is-eq tx-sender contributor) ERROR_UNAUTHORIZED)
      (asserts! (< block-height current-expiration) ERROR_ALREADY_EXPIRED)
      (map-set ResourceAllocations
        { resource-id: resource-id }
        (merge resource-details { expiration-timestamp: (+ current-expiration extension-blocks) })
      )
      (ok true)
    )
  )
)

;; Augment resource allocation amount
(define-public (increase-resource-allocation-amount (resource-id uint) (additional-amount uint))
  (begin
    (asserts! (is-valid-resource-identifier resource-id) ERROR_INVALID_RESOURCE_ID)
    (asserts! (> additional-amount u0) ERROR_INVALID_CONTRIBUTION)
    (let
      (
        (resource-details (unwrap! (map-get? ResourceAllocations { resource-id: resource-id }) ERROR_RESOURCE_NOT_FOUND))
        (contributor (get contributor resource-details))
        (current-amount (get total-amount resource-details))
      )
      (asserts! (is-eq tx-sender contributor) ERROR_UNAUTHORIZED)
      (asserts! (< block-height (get expiration-timestamp resource-details)) ERROR_PROJECT_EXPIRED)
      (match (stx-transfer? additional-amount tx-sender (as-contract tx-sender))
        success
          (begin
            (map-set ResourceAllocations
              { resource-id: resource-id }
              (merge resource-details { total-amount: (+ current-amount additional-amount) })
            )
            (ok true)
          )
        error ERROR_TRANSFER_UNSUCCESSFUL
      )
    )
  )
)

;; Emergency Allocation Recovery
(define-constant ERROR_EMERGENCY_RESTORATION_UNAUTHORIZED (err u209))
(define-map EmergencyRestorationRequests
  { resource-id: uint }
  { 
    administrator-approved: bool,
    contributor-approved: bool,
    restoration-reason: (string-ascii 100)
  }
)

(define-public (emergency-allocation-recovery (resource-id uint) (restoration-reason (string-ascii 100)))
  (begin
    (asserts! (is-valid-resource-identifier resource-id) ERROR_INVALID_RESOURCE_ID)
    (let
      (
        (resource-details (unwrap! (map-get? ResourceAllocations { resource-id: resource-id }) ERROR_RESOURCE_NOT_FOUND))
        (contributor (get contributor resource-details))
        (total-amount (get total-amount resource-details))
        (completed-stages (get approved-stages resource-details))
        (remaining-amount (- total-amount (* (/ total-amount (len (get project-stages resource-details))) completed-stages)))
        (emergency-request (default-to 
                            { administrator-approved: false, contributor-approved: false, restoration-reason: restoration-reason }
                            (map-get? EmergencyRestorationRequests { resource-id: resource-id })))
      )
      (asserts! (or (is-eq tx-sender PROTOCOL_ADMINISTRATOR) (is-eq tx-sender contributor)) ERROR_UNAUTHORIZED)
      (asserts! (not (is-eq (get status resource-details) "refunded")) ERROR_FUNDS_PREVIOUSLY_DISTRIBUTED)
      (asserts! (not (is-eq (get status resource-details) "recovered")) ERROR_FUNDS_PREVIOUSLY_DISTRIBUTED)

      (if (is-eq tx-sender PROTOCOL_ADMINISTRATOR)
        (map-set EmergencyRestorationRequests
          { resource-id: resource-id }
          (merge emergency-request { administrator-approved: true, restoration-reason: restoration-reason })
        )
        (map-set EmergencyRestorationRequests
          { resource-id: resource-id }
          (merge emergency-request { contributor-approved: true, restoration-reason: restoration-reason })
        )
      )

      (let
        (
          (updated-request (unwrap! (map-get? EmergencyRestorationRequests { resource-id: resource-id }) ERROR_RESOURCE_NOT_FOUND))
        )
        (if (and (get administrator-approved updated-request) (get contributor-approved updated-request))
          (match (stx-transfer? remaining-amount (as-contract tx-sender) contributor)
            success
              (begin
                (map-set ResourceAllocations
                  { resource-id: resource-id }
                  (merge resource-details { status: "recovered" })
                )
                (ok true)
              )
            error ERROR_TRANSFER_UNSUCCESSFUL
          )
          (ok false)
        )
      )
    )
  )
)

;; Project Stage Progress Reporting
(define-constant ERROR_PROGRESS_ALREADY_RECORDED (err u210))
(define-map StageProgressTracker
  { resource-id: uint, stage-index: uint }
  {
    progress-percentage: uint,
    stage-details: (string-ascii 200),
    recorded-timestamp: uint,
    evidence-hash: (buff 32)
  }
)

(define-public (report-stage-progress 
                (resource-id uint) 
                (stage-index uint) 
                (progress-percentage uint) 
                (stage-details (string-ascii 200))
                (evidence-hash (buff 32)))
  (begin
    (asserts! (is-valid-resource-identifier resource-id) ERROR_INVALID_RESOURCE_ID)
    (asserts! (<= progress-percentage u100) ERROR_INVALID_CONTRIBUTION)
    (let
      (
        (resource-details (unwrap! (map-get? ResourceAllocations { resource-id: resource-id }) ERROR_RESOURCE_NOT_FOUND))
        (project-stages (get project-stages resource-details))
        (recipient (get recipient resource-details))
      )
      (asserts! (is-eq tx-sender recipient) ERROR_UNAUTHORIZED)
      (asserts! (< stage-index (len project-stages)) ERROR_INVALID_PROJECT_STAGE)
      (asserts! (not (is-eq (get status resource-details) "refunded")) ERROR_FUNDS_PREVIOUSLY_DISTRIBUTED)
      (asserts! (< block-height (get expiration-timestamp resource-details)) ERROR_PROJECT_EXPIRED)

      (match (map-get? StageProgressTracker { resource-id: resource-id, stage-index: stage-index })
        previous-progress (asserts! (< (get progress-percentage previous-progress) u100) ERROR_PROGRESS_ALREADY_RECORDED)
        true
      )
      (ok true)
    )
  )
)

;; Resource Allocation Control Delegation
(define-constant ERROR_DELEGATION_ALREADY_EXISTS (err u211))
(define-map AllocationControlDelegates
  { resource-id: uint }
  {
    delegate: principal,
    can-cancel: bool,
    can-extend: bool,
    can-increase: bool,
    delegation-expiry: uint
  }
)

(define-public (delegate-allocation-control 
                (resource-id uint) 
                (delegate principal) 
                (can-cancel bool)
                (can-extend bool)
                (can-increase bool)
                (delegation-duration uint))
  (begin
    (asserts! (is-valid-resource-identifier resource-id) ERROR_INVALID_RESOURCE_ID)
    (asserts! (> delegation-duration u0) ERROR_INVALID_CONTRIBUTION)
    (let
      (
        (resource-details (unwrap! (map-get? ResourceAllocations { resource-id: resource-id }) ERROR_RESOURCE_NOT_FOUND))
        (contributor (get contributor resource-details))
        (delegation-expiry (+ block-height delegation-duration))
      )
      (asserts! (is-eq tx-sender contributor) ERROR_UNAUTHORIZED)
      (asserts! (< block-height (get expiration-timestamp resource-details)) ERROR_PROJECT_EXPIRED)
      (asserts! (not (is-eq (get status resource-details) "refunded")) ERROR_FUNDS_PREVIOUSLY_DISTRIBUTED)

      (match (map-get? AllocationControlDelegates { resource-id: resource-id })
        existing-delegation (asserts! (< block-height (get delegation-expiry existing-delegation)) ERROR_DELEGATION_ALREADY_EXISTS)
        true
      )
      (ok true)
    )
  )
)

;; Batch Stage Validation Mechanism
(define-constant ERROR_BATCH_OPERATION_FAILED (err u212))

(define-public (batch-validate-project-stages (resource-ids (list 10 uint)))
  (begin
    (asserts! (is-eq tx-sender PROTOCOL_ADMINISTRATOR) ERROR_UNAUTHORIZED)
    (let
      (
        (result (fold validate-stage-fold resource-ids (ok true)))
      )
      result
    )
  )
)

;; Stage validation helper function
(define-private (validate-stage-fold (resource-id uint) (previous-result (response bool uint)))
  (begin
    (match previous-result
      success
        (match (validate-project-stage resource-id)
          inner-success (ok true)
          inner-error (err inner-error)
        )
      error (err error)
    )
  )
)

;; Secure Resource Allocation Initiation with Recipient Validation
(define-public (secure-launch-resource-allocation (recipient principal) (amount uint) (project-stages (list 5 uint)))
  (begin
    (asserts! (not (var-get contract-operational-status)) ERROR_UNAUTHORIZED)
    (asserts! (is-recipient-validated recipient) ERROR_UNAUTHORIZED)
    (asserts! (> amount u0) ERROR_INVALID_CONTRIBUTION)
    (asserts! (is-valid-recipient recipient) ERROR_INVALID_PROJECT_STAGE)
    (asserts! (> (len project-stages) u0) ERROR_INVALID_PROJECT_STAGE)

    (let
      (
        (resource-id (+ (var-get latest-resource-id) u1))
        (expiration-point (+ block-height PROJECT_DURATION))
      )
      (match (stx-transfer? amount tx-sender (as-contract tx-sender))
        success
          (begin
            (map-set ResourceAllocations
              { resource-id: resource-id }
              {
                contributor: tx-sender,
                recipient: recipient,
                total-amount: amount,
                status: "pending",
                creation-timestamp: block-height,
                expiration-timestamp: expiration-point,
                project-stages: project-stages,
                approved-stages: u0
              }
            )
            (var-set latest-resource-id resource-id)
            (ok resource-id)
          )
        error ERROR_TRANSFER_UNSUCCESSFUL
      )
    )
  )
)

;; Rate Limitation System for Allocation Prevention
(define-constant ERROR_RATE_LIMIT_EXCEEDED (err u213))
(define-constant RATE_LIMIT_WINDOW u144) ;; ~24 hours in blocks
(define-constant MAX_ALLOCATIONS_PER_WINDOW u5)

(define-map ContributorActivityTracker
  { contributor: principal }
  {
    last-allocation-block: uint,
    allocations-in-window: uint
  }
)

(define-public (rate-limited-resource-allocation (recipient principal) (amount uint) (project-stages (list 5 uint)))
  (let
    (
      (contributor-activity (default-to 
                        { last-allocation-block: u0, allocations-in-window: u0 }
                        (map-get? ContributorActivityTracker { contributor: tx-sender })))
      (last-block (get last-allocation-block contributor-activity))
      (window-count (get allocations-in-window contributor-activity))
      (is-new-window (> (- block-height last-block) RATE_LIMIT_WINDOW))
      (updated-count (if is-new-window u1 (+ window-count u1)))
    )
    (asserts! (or is-new-window (< window-count MAX_ALLOCATIONS_PER_WINDOW)) ERROR_RATE_LIMIT_EXCEEDED)

    (map-set ContributorActivityTracker
      { contributor: tx-sender }
      {
        last-allocation-block: block-height,
        allocations-in-window: updated-count
      }
    )

    (secure-launch-resource-allocation recipient amount project-stages)
  )
)
