(define-module (rde features version-control)
  #:use-module (rde features)
  #:use-module (rde features predicates)
  #:use-module (rde packages)
  #:use-module (gnu home-services version-control)
  #:use-module (gnu home services)
  #:use-module (gnu services)
  #:use-module (gnu packages version-control)
  #:use-module (guix gexp)

  #:export (feature-git))

(define* (feature-git
          #:key
          (git git)
          (sign-commits? #t)
          (git-gpg-sign-key #f)
          (git-send-email? #t)
          (extra-config '()))
  "Setup and configure Git."
  (ensure-pred any-package? git)
  (ensure-pred maybe-string? git-gpg-sign-key)
  (ensure-pred boolean? sign-commits?)
  (ensure-pred boolean? git-send-email?)
  (ensure-pred list? extra-config)

  (define (git-home-services config)
    "Returns home services related to Git."
    (require-value 'full-name config)
    (require-value 'email config)

    (let ((gpg-sign-key (or git-gpg-sign-key
                            (get-value 'gpg-primary-key config))))
      (when sign-commits?
        ;; TODO: Make a more detailed exception, which tells that user either
        ;; need to provide a correct key or set sign-commits? to #f
        (ensure-pred string? gpg-sign-key))
      (list
       (when git-send-email?
         (simple-service
          'git-send-email-package
          home-profile-service-type
          (list (list git "send-email"))))
       (service
        home-git-service-type
        (home-git-configuration
         (package git)
         (ignore
          '("*~"
            "*.\\#\\*"
            "*.\\#*\\#"))
         (config
          `((user
             ((name . ,(get-value 'full-name config))
              (email . ,(get-value 'email config))
              ,@(if sign-commits?
                    `((signingkey . ,gpg-sign-key))
                    '())))
            (merge
             ;; diff3 makes it easier to solve conflicts with smerge, zdiff3
             ;; should make a conflict scope smaller, but guile-git fails if
             ;; this option is set.
             ((conflictStyle . diff3)))
            (diff
             ;; histogram should be smarter about diff generation.
             ((algorithm . histogram)))
            (commit
             (,@(if sign-commits?
                    '((gpgsign . #t))
                    '())))
            (sendemail
             ((annotate . #t)))

            ,@extra-config)))))))

  (feature
   (name 'git)
   (values (make-feature-values git git-send-email?))
   (home-services-getter git-home-services)))
