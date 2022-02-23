
; both Gambit and Chez define pretty-print. Chicken doesn't obv
; In Chez, arithmetic-shift is bitwise-arithmetic-shift

; Chicken
;(import (chicken process-context)) (import (chicken port)) (import (chicken io)) (import (chicken bitwise)) (import (chicken string)) (import (r5rs))

; Chez
;(define print pretty-print) (define arithmetic-shift bitwise-arithmetic-shift)

; Gambit - Gambit also has a problem with the dlet definition (somehow recursing and making (cdr nil) for (cdr ls)?), even if using the unstable one that didn't break syntax-rules
;(define print pretty-print)

(define-syntax rec-lambda
  (syntax-rules ()
    ((_ name params body) (letrec ((name (lambda params body))) name))))


; Based off of http://www.phyast.pitt.edu/~micheles/scheme/scheme15.html
; many thanks!
(define-syntax dlet
  (syntax-rules ()
    ((_ () expr) expr)
    ((_ ((() bad)) expr) expr)
    ((_ (((arg1 arg2 ...) lst)) expr)
            (let ((ls lst))
              (dlet ((arg1 (car ls)))
                    (dlet (((arg2 ...) (cdr ls))) expr))))
   ((_ ((name value)) expr) (let ((name value)) expr))
   ((_ ((name value) (n v) ...) expr) (dlet ((name value)) (dlet ((n v) ...) expr)))
))

(define-syntax dlambda
  (syntax-rules ()
    ((_ params body) (lambda fullparams (dlet ((params fullparams)) body)))))

; Adapted from https://stackoverflow.com/questions/16335454/reading-from-file-using-scheme WTH
(define (slurp path)
 (list->string (call-with-input-file path
    (lambda (input-port)
         (let loop ((x (read-char input-port)))
                (cond
                        ((eof-object? x) '())
                                (#t (begin (cons x (loop (read-char input-port)))))))))))

(let* (
      (lapply apply)
      (= equal?)
      (!= (lambda (a b) (not (= a b))))
      (array list)
      (array? list?)
      (concat (lambda args (cond ((equal?  (length args) 0)   (list))
                                 ((list?   (list-ref args 0)) (apply append args))
                                 ((string? (list-ref args 0)) (apply string-append args))
                                 (#t          (error "bad value to concat")))))
      (len    (lambda (x)  (cond ((list? x)   (length x))
                                 ((string? x) (string-length x))
                                 (#t          (error "bad value to len")))))
      (idx (lambda (x i) (list-ref x (if (< i 0) (+ i (len x)) i))))
      (false #f)
      (true #t)
      (nil '())
      (str-to-symbol string->symbol)
      (get-text symbol->string)

      (bor  bitwise-ior)
      (band bitwise-and)
      (bxor bitwise-xor)
      (bnot bitwise-not)
      (<<   arithmetic-shift)
      (>>   (lambda (a b) (arithmetic-shift a (- b))))


      (nil? (lambda (x) (= nil x)))
      (bool? (lambda (x) (or (= #t x) (= #f x))))

      (read-string (lambda (s) (read (open-input-string s))))

      (zip (lambda args (apply map list args)))

      (empty_dict (array))
      (put (lambda (m k v) (cons (array k v) m)))
      ;(get-value (lambda (d k) (let ((result (alist-ref k d)))
      ;                              (if (array? result) (idx result 0)
      ;                                                  (error (print "could not find " k " in " d))))))
      ;(get-value-or-false (lambda (d k) (let ((result (alist-ref k d)))
      ;                              (if (array? result) (idx result 0)
      ;                                                  false))))

      (% modulo)
      (int? integer?)
      (str? string?)
      (env? (lambda (x) false))
      (combiner? (lambda (x) false))

      ;; For chicken and Chez
      (drop (rec-lambda recurse (x i) (if (= 0 i) x (recurse (cdr x) (- i 1)))))
      (take (rec-lambda recurse (x i) (if (= 0 i) (array) (cons (car x) (recurse (cdr x) (- i 1))))))
      (slice (lambda (x s e) (let* ( (l (len x))
                                     (s (if (< s 0) (+ s l 1) s))
                                     (e (if (< e 0) (+ e l 1) e))
                                     (t (- e s)) )
                              (take (drop x s) t))))
      (range   (rec-lambda recurse (a b)
                   (cond ((= a b) nil)
                         ((< a b) (cons a (recurse (+ a 1) b)))
                         (true    (cons a (recurse (- a 1) b)))
      )))
      (filter (rec-lambda recurse (f l) (cond ((nil? l)    nil)
                                              ((f (car l)) (cons (car l) (recurse f (cdr l))))
                                              (true        (recurse f (cdr l))))))

      (flat_map (lambda (f l) ((rec recurse (lambda (f l) (cond
                                                               ((equal? '() l) '())
                                                               (#t      (append (f (car l)) (recurse f (cdr l)))))
                                              )) f l)))
      (str (lambda args (begin
                           (define mp (open-output-string))
                           ((rec-lambda recurse (x) (if (and x (!= nil x)) (begin (display (car x) mp) (recurse (cdr x))) nil)) args)
                           (get-output-string mp))))

      (print (lambda args (print (apply str args))))

      (write_file (lambda (file bytes) (call-with-output-file file (lambda (out) (foldl (lambda (_ o) (write-byte o out)) (void) bytes)))))
      )

   (begin
       (print "take 3" (take '(1 2 3 4 5 6 7 8 9 10) 3))
       ; shadowed by wasm
       ;(print "drop 3" (drop '(1 2 3 4 5 6 7 8 9 10) 3))
       (print (slice '(1 2 3) 1 2))
       (print (slice '(1 2 3) 1 -1))
       (print (slice '(1 2 3) -1 -1))
       (print (slice '(1 2 3) -2 -1))

       (print "ASWDF")
       (print (str-to-symbol (str '(a b))))
       (print (symbol? (str-to-symbol (str '(a b)))))
       (print "first dlambda test")
       (print ( (dlambda ((a b)) a) '(1337 1338)))
       (print ( (dlambda ((a b)) b) '(1337 1338)))

       (print (str 1 2 3 (array 1 23 4) "a" "B"))

       (print "first destructure test")
       (print (dlet ( (x 2) ((a b) '(1 2)) (((i i2) i3) '((5 6) 7)) ) (+  x a b i i2 i3)))
       (print (dlet () 1))
       (print (dlet ((x 1)) x))
       (print (dlet (((x) '(1))) x))
       (print (dlet (((x y) (list 1 2))) x))
       (print (dlet (((x y) (list 1 2))) y))
       (print (dlet (((x y) (list 1 2))) (+ x y)))
       (print (dlet (((x y) (list 1 2)) ((e f g) (list 4 5 6))) (+ x y e f g)))

       (print (array 1 2 3))
       (print (command-line-arguments))

       ;(print (call-with-input-string "'(1 2)" (lambda (p) (read p))))
       (print (read (open-input-string "'(3 4)")))

       (print "if tests")
       (print (if true 1 2))
       (print (if false 1 2))
       (print (if true 1))
       (print (if false 1))
       (print "if tests end")

       (print "zip " (zip '(1 2 3) '(4 5 6) '(7 8 9)))
   )
)
