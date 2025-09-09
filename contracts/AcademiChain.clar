;; AcademiChain - Academic credential verification and validation platform
;; Institutions earn tokens based on credential verification and quality ratings

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_ALREADY_VERIFIED (err u104))
(define-constant ERR_ALREADY_RATED (err u105))
(define-constant ERR_SELF_RATING (err u106))
(define-constant ERR_EMPTY_STRING (err u107))
(define-constant ERR_INVALID_RATING (err u108))
(define-constant ERR_INVALID_CREDENTIAL_ID (err u109))
(define-constant ERR_EMPTY_HASH (err u110))

;; Constants
(define-constant MAX_RATING u5)
(define-constant VALIDATION_REWARD u10)
(define-constant EXCELLENCE_REWARD u20)
(define-constant ACCREDITATION_REWARD u50)

;; Data maps
(define-map institutions
  { institution-id: principal }
  { name: (string-ascii 50), institution-type: (string-ascii 20), reputation: uint, tokens: uint, accredited: bool }
)

(define-map academic-credentials
  { credential-id: uint }
  { 
    issuer: principal, 
    description: (string-ascii 500), 
    credential-hash: (buff 32),
    timestamp: uint, 
    verified: bool,
    validation-count: uint,
    endorsement-count: uint,
    quality-rating: uint,
    rating-count: uint
  }
)

(define-map credential-validations
  { credential-id: uint, validator: principal }
  { validated: bool }
)

(define-map credential-endorsements
  { credential-id: uint, endorser: principal }
  { endorsement-level: uint, endorsement-date: uint }
)

(define-map quality-ratings
  { credential-id: uint, rater: principal }
  { rating: uint }
)

;; Variables
(define-data-var next-credential-id uint u1)
(define-data-var action-counter uint u0)

;; Helper functions
(define-private (is-valid-credential-id (credential-id uint))
  (< credential-id (var-get next-credential-id))
)

;; Institution functions
(define-public (register-institution (name (string-ascii 50)) (institution-type (string-ascii 20)))
  (let ((caller tx-sender))
    (asserts! (> (len name) u0) ERR_EMPTY_STRING)
    (asserts! (or (is-eq institution-type "university") (is-eq institution-type "validator") (is-eq institution-type "employer")) ERR_INVALID_INPUT)
    (asserts! (is-none (map-get? institutions {institution-id: caller})) ERR_ALREADY_EXISTS)
    (ok (map-set institutions 
      {institution-id: caller} 
      {name: name, institution-type: institution-type, reputation: u0, tokens: u100, accredited: false}))
  )
)

(define-public (update-institution (name (string-ascii 50)) (institution-type (string-ascii 20)))
  (let ((caller tx-sender))
    (asserts! (> (len name) u0) ERR_EMPTY_STRING)
    (asserts! (or (is-eq institution-type "university") (is-eq institution-type "validator") (is-eq institution-type "employer")) ERR_INVALID_INPUT)
    (asserts! (is-some (map-get? institutions {institution-id: caller})) ERR_NOT_FOUND)
    (ok (map-set institutions 
      {institution-id: caller} 
      (merge (unwrap! (map-get? institutions {institution-id: caller}) ERR_NOT_FOUND)
             {name: name, institution-type: institution-type})))
  )
)

;; Credential functions
(define-public (issue-credential (description (string-ascii 500)) (credential-hash (buff 32)))
  (let ((caller tx-sender)
        (credential-id (var-get next-credential-id)))
    (asserts! (> (len description) u0) ERR_EMPTY_STRING)
    (asserts! (> (len credential-hash) u0) ERR_EMPTY_HASH)
    (asserts! (is-some (map-get? institutions {institution-id: caller})) ERR_NOT_FOUND)
    (var-set action-counter (+ (var-get action-counter) u1))
    
    (map-set academic-credentials 
      {credential-id: credential-id} 
      { 
        issuer: caller, 
        description: description, 
        credential-hash: credential-hash,
        timestamp: (var-get action-counter), 
        verified: false,
        validation-count: u0,
        endorsement-count: u0,
        quality-rating: u0,
        rating-count: u0
      })
    (var-set next-credential-id (+ credential-id u1))
    (ok credential-id)
  )
)

(define-public (validate-credential (credential-id uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-credential-id credential-id) ERR_INVALID_CREDENTIAL_ID)
    (asserts! (is-some (map-get? institutions {institution-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? academic-credentials {credential-id: credential-id})) ERR_NOT_FOUND)
    
    (let ((credential (unwrap! (map-get? academic-credentials {credential-id: credential-id}) ERR_NOT_FOUND)))
      (asserts! (not (is-eq caller (get issuer credential))) ERR_SELF_RATING)
      (asserts! (is-none (map-get? credential-validations {credential-id: credential-id, validator: caller})) ERR_ALREADY_VERIFIED)
      
      (map-set credential-validations 
        {credential-id: credential-id, validator: caller} 
        {validated: true})
      
      (let ((new-validation-count (+ (get validation-count credential) u1))
            (credential-issuer (unwrap! (map-get? institutions {institution-id: (get issuer credential)}) ERR_NOT_FOUND))
            (validator-inst (unwrap! (map-get? institutions {institution-id: caller}) ERR_NOT_FOUND)))
        
        (map-set academic-credentials 
          {credential-id: credential-id} 
          (merge credential {
            validation-count: new-validation-count,
            verified: (>= new-validation-count u3)
          }))
        
        (map-set institutions 
          {institution-id: caller} 
          (merge validator-inst {
            tokens: (+ (get tokens validator-inst) u5),
            reputation: (+ (get reputation validator-inst) u1)
          }))
        
        (if (and (>= new-validation-count u3) (not (get verified credential)))
          (map-set institutions 
            {institution-id: (get issuer credential)} 
            (merge credential-issuer {
              tokens: (+ (get tokens credential-issuer) ACCREDITATION_REWARD),
              reputation: (+ (get reputation credential-issuer) u10),
              accredited: true
            }))
          true)
        
        (ok new-validation-count)
      )
    )
  )
)

(define-public (endorse-credential (credential-id uint) (endorsement-level uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-credential-id credential-id) ERR_INVALID_CREDENTIAL_ID)
    (asserts! (> endorsement-level u0) ERR_INVALID_INPUT)
    (asserts! (is-some (map-get? institutions {institution-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? academic-credentials {credential-id: credential-id})) ERR_NOT_FOUND)
    
    (let ((credential (unwrap! (map-get? academic-credentials {credential-id: credential-id}) ERR_NOT_FOUND)))
      (asserts! (get verified credential) ERR_UNAUTHORIZED)
      
      (map-set credential-endorsements 
        {credential-id: credential-id, endorser: caller} 
        {endorsement-level: endorsement-level, endorsement-date: (var-get action-counter)})
      
      (let ((new-endorsement-count (+ (get endorsement-count credential) endorsement-level))
            (credential-issuer (unwrap! (map-get? institutions {institution-id: (get issuer credential)}) ERR_NOT_FOUND)))
        
        (map-set academic-credentials 
          {credential-id: credential-id} 
          (merge credential {endorsement-count: new-endorsement-count}))
        
        (map-set institutions 
          {institution-id: (get issuer credential)} 
          (merge credential-issuer {
            tokens: (+ (get tokens credential-issuer) (* VALIDATION_REWARD endorsement-level))
          }))
        
        (ok new-endorsement-count)
      )
    )
  )
)

(define-public (rate-credential-quality (credential-id uint) (rating uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-credential-id credential-id) ERR_INVALID_CREDENTIAL_ID)
    (asserts! (and (>= rating u1) (<= rating MAX_RATING)) ERR_INVALID_RATING)
    (asserts! (is-some (map-get? institutions {institution-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? academic-credentials {credential-id: credential-id})) ERR_NOT_FOUND)
    
    (let ((credential (unwrap! (map-get? academic-credentials {credential-id: credential-id}) ERR_NOT_FOUND)))
      (asserts! (not (is-eq caller (get issuer credential))) ERR_SELF_RATING)
      (asserts! (is-none (map-get? quality-ratings {credential-id: credential-id, rater: caller})) ERR_ALREADY_RATED)
      
      (map-set quality-ratings 
        {credential-id: credential-id, rater: caller} 
        {rating: rating})
      
      (let ((current-total-rating (* (get quality-rating credential) (get rating-count credential)))
            (new-rating-count (+ (get rating-count credential) u1))
            (new-total-rating (+ current-total-rating rating))
            (new-average-rating (/ new-total-rating new-rating-count))
            (credential-issuer (unwrap! (map-get? institutions {institution-id: (get issuer credential)}) ERR_NOT_FOUND))
            (rater-inst (unwrap! (map-get? institutions {institution-id: caller}) ERR_NOT_FOUND)))
        
        (map-set academic-credentials 
          {credential-id: credential-id} 
          (merge credential {
            quality-rating: new-average-rating,
            rating-count: new-rating-count
          }))
        
        (map-set institutions 
          {institution-id: caller} 
          (merge rater-inst {
            tokens: (+ (get tokens rater-inst) u2),
            reputation: (+ (get reputation rater-inst) u1)
          }))
        
        (if (>= rating u4)
          (map-set institutions 
            {institution-id: (get issuer credential)} 
            (merge credential-issuer {
              tokens: (+ (get tokens credential-issuer) EXCELLENCE_REWARD),
              reputation: (+ (get reputation credential-issuer) u5)
            }))
          true)
        
        (ok new-average-rating)
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-institution-info (institution-id principal))
  (map-get? institutions {institution-id: institution-id})
)

(define-read-only (get-credential (credential-id uint))
  (map-get? academic-credentials {credential-id: credential-id})
)

(define-read-only (get-credential-validation (credential-id uint) (validator principal))
  (map-get? credential-validations {credential-id: credential-id, validator: validator})
)

(define-read-only (get-credential-endorsement (credential-id uint) (endorser principal))
  (map-get? credential-endorsements {credential-id: credential-id, endorser: endorser})
)

(define-read-only (get-quality-rating (credential-id uint) (rater principal))
  (map-get? quality-ratings {credential-id: credential-id, rater: rater})
)

(define-read-only (get-total-credentials)
  (- (var-get next-credential-id) u1)
)
