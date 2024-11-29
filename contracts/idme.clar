;; Decentralized Identity Management Contract
;; Allows users to create and manage self-sovereign identities

(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-identity-exists (err u101))
(define-constant err-identity-not-found (err u102))
(define-constant err-invalid-credential (err u103))

;; Data maps
;; Store identity information
(define-map identities 
  principal 
  {
    did: (string-ascii 100),
    created-at: uint,
    credentials: (list 10 (string-ascii 100))
  }
)

;; Map to track credential validity
(define-map credential-registry 
  (string-ascii 100) 
  bool
)

;; Create a new decentralized identity
(define-public (create-identity (did (string-ascii 100)))
  (begin
    ;; Check if identity already exists
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
  (issuer principal)
)
  (let 
    (
      (current-identity 
        (unwrap! 
          (map-get? identities tx-sender) 
          err-identity-not-found
        )
      )
      (updated-credentials 
        (unwrap! 
          (as-max-len? 
            (append (get credentials current-identity) credential) 
            u10
          ) 
          (err u104)
        )
      )
    )

    ;; Update identity with new credential
    (map-set identities 
      tx-sender 
      (merge current-identity { credentials: updated-credentials })
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

;; Remove a specific credential
(define-public (remove-credential (credential (string-ascii 100)))
  (let 
    (
      (current-identity 
        (unwrap! 
          (map-get? identities tx-sender) 
          err-identity-not-found
        )
      )
      (updated-credentials 
        (filter 
          (lambda (cred) (not (is-eq cred credential))) 
          (get credentials current-identity)
        )
      )
    )

    ;; Update identity without the removed credential
    (map-set identities 
      tx-sender 
      (merge current-identity { credentials: updated-credentials })
    )

    ;; Remove credential from registry
    (map-delete credential-registry credential)

    (ok true)
  )
)