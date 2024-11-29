;; IDME Decentralized Identity Management Contract
;; Self-sovereign identity solution on Stacks blockchain

(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-identity-exists (err u101))
(define-constant err-identity-not-found (err u102))
(define-constant err-invalid-credential (err u103))
(define-constant err-max-credentials (err u104))

;; Store identity information
(define-map identities 
  principal 
  {
    did: (string-ascii 100),
    created-at: uint,
    credentials: (list 10 (string-ascii 100))
  }
)

;; Track credential validity
(define-map credential-registry 
  (string-ascii 100) 
  bool
)

;; Create a new decentralized identity
(define-public (create-identity (did (string-ascii 100)))
  (begin
    ;; Prevent duplicate identities
    (asserts! (is-none (map-get? identities tx-sender)) err-identity-exists)
    
    ;; Create identity
    (map-set identities 
      tx-sender 
      {
        did: did,
        created-at: block-height,
        credentials: (list)
      }
    )
    
    (ok true)
  )
)

;; Add a credential to an identity
(define-public (add-credential 
  (credential (string-ascii 100))
)
  (let 
    (
      (current-identity 
        (unwrap! 
          (map-get? identities tx-sender) 
          err-identity-not-found
        )
      )
      (current-credentials (get credentials current-identity))
    )
    ;; Check if we can add more credentials
    (asserts! 
      (< (len current-credentials) u10) 
      err-max-credentials
    )
    
    ;; Update identity with new credential
    (map-set identities 
      tx-sender 
      (merge current-identity { 
        credentials: (unwrap-panic 
          (as-max-len? 
            (append current-credentials credential) 
            u10
          )
        )
      })
    )
    
    ;; Register credential
    (map-set credential-registry credential true)
    
    (ok true)
  )
)

;; Verify a credential
(define-read-only (verify-credential (credential (string-ascii 100)))
  (default-to false (map-get? credential-registry credential))
)

;; Get identity information
(define-read-only (get-identity (user principal))
  (map-get? identities user)
)

;; Transfer identity ownership (optional feature)
(define-public (transfer-identity (new-owner principal))
  (match (map-get? identities tx-sender)
    current-identity 
      (begin
        ;; Ensure new owner doesn't already have an identity
        (asserts! (is-none (map-get? identities new-owner)) err-identity-exists)
        
        ;; Remove old identity
        (map-delete identities tx-sender)
        
        ;; Create new identity for new owner
        (map-set identities 
          new-owner 
          current-identity
        )
        
        (ok true)
      )
    ;; If no identity found, return an error
    err-identity-not-found
  )
)
