(define-module (gnu home-services mail)
  #:use-module (gnu home-services)
  #:use-module (gnu home-services-utils)
  #:use-module (gnu home-services files)
  #:use-module (gnu home-services shepherd)
  #:use-module (gnu packages mail)
  #:use-module (gnu services configuration)

  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)

  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:export (home-isync-service-type
	    home-isync-configuration

            home-notmuch-service-type
	    home-notmuch-configuration))

(define (serialize-isync-config field-name val)
  (define (serialize-term term)
    (match term
      ((? symbol? e) (symbol->string e))
      ((? string? e) (format #f "~s" e))
      (e e)))
  (define (serialize-item entry)
    (match entry
      ((? gexp? e) e)
      ((? list lst)
       #~(string-join '#$(map serialize-term lst)))))

  #~(string-append #$@(interpose (map serialize-item val) "\n" 'suffix)))

(define-configuration/no-serialization home-isync-configuration
  (package
   (package isync)
   "isync package to use.")
  (xdg-flavor?
   (boolean #t)
   "Whether to use the {$XDG_CONFIG_HOME/isync/mbsyncrc} configuration
file or not.  If @code{#t} creates a wrapper for mbsync binary.")
  (config
   (list '())
   "AList of pairs, each pair is a String and String or Gexp."))

(define (add-isync-package config)
  (if (home-isync-configuration-xdg-flavor? config)
      (list
       (home-isync-configuration-package config)
       (wrap-package
        (home-isync-configuration-package config)
        "mbsync"
        #~(system
           (string-join
            (cons
             #$(file-append (home-isync-configuration-package config)
                            "/bin/mbsync")
             (if (or (member "-c" (command-line))
                     (member "--config" (command-line)))
                 (cdr (command-line))
                 (append
                  (list "--config"
                        "${XDG_CONFIG_HOME:-$HOME/.config}/isync/mbsyncrc")
                  (cdr (command-line)))))))))
      (list (home-isync-configuration-package config))))

(define (add-isync-configuration config)
  `((,(if (home-isync-configuration-xdg-flavor? config)
          "config/isync/mbsyncrc"
          "mbsyncrc")
     ,(mixed-text-file
       "mbsyncrc"
       (serialize-isync-config #f (home-isync-configuration-config config))))))

(define (home-isync-extensions cfg extensions)
  (display extensions)
  (home-isync-configuration
   (inherit cfg)
   (config (append (home-isync-configuration-config cfg) extensions))))

;; TODO: create dirs on-change?
(define home-isync-service-type
  (service-type (name 'home-isync)
                (extensions
                 (list (service-extension
			home-profile-service-type
			add-isync-package)
		       (service-extension
                        home-files-service-type
                        add-isync-configuration)))
		(compose concatenate)
		(extend home-isync-extensions)
                (default-value (home-isync-configuration))
                (description "Install and configure isync.")))

(define-configuration/no-serialization home-notmuch-configuration
  (package
   (package notmuch)
   "notmuch package to use.")
  (xdg-flavor?
   (boolean #t)
   "Whether to use the {$XDG_CONFIG_HOME/notmuch/default/config}
configuration file or not.")
  (config
   (ini-config '())
   "AList of pairs, each pair is a String and String or Gexp.")
  (hooks
   (list '())
   "List of lists, each nested list contains hook name and file-object."))


(define (add-notmuch-package config)
  (list (home-notmuch-configuration-package config)))

(define (add-notmuch-configuration config)
  (define (serialize-field key val)
    (let ((val (cond
                ((list? val) (string-join (map maybe-object->string val) ";"))
                (else val))))
      (format #f "~a=~a\n" key val)))

  (define (prepend-hook x)
    (cons (string-append "config/notmuch/default/hooks/" (car x)) (cdr x)))

  `(,@(map prepend-hook (home-notmuch-configuration-hooks config))
    (,(if (home-notmuch-configuration-xdg-flavor? config)
          "config/notmuch/default/config"
          "notmuch-config")
     ,(mixed-text-file
       "notmuch-config"
       (generic-serialize-ini-config
        #:serialize-field serialize-field
        #:fields (home-notmuch-configuration-config config))))))

(define home-notmuch-service-type
  (service-type (name 'home-notmuch)
                (extensions
                 (list (service-extension
			home-profile-service-type
			add-notmuch-package)
		       (service-extension
                        home-files-service-type
                        add-notmuch-configuration)))
		;; (compose concatenate)
		;; (extend home-isync-extensions)
                (default-value (home-notmuch-configuration))
                (description "Install and configure notmuch.")))
