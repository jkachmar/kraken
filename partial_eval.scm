
; both Gambit and Chez define pretty-print. Chicken doesn't obv
; In Chez, arithmetic-shift is bitwise-arithmetic-shift

; Chicken
;(import (chicken process-context)) (import (chicken port)) (import (chicken io)) (import (chicken bitwise)) (import (chicken string)) (import (r5rs)) (define write_file (lambda (file bytes) (call-with-output-file file (lambda (out) (foldl (lambda (_ o) (write-byte o out)) (void) bytes))))) (define args (command-line-arguments))

; Chez
(define print pretty-print) (define arithmetic-shift bitwise-arithmetic-shift) (define foldl fold-left) (define foldr fold-right) (define write_file (lambda (file bytes) (let* ( (port (open-file-output-port file)) (_ (foldl (lambda (_ o) (put-u8 port o)) (void) bytes)) (_ (close-port port))) '()))) (define args (cdr (command-line)))
;(compile-profile 'source)

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

(define-syntax mif
  (syntax-rules ()
    ((_ con then     ) (if (let ((x con)) (and (not (equal? (list) x)) x)) then '()))
    ((_ con then else) (if (let ((x con)) (and (not (equal? (list) x)) x)) then else))))



(define str (lambda args (begin
                     (define mp (open-output-string))
                     ((rec-lambda recurse (x) (if (and x (not (equal? '() x))) (begin (display (car x) mp) (recurse (cdr x))) '())) args)
                     (get-output-string mp))))

(define true_error error)
(define error (lambda args (begin (print "ERROR! About to Error! args are\n") (print (str args)) (apply true_error args))))

; Adapted from https://stackoverflow.com/questions/16335454/reading-from-file-using-scheme WTH
(define (slurp path)
 (list->string (call-with-input-file path
    (lambda (input-port)
         (let loop ((x (read-char input-port)))
                (cond
                        ((eof-object? x) '())
                                (#t (begin (cons x (loop (read-char input-port)))))))))))

(define speed_hack #t)
;(define GLOBAL_MAX 0)

(let* (
      (lapply apply)
      (= equal?)
      (!= (lambda (a b) (not (= a b))))
      (array list)
      (array? list?)
      (concat (lambda args (cond ((equal?  (length args) 0)   (list))
                                 ((list?   (list-ref args 0)) (apply append args))
                                 ((string? (list-ref args 0)) (apply string-append args))
                                 (#t          (error "bad value to concat " (list-ref args 0))))))
      (len    (lambda (x)  (cond ((list? x)   (length x))
                                 ((string? x) (string-length x))
                                 (#t          (error "bad value to len" x)))))
      (idx (lambda (x i) (cond ((list? x)                  (list-ref x                (if (< i 0) (+ i (len x)) i)))
                               ((string? x) (char->integer (list-ref (string->list x) (if (< i 0) (+ i (len x)) i)))))))
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

      (print (lambda args (print (apply str args))))
      (true_str str)
      ;(str (if speed_hack (lambda args "") str))
      (true_print print)
      (print (if speed_hack (lambda x 0) print))
      ;(true_print print)
      (println print)


      (nil? (lambda (x) (= nil x)))
      (bool? (lambda (x) (or (= #t x) (= #f x))))

      (read-string (lambda (s) (read (open-input-string s))))

      (zip (lambda args (apply map list args)))

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
                              (if (list? x) (take (drop x s) t)
                                            (list->string (take (drop (string->list x) s) t))))))
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

      (reverse_e (lambda (x) (foldl (lambda (acc i) (cons i acc)) (array) x)))
      ;;;;;;;;;;;;;;;;;;
      ; End kludges
      ;;;;;;;;;;;;;;;;;;

      (empty_dict-list (array))
      ;(put-list (lambda (m k v) (cons (array k v) m)))
      (put-list (lambda (m k v) ((rec-lambda recurse (m k v len_m i) (cond ((= len_m i)             (cons (array k v) m))
                                                                           ((= k (idx (idx m i) 0)) (concat (slice m 0 i) (array (array k v)) (slice m (+ i 1) len_m)))
                                                                           (true                    (recurse m k v len_m (+ 1 i)))))
                                m k v (len m) 0)))
      (get-list (lambda (d k) ((rec-lambda recurse (k d len_d i) (cond ((= len_d i)             false)
                                                                       ((= k (idx (idx d i) 0)) (idx d i))
                                                                       (true                    (recurse k d len_d (+ 1 i)))))
                                k d (len d) 0)))
      (put-all-list (lambda (m nv) (map (dlambda ((k v)) (array k nv)) m)))

      ;(combine_hash     (lambda (a b) (+ (* 37 a) b)))
      (combine_hash     (lambda (a b) (band #xFFFFFFFFFFFFFF (+ (* 37 a) b))))
      (hash_bool        (lambda (b) (if b 2 3)))
      (hash_num         (lambda (n) (combine_hash 5 n)))
      (hash_string      (lambda (s) (foldl combine_hash 7  (map char->integer (string->list s)))))
      ;(hash_string      (lambda (s) (foldl combine_hash 7  s)))
      ;(hash_string      (lambda (s) (foldl combine_hash 102233  (map char->integer (string->list s)))))


    (in_array (dlet ((helper (rec-lambda recurse (x a len_a i) (cond ((= i len_a)     false)
                                                                     ((= x (idx a i)) true)
                                                                     (true            (recurse x a len_a (+ i 1)))))))
                   (lambda (x a) (helper x a (len a) 0))))
    (any_in_array (dlet ((helper (rec-lambda recurse (f a len_a i) (cond ((= i len_a) false)
                                                                     ((f (idx a i))   i)
                                                                     (true            (recurse f a len_a (+ i 1)))))))
                   (lambda (f a) (helper f a (len a) 0))))
    (array_item_union (lambda (a bi) (if (in_array bi a) a (cons bi a))))
    (array_union (lambda (a b) (foldl array_item_union a b)))


    (intset_word_size 64)
    (in_intset (rec-lambda in_intset (x a) (cond ((nil? a) false)
                                                 ((>= x intset_word_size) (in_intset (- x intset_word_size) (cdr a)))
                                                 (true                    (!= (band (>> (car a) x) 1) 0)))))

    (intset_item_union (rec-lambda intset_item_union   (a bi) (cond ((nil? a)                 (intset_item_union (array 0) bi))
                                                                    ((>= bi intset_word_size) (cons (car a) (intset_item_union (cdr a) (- bi intset_word_size))))
                                                                    (true                     (cons (bor (car a) (<< 1 bi)) (cdr a))))))

    (intset_item_remove (rec-lambda intset_item_remove (a bi) (cond ((nil? a)                 nil)
                                                                    ((>= bi intset_word_size) (dlet ((new_tail (intset_item_remove (cdr a) (- bi intset_word_size))))
                                                                                                    (if (and (nil? new_tail) (= 0 (car a))) nil
                                                                                                                                            (cons (car a) new_tail))))
                                                                    (true                     (dlet ((new_int (band (car a) (bnot (<< 1 bi)))))
                                                                                                    (if (and (nil? (cdr a)) (= 0 new_int)) nil
                                                                                                                                           (cons new_int (cdr a))))))))
    (intset_union (rec-lambda intset_union (a b) (cond ((and (nil? a) (nil? b)) nil)
                                                       ((nil? a)                b)
                                                       ((nil? b)                a)
                                                       (true                    (cons (bor (car a) (car b)) (intset_union (cdr a) (cdr b)))))))

    (intset_intersection_nonempty (rec-lambda intset_intersection_nonempty (a b) (cond ((nil? a)  false)
                                                                                       ((nil? b)  false)
                                                                                       (true      (or (!= 0 (band (car a) (car b))) (intset_intersection_nonempty (cdr a) (cdr b)))))))

    ;(_ (true_print "of 1 " (intset_item_union nil 1)))
    ;(_ (true_print "of 1 and 2 " (intset_item_union (intset_item_union nil 1) 2)))
    ;(_ (true_print "of 1 and 2 union 3 4" (intset_union (intset_item_union (intset_item_union nil 1) 2) (intset_item_union (intset_item_union nil 3) 4))))

    ;(_ (true_print "of 100 " (intset_item_union nil 100)))
    ;(_ (true_print "of 100 and 200 " (intset_item_union (intset_item_union nil 100) 200)))
    ;(_ (true_print "of 100 and 200 union 300 400" (intset_union (intset_item_union (intset_item_union nil 100) 200) (intset_item_union (intset_item_union nil 300) 400))))

    ;(_ (true_print "1 in 1 " (in_intset 1 (intset_item_union nil 1))))
    ;(_ (true_print "1 in 1 and 2 " (in_intset 1 (intset_item_union (intset_item_union nil 1) 2))))
    ;(_ (true_print "1 in 1 and 2 union 3 4" (in_intset 1 (intset_union (intset_item_union (intset_item_union nil 1) 2) (intset_item_union (intset_item_union nil 3) 4)))))

    ;(_ (true_print "1 in 1 "                (in_intset 1 (intset_item_union nil 1))))
    ;(_ (true_print "1 in 1 and 2 "          (in_intset 1 (intset_item_union (intset_item_union nil 1) 2))))
    ;(_ (true_print "1 in 1 and 2 union 3 4" (in_intset 1 (intset_union (intset_item_union (intset_item_union nil 1) 2) (intset_item_union (intset_item_union nil 3) 4)))))

    ;(_ (true_print "5 in 1 "                (in_intset 5 (intset_item_union nil 1))))
    ;(_ (true_print "5 in 1 and 2 "          (in_intset 5 (intset_item_union (intset_item_union nil 1) 2))))
    ;(_ (true_print "5 in 1 and 2 union 3 4" (in_intset 5 (intset_union (intset_item_union (intset_item_union nil 1) 2) (intset_item_union (intset_item_union nil 3) 4)))))

    ;(_ (true_print "1 in 100 "                      (in_intset 1 (intset_item_union nil 100))))
    ;(_ (true_print "1 in 100 and 200 "              (in_intset 1 (intset_item_union (intset_item_union nil 100) 200))))
    ;(_ (true_print "1 in 100 and 200 union 300 400" (in_intset 1 (intset_union (intset_item_union (intset_item_union nil 100) 200) (intset_item_union (intset_item_union nil 300) 400)))))
    ;(_ (true_print "5 in 100 "                      (in_intset 5 (intset_item_union nil 100))))
    ;(_ (true_print "5 in 100 and 200 "              (in_intset 5 (intset_item_union (intset_item_union nil 100) 200))))
    ;(_ (true_print "5 in 100 and 200 union 300 400" (in_intset 5 (intset_union (intset_item_union (intset_item_union nil 100) 200) (intset_item_union (intset_item_union nil 300) 400)))))
    ;(_ (true_print "100 in 100 "                      (in_intset 100 (intset_item_union nil 100))))
    ;(_ (true_print "100 in 100 and 200 "              (in_intset 100 (intset_item_union (intset_item_union nil 100) 200))))
    ;(_ (true_print "100 in 100 and 200 union 300 400" (in_intset 100 (intset_union (intset_item_union (intset_item_union nil 100) 200) (intset_item_union (intset_item_union nil 300) 400)))))
    ;(_ (true_print "500 in 100 "                      (in_intset 500 (intset_item_union nil 100))))
    ;(_ (true_print "500 in 100 and 200 "              (in_intset 500 (intset_item_union (intset_item_union nil 100) 200))))
    ;(_ (true_print "500 in 100 and 200 union 300 400" (in_intset 500 (intset_union (intset_item_union (intset_item_union nil 100) 200) (intset_item_union (intset_item_union nil 300) 400)))))

    ;(_ (true_print "all removed in 100 and 200 union 300 400" (intset_item_remove (intset_item_remove (intset_item_remove (intset_item_remove (intset_union (intset_item_union (intset_item_union nil 100) 200) (intset_item_union (intset_item_union nil 300) 400)) 100) 200) 300) 400)))

    (intset_union_without (lambda (wo a b) (intset_item_remove (intset_union a b) wo)))

    (val?                               (lambda (x) (= 'val (idx x 0))))
    (marked_array?                      (lambda (x) (= 'marked_array (idx x 0))))
    (marked_symbol?                     (lambda (x) (= 'marked_symbol (idx x 0))))
    (comb?                              (lambda (x) (= 'comb (idx x 0))))
    (prim_comb?                         (lambda (x) (= 'prim_comb (idx x 0))))
    (marked_env?                        (lambda (x) (= 'env (idx x 0))))

    (.hash                              (lambda (x) (idx x 1)))

    (.val                               (lambda (x) (idx x 2)))

    (.marked_array_is_val               (lambda (x) (idx x 2)))
    (.marked_array_is_attempted         (lambda (x) (idx x 3)))
    (.marked_array_needed_for_progress  (lambda (x) (idx x 4)))
    (.marked_array_values               (lambda (x) (idx x 5)))
    (.marked_array_source               (lambda (x) (if (= true (idx x 6)) x (idx x 6))))
    (.marked_array_this_rec_stop        (lambda (x) (idx x 7)))

    (.marked_symbol_needed_for_progress (lambda (x) (idx x 2)))
    (.marked_symbol_is_val              (lambda (x) (= nil (.marked_symbol_needed_for_progress x))))
    (.marked_symbol_value               (lambda (x) (idx x 3)))

    (.comb                              (lambda (x) (slice x 2 -1)))
    (.comb_id                           (lambda (x) (idx x 3)))
    (.comb_des                          (lambda (x) (idx x 4)))
    (.comb_env                          (lambda (x) (idx x 5)))
    (.comb_varadic                      (lambda (x) (idx x 6)))
    (.comb_params                       (lambda (x) (idx x 7)))
    (.comb_body                         (lambda (x) (idx x 8)))
    (.comb_wrap_level                   (lambda (x) (idx x 2)))

    (.prim_comb_sym                     (lambda (x) (idx x 3)))
    (.prim_comb_handler                 (lambda (x) (idx x 2)))
    (.prim_comb_wrap_level              (lambda (x) (idx x 4)))
    (.prim_comb_val_head_ok             (lambda (x) (idx x 5)))
    (.prim_comb                         (lambda (x) (slice x 2 -1)))

    (.marked_env                        (lambda (x) (slice x 2 -1)))
    (.marked_env_has_vals               (lambda (x) (idx x 2)))
    (.marked_env_needed_for_progress    (lambda (x) (idx x 3)))
    (.marked_env_id                    (lambda (x) (idx x 4)))
    (.marked_env_upper                  (lambda (x) (idx (idx x 5) -1)))
    (.env_marked                        (lambda (x) (idx x 5)))
    (marked_env_real?                   (lambda (x) (= nil (idx (.marked_env_needed_for_progress x) 0))))
    (.any_comb_wrap_level               (lambda (x) (cond  ((prim_comb? x)   (.prim_comb_wrap_level x))
                                                           ((comb? x)        (.comb_wrap_level x))
                                                           (true             (error "bad .any_comb_level")))))
      (empty_dict-tree nil)
      ;(trans-key (lambda (k) (cond ((string? k) (cons (hash_string k) k))
      ;                             ((symbol? k) (cons (hash_string (symbol->string k)) k))
      ;                             (true        (cons k k)))))
      ;(put-helper (rec-lambda put-helper (m k v) (cond ((nil? m)        (cons (list k v) (cons nil                       nil)))
      ;                                                 ((and (= (car k) (caaar m))
      ;                                                       (= (cdr k) (cdaar m)))      (cons (list k v) (cons (cadr m)                  (cddr m))))
      ;                                                 ((< (car k) (caaar m))            (cons (car m)    (cons (put-helper (cadr m) k v) (cddr m))))
      ;                                                 (true                             (cons (car m)    (cons (cadr m)                  (put-helper (cddr m) k v)))))))
      ;(put-tree (lambda (m k v) (put-helper m (trans-key k) v)))
      ;(get-helper (rec-lambda get-helper (m k) (cond ((nil? m)                     false)
      ;                                               ((and (= (car k) (caaar m))
      ;                                                     (= (cdr k) (cdaar m)))  (car m))
      ;                                               ((< (car k) (caaar m))        (get-helper (cadr m) k))
      ;                                               (true                         (get-helper (cddr m) k)))))
      (trans-key (lambda (k) (cond ((string? k) (hash_string k))
                                   ((symbol? k) (hash_string (get-text k)))
                                   ((array?  k) (.hash k))
                                   (true        k))))
      (put-helper (rec-lambda put-helper (m hk k v) (cond ((nil? m)                (array hk        k         v          nil                           nil))
                                                           ((and (= hk (idx m 0))
                                                                 (= k  (idx m 1))) (array hk        k         v         (idx m 3)                     (idx m 4)))
                                                           ((< hk (idx m 0))       (array (idx m 0) (idx m 1) (idx m 2) (put-helper (idx m 3) hk k v) (idx m 4)))
                                                           (true                   (array (idx m 0) (idx m 1) (idx m 2) (idx m 3)                     (put-helper (idx m 4) hk k v))))))
      (put-tree (lambda (m k v) (put-helper m (trans-key k) k v)))
      (get-helper (rec-lambda get-helper (m hk k) (cond ((nil? m)                     false)
                                                        ((and (= hk (idx m 0))
                                                              (= k  (idx m 1)))       (array k (idx m 2)))
                                                        ((< hk (idx m 0))             (get-helper (idx m 3) hk k))
                                                        (true                         (get-helper (idx m 4) hk k)))))
      (get-tree (lambda (m k) (get-helper m (trans-key k) k)))
      (foldl-tree (rec-lambda foldl-tree (f a m) (cond ((nil? m)                     a)
                                                       (true                         (dlet (
                                                                                            (a (foldl-tree f a (idx m 3)))
                                                                                            (a (f a (idx m 1) (idx m 2)))
                                                                                            (a (foldl-tree f a (idx m 4)))
                                                                                           ) a)))))

      ;(empty_dict empty_dict-list)
      ;(put put-list)
      ;(get get-list)
      (empty_dict empty_dict-tree)
      (put put-tree)
      (get get-tree)

      ;(empty_dict (list empty_dict-list empty_dict-tree))
      ;(put (lambda (m k v) (list (put-list (idx m 0) k v) (put-tree (idx m 1) k v))))
      ;(get (lambda (m k) (dlet (  ;(_ (true_print "doing a get " m " " k))
      ;                            (list-result (get-list (idx m 0) k))
      ;                            (tree-result (get-tree (idx m 1) k))
      ;                            (_ (if (and (!= list-result tree-result) (!= (idx list-result 1) (idx tree-result 1))) (error "BAD GET " list-result " vs " tree-result)))
      ;                            ) tree-result)))

      (get-value (lambda (d k) (dlet ((result (get d k)))
                                    (if (array? result) (idx result 1)
                                                       (error (str "could not find " k " in " d))))))
      (get-value-or-false (lambda (d k) (dlet ((result (get d k)))
                                    (if (array? result) (idx result 1)
                                                       false))))


    ; The actual needed_for_progress values are either
    ; #t            - any eval will do something
    ; nil           - is a value, no eval will do anything
    ; (3 4 1...)    - list of env ids that would allow forward progress
    ; But these are paired with another list of hashes that if you're not inside
    ; of an evaluation of, then it could progress futher. These are all caused by
    ; the infinite recursion stopper.
    (needed_for_progress (rec-lambda needed_for_progress (x) (cond ((marked_array? x)       (.marked_array_needed_for_progress  x))
                                                                   ((marked_symbol? x)      (dlet ((n (.marked_symbol_needed_for_progress x))) (array (if (int? n) (intset_item_union nil n) n) nil nil)))
                                                                   ((marked_env? x)         (.marked_env_needed_for_progress    x))
                                                                   ((comb? x)               (dlet ((id (.comb_id x))
                                                                                                   ((body_needed _hashes extra1) (needed_for_progress (.comb_body x)))
                                                                                                   ((se_needed   _hashes extra2) (needed_for_progress (.comb_env  x))))
                                                                                                (if (or (= true body_needed) (= true se_needed)) (array true nil nil)
                                                                                                        (array (intset_union_without id body_needed se_needed)
                                                                                                               nil (intset_union_without id extra1 extra2))
                                                                                                )))
                                                                   ((prim_comb? x)          (array nil nil nil))
                                                                   ((val? x)                (array nil nil nil))
                                                                   (true                    (error (str "what is this? in need for progress" x))))))
    (needed_for_progress_slim (lambda (x) (idx (needed_for_progress x) 0)))
    (hash_symbol      (lambda (progress_idx s) (combine_hash (cond ((= true progress_idx) 11)
                                                                   ((int? progress_idx)   (combine_hash 13 progress_idx))
                                                                   (true                  113)) (hash_string (get-text s)))))

    (hash_array       (lambda (is_val attempted a) (foldl combine_hash (if is_val 17 (cond ((int? attempted) (combine_hash attempted 19))
                                                                                            (attempted       61)
                                                                                            (true            107))) (map .hash a))))
    (hash_env         (lambda (has_vals progress_idxs dbi arrs) (combine_hash (if has_vals 107 109)
                                                                (combine_hash (mif dbi (hash_num dbi) 59) (dlet (
                                                                ;(_ (begin (true_print "pre slice " (slice arrs 0 -2)) 0))
                                                                ;(_ (begin (true_print "about to do a fold " progress_idxs " and " (slice arrs 0 -2)) 0))
                                                                (inner_hash (foldl (dlambda (c (s v)) (combine_hash c (combine_hash (hash_symbol true s) (.hash v))))
                                                                                   (cond ((= nil progress_idxs)     23)
                                                                                         ((= true progress_idxs)    29)
                                                                                         (true                      (foldl combine_hash 31 progress_idxs)))
                                                                                   (slice arrs 0 -2)))
                                                                (end (idx arrs -1))
                                                                (end_hash (mif end (.hash end) 41))
                                                                                                         ) (combine_hash inner_hash end_hash))))))
    (hash_comb        (lambda (wrap_level env_id de? se variadic params body)
                                                                             (combine_hash 43
                                                                             (combine_hash wrap_level
                                                                             (combine_hash env_id
                                                                             (combine_hash (mif de? (hash_symbol true de?) 47)
                                                                             (combine_hash (.hash se)
                                                                             (combine_hash (hash_bool variadic)
                                                                             (combine_hash (foldl (lambda (c x) (combine_hash c (hash_symbol true x))) 53 params)
                                                                             (.hash body))))))))))
    (hash_prim_comb   (lambda (handler_fun real_or_name wrap_level val_head_ok) (combine_hash (combine_hash 59 (hash_symbol true real_or_name))
                                                                                              (combine_hash (if val_head_ok 89 97) wrap_level))))
    (hash_val         (lambda (x) (cond ((bool? x)     (hash_bool x))
                                        ((string? x)   (hash_string x))
                                        ((int? x)      (hash_num x))
                                        (true          (error (str "bad thing to hash_val " x))))))
    ; 127 131 137 139 149 151 157 163 167 173

    (marked_symbol    (lambda (progress_idx x)                        (array 'marked_symbol    (hash_symbol progress_idx x)                      progress_idx x)))
    (marked_array     (lambda (is_val attempted resume_hashes x source)       (dlet (
                                                                            ((sub_progress_idxs hashes extra) (foldl (dlambda ((a ahs aeei) (x xhs x_extra_env_ids))
                                                                                                    (array (cond ((or (= true a) (= true x)) true)
                                                                                                                 (true                       (intset_union a x)))
                                                                                                           (array_union ahs xhs)
                                                                                                           (intset_union aeei x_extra_env_ids))
                                                                                                 ) (array (array) resume_hashes (array)) (map needed_for_progress x)))
                                                                            (progress_idxs (cond ((and (= nil sub_progress_idxs) (not is_val) (= true attempted))  nil)
                                                                                                 ((and (= nil sub_progress_idxs) (not is_val) (= false attempted)) true)
                                                                                                 ((and (= nil sub_progress_idxs) (not is_val) (int? attempted))    (array attempted))
                                                                                                 (true                                                             (if (int? attempted)
                                                                                                                                                                       (intset_item_union sub_progress_idxs attempted)
                                                                                                                                                                       sub_progress_idxs))))
                                                                        ) (array 'marked_array  (hash_array is_val attempted x) is_val attempted (array progress_idxs hashes extra) x source resume_hashes))))


    (marked_env       (lambda (has_vals de? de ue dbi arrs) (dlet (
                                  (de_entry (mif de? (array (array de? de)) (array)))
                                  (full_arrs (concat arrs de_entry (array ue)))
                                  ((progress_idxs1 _hashes extra1) (mif ue  (needed_for_progress ue) (array nil nil nil)))
                                  ((progress_idxs2 _hashes extra2) (mif de? (needed_for_progress de) (array nil nil nil)))
                                  (progress_idxs (intset_union progress_idxs1 progress_idxs2))
                                  (extra (intset_union extra1 extra2))
                                  (progress_idxs (if (not has_vals) (intset_item_union progress_idxs dbi) progress_idxs))
                                  (extra         (if (!= nil progress_idxs) (intset_item_union extra dbi) extra))
                                ) (array 'env              (hash_env has_vals progress_idxs dbi full_arrs)                  has_vals (array progress_idxs nil extra) dbi full_arrs))))


    (marked_val       (lambda (x)                                             (array 'val       (hash_val x)                                              x)))
    (marked_comb      (lambda (wrap_level env_id de? se variadic params body) (array 'comb  (hash_comb wrap_level env_id de? se variadic params body) wrap_level env_id de? se variadic params body)))
    (comb_w_body      (dlambda ((_comb  _hash wrap_level env_id de? se variadic params _body) new_body) (marked_comb wrap_level env_id de? se variadic params new_body)))
    (marked_prim_comb (lambda (handler_fun real_or_name wrap_level val_head_ok)    (array 'prim_comb        (hash_prim_comb handler_fun real_or_name wrap_level val_head_ok) handler_fun real_or_name wrap_level val_head_ok)))

    (with_wrap_level                    (lambda (x new_wrap) (cond  ((prim_comb? x)   (dlet (((handler_fun real_or_name wrap_level val_head_ok) (.prim_comb x)))
                                                                                             (marked_prim_comb handler_fun real_or_name new_wrap val_head_ok)))
                                                                    ((comb? x)        (dlet (((wrap_level env_id de? se variadic params body) (.comb x)))
                                                                                             (marked_comb new_wrap env_id de? se variadic params body)))
                                                                    (true             (error "bad with_wrap_level")))))


    (later_head? (rec-lambda recurse (x) (or (and (marked_array? x)  (or (= false (.marked_array_is_val x)) (foldl (lambda (a x) (or a (recurse x))) false (.marked_array_values x))))
                                             (and (marked_symbol? x) (= false (.marked_symbol_is_val x)))
                                         )))


    ; array and comb are the ones wherewhere (= nil (needed_for_progress_slim x)) == total_value? isn't true.
    ; Right now we only call functions when all parameters are values, which means you can't
    ; create a true_value array with non-value memebers (*right now* anyway), but it does mean that
    ; you can create a nil needed for progress array that isn't a value, namely for the give_up_*
    ; primitive functions (extra namely, log and error, which are our two main sources of non-purity besides implicit runtime errors).
    ; OR, currently, having your code stopped because of infinite recursion checker. This comes up with the Y combiner
    ; For combs, being a value is having your env-chain be real?
    (total_value?  (lambda (x) (if (marked_array? x) (.marked_array_is_val x)
                                                     (= nil (needed_for_progress_slim x)))))


    (is_all_values      (lambda (evaled_params) (foldl (lambda (a x) (and a      (total_value? x))) true evaled_params)))
    (is_all_head_values (lambda (evaled_params) (foldl (lambda (a x) (and a (not (later_head? x)))) true evaled_params)))

    (false? (lambda (x) (cond ((and (marked_array? x)  (= false (.marked_array_is_val x)))    (error "got a later marked_array passed to false? " x))
                              ((and (marked_symbol? x) (= false (.marked_symbol_is_val x)))   (error "got a later marked_symbol passed to false? " x))
                              ((val? x)                                                       (not (.val x)))
                              (true                                                           false))))


    (mark (rec-lambda recurse (x) (cond   ((env? x)        (error "called mark with an env " x))
                                          ((combiner? x)   (error "called mark with a combiner " x))
                                          ((symbol? x)     (cond ((= 'true x)  (marked_val #t))
                                                                 ((= 'false x) (marked_val #f))
                                                                 (#t           (marked_symbol nil x))))
                                          ((array? x)      (marked_array true false nil (map recurse x) true))
                                          (true            (marked_val x)))))

    (indent_str (rec-lambda recurse (i) (mif (= i 0) ""
                                                   (str "   " (recurse (- i 1))))))
    (indent_str (if speed_hack (lambda (i) "") indent_str))

    (str_strip (lambda args (apply true_str (concat (slice args 0 -2) (array (idx ((rec-lambda recurse (x done_envs)
        (cond ((= nil x)          (array "<nil>" done_envs))
              ((string? x)        (array (true_str "<raw string " x ">") done_envs))
              ((val? x)           (array (true_str (.val x)) done_envs))
              ((marked_array? x)  (dlet (((stripped_values done_envs) (foldl (dlambda ((vs de) x) (dlet (((v de) (recurse x de))) (array (concat vs (array v)) de)))
                                                                             (array (array) done_envs) (.marked_array_values x))))
                                        (mif (.marked_array_is_val x) (array (true_str "[" stripped_values "]") done_envs)
                                                                      ;(array (true_str stripped_values) done_envs))))
                                                                      (array (true_str "<a" (.marked_array_is_attempted x) ",r" (needed_for_progress x) "~" (.marked_array_this_rec_stop x) "~*" (.hash x) "*>" stripped_values) done_envs))))
              ((marked_symbol? x) (mif (.marked_symbol_is_val x) (array (true_str "'" (.marked_symbol_value x)) done_envs)
                                                                 (array (true_str (.marked_symbol_needed_for_progress x) "#" (.marked_symbol_value x)) done_envs)))
              ((comb? x)          (dlet (((wrap_level env_id de? se variadic params body) (.comb x))
                                         ((se_s done_envs)   (recurse se done_envs))
                                         ((body_s done_envs) (recurse body done_envs)))
                                      (array (true_str "<n " (needed_for_progress x) " (comb " wrap_level " " env_id " " se_s " " de? " " params " " body_s ")>") done_envs)))
              ((prim_comb? x)     (array (true_str "<wl=" (.prim_comb_wrap_level x) " " (.prim_comb_sym x) ">") done_envs))
              ((marked_env? x)    (dlet ((e (.env_marked x))
                                         (index (.marked_env_id x))
                                         (u (idx e -1))
                                         (already (in_array index done_envs))
                                         (opening (true_str "{" (mif (marked_env_real? x) "real" "fake") (mif (.marked_env_has_vals x) " real vals" " fake vals")  " ENV idx: " (true_str index) ", "))
                                         ((middle done_envs) (if already (array "" done_envs) (foldl (dlambda ((vs de) (k v)) (dlet (((x de) (recurse v de))) (array (concat vs (array (array k x))) de)))
                                                                                                     (array (array) done_envs)
                                                                                                     (slice e 0 -2))))
                                         ((upper  done_envs) (if already (array "" done_envs) (mif u (recurse u done_envs) (array "no_upper_likely_root_env" done_envs))))
                                         (done_envs (if already done_envs (cons index done_envs)))
                                       ) (array (if already (true_str opening "omitted}")
                                                            (if (> (len e) 30) (true_str "{" (len e) "env}")
                                                                               (true_str opening middle " upper: " upper "}"))) done_envs)
                                               ))
              (true               (error (true_str "some other str_strip? |" x "|")))
        )
    ) (idx args -1) (array)) 0))))))
    (true_str_strip str_strip)
    (str_strip (if speed_hack (lambda args 0) str_strip))
    ;(true_str_strip str_strip)
    (print_strip (lambda args (println (apply str_strip args))))

    (env-lookup-helper (rec-lambda recurse (dict key i fail success) (cond ((and (= i (- (len dict) 1)) (= nil (idx dict i)))  (fail))
                                                                           ((= i (- (len dict) 1))                             (recurse (.env_marked (idx dict i)) key 0 fail success))
                                                                           ((= key (idx (idx dict i) 0))                       (success (idx (idx dict i) 1)))
                                                                           (true                                               (recurse dict key (+ i 1) fail success)))))
    (env-lookup (lambda (env key) (env-lookup-helper (.env_marked env) key 0 (lambda () (error (str key " not found in env " (str_strip env)))) (lambda (x) x))))

    (strip (dlet ((helper (rec-lambda recurse (x need_value)
        (cond ((val? x)           (.val x))
              ((marked_array? x)  (dlet ((stripped_values (map (lambda (x) (recurse x need_value)) (.marked_array_values x))))
                                      (mif (.marked_array_is_val x) stripped_values
                                                                    (error (str "needed value for this strip but got" x)))))
              ((marked_symbol? x) (mif (.marked_symbol_is_val x) (.marked_symbol_value x)
                                                                 (error (str "needed value for this strip but got" x))))
              ((comb? x)          (error "got comb for strip, won't work"))
              ((prim_comb? x)     (idx x 2))
                                         ; env emitting doesn't pay attention to real value right now, not sure mif that makes sense
                                         ; TODO: properly handle de Bruijn indexed envs
              ((marked_env? x)    (error "got env for strip, won't work"))
              (true               (error (str "some other strip? " x)))
        )
    )))  (lambda (x) (dlet (
                            ;(_ (print_strip "stripping: " x))
                            (r (helper x true))
                            ;(_ (println "result of strip " r))
                            ) r))))

    (try_unval (rec-lambda recurse (x fail_f)
        (cond ((marked_array? x) (mif (not (.marked_array_is_val x)) (array false (fail_f x))
                                                                    (if (!= 0 (len (.marked_array_values x)))
                                                                        (dlet ((values (.marked_array_values x))
                                                                               ((ok f) (recurse (idx values 0) fail_f))
                                                                        ) (array ok (marked_array false false nil (cons f (slice values 1 -1)) (.marked_array_source x))))
                                                                        (array true (marked_array false false nil (array) (.marked_array_source x))))))
              ((marked_symbol? x) (mif (.marked_symbol_is_val x) (array true (marked_symbol true (.marked_symbol_value x)))
                                                                 (array false (fail_f x))))
              (true               (array true x))
        )
    ))
    (try_unval_array (lambda (x) (foldl (dlambda ((ok a) x) (dlet (((nok p) (try_unval x (lambda (_) nil))))
                                                                   (array (and ok nok) (concat a (array p)))))
                                        (array true (array))
                                        x)))

    (check_for_env_id_in_result (lambda (s_env_id x) (idx ((rec-lambda check_for_env_id_in_result (memo s_env_id x)
        (dlet (
            ((need _hashes extra) (needed_for_progress x))
            (in_need (if (!= true need) (in_intset s_env_id need) false))
            (in_extra (in_intset s_env_id extra))
              ;(or in_need in_extra) (array memo true)
              ;(!= true need)        (array memo false)
        ) (cond ((or in_need in_extra) (array memo true))
                ((!= true need)        (array memo false))
                (true                  (dlet (

            (old_way (dlet (
                    (hash (.hash x))
                    ;(result (if (or (comb? x) (marked_env? x)) (alist-ref hash memo) false))
                    ;(result (if (or (marked_array? x) (marked_env? x)) (alist-ref hash memo) false))
                    ;(result (if (marked_env? x) (my-alist-ref hash memo) false))
                    (result (if (marked_env? x) (get memo hash) false))
                ) (if (array? result) (array memo (idx result 1)) (cond
                      ((marked_symbol? x) (array memo false))
                      ((marked_array? x)  (dlet (
                                            (values (.marked_array_values x))
                                            ((memo result) ((rec-lambda recurse (memo i) (if (= (len values) i) (array memo false)
                                                                                              (dlet (((memo r) (check_for_env_id_in_result memo s_env_id (idx values i))))
                                                                                                  (if r (array memo true)
                                                                                                        (recurse memo (+ i 1))))))
                                                            memo 0))
                                            ;(memo (put memo hash result))
                                          ) (array memo result)))
                      ((prim_comb? x)    (array memo false))
                      ((val? x)           (array memo false))
                      ((comb? x)          (dlet (
                                            ((wrap_level i_env_id de? se variadic params body) (.comb x))
                                            ((memo in_se) (check_for_env_id_in_result memo s_env_id se))
                                            ((memo total) (if (and (not in_se) (!= s_env_id i_env_id)) (check_for_env_id_in_result memo s_env_id body)
                                                                                                       (array memo in_se)))
                                            ;(memo (put memo hash total))
                                          ) (array memo total)))

                      ((marked_env? x)   (if (and (not (marked_env_real? x)) (= s_env_id (.marked_env_id x))) (array memo true)
                                                 (dlet (
                                                    (values (slice (.env_marked x) 0 -2))
                                                    (upper  (idx (.env_marked x) -1))
                                                    ((memo result) ((rec-lambda recurse (memo i) (if (= (len values) i) (array memo false)
                                                                                                      (dlet (((memo r) (check_for_env_id_in_result memo s_env_id (idx (idx values i) 1))))
                                                                                                          (if r (array memo true)
                                                                                                                (recurse memo (+ i 1))))))
                                                                    memo 0))
                                                    ((memo result) (if (or result (= nil upper)) (array memo result)
                                                                                                 (check_for_env_id_in_result memo s_env_id upper)))
                                                    (memo (put memo hash result))
                                                 ) (array memo result))))
                      (true              (error (str "Something odd passed to check_for_env_id_in_result " x)))
            ))))

            (new_if_working (or in_need in_extra))
            (_ (if (and (!= true need) (!= new_if_working (idx old_way 1))) (error "GAH looking for " s_env_id " - " need " - " extra " - " new_if_working " " (idx old_way 1))))
        ) old_way))))) (array) s_env_id x) 1)))

    (comb_takes_de? (lambda (x l) (cond
        ((comb? x)      (!= nil (.comb_des x)))
        ((prim_comb? x) (cond ((= (.prim_comb_sym x) 'vau)    true)
                              ((= (.prim_comb_sym x) 'eval)   (= 1 l))
                              ((= (.prim_comb_sym x) 'veval)  (= 1 l))
                              ((= (.prim_comb_sym x) 'lapply) (= 1 l))
                              ((= (.prim_comb_sym x) 'vapply) (= 1 l))
                              ((= (.prim_comb_sym x) 'cond)   true) ; but not vcond
                              (true                           false)))
        ((and (marked_array? x)  (not (.marked_array_is_val  x)))          true)
        ((and (marked_symbol? x) (not (.marked_symbol_is_val x)))          true)
        (true           (error (str "illegal comb_takes_de? param " x)))
    )))

    ; Handles let 4.3 through macro level leaving it as (<comb wraplevel=1 (y) (+ y x 12)> 13)
    ; need handling of symbols (which is illegal for eval but ok for calls) to push it farther
    (combiner_return_ok (rec-lambda combiner_return_ok (func_result env_id)
        (cond   ((not (later_head? func_result)) (not (check_for_env_id_in_result env_id func_result)))
        ; special cases now
        ;   *(veval body {env}) => (combiner_return_ok {env})
        ;       The reason we don't have to check body is that this form is only creatable in ways that body was origionally a value and only need {env}
        ;           Either it's created by eval, in which case it's fine, or it's created by something like (eval (array veval x de) de2) and the array has checked it,
        ;           or it's created via literal vau invocation, in which case the body is a value.
                ((and (marked_array? func_result)
                      (prim_comb? (idx (.marked_array_values func_result) 0))
                      (= 'veval (.prim_comb_sym (idx (.marked_array_values func_result) 0)))
                      (= 3 (len (.marked_array_values func_result)))
                      (combiner_return_ok (idx (.marked_array_values func_result) 2) env_id))                                       true)
        ;   (func ...params) => (and (doesn't take de func) (foldl combiner_return_ok (cons func params)))
        ;
                ((and (marked_array? func_result)
                      (not (comb_takes_de? (idx (.marked_array_values func_result) 0) (len (.marked_array_values func_result))))
                      (foldl (lambda (a x) (and a (combiner_return_ok x env_id))) true (.marked_array_values func_result)))         true)

        ;   So that's enough for macro like, but we would like to take it farther
        ;       For like (let1 a 12 (wrap (vau (x) (let1 y (+ a 1) (+ y x a)))))
        ;           we get to (+ 13 x 12) not being a value, and it reconstructs
        ;           (<comb wraplevel=1 (y) (+ y x 12)> 13)
        ;           and that's what eval gets, and eval then gives up as well.

        ;           That will get caught by the above cases to remain the expansion (<comb wraplevel=1 (y) (+ y x 12)> 13),
        ;           but ideally we really want another case to allow (+ 13 x 12) to bubble up
        ;           I think it would be covered by the (func ...params) case if a case is added to allow symbols to be bubbled up if their
        ;           needed for progress wasn't true or the current environment, BUT this doesn't work for eval, just for functions,
        ;           since eval changes the entire env chain (but that goes back to case 1, and might be eliminated at compile if it's an env reachable from the func).
        ;
        ;
        ;   Do note a key thing to be avoided is allowing any non-val inside a comb, since that can cause a fake env's ID to
        ;   reference the wrong env/comb in the chain.
        ;   We do allow calling eval with a fake env, but since it's only callable withbody value and is strict (by calling this)
        ;   about it's return conditions, and the env it's called with must be ok in the chain, and eval doesn't introduce a new scope, it works ok.
        ;   We do have to be careful about allowing returned later symbols from it though, since it could be an entirely different env chain.

                (true false)
        )
    ))

    (drop_redundent_veval (rec-lambda drop_redundent_veval (partial_eval_helper x de env_stack pectx indent) (dlet (
                                                    (env_id (.marked_env_id de))
                                                    (r (if
                                                      (and (marked_array? x) (not (.marked_array_is_val x)))
                                                           (if (and (prim_comb? (idx (.marked_array_values x) 0))
                                                                    (= 'veval (.prim_comb_sym (idx (.marked_array_values x) 0)))
                                                                    (= 3 (len (.marked_array_values x)))
                                                                    (not (marked_env_real? (idx (.marked_array_values x) 2)))
                                                                    (= env_id (.marked_env_id (idx (.marked_array_values x) 2)))) (drop_redundent_veval partial_eval_helper (idx (.marked_array_values x) 1) de env_stack pectx (+ 1 indent))
                                                                                                                                   ; wait, can it do this? will this mess with eval?

                                                           ; basically making sure that this comb's params are still good to eval
                                                           (if (and (or (prim_comb? (idx (.marked_array_values x) 0)) (comb? (idx (.marked_array_values x) 0)))
                                                                     (!= -1 (.any_comb_wrap_level (idx (.marked_array_values x) 0))))
                                                                (dlet (((pectx err ress changed) (foldl (dlambda ((c er ds changed) p) (dlet (
                                                                                                      (pre_hash (.hash p))
                                                                                                      ((c e d) (drop_redundent_veval partial_eval_helper p de env_stack c (+ 1 indent)))
                                                                                                      (err (mif er er e))
                                                                                                      (changed (mif err false (or (!= pre_hash (.hash d)) changed)))
                                                                                                    ) (array c err (concat ds (array d)) changed)))
                                                                                                 (array pectx nil (array) false)
                                                                                                 (.marked_array_values x)))
                                                                        ((pectx err new_array) (if (or (!= nil err) (not changed))
                                                                                                   (array pectx err x)
                                                                                                   (partial_eval_helper (marked_array false (.marked_array_is_attempted x) nil ress (.marked_array_source x))
                                                                                                                        false de env_stack pectx (+ indent 1) true)))

                                                                       ) (array pectx err new_array))
                                                                (array pectx nil x))
                                                            ) (array pectx nil x))))

                                                    r)))

    (make_tmp_inner_env (lambda (params de? ue env_id)
        (dlet ((param_entries       (map (lambda (p) (array p (marked_symbol env_id p))) params))
               (possible_de         (mif (= nil de?) (array) (marked_symbol  env_id de?)))
            ) (marked_env false de? possible_de ue env_id param_entries))))


    (partial_eval_helper (rec-lambda partial_eval_helper (x only_head env env_stack pectx indent force)
        (dlet (((for_progress for_progress_hashes extra_env_ids) (needed_for_progress x))
               (_ (print_strip (indent_str indent) "for_progress " for_progress ", for_progress_hashes " for_progress_hashes " for " x))
               ((env_counter memo) pectx)
               (hashes_now (foldl (lambda (a hash) (or a (= false (get-value-or-false memo hash)))) false for_progress_hashes))
              )
        (if (or force hashes_now (= for_progress true) (intset_intersection_nonempty for_progress (idx env_stack 0)))
        (cond   ((val? x)            (array pectx nil x))
                ((marked_env? x)     (dlet ((dbi (.marked_env_id x)))
                                          ; compiler calls with empty env stack
                                          (mif dbi (dlet ( (new_env ((rec-lambda rec (i len_env_stack) (cond ((= i len_env_stack)                                 nil)
                                                                                                             ((= dbi (.marked_env_id (idx (idx env_stack 1) i))) (idx (idx env_stack 1) i))
                                                                                                             (true                                                (rec (+ i 1) len_env_stack))))
                                                                     0 (len (idx env_stack 1))))
                                                         (_ (println (str_strip "replacing " x) (str_strip " with (if nonnil) " new_env)))
                                                        )
                                                        (array pectx nil (if (!= nil new_env) new_env x)))
                                                  (array pectx nil x))))

                ((comb? x)           (dlet (((wrap_level env_id de? se variadic params body) (.comb x)))
                                        (mif (or (and (not (marked_env_real? env)) (not (marked_env_real? se)))   ; both aren't real, re-evaluation of creation site
                                                 (and      (marked_env_real? env)  (not (marked_env_real? se))))  ; new env real, but se isn't - creation!
                                             (dlet ((inner_env (make_tmp_inner_env params de? env env_id))
                                                    ((pectx err evaled_body) (partial_eval_helper body false inner_env (array (idx env_stack 0) (cons inner_env (idx env_stack 1))) pectx (+ indent 1) false)))
                                                   (array pectx err (mif err nil (marked_comb wrap_level env_id de? env variadic params evaled_body))))
                                             (array pectx nil x))))
                ((prim_comb? x)      (array pectx nil x))
                ((marked_symbol? x)  (mif (.marked_symbol_is_val x) x
                                                                    (env-lookup-helper (.env_marked env) (.marked_symbol_value x) 0
                                                                                       (lambda ()  (array pectx (str "could't find " (true_str_strip x) " in " (str_strip env))  nil))
                                                                                       (lambda (x) (array pectx nil x)))))
                                                                     ; Does this ever happen? non-fully-value arrays?
                ((marked_array? x)   (cond ((.marked_array_is_val x) (dlet ( ((pectx err inner_arr) (foldl (dlambda ((c er ds) p) (dlet (((c e d) (partial_eval_helper p false env env_stack c (+ 1 indent) false))) (array c (mif er er e) (concat ds (array d)))))
                                                                                                             (array pectx nil (array))
                                                                                                             (.marked_array_values x)))
                                                                           ) (array pectx err (mif err nil (marked_array true false nil inner_arr (.marked_array_source x))))))
                                           ((= 0 (len (.marked_array_values x))) (array pectx "Partial eval on empty array" nil))
                                           (true (dlet ((values (.marked_array_values x))
                                                        (_ (print_strip (indent_str indent) "partial_evaling comb " (idx values 0)))

                                                        (literal_params (slice values 1 -1))
                                                        ((pectx err comb) (partial_eval_helper (idx values 0) false env env_stack pectx (+ 1 indent) false))
                                                       ) (cond ((!= nil err) (array pectx err nil))
                                                               ((later_head? comb)                               (array pectx nil (marked_array false true nil (cons comb literal_params) (.marked_array_source x))))
                                                               ((not (or (comb? comb) (prim_comb? comb))) (array pectx (str "impossible comb value " x) nil))
                                                               (true    (dlet (
                                                                            ; If we haven't evaluated the function before at all, we would like to partially evaluate it so we know
                                                                            ; what it needs. We'll see if this re-introduces exponentail (I think this should limit it to twice?)
                                                                            (comb_err nil)
                                                                            ;((pectx comb_err comb) (if (and (= nil err) (= true (needed_for_progress_slim comb)))
                                                                            ;                            (partial_eval_helper comb false env env_stack pectx (+ 1 indent) false)
                                                                            ;                            (array pectx err comb)))
                                                                            (_ (println (indent_str indent) "Going to do an array call!"))
                                                                            (indent (+ 1 indent))
                                                                            (_ (print_strip (indent_str indent) "total (in env " (.marked_env_id env) ") is (proceeding err " err ") " x))
                                                                            (map_rp_eval (lambda (pectx ps) (foldl (dlambda ((c er ds) p) (dlet ((_ (print_strip (indent_str indent) "rp_evaling " p)) ((c e d) (partial_eval_helper p false env env_stack c (+ 1 indent) false)) (_ (print_strip (indent_str indent) "result of rp_eval was err " e " and value " d))) (array c (mif er er e) (concat ds (array d)))))
                                                                                                        (array pectx nil (array))
                                                                                                        ps)))
                                                                            (wrap_level (.any_comb_wrap_level comb))
                                                                                                                                ; -1 is a minor hack for veval to prevent re-eval
                                                                                                                                ; in the wrong env and vcond to prevent guarded
                                                                                                                                ; infinate recursion
                                                                            ((remaining_wrap param_err evaled_params pectx) (if (= -1 wrap_level)
                                                                                                                                (array -1 nil literal_params pectx)
                                                                                                                                ((rec-lambda param-recurse (wrap cparams pectx)
                                                                                   (dlet (
                                                                                          (_ (print (indent_str indent) "For initial rp_eval:"))
                                                                                          (_ (map (lambda (x) (print_strip (indent_str indent) "item " x)) cparams))
                                                                                          ((pectx er pre_evaled) (map_rp_eval pectx cparams))
                                                                                          (_ (print (indent_str indent) "er for intial  rp_eval: " er))
                                                                                         )
                                                                                       (mif er (array wrap er nil pectx)
                                                                                       (mif (!= 0 wrap)
                                                                                           (dlet (((ok unval_params) (try_unval_array pre_evaled)))
                                                                                                (mif (not ok) (array wrap nil pre_evaled pectx)
                                                                                                              (param-recurse (- wrap 1) unval_params pectx)))
                                                                                           (array wrap nil pre_evaled pectx)))))
                                                                                                                        wrap_level literal_params pectx)))
                                                                            (_ (println (indent_str indent) "Done evaluating parameters"))

                                                                            (l_later_call_array (lambda () (marked_array false true nil (cons (with_wrap_level comb remaining_wrap) evaled_params) (.marked_array_source x))))
                                                                            (ok_and_non_later (or (= -1 remaining_wrap)
                                                                                                  (and (= 0 remaining_wrap) (if (and (prim_comb? comb) (.prim_comb_val_head_ok comb))
                                                                                                                                (is_all_head_values evaled_params)
                                                                                                                                (is_all_values evaled_params)))))
                                                                            (_ (println (indent_str indent) "ok_and_non_later " ok_and_non_later))
                                                                        ) (cond ((!= nil comb_err)      (array pectx comb_err nil))
                                                                                ((!= nil param_err)     (array pectx param_err nil))
                                                                                ((not ok_and_non_later) (array pectx nil (l_later_call_array)))
                                                                                ((prim_comb? comb) (dlet (
                                                                                                    ;(_ (println (indent_str indent) "Calling prim comb " (.prim_comb_sym comb)))
                                                                                                    ;(_ (if (= '!= (.prim_comb_sym comb)) (true_print (indent_str indent) "Calling prim comb " (.prim_comb_sym comb) " with params " evaled_params)))
                                                                                                    ((pectx err result) ((.prim_comb_handler comb) only_head env env_stack pectx evaled_params (+ 1 indent)))
                                                                                                    ) (if (= 'LATER err) (array pectx nil (l_later_call_array))
                                                                                                                         (array pectx err result))))
                                                                                ((comb? comb)      (dlet (
                                                                                     ((wrap_level env_id de? se variadic params body) (.comb comb))


                                                                                     (final_params (mif variadic (concat (slice evaled_params 0 (- (len params) 1))
                                                                                                                       (array (marked_array true false nil (slice evaled_params (- (len params) 1) -1) nil)))
                                                                                                                 evaled_params))
                                                                                     (de_env (mif (!= nil de?) env nil))
                                                                                     (inner_env (marked_env true de? de_env se env_id (zip params final_params)))
                                                                                     (_ (print_strip (indent_str indent) " with inner_env is " inner_env))
                                                                                     (_ (print_strip (indent_str indent) "going to eval " body))

                                                                                     ; prevent infinite recursion
                                                                                     (hash (combine_hash (.hash body) (.hash inner_env)))
                                                                                     ((env_counter memo) pectx)
                                                                                     ((pectx func_err func_result rec_stop) (if (!= false (get-value-or-false memo hash))
                                                                                                                                (array pectx nil "stopping for infinite recursion" true)
                                                                                                                    (dlet (
                                                                                                                        (new_memo (put memo hash nil))
                                                                                                                        (pectx (array env_counter new_memo))
                                                                                                                        ((pectx func_err func_result) (partial_eval_helper body only_head inner_env
                                                                                                                                                            (array (intset_item_union (idx env_stack 0) env_id)
                                                                                                                                                                   (cons inner_env (idx env_stack 1)))
                                                                                                                                                                           pectx (+ 1 indent) false))
                                                                                                                        ((env_counter new_memo) pectx)
                                                                                                                        (pectx (array env_counter memo))
                                                                                                                    ) (array pectx func_err func_result false))))

                                                                                     (_ (print_strip (indent_str indent) "evaled result of function call (in env " (.marked_env_id env) ", with inner " env_id ") and err " func_err "  is " func_result))
                                                                                     (must_stop_maybe_id (and (= nil func_err)
                                                                                                              (or rec_stop (if (not (combiner_return_ok func_result env_id))
                                                                                                                               (if (!= nil de?) (.marked_env_id env) true)
                                                                                                                               false))))
                                                                                     ) (if (!= nil func_err) (array pectx func_err nil)
                                                                                             (if must_stop_maybe_id
                                                                                                 (array pectx nil (marked_array false must_stop_maybe_id (if rec_stop (array hash) nil) (cons (with_wrap_level comb remaining_wrap) evaled_params) (.marked_array_source x)))
                                                                                                 (dlet (((pectx err x) (drop_redundent_veval partial_eval_helper func_result env env_stack pectx indent)))
                                                                                                       (array pectx err x))))))
                                                                        )))
                                                               )))))

                (true                (array pectx (str "impossible partial_eval value " x) nil))
        )
        ; otherwise, we can't make progress yet
        (begin (print_strip (indent_str indent) "Not evaluating " x)
               ;(print (indent_str indent) "comparing to env stack " env_stack)
               (drop_redundent_veval partial_eval_helper x env env_stack pectx indent))))
    ))

    (needs_params_val_lambda (lambda (f_sym actual_function) (dlet (
        (handler (rec-lambda recurse (only_head de env_stack pectx params indent)
                                     (array pectx nil (mark (apply actual_function (map strip params))))))
        ) (array f_sym (marked_prim_comb handler f_sym 1 false)))))

    (give_up_eval_params (lambda (f_sym) (dlet (
        (handler (lambda (only_head de env_stack pectx params indent) (array pectx 'LATER nil)))
        ) (array f_sym (marked_prim_comb handler f_sym 1 false)))))

    (veval_inner (rec-lambda recurse (only_head de env_stack pectx params indent) (dlet (
        (body (idx params 0))
        (implicit_env (!= 2 (len params)))
        (eval_env (if implicit_env de (idx params 1)))
        ((pectx err eval_env)  (if implicit_env (array pectx nil de)
                                                (partial_eval_helper (idx params 1) only_head de env_stack pectx (+ 1 indent) false)))
        ((pectx err ebody) (if (or (!= nil err) (not (marked_env? eval_env)))
                               (array pectx err body)
                               (partial_eval_helper body only_head eval_env env_stack pectx (+ 1 indent) false)))
    ) (cond
        ((!= nil err)                                          (begin (print (indent_str indent) "got err " err) (array pectx err nil)))
        ; If our env was implicit, then our unval'd code can be inlined directly in our caller
        (implicit_env                                          (drop_redundent_veval partial_eval_helper ebody de env_stack pectx indent))
        ((combiner_return_ok ebody (.marked_env_id eval_env)) (drop_redundent_veval partial_eval_helper ebody de env_stack pectx indent))
        (true                                                  (drop_redundent_veval partial_eval_helper (marked_array false true nil (array (marked_prim_comb recurse 'veval -1 true) ebody eval_env) nil) de env_stack pectx indent))
    ))))

    (env_id_start 1)
    (empty_env      (marked_env true nil nil nil nil nil))
    (quote_internal (marked_comb 0 env_id_start nil empty_env false (array 'x) (marked_symbol env_id_start 'x)))
    (env_id_start (+ 1 env_id_start))

    (root_marked_env (marked_env true nil nil nil nil (array

        (array 'eval (marked_prim_comb (rec-lambda recurse (only_head de env_stack pectx evaled_params indent)
            (if (not (total_value? (idx evaled_params 0)))                                (array pectx nil (marked_array false true nil (cons (marked_prim_comb recurse 'eval 0 true) evaled_params) nil))
            (if (and (= 2 (len evaled_params)) (not (marked_env? (idx evaled_params 1)))) (array pectx nil (marked_array false true nil (cons (marked_prim_comb recurse 'eval 0 true) evaled_params) nil))
            (dlet (
                (body (idx evaled_params 0))
                (implicit_env (!= 2 (len evaled_params)))
                (eval_env (if implicit_env de (idx evaled_params 1)))
                ((ok unval_body) (try_unval body (lambda (_) nil)))
                (_ (if (not ok) (error "actually impossible eval unval")))


            ) (veval_inner only_head de env_stack pectx (if implicit_env (array unval_body) (array unval_body eval_env)) indent))))
        ) 'eval 1 true))

        (array 'vapply (marked_prim_comb (dlambda (only_head de env_stack pectx args indent)
            (veval_inner only_head de env_stack pectx (array (marked_array false false nil (cons (idx args 0) (.marked_array_values (idx args 1))) nil) (mif (= 3 (len args)) (idx args 2) de)) (+ 1 indent))
        ) 'vapply 1 true))
        (array 'lapply (marked_prim_comb (dlambda (only_head de env_stack pectx args indent)
            (mif (< 0 (.any_comb_wrap_level (idx args 0)))
                 (veval_inner only_head de env_stack pectx (array (marked_array false false nil (cons (with_wrap_level (idx args 0) (- (.any_comb_wrap_level (idx args 0)) 1)) (.marked_array_values (idx args 1))) nil) (mif (= 3 (len args)) (idx args 2) de)) (+ 1 indent))
                 (veval_inner only_head de env_stack pectx (array (marked_array false false nil (cons (idx args 0)
                                                                                                      (map (lambda (x) (marked_array false false nil (array quote_internal x) nil)) (.marked_array_values (idx args 1)))
                                                                                                ) nil) (mif (= 3 (len args)) (idx args 2) de)) (+ 1 indent))
            )
        ) 'lapply 1 true))

        (array 'vau (marked_prim_comb (lambda (only_head de env_stack pectx params indent) (dlet (
            (mde?         (mif (= 3 (len params)) (idx params 0) nil))
            (vau_mde?     (mif (= nil mde?) (array) (array mde?)))
            (_ (print (indent_str indent) "mde? is " mde?))
            (_ (print (indent_str indent) "\tmde? if " (mif mde? #t #f)))
            (de?          (mif mde? (.marked_symbol_value mde?) nil))
            (_ (print (indent_str indent) "de? is " de?))
            (vau_de?      (mif (= nil de?) (array) (array de?)))
            (raw_marked_params (mif (= nil de?) (idx params 0) (idx params 1)))
            (raw_params (map (lambda (x) (mif (not (marked_symbol? x)) (error (str "not a marked symbol " x))
                                            (.marked_symbol_value x))) (.marked_array_values raw_marked_params)))

            ((variadic vau_params)  (foldl (dlambda ((v a) x) (mif (= x '&) (array true a) (array v (concat a (array x))))) (array false (array)) raw_params))
            ((ok body) (try_unval (mif (= nil de?) (idx params 1) (idx params 2)) (lambda (_) nil)))
            (_ (if (not ok) (error "actually impossible vau unval")))
            ((env_counter memo) pectx)
            (new_id env_counter)
            (env_counter (+ 1 env_counter))
            (pectx (array env_counter memo))
            ((pectx err pe_body) (if (and false only_head) (begin (print "skipping inner eval cuz only_head") (array pectx nil body))
                                       (dlet (
                                            (inner_env (make_tmp_inner_env vau_params de? de new_id))
                                            (_ (print_strip (indent_str indent) "in vau, evaluating body with 'later params - " body))
                                            ((pectx err pe_body) (partial_eval_helper body false inner_env (array (idx env_stack 0)
                                                                                                                  (cons inner_env (idx env_stack 1))) pectx (+ 1 indent) false))
                                            (_ (print_strip (indent_str indent) "in vau, result of evaluating body was " pe_body))
                                        ) (array pectx err pe_body))))
        ) (mif err (array pectx err nil) (array pectx nil (marked_comb 0 new_id de? de variadic vau_params pe_body)))
        )) 'vau 0 true))

        (array 'wrap (marked_prim_comb (dlambda (only_head de env_stack pectx (evaled) indent)
              (if (comb? evaled) (array pectx nil (with_wrap_level evaled (+ (.any_comb_wrap_level evaled) 1)))
                                 (array pectx "bad passed to wrap" nil))
        ) 'wrap 1 true))

        (array 'unwrap (marked_prim_comb (dlambda (only_head de env_stack pectx (evaled) indent)
              ; TODO should support prim comb like runtime
              (if (comb? evaled) (array pectx nil (with_wrap_level evaled (- (.any_comb_wrap_level evaled) 1)))
                                 (array pectx "bad passed to unwrap" nil))
        ) 'unwrap 1 true))

        (array 'cond (marked_prim_comb ((rec-lambda recurse (already_stripped) (lambda (only_head de env_stack pectx params indent)
            (mif (!= 0 (% (len params) 2)) (array pectx (str "partial eval cond with odd params " params) nil)
                (dlet (
                    (eval_helper    (lambda (to_eval pectx)
                                       (dlet (((ok unvald) (if already_stripped (array true to_eval)
                                                                                (try_unval to_eval (lambda (_) nil)))))
                                             (mif (not ok)
                                                  (array pectx "bad unval in cond" nil)
                                                  (partial_eval_helper unvald false de env_stack pectx (+ 1 indent) false)))))
                )
                ((rec-lambda recurse_inner (i so_far pectx)
                                          (dlet (((pectx err pred)                              (eval_helper (idx params i) pectx)))
                                          (cond ((!= nil err)                                   (array pectx err nil))
                                                ((later_head? pred)                             (dlet (
                                                                                            (sliced_params (slice params (+ i 1) -1))
                                                                                            (this (marked_array false true nil (concat (array (marked_prim_comb (recurse false) 'cond 0 true)
                                                                                                                                              pred)
                                                                                                                                       sliced_params) nil))
                                                                                            (hash (combine_hash (combine_hash 101 (.hash this)) (+ 103 (.marked_env_id de))))
                                                                                            ((env_counter memo) pectx)
                                                                                            (already_in (!= false (get-value-or-false memo hash)))
                                                                                            (_ (if already_in (print_strip "ALREADY IN " this)
                                                                                                              (print_strip "NOT ALREADY IN, CONTINUING with " this)))
                                                                                            ; WE SHOULDN'T DIE ON ERROR, since these errors may be guarded by conditions we
                                                                                            ; can't evaluate. We'll keep branches that error as un-valed only
                                                                                            ((pectx _err evaled_params later_hash) (if already_in
                                                                                                        (array pectx nil (if already_stripped sliced_params
                                                                                                                                              (map (lambda (x) (dlet (((ok ux) (try_unval x (lambda (_) nil)))
                                                                                                                                                 (_ (if (not ok) (error "BAD cond un first  " already_stripped " " x))))
                                                                                                                                                 ux))
                                                                                                                              sliced_params)) (array hash))
                                                                                                        (foldl (dlambda ((pectx _err as later_hash) x)
                                                                                                            (dlet (((pectx er a) (eval_helper x pectx)))
                                                                                                                (mif er (dlet (((ok ux) (if already_stripped (array true x) (try_unval x (lambda (_) nil))))
                                                                                                                               (_ (if (not ok) (error (str "BAD cond un second " already_stripped " " x)))))
                                                                                                                              (array pectx nil (concat as (array ux)) later_hash))
                                                                                                                        (array pectx nil (concat as (array a)) later_hash)))
                                                                                                        ) (array (array env_counter (put memo hash nil)) nil (array) nil) sliced_params)))
                                                                                            ((env_counter omemo) pectx)
                                                                                            (new_call (concat (array (marked_prim_comb (recurse true) 'vcond -1 true) pred) evaled_params))
                                                                                            (pectx (array env_counter memo))
                                                                                                ) (array pectx nil (marked_array false true later_hash new_call nil))))
                                                ((and (< (+ 2 i) (len params)) (false? pred))   (recurse_inner (+ 2 i) so_far pectx))
                                                (                              (false? pred)    (array pectx "comb reached end with no true" nil))
                                                (true                                           (eval_helper (idx params (+ i 1)) pectx))
                 ))) 0 (array) pectx))
            )
        )) false) 'cond 0 true))

        (needs_params_val_lambda 'symbol? symbol?)
        (needs_params_val_lambda 'int? int?)
        (needs_params_val_lambda 'string? string?)

        (array 'combiner? (marked_prim_comb (dlambda (only_head de env_stack pectx (evaled_param) indent)
            (array pectx nil (cond
                  ((comb? evaled_param)          (marked_val true))
                  ((prim_comb? evaled_param)     (marked_val true))
                  (true                          (marked_val false))
            ))
        ) 'combiner? 1 true))
        (array 'env? (marked_prim_comb (dlambda (only_head de env_stack pectx (evaled_param) indent)
            (array pectx nil (cond
                  ((marked_env? evaled_param)    (marked_val true))
                  (true                          (marked_val false))
            ))
        ) 'env? 1 true))
        (needs_params_val_lambda 'nil? nil?)
        (needs_params_val_lambda 'bool? bool?)
        (needs_params_val_lambda 'str-to-symbol str-to-symbol)
        (needs_params_val_lambda 'get-text get-text)

        (array 'array? (marked_prim_comb (dlambda (only_head de env_stack pectx (evaled_param) indent)
            (array pectx nil (cond
                  ((marked_array? evaled_param)  (marked_val true))
                  (true                          (marked_val false))
            ))
        ) 'array? 1 true))

        ; Look into eventually allowing some non values, perhaps, when we look at combiner non all value params
        (array 'array (marked_prim_comb (lambda (only_head de env_stack pectx evaled_params indent)
                                                (array pectx nil (marked_array true false nil evaled_params nil))
        ) 'array 1 false))
        (array 'len (marked_prim_comb (dlambda (only_head de env_stack pectx (evaled_param) indent)
            (cond
                  ((marked_array? evaled_param)         (array pectx nil (marked_val (len (.marked_array_values evaled_param)))))
                  ((and (val? evaled_param)
                        (string? (.val evaled_param)))  (array pectx nil (marked_val (len (.val evaled_param)))))
                  (true                                 (array pectx (str "bad type to len " evaled_param) nil))
            )
        ) 'len 1 true))
        (array 'idx (marked_prim_comb (dlambda (only_head de env_stack pectx (evaled_array evaled_idx) indent)
            (cond
                  ((and (val? evaled_idx) (marked_array? evaled_array))                       (if (< (.val evaled_idx) (len (.marked_array_values evaled_array)))
                                                                                                  (array pectx nil (idx (.marked_array_values evaled_array) (.val evaled_idx)))
                                                                                                  (array pectx (true_str "idx out of bounds " evaled_array " " evaled_idx) nil)))
                  ((and (val? evaled_idx) (val? evaled_array) (string? (.val evaled_array)))  (array pectx nil (marked_val (idx (.val evaled_array) (.val evaled_idx)))))
                  (true                                                                       (array pectx (str "bad type to idx " evaled_idx " " evaled_array) nil))
            )
        ) 'idx 1 true))
        (array 'slice (marked_prim_comb (dlambda (only_head de env_stack pectx (evaled_array evaled_begin evaled_end) indent)
            (cond
                  ((and (val? evaled_begin) (val? evaled_end) (marked_array? evaled_array)

                              (int? (.val evaled_begin))
                              (or (and (>= (.val evaled_begin) 0) (<= (.val evaled_begin) (len (.marked_array_values evaled_array))))
                                  (and (<  (.val evaled_begin) 0) (>= (+ (.val evaled_begin) 1 (len (.marked_array_values evaled_array))) 0)
                                                                  (<= (+ (.val evaled_begin) 1 (len (.marked_array_values evaled_array))) (len (.marked_array_values evaled_array)))))
                              (int? (.val evaled_end))
                              (or (and (>= (.val evaled_end) 0)   (<= (.val evaled_end) (len (.marked_array_values evaled_array))))
                                  (and (<  (.val evaled_end) 0)   (>= (+ (.val evaled_end) 1 (len (.marked_array_values evaled_array))) 0)
                                                                  (<= (+ (.val evaled_end) 1 (len (.marked_array_values evaled_array))) (len (.marked_array_values evaled_array)))))
                  )
                            (array pectx nil (marked_array true false nil (slice (.marked_array_values evaled_array) (.val evaled_begin) (.val evaled_end)) nil)))
                  ((and (val? evaled_begin) (val? evaled_end) (val? evaled_array) (string? (.val evaled_array))

                              (int? (.val evaled_begin))
                              (or (and (>= (.val evaled_begin) 0) (<= (.val evaled_begin) (len (.val evaled_array))))
                                  (and (<  (.val evaled_begin) 0) (>= (+ (.val evaled_begin) 1 (len (.val evaled_array))) 0)
                                                                  (<= (+ (.val evaled_begin) 1 (len (.val evaled_array))) (len (.val evaled_array)))))
                              (int? (.val evaled_end))
                              (or (and (>= (.val evaled_end) 0)   (<= (.val evaled_end) (len (.val evaled_array))))
                                  (and (<  (.val evaled_end) 0)   (>= (+ (.val evaled_end) 1 (len (.val evaled_array))) 0)
                                                                  (<= (+ (.val evaled_end) 1 (len (.val evaled_array))) (len (.val evaled_array)))))
                  )

                            (array pectx nil (marked_val (slice (.val evaled_array) (.val evaled_begin) (.val evaled_end)))))
                  (true     (array pectx (str "bad params to slice " evaled_begin " " evaled_end " " evaled_array) nil))
            )
        ) 'slice 1 true))
        (array 'concat (marked_prim_comb (lambda (only_head de env_stack pectx evaled_params indent)
            (cond
                  ((foldl (lambda (a x) (and a (marked_array? x))) true evaled_params)
                        (array pectx nil (marked_array true false nil (lapply concat (map (lambda (x) (.marked_array_values x)) evaled_params)) nil)))
                  ((foldl (lambda (a x) (and a (val? x) (string? (.val x)))) true evaled_params)
                        (array pectx nil (marked_val (lapply concat (map (lambda (x) (.val x)) evaled_params)))))
                  (true                                                                (array pectx (str "bad params to concat " evaled_params) nil))
            )
        ) 'concat 1 true))

        (needs_params_val_lambda '+ +)
        (needs_params_val_lambda '- -)
        (needs_params_val_lambda '* *)
        (needs_params_val_lambda '/ /)
        (needs_params_val_lambda '% %)
        (needs_params_val_lambda 'band band)
        (needs_params_val_lambda 'bor bor)
        (needs_params_val_lambda 'bnot bnot)
        (needs_params_val_lambda 'bxor bxor)
        (needs_params_val_lambda '<< <<)
        (needs_params_val_lambda '>> >>)
        (needs_params_val_lambda '= =)
        (needs_params_val_lambda '!= !=)
        (needs_params_val_lambda '< <)
        (needs_params_val_lambda '<= <=)
        (needs_params_val_lambda '> >)
        (needs_params_val_lambda '>= >=)
        (needs_params_val_lambda 'str true_str)
        ;(needs_params_val_lambda 'pr-str pr-str)
        ;(needs_params_val_lambda 'prn prn)
        (give_up_eval_params 'log)
        (give_up_eval_params 'debug)
        (give_up_eval_params 'builtin_fib)
        ; really do need to figure out mif we want to keep meta, and add it mif so
        ;(give_up_eval_params 'meta meta)
        ;(give_up_eval_params 'with-meta with-meta)
        ; mif we want to get fancy, we could do error/recover too
        (give_up_eval_params 'error)
        ;(give_up_eval_params 'recover)
        (needs_params_val_lambda 'read-string read-string)
        (array 'empty_env empty_env)
    )))

    (partial_eval (lambda (x) (partial_eval_helper (idx (try_unval (mark x) (lambda (_) nil)) 1) false root_marked_env (array nil nil) (array env_id_start empty_dict) 0 false)))


    ;; WASM

    ; Vectors and Values
    ; Bytes encode themselves

    ; Note that the shift must be arithmatic
    (encode_LEB128 (rec-lambda recurse (x)
        (dlet ((b (band #x7F x))
              (v (>> x 7)))

            (cond ((or (and (= v 0) (= (band b #x40) 0)) (and (= v -1) (!= (band b #x40) 0))) (array b))
                  (true                                                                       (cons (bor b #x80) (recurse v)))))
    ))
    (encode_vector (lambda (enc v)
        (concat (encode_LEB128 (len v)) (flat_map enc v) )
    ))
    (encode_floating_point (lambda (x) (error "unimplemented")))
    (encode_name (lambda (name)
        (encode_vector (lambda (x) (array x)) (map char->integer (string->list name)))
    ))
    (hex_digit (lambda (digit) (dlet ((d (char->integer digit)))
                                    (cond ((< d #x3A) (- d #x30))
                                          ((< d #x47) (- d #x37))
                                          (true       (- d #x57))))))
    (encode_bytes (lambda (str)
        (encode_vector (lambda (x) (array x)) ((rec-lambda recurse (s) (cond
                                                                          ((= nil s)       nil)
                                                                          ((= #\\ (car s)) (cons (+ (* 16 (hex_digit (car (cdr s))))
                                                                                                          (hex_digit (car (cdr (cdr s))))) (recurse (cdr (cdr (cdr s))))))
                                                                          (true            (cons (char->integer (car s)) (recurse (cdr s))))
                                               )) (string->list str)))
    ))

    (encode_limits (lambda (x)
       (cond ((= 1 (len x)) (concat (array #x00) (encode_LEB128 (idx x 0))))
             ((= 2 (len x)) (concat (array #x01) (encode_LEB128 (idx x 0)) (encode_LEB128 (idx x 1))))
             (true          (error "trying to encode bad limits")))
    ))
    (encode_number_type (lambda (x)
        (cond  ((= x 'i32) (array #x7F))
               ((= x 'i64) (array #x7E))
               ((= x 'f32) (array #x7D))
               ((= x 'f64) (array #x7C))
               (true       (error (str "bad number type " x))))
    ))
    (encode_valtype (lambda (x)
        ; we don't handle reference types yet
        (encode_number_type x)
    ))
    (encode_result_type (lambda (x)
        (encode_vector encode_valtype x)
    ))
    (encode_function_type (lambda (x)
        (concat (array #x60) (encode_result_type (idx x 0))
                             (encode_result_type (idx x 1)))
    ))
    (encode_ref_type (lambda (t) (cond ((= t 'funcref)   (array #x70))
                                       ((= t 'externref) (array #x6F))
                                       (true             (error (str "Bad ref type " t))))))
    (encode_type_section (lambda (x)
        (dlet (
            (encoded (encode_vector encode_function_type x))
        ) (concat (array #x01) (encode_LEB128 (len encoded)) encoded ))
    ))
    (encode_import (lambda (import)
        (dlet (
            ((mod_name name type idx) import)
        ) (concat (encode_name mod_name)
                  (encode_name name)
                  (cond ((= type 'func)   (concat (array #x00) (encode_LEB128 idx)))
                        ((= type 'table)  (concat (array #x01) (error "can't encode table type")))
                        ((= type 'memory) (concat (array #x02) (error "can't encode memory type")))
                        ((= type 'global) (concat (array #x03) (error "can't encode global type")))
                        (true                                  (error (str "bad import type" type)))))
        )
    ))
    (encode_import_section (lambda (x)
        (dlet (
            (encoded (encode_vector encode_import x))
        ) (concat (array #x02) (encode_LEB128 (len encoded)) encoded ))
    ))

    (encode_table_type (lambda (t) (concat (encode_ref_type (idx t 0)) (encode_limits (idx t 1)))))

    (encode_table_section (lambda (x)
        (dlet (
            (encoded (encode_vector encode_table_type x))
        ) (concat (array #x04) (encode_LEB128 (len encoded)) encoded ))
    ))
    (encode_memory_section (lambda (x)
        (dlet (
            (encoded (encode_vector encode_limits x))
        ) (concat (array #x05) (encode_LEB128 (len encoded)) encoded ))
    ))
    (encode_export (lambda (export)
        (dlet (
            ((name type idx) export)
        ) (concat (encode_name name)
                  (cond ((= type 'func)   (array #x00))
                        ((= type 'table)  (array #x01))
                        ((= type 'memory) (array #x02))
                        ((= type 'global) (array #x03))
                        (true             (error "bad export type")))
                  (encode_LEB128 idx)
        ))
    ))
    (encode_export_section (lambda (x)
        (dlet (
            ;(_ (print "encoding element " x))
            (encoded (encode_vector encode_export x))
            ;(_ (print "donex"))
        ) (concat (array #x07) (encode_LEB128 (len encoded)) encoded ))
    ))

    (encode_start_section (lambda (x)
        (cond ((= 0 (len x)) (array))
              ((= 1 (len x)) (dlet ((encoded (encode_LEB128 (idx x 0)))) (concat (array #x08) (encode_LEB128 (len encoded)) encoded )))
              (true          (error (str "bad lenbgth for start section " (len x) " was " x))))
    ))

    (encode_function_section (lambda (x)
        (dlet (                                     ; nil functions are placeholders for improted functions
            ;(_ (true_print "encoding function section " x))
            (filtered (filter (lambda (i) (!= nil i)) x))
            ;(_ (true_print "post filtered " filtered))
            (encoded (encode_vector encode_LEB128 filtered))
        ) (concat (array #x03) (encode_LEB128 (len encoded)) encoded ))
    ))
    (encode_blocktype (lambda (type) (cond ((symbol? type)   (encode_valtype type))
                                           ((= (array) type) (array #x40)) ; empty type
                                           (true             (encode_LEB128 type))
                                   )))

    (encode_ins (rec-lambda recurse (ins)
        (dlet (
            ;(_ (true_print "encoding ins " ins))
            (op (idx ins 0))
        ) (cond ((= op 'unreachable)            (array #x00))
                ((= op 'nop)                    (array #x01))
                ((= op 'block)          (concat (array #x02) (encode_blocktype (idx ins 1)) (flat_map recurse (idx ins 2)) (array #x0B)))
                ((= op 'loop)           (concat (array #x03) (encode_blocktype (idx ins 1)) (flat_map recurse (idx ins 2)) (array #x0B)))
                ((= op 'if)             (concat (array #x04) (encode_blocktype (idx ins 1)) (flat_map recurse (idx ins 2)) (if (!= 3 (len ins)) (concat (array #x05) (flat_map recurse (idx ins 3)))
                                                                                                                                          (array ))     (array #x0B)))
                ((= op 'br)             (concat (array #x0C) (encode_LEB128 (idx ins 1))))
                ((= op 'br_if)          (concat (array #x0D) (encode_LEB128 (idx ins 1))))
                ;...
                ((= op 'return)                 (array #x0F))
                ((= op 'call)           (concat (array #x10) (encode_LEB128 (idx ins 1))))
                ((= op 'call_indirect)  (concat (array #x11) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ; skipping a bunch
                ; Parametric Instructions
                ((= op 'drop)                   (array #x1A))
                ; skip
                ; Variable Instructions
                ((= op 'local.get)      (concat (array #x20) (encode_LEB128 (idx ins 1))))
                ((= op 'local.set)      (concat (array #x21) (encode_LEB128 (idx ins 1))))
                ((= op 'local.tee)      (concat (array #x22) (encode_LEB128 (idx ins 1))))
                ((= op 'global.get)     (concat (array #x23) (encode_LEB128 (idx ins 1))))
                ((= op 'global.set)     (concat (array #x24) (encode_LEB128 (idx ins 1))))
                ; table
                ; memory
                ((= op 'i32.load)       (concat (array #x28) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i64.load)       (concat (array #x29) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i32.load8_s)    (concat (array #x2C) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i32.load8_u)    (concat (array #x2D) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i32.load16_s)   (concat (array #x2E) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i32.load16_u)   (concat (array #x2F) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i64.load8_s)    (concat (array #x30) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i64.load8_u)    (concat (array #x31) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i64.load16_s)   (concat (array #x32) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i64.load16_u)   (concat (array #x33) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i64.load32_s)   (concat (array #x34) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i64.load32_u)   (concat (array #x35) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i32.store)      (concat (array #x36) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i64.store)      (concat (array #x37) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i32.store8)     (concat (array #x3A) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i32.store16)    (concat (array #x3B) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i64.store8)     (concat (array #x3C) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'i64.store16)    (concat (array #x3D) (encode_LEB128 (idx ins 1)) (encode_LEB128 (idx ins 2))))
                ((= op 'memory.grow)            (array #x40 #x00))
                ; Numeric Instructions
                ((= op 'i32.const)      (concat (array #x41) (encode_LEB128 (idx ins 1))))
                ((= op 'i64.const)      (concat (array #x42) (encode_LEB128 (idx ins 1))))
                ((= op 'i32.eqz)                (array #x45))
                ((= op 'i32.eq)                 (array #x46))
                ((= op 'i32.ne)                 (array #x47))
                ((= op 'i32.lt_s)               (array #x48))
                ((= op 'i32.lt_u)               (array #x49))
                ((= op 'i32.gt_s)               (array #x4A))
                ((= op 'i32.gt_u)               (array #x4B))
                ((= op 'i32.le_s)               (array #x4C))
                ((= op 'i32.le_u)               (array #x4D))
                ((= op 'i32.ge_s)               (array #x4E))
                ((= op 'i32.ge_u)               (array #x4F))

                ((= op 'i64.eqz)                (array #x50))
                ((= op 'i64.eq)                 (array #x51))
                ((= op 'i64.ne)                 (array #x52))
                ((= op 'i64.lt_s)               (array #x53))
                ((= op 'i64.lt_u)               (array #x54))
                ((= op 'i64.gt_s)               (array #x55))
                ((= op 'i64.gt_u)               (array #x56))
                ((= op 'i64.le_s)               (array #x57))
                ((= op 'i64.le_u)               (array #x58))
                ((= op 'i64.ge_s)               (array #x59))
                ((= op 'i64.ge_u)               (array #x5A))

                ((= op 'i32.add)                (array #x6A))
                ((= op 'i32.sub)                (array #x6B))
                ((= op 'i32.mul)                (array #x6C))
                ((= op 'i32.div_s)              (array #x6D))
                ((= op 'i32.div_u)              (array #x6E))
                ((= op 'i32.rem_s)              (array #x6F))
                ((= op 'i32.rem_u)              (array #x70))
                ((= op 'i32.and)                (array #x71))
                ((= op 'i32.or)                 (array #x72))
                ((= op 'i32.shl)                (array #x74))
                ((= op 'i32.shr_s)              (array #x75))
                ((= op 'i32.shr_u)              (array #x76))
                ((= op 'i64.add)                (array #x7C))
                ((= op 'i64.sub)                (array #x7D))
                ((= op 'i64.mul)                (array #x7E))
                ((= op 'i64.div_s)              (array #x7F))
                ((= op 'i64.div_u)              (array #x80))
                ((= op 'i64.rem_s)              (array #x81))
                ((= op 'i64.rem_u)              (array #x82))
                ((= op 'i64.and)                (array #x83))
                ((= op 'i64.or)                 (array #x84))
                ((= op 'i64.xor)                (array #x85))
                ((= op 'i64.shl)                (array #x86))
                ((= op 'i64.shr_s)              (array #x87))
                ((= op 'i64.shr_u)              (array #x88))

                ((= op 'i32.wrap_i64)           (array #xA7))
                ((= op 'i64.extend_i32_s)       (array #xAC))
                ((= op 'i64.extend_i32_u)       (array #xAD))

                ((= op 'memory.copy)            (array #xFC #x0A #x00 #x00))
        ))
    ))

    (encode_expr (lambda (expr) (concat (flat_map encode_ins expr) (array #x0B))))
    (encode_code (lambda (x)
        (dlet (
            ((locals body) x)
            (enc_locals (encode_vector (lambda (loc)
                                    (concat (encode_LEB128 (idx loc 0)) (encode_valtype (idx loc 1)))) locals))
            (enc_expr (encode_expr body))
            (code_bytes (concat enc_locals enc_expr))
        ) (concat (encode_LEB128 (len code_bytes)) code_bytes))
    ))
    (encode_code_section (lambda (x)
        (dlet (
            (encoded (encode_vector encode_code x))
        ) (concat (array #x0A) (encode_LEB128 (len encoded)) encoded ))
    ))

    (encode_global_type (lambda (t) (concat (encode_valtype (idx t 0)) (cond ((= (idx t 1) 'const) (array #x00))
                                                                             ((= (idx t 1) 'mut)   (array #x01))
                                                                             (true                 (error (str "bad mutablity " (idx t 1))))))))
    (encode_global_section (lambda (global_section)
        (dlet (
            ;(_ (print "encoding exprs " global_section))
            (encoded (encode_vector (lambda (x) (concat (encode_global_type (idx x 0)) (encode_expr (idx x 1)))) global_section))
        ) (concat (array #x06) (encode_LEB128 (len encoded)) encoded ))
    ))

    ; only supporting one type of element section for now, active funcrefs with offset
    (encode_element (lambda (x) (concat (array #x00) (encode_expr (idx x 0)) (encode_vector encode_LEB128 (idx x 1)))))
    (encode_element_section (lambda (x)
        (dlet (
            ;(_ (print "encoding element " x))
            (encoded (encode_vector encode_element x))
            ;(_ (print "donex"))
        ) (concat (array #x09) (encode_LEB128 (len encoded)) encoded ))
    ))


    (encode_data (lambda (data) (cond ((= 2 (len data)) (concat (array #x00) (encode_expr (idx data 0)) (encode_bytes (idx data 1))))
                                      ((= 1 (len data)) (concat (array #x01) (encode_bytes (idx data 0))))
                                      ((= 3 (len data)) (concat (array #x02) (encode_LEB128 (idx data 0)) (encode_expr (idx data 1)) (encode_bytes (idx data 2))))
                                      (true             (error (str "bad data" data))))))
    (encode_data_section (lambda (x)
        (dlet (
            (encoded (encode_vector encode_data x))
        ) (concat (array #x0B) (encode_LEB128 (len encoded)) encoded ))
    ))


    (wasm_to_binary (lambda (wasm_code)
        (dlet (
            ((type_section import_section function_section table_section memory_section global_section export_section start_section element_section code_section data_section) wasm_code)
            ;(_ (println "type_section" type_section "import_section" import_section "function_section" function_section "memory_section" memory_section "global_section" global_section "export_section" export_section "start_section" start_section "element_section" element_section "code_section" code_section "data_section" data_section))
            (magic    (array #x00 #x61 #x73 #x6D ))
            (version  (array #x01 #x00 #x00 #x00 ))
            (type     (encode_type_section type_section))
            (import   (encode_import_section import_section))
            (function (encode_function_section function_section))
            (table    (encode_table_section table_section))
            (memory   (encode_memory_section memory_section))
            (global   (encode_global_section global_section))
            (export   (encode_export_section export_section))
            (start    (encode_start_section start_section))
            (elem     (encode_element_section element_section))
            (code     (encode_code_section code_section))
            (data     (encode_data_section data_section))
            ;data_count (dlet (body (encode_LEB128 (len data_section))) (concat (array #x0C) (encode_LEB128 (len body)) body))
            (data_count (array))
        ) (concat magic version type import function table memory global export data_count start elem code data))
    ))

    (module (lambda args (dlet (
        (helper (rec-lambda recurse (entries i name_dict type import function table memory global export start elem code data)
            (if (= i (len entries)) (array  type import function table memory global export start elem code data)
                (dlet (
                    ((n_d t im f ta m g e s elm c d) ((idx entries i) name_dict type import function table memory global export start elem code data))
                 ) (recurse entries (+ i 1) n_d t im f ta m g e s elm c d)))))
    ) (helper (apply concat args) 0 empty_dict (array ) (array ) (array ) (array ) (array ) (array ) (array ) (array ) (array ) (array ) (array )))))

    (table (lambda (idx_name . limits_type) (array (lambda (name_dict type import function table memory global export start elem code data)
        (array (put name_dict idx_name (len table)) type import function (concat table (array (array (idx limits_type -1) (slice limits_type 0 -2) ))) memory global export start elem code data )))))

    (memory (lambda (idx_name . limits) (array (lambda (name_dict type import function table memory global export start elem code data)
        (array (put name_dict idx_name (len memory)) type import function table (concat memory (array limits)) global export start elem code data )))))

    (func (lambda (name . inside) (array (lambda (name_dict type import function table memory global export start elem code data)
        (dlet (
            ;(_ (print "ok, doing a func: " name " with inside " inside))
            ((params result locals body) ((rec-lambda recurse (i pe re)
                                            (cond ((and (= false pe) (< i (len inside)) (array? (idx inside i)) (< 0 (len (idx inside i))) (= 'param (idx (idx inside i) 0)))
                                                             (recurse (+ i 1) pe re))
                                                  ((and (= false pe) (= false re) (< i (len inside)) (array? (idx inside i)) (< 0 (len (idx inside i))) (= 'result (idx (idx inside i) 0)))
                                                            ; only one result possible
                                                             (recurse (+ i 1) i (+ i 1)))
                                                  ((and (= false re) (< i (len inside)) (array? (idx inside i)) (< 0 (len (idx inside i))) (= 'result (idx (idx inside i) 0)))
                                                            ; only one result possible
                                                             (recurse (+ i 1) pe (+ i 1)))
                                                  ((and              (< i (len inside)) (array? (idx inside i)) (< 0 (len (idx inside i))) (= 'local (idx (idx inside i) 0)))
                                                             (recurse (+ i 1) (or pe i) (or re i)))
                                                  (true      (array (slice inside 0 (or pe i)) (slice inside (or pe i) (or re pe i)) (slice inside (or re pe i) i) (slice inside i -1)))
                                            )
                                        ) 0 false false))
            (result (if (!= 0 (len result)) (array (idx (idx result 0) 1))
                                           result))
            ;(_ (println "params " params " result " result " locals " locals " body " body))
            (outer_name_dict (put name_dict name (len function)))
            ((num_params inner_name_dict) (foldl (lambda (a x) (array (+ (idx a 0) 1) (put (idx a 1) (idx x 1) (idx a 0)))) (array 0 outer_name_dict ) params))
            ((num_locals inner_name_dict) (foldl (lambda (a x) (array (+ (idx a 0) 1) (put (idx a 1) (idx x 1) (idx a 0)))) (array num_params inner_name_dict ) locals))
            ;(_ (println "inner name dict" inner_name_dict))
            (compressed_locals ((rec-lambda recurse (cur_list cur_typ cur_num i)
                (cond ((and (= i (len locals)) (= 0 cur_num)) cur_list)
                           ((= i (len locals))                (concat cur_list (array (array cur_num cur_typ) )))
                      ((= cur_typ (idx (idx locals i) 2))     (recurse cur_list                              cur_typ                (+ 1 cur_num) (+ 1 i)))
                      ((= nil cur_typ)                        (recurse cur_list                              (idx (idx locals i) 2) 1             (+ 1 i)))
                      (true                                   (recurse (concat cur_list (array (array cur_num cur_typ))) (idx (idx locals i) 2) 1             (+ 1 i))))
               ) (array) nil 0 0))
            ;(_ (println "params: " params " result: " result))
            (our_type (array (map (lambda (x) (idx x 2)) params) result))
            ;(inner_env (add-dict-to-env de (put inner_name_dict 'depth 0)))
            (inner_name_dict_with_depth (put inner_name_dict 'depth 0))
            ;(_ (println "about to get our_code: " body))
            (our_code (flat_map (lambda (inss) (map (lambda (ins) (ins inner_name_dict_with_depth)) inss))
                                body))
            ;(_ (println "resulting code " our_code))
            (final_code (concat code (array (array compressed_locals our_code ) )))
        ) (array
            outer_name_dict
            ; type
            (concat type (array our_type ))
            ; import
            import
            ; function
            (concat function (array (len function) ))
            ; table
            table
            ; memory
            memory
            ; global
            global
            ; export
            export
            ; start
            start
            ; element
            elem
            ; code
            final_code
            ; data
            data
        ))
    ))))


    ;;;;;;;;;;;;;;;
    ; Instructions
    ;;;;;;;;;;;;;;;
    (unreachable    (lambda ()                                           (array (lambda (name_dict) (array 'unreachable)))))
    (_drop           (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'drop))))))
    (i32.const      (lambda (const)                                      (array (lambda (name_dict) (array 'i32.const const)))))
    (i64.const      (lambda (const)                                      (array (lambda (name_dict) (array 'i64.const const)))))
    (local.get      (lambda (const)                                      (array (lambda (name_dict)     (array 'local.get (if (int? const) const (get-value name_dict const)))))))
    (local.set      (lambda (const . flatten) (concat (apply concat flatten) (array (lambda (name_dict) (array 'local.set (if (int? const) const (get-value name_dict const))))))))
    (local.tee      (lambda (const . flatten) (concat (apply concat flatten) (array (lambda (name_dict) (array 'local.tee (if (int? const) const (get-value name_dict const))))))))
    (global.get     (lambda (const)                                      (array (lambda (name_dict)     (array 'global.get (if (int? const) const (get-value name_dict const)))))))
    (global.set     (lambda (const . flatten) (concat (apply concat flatten) (array (lambda (name_dict) (array 'global.set (if (int? const) const (get-value name_dict const))))))))
    (i32.add        (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.add))))))
    (i32.sub        (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.sub))))))
    (i32.mul        (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.mul))))))
    (i32.div_s      (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.div_s))))))
    (i32.div_u      (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.div_u))))))
    (i32.rem_s      (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.rem_s))))))
    (i32.rem_u      (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.rem_u))))))
    (i32.and        (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.and))))))
    (i32.or         (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.or))))))
    (i64.add        (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.add))))))
    (i64.sub        (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.sub))))))
    (i64.mul        (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.mul))))))
    (i64.div_s      (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.div_s))))))
    (i64.div_u      (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.div_u))))))
    (i64.rem_s      (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.rem_s))))))
    (i64.rem_u      (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.rem_u))))))
    (i64.and        (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.and))))))
    (i64.or         (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.or))))))
    (i64.xor        (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.xor))))))

    (i32.eqz        (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.eqz))))))
    (i32.eq         (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.eq))))))
    (i32.ne         (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.ne))))))
    (i32.lt_s       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.lt_s))))))
    (i32.lt_u       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.lt_u))))))
    (i32.gt_s       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.gt_s))))))
    (i32.gt_u       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.gt_u))))))
    (i32.le_s       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.le_s))))))
    (i32.le_u       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.le_u))))))
    (i32.ge_s       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.ge_s))))))
    (i32.ge_u       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.ge_u))))))
    (i64.eqz        (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.eqz))))))
    (i64.eq         (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.eq))))))
    (i64.ne         (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.ne))))))
    (i64.lt_s       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.lt_s))))))
    (i64.lt_u       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.lt_u))))))
    (i64.gt_s       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.gt_s))))))
    (i64.gt_u       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.gt_u))))))
    (i64.le_s       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.le_s))))))
    (i64.le_u       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.le_u))))))
    (i64.ge_s       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.ge_s))))))
    (i64.ge_u       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.ge_u))))))

    (mem_load   (lambda (op align) (lambda flatten (dlet (
        (explicit_offset (int? (idx flatten 0)))
        (offset       (if explicit_offset (idx flatten 0)      0))
        (flatten_rest (if explicit_offset (slice flatten 1 -1) flatten))
    ) (concat (apply concat flatten_rest) (array (lambda (name_dict) (array op align offset))))))))

    (i32.load       (mem_load 'i32.load 2))
    (i64.load       (mem_load 'i64.load 3))
    (i32.store      (mem_load 'i32.store 2))
    (i64.store      (mem_load 'i64.store 3))
    (i32.store8     (mem_load 'i32.store8 0))
    (i32.store16    (mem_load 'i32.store16 1))
    (i64.store8     (mem_load 'i64.store8 0))
    (i64.store16    (mem_load 'i64.store16 1))

    (i32.load8_s    (mem_load 'i32.load8_s  0))
    (i32.load8_u    (mem_load 'i32.load8_u  0))
    (i32.load16_s   (mem_load 'i32.load16_s 1))
    (i32.load16_u   (mem_load 'i32.load16_u 1))
    (i64.load8_s    (mem_load 'i64.load8_s  0))
    (i64.load8_u    (mem_load 'i64.load8_u  0))
    (i64.load16_s   (mem_load 'i64.load16_s 1))
    (i64.load16_u   (mem_load 'i64.load16_u 1))
    (i64.load32_s   (mem_load 'i64.load32_s 2))
    (i64.load32_u   (mem_load 'i64.load32_u 2))

    (memory.grow    (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'memory.grow))))))
    (i32.shl        (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.shl))))))
    (i32.shr_u      (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.shr_u))))))
    (i64.shl        (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.shl))))))
    (i64.shr_s      (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.shr_s))))))
    (i64.shr_u      (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.shr_u))))))

    (i32.wrap_i64       (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i32.wrap_i64))))))
    (i64.extend_i32_s   (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.extend_i32_s))))))
    (i64.extend_i32_u   (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'i64.extend_i32_u))))))

    (memory.copy    (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'memory.copy))))))

    (block_like_body (lambda (name_dict name inner) (dlet (
                                                    (new_depth (+ 1 (get-value name_dict 'depth)))
                                                    (inner_env (put (put name_dict name new_depth) 'depth new_depth))
                                                ) (flat_map (lambda (inss) (map (lambda (ins) (ins inner_env)) inss)) inner))))


    (block     (lambda (name . inner)                               (array (lambda (name_dict) (array 'block (array) (block_like_body name_dict name inner))))))
    (_loop     (lambda (name . inner)                               (array (lambda (name_dict) (array 'loop  (array) (block_like_body name_dict name inner))))))
    (_if       (lambda (name . inner) (dlet (
                                            ((end_idx else_section) (if (= 'else (idx (idx inner -1) 0))        (array -2            (slice (idx inner -1) 1 -1) )
                                                                                                                (array -1             nil )))
                                            ((end_idx then_section) (if (= 'then (idx (idx inner end_idx) 0))   (array (- end_idx 1) (slice (idx inner end_idx) 1 -1) )
                                                                                                                (array (- end_idx 1) (array (idx inner end_idx) ) )))
                                            ((start_idx result_t)   (if (= 'result (idx (idx inner 0) 0))       (array 1             (idx (idx inner 0) 1))
                                                                                                                (array 0             (array))))
                                            (flattened (apply concat (slice inner start_idx end_idx)))
                                            ;(_ (println "result_t " result_t " flattened " flattened " then_section " then_section " else_section " else_section))
                                           ) (concat flattened      (array (lambda (name_dict) (concat ;(dlet ( (_ (true_print "inner if " name " " inner)) ) (array))
                                                                                                       (array 'if result_t (block_like_body name_dict name then_section))
                                                                                                       (if (!= nil else_section) (array (block_like_body name_dict name else_section))
                                                                                                                                 (array)))))))))

    (then (lambda rest (cons 'then rest)))
    (else (lambda rest (cons 'else rest)))

    (br        (lambda (block) (array (lambda (name_dict) (array 'br (if (int? block) block (- (get-value name_dict 'depth) (get-value name_dict block))))))))
    (br_if     (lambda (block . flatten) (concat (apply concat flatten)  (array (lambda (name_dict) (array 'br_if (if (int? block) block (- (get-value name_dict 'depth) (get-value name_dict block)))))))))
    (call      (lambda (f . flatten)  (concat (apply concat flatten)  (array (lambda (name_dict) (array 'call (if (int? f) f (get-value name_dict f))))))))
    (call_indirect (lambda (type_idx table_idx . flatten)  (concat (apply concat flatten)  (array (lambda (name_dict) (array 'call_indirect type_idx table_idx))))))

    ;;;;;;;;;;;;;;;;;;;
    ; End Instructions
    ;;;;;;;;;;;;;;;;;;;

    (import (lambda (mod_name name t_idx_typ) (array (lambda (name_dict type import function table memory global export start elem code data) (dlet (
            (_ (if (!= 'func (idx t_idx_typ 0)) (error "only supporting importing functions rn")))
            ((import_type idx_name param_type result_type) t_idx_typ)
            (actual_type_idx (len type))
            (actual_type (array (slice param_type 1 -1) (slice result_type 1 -1) ))
        )
        (array (put name_dict idx_name (len function)) (concat type (array actual_type)) (concat import (array (array mod_name name import_type actual_type_idx) )) (concat function (array nil)) table memory global export start elem code data ))
    ))))

    (global (lambda (idx_name global_type expr) (array (lambda (name_dict type import function table memory global export start elem code data)
        (array (put name_dict idx_name (len global))
          type import function table memory
          (concat global (array (array (if (array? global_type) (reverse global_type) (array global_type 'const)) (map (lambda (x) (x empty_dict)) expr) )))
          export start elem code data )
    ))))

    (export (lambda (name t_v) (array (lambda (name_dict type import function table memory global export start elem code data)
        (array name_dict type import function table memory global
               (concat export (array (array name (idx t_v 0) (get-value name_dict (idx t_v 1)) ) ))
               start elem code data )
    ))))

    (start (lambda (name) (array (lambda (name_dict type import function table memory global export start elem code data)
        (array name_dict type import function table memory global export (concat start (array (get-value name_dict name))) elem code data )
    ))))

    (elem (lambda (offset . entries) (array (lambda (name_dict type import function table memory global export start elem code data)
        (array name_dict type import function table memory global export start (concat elem (array (array (map (lambda (x) (x empty_dict)) offset) (map (lambda (x) (if (int? x) x (get-value name_dict x))) entries)))) code data )
    ))))

    (data (lambda it (array (lambda (name_dict type import function table memory global export start elem code data)
                       (array name_dict type import function table memory global export start elem code
                              (concat data (array (map (lambda (x) (if (array? x) (map (lambda (y) (y empty_dict)) x) x)) it))))))))


    ; Everything is an i64, and we're on a 32 bit wasm system, so we have a good many bits to play with

    ; The two interesting splits are ref-counted/vs not and changes on eval / vs not
    ; ref counted is much more important

    ; y is constant bit
    ;                                                  - all pointers in identical spots
    ;                                                  - all pointers full 32 bits for easy inlining of
    ;                                                        refcounting ops (with static -8 offset)
    ;                                                  - all sizes in identical spots
    ;                                                  - vals vs not vals split on first bit
    ; Int - should maximize int                 xx0000 (nicely leaves 1000 for BigInt later)
    ;  False                                     00100
    ;  True                                      10100
    ;  <string_ptr32><string_size28>              y010
    ;  <symbol_ptr32><symbol_size28>              0011
    ;  <array__ptr32><array__size28>              y111 - symbols 1 bit diff from array for value checking
    ;  <env____ptr32>|<func_idx26><usesde1><wrap1>y101 - both env-carrying values 1 bit different
    ;  <env____ptr32><28 0s>                      y001

    ; NOTE / TODO:
    ;   reduce sizes to 16 bits w/ saturation & include true size field/calculation in object header
    ;   to allow for 44 bit pointers for wasm64 (48 that could be used + minimum alignment of 16)
    ;   Biggest loser is func_idx which would become 14 bits, but can perhaps borrow from env pointer if we further align envs
    ;     currently aligning to 32 bytes, which is 8 word boundries or 4 kraken values (which I think is exactly what env requires, actually) 
    ;     which allows pretty long strings or envs or arrays with 3 values
    ;     so that's 5 unused bits, to actually only require 43 bit pointers right now, I think
    ;     Honestly, going to 40 bits is 1024GB of RAM, -5 is 35 bits. If we allow a non-standard encoding for env-funcs, then
    ;     it leaves 23 bits for a function id, which is 8_388_608 possible functions, which isn't really terrible.
    ;     We could do this only for env-funcs, or actually for anything depending on the extra slow down vs the extra non-saturating size
    ;     Note that this does add an extra mask instruction for *everything* since the pointers aren't full width anymore

    (to_hex_digit (lambda (x) (string (integer->char (if (< x 10) (+ x #x30)
                                                                  (+ x #x37))))))
    (le_hexify_helper (rec-lambda recurse (x i) (if (= i 0) ""
                                                                  (concat "\\" (to_hex_digit (remainder (quotient x 16) 16))
                                                                               (to_hex_digit (remainder x 16))
                                                                               (recurse (quotient x 256) (- i 1))))))
    (i64_le_hexify (lambda (x) (le_hexify_helper (bitwise-and x #xFFFFFFFFFFFFFFFF) 8)))
    (i32_le_hexify (lambda (x) (le_hexify_helper (bitwise-and x #xFFFFFFFF) 4)))

    (type_mask      #b111)
    (rc_mask       #b1000)
    (wrap_mask    #b10000)

    (int_tag        #b000)
    (bool_tag       #b100)
    (string_tag     #b010)
    (symbol_tag     #b011)
    (array_tag      #b111)
    (env_tag        #b001)
    (comb_tag       #b101)

    (int_mask         -16)

    ; catching only 0array and false
    ; -12 is #b1111...110100
    ; the 0 for y means don't care about rc
    ; the 100 means env, array, or bool
    ; and the rest 0 can only mean null env (not possible), nil, or false
    (truthy_test (lambda (x) (i64.ne (i64.const #b100) (i64.and x (i64.const -12)))))
    (falsey_test (lambda (x) (i64.eq (i64.const #b100) (i64.and x (i64.const -12)))))

    (value_test  (lambda (x) (i64.ne (i64.const #b011) (i64.and x (i64.const #b011)))))

    (mk_int_value     (lambda (x)                        (<< x   4)))
    (mk_symbol_value  (lambda (ptr len) (bor (<< ptr 32) (<< len 4) symbol_tag)))
    (mk_string_value  (lambda (ptr len) (bor (<< ptr 32) (<< len 4) string_tag)))
    (mk_env_value     (lambda (ptr)     (bor (<< ptr 32)            env_tag)))

    (mk_int_code_i64  (lambda (x)                        (i64.shl x  (i64.const 4))))
    (mk_int_code_i32u (lambda (x)                        (i64.shl (i64.extend_i32_u x)  (i64.const 4))))
    (mk_int_code_i32s (lambda (x)                        (i64.shl (i64.extend_i32_s x)  (i64.const 4))))

    (mk_env_code_rc   (lambda (ptr) (i64.or (i64.shl (i64.extend_i32_u ptr) (i64.const 32))
                                            (i64.const (bor rc_mask env_tag)))))
    (mk_array_value   (lambda (len ptr) (bor (<< ptr 32) (<< len 4) array_tag)))
    (mk_array_code_rc_const_len (lambda (len ptr) (i64.or (i64.shl (i64.extend_i32_u ptr) (i64.const 32))
                                                          (i64.const (bor (<< len 4) rc_mask array_tag)))))
    (mk_array_code_rc (lambda (len ptr) (i64.or (i64.or (i64.shl (i64.extend_i32_u ptr) (i64.const 32))
                                                        (i64.const (bor rc_mask array_tag)))
                                                (i64.shl (i64.extend_i32_u len) (i64.const 4)))))
    (mk_string_code_rc (lambda (len ptr) (i64.or (i64.or (i64.shl (i64.extend_i32_u ptr) (i64.const 32))
                                                        (i64.const (bor rc_mask string_tag)))
                                                (i64.shl (i64.extend_i32_u len) (i64.const 4)))))
    (toggle_sym_str_code      (lambda (x)     (i64.xor (i64.const #b001) x)))
    (toggle_sym_str_code_norc (lambda (x)     (i64.and (i64.const -9) (i64.xor (i64.const #b001) x))))

    (mk_comb_val_nil_env   (lambda (fidx uses_de wrap) (bor (<< fidx 6) (<< uses_de 5) (<< wrap 4) comb_tag)))
    (mk_comb_val_code_rc_wrap0 (lambda (fidx env uses_de)
                             (i64.or (i64.and env (i64.const -8))
                                     (i64.or (i64.const (<< fidx 6))
                                             (_if '$using_d_env '(result i64)
                                                  uses_de
                                                  (then (i64.const (bor #b100000 comb_tag)))
                                                  (else (i64.const (bor #b000000 comb_tag))))))))
    (combine_env_comb_val            (lambda (env_val  func_val) (bor (band -8 env_val) func_val)))
    (combine_env_code_comb_val_code  (lambda (env_code func_val) (i64.or (i64.and env_code (i64.const -8)) (i64.const func_val))))

    (mod_fval_to_wrap (lambda (it) (cond ((= nil it)                                                      it)
                                         ((and (= (band it type_mask) comb_tag) (= #b0 (band (>> it 6) #b1))) (- it (<< 1 6)))
                                         (true                                                            it))))
    (extract_unwrapped     (lambda (x) (= #b0 (band #b1       (>> x 6)))))
    (extract_func_idx      (lambda (x)        (band #x3FFFFFF (>> x 6))))
    (extract_func_wrap     (lambda (x)        (band #b1       (>> x 4))))
    (extract_func_usesde   (lambda (x) (= #b1 (band #b1       (>> x 5)))))


    (set_wrap_val          (lambda (level func) (bor (<< level 4) (band func -17))))

    (extract_func_idx_code (lambda (x)      (i32.and (i32.const #x3FFFFFF) (i32.wrap_i64 (i64.shr_u x (i64.const 6))))))
                                                                                          ; mask away all but
                                                                                          ; env ptr and rc-bit
    (extract_func_env      (lambda (x)      (bor               env_tag  (band               (- #xFFFFFFF8)  x))))
    (extract_func_env_code (lambda (x)      (i64.or (i64.const env_tag) (i64.and (i64.const (- #xFFFFFFF8)) x))))
    (extract_wrap_code     (lambda (x)      (i64.and (i64.const #b1) (i64.shr_u x (i64.const 4)))))
    (set_wrap_code   (lambda (level func) (i64.or (i64.shl level (i64.const 4)) (i64.and func  (i64.const -17)))))
    (is_wrap_code    (lambda (level func) (i64.eq (i64.const (<< level 4)) (i64.and func (i64.const #b10000)))))
    (needes_de_code  (lambda (func)       (i64.ne (i64.const 0) (i64.and func (i64.const #b100000)))))
    (extract_usede_code        (lambda (x)      (i32.and (i32.const #b1) (i32.wrap_i64 (i64.shr_u x (i64.const 5))))))
    (extract_int_code          (lambda (x)     (i64.shr_s x (i64.const 4))))
    (extract_int_code_i32      (lambda (x)     (i32.wrap_i64 (extract_int_code x))))
    (extract_ptr_code          (lambda (bytes) (i32.wrap_i64 (i64.shr_u bytes (i64.const 32)))))
    (extract_size_code         (lambda (bytes) (i32.wrap_i64 (i64.and (i64.const  #xFFFFFFF) (i64.shr_u bytes (i64.const 4))))))
    (extract_size_code_to_int  (lambda (bytes)               (i64.and (i64.const #xFFFFFFF0) bytes)))


    (is_type_code (lambda (tag x) (i64.eq (i64.const tag) (i64.and (i64.const type_mask) x))))
    (is_not_type_code (lambda (tag x) (i64.ne (i64.const tag) (i64.and (i64.const type_mask) x))))
    (is_str_or_sym_code (lambda (x) (i64.eq (i64.const #b010) (i64.and (i64.const #b110) x))))

    (true_val          #b00010100)
    (false_val         #b00000100)
    (empty_parse_value #b00100100)
    (close_peren_value #b01000100)
    (error_parse_value #b01100100)
    (nil_val           array_tag) ; automatically 0 ptr, 0 size, 0 ref-counted
    (emptystr_val      string_tag); ^ ditto

    (compile (dlambda ((pectx partial_eval_err marked_code) dont_partial_eval
                                                            dont_lazy_env
                                                            dont_y_comb
                                                            dont_prim_inline
                                                            dont_closure_inline)
      (mif partial_eval_err (error partial_eval_err) (wasm_to_binary (module
          (import "wasi_unstable" "args_sizes_get"
                  '(func $args_sizes_get (param i32 i32)
                                  (result i32)))
          (import "wasi_unstable" "args_get"
                  '(func $args_get (param i32 i32)
                                  (result i32)))
          (import "wasi_unstable" "path_open"
                  '(func $path_open  (param i32 i32 i32 i32 i32 i64 i64 i32 i32)
                                     (result i32)))
          (import "wasi_unstable" "fd_read"
                  '(func $fd_read  (param i32 i32 i32 i32)
                                   (result i32)))
          (import "wasi_unstable" "fd_write"
                  '(func $fd_write (param i32 i32 i32 i32)
                                   (result i32)))
          (global '$malloc_head  '(mut i32) (i32.const 0))
          (global '$phs          '(mut i32) (i32.const 0))
          (global '$phl          '(mut i32) (i32.const 0))

          (global '$stack_trace  '(mut i64) (i64.const nil_val))
          (global '$debug_depth  '(mut i32) (i32.const -1))
          (global '$debug_func_to_call   '(mut i64) (i64.const nil_val))
          (global '$debug_params_to_call '(mut i64) (i64.const nil_val))
          (global '$debug_env_to_call    '(mut i64) (i64.const nil_val))

          (global '$num_mallocs  '(mut i32) (i32.const 0))
          (global '$num_sbrks    '(mut i32) (i32.const 0))
          (global '$num_frees    '(mut i32) (i32.const 0))

          (global '$num_evals             '(mut i32) (i32.const 0))
          (global '$num_all_evals             '(mut i32) (i32.const 0))
          (global '$num_interp_dzero    '(mut i32) (i32.const 0))
          (global '$num_interp_done     '(mut i32) (i32.const 0))
          (global '$num_compiled_dzero    '(mut i32) (i32.const 0))
          (global '$num_compiled_done     '(mut i32) (i32.const 0))

          (global '$num_array_innerdrops    '(mut i32) (i32.const 0))
          (global '$num_env_innerdrops    '(mut i32) (i32.const 0))
          (global '$num_array_subdrops    '(mut i32) (i32.const 0))
          (global '$num_array_maxsubdrops    '(mut i32) (i32.const 0))

          (global '$num_interned_symbols    '(mut i32) (i32.const 0))

          (dlet (
              (_ (true_print "beginning of dlet"))
              (alloc_data (dlambda (d (watermark datas)) (cond ((str? d)      (dlet ((size (+ 8 (band (len d) -8))))
                                                                                   (array (+ watermark 8)
                                                                                          (len d)
                                                                                          (array (+ watermark 8 size)
                                                                                                 (concat datas
                                                                                                         (data (i32.const watermark)
                                                                                                               (concat (i32_le_hexify size) "\\00\\00\\00\\80" d)))))))
                                                               (true          (error (str "can't alloc_data for anything else besides strings yet" d)))
                                                         )
              ))
              (memo empty_dict)
              ; We won't use 0 because some impls seem to consider that NULL and crash on reading/writing?
              (iov_tmp 8) ; <32bit len><32bit ptr> + <32bit numwitten>
              (datasi (array (+ iov_tmp 16) (array)))

              (compile-symbol-val (lambda (datasi memo sym) (dlet ((marked_sym (marked_symbol nil sym))
                                                                   (maybe_done (get-value-or-false memo marked_sym))
                                                                  ) (if maybe_done (array datasi memo maybe_done)
                                                                          (dlet (((c_loc c_len datasi) (alloc_data (get-text sym) datasi))
                                                                                 (sym_val (mk_symbol_value c_loc c_len))
                                                                                 (memo (put memo marked_sym sym_val)))
                                                                                (array datasi memo sym_val))))))

              (compile-string-val (lambda (datasi memo s) (dlet ((marked_string (marked_val s))
                                                                 (maybe_done (get-value-or-false memo marked_string))
                                                                ) (if maybe_done (array datasi memo maybe_done)
                                                                        (dlet (((c_loc c_len datasi) (alloc_data s datasi))
                                                                               (str_val (mk_string_value c_loc c_len))
                                                                               (memo (put memo marked_string str_val)))
                                                                              (array datasi memo str_val))))))

              ((true_loc true_length datasi) (alloc_data "true" datasi))
              ((false_loc false_length datasi) (alloc_data "false" datasi))

              (_ (true_print "made true/false"))

              ((datasi memo bad_source_code_msg_val) (compile-string-val datasi memo "\nError: bad source code compile hit\n"))
              ((datasi memo bad_params_number_msg_val) (compile-string-val datasi memo "\nError: passed a bad number of parameters\n"))
              ((datasi memo bad_params_type_msg_val) (compile-string-val datasi memo "\nError: passed a bad type of parameters\n"))
              ((datasi memo dropping_msg_val) (compile-string-val datasi memo "dropping "))
              ((datasi memo duping_msg_val) (compile-string-val datasi memo "duping "))
              ((datasi memo error_msg_val) (compile-string-val datasi memo "\nError: "))
              ((datasi memo log_msg_val) (compile-string-val datasi memo "\nLog: "))
              ((datasi memo call_ok_msg_val) (compile-string-val datasi memo "call ok!"))
              ((datasi memo newline_msg_val) (compile-string-val datasi memo "\n"))
              ((datasi memo space_msg_val) (compile-string-val datasi memo " "))
              ((datasi memo remaining_eval_msg_val) (compile-string-val datasi memo "\nError: trying to call remainin eval\n"))
              ((datasi memo hit_upper_in_eval_msg_val) (compile-string-val datasi memo "\nError: hit nil upper env when looking up symbol in remaining eval: "))
              ((datasi memo remaining_vau_msg_val) (compile-string-val datasi memo "\nError: trying to call remainin vau (primitive)\n"))
              ((datasi memo no_true_cond_msg_val) (compile-string-val datasi memo "\nError: runtime cond had no true branch\n"))
              ((datasi memo weird_wrap_msg_val) (compile-string-val datasi memo "\nError: trying to call a combiner with a weird wrap (not 0 or 1)\n"))
              ((datasi memo bad_not_vau_msg_val) (compile-string-val datasi memo "\nError: Trying to call a function (not vau) but the parameters caused a compile error\n"))
              ((datasi memo going_up_msg_val) (compile-string-val datasi memo "going up"))
              ((datasi memo starting_from_msg_val) (compile-string-val datasi memo "starting from "))
              ((datasi memo got_it_msg_val) (compile-string-val datasi memo "got it"))
              ((datasi memo couldnt_parse_1_msg_val) (compile-string-val datasi memo "\nError: Couldn't parse:\n"))
              ((datasi memo couldnt_parse_2_msg_val) (compile-string-val datasi memo "\nAt character:\n"))
              ((datasi memo parse_remaining_msg_val) (compile-string-val datasi memo "\nLeft over after parsing, starting at byte offset:\n"))
              ((datasi memo quote_sym_val) (compile-symbol-val datasi memo 'quote))
              ((datasi memo unquote_sym_val) (compile-symbol-val datasi memo 'unquote))

              ((datasi memo pre_read_val) (compile-string-val datasi memo "\nPreRead\n"))
              ((datasi memo post_read_val) (compile-string-val datasi memo "\nPostRead\n"))
              ((datasi memo pre_parse_val) (compile-string-val datasi memo "\nPreParse\n"))
              ((datasi memo post_parse_val) (compile-string-val datasi memo "\nPostParse\n"))
              ((datasi memo pre_symbol_intern_val) (compile-string-val datasi memo "\npre symbol intern\n"))
              ((datasi memo pre_eval_val) (compile-string-val datasi memo "\npre eval\n"))
              ((datasi memo post_eval_val) (compile-string-val datasi memo "\npost eval\n"))
              ((datasi memo  pre_inner_eval_val) (compile-string-val datasi memo "\n inner pre eval\n"))
              ((datasi memo post_inner_eval_val) (compile-string-val datasi memo "\n inner post eval\n"))
              ((datasi memo pre_write_callback) (compile-string-val datasi memo "\n pre write callback\n"))

              (_ (true_print "made string/symbol-vals"))

              ; 0 is get_argc, 1 is get_args, 2 is path_open, 3 is fd_read, 4 is fd_write
              (num_pre_functions 5)
              ((func_idx funcs) (array num_pre_functions (array)))

              (typecheck (dlambda (idx result_type op type_tag then_branch else_branch)
                (apply _if (concat (array '$matches) result_type
                    (array (op (i64.const type_tag) (i64.and (i64.const type_mask) (i64.load (* 8 idx) (local.get '$ptr)))))
                    then_branch
                    else_branch
                ))
              ))

              (type_assert (rec-lambda type_assert (i type_check name_msg_val)
                (typecheck i (array)
                    i64.ne (if (array? type_check) (idx type_check 0) type_check)
                    (array (then
                        (if (and (array? type_check) (> (len type_check) 1))
                              (type_assert i (slice type_check 1 -1) name_msg_val)
                              (concat
                                    (call '$print (i64.const bad_params_type_msg_val))
                                    (call '$print (i64.const (mk_int_value i)))
                                    (call '$print (i64.const space_msg_val))
                                    (call '$print (i64.const name_msg_val))
                                    (call '$print (i64.const space_msg_val))
                                    (call '$print (i64.load (* 8 i) (local.get '$ptr)))
                                    (unreachable)
                              )
                        )
                    ))
                    nil
                )
              ))

              ;(generate_dup (lambda (it) (call '$dup it)))
              (generate_dup (lambda (it) (concat
                    (_if '$is_rc
                        (i64.ne (i64.const 0) (i64.and (i64.const rc_mask) (local.tee '$rc_bytes it)))
                        (then
                            (local.set '$rc_ptr (i32.sub (extract_ptr_code (local.get '$rc_bytes)) (i32.const 4)))
                            (i32.store (local.get '$rc_ptr) (i32.add (i32.load (local.get '$rc_ptr)) (i32.const 1)))
                        )
                    )
                    (local.get '$rc_bytes)
              )))
              ;(generate_drop (lambda (it) (call '$drop it)))
              (generate_drop (lambda (it) (concat
                    (_if '$is_rc
                        (i64.ne (i64.const 0) (i64.and (i64.const rc_mask) (local.tee '$rc_bytes it)))
                        (then
                            (_if '$zero
                                (i32.eqz (local.tee '$rc_tmp (i32.sub (i32.load (local.tee '$rc_ptr (i32.sub (extract_ptr_code (local.get '$rc_bytes)) (i32.const 4)))) (i32.const 1))))
                                (then
                                    (call '$drop_free (local.get '$rc_bytes))
                                )
                                (else (i32.store (local.get '$rc_ptr) (local.get '$rc_tmp)))
                            )
                        )
                    )
              )))

              (_ (true_print "made typecheck/assert"))

              ; malloc allocates with size and refcount in header
              ((k_malloc func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$malloc '(param $bytes i32) '(result i32) '(local $result i32) '(local $ptr i32) '(local $last i32) '(local $pages i32)
                (global.set '$num_mallocs (i32.add (i32.const 1) (global.get '$num_mallocs)))

                (local.set '$bytes (i32.add (i32.const 8) (local.get '$bytes)))
                ; ROUND AND ALIGN to 8 byte boundries (1 word) NOT ALLOWED - we expect 16 byte boundries, seemingly?
                ; (though it doesn't seem like it from the ptr encoding :/) It crashes if only 8...
                ;(local.set '$bytes (i32.and (i32.const -16) (i32.add (i32.const 15) (local.get '$bytes))))
                ; or heck, to 4 word boundries
                ;(local.set '$bytes (i32.and (i32.const -32) (i32.add (i32.const 31) (local.get '$bytes))))
                ; or 8 word boundries!
                (local.set '$bytes (i32.and (i32.const -64) (i32.add (i32.const 63) (local.get '$bytes))))

                (local.set '$result (i32.const 0))
                (_if '$has_head
                    (i32.ne (i32.const 0) (global.get '$malloc_head))
                    (then
                        (local.set '$ptr (global.get '$malloc_head))
                        (local.set '$last (i32.const 0))
                        (_loop '$l
                            (_if '$fits
                                (i32.ge_u (i32.load 0 (local.get '$ptr)) (local.get '$bytes))
                                (then
                                    (local.set '$result (local.get '$ptr))
                                    (_if '$head
                                        (i32.eq (local.get '$result) (global.get '$malloc_head))
                                        (then
                                            (global.set '$malloc_head (i32.load 4 (global.get '$malloc_head)))
                                        )
                                        (else
                                            (i32.store 4 (local.get '$last) (i32.load 4 (local.get '$result)))
                                        )
                                    )
                                )
                                (else
                                    (local.set '$last (local.get '$ptr))
                                    (local.set '$ptr (i32.load 4 (local.get '$ptr)))
                                    (br_if '$l (i32.ne (i32.const 0) (local.get '$ptr)))
                                )
                            )
                        )
                    )
                )
                (_if '$result_0
                    (i32.eqz (local.get '$result))
                    (then
                        (global.set '$num_sbrks   (i32.add (i32.const 1) (global.get '$num_sbrks)))
                        (local.set '$pages (i32.add (i32.const 1) (i32.shr_u (local.get '$bytes) (i32.const 16))))
                        (local.set '$result (i32.shl (memory.grow (local.get '$pages)) (i32.const 16)))
                        (i32.store 0 (local.get '$result) (i32.shl (local.get '$pages) (i32.const 16)))
                    )
                )
                ; If too big (>= 2x needed), break off a chunk
                (_if '$too_big
                    (i32.ge_u (i32.load 0 (local.get '$result)) (i32.shl (local.get '$bytes) (i32.const 1)))
                    (then
                        (local.set '$ptr (i32.add (local.get '$result) (local.get '$bytes)))
                        (i32.store 0 (local.get '$ptr) (i32.sub (i32.load 0 (local.get '$result)) (local.get '$bytes)))
                        (i32.store 4 (local.get '$ptr) (global.get '$malloc_head))
                        (global.set '$malloc_head (local.get '$ptr))
                        (i32.store 0 (local.get '$result) (local.get '$bytes))
                    )
                )

                (i32.store 4 (local.get '$result) (i32.const 1))
                (i32.add (local.get '$result) (i32.const 8))
              ))))

              (_ (true_print "made malloc"))

              ((k_free func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$free '(param $bytes i32)
                   (local.set '$bytes (i32.sub (local.get '$bytes) (i32.const 8)))
                   (global.set '$num_frees (i32.add (i32.const 1) (global.get '$num_frees)))
                   (_if '$properly_counted
                        (i32.ne (i32.const 1) (i32.load 4 (local.get '$bytes)))
                        (then
                          (unreachable)
                        )
                   )
                   (i32.store 4 (local.get '$bytes) (global.get '$malloc_head))
                   (global.set '$malloc_head (local.get '$bytes))
              ))))

              ((k_get_ptr func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$get_ptr '(param $bytes i64) '(result i32)
                    (_if '$isnt_rc '(result i32)
                         (i64.eqz (i64.and (i64.const rc_mask) (local.get '$bytes)))
                         (then (i32.const 0))
                         (else (extract_ptr_code (local.get '$bytes)))
                     )
              ))))

              ((k_env_alloc func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$env_alloc '(param $keys i64) '(param $vals i64) '(param $upper i64) '(result i64) '(local $tmp i32)
                    (local.set '$tmp (call '$malloc (i32.const (* 8 3))))
                    (i64.store 0  (local.get '$tmp) (local.get '$keys))
                    (i64.store 8  (local.get '$tmp) (local.get '$vals))
                    (i64.store 16 (local.get '$tmp) (local.get '$upper))
                    (mk_env_code_rc (local.get '$tmp))
              ))))

              ((k_array1_alloc func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$array1_alloc '(param $item i64) '(result i64) '(local $tmp i32)
                    (local.set '$tmp (call '$malloc (i32.const 8)))
                    (i64.store 0  (local.get '$tmp) (local.get '$item))
                    (mk_array_code_rc_const_len 1 (local.get '$tmp))
              ))))
              ((k_array2_alloc func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$array2_alloc '(param $a i64) '(param $b i64) '(result i64) '(local $tmp i32)
                    (local.set '$tmp (call '$malloc (i32.const 16)))
                    (i64.store 0  (local.get '$tmp) (local.get '$a))
                    (i64.store 8  (local.get '$tmp) (local.get '$b))
                    (mk_array_code_rc_const_len 2 (local.get '$tmp))
              ))))
              ((k_array3_alloc func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$array3_alloc '(param $a i64) '(param $b i64) '(param $c i64) '(result i64) '(local $tmp i32)
                    (local.set '$tmp (call '$malloc (i32.const 24)))
                    (i64.store  0  (local.get '$tmp) (local.get '$a))
                    (i64.store  8  (local.get '$tmp) (local.get '$b))
                    (i64.store 16  (local.get '$tmp) (local.get '$c))
                    (mk_array_code_rc_const_len 3 (local.get '$tmp))
              ))))
              ((k_array5_alloc func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$array5_alloc '(param $a i64) '(param $b i64) '(param $c i64) '(param $d i64) '(param $e i64) '(result i64) '(local $tmp i32)
                    (local.set '$tmp (call '$malloc (i32.const 40)))
                    (i64.store 0   (local.get '$tmp) (local.get '$a))
                    (i64.store 8   (local.get '$tmp) (local.get '$b))
                    (i64.store 16  (local.get '$tmp) (local.get '$c))
                    (i64.store 24  (local.get '$tmp) (local.get '$d))
                    (i64.store 32  (local.get '$tmp) (local.get '$e))
                    (mk_array_code_rc_const_len 5 (local.get '$tmp))
              ))))

              (_ (true_print "made array allocs"))

              ; Not called with actual objects, not subject to refcounting
              ((k_int_digits func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$int_digits '(param $int i64) '(result i32) '(local $tmp i32)
                    (_if '$is_neg
                        (i64.lt_s (local.get '$int) (i64.const 0))
                        (then
                            (local.set '$int (i64.sub (i64.const 0) (local.get '$int)))
                            (local.set '$tmp (i32.const 2))
                        )
                        (else
                            (local.set '$tmp (i32.const 1))
                        )
                    )
                    (block '$b
                        (_loop '$l
                            (br_if '$b (i64.le_u (local.get '$int) (i64.const 9)))
                            (local.set '$tmp (i32.add (i32.const 1) (local.get '$tmp)))
                            (local.set '$int (i64.div_u (local.get '$int) (i64.const 10)))
                            (br '$l)
                        )
                    )
                    (local.get '$tmp)
              ))))
              ; Utility method, not subject to refcounting
              ((k_str_len func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$str_len '(param $to_str_len i64) '(result i32) '(local $running_len_tmp i32) '(local $i_tmp i32) '(local $x_tmp i32) '(local $y_tmp i32) '(local $ptr_tmp i32) '(local $item i64)
                    (_if '$is_true '(result i32)
                         (i64.eq (i64.const true_val) (local.get '$to_str_len))
                         (then (i32.const true_length))
                         (else
                            (_if '$is_false '(result i32)
                                 (i64.eq (i64.const false_val) (local.get '$to_str_len))
                                 (then (i32.const false_length))
                                 (else
                                    (_if '$is_str_or_symbol '(result i32)
                                         (is_str_or_sym_code (local.get '$to_str_len))
                                         (then (_if '$is_str '(result i32)
                                                 (is_type_code string_tag (local.get '$to_str_len))
                                                 (then (i32.add (i32.const 2) (extract_size_code (local.get '$to_str_len))))
                                                 (else (i32.add (i32.const 1) (extract_size_code (local.get '$to_str_len))))
                                               ))
                                         (else
                                            (_if '$is_array '(result i32)
                                                 (is_type_code array_tag (local.get '$to_str_len))
                                                 (then
                                                    (local.set '$running_len_tmp (i32.const 1))
                                                    (local.set '$i_tmp (extract_size_code (local.get '$to_str_len)))
                                                    (local.set '$x_tmp (extract_ptr_code  (local.get '$to_str_len)))
                                                    (block '$b
                                                        (_loop '$l
                                                            (local.set '$running_len_tmp (i32.add (local.get '$running_len_tmp) (i32.const 1)))
                                                            (br_if '$b (i32.eq (local.get '$i_tmp) (i32.const 0)))
                                                            (local.set '$running_len_tmp (i32.add (local.get '$running_len_tmp) (call '$str_len (i64.load (local.get '$x_tmp)))))
                                                            (local.set '$x_tmp           (i32.add (local.get '$x_tmp)           (i32.const 8)))
                                                            (local.set '$i_tmp           (i32.sub (local.get '$i_tmp)           (i32.const 1)))
                                                            (br '$l)
                                                        )
                                                    )
                                                    (local.get '$running_len_tmp)
                                                 )
                                                 (else
                                                    (_if '$is_env '(result i32)
                                                        (is_type_code env_tag (local.get '$to_str_len))
                                                        (then
                                                            (local.set '$running_len_tmp (i32.const 0))

                                                            ; ptr to env
                                                            (local.set '$ptr_tmp (extract_ptr_code (local.get '$to_str_len)))
                                                            ; ptr to start of array of symbols
                                                            (local.set '$x_tmp (extract_ptr_code (i64.load (local.get '$ptr_tmp))))
                                                            ; ptr to start of array of values
                                                            (local.set '$y_tmp (extract_ptr_code (i64.load 8 (local.get '$ptr_tmp))))
                                                            ; lenght of both arrays, pulled from array encoding of x
                                                            (local.set '$i_tmp (extract_size_code (i64.load (local.get '$ptr_tmp))))

                                                            (block '$b
                                                                (_loop '$l
                                                                    (local.set '$running_len_tmp (i32.add (local.get '$running_len_tmp) (i32.const 2)))
                                                                    ; break if 0 length left
                                                                    (br_if '$b (i32.eq (local.get '$i_tmp) (i32.const 0)))

                                                                    (local.set '$running_len_tmp (i32.add (local.get '$running_len_tmp)
                                                                                                          (call '$str_len (i64.load (local.get '$x_tmp)))))
                                                                    (local.set '$running_len_tmp (i32.add (local.get '$running_len_tmp)
                                                                                                          (call '$str_len (i64.load (local.get '$y_tmp)))))
                                                                    (local.set '$running_len_tmp (i32.add (local.get '$running_len_tmp) (i32.const 2)))

                                                                    (local.set '$x_tmp           (i32.add (local.get '$x_tmp)           (i32.const 8)))
                                                                    (local.set '$y_tmp           (i32.add (local.get '$y_tmp)           (i32.const 8)))
                                                                    (local.set '$i_tmp           (i32.sub (local.get '$i_tmp)           (i32.const 1)))
                                                                    (br '$l)
                                                                )
                                                            )
                                                            ;; deal with upper
                                                            (local.set '$item (i64.load 16 (local.get '$ptr_tmp)))
                                                            (_if '$is_upper_env
                                                                (is_type_code env_tag (local.get '$item))
                                                                (then
                                                                    (local.set '$running_len_tmp (i32.add (local.get '$running_len_tmp) (i32.const 1)))
                                                                    (local.set '$running_len_tmp (i32.add (local.get '$running_len_tmp) (call '$str_len (local.get '$item))))
                                                                )
                                                            )

                                                            (local.get '$running_len_tmp)
                                                        )
                                                        (else
                                                            (_if '$is_comb '(result i32)
                                                                (is_type_code comb_tag (local.get '$to_str_len))
                                                                (then
                                                                    (i32.const 5)
                                                                )
                                                                (else
                                                                    ;; must be int
                                                                    (call '$int_digits (extract_int_code (local.get '$to_str_len)))
                                                                )
                                                            )
                                                        )
                                                    )
                                                 )
                                             )
                                        )
                                    )
                                )
                            )
                        )
                    )
              ))))
              ; Utility method, not subject to refcounting
              ((k_str_helper func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$str_helper '(param $to_str i64) '(param $buf i32) '(result i32) '(local $len_tmp i32) '(local $buf_tmp i32) '(local $ptr_tmp i32) '(local $x_tmp i32) '(local $y_tmp i32) '(local $i_tmp i32) '(local $item i64)
                    (_if '$is_true '(result i32)
                         (i64.eq (i64.const true_val) (local.get '$to_str))
                         (then (memory.copy (local.get '$buf)
                                            (i32.const true_loc)
                                            (i32.const true_length))
                               (i32.const true_length))
                         (else
                            (_if '$is_false '(result i32)
                                 (i64.eq (i64.const false_val) (local.get '$to_str))
                                 (then (memory.copy (local.get '$buf)
                                                    (i32.const false_loc)
                                                    (i32.const false_length))
                                       (i32.const false_length))
                                 (else
                                    (_if '$is_str_or_symbol '(result i32)
                                         (is_str_or_sym_code (local.get '$to_str))
                                         (then (_if '$is_str '(result i32)
                                                 (is_type_code string_tag (local.get '$to_str))
                                                 (then
                                                    (i32.store8 (local.get '$buf) (i32.const #x22))
                                                    (memory.copy (i32.add (i32.const 1) (local.get '$buf))
                                                                 (extract_ptr_code (local.get '$to_str))
                                                                 (local.tee '$len_tmp (extract_size_code (local.get '$to_str))))
                                                    (i32.store8 1 (i32.add (local.get '$buf) (local.get '$len_tmp)) (i32.const #x22))
                                                    (i32.add (i32.const 2) (local.get '$len_tmp))
                                                 )
                                                 (else
                                                    (i32.store8 (local.get '$buf) (i32.const #x27))
                                                    (memory.copy (i32.add (i32.const 1) (local.get '$buf))
                                                                 (extract_ptr_code (local.get '$to_str))
                                                                 (local.tee '$len_tmp (extract_size_code (local.get '$to_str))))
                                                    (i32.add (i32.const 1) (local.get '$len_tmp))
                                                )
                                               ))
                                         (else
                                            (_if '$is_array '(result i32)
                                                 (is_type_code array_tag (local.get '$to_str))
                                                 (then
                                                    (local.set '$len_tmp (i32.const 0))
                                                    (local.set '$i_tmp (extract_size_code (local.get '$to_str)))
                                                    (local.set '$ptr_tmp (extract_ptr_code  (local.get '$to_str)))
                                                    (block '$b
                                                        (_loop '$l
                                                            (i32.store8 (i32.add (local.get '$buf) (local.get '$len_tmp))   (i32.const #x20))
                                                            (local.set '$len_tmp (i32.add (local.get '$len_tmp) (i32.const 1)))
                                                            (br_if '$b (i32.eq (local.get '$i_tmp) (i32.const 0)))
                                                            (local.set '$len_tmp (i32.add (local.get '$len_tmp) (call '$str_helper (i64.load (local.get '$ptr_tmp)) (i32.add (local.get '$buf) (local.get '$len_tmp)))))
                                                            (local.set '$ptr_tmp (i32.add (local.get '$ptr_tmp) (i32.const 8)))
                                                            (local.set '$i_tmp   (i32.sub (local.get '$i_tmp)   (i32.const 1)))
                                                            (br '$l)
                                                        )
                                                    )
                                                    (i32.store8 (local.get '$buf)                                   (i32.const #x28))
                                                    (i32.store8 (i32.add (local.get '$buf) (local.get '$len_tmp))   (i32.const #x29))
                                                    (i32.add (local.get '$len_tmp) (i32.const 1))
                                                 )
                                                 (else
                                                    (_if '$is_env '(result i32)
                                                        (is_type_code env_tag (local.get '$to_str))
                                                        (then
                                                            (local.set '$len_tmp (i32.const 0))

                                                            ; ptr to env
                                                            (local.set '$ptr_tmp (extract_ptr_code (local.get '$to_str)))
                                                            ; ptr to start of array of symbols
                                                            (local.set '$x_tmp (extract_ptr_code (i64.load (local.get '$ptr_tmp))))
                                                            ; ptr to start of array of values
                                                            (local.set '$y_tmp (extract_ptr_code (i64.load 8 (local.get '$ptr_tmp))))
                                                            ; lenght of both arrays, pulled from array encoding of x
                                                            (local.set '$i_tmp (extract_size_code (i64.load (local.get '$ptr_tmp))))

                                                            (block '$b
                                                                (_loop '$l
                                                                    (i32.store8 (i32.add (local.get '$buf) (local.get '$len_tmp)) (i32.const #x20))
                                                                    (local.set '$len_tmp (i32.add (local.get '$len_tmp) (i32.const 1)))
                                                                    ; break if 0 length left
                                                                    (br_if '$b (i32.eq (local.get '$i_tmp) (i32.const 0)))

                                                                    (local.set '$len_tmp (i32.add (local.get '$len_tmp) (call '$str_helper (i64.load (local.get '$x_tmp)) (i32.add (local.get '$buf) (local.get '$len_tmp)))))
                                                                    (i32.store8 (i32.add (local.get '$len_tmp) (local.get '$buf)) (i32.const #x3A))
                                                                    (local.set '$len_tmp (i32.add (local.get '$len_tmp) (i32.const 1)))
                                                                    (i32.store8 (i32.add (local.get '$len_tmp) (local.get '$buf)) (i32.const #x20))
                                                                    (local.set '$len_tmp (i32.add (local.get '$len_tmp) (i32.const 1)))
                                                                    (local.set '$len_tmp (i32.add (local.get '$len_tmp) (call '$str_helper (i64.load (local.get '$y_tmp)) (i32.add (local.get '$buf) (local.get '$len_tmp)))))
                                                                    (i32.store8 (i32.add (local.get '$len_tmp) (local.get '$buf)) (i32.const #x2C))
                                                                    (local.set '$len_tmp (i32.add (local.get '$len_tmp) (i32.const 1)))

                                                                    (local.set '$x_tmp           (i32.add (local.get '$x_tmp)           (i32.const 8)))
                                                                    (local.set '$y_tmp           (i32.add (local.get '$y_tmp)           (i32.const 8)))
                                                                    (local.set '$i_tmp           (i32.sub (local.get '$i_tmp)           (i32.const 1)))
                                                                    (br '$l)
                                                                )
                                                            )
                                                            ;; deal with upper
                                                            (local.set '$item (i64.load 16 (local.get '$ptr_tmp)))
                                                            (_if '$is_upper_env
                                                                (is_type_code env_tag (local.get '$item))
                                                                (then
                                                                    (i32.store8 -2 (i32.add (local.get '$buf) (local.get '$len_tmp)) (i32.const #x20))
                                                                    (i32.store8 -1 (i32.add (local.get '$buf) (local.get '$len_tmp)) (i32.const #x7C))
                                                                    (i32.store8 (i32.add (local.get '$len_tmp) (local.get '$buf)) (i32.const #x20))
                                                                    (local.set '$len_tmp (i32.add (local.get '$len_tmp) (i32.const 1)))
                                                                    (local.set '$len_tmp (i32.add (local.get '$len_tmp) (call '$str_helper (local.get '$item) (i32.add (local.get '$buf) (local.get '$len_tmp)))))
                                                                )
                                                            )
                                                            (i32.store8 (local.get '$buf)                                   (i32.const #x7B))
                                                            (i32.store8 (i32.add (local.get '$buf) (local.get '$len_tmp))   (i32.const #x7D))
                                                            (local.set '$len_tmp (i32.add (local.get '$len_tmp) (i32.const 1)))
                                                            (local.get '$len_tmp)
                                                        )
                                                        (else
                                                            (_if '$is_comb '(result i32)
                                                                (is_type_code comb_tag (local.get '$to_str))
                                                                (then
                                                                    (i32.store (local.get '$buf) (i32.const #x626D6F63))
                                                                    (i32.store8 4 (local.get '$buf)
                                                                                (i32.add (i32.const #x30)
                                                                                         (i32.wrap_i64 (extract_wrap_code (local.get '$to_str)))))
                                                                    (i32.const 5)
                                                                )
                                                                (else
                                                                    ;; must be int
                                                                    (local.set '$to_str (extract_int_code (local.get '$to_str)))
                                                                    (local.set '$len_tmp (call '$int_digits (local.get '$to_str)))
                                                                    (local.set '$buf_tmp (i32.add (local.get '$buf) (local.get '$len_tmp)))

                                                                    (_if '$is_neg
                                                                        (i64.lt_s (local.get '$to_str) (i64.const 0))
                                                                        (then
                                                                            (local.set '$to_str (i64.sub (i64.const 0) (local.get '$to_str)))
                                                                            (i64.store8 (local.get '$buf) (i64.const #x2D))
                                                                        )
                                                                    )

                                                                    (block '$b
                                                                        (_loop '$l
                                                                            (local.set '$buf_tmp (i32.sub (local.get '$buf_tmp) (i32.const 1)))
                                                                            (i64.store8 (local.get '$buf_tmp) (i64.add (i64.const #x30) (i64.rem_u (local.get '$to_str) (i64.const 10))))
                                                                            (local.set '$to_str (i64.div_u (local.get '$to_str) (i64.const 10)))
                                                                            (br_if '$b (i64.eq (local.get '$to_str) (i64.const 0)))
                                                                            (br '$l)
                                                                        )
                                                                    )

                                                                    (local.get '$len_tmp)
                                                                )
                                                            )
                                                        )
                                                    )
                                                )
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
              ))))
              ; Utility method, not subject to refcounting
              ((k_print func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$print '(param $to_print i64) '(local $iov i32) '(local $data_size i32)
                    (local.set '$iov (call '$malloc (i32.add (i32.const 8)
                                                             (local.tee '$data_size (call '$str_len (local.get '$to_print))))))
                    (_drop (call '$str_helper (local.get '$to_print) (i32.add (i32.const 8) (local.get '$iov))))
                    (_if '$is_str (is_type_code string_tag (local.get '$to_print))
                         (then
                             (i32.store   (local.get '$iov) (i32.add (i32.const 9) (local.get '$iov)))       ;; adder of data
                             (i32.store 4 (local.get '$iov) (i32.sub (local.get '$data_size) (i32.const 2))) ;; len of data
                         )
                         (else
                             (i32.store   (local.get '$iov) (i32.add (i32.const 8) (local.get '$iov))) ;; adder of data
                             (i32.store 4 (local.get '$iov) (local.get '$data_size))                   ;; len of data
                         )
                    )
                    (_drop (call '$fd_write
                              (i32.const 1)     ;; file descriptor
                              (local.get '$iov) ;; *iovs
                              (i32.const 1)     ;; iovs_len
                              (local.get '$iov) ;; nwritten
                    ))
                    (call '$free (local.get '$iov))
              ))))
              (_ (true_print "made print"))
              ((k_dup func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$dup '(param $rc_bytes i64) '(result i64) '(local $rc_ptr i32)
                    ;(generate_dup (local.get '$rc_bytes))
                    ;(unreachable)
                    (_if '$is_rc
                        (i64.ne (i64.const 0) (i64.and (i64.const rc_mask) (local.get '$rc_bytes)))
                        (then
                            (local.set '$rc_ptr (i32.sub (extract_ptr_code (local.get '$rc_bytes)) (i32.const 4)))
                            (i32.store (local.get '$rc_ptr) (i32.add (i32.load (local.get '$rc_ptr)) (i32.const 1)))
                        )
                    )
                    (local.get '$rc_bytes)
              ))))
              ; currenty func 16( 18?! ) in profile
              ((k_drop_free func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$drop_free '(param $it i64) '(local $ptr i32) '(local $tmp_ptr i32) '(local $new_val i32) '(local $i i32) '(local $rc_bytes i64) '(local $rc_tmp i32) '(local $rc_ptr i32)
                  (local.set '$ptr (extract_ptr_code (local.get '$it)))
                  (_if '$needs_inner_drop
                      (is_not_type_code string_tag (local.get '$it))
                      (then
                          (_if '$is_array
                              (is_type_code array_tag (local.get '$it))
                              (then
                                  (local.set '$i (extract_size_code (local.get '$it)))

                                  (_if '$new_max
                                      (i32.gt_u (local.get '$i) (global.get '$num_array_maxsubdrops))
                                      (then (global.set '$num_array_maxsubdrops (local.get '$i))))
                                  (global.set '$num_array_subdrops (i32.add (local.get '$i) (global.get '$num_array_subdrops)))

                                  (local.set '$tmp_ptr (local.get '$ptr))
                                  (block '$done
                                      (_loop '$l
                                          (br_if '$done (i32.eqz (local.get '$i)))
                                          (generate_drop (i64.load (local.get '$tmp_ptr)))
                                          (local.set '$tmp_ptr (i32.add (local.get '$tmp_ptr) (i32.const 8)))
                                          (local.set '$i (i32.sub (local.get '$i) (i32.const 1)))
                                          (br '$l)
                                      )
                                  )
                                  (global.set '$num_array_innerdrops (i32.add (i32.const 1) (global.get '$num_array_innerdrops)))
                              )
                              (else
                                  ; is env ptr
                                  (generate_drop (i64.load  0 (local.get '$ptr)))
                                  (generate_drop (i64.load  8 (local.get '$ptr)))
                                  (generate_drop (i64.load 16 (local.get '$ptr)))
                                  (global.set '$num_env_innerdrops (i32.add (i32.const 1) (global.get '$num_env_innerdrops)))
                              )
                          )
                      )
                  )
                  (call '$free (local.get '$ptr))
              ))))

              ; Utility method, but does refcount
              ((k_slice_impl func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$slice_impl '(param $array i64) '(param $s i32) '(param $e i32) '(result i64) '(local $size i32) '(local $new_size i32) '(local $i i32) '(local $ptr i32) '(local $new_ptr i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                    (local.set '$size (extract_size_code (local.get '$array)))
                    (local.set '$ptr  (extract_ptr_code  (local.get '$array)))
                    (_if '$s_lt_0
                        (i32.lt_s (local.get '$s) (i32.const 0))
                        (then
                            (local.set '$s (i32.add (i32.const 1) (i32.add (local.get '$s) (local.get '$size))))
                        )
                    )
                    (_if '$e_lt_0
                        (i32.lt_s (local.get '$e) (i32.const 0))
                        (then
                            (local.set '$e (i32.add (i32.const 1) (i32.add (local.get '$e) (local.get '$size))))
                        )
                    )

                    (_if '$s_lt_0     (i32.lt_s (local.get '$s) (i32.const 0))      (then (unreachable)))
                    (_if '$e_lt_s     (i32.lt_s (local.get '$e) (local.get '$s))    (then (unreachable)))
                    (_if '$e_gt_size  (i32.gt_s (local.get '$e) (local.get '$size)) (then (unreachable)))

                    (local.set '$new_size (i32.sub (local.get '$e) (local.get '$s)))
                    (_if '$new_size_0 '(result i64)
                        (i32.eqz (local.get '$new_size))
                        (then
                            (generate_drop (local.get '$array))
                            (_if '$is_array '(result i64)
                             (is_type_code array_tag (local.get '$array))
                             (then (i64.const nil_val))
                             (else (i64.const emptystr_val)))
                        )
                        (else
                            (_if '$is_array '(result i64)
                             (is_type_code array_tag (local.get '$array))
                             (then
                                  (local.set '$new_ptr  (call '$malloc (i32.shl (local.get '$new_size) (i32.const 3)))) ; malloc(size*8)

                                  (local.set '$i (i32.const 0))
                                  (block '$exit_loop
                                      (_loop '$l
                                          (br_if '$exit_loop (i32.eq (local.get '$i) (local.get '$new_size)))
                                          (i64.store (i32.add (i32.shl (local.get '$i) (i32.const 3)) (local.get '$new_ptr))
                                                     (generate_dup (i64.load (i32.add (i32.shl (i32.add (local.get '$s) (local.get '$i)) (i32.const 3))
                                                                                    (local.get '$ptr))))) ; n[i] = dup(o[i+s])
                                          (local.set '$i (i32.add (i32.const 1) (local.get '$i)))
                                          (br '$l)
                                      )
                                  )
                                  (generate_drop (local.get '$array))
                                  (mk_array_code_rc (local.get '$new_size) (local.get '$new_ptr))
                             )
                             (else
                                  (local.set '$new_ptr  (call '$malloc (local.get '$new_size))) ; malloc(size)
                                  (memory.copy (local.get '$new_ptr)
                                               (i32.add (local.get '$ptr) (local.get '$s))
                                               (local.get '$new_size))

                                  (generate_drop (local.get '$array))
                                  (mk_string_code_rc (local.get '$new_size) (local.get '$new_ptr))
                            )
                        )
                    )
              )))))
              (_ (true_print "made k_slice_impl"))

              ; chose k_slice_impl because it will never be called, so that
              ; no function will have a 0 func index and count as falsy
              (dyn_start (+ 0 k_slice_impl))

              (func_id_dynamic_ofset  (+ (- 0 dyn_start) (- num_pre_functions 1)))

              (set_len_ptr (concat (local.set '$len (extract_size_code (local.get '$p)))
                                   (local.set '$ptr (extract_ptr_code  (local.get '$p)))
              ))
              (ensure_not_op_n_params_set_ptr_len (lambda (op n) (concat set_len_ptr
                                                                (_if '$is_2_params
                                                                    (op (local.get '$len) (i32.const n))
                                                                    (then
                                                                        (call '$print (i64.const bad_params_number_msg_val))
                                                                        (unreachable)
                                                                    )
                                                                )
                                                        )))
              (drop_p_d (concat 
                    (generate_drop (local.get '$p))
                    (generate_drop (local.get '$d))))

              ((datasi memo k_log_msg_val) (compile-string-val datasi memo "k_log"))
              ((k_log           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$log           '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                set_len_ptr
                (call '$print (i64.const log_msg_val))
                (call '$print (local.get '$p))
                (call '$print (i64.const newline_msg_val))
                (_if '$no_params '(result i64)
                        (i32.eqz (local.get '$len))
                        (then
                            (i64.const nil_val)
                        )
                        (else
                            (generate_dup (i64.load (i32.add (local.get '$ptr) (i32.shl (i32.sub (local.get '$len) (i32.const 1)) (i32.const 3)))))
                        )
                )
                drop_p_d
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_error_msg_val) (compile-string-val datasi memo "k_error"))
              ((k_error         func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$error         '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (call '$print (i64.const error_msg_val))
                (call '$print (local.get '$p))
                (call '$print (i64.const newline_msg_val))
                drop_p_d
                (unreachable)
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_str_msg_val) (compile-string-val datasi memo "k_str"))
              ((k_str           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$str           '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $buf i32) '(local $size i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (local.set '$buf (call '$malloc (local.tee '$size (call '$str_len (local.get '$p)))))
                (_drop (call '$str_helper (local.get '$p) (local.get '$buf)))
                drop_p_d
                (mk_string_code_rc (local.get '$size) (local.get '$buf))
              ))))
              (_ (true_print "str is " k_str " which might be " (- k_str dyn_start)))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              (pred_func    (lambda (name type_tag) (func name '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (typecheck 0 (array '(result i64))
                    i64.eq type_tag
                    (array (then (i64.const true_val)))
                    (array (else (i64.const false_val)))
                )
                drop_p_d
              )))
              ((datasi memo k_nil_msg_val) (compile-string-val datasi memo "k_nil"))
              ((k_nil?          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func 'nil? '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (_if '$a_len_lt_b_len '(result i64)
                     (i64.eq (i64.const nil_val) (i64.load (local.get '$ptr)))
                     (then (i64.const true_val))
                     (else (i64.const false_val))
                )
                drop_p_d
              ))))
              (_ (true_print "nil? is " k_nil? " which might be " (- k_nil? dyn_start)))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((k_array?        func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$array?    array_tag))))
              (_ (true_print "array? is " k_array? " which might be " (- k_array? dyn_start)))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_bool_msg_val) (compile-string-val datasi memo "k_bool"))
              ((k_bool?         func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$bool?     bool_tag))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_env_msg_val) (compile-string-val datasi memo "k_env"))
              ((k_env?          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$env?      env_tag))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_combiner_msg_val) (compile-string-val datasi memo "k_combiner"))
              ((k_combiner?     func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$combiner  comb_tag))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_string_msg_val) (compile-string-val datasi memo "k_string"))
              ((k_string?       func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$string?   string_tag))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_int_msg_val) (compile-string-val datasi memo "k_int"))
              ((k_int?          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$int?      int_tag))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_symbol_msg_val) (compile-string-val datasi memo "k_symbol"))
              ((k_symbol?       func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$symbol?   symbol_tag))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              (_ (true_print "made k_sybmol?"))

              ((k_str_sym_comp func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$str_sym_comp '(param $a i64) '(param $b i64) '(param $lt_val i64) '(param $eq_val i64) '(param $gt_val i64) '(result i64) '(local $result i64) '(local $a_len i32) '(local $b_len i32) '(local $a_ptr i32) '(local $b_ptr i32)
                (local.set '$result (local.get '$eq_val))
                (local.set '$a_len (extract_size_code (local.get '$a)))
                (local.set '$b_len (extract_size_code (local.get '$b)))
                (local.set '$a_ptr (extract_ptr_code  (local.get '$a)))
                (local.set '$b_ptr (extract_ptr_code  (local.get '$b)))
                (block '$b
                    (_if '$a_len_lt_b_len
                        (i32.lt_s (local.get '$a_len) (local.get '$b_len))
                        (then (local.set '$result (local.get '$lt_val))
                              (br '$b)))
                    (_if '$a_len_gt_b_len
                        (i32.gt_s (local.get '$a_len) (local.get '$b_len))
                        (then (local.set '$result (local.get '$gt_val))
                              (br '$b)))

                    (_loop '$l
                        (br_if '$b (i32.eqz (local.get '$a_len)))

                        (local.set '$a (i64.load8_u (local.get '$a_ptr)))
                        (local.set '$b (i64.load8_u (local.get '$b_ptr)))

                        (_if '$a_lt_b
                            (i64.lt_s (local.get '$a) (local.get '$b))
                            (then (local.set '$result (local.get '$lt_val))
                                  (br '$b)))
                        (_if '$a_gt_b
                            (i64.gt_s (local.get '$a) (local.get '$b))
                            (then (local.set '$result (local.get '$gt_val))
                                  (br '$b)))

                        (local.set '$a_len (i32.sub (local.get '$a_len) (i32.const 1)))
                        (local.set '$a_ptr (i32.add (local.get '$a_ptr) (i32.const 1)))
                        (local.set '$b_ptr (i32.add (local.get '$b_ptr) (i32.const 1)))
                        (br '$l)
                    )
                )
                (local.get '$result)
              ))))
              (_ (true_print "str_sym_comp is " k_str_sym_comp " which might be " (- k_str_sym_comp dyn_start)))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              ((k_comp_helper_helper func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$comp_helper_helper '(param $a i64) '(param $b i64) '(param $lt_val i64) '(param $eq_val i64) '(param $gt_val i64) '(result i64) '(local $result i64) '(local $a_tmp i32) '(local $b_tmp i32) '(local $a_ptr i32) '(local $b_ptr i32) '(local $result_tmp i64)
                (block '$blck
                    ;; INT
                    (_if '$a_int
                        (is_type_code int_tag (local.get '$a))
                        (then
                            (_if '$b_int
                                (is_type_code int_tag (local.get '$b))
                                (then
                                    (_if '$a_lt_b
                                        (i64.lt_s (local.get '$a) (local.get '$b))
                                        (then (local.set '$result (local.get '$lt_val))
                                              (br '$blck)))
                                    (_if '$a_gt_b
                                        (i64.gt_s (local.get '$a) (local.get '$b))
                                        (then (local.set '$result (local.get '$gt_val))
                                              (br '$blck)))
                                    (local.set '$result (local.get '$eq_val))
                                    (br '$blck)
                                )
                            )
                            ; Else, b is not an int, so a < b
                            (local.set '$result (local.get '$lt_val))
                            (br '$blck)
                        )
                    )
                    (_if '$b_int
                        (is_type_code int_tag (local.get '$b))
                        (then
                            (local.set '$result (local.get '$gt_val))
                            (br '$blck))
                    )
                    ;; STRING
                    (_if '$a_string
                        (is_type_code string_tag (local.get '$a))
                        (then
                            (_if '$b_string
                                (is_type_code string_tag (local.get '$b))
                                (then
                                    (local.set '$result (call '$str_sym_comp (local.get '$a) (local.get '$b) (local.get '$lt_val) (local.get '$eq_val) (local.get '$gt_val)))
                                    (br '$blck))
                            )
                            ; else b is not an int or string, so bigger
                            (local.set '$result (local.get '$lt_val))
                            (br '$blck)
                        )
                    )
                    (_if '$b_string
                        (is_type_code string_tag (local.get '$b))
                        (then
                            (local.set '$result (local.get '$gt_val))
                            (br '$blck))
                    )
                    ;; SYMBOL
                    (_if '$a_symbol
                        (is_type_code symbol_tag (local.get '$a))
                        (then
                            (_if '$b_symbol
                                (is_type_code symbol_tag (local.get '$b))
                                (then
                                    ; if we're only doing eq or neq, we can compare interned values
                                    (_if '$eq_based_test
                                        (i64.eq (local.get '$lt_val) (local.get '$gt_val))
                                        (then
                                          (_if '$eq
                                              (i64.eq (local.get '$a) (local.get '$b))
                                              (then
                                                (local.set '$result (local.get '$eq_val))
                                              )
                                              (else
                                                (local.set '$result (local.get '$lt_val))
                                              )
                                          )
                                        )
                                        (else
                                          (local.set '$result (call '$str_sym_comp (local.get '$a) (local.get '$b) (local.get '$lt_val) (local.get '$eq_val) (local.get '$gt_val)))
                                        )
                                    )

                                    (br '$blck))
                            )
                            ; else b is not an int or string or symbol, so bigger
                            (local.set '$result (local.get '$lt_val))
                            (br '$blck)
                        )
                    )
                    (_if '$b_symbol
                        (is_type_code symbol_tag (local.get '$b))
                        (then
                            (local.set '$result (local.get '$gt_val))
                            (br '$blck))
                    )
                    ;; ARRAY
                    (_if '$a_array
                        (is_type_code array_tag (local.get '$a))
                        (then
                            (_if '$b_array
                                (is_type_code array_tag (local.get '$b))
                                (then
                                    (local.set '$result (local.get '$eq_val))
                                    (local.set '$a_tmp (extract_size_code (local.get '$a)))
                                    (local.set '$b_tmp (extract_size_code (local.get '$b)))

                                    (_if '$a_len_lt_b_len
                                        (i32.lt_s (local.get '$a_tmp) (local.get '$b_tmp))
                                        (then (local.set '$result (local.get '$lt_val))
                                              (br '$blck)))
                                    (_if '$a_len_gt_b_len
                                        (i32.gt_s (local.get '$a_tmp) (local.get '$b_tmp))
                                        (then (local.set '$result (local.get '$gt_val))
                                              (br '$blck)))

                                    (local.set '$a_ptr (extract_ptr_code (local.get '$a)))
                                    (local.set '$b_ptr (extract_ptr_code (local.get '$b)))

                                    (_loop '$l
                                        (br_if '$b (i32.eqz (local.get '$a_tmp)))

                                        (local.set '$result_tmp (call '$comp_helper_helper (i64.load (local.get '$a_ptr))
                                                                                           (i64.load (local.get '$b_ptr))
                                                                                           (i64.const -1) (i64.const 0) (i64.const 1)))

                                        (_if '$a_lt_b
                                            (i64.eq (local.get '$result_tmp) (i64.const -1))
                                            (then (local.set '$result (local.get '$lt_val))
                                                  (br '$blck)))
                                        (_if '$a_gt_b
                                            (i64.eq (local.get '$result_tmp) (i64.const 1))
                                            (then (local.set '$result (local.get '$gt_val))
                                                  (br '$blck)))

                                        (local.set '$a_tmp (i32.sub (local.get '$a_tmp) (i32.const 1)))
                                        (local.set '$a_ptr (i32.add (local.get '$a_ptr) (i32.const 8)))
                                        (local.set '$b_ptr (i32.add (local.get '$b_ptr) (i32.const 8)))
                                        (br '$l)
                                    ))
                            )
                            ; else b is not an int or string or symbol or array, so bigger
                            (local.set '$result (local.get '$lt_val))
                            (br '$blck)
                        )
                    )
                    (_if '$b_array
                        (is_type_code array_tag (local.get '$b))
                        (then
                            (local.set '$result (local.get '$gt_val))
                            (br '$blck))
                    )
                    ;; COMBINER
                    (_if '$a_comb
                        (is_type_code comb_tag (local.get '$a))
                        (then
                            (_if '$b_comb
                                (is_type_code comb_tag (local.get '$b))
                                (then
                                    ; compare func indicies first
                                    (local.set '$a_tmp (extract_func_idx_code (local.get '$a)))
                                    (local.set '$b_tmp (extract_func_idx_code (local.get '$b)))
                                    (_if '$a_tmp_lt_b_tmp
                                        (i32.lt_s (local.get '$a_tmp) (local.get '$b_tmp))
                                        (then
                                            (local.set '$result (local.get '$lt_val))
                                            (br '$blck))
                                    )
                                    (_if '$a_tmp_eq_b_tmp
                                        (i32.gt_s (local.get '$a_tmp) (local.get '$b_tmp))
                                        (then
                                            (local.set '$result (local.get '$gt_val))
                                            (br '$blck))
                                    )
                                    ; Idx was the same, so recursively comp envs
                                    (local.set '$result (call '$comp_helper_helper (extract_func_env_code (local.get '$a))
                                                                                   (extract_func_env_code (local.get '$b))
                                                                                   (local.get '$lt_val) (local.get '$eq_val) (local.get '$gt_val)))
                                    (br '$blck))
                            )
                            ; else b is not an int or string or symbol or array or combiner, so bigger
                            (local.set '$result (local.get '$lt_val))
                            (br '$blck)
                        )
                    )
                    (_if '$b_comb
                        (is_type_code comb_tag (local.get '$b))
                        (then
                            (local.set '$result (local.get '$gt_val))
                            (br '$blck))
                    )
                    ;; ENV
                    (_if '$a_env
                        (is_type_code env_tag (local.get '$a))
                        (then
                            (_if '$b_comb
                                (is_type_code env_tag (local.get '$b))
                                (then
                                    (local.set '$a_ptr (extract_ptr_code (local.get '$a)))
                                    (local.set '$b_ptr (extract_ptr_code (local.get '$b)))

                                    ; First, compare their symbol arrays
                                    (local.set '$result_tmp (call '$comp_helper_helper (i64.load 0 (local.get '$a_ptr))
                                                                                       (i64.load 0 (local.get '$b_ptr))
                                                                                       (i64.const -1) (i64.const 0) (i64.const 1)))
                                    (_if '$a_lt_b
                                        (i64.eq (local.get '$result_tmp) (i64.const -1))
                                        (then (local.set '$result (local.get '$lt_val))
                                              (br '$blck)))
                                    (_if '$a_gt_b
                                        (i64.eq (local.get '$result_tmp) (i64.const 1))
                                        (then (local.set '$result (local.get '$gt_val))
                                              (br '$blck)))

                                    ; Second, compare their value arrays
                                    (local.set '$result_tmp (call '$comp_helper_helper (i64.load 8 (local.get '$a_ptr))
                                                                                       (i64.load 8 (local.get '$b_ptr))
                                                                                       (i64.const -1) (i64.const 0) (i64.const 1)))
                                    (_if '$a_lt_b
                                        (i64.eq (local.get '$result_tmp) (i64.const -1))
                                        (then (local.set '$result (local.get '$lt_val))
                                              (br '$blck)))
                                    (_if '$a_gt_b
                                        (i64.eq (local.get '$result_tmp) (i64.const 1))
                                        (then (local.set '$result (local.get '$gt_val))
                                              (br '$blck)))

                                    ; Finally, just accept the result of recursion
                                    (local.set '$result (call '$comp_helper_helper (i64.load 16 (local.get '$a_ptr))
                                                                                   (i64.load 16 (local.get '$b_ptr))
                                                                                   (local.get '$lt_val) (local.get '$eq_val) (local.get '$gt_val)))

                                    (br '$blck))
                            )
                            ; else b is bool, so bigger
                            (local.set '$result (local.get '$lt_val))
                            (br '$blck)
                        )
                    )
                    (_if '$b_env
                        (is_type_code env_tag (local.get '$b))
                        (then
                            (local.set '$result (local.get '$gt_val))
                            (br '$blck))
                    )
                    ;; BOOL hehe
                    (_if '$a_lt_b
                        (i64.lt_s (local.get '$a) (local.get '$b))
                        (then
                            (local.set '$result (local.get '$lt_val))
                            (br '$blck))
                    )
                    (_if '$a_eq_b
                        (i64.eq (local.get '$a) (local.get '$b))
                        (then
                            (local.set '$result (local.get '$eq_val))
                            (br '$blck))
                    )
                    (local.set '$result (local.get '$gt_val))
                    (br '$blck)
                )
                (local.get '$result)
              ))))
              (_ (true_print "comp_helper_helper is " k_comp_helper_helper " which might be " (- k_comp_helper_helper dyn_start)))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              ((k_comp_helper   func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$comp_helper '(param $p i64) '(param $d i64) '(param $s i64) '(param $lt_val i64) '(param $eq_val i64) '(param $gt_val i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $result i64) '(local $a i64) '(local $b i64) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                set_len_ptr
                (local.set '$result (i64.const true_val))
                (block '$done_block
                    (_loop '$loop
                        (br_if '$done_block (i32.le_u (local.get '$len) (i32.const 1)))
                        (local.set '$a (i64.load (local.get '$ptr)))
                        (local.set '$ptr (i32.add (local.get '$ptr) (i32.const 8)))
                        (local.set '$b (i64.load (local.get '$ptr)))
                        (_if '$was_false
                            (i64.eq (i64.const false_val) (call '$comp_helper_helper (local.get '$a) (local.get '$b) (local.get '$lt_val) (local.get '$eq_val) (local.get '$gt_val)))
                            (then
                                (local.set '$result (i64.const false_val))
                                (br '$done_block)
                            )
                        )
                        (local.set '$len (i32.sub (local.get '$len) (i32.const 1)))
                        (br '$loop)
                    )
                )
                (local.get '$result)
                drop_p_d
              ))))
              (_ (true_print "comp_helper is " k_comp_helper " which might be " (- k_comp_helper dyn_start)))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              (_ (true_print "made k_comp_hlper"))

              ((datasi memo k_eq_msg_val) (compile-string-val datasi memo "k_eq"))
              ((k_eq            func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$eq  '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$comp_helper (local.get '$p) (local.get '$d) (local.get '$s) (i64.const false_val)  (i64.const true_val)  (i64.const false_val))
              ))))
              (_ (true_print "= is " k_eq " which might be " (- k_eq dyn_start)))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_neq_msg_val) (compile-string-val datasi memo "k_neq"))
              ((k_neq           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$neq '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$comp_helper (local.get '$p) (local.get '$d) (local.get '$s) (i64.const true_val)   (i64.const false_val) (i64.const true_val))
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_geq_msg_val) (compile-string-val datasi memo "k_geq"))
              ((k_geq           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$geq '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$comp_helper (local.get '$p) (local.get '$d) (local.get '$s) (i64.const false_val)  (i64.const true_val)  (i64.const true_val))
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_gt_msg_val) (compile-string-val datasi memo "k_gt"))
              ((k_gt            func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$gt  '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$comp_helper (local.get '$p) (local.get '$d) (local.get '$s) (i64.const false_val)  (i64.const false_val) (i64.const true_val))
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_leq_msg_val) (compile-string-val datasi memo "k_leq"))
              ((k_leq           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$leq '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$comp_helper (local.get '$p) (local.get '$d) (local.get '$s) (i64.const true_val)   (i64.const true_val)  (i64.const false_val))
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_lt_msg_val) (compile-string-val datasi memo "k_lt"))
              ((k_lt            func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$lt  '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$comp_helper (local.get '$p) (local.get '$d) (local.get '$s) (i64.const true_val)   (i64.const false_val) (i64.const false_val))
              ))))
              (_ (true_print "< is " k_lt " which might be " (- k_lt dyn_start)))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              (math_function (lambda (name sensitive op)
                (func name           '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $i i32) '(local $cur i64) '(local $next i64) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                    (ensure_not_op_n_params_set_ptr_len i32.eq 0)
                    (local.set '$i   (i32.const 1))
                    (local.set '$cur (i64.load (local.get '$ptr)))
                    (_if '$not_num
                         (is_not_type_code int_tag (local.get '$cur))
                        (then (unreachable))
                    )
                    (block '$b
                        (_loop '$l
                            (br_if '$b (i32.eq (local.get '$len) (local.get '$i)))
                            (local.set '$ptr (i32.add (i32.const 8) (local.get '$ptr)))
                            (local.set '$next (i64.load (local.get '$ptr)))
                            (_if '$not_num
                                 (is_not_type_code int_tag (local.get '$next))
                                (then (unreachable))
                            )
                            (local.set '$cur (if sensitive (mk_int_code_i64 (op (extract_int_code (local.get '$cur)) (extract_int_code (local.get '$next))))
                                                           (op (local.get '$cur) (local.get '$next))))
                            (local.set '$i (i32.add (local.get '$i) (i32.const 1)))
                            (br '$l)
                        )
                    )
                    drop_p_d
                    (local.get '$cur)
                )
              ))

              ((datasi memo k_mod_msg_val) (compile-string-val datasi memo "k_mod"))
              ((k_mod           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$mod  true  i64.rem_s))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_div_msg_val) (compile-string-val datasi memo "k_div"))
              ((k_div           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$div  true  i64.div_s))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_mul_msg_val) (compile-string-val datasi memo "k_mul"))
              ((k_mul           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$mul  true  i64.mul))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_sub_msg_val) (compile-string-val datasi memo "k_sub"))
              ((k_sub           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$sub  true  i64.sub))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_add_msg_val) (compile-string-val datasi memo "k_add"))
              ((k_add           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$add  false i64.add))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_band_msg_val) (compile-string-val datasi memo "k_band"))
              ((k_band          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$band false i64.and))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_bor_msg_val) (compile-string-val datasi memo "k_bor"))
              ((k_bor           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$bor  false i64.or))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_bxor_msg_val) (compile-string-val datasi memo "k_bxor"))
              ((k_bxor          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$bxor false i64.xor))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              ((datasi memo k_bnot_msg_val) (compile-string-val datasi memo "k_bnot"))
              ((k_bnot          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$bnot   '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 int_tag k_bnot_msg_val)
                (i64.xor (i64.const int_mask) (i64.load (local.get '$ptr)))
                drop_p_d
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              ((datasi memo k_ls_msg_val) (compile-string-val datasi memo "k_ls"))
              ((k_ls            func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$ls  '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 2)
                (type_assert 0 int_tag k_ls_msg_val)
                (type_assert 1 int_tag k_ls_msg_val)
                (i64.shl (i64.load 0 (local.get '$ptr)) (extract_int_code (i64.load 8 (local.get '$ptr))))
                drop_p_d
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_rs_msg_val) (compile-string-val datasi memo "k_rs"))
              ((k_rs            func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$rs  '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 2)
                (type_assert 0 int_tag k_rs_msg_val)
                (type_assert 1 int_tag k_rs_msg_val)
                (i64.and (i64.const int_mask) (i64.shr_s (i64.load 0 (local.get '$ptr)) (extract_int_code (i64.load 8 (local.get '$ptr)))))
                drop_p_d
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))


              ((k_builtin_fib_helper            func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$builtin_fib_helper  '(param $n i64) '(result i64)
                  (_if '$eq0 '(result i64)
                       (i64.eq (i64.const 0) (local.get '$n))
                      (then (i64.const (mk_int_value 1)))
                      (else
                        (_if '$eq1 '(result i64)
                            (i64.eq (i64.const (mk_int_value 1)) (local.get '$n))
                            (then (i64.const (mk_int_value 1)))
                            (else
                              (i64.add (call '$builtin_fib_helper (i64.sub (local.get '$n) (i64.const (mk_int_value 1)))) (call '$builtin_fib_helper (i64.sub (local.get '$n) (i64.const (mk_int_value 2)))))
                            )
                        )
                      )
                  )
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              ((datasi memo k_builtin_fib_msg_val) (compile-string-val datasi memo "k_builtin_fib"))
              ((k_builtin_fib            func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$builtin_fib  '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 int_tag k_builtin_fib_msg_val)
                (call '$builtin_fib_helper (i64.load 0 (local.get '$ptr)))
                drop_p_d
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              (_ (true_print "made k_builtin_fib"))

              ((datasi memo k_concat_msg_val) (compile-string-val datasi memo "k_concat"))
              ((k_concat        func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$concat  '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $size i32) '(local $i i32) '(local $it i64) '(local $new_ptr i32) '(local $inner_ptr i32) '(local $inner_size i32) '(local $new_ptr_traverse i32) '(local $is_str i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                set_len_ptr
                (local.set '$size (i32.const 0))
                (local.set '$i (i32.const 0))
                (local.set '$is_str (i32.const 0))
                (block '$b
                    (_loop '$l
                        (br_if '$b (i32.eq (local.get '$len) (local.get '$i)))
                        (local.set '$it (i64.load (i32.add (i32.shl (local.get '$i) (i32.const 3)) (local.get '$ptr))))
                        (_if '$not_array (is_not_type_code array_tag (local.get '$it))
                            (then
                                (_if '$is_string (is_type_code string_tag (local.get '$it))
                                    (then
                                         (_if '$is_first (i32.eq (i32.const 0) (local.get '$i))
                                              (then
                                                (local.set '$is_str (i32.const 1))
                                              )
                                              (else
                                                    (_if '$mixed (i32.eqz (local.get '$is_str))
                                                         (then (unreachable)))
                                              )
                                         )
                                    )
                                    (else (unreachable))
                                )
                            )
                            (else
                              (_if '$mixed (local.get '$is_str)
                                   (then (unreachable)))
                            )
                        )
                        (local.set '$size (i32.add (local.get '$size) (extract_size_code (local.get '$it))))
                        (local.set '$i    (i32.add (local.get '$i)    (i32.const 1)))
                        (br '$l)
                    )
                )
                (_if '$size_0 '(result i64)
                    (i32.eqz (local.get '$size))
                    (then (_if 'ret_emptystr '(result i64) (local.get '$is_str)
                               (then (i64.const emptystr_val))
                               (else (i64.const nil_val))))
                    (else
                        (_if 'doing_str '(result i64) (local.get '$is_str)
                          (then
                              (local.set '$new_ptr  (call '$malloc (local.get '$size))) ; malloc(size)
                              (local.set '$new_ptr_traverse (local.get '$new_ptr))

                              (local.set '$i (i32.const 0))
                              (block '$exit_outer_loop
                                  (_loop '$outer_loop
                                      (br_if '$exit_outer_loop (i32.eq (local.get '$len) (local.get '$i)))
                                      (local.set '$it (i64.load (i32.add (i32.shl (local.get '$i) (i32.const 3)) (local.get '$ptr))))

                                      (local.set '$inner_ptr  (extract_ptr_code  (local.get '$it)))
                                      (local.set '$inner_size (extract_size_code (local.get '$it)))

                                      (memory.copy (local.get '$new_ptr_traverse)
                                                   (local.get '$inner_ptr)
                                                   (local.get '$inner_size))

                                      (local.set '$new_ptr_traverse    (i32.add (local.get '$new_ptr_traverse) (local.get '$inner_size)))
                                      (local.set '$i (i32.add (local.get '$i) (i32.const 1)))
                                      (br '$outer_loop)
                                  )
                              )

                              (mk_string_code_rc (local.get '$size) (local.get '$new_ptr))
                          )
                          (else
                              (local.set '$new_ptr  (call '$malloc (i32.shl (local.get '$size) (i32.const 3)))) ; malloc(size*8)
                              (local.set '$new_ptr_traverse (local.get '$new_ptr))

                              (local.set '$i (i32.const 0))
                              (block '$exit_outer_loop
                                  (_loop '$outer_loop
                                      (br_if '$exit_outer_loop (i32.eq (local.get '$len) (local.get '$i)))
                                      (local.set '$it (i64.load (i32.add (i32.shl (local.get '$i) (i32.const 3)) (local.get '$ptr))))
                                      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                                      ; There's some serious optimization we could do here
                                      ; Moving the items from the sub arrays to this one without
                                      ; going through all the dup/drop
                                      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                                      (local.set '$inner_ptr  (extract_ptr_code  (local.get '$it)))
                                      (local.set '$inner_size (extract_size_code (local.get '$it)))

                                      (block '$exit_inner_loop
                                          (_loop '$inner_loop
                                              (br_if '$exit_inner_loop (i32.eqz (local.get '$inner_size)))
                                              (i64.store (local.get '$new_ptr_traverse)
                                                         (generate_dup (i64.load (local.get '$inner_ptr))))
                                              (local.set '$inner_ptr           (i32.add (local.get '$inner_ptr)          (i32.const 8)))
                                              (local.set '$new_ptr_traverse    (i32.add (local.get '$new_ptr_traverse)   (i32.const 8)))
                                              (local.set '$inner_size          (i32.sub (local.get '$inner_size)         (i32.const 1)))
                                              (br '$inner_loop)
                                          )
                                      )
                                      (local.set '$i (i32.add (local.get '$i) (i32.const 1)))
                                      (br '$outer_loop)
                                  )
                              )
                              (mk_array_code_rc (local.get '$size) (local.get '$new_ptr))
                          )
                         )
                    )
                )
                drop_p_d
              ))))
              (_ (true_print "concat is " k_concat " which might be " (- k_concat dyn_start)))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_slice_msg_val) (compile-string-val datasi memo "k_slice"))
              ((k_slice         func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$slice   '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 3)
                (type_assert 0 (array array_tag string_tag) k_slice_msg_val)
                (type_assert 1 int_tag k_slice_msg_val)
                (type_assert 2 int_tag k_slice_msg_val)
                (call '$slice_impl (generate_dup (i64.load  0 (local.get '$ptr)))
                                   (extract_int_code_i32 (i64.load  8 (local.get '$ptr)))
                                   (extract_int_code_i32 (i64.load 16 (local.get '$ptr))))
                drop_p_d
              ))))
              (_ (true_print "slice is " k_slice " which might be " (- k_slice dyn_start)))
              (_ (true_print "made k_slice"))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_idx_msg_val) (compile-string-val datasi memo "k_idx"))
              ((k_idx           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$idx     '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $array i64) '(local $idx i32) '(local $size i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 2)
                (type_assert 0 (array array_tag string_tag) k_idx_msg_val)
                (type_assert 1 int_tag k_idx_msg_val)
                (local.set '$array (i64.load 0 (local.get '$ptr)))
                (local.set '$idx  (extract_int_code_i32  (i64.load 8 (local.get '$ptr))))
                (local.set '$size (extract_size_code (local.get '$array)))

                (_if '$i_lt_0     (i32.lt_s (local.get '$idx) (i32.const 0))      (then (unreachable)))
                (_if '$i_ge_s     (i32.ge_s (local.get '$idx) (local.get '$size)) (then (unreachable)))

                (typecheck 0 (array '(result i64))
                    i64.eq array_tag
                    (array (then
                      (generate_dup (i64.load (i32.add (extract_ptr_code (local.get '$array))
                                                     (i32.shl (local.get '$idx) (i32.const 3)))))
                    ))
                    (array (else (mk_int_code_i64 (i64.load8_u (i32.add (extract_ptr_code (local.get '$array))
                                                                    (local.get '$idx))))))
                )
                drop_p_d
              ))))
              (_ (true_print "idx is " k_idx " which might be " (- k_idx dyn_start)))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_len_msg_val) (compile-string-val datasi memo "k_len"))
              ((k_len           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$len     '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 (array array_tag string_tag) k_len_msg_val)
                (mk_int_code_i32u (extract_size_code (i64.load 0 (local.get '$ptr))))
                drop_p_d
              ))))
              (_ (true_print "len is " k_len " which might be " (- k_len dyn_start)))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_array_msg_val) (compile-string-val datasi memo "k_array"))
              ((k_array         func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$array   '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (local.get '$p)
                (generate_drop (local.get '$d))
                ; s is 0
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              ((datasi memo k_get_msg_val) (compile-string-val datasi memo "k_get-text"))
              ((k_get-text      func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$get-text      '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 symbol_tag k_get_msg_val)
                ; Does not need to dup, as since it's a symbol it's already interned
                ; so this is now an interned string
                (toggle_sym_str_code (i64.load (local.get '$ptr)))
                drop_p_d
              ))))

              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_str_msg_val) (compile-string-val datasi memo "k_str"))
              ((k_str-to-symbol func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$str-to-symbol '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $looking_for i64) '(local $potential i64) '(local $traverse i64) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 string_tag k_str_msg_val)

                (local.set '$looking_for (i64.load (local.get '$ptr)))
                (local.set '$traverse (global.get '$symbol_intern))
                (local.set '$potential (i64.const nil_val))

                (block '$loop_break
                      (_loop '$loop
                             (br_if '$loop_break (i64.eq (local.get '$traverse) (i64.const nil_val)))
                             (local.set '$potential (i64.load 0 (extract_ptr_code (local.get '$traverse))))
                             (local.set '$traverse  (i64.load 8 (extract_ptr_code (local.get '$traverse))))
                             (_if '$found_it
                                  (i64.eq (i64.const 1)
                                          (call '$str_sym_comp (local.get '$looking_for) (local.get '$potential) (i64.const 0) (i64.const 1) (i64.const 0)))
                                  (then
                                    (br '$loop_break)
                                  )
                             )
                             (local.set '$potential (i64.const nil_val))
                             (br '$loop)
                      )
                )
                (_if '$didnt_find_it
                     (i64.eq (local.get '$traverse) (i64.const nil_val))
                     (then
                         (local.set '$potential (toggle_sym_str_code_norc (generate_dup (local.get '$looking_for))))
                         ;(local.set '$potential (toggle_sym_str_code (generate_dup (local.get '$looking_for))))
                         (global.set '$symbol_intern (call '$array2_alloc (local.get '$potential) (global.get '$symbol_intern)))
                         (global.set '$num_interned_symbols   (i32.add (i32.const 1) (global.get '$num_interned_symbols)))
                     )
                )
                (local.get '$potential)
                ;(generate_dup (local.get '$potential))
                drop_p_d
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              ((datasi memo k_unwrap_msg_val) (compile-string-val datasi memo "k_unwrap"))
              ((k_unwrap        func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$unwrap        '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $comb i64) '(local $wrap_level i64) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 comb_tag k_unwrap_msg_val)
                (local.set '$comb (i64.load (local.get '$ptr)))
                (local.set '$wrap_level (extract_wrap_code (local.get '$comb)))
                (_if '$wrap_level_0
                    (i64.eqz (local.get '$wrap_level))
                    (then (unreachable))
                )
                (generate_dup (set_wrap_code (i64.sub (local.get '$wrap_level) (i64.const 1)) (local.get '$comb)))
                drop_p_d
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_wrap_msg_val) (compile-string-val datasi memo "k_wrap"))
              ((k_wrap          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$wrap          '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $comb i64) '(local $wrap_level i64) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 comb_tag k_wrap_msg_val)
                (local.set '$comb (i64.load (local.get '$ptr)))
                (local.set '$wrap_level (extract_wrap_code (local.get '$comb)))
                (_if '$wrap_level_1
                    (i64.eq (i64.const 1) (local.get '$wrap_level))
                    (then (unreachable))
                )
                (generate_dup (set_wrap_code (i64.add (local.get '$wrap_level) (i64.const 1)) (local.get '$comb)))
                drop_p_d
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              ((datasi memo k_quote_msg_val) (compile-string-val datasi memo "k_quote"))
              ((k_quote          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$quote          '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $comb i64) '(local $wrap_level i64) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (generate_dup (i64.load (local.get '$ptr)))
                drop_p_d
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              (quote_val (mk_comb_val_nil_env (- k_quote dyn_start) 0 0))

              ((datasi memo k_lapply_msg_val) (compile-string-val datasi memo "k_lapply"))
              ((k_lapply          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$lapply          '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $ptr_b i32) '(local $len i32) '(local $comb i64) '(local $params i64) '(local $wrap_level i64) '(local $inner_env i64) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.lt_u 2)
                (type_assert 0 comb_tag k_lapply_msg_val)
                (type_assert 1 array_tag k_lapply_msg_val)
                (local.set '$comb   (generate_dup (i64.load 0 (local.get '$ptr))))
                (local.set '$params (generate_dup (i64.load 8 (local.get '$ptr))))
                (_if '$needs_dynamic_env
                     (extract_usede_code (local.get '$comb))
                     (then
                       (_if '$explicit_inner
                            (i32.eq (i32.const 3) (local.get '$len))
                            (then
                              (type_assert 2 env_tag k_lapply_msg_val)
                              (generate_drop (local.get '$d))
                              (local.set '$inner_env (generate_dup (i64.load 16 (local.get '$ptr))))
                            )
                            (else
                              (local.set '$inner_env (local.get '$d))
                            )
                       )
                     )
                     (else
                       (generate_drop (local.get '$d))
                       (local.set '$inner_env (i64.const nil_val))
                     )
                )
                (generate_drop (local.get '$p))
                (local.set '$wrap_level (extract_wrap_code (local.get '$comb)))
                (local.set '$len (extract_size_code (local.get '$params)))
                ; if params len == 0, doesn't matter what the wrap level is
                (_if '$params_len_ne_0
                     (i32.ne (i32.const 0) (local.get '$len))
                     (then
                      (_if '$wrap_level_ne_1
                          (i64.ne (i64.const 1) (local.get '$wrap_level))
                          (then
                                  (_if '$wrap_level_eq_0
                                      (i64.eq (i64.const 0) (local.get '$wrap_level))
                                      (then
                                        (local.set '$ptr (call '$malloc (i32.shl (local.get '$len) (i32.const 3))))
                                        (local.set '$ptr_b (extract_ptr_code (local.get '$params)))
                                        (_loop '$quote_params
                                            (local.set '$len (i32.sub (local.get '$len) (i32.const 1)))
                                            (i64.store                                                                    (i32.add (i32.shl (local.get '$len) (i32.const 3)) (local.get '$ptr))
                                                       (call '$array2_alloc (i64.const quote_val) (generate_dup (i64.load (i32.add (i32.shl (local.get '$len) (i32.const 3)) (local.get '$ptr_b))))))
                                            (br_if '$quote_params (i32.ne (i32.const 0) (local.get '$len)))
                                        )
                                        (local.set '$len (extract_size_code (local.get '$params)))
                                        (generate_drop (local.get '$params))
                                        (local.set '$params (mk_array_code_rc (local.get '$len) (local.get '$ptr)))
                                      )
                                      (else (unreachable))
                                  )
                            )
                      )
                     )
                )

                (call_indirect
                    ;type
                    k_wrap
                    ;table
                    0
                    ;params
                    (local.get '$params)
                    ; dynamic env
                    (local.get '$inner_env)
                    ; static env
                    (extract_func_env_code (local.get '$comb))
                    ;func_idx
                    (extract_func_idx_code (local.get '$comb))
                )
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              ((datasi memo k_vapply_msg_val) (compile-string-val datasi memo "k_vapply"))
              ((datasi memo k_vapply_1_msg_val) (compile-string-val datasi memo "vapply - we don't yet support compiled (vapply <comb1> (args..)), is TODO - needs rearranging of eval_helper position etc"))
              ((k_vapply          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$vapply          '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $comb i64) '(local $params i64) '(local $wrap_level i64) '(local $inner_env i64) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 3)
                (type_assert 0 comb_tag k_vapply_msg_val)
                (type_assert 1 array_tag k_vapply_msg_val)
                (local.set '$comb   (generate_dup (i64.load 0 (local.get '$ptr))))
                (local.set '$params (generate_dup (i64.load 8 (local.get '$ptr))))
                (_if '$needs_dynamic_env
                     (extract_usede_code (local.get '$comb))
                     (then
                       (_if '$explicit_inner
                            (i32.eq (i32.const 3) (local.get '$len))
                            (then
                              (type_assert 2 env_tag k_vapply_msg_val)
                              (generate_drop (local.get '$d))
                              (local.set '$inner_env (generate_dup (i64.load 16 (local.get '$ptr))))
                            )
                            (else
                              (local.set '$inner_env (local.get '$d))
                            )
                       )
                     )
                     (else
                       (generate_drop (local.get '$d))
                       (local.set '$inner_env (i64.const nil_val))
                     )
                )
                (generate_drop (local.get '$p))
                (local.set '$wrap_level (extract_wrap_code (local.get '$comb)))
                (_if '$wrap_level_ne_0
                    (i64.ne (i64.const 0) (local.get '$wrap_level))
                    ; TODO - if wrap_level == 1, eval all parameters
                    ; that's what the partially evaluated one does.
                    ; Will require some re-arranging as eval helper etc
                    ; are currently defined below us
                    (then (call '$print (i64.const k_vapply_1_msg_val))
                          (unreachable))
                )

                (call_indirect
                    ;type
                    k_wrap
                    ;table
                    0
                    ;params
                    (local.get '$params)
                    ; dynamic env
                    (local.get '$inner_env)
                    ; static env
                    (extract_func_env_code (local.get '$comb))
                    ;func_idx
                    (extract_func_idx_code (local.get '$comb))
                )
              ))))
              (_ (true_print "made vapply"))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ; *GLOBAL ALERT*
              ((k_parse_helper  func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$parse_helper  '(result i64) '(local $result i64) '(local $tmp i32) '(local $sub_result i64) '(local $asiz i32) '(local $acap i32) '(local $aptr i32) '(local $bptr i32) '(local $bcap i32) '(local $neg_multiplier i64) '(local $radix i64)
                (block '$b1
                    (block '$b2
                        (_loop '$l
                            (br_if '$b2 (i32.eqz (global.get '$phl)))
                            (local.set '$tmp (i32.load8_u (global.get '$phs)))
                            (_if '$whitespace (i32.or (i32.or (i32.eq (i32.const #x9)  (local.get '$tmp))    ; tab
                                                              (i32.eq (i32.const #xA)  (local.get '$tmp)))   ; newline
                                                      (i32.or (i32.eq (i32.const #xD)  (local.get '$tmp))    ; carrige return
                                                              (i32.eq (i32.const #x20) (local.get '$tmp))))  ; space
                                (then
                                    (global.set '$phs (i32.add (global.get '$phs) (i32.const 1)))
                                    (global.set '$phl (i32.sub (global.get '$phl) (i32.const 1)))
                                    (br '$l)
                                )
                            )
                            (_if '$comment (i32.eq (i32.const #x3B)  (local.get '$tmp))
                                (then
                                    (_loop '$li
                                        (global.set '$phs (i32.add (global.get '$phs) (i32.const 1)))
                                        (global.set '$phl (i32.sub (global.get '$phl) (i32.const 1)))
                                        (br_if '$b2 (i32.eqz (global.get '$phl)))
                                        (local.set '$tmp (i32.load8_u (global.get '$phs)))
                                        (br_if '$li (i32.ne (i32.const #xA) (local.get '$tmp)))
                                    )
                                    (br '$l)
                                )
                            )
                        )
                    )
                    (local.set '$result (i64.const empty_parse_value))
                    (_if '$at_least1
                        (i32.ge_u (global.get '$phl) (i32.const 1))
                        (then
                            (local.set '$tmp (i32.load8_u (global.get '$phs)))
                            ; string
                            (_if '$is_open
                                (i32.eq (local.get '$tmp) (i32.const #x22))
                                (then
                                    (global.set '$phs (i32.add (global.get '$phs) (i32.const 1)))
                                    (global.set '$phl (i32.sub (global.get '$phl) (i32.const 1)))
                                    (local.set '$asiz (i32.const 0))
                                    (local.set '$bptr (global.get '$phs))

                                    ; Count size
                                    (block '$b2
                                        (_loop '$il
                                            (_if '$doesnt_have_next
                                                (i32.eqz (global.get '$phl))
                                                (then
                                                    (local.set '$result (i64.const error_parse_value))
                                                    (br '$b1)
                                                )
                                            )

                                            (br_if '$b2 (i32.eq (i32.load8_u (global.get '$phs)) (i32.const #x22)))

                                            (_if '$an_escape
                                                (i32.eq (i32.load8_u (global.get '$phs)) (i32.const #x5C))
                                                (then
                                                    (global.set '$phs  (i32.add (global.get '$phs)  (i32.const 1)))
                                                    (global.set '$phl  (i32.sub (global.get '$phl)  (i32.const 1)))
                                                    (_if '$doesnt_have_next
                                                        (i32.eqz (global.get '$phl))
                                                        (then
                                                            (local.set '$result (i64.const error_parse_value))
                                                            (br '$b1)
                                                        )
                                                    )
                                                )
                                            )
                                            (local.set '$asiz (i32.add (local.get '$asiz) (i32.const 1)))

                                            (global.set '$phs  (i32.add (global.get '$phs)  (i32.const 1)))
                                            (global.set '$phl  (i32.sub (global.get '$phl)  (i32.const 1)))
                                            (br '$il)
                                        )
                                    )

                                    (global.set '$phs  (i32.add (global.get '$phs)  (i32.const 1)))
                                    (global.set '$phl  (i32.sub (global.get '$phl)  (i32.const 1)))

                                    (local.set '$bcap (local.get '$asiz))
                                    (local.set '$aptr (call '$malloc (local.get '$asiz)))

                                    ; copy the bytes, implementing the escapes
                                    (block '$b2
                                        (_loop '$il
                                            (br_if '$b2 (i32.eqz (local.get '$bcap)))

                                            (_if '$an_escape
                                                (i32.eq (i32.load8_u (local.get '$bptr)) (i32.const #x5C))
                                                (then
                                                    (_if '$escaped_slash
                                                        (i32.eq (i32.load8_u 1 (local.get '$bptr)) (i32.const #x5C))
                                                        (then
                                                            (i32.store8 (local.get '$aptr) (i32.const #x5C))
                                                        )
                                                        (else
                                                            (_if '$escaped_quote
                                                                (i32.eq (i32.load8_u 1 (local.get '$bptr)) (i32.const #x22))
                                                                (then
                                                                    (i32.store8 (local.get '$aptr) (i32.const #x22))
                                                                )
                                                                (else
                                                                    (_if '$escaped_newline
                                                                        (i32.eq (i32.load8_u 1 (local.get '$bptr)) (i32.const #x6E))
                                                                        (then
                                                                            (i32.store8 (local.get '$aptr) (i32.const #x0A))
                                                                        )
                                                                        (else
                                                                            (_if '$escaped_tab
                                                                                (i32.eq (i32.load8_u 1 (local.get '$bptr)) (i32.const #x74))
                                                                                (then
                                                                                    (i32.store8 (local.get '$aptr) (i32.const #x09))
                                                                                )
                                                                                (else
                                                                                    (global.set '$phl  (i32.add (global.get '$phl) (i32.sub (global.get '$phs) (local.get '$bptr))))
                                                                                    (global.set '$phs  (local.get '$bptr))
                                                                                    (local.set '$result (i64.const error_parse_value))
                                                                                    (br '$b1)
                                                                                )
                                                                            )
                                                                        )
                                                                    )
                                                                )
                                                            )
                                                        )
                                                    )
                                                    (local.set '$bptr (i32.add (local.get '$bptr) (i32.const 2)))
                                                )
                                                (else
                                                    (i32.store8 (local.get '$aptr) (i32.load8_u (local.get '$bptr)))
                                                    (local.set '$bptr (i32.add (local.get '$bptr) (i32.const 1)))
                                                )
                                            )
                                            (local.set '$bcap (i32.sub (local.get '$bcap) (i32.const 1)))
                                            (local.set '$aptr (i32.add (local.get '$aptr) (i32.const 1)))
                                            (br '$il)
                                        )
                                    )
                                    (local.set '$aptr (i32.sub (local.get '$aptr) (local.get '$asiz)))

                                    (local.set '$result (mk_string_code_rc (local.get '$asiz) (local.get '$aptr)))
                                    (br '$b1)
                                )
                            )

                            ; negative int
                            (local.set '$neg_multiplier (i64.const 1))
                            (_if '$is_dash_and_more
                                (i32.and (i32.eq (local.get '$tmp) (i32.const #x2D)) (i32.ge_u (global.get '$phl) (i32.const 2)))
                                (then
                                    (_if '$next_is_letter
                                        (i32.and (i32.ge_u (i32.load8_u 1 (global.get '$phs)) (i32.const #x30)) (i32.le_u (i32.load8_u 1 (global.get '$phs)) (i32.const #x39)))
                                        (then
                                            (global.set '$phs  (i32.add (global.get '$phs)  (i32.const 1)))
                                            (global.set '$phl  (i32.sub (global.get '$phl)  (i32.const 1)))
                                            (local.set '$tmp (i32.load8_u (global.get '$phs)))
                                            (local.set '$neg_multiplier (i64.const -1))
                                        )
                                    )
                                )
                            )
                            ; int
                            (local.set '$radix (i64.const 10))
                            (_if '$is_zero_through_nine
                                (i32.and (i32.ge_u (local.get '$tmp) (i32.const #x30)) (i32.le_u (local.get '$tmp) (i32.const #x39)))
                                (then
                                    (local.set '$result (i64.const 0))
                                    (_loop '$il
                                        (_if '$is_zero_through_nine_inner
                                            (i32.and (i32.ge_u (local.get '$tmp) (i32.const #x30)) (i32.le_u (local.get '$tmp) (i32.const #x39)))
                                            (then
                                                (local.set '$tmp (i32.sub (local.get '$tmp) (i32.const #x30)))
                                            )
                                            (else
                                                (local.set '$tmp (i32.sub (local.get '$tmp) (i32.const #x37)))
                                            )
                                        )
                                        (local.set '$result (i64.add (i64.mul (local.get '$radix) (local.get '$result)) (i64.extend_i32_u (local.get '$tmp))))
                                        (global.set '$phs  (i32.add (global.get '$phs)  (i32.const 1)))
                                        (global.set '$phl  (i32.sub (global.get '$phl)  (i32.const 1)))
                                        (_if '$at_least1
                                            (i32.ge_u (global.get '$phl) (i32.const 1))
                                            (then
                                                (local.set '$tmp (i32.load8_u (global.get '$phs)))
                                                (_if '$is_hex_and_more
                                                    (i32.and (i32.eq (local.get '$tmp) (i32.const #x78)) (i32.ge_u (global.get '$phl) (i32.const 2)))
                                                    (then
                                                        (global.set '$phs  (i32.add (global.get '$phs)  (i32.const 1)))
                                                        (global.set '$phl  (i32.sub (global.get '$phl)  (i32.const 1)))
                                                        (local.set '$tmp (i32.load8_u (global.get '$phs)))
                                                        (local.set '$radix (i64.const 16))
                                                    )
                                                    (else
                                                        (_if '$is_hex_and_more
                                                            (i32.and (i32.eq (local.get '$tmp) (i32.const #x62)) (i32.ge_u (global.get '$phl) (i32.const 2)))
                                                            (then
                                                                (global.set '$phs  (i32.add (global.get '$phs)  (i32.const 1)))
                                                                (global.set '$phl  (i32.sub (global.get '$phl)  (i32.const 1)))
                                                                (local.set '$tmp (i32.load8_u (global.get '$phs)))
                                                                (local.set '$radix (i64.const 2))
                                                            )
                                                        )
                                                    )
                                                )
                                                (br_if '$il (i32.or (i32.and (i32.ge_u (local.get '$tmp) (i32.const #x30)) (i32.le_u (local.get '$tmp) (i32.const #x39)))
                                                                    (i32.and (i32.ge_u (local.get '$tmp) (i32.const #x41)) (i32.le_u (local.get '$tmp) (i32.const #x46)))))
                                            )
                                        )
                                    )
                                    (local.set '$result (mk_int_code_i64 (i64.mul (local.get '$neg_multiplier) (local.get '$result))))
                                    (br '$b1)
                                )
                            )

                            ; []?
                            ; '
                            (_if '$is_quote
                                (i32.eq (local.get '$tmp) (i32.const #x27))
                                (then
                                    (global.set '$phs (i32.add (global.get '$phs) (i32.const 1)))
                                    (global.set '$phl (i32.sub (global.get '$phl) (i32.const 1)))
                                    (local.set '$sub_result (call '$parse_helper))
                                    (_if '$ended
                                        (i64.eq (i64.const close_peren_value) (local.get '$sub_result))
                                        (then
                                            (local.set '$result (i64.const error_parse_value))
                                            (br '$b1)
                                        )
                                    )
                                    (_if '$error
                                        (i32.or (i64.eq (i64.const error_parse_value) (local.get '$sub_result))
                                                (i64.eq (i64.const empty_parse_value) (local.get '$sub_result)))
                                        (then
                                            (local.set '$result (local.get '$sub_result))
                                            (br '$b1)
                                        )
                                    )
                                    (local.set '$result (call '$array2_alloc (i64.const quote_sym_val) (local.get '$sub_result)))
                                    (br '$b1)
                                )
                            )
                            (_if '$is_unquote
                                (i32.eq (local.get '$tmp) (i32.const #x2C))
                                (then
                                    (global.set '$phs (i32.add (global.get '$phs) (i32.const 1)))
                                    (global.set '$phl (i32.sub (global.get '$phl) (i32.const 1)))
                                    (local.set '$sub_result (call '$parse_helper))
                                    (_if '$ended
                                        (i64.eq (i64.const close_peren_value) (local.get '$sub_result))
                                        (then
                                            (local.set '$result (i64.const error_parse_value))
                                            (br '$b1)
                                        )
                                    )
                                    (_if '$error
                                        (i32.or (i64.eq (i64.const error_parse_value) (local.get '$sub_result))
                                                (i64.eq (i64.const empty_parse_value) (local.get '$sub_result)))
                                        (then
                                            (local.set '$result (local.get '$sub_result))
                                            (br '$b1)
                                        )
                                    )
                                    (local.set '$result (call '$array2_alloc (i64.const unquote_sym_val) (local.get '$sub_result)))
                                    (br '$b1)
                                )
                            )

                            ; symbol
                            (_if '$is_dash_and_more
                                ; 21    !
                                ; 22    "           X
                                ; 23-26 #-&
                                ; 27    '           X
                                ; 28-29 (-)         X
                                ; 2A-2F *-/
                                ; 30-39 0-9         /
                                ; 3A    :
                                ; 3B    ;
                                ; 3C-40 <-@
                                ; 41-5A A-Z
                                ; 5B-60 [-`
                                ; 61-7A a-z
                                ; 7B-7E {-~
                                (i32.or (i32.or         (i32.eq (local.get '$tmp) (i32.const #x21))
                                                        (i32.and (i32.ge_u (local.get '$tmp) (i32.const #x23)) (i32.le_u (local.get '$tmp) (i32.const #x26))))
                                        (i32.or         (i32.and (i32.ge_u (local.get '$tmp) (i32.const #x2A)) (i32.le_u (local.get '$tmp) (i32.const #x2F)))
                                                (i32.or (i32.eq (local.get '$tmp) (i32.const #x3A))
                                                        (i32.and (i32.ge_u (local.get '$tmp) (i32.const #x3C)) (i32.le_u (local.get '$tmp) (i32.const #x7E))))))
                                (then
                                    (local.set '$asiz (i32.const 0))
                                    (local.set '$bptr (global.get '$phs))
                                    (block '$loop_break
                                        (_loop '$il
                                            (global.set '$phs  (i32.add (global.get '$phs)  (i32.const 1)))
                                            (global.set '$phl  (i32.sub (global.get '$phl)  (i32.const 1)))
                                            (local.set '$asiz (i32.add (local.get '$asiz) (i32.const 1)))
                                            (_if '$doesnt_have_next
                                                (i32.eqz (global.get '$phl))
                                                (then (br '$loop_break))
                                            )
                                            (local.set '$tmp (i32.load8_u (global.get '$phs)))
                                            (br_if '$il (i32.or (i32.or         (i32.eq (local.get '$tmp) (i32.const #x21))
                                                                                (i32.and (i32.ge_u (local.get '$tmp) (i32.const #x23)) (i32.le_u (local.get '$tmp) (i32.const #x26))))
                                                                        (i32.or (i32.and (i32.ge_u (local.get '$tmp) (i32.const #x2A)) (i32.le_u (local.get '$tmp) (i32.const #x3A)))
                                                                                (i32.and (i32.ge_u (local.get '$tmp) (i32.const #x3C)) (i32.le_u (local.get '$tmp) (i32.const #x7E))))))
                                        )
                                    )
                                    (_if '$is_true1
                                        (i32.eq (local.get '$asiz) (i32.const 4))
                                        (then
                                            (_if '$is_true2
                                                (i32.eq (i32.load (local.get '$bptr)) (i32.const #x65757274))
                                                (then
                                                    (local.set '$result (i64.const true_val))
                                                    (br '$b1)
                                                )
                                            )
                                        )
                                    )
                                    (_if '$is_false1
                                        (i32.eq (local.get '$asiz) (i32.const 5))
                                        (then
                                            (_if '$is_false2
                                                (i32.and (i32.eq (i32.load (local.get '$bptr)) (i32.const #x736C6166)) (i32.eq (i32.load8_u 4 (local.get '$bptr)) (i32.const #x65)))
                                                (then
                                                    (local.set '$result (i64.const false_val))
                                                    (br '$b1)
                                                )
                                            )
                                        )
                                    )
                                    (local.set '$aptr (call '$malloc (local.get '$asiz)))
                                    (memory.copy (local.get '$aptr)
                                                 (local.get '$bptr)
                                                 (local.get '$asiz))

                                    ; Inefficient hack
                                    (local.set '$result (call '$str-to-symbol
                                        ;params
                                        (call '$array1_alloc (mk_string_code_rc (local.get '$asiz) (local.get '$aptr)))
                                        ; dynamic env
                                        (i64.const nil_val)
                                        ; static env
                                        (i64.const nil_val)
                                    ))
                                    (br '$b1)
                                )
                            )

                            ; lists (arrays)!
                            (_if '$is_open
                                (i32.eq (local.get '$tmp) (i32.const #x28))
                                (then
                                    (global.set '$phs (i32.add (global.get '$phs) (i32.const 1)))
                                    (global.set '$phl (i32.sub (global.get '$phl) (i32.const 1)))
                                    (local.set '$asiz (i32.const 0))
                                    (local.set '$acap (i32.const 4))
                                    (local.set '$aptr (call '$malloc (i32.const (* 4 8))))
                                    (_loop '$il
                                        (local.set '$sub_result (call '$parse_helper))
                                        (_if '$ended
                                            (i64.eq (i64.const close_peren_value) (local.get '$sub_result))
                                            (then
                                                (_if '$nil
                                                    (i32.eqz (local.get '$asiz))
                                                    (then
                                                        (call '$free (local.get '$aptr))
                                                        (local.set '$result (i64.const nil_val))
                                                    )
                                                    (else
                                                        (local.set '$result (mk_array_code_rc (local.get '$asiz) (local.get '$aptr)))
                                                    )
                                                )
                                                (br '$b1)
                                            )
                                        )
                                        (_if '$error
                                            (i32.or (i64.eq (i64.const error_parse_value) (local.get '$sub_result))
                                                    (i64.eq (i64.const empty_parse_value) (local.get '$sub_result)))
                                            (then
                                                (local.set '$result (local.get '$sub_result))
                                                (br '$b1)
                                            )
                                        )
                                        (_if '$need_to_grow
                                            (i32.eq (local.get '$asiz) (local.get '$acap))
                                            (then
                                                (local.set '$bcap (i32.shl (local.get '$acap) (i32.const 1)))
                                                (local.set '$bptr (call '$malloc (i32.shl (local.get '$bcap) (i32.const 3))))
                                                (local.set '$asiz (i32.const 0))
                                                (_loop '$iil
                                                    (i64.store            (i32.add (local.get '$bptr) (i32.shl (local.get '$asiz) (i32.const 3)))
                                                                (i64.load (i32.add (local.get '$aptr) (i32.shl (local.get '$asiz) (i32.const 3)))))
                                                    (local.set '$asiz (i32.add (local.get '$asiz) (i32.const 1)))
                                                    (br_if '$iil (i32.lt_u (local.get '$asiz) (local.get '$acap)))
                                                )
                                                (local.set '$acap (local.get '$bcap))
                                                (call '$free (local.get '$aptr))
                                                (local.set '$aptr (local.get '$bptr))
                                            )
                                        )
                                        (i64.store  (i32.add (local.get '$aptr) (i32.shl (local.get '$asiz) (i32.const 3)))
                                                    (local.get '$sub_result))
                                        (local.set '$asiz (i32.add (local.get '$asiz) (i32.const 1)))
                                        (br '$il)
                                    )
                                )
                            )
                            (_if '$is_close
                                (i32.eq (local.get '$tmp) (i32.const #x29))
                                (then
                                    (local.set '$result (i64.const close_peren_value))
                                    (global.set '$phs (i32.add (global.get '$phs) (i32.const 1)))
                                    (global.set '$phl (i32.sub (global.get '$phl) (i32.const 1)))
                                    (br '$b1)
                                )
                            )
                        )
                    )
                )
                (local.get '$result)
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_read_msg_val) (compile-string-val datasi memo "k_read"))
              ((k_read-string   func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$read-string   '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $str i64) '(local $result i64) '(local $tmp_result i64) '(local $tmp_offset i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 string_tag k_read_msg_val)
                (local.set '$str (i64.load (local.get '$ptr)))
                ;(call '$print (i64.const pre_parse_val))
                (global.set '$phl (extract_size_code (local.get '$str)))
                (global.set '$phs (extract_ptr_code  (local.get '$str)))
                (local.set '$result (call '$parse_helper))
                ;(call '$print (i64.const post_parse_val))
                (_if '$was_empty_parse
                    (i32.or         (i64.eq (i64.const error_parse_value) (local.get '$result))
                            (i32.or (i64.eq (i64.const empty_parse_value) (local.get '$result))
                                    (i64.eq (i64.const close_peren_value) (local.get '$result))))
                    (then
                        (call '$print (i64.const couldnt_parse_1_msg_val))
                        (call '$print (local.get '$str))
                        (call '$print (i64.const couldnt_parse_2_msg_val))
                        (call '$print (mk_int_code_i64 (i64.add (i64.const 1) (i64.sub (i64.shr_u (local.get '$str) (i64.const 32)) (i64.extend_i32_u (global.get '$phl))))))
                        (call '$print (i64.const newline_msg_val))
                        (unreachable)
                    )
                )
                (_if '$remaining
                    (i32.ne (i32.const 0) (global.get '$phl))
                    (then
                        (local.set '$tmp_offset (global.get '$phl))
                        (local.set '$tmp_result (call '$parse_helper))
                        (_if '$wasnt_empty_parse
                            (i64.ne (i64.const empty_parse_value) (local.get '$tmp_result))
                            (then
                                (call '$print (i64.const parse_remaining_msg_val))
                                (call '$print (mk_int_code_i64 (i64.sub (i64.shr_u (local.get '$str) (i64.const 32)) (i64.extend_i32_u (local.get '$tmp_offset)))))
                                (call '$print (i64.const newline_msg_val))
                                (unreachable)
                            )
                        )
                    )
                )
                (local.get '$result)
                drop_p_d
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              (_ (true_print "made parse/read"))


              (front_half_stack_code (lambda (call_val env_val) (_if '$debug_level (i32.ne (i32.const -1) (global.get '$debug_depth)) (then (global.set '$stack_trace (call '$array3_alloc call_val
                                                                                                       env_val
                                                                                                       (generate_dup (global.get '$stack_trace))))))))
              (back_half_stack_code (concat (_if '$debug_level (i32.ne (i32.const -1) (global.get '$debug_depth)) (then
                                            (i64.load 16 (extract_ptr_code (global.get '$stack_trace)))
                                            (generate_drop (global.get '$stack_trace))
                                            (global.set '$stack_trace)))))
              ;(front_half_stack_code (lambda (call_val env_val) (array)))
              ;(back_half_stack_code (array))

              ((datasi memo k_call_zero_len_msg_val) (compile-string-val datasi memo "tried to eval a 0-length call"))
              ((datasi memo k_call_not_a_function_msg_val) (compile-string-val datasi memo "tried to eval a call to not a function "))

              ; Helper method, doesn't refcount consume parameters
              ; but does properly refcount internally / dup returns
              ((k_eval_helper func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$eval_helper '(param $it i64) '(param $env i64) '(result i64) '(local $len i32) '(local $ptr i32) '(local $current_env i64) '(local $res i64) '(local $env_ptr i32) '(local $tmp_ptr i32) '(local $i i32) '(local $comb i64) '(local $params i64) '(local $wrap i32) '(local $tmp i64) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)


            (global.set '$num_all_evals   (i32.add (i32.const 1) (global.get '$num_all_evals)))
            ; The cool thing about Vau calculus / Kernel / Kraken
            ; is that everything is a value that evaluates to itself except symbols
            ; and arrays.
            (_if '$is_value '(result i64)
                 (value_test (local.get '$it))
                 (then
                   ; it's a value, we can just return it!
                   (generate_dup (local.get '$it))
                 )
                 (else
                   (_if '$is_symbol '(result i64)
                        (is_type_code symbol_tag (local.get '$it))
                        (then
                          ;(call '$print (local.get '$it))
                          ; look it up in the environment
                          ;   Env object is <key_array_value><value_array_value><upper_env_value>
                          ;       each being the full 64 bit objects.
                          (local.set '$current_env (local.get '$env))
                          ;(call '$print (local.get '$current_env))
                          ;(call '$print (i64.const newline_msg_val))

                          (block '$outer_loop_break
                                (_loop '$outer_loop
                                      (local.set '$env_ptr (extract_ptr_code (local.get '$current_env)))

                                      (local.set '$len (extract_size_code (i64.load 0 (local.get '$env_ptr))))
                                      (local.set '$ptr (extract_ptr_code  (i64.load 0 (local.get '$env_ptr))))
                                      (local.set '$i   (i32.const 0))

                                      (block '$inner_loop_break
                                            (_loop '$inner_loop
                                                   (br_if '$inner_loop_break (i32.eqz (local.get '$len)))
                                                   (_if '$found_it
                                                        (i64.eq (local.get '$it) (i64.load (local.get '$ptr)))
                                                        (then
                                                          (local.set '$res (generate_dup (i64.load (i32.add (extract_ptr_code (i64.load 8 (local.get '$env_ptr)))
                                                                                                          (i32.shl (local.get '$i) (i32.const 3))))))
                                                          (br '$outer_loop_break)
                                                        )
                                                   )
                                                   (local.set '$len (i32.sub (local.get '$len) (i32.const 1)))
                                                   (local.set '$ptr (i32.add (local.get '$ptr) (i32.const 8)))
                                                   (local.set '$i   (i32.add (local.get '$i)   (i32.const 1)))
                                                   (br '$inner_loop)
                                            )
                                      )
                                      ; try in upper
                                      (local.set '$current_env (i64.load 16 (local.get '$env_ptr)))
                                      ;(call '$print (mk_int_code_i64 (local.get '$current_env)))
                                      ;(call '$print (i64.const newline_msg_val))
                                      (br_if '$outer_loop (i64.ne (i64.const nil_val) (local.get '$current_env)))
                                )
                                ; Ended at upper case
                                (call '$print (i64.const hit_upper_in_eval_msg_val))
                                (call '$print (local.get '$it))
                                (call '$print (i64.const newline_msg_val))
                                (local.set '$res (call (+ 4 func_idx) (call '$array1_alloc (generate_dup (local.get '$it))) (generate_dup (local.get '$env)) (i64.const nil_val)))
                          )
                          (local.get '$res)
                        )
                        (else
                          (local.set '$len (extract_size_code (local.get '$it)))
                          (local.set '$ptr (extract_ptr_code  (local.get '$it)))
                          (_if '$zero_length
                               (i32.eqz (local.get '$len))
                               (then (call '$print (i64.const k_call_zero_len_msg_val))
                                     (unreachable)))
                          ; its a call, evaluate combiner first then
                          ;(call '$print (i64.const pre_inner_eval_val))
                          (local.set '$comb (call '$eval_helper (i64.load 0 (local.get '$ptr)) (local.get '$env)))
                          ;(call '$print (i64.const post_inner_eval_val))
                          ; check to make sure it's a combiner
                          (_if '$isnt_function
                                (is_not_type_code comb_tag (local.get '$comb))
                                (then (call '$print (i64.const k_call_not_a_function_msg_val))
                                      (call '$print (mk_int_code_i64 (local.get '$comb)))
                                      (call '$print (local.get '$comb))
                                      ; this has problems with redebug for some reason
                                      (local.set '$res (call (+ 4 func_idx) (call '$array1_alloc (generate_dup (local.get '$it))) (generate_dup (local.get '$env)) (i64.const nil_val)))
                                )
                          )
                          (local.set '$wrap (i32.wrap_i64 (extract_wrap_code (local.get '$comb))))
                          (local.set '$params (call '$slice_impl (generate_dup (local.get '$it)) (i32.const 1) (local.get '$len)))

                          ; Pure benchmarking
                          (_if '$is_wrap_one
                               (i32.eq (i32.const 1) (local.get '$wrap))
                               (then (global.set '$num_interp_done  (i32.add (i32.const 1) (global.get '$num_interp_done))))
                               (else
                                 (_if '$is_wrap_zero
                                      (i32.eqz (local.get '$wrap))
                                      (then (global.set '$num_interp_dzero (i32.add (i32.const 1) (global.get '$num_interp_dzero))))
                                      (else (unreachable)))))

                          ; we'll reuse len and ptr now for params
                          (local.set '$len (extract_size_code (local.get '$params)))
                          (local.set '$ptr (extract_ptr_code  (local.get '$params)))
                          ; then evaluate parameters wrap times (only 0 or 1 right now)
                          (block '$wrap_loop_break
                                 (_loop '$wrap_loop
                                        (br_if '$wrap_loop_break (i32.eqz (local.get '$wrap)))

                                        (local.set '$i   (i32.const 0))
                                        (block '$inner_eval_loop_break
                                               (_loop '$inner_eval_loop
                                                      (br_if '$inner_eval_loop_break (i32.eq (local.get '$len) (local.get '$i)))

                                                      (local.set '$tmp_ptr (i32.add (local.get '$ptr) (i32.shl (local.get '$i) (i32.const 3))))
                                                      (local.set '$tmp (call '$eval_helper (i64.load (local.get '$tmp_ptr)) (local.get '$env)))
                                                      (generate_drop (i64.load (local.get '$tmp_ptr)))
                                                      (i64.store (local.get '$tmp_ptr) (local.get '$tmp))

                                                      (local.set '$i   (i32.add (local.get '$i)   (i32.const 1)))
                                                      (br '$inner_eval_loop)
                                               )
                                        )
                                        (local.set '$wrap (i32.sub (local.get '$wrap) (i32.const 1)))
                                        (br '$wrap_loop)
                                 )
                          )
                          (front_half_stack_code (generate_dup (local.get '$it)) (generate_dup (local.get '$env)))
                          ; Also, this really should tail-call when we support it
                          (call_indirect
                                ;type
                                k_wrap
                                ;table
                                0
                                ;params
                                (local.get '$params)
                                ; dynamic env
                                (_if '$needs_dynamic_env '(result i64)
                                     (extract_usede_code (local.get '$comb))
                                     (then (generate_dup (local.get '$env)))
                                     (else (i64.const nil_val)))
                                ; static env
                                (extract_func_env_code (local.get '$comb))
                                ;func_idx
                                (extract_func_idx_code (local.get '$comb))
                          )
                          back_half_stack_code
                        )
                   )
                 )
            )

              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              ((datasi memo k_eval_msg_val) (compile-string-val datasi memo "k_eval"))
              ((k_eval          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$eval          '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $len i32) '(local $ptr i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)

                  (ensure_not_op_n_params_set_ptr_len i32.lt_u 1)
                  (global.set '$num_evals   (i32.add (i32.const 1) (global.get '$num_evals)))
                  (_if '$using_d_env '(result i64)
                        (i32.eq (i32.const 1) (local.get '$len))
                        (then
                            (call '$eval_helper (i64.load 0 (local.get '$ptr)) (local.get '$d))
                        )
                        (else
                            (type_assert 1 env_tag k_eval_msg_val)
                            (call '$eval_helper (i64.load 0 (local.get '$ptr)) (i64.load 8 (local.get '$ptr)))
                        )
                  )
                  drop_p_d
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              (_ (true_print "made eval"))

              ((datasi memo k_debug_parameters_msg_val) (compile-string-val datasi memo "parameters to debug were "))
              ((datasi memo k_debug_prompt_msg_val) (compile-string-val datasi memo "debug_prompt > "))
              ((datasi memo k_debug_exit_msg_val) (compile-string-val datasi memo "exit"))
              ((datasi memo k_debug_abort_msg_val) (compile-string-val datasi memo "abort\n"))
              ((datasi memo k_debug_redebug_msg_val) (compile-string-val datasi memo "redebug\n"))
              ((datasi memo k_debug_print_st_msg_val) (compile-string-val datasi memo "print_st\n"))
              ((datasi memo k_debug_help_msg_val) (compile-string-val datasi memo "help\n"))
              ((datasi memo k_debug_help_info_msg_val) (compile-string-val datasi memo "commands: help, print_st, print_envs, print_all, redebug, or (exit <exit value>)\n"))
              ((datasi memo k_debug_print_envs_msg_val) (compile-string-val datasi memo "print_envs\n"))
              ((datasi memo k_debug_print_all_msg_val) (compile-string-val datasi memo "print_all\n"))
              ((datasi memo k_debug_msg_val) (compile-string-val datasi memo "k_debug"))
              ((k_debug           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$debug           '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $len i32) '(local $buf i32) '(local $str i64) '(local $tmp_read i64) '(local $tmp_evaled i64) '(local $to_ret i64) '(local $tmp_ptr i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                (global.set '$debug_depth  (i32.add (global.get '$debug_depth) (i32.const 1)))
                (call '$print (i64.const k_debug_parameters_msg_val))
                (call '$print (local.get '$p))
                (call '$print (i64.const newline_msg_val))

                (block '$varadic_loop_exit
                    (_loop '$varadic_loop
                          (call '$print (i64.const k_debug_prompt_msg_val))

                          (local.set '$len (i32.const 100))
                          (i32.store 4 (i32.const iov_tmp) (local.get '$len))
                          (i32.store 0 (i32.const iov_tmp) (local.tee '$buf (call '$malloc (local.get '$len))))
                          (_drop (call '$fd_read
                                (i32.const 0)               ;; file descriptor
                                (i32.const iov_tmp)         ;; *iovs
                                (i32.const 1)               ;; iovs_len
                                (i32.const (+ 8 iov_tmp))   ;; nwritten
                          ))

                          (local.set '$str (mk_string_code_rc (i32.load 8 (i32.const iov_tmp)) (local.get '$buf)))

                          (local.set '$tmp_evaled (i64.const 0))
                          (_if '$print_help (i64.eq (i64.const 1) (call '$str_sym_comp (i64.const k_debug_help_msg_val) (local.get '$str) (i64.const 0) (i64.const 1) (i64.const 0)))
                               (then
                                 (call '$print (i64.const k_debug_help_info_msg_val))
                                 (generate_drop  (local.get '$str))
                                 (br '$varadic_loop)
                               )
                          )
                          (_if '$print_st (i64.eq (i64.const 1) (call '$str_sym_comp (i64.const k_debug_print_st_msg_val) (local.get '$str) (i64.const 0) (i64.const 1) (i64.const 0)))
                               (then
                                 (local.set '$tmp_read (global.get '$stack_trace))
                                 (block '$print_loop_exit
                                        (_loop '$print_loop
                                               (br_if '$print_loop_exit (i64.eq (i64.const nil_val) (local.get '$tmp_read)))
                                               (call '$print (local.get '$tmp_evaled))
                                               (local.set '$tmp_evaled (i64.add (local.get '$tmp_evaled) (i64.const 2)))
                                               (call '$print (i64.const space_msg_val))
                                               (call '$print (i64.load 0 (extract_ptr_code (local.get '$tmp_read))))
                                               (call '$print (i64.const newline_msg_val))
                                               (local.set '$tmp_read (i64.load 16 (extract_ptr_code (local.get '$tmp_read))))
                                               (br '$print_loop)
                                        )
                                 )
                                 (generate_drop  (local.get '$str))
                                 (br '$varadic_loop)
                               )
                          )
                          (_if '$print_envs (i64.eq (i64.const 1) (call '$str_sym_comp (i64.const k_debug_print_envs_msg_val) (local.get '$str) (i64.const 0) (i64.const 1) (i64.const 0)))
                               (then
                                 (local.set '$tmp_read (global.get '$stack_trace))
                                 (block '$print_loop_exit
                                        (_loop '$print_loop
                                               (br_if '$print_loop_exit (i64.eq (i64.const nil_val) (local.get '$tmp_read)))
                                               (call '$print (local.get '$tmp_evaled))
                                               (call '$print (i64.const space_msg_val))
                                               (call '$print (i64.load 8 (extract_ptr_code (local.get '$tmp_read))))
                                               (local.set '$tmp_evaled (i64.add (local.get '$tmp_evaled) (i64.const 2)))
                                               (call '$print (i64.const newline_msg_val))
                                               (local.set '$tmp_read (i64.load 16 (extract_ptr_code (local.get '$tmp_read))))
                                               (br '$print_loop)
                                        )
                                 )
                                 (generate_drop  (local.get '$str))
                                 (br '$varadic_loop)
                               )
                          )
                          (_if '$print_all (i64.eq (i64.const 1) (call '$str_sym_comp (i64.const k_debug_print_all_msg_val) (local.get '$str) (i64.const 0) (i64.const 1) (i64.const 0)))
                               (then
                                 (local.set '$tmp_read (global.get '$stack_trace))
                                 (block '$print_loop_exit
                                        (_loop '$print_loop
                                               (br_if '$print_loop_exit (i64.eq (i64.const nil_val) (local.get '$tmp_read)))
                                               (call '$print (local.get '$tmp_evaled))
                                               (local.set '$tmp_evaled (i64.add (local.get '$tmp_evaled) (i64.const 2)))
                                               (call '$print (i64.const space_msg_val))
                                               (call '$print (i64.load 0 (extract_ptr_code (local.get '$tmp_read))))
                                               (call '$print (i64.const space_msg_val))
                                               (call '$print (i64.load 8 (extract_ptr_code (local.get '$tmp_read))))
                                               (call '$print (i64.const newline_msg_val))
                                               (local.set '$tmp_read (i64.load 16 (extract_ptr_code (local.get '$tmp_read))))
                                               (br '$print_loop)
                                        )
                                 )
                                 (generate_drop  (local.get '$str))
                                 (br '$varadic_loop)
                               )
                          )
                          (_if '$abort (i64.eq (i64.const 1) (call '$str_sym_comp (i64.const k_debug_abort_msg_val) (local.get '$str) (i64.const 0) (i64.const 1) (i64.const 0)))
                               (then
                                    (generate_drop  (local.get '$str))
                                    (unreachable)
                               )
                          )

                          (_if '$redebug (i64.eq (i64.const 1) (call '$str_sym_comp (i64.const k_debug_redebug_msg_val) (local.get '$str) (i64.const 0) (i64.const 1) (i64.const 0)))
                               (then
                                 (generate_drop  (local.get '$str))
                                 (global.get '$debug_func_to_call)
                                 (global.get '$debug_params_to_call)
                                 (global.get '$debug_env_to_call)

                                 (local.set '$tmp_evaled (call_indirect
                                     ;type
                                     k_log
                                     ;table
                                     0
                                     ;params
                                     (generate_dup (global.get '$debug_params_to_call))
                                     ;top_env
                                     (generate_dup (global.get '$debug_env_to_call))
                                     ; static env
                                     (extract_func_env_code (generate_dup (global.get '$debug_func_to_call)))
                                     ;func_idx
                                     (extract_func_idx_code (global.get '$debug_func_to_call))
                                 ))

                                 (call '$print (local.get '$tmp_evaled))
                                 (generate_drop (local.get '$tmp_evaled))
                                 (call '$print (i64.const newline_msg_val))

                                 (global.set '$debug_env_to_call)
                                 (global.set '$debug_params_to_call)
                                 (global.set '$debug_func_to_call)
                                 (br '$varadic_loop)
                               )
                          )


                          ;(call '$print (i64.const  pre_read_val))
                          (local.set '$tmp_read (call '$read-string (call '$array1_alloc (local.get '$str)) (i64.const nil_val) (i64.const nil_val)))
                          ;(call '$print (i64.const post_read_val))
                          ;(call '$print (local.get '$tmp_read))
                          ;(call '$print (i64.const post_read_val))
                          (_if '$arr (is_type_code array_tag (local.get '$tmp_read))
                               (then
                                (_if '$arr (i32.ge_u (i32.const 2) (extract_size_code (local.get '$tmp_read)))
                                     (then
                                         (_if '$exit (i64.eq (i64.const 1) (call '$str_sym_comp (i64.const k_debug_exit_msg_val)
                                                                                                (i64.load 0 (extract_ptr_code (local.get '$tmp_read)))
                                                                                                (i64.const 0) (i64.const 1) (i64.const 0)))
                                              (then
                                                (local.set '$to_ret (call '$eval_helper (i64.load 8 (extract_ptr_code (local.get '$tmp_read))) (local.get '$d)))
                                                (generate_drop (local.get '$tmp_read))
                                                (br '$varadic_loop_exit)
                                              )
                                         )
                                     )
                                )
                               )
                          )
                          ;(call '$print (i64.const pre_eval_val))
                          (local.set '$tmp_evaled (call '$eval_helper (local.get '$tmp_read) (local.get '$d)))
                          ;(call '$print (i64.const post_eval_val))
                          (call '$print (local.get '$tmp_evaled))
                          (generate_drop (local.get '$tmp_read))
                          (generate_drop (local.get '$tmp_evaled))
                          (call '$print (i64.const newline_msg_val))
                          (br '$varadic_loop)
                    )
                )
                (global.set '$debug_depth  (i32.sub (global.get '$debug_depth) (i32.const 1)))
                drop_p_d
                (local.get '$to_ret)
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              (_ (true_print "made debug"))

              ((datasi memo k_vau_helper_msg_val) (compile-string-val datasi memo "k_vau_helper"))
              ((k_vau_helper          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$vau_helper '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $len i32) '(local $ptr i32) '(local $i_se i64) '(local $i_des i64) '(local $i_params i64) '(local $i_is_varadic i64) '(local $min_num_params i32) '(local $i_body i64) '(local $new_env i64) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)

                  ; get env ptr
                  (local.set '$ptr (extract_ptr_code (local.get '$s)))
                  ; get value array ptr
                  (local.set '$ptr (extract_ptr_code (i64.load 8 (local.get '$ptr))))


                  (local.set '$i_se             (generate_dup (i64.load  0 (local.get '$ptr))))
                  (local.set '$i_des                        (i64.load  8 (local.get '$ptr)))
                  (local.set '$i_params         (generate_dup (i64.load 16 (local.get '$ptr))))
                  (local.set '$i_is_varadic                 (i64.load 24 (local.get '$ptr)))
                  (local.set '$i_body           (generate_dup (i64.load 32 (local.get '$ptr))))


                  ; reusing len for i_params
                  (local.set '$len (extract_size_code (local.get '$i_params)))
                  (local.set '$ptr (extract_ptr_code  (local.get '$i_params)))

                  ; each branch consumes i_params, p, d, and i_se
                  (_if '$varadic
                        (i64.eq (local.get '$i_is_varadic) (i64.const true_val))
                        (then
                            (_if '$using_d_env
                                  (i64.ne (local.get '$i_des) (i64.const nil_val))
                                  (then
                                      (local.set '$min_num_params (i32.sub (local.get '$len) (i32.const 2)))
                                      (_if '$wrong_no_params
                                           ; with both de and varadic, needed params is at least two less than the length of our params
                                           (i32.lt_u (extract_size_code (local.get '$p)) (local.get '$min_num_params))
                                           (then (call '$print (i64.const bad_params_number_msg_val))
                                                 (unreachable)))

                                           (local.set '$new_env (call '$env_alloc
                                                                       (local.get '$i_params)
                                                                       (call '$concat (call '$array3_alloc (call '$slice_impl (generate_dup (local.get '$p))
                                                                                                                              (i32.const 0)
                                                                                                                              (local.get '$min_num_params))
                                                                                                           (call '$array1_alloc (call '$slice_impl (local.get '$p)
                                                                                                                                                   (local.get '$min_num_params)
                                                                                                                                                   (i32.const -1)))
                                                                                                           (call '$array1_alloc (local.get '$d)))
                                                                                      (i64.const nil_val)
                                                                                      (i64.const nil_val))
                                                                       (local.get '$i_se)))
                                  )
                                  (else
                                      (local.set '$min_num_params (i32.sub (local.get '$len) (i32.const 1)))
                                      (_if '$wrong_no_params
                                           (i32.lt_u (extract_size_code (local.get '$p)) (local.get '$min_num_params))
                                           (then (call '$print (i64.const bad_params_number_msg_val))
                                                 (unreachable)))

                                           (local.set '$new_env (call '$env_alloc
                                                                       (local.get '$i_params)
                                                                       (call '$concat (call '$array2_alloc (call '$slice_impl (generate_dup (local.get '$p))
                                                                                                                              (i32.const 0)
                                                                                                                              (local.get '$min_num_params))
                                                                                                           (call '$array1_alloc (call '$slice_impl (local.get '$p)
                                                                                                                                                   (local.get '$min_num_params)
                                                                                                                                                   (i32.const -1))))
                                                                                      (i64.const nil_val)
                                                                                      (i64.const nil_val))
                                                                       (local.get '$i_se)))
                                           (generate_drop (local.get '$d))
                                  )
                            )
                        )
                        (else
                            (_if '$using_d_env
                                  (i64.ne (local.get '$i_des) (i64.const nil_val))
                                  (then
                                      (local.set '$min_num_params (i32.sub (local.get '$len) (i32.const 1)))
                                      (_if '$wrong_no_params
                                           (i32.ne (extract_size_code (local.get '$p)) (local.get '$min_num_params))
                                           (then (call '$print (i64.const bad_params_number_msg_val))
                                                 (unreachable)))

                                           (local.set '$new_env (call '$env_alloc
                                                                       (local.get '$i_params)
                                                                       (call '$concat (call '$array2_alloc (local.get '$p)
                                                                                                           (call '$array1_alloc (local.get '$d)))
                                                                                      (i64.const nil_val)
                                                                                      (i64.const nil_val))
                                                                       (local.get '$i_se)))
                                  )
                                  (else
                                      (local.set '$min_num_params (local.get '$len))
                                      (_if '$wrong_no_params
                                           (i32.ne (extract_size_code (local.get '$p)) (local.get '$min_num_params))
                                           (then (call '$print (i64.const bad_params_number_msg_val))
                                                 (unreachable)))

                                           (local.set '$new_env (call '$env_alloc
                                                                       (local.get '$i_params)
                                                                       (local.get '$p)
                                                                       (local.get '$i_se)))
                                           (generate_drop (local.get '$d))
                                  )
                            )
                        )
                  )

                  (call '$eval_helper (local.get '$i_body) (local.get '$new_env))

                  (generate_drop (local.get '$i_body))
                  (generate_drop (local.get '$new_env))
                  (generate_drop (local.get '$s))
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              ((datasi memo k_env_symbol_val) (compile-symbol-val datasi memo 'env_symbol))
              ((datasi memo k_des_symbol_val) (compile-symbol-val datasi memo 'des_symbol))
              ((datasi memo k_param_symbol_val) (compile-symbol-val datasi memo 'param_symbol))
              ((datasi memo k_varadic_symbol_val) (compile-symbol-val datasi memo 'varadic_symbol))
              ((datasi memo k_body_symbol_val) (compile-symbol-val datasi memo 'body_symbol))
              ((datasi memo k_and_symbol_val) (compile-symbol-val datasi memo '&))

              ((k_env_dparam_body_array_loc k_env_dparam_body_array_len datasi) (alloc_data (concat (i64_le_hexify k_env_symbol_val)
                                                                                                    (i64_le_hexify k_des_symbol_val)
                                                                                                    (i64_le_hexify k_param_symbol_val)
                                                                                                    (i64_le_hexify k_varadic_symbol_val)
                                                                                                    (i64_le_hexify k_body_symbol_val)
                                                                                            ) datasi))
              (k_env_dparam_body_array_val (mk_array_value 5 k_env_dparam_body_array_loc))

              (_ (true_print "about to make vau"))

              ((datasi memo k_vau_msg_val) (compile-string-val datasi memo "k_vau"))
              ((k_vau           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$vau           '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $len i32) '(local $ptr i32) '(local $i i32) '(local $des i64) '(local $params i64) '(local $is_varadic i64) '(local $body i64) '(local $tmp i64) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)

                (local.set '$len (extract_size_code (local.get '$p)))
                (local.set '$ptr (extract_ptr_code  (local.get '$p)))

                (_if '$using_d_env
                      (i32.eq (i32.const 3) (local.get '$len))
                      (then
                          (local.set '$des      (generate_dup (i64.load 0  (local.get '$ptr))))
                          (local.set '$params   (generate_dup (i64.load 8  (local.get '$ptr))))
                          (local.set '$body     (generate_dup (i64.load 16 (local.get '$ptr))))
                          )
                      (else
                          (local.set '$des      (i64.const nil_val))
                          (local.set '$params   (generate_dup (i64.load 0  (local.get '$ptr))))
                          (local.set '$body     (generate_dup (i64.load 8  (local.get '$ptr))))
                      )
                )

                (local.set '$is_varadic   (i64.const false_val))
                (local.set '$len (extract_size_code (local.get '$params)))
                (local.set '$ptr (extract_ptr_code  (local.get '$params)))
                (local.set '$i (i32.const 0))
                (block '$varadic_break
                    (_loop '$varadic_loop
                        (br_if '$varadic_break (i32.eq (local.get '$i) (local.get '$len)))
                        (_if 'this_varadic
                             (i64.eq (i64.const 1)
                                     (call '$str_sym_comp (i64.const k_and_symbol_val) (i64.load (local.get '$ptr)) (i64.const 0) (i64.const 1) (i64.const 0)))
                             (then
                                 (local.set '$is_varadic (i64.const true_val))

                                 (local.set '$tmp (call '$array1_alloc (generate_dup (i64.load 8 (local.get '$ptr)))))
                                 (local.set '$params (call '$concat (call '$array2_alloc (call '$slice_impl (local.get '$params) (i32.const 0) (local.get '$i))
                                                                                         (local.get '$tmp))
                                                                    (i64.const nil_val)
                                                                    (i64.const nil_val)))

                                 (br '$varadic_break)
                             )
                        )
                        (local.set '$ptr (i32.add (local.get '$ptr) (i32.const 8)))
                        (local.set '$i   (i32.add (local.get '$i)   (i32.const 1)))
                        (br '$varadic_loop)
                    )
                )
                (_if '$using_d_env
                      (i64.ne (local.get '$des) (i64.const nil_val))
                      (then
                           (local.set '$params (call '$concat (call '$array2_alloc (local.get '$params) (call '$array1_alloc (generate_dup (local.get '$des))))
                                                     (i64.const nil_val)
                                                     (i64.const nil_val)))
                      )
                )

                ;  <func_idx29>|<env_ptr29><usesde1><wrap1>0001
                (mk_comb_val_code_rc_wrap0 (- k_vau_helper dyn_start)
                                       (call '$env_alloc (i64.const k_env_dparam_body_array_val)
                                                         (call '$array5_alloc (local.get '$d)
                                                                              (local.get '$des)
                                                                              (local.get '$params)
                                                                              (local.get '$is_varadic)
                                                                              (local.get '$body))
                                                         (i64.const nil_val))
                                       (i64.ne (local.get '$des) (i64.const nil_val)))

                (generate_drop (local.get '$p))
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))
              (_ (true_print "made vau"))
              ((datasi memo k_cond_msg_val) (compile-string-val datasi memo "k_cond"))
              ((k_cond          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$cond          '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $len i32) '(local $ptr i32) '(local $tmp i64) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                  set_len_ptr
                  ;yall
                  (block '$cond_loop_break_ok
                      (block '$cond_loop_break_err
                          (_loop '$cond_loop
                              (br_if '$cond_loop_break_err (i32.le_s (local.get '$len) (i32.const 1)))

                              (local.set '$tmp (call '$eval_helper (i64.load 0 (local.get '$ptr)) (local.get '$d)))
                              (_if 'cond_truthy
                                   (truthy_test (local.get '$tmp))
                                   (then
                                       (generate_drop (local.get '$tmp))
                                       (local.set '$tmp (call '$eval_helper (i64.load 8 (local.get '$ptr)) (local.get '$d)))
                                       (br '$cond_loop_break_ok)
                                   )
                                   (else (generate_drop (local.get '$tmp)))
                              )
                              (local.set '$len (i32.sub (local.get '$len) (i32.const 2)))
                              (local.set '$ptr (i32.add (local.get '$ptr) (i32.const 16)))
                              (br '$cond_loop)
                          )
                      )
                      (call '$print (i64.const no_true_cond_msg_val))
                      (unreachable)
                  )
                  (local.get '$tmp)
                  drop_p_d
              ))))
              ((func_idx funcs) (array (+ 1 func_idx) (concat funcs (func '$dummy '(result i64) (i64.const 0)))))

              (get_passthrough (dlambda (hash (datasi funcs memo env pectx inline_locals)) (dlet ((r (get-value-or-false memo hash)))
                                                                     (if r (array r nil nil (array datasi funcs memo env pectx inline_locals)) #f))))


              ; This is the second run at this, and is a little interesting
              ; It can return a value OR code OR an error string. An error string should be propegated,
              ; unless it was expected as a possiblity, which can happen when compling a call that may or
              ; may not be a Vau. When it recurses, if the thing you're currently compiling could be a value
              ; but your recursive calls return code, you will likely have to swap back to code.

              ; ctx is (datasi funcs memo env pectx inline_locals)
              ; return is (value? code? error? (datasi funcs memo env pectx inline_locals))

              (let_like_inline_closure (lambda (func_value containing_env_idx)   (and (comb? func_value)
                                                                                  (not (.comb_varadic func_value))
                                                                                  (= containing_env_idx (.marked_env_id (.comb_env func_value)))
                                                                                  (= nil (.comb_des func_value)))))
              (is_prim_function_call (lambda (c s) (and (marked_array? c) (not (.marked_array_is_val c)) (<= 2 (len (.marked_array_values c)))
                                                        (prim_comb? (idx (.marked_array_values c) 0)) (= s (.prim_comb_sym (idx (.marked_array_values c) 0))))))

              ; Ok, we're pulling out the call stuff out of compile
              ;   Wrapped vs unwrapped
              ;   Y combinator elimination
              ;         Eta reduction?
              ;   tail call elimination
              ;   dynamic call unval-partial-eval branch
              ;
              ; Rembember to account for (dont_compile dont_lazy_env dont_y_comb dont_prim_inline dont_closure_inline)

              ; (<this_data>... <sub_data>)

              ; call-info will be a fairly simple pre-order traversal (looking at caller before params)
              ; infer-type has to walk though cond in pairs, special handle the (and ) case, and adjust parameters for veval
              ; perceus is weird, as it has to look at the head to determine how to order/combine the children, as well as an extra sub-data for the call itself (though I guess this is just part of the node data)

              ; Starting with only dynamic call unval
              ; TODO: tce-data

              (call-info (rec-lambda call-info (c env pectx) (cond
                        ((val? c)                                                (array nil nil pectx))
                        ((and (marked_symbol? c) (.marked_symbol_is_val c))      (array nil nil pectx))
                        ((marked_symbol? c)                                      (array nil nil pectx))
                        ((marked_env? c)                                         (array nil nil pectx))
                        ((prim_comb? c)                                          (array nil nil pectx))
                        ((and (marked_array? c) (.marked_array_is_val c))        (array nil nil pectx))
                        ((comb? c)                                               (array nil nil pectx))

                        ((and (marked_array? c) (let_like_inline_closure (idx (.marked_array_values c) 0) (.marked_env_id env))) (dlet (
                              (func_param_values (.marked_array_values c))
                              (func (idx func_param_values 0))
                              ; TODO: pull errors out of here
                              ;(param_data (map (lambda (x) (call-info x env)) (slice func_param_values 1 -1)))
                              ; TODO: pull errors out of here
                              ; mk tmp env
                              ;(body_data (call-info (.comb_body func tmp_env)))
                        ) (array nil nil pectx))) ;(array nil (cons body_data param_data))))

                        ((is_prim_function_call c 'veval)  (dlet (
                               (func_param_values (.marked_array_values c))
                               (num_params (- (len func_param_values) 1))
                               (params (slice func_param_values 1 -1))
                               ; These can't be fatal either
                               ;(_ (if (!= 2 num_params) (error "call to veval has != 2 params!")))
                               ;(_ (if (not (marked_env? (idx params 1))) (error "call to veval has not marked_env second param")))

                               ; TODO: pull errors out of here
                               ;(sub_data (array nil (call-info (idx params 0) (idx params 1)) nil))
                        ) (array nil nil pectx))) ;(array nil sub_data)))

                        (true (dlet (
                              ; obv need to handle possible dynamic calls with an additional unval side, but also be careful of infinite recursion (as we had happen on compile before)
                              ;     due to the interaction of partial eval and unval (previously in compile) here
                              ; might need to check for (is_prim_function_call c 'vcond) for recursion?

                              ; the basic check is is this dynamic or not, and if so (and thus we don't know the wrap level)
                              ;     we need to
                              ; if not dynamic, just recurse as normal
                              ;     assert wrap-level == 0 or == -1

                               (func_param_values (.marked_array_values c))
                               (func (idx func_param_values 0))
                         ;      ; TODO: pull errors out of here
                         ;      (sub_data (map (lambda (x) (call-info x env)) func_param_values))
                         ;      ; TODO: pull errors out of here
                         ;      (our_data (cond ((and (comb? func) ( = (.comb_wrap_level func) 0)) nil)
                         ;                      ((and (comb? func) (!= (.comb_wrap_level func) 1)) (error "bad wrap level call-info")) ; this is a tad tricky - I wanted to just have error here, but
                         ;                                                                                                             ; *concievably this is the result of wrongly evaluted code based on this
                         ;                                                                                                             ; very method of prediction. Instead, we need to error here,
                         ;                                                                                                             ; and have that count as erroing out of the compile.
                         ;                                                                                                             ; How best should we do that, I wonder?
                         ;                      ((prim_comb? func)                                 nil)
                         ;                      (true                                              (dlet (
                         ;                          ((ok x) (try_unval x (lambda (_) nil)))
                         ;                          (err (if (not ok) "couldn't unval in compile" err))
                         ;                          ((pectx e pex) (mif err  (array pectx err nil))
                         ;                                                   ;                    x only_head env env_stack       pectx indent force
                         ;                                                   (partial_eval_helper x false     env (array nil nil) pectx 1      false))))
                         ;                      ) nil)
                         ;                ))
                        ;) (array our_data sub_data))
                        ) (array nil nil pectx))) ;(array nil sub_data)))
              )))

              ; type is a bit generic, both the runtime types + length of arrays
              ;
              ; (array <symbol_identifier> maybe_rc <length or false for arrays/strings>)
              ;
              ; there are three interesting things to say about types
              ; the x=type guarentee map (x has this type. i.e, constants, being after an assertion, being inside a cond branch with a true->x=type assertion
              ; the x=type assertion map (x needs to have this type, else trap. Comes from calling a function with a typed parameter)
              ; the true->x=type structure (if a particular value is true, than it implies that x=type. Happens based on cond branches with type/len/equality checks in contitional)

              ; call
              ;   -y=true->(x=type...) structure
              ;   -type guarentee map
              ; return
              ;   -value type (or false)
              ;   -return value=true ->(x=type...)
              ;   -type assertion map
              ;   -extra data that should be passed back in (sub_results)
              ;
              ;
              ; the cache data structure is just what it returned. Sub-calls should pass in the extra data indexed appropriately
              (type_data_nil nil)
              (analysis_nil nil)
              (get-list-or (lambda (d k o) (dlet ((x (get-list d k)))
                                                 (mif x (idx x 1)
                                                        o))))
              (is_markable           (lambda (x)   (or (and (marked_symbol? x) (not (.marked_symbol_is_val x)))
                                                       (and (marked_array?  x) (not (.marked_array_is_val  x)))
                                                   )))
              (is_markable_idx       (lambda (c i) (and (marked_array? c) (< i (len (.marked_array_values c))) (is_markable (idx (.marked_array_values c) i)))))
              (mark                  (lambda (x)   (or (and (marked_symbol? x) (not (.marked_symbol_is_val x)) (.marked_symbol_value x))
                                                       (and (marked_array?  x) (not (.marked_array_is_val  x)) (.hash x))
                                                   )))
              (mark_idx              (lambda (c i) (and (marked_array? c) (< i (len (.marked_array_values c))) (mark (idx (.marked_array_values c) i)))))
              (combine-list          (lambda (mf a b) (dlet (
                                                      ;(_ (true_print "going to combine " a " and " b))
                                                      (r (cond ((= false a) b)
                                                               ((= false b) a)
                                                               (true        (dlet (
                                                                             (total (concat a b))
                                                                             ;(_ (true_print " total is " total))
                                                                             ) (foldl (lambda (acc i) (dlet (
                                                                                                             ;(_ (true_print "looking at " i))
                                                                                                             ;(_ (true_print "       which is " (idx total i)))
                                                                                                             (r (concat acc 
                                                                                                              (foldl (dlambda (o_combined j) (mif (= nil o_combined)
                                                                                                                                                  nil
                                                                                                                                                  (dlet (
                                                                                                                                                    (combined (idx o_combined 0))
                                                                                                                                                   ;(_ (true_print "          inner looking at " j))
                                                                                                                                                   ;(_ (true_print "                which is " (idx total j)))
                                                                                                                                                   ;(_ (true_print "                combined currently is " combined))
                                                                                                                                                    (r (mif (= (idx combined 0) (idx (idx total j) 0))
                                                                                                                                                            (mif (> i j )
                                                                                                                                                                (array)
                                                                                                                                                                (array (array (idx combined 0)
                                                                                                                                                                              (mf (idx combined 1) (idx (idx total j) 1)))))
                                                                                                                                                            (array combined)))
                                                                                                                                                   ;(_ (true_print "                r was " r))
                                                                                                                                                    ) r)))
                                                                                                                     (array (idx total i))
                                                                                                                     (range 0 (len total)))))
                                                                                                             ;(_ (true_print "did  " i " was " r))
                                                                                                             ) r)
                                                                                        )
                                                                                      (array)
                                                                                      (range 0 (len total)))))))
                                                      ;(_ (true_print "combining " a " and " b " type maps gave us " r))
                                                      ) r)))
              (combine-type        (lambda (a b) (dlet (
                                                      ;(_ (true_print "combinging types " a " and " b))
                                                      (r (cond ((= false a)                            b)
                                                               ((= false b)                            a)
                                                               ((and (idx a 0)     (idx b 0)
                                                                     (!= (idx a 0) (idx b 0)))         (error "merge inequlivant types " a b))
                                                               ((and (idx a 2)     (idx b 2)
                                                                 (!= (idx a 2)     (idx b 2)))         (error "merge inequlivant tlen " a b))
                                                               (true                                   (array (or (idx a 0) (idx b 0)) (and (idx a 1) (idx b 1)) (or (idx a 2) (idx b 2))))
                                                      ))
                                                      ;(_ (true_print "combined em to " r))
                                                      ) r)))
              (infer_types (rec-lambda infer_types (c env_id implies guarentees) (cond
                        ((and (val? c) (int?    (.val c)))                                (array (array 'int  false false)                               false                    empty_dict-list type_data_nil))
                        ((and (val? c) (= true  (.val c)))                                (array (array 'bool false false)                               false                    empty_dict-list type_data_nil))
                        ((and (val? c) (= false (.val c)))                                (array (array 'bool false false)                               false                    empty_dict-list type_data_nil))
                        ((and (val? c) (str?    (.val c)))                                (array (array 'str  false false (len (.val c)))                false                    empty_dict-list type_data_nil))
                        ((and (marked_symbol? c) (.marked_symbol_is_val c))               (array (array 'sym  false false)                               false                    empty_dict-list type_data_nil))
                        ((marked_symbol? c)                                            (array (get-list-or guarentees (.marked_symbol_value c) false) (get-list-or implies (.marked_symbol_value c) false) empty_dict-list type_data_nil))
                        ((marked_env? c)                                                  (array (array 'env  true false)                                false                    empty_dict-list type_data_nil))
                        ((comb? c)                                                        (array (array 'comb true false)                                false                    empty_dict-list type_data_nil))
                        ((prim_comb? c)                                                   (array (array 'prim_comb false)                                false                    empty_dict-list type_data_nil))
                        ((and (marked_array? c) (.marked_array_is_val c))                 (array (array 'arr  false (len (.marked_array_values c)))      false                    empty_dict-list type_data_nil))
                        ; The type predicates (ADD ASSERTS TO THESE)
                        ((and (is_prim_function_call c 'array?)    (is_markable_idx c 1)) (array (array 'bool false false)   (put-list empty_dict-list (mark_idx c 1) (array 'arr  true false))  empty_dict-list (map (lambda (x) (infer_types x env_id implies guarentees)) (.marked_array_values c))))
                        ((and (is_prim_function_call c 'nil?)      (is_markable_idx c 1)) (array (array 'bool false false)   (put-list empty_dict-list (mark_idx c 1) (array 'arr  true 0))      empty_dict-list (map (lambda (x) (infer_types x env_id implies guarentees)) (.marked_array_values c))))
                        ((and (is_prim_function_call c 'bool?)     (is_markable_idx c 1)) (array (array 'bool false false)   (put-list empty_dict-list (mark_idx c 1) (array 'bool false false)) empty_dict-list (map (lambda (x) (infer_types x env_id implies guarentees)) (.marked_array_values c))))
                        ((and (is_prim_function_call c 'env?)      (is_markable_idx c 1)) (array (array 'bool false false)   (put-list empty_dict-list (mark_idx c 1) (array 'env  true false))  empty_dict-list (map (lambda (x) (infer_types x env_id implies guarentees)) (.marked_array_values c))))
                        ((and (is_prim_function_call c 'combiner?) (is_markable_idx c 1)) (array (array 'bool false false)   (put-list empty_dict-list (mark_idx c 1) (array 'comb true false))  empty_dict-list (map (lambda (x) (infer_types x env_id implies guarentees)) (.marked_array_values c))))
                        ((and (is_prim_function_call c 'string?)   (is_markable_idx c 1)) (array (array 'bool false false)   (put-list empty_dict-list (mark_idx c 1) (array 'str  true false))  empty_dict-list (map (lambda (x) (infer_types x env_id implies guarentees)) (.marked_array_values c))))
                        ((and (is_prim_function_call c 'int?)      (is_markable_idx c 1)) (array (array 'bool false false)   (put-list empty_dict-list (mark_idx c 1) (array 'int  false false)) empty_dict-list (map (lambda (x) (infer_types x env_id implies guarentees)) (.marked_array_values c))))
                        ((and (is_prim_function_call c 'symbol?)   (is_markable_idx c 1)) (array (array 'bool false false)   (put-list empty_dict-list (mark_idx c 1) (array 'sym  false false)) empty_dict-list (map (lambda (x) (infer_types x env_id implies guarentees)) (.marked_array_values c))))
                        ; len case
                        ; either (= (len markable) number) or (= number (len markable))
                        ((and (is_prim_function_call c '=) (= 3 (len (.marked_array_values c)))) (dlet (
                              ((mi ni) (cond ((and (marked_array? (idx (.marked_array_values c) 1)) (is_prim_function_call (idx (.marked_array_values c) 1) 'len) (is_markable_idx (idx (.marked_array_values c) 1) 1)
                                                  (val? (idx (.marked_array_values c) 2)) (int? (.val (idx (.marked_array_values c) 2))))                                                                               (array 1 2))
                                             ((and (marked_array? (idx (.marked_array_values c) 2)) (is_prim_function_call (idx (.marked_array_values c) 2) 'len) (is_markable_idx (idx (.marked_array_values c) 2) 1)
                                                  (val? (idx (.marked_array_values c) 1)) (int? (.val (idx (.marked_array_values c) 1))))                                                                               (array 2 1))
                                             (true                                                                                                                                                                (array false false))))
                              ) (array (array 'bool false false)
                                       (mif mi (put-list empty_dict-list (mark_idx (idx (.marked_array_values c) mi) 1) (array false true (.val (idx (.marked_array_values c) ni))))
                                               false)
                                       empty_dict-list
                                       (map (lambda (x) (infer_types x env_id implies guarentees)) (.marked_array_values c)))))

                        ; let case
                        ((and (marked_array? c) ;(>= 2 (len (.marked_array_values c)))
                              (let_like_inline_closure (idx (.marked_array_values c) 0) env_id)) (dlet (
                            ; map recurse over arguments
                            ;(_ (true_print "entering let"))
                            (func (idx (.marked_array_values c) 0))
                            (params (.comb_params func))
                            (func_sub (infer_types func env_id implies guarentees))
                            ;( _ (true_print "Pre let sub collection, implies is " implies " and guarentees is " guarentees))
                            ;( _ (true_print "   and params are " params))
                            ( (sub_implies sub_guarentees psub_data) (foldl (dlambda ((sub_implies sub_guarentees running_sub_data) i) (dlet ((psym (idx params (- i 1)))
                                                                                                                   ((ttyp timpl assertions sub_sub_data) (infer_types (idx (.marked_array_values c) i) env_id implies guarentees))
                                                                                                                  ) (array ;(combine-list (lambda (a b) (combine-list combine-type a b)) (put-list empty_dict-list psym timpl) sub_implies)
                                                                                                                           ;(combine-list combine-type (put-list empty_dict-list psym ttyp) sub_guarentees)
                                                                                                                           (put-list sub_implies psym timpl)
                                                                                                                           (put-list sub_guarentees psym ttyp)
                                                                                                                           (concat running_sub_data (array (array ttyp timpl assertions sub_sub_data))))))
                                                                  (array implies guarentees
                                                                         ;(array func_sub)
                                                                         (array)
                                                                         ) (range 1 (len (.marked_array_values c)))))
                            ;( _ (true_print "based on inline (let) case " params " we have sub_implies " sub_implies " and sub_guarentees " sub_guarentees) )
                            ((ttyp timpl assertion inl_subdata) (infer_types (.comb_body func) (.comb_id func) sub_implies sub_guarentees))
                            ; remove the implication if it's about something that only exists inside the inlined function (a parameter)
                            ; TODO: does this have to check for env_symbol?
                            (timpl (mif (and timpl (in_array (idx timpl 0) params)) false timpl))
                            ;( _ (true_print "final result of inline " params " is type " ttyp " and impl " timpl))
                            ;(_ (true_print "exiting let"))
                        ) (array ttyp timpl empty_dict-list (concat (array (array ttyp timpl assertion inl_subdata)) psub_data))))
                        ; cond case
                        ; start simply by making this only an 'and'-style recognizer
                        ; if (vcond p b true p) (or (vcond p b true false)) combine b's implies with p's implies
                        ((is_prim_function_call c 'vcond)  (dlet (

                               (func_param_values (.marked_array_values c))
                               (num_params (- (len func_param_values) 1))
                               (params (slice func_param_values 1 -1))
                               (func (idx func_param_values 0))
                               ((impls sub_data)  (foldl (dlambda ((impls sub_data) i) (dlet (
                                                             ((ptyp pimpl p_assertion p_subdata) (infer_types (idx params (+ (* 2 i) 0)) env_id implies guarentees))
                                                             ;(_ (true_print "about to combine pimpl and guarentees in cond, they are " pimpl "and " guarentees))
                                                             ((btyp bimpl b_assertion b_subdata) (infer_types (idx params (+ (* 2 i) 1)) env_id implies (combine-list combine-type pimpl guarentees)))
                                                             ;(_ (true_print "about to combine pimpl and bimpl in cond, they are " pimpl " and " bimpl))
                                                             (combined_impl (combine-list combine-type pimpl bimpl))
                                                             ;(_ (true_print "combined is " combined_impl))
                                                         ) (array (concat impls (array combined_impl)) (concat sub_data (array (array ptyp pimpl p_assertion p_subdata) (array btyp bimpl b_assertion b_subdata))))))
                                                         (array (array) (array (infer_types func env_id implies guarentees)))
                                                         (range 0 (/ num_params 2))
                                                  ))

                        ) (mif (and (= 5 (len (.marked_array_values c))) (val? (idx (.marked_array_values c) 3)) (= true (.val (idx (.marked_array_values c) 3)))
                                  (or (and (val? (idx (.marked_array_values c) 4)) (= false (.val (idx (.marked_array_values c) 4))))
                                      (= (.hash (idx (.marked_array_values c) 1)) (.hash (idx (.marked_array_values c) 4)))))          
                             (array false (idx impls 0) empty_dict-list sub_data)
                             (array false false         empty_dict-list sub_data))))

                        ((is_prim_function_call c 'veval)  (dlet (
                               (func_param_values (.marked_array_values c))
                               (num_params (- (len func_param_values) 1))
                               (params (slice func_param_values 1 -1))
                               (_ (if (!= 2 num_params) (error "call to veval has != 2 params!")))
                               (_ (if (not (marked_env? (idx params 1))) (error "call to veval has not marked_env second param")))

                               (new_env_id      (.marked_env_id (idx params 1)))

                               (sub_data (array (infer_types func env_id implies guarentees)
                                                (infer_types (idx params 0) new_env_id  empty_dict-list empty_dict-list)
                                                (infer_types (idx params 1) env_id implies guarentees)))
                        ) (array btyp false empty_dict-list sub_data)))

                        ; generic combiner calls - recurse into all
                        ((and (marked_array? c) (not (.marked_array_is_val c))) (dlet (
                              ; this will have to gather assertions in the future
                              ;(_ (true_print "  doing infer-types for random call "))
                              (sub_results (map (lambda (x) (infer_types x env_id implies guarentees)) (.marked_array_values c)))
                              ;(_ (true_print "  done infer-types for random call "))
                                 ; I belive this .hash doesn't do anything
                        ) (array (get-list-or guarentees (.hash c) false) false empty_dict-list sub_results)))

                        ; fallthrough
                        (true                                                             (array false                                                   false                    empty_dict-list type_data_nil))
              )))
              (cached_infer_types_idx (lambda (c env_id cache i) (dlet (
                                                                ;(_ (true_print "doing infer-types-idx for " (true_str_strip c)))
                                                                ;(_ (true_print "doing infer-types-idx i " i))
                                                                ;(_ (true_print "doing infer-types-idx with " cache))
                                                                ;(_ (true_print "doing infer-types-idx, cache is real? " (mif cache true false)))
                                                                ( r (mif cache (idx (idx cache 3) i) (infer_types (idx (.marked_array_values c) i) env_id empty_dict-list empty_dict-list)))
                                                                ;(_ (true_print "done infer-types-idx"))
                                                                ) r)))
              (just_type              (lambda (analysis_data) (idx (idx analysis_data 0) 0)))
              (word_value_type?       (lambda (x) (or (= 'int (idx x 0)) (= 'bool (idx x 0)) (= 'sym (idx x 0)))))

              ;
              ; Used map
              ; --------
              ;
              ; Ok, we start at a function, and initialize our map with all of our parameters mapped to false.
              ; we then traverse *backwards (only comes into play for calls, everything is a call wooo)*
              ; dynamic calls are rough and we have to assume they eat everything through the env.
              ; vcond has to be handled specially, starting at then end of each arm, joining with below at the
              ; end of the predicate, then going backwards through the predicate.
              ;
              ; Later we'll look at tracking individual indexes inside of arrays - this is based on
              ; type inference and very much can be path-dependent. (array destructuring should probs happen in
              ; the branch where we first have the full array type+length guarenteed?)
              ;
              ; all uses of used_data_nil need to be re-examined

              ; psudo_perceus takes in a used_map (after-node) and an env_id (for inlining checks) and returns a used_map (before-node) and (sub_results + used_map_after_node, if it would change it)

              ; used map also needs to track env_ids for env values that are partial?

              (used_data_nil nil)
              (empty_use_map false) ; used_map is (<list-dict s->true/false>/true(for all) upper) or false
              (push_used_map        (lambda                       (used_map params)   (array (foldl (lambda (m s) (put-list m s false)) empty_dict-list params) used_map)))
              (pop_used_map         (lambda                       (used_map)          (idx used_map 1)))
              (set_used_map         (rec-lambda set_used_map      (used_map s)        (mif (and used_map (!= true (idx used_map 0)))
                                                                                           (mif (get-list (idx used_map 0) s)
                                                                                                (array (put-list (idx used_map 0) s true) (idx used_map 1))
                                                                                                (array (idx used_map 0)                   (set_used_map (idx used_map 1) s)))
                                                                                           used_map)))
              (set_all_used_map     (rec-lambda set_all_used_map  (used_map)          (mif used_map
                                                                                          (array true (set_all_used_map (idx used_map 1)))
                                                                                          used_map)))
              (get_used_map         (rec-lambda get_used_map      (used_map s)        (mif used_map
                                                                                          (mif (= true (idx used_map 0))
                                                                                               true
                                                                                               (dlet ((r (get-list (idx used_map 0) s)))
                                                                                                     (mif r (idx r 1)
                                                                                                            (get_used_map (idx used_map 1) s))))
                                                                                          ; we treat not-found as true, as it must be inside an env, and persistent env's are cached and "used" till the end of the scope
                                                                                          true)))
              (combine_used_maps    (rec-lambda combine_used_maps (a b) (cond ((not a)                      b)
                                                                              ((not b)                      a)
                                                                              ((or (= true (idx a 0))
                                                                                   (= true (idx b 0)))      (array true (combine_used_maps (idx a 1) (idx b 1))))
                                                                              (true                         (array (foldl (lambda (a x) (mif (idx x 1) (put-list a (idx x 0) true)
                                                                                                                                                       a))
                                                                                                                          (idx a 0) (idx b 0))
                                                                                                                   (combine_used_maps (idx a 1) (idx b 1)))))))

              (pseudo_perceus (rec-lambda pseudo_perceus (c env_id knot_memo used_map_after) (dlet (
                                                                                                    ;(_ (true_print "pseudo_perceus " (true_str_strip c) " " used_map_after))
                                                                                                    ) (cond
                        ((val? c)                                                         (array used_map_after                                         (array used_map_after)))
                        ((prim_comb? c)                                                   (array used_map_after                                         (array used_map_after)))
                        ((and (marked_symbol? c) (.marked_symbol_is_val c))               (array used_map_after                                         (array used_map_after)))
                        ((and (marked_array?  c) (.marked_array_is_val  c))               (array used_map_after                                         (array used_map_after)))
                        ; this triggers the env access code, which will
                        ; traverse and realize every env until it reaches the right one,
                        ; which will thus consume *everything*
                        ((and (marked_env? c) (not (marked_env_real? c)))                 (array (set_all_used_map used_map_after)                      (array used_map_after)))
                        ((and (marked_env? c)      (marked_env_real? c))                  (array used_map_after                                         (array used_map_after)))
                        ; just fixed symbol lookup to use outer_s_env instead of s_env
                        ; for lookups that aren't expanded out (level <= inline_level),
                        ; so it doesn't reify envs. This symbol *might* be outside of the current
                        ; env chain though, so the set used shouldn't change it if the symbol's not
                        ; in the current map
                        ; ALSO - symbol sub_data stores if this is the owning sink of the symbol (based on if it wasn't used after)
                        ((and (marked_symbol? c) (not (.marked_symbol_is_val c)))         (array (set_used_map used_map_after (.marked_symbol_value c)) (array (not (get_used_map used_map_after (.marked_symbol_value c))) used_map_after)))
                        ; comb value just does its env
                        ((comb? c)                                                        (pseudo_perceus (.comb_env c) env_id knot_memo used_map_after))

                        ((is_prim_function_call c 'veval)  (dlet (
                               (func_param_values (.marked_array_values c))
                               (num_params (- (len func_param_values) 1))
                               (params (slice func_param_values 1 -1))
                               (_ (if (!= 2 num_params) (error "call to veval has != 2 params!")))
                               (_ (if (not (marked_env? (idx params 1))) (error "call to veval has not marked_env second param")))

                               (new_env_id      (.marked_env_id (idx params 1)))
                              (body_data                       (pseudo_perceus (idx params 0) new_env_id knot_memo empty_use_map))
                              ((used_map_pre_env env_sub_data) (pseudo_perceus (idx params 1) env_id     knot_memo used_map_after))

                        ) (array used_map_pre_env (array (array used_map_pre_env used_data_nil) body_data (array used_map_pre_env env_sub_data) used_map_after))))

                        ; cond case
                        ((is_prim_function_call c 'vcond)  (dlet (
                               (func_param_values (.marked_array_values c))
                               (num_params (- (len func_param_values) 1))
                               (params (slice func_param_values 1 -1))
                               ((used_map_pre sub_data)  (foldl (dlambda ((sub_used_map_after sub_data) i) (dlet (
                                                             ((used_map_pre_body_arm body_arm_sub_data) (pseudo_perceus (idx params (+ (* 2 i) 1)) env_id knot_memo used_map_after))
                                                             (used_map_post_pred (combine_used_maps sub_used_map_after used_map_pre_body_arm))
                                                             ((used_map_pre_pred         pred_sub_data) (pseudo_perceus (idx params (+ (* 2 i) 0)) env_id knot_memo used_map_post_pred))
                                                         ) (array used_map_pre_pred (concat (array (array used_map_pre_pred pred_sub_data) (array used_map_pre_body_arm body_arm_sub_data)) sub_data))))
                                                         (array used_map_after (array used_map_after))
                                                         (reverse_e (range 0 (/ num_params 2)))
                                                  ))
                        ) (array used_map_pre (cons (array used_data_nil used_map_pre) sub_data))))

                        ; generic combiner calls - recurse into all


                        ; generic call taxonomy
                        ;     unknown
                        ;           may take in reified env, set all to used, then do params (note will be generated as a branch, but the union of the branch will still be everything), then do func code
                        ;     known-val or Y-combiner knot tying
                        ;           takes in env, inlined - add all parameters to map as unused, recurse, then remove off extra env back to the smaller (but maybe modified env), then backwards through params
                        ;           takes in env, not inlined - same as unknown
                        ;           doesn't take in env - call itself won't do anything, move backwards through params and then func
                        ;
                        ; call needs an extra sub_data, which is before the call happens - nice to have for regular calls, key for inlined calls (with the full, un-trimmed pre-env)
                        ;     return pre_func, (func_data, param_1_data, param_2_data, param_3_data, (pre_call maybe_inline_subdata), post_call)

                        ; Ok, so three real cases, might-take-env, inline, and doesn't-take-env

                        ; YES remember to check for implicits on prim comb calls - (comb_takes_de? (lambda (x l) ...
                        ; YES remember to check for Y-combiner recursion knot tying - (and (!= nil (.marked_array_this_rec_stop c)) (get_passthrough (idx (.marked_array_this_rec_stop c) 0) ctx))
                        ; YES remember to check for let-like inlining (and (marked_array? c) (let_like_inline_closure (idx (.marked_array_values c) 0) env_id))
                        ; YES remember to properly handle crazy stuff like inlining inside of veval (does that mean we have to re-pick up inside veval after all?)
                        ; TODO: properly handle param usage based on wrap level if unknown (based on call-info)
                        ; remember to think (/modify appropriately) about TCE - I think it's fine to have it act like a normal call?
                        ((and (marked_array? c) (not (.marked_array_is_val c))) (dlet (
                              ; check func first for val or not & if val if it uses de (comb that uses de, prim_comb that takes it)
                              ;     if not, then full white-out first/'last' at call
                              ; then backwards through parameters
                              ; then backwards through func if not val
                              (func_param_values (.marked_array_values c))
                              (num_params (- (len func_param_values) 1))
                              (params (slice func_param_values 1 -1))
                              (func (idx func_param_values 0))
                              ((used_map_pre_call full_used_map_pre_call maybe_inline_subdata do_func) (cond ((let_like_inline_closure func env_id)    (dlet (
                                                                                                                                      (inl_used_map_after (push_used_map used_map_after (.comb_params func)))
                                                                                                                                      ((full_pre_inl_used_map inl_subdata) (pseudo_perceus (.comb_body func)
                                                                                                                                                                                           (.comb_id   func)
                                                                                                                                                                                           knot_memo
                                                                                                                                                                                           inl_used_map_after))
                                                                                                                                      ) (array (pop_used_map full_pre_inl_used_map)
                                                                                                                                               full_pre_inl_used_map
                                                                                                                                               (array inl_subdata inl_used_map_after)
                                                                                                                                               false)))
                                                                                      ((or (and (or (prim_comb? func) (comb? func)) (not (comb_takes_de? func num_params)))
                                                                                           (and (!= nil (.marked_array_this_rec_stop c))
                                                                                                                     (get-value-or-false knot_memo (idx (.marked_array_this_rec_stop c) 0))
                                                                                                (extract_func_usesde (get-value-or-false knot_memo (idx (.marked_array_this_rec_stop c) 0)))))
                                                                                            (array used_map_after used_map_after used_data_nil false))
                                                                                      (true (dlet ((whiteout (set_all_used_map used_map_after))) (array whiteout whiteout used_data_nil true)))
                                                                          ))
                              ((used_map_pre_params sub_results) (foldl (dlambda ((used_map_after_param sub_data) param) (dlet (
                                                                                    ((used_map_pre_param param_sub_data) (pseudo_perceus param env_id knot_memo used_map_after_param))
                                                                                 ) (array used_map_pre_param (cons (array used_map_pre_param param_sub_data) sub_data))))
                                                                        (array used_map_pre_call (array (array full_used_map_pre_call maybe_inline_subdata 'thats_subdata) used_map_after))
                                                                        (reverse_e params)))
                              ((used_map_pre_func func_sub_data) (mif do_func
                                                                      (pseudo_perceus func env_id knot_memo used_map_pre_params)
                                                                      (array used_map_pre_params used_data_nil)))
                        ) (array used_map_pre_func (cons (array used_map_pre_func func_sub_data) sub_results))))

                        ; fallthrough
                        (true   (array (error "Shouldn't happen, missing case for pseudo_perceus: " (true_str_strip c))))
              ))))
              (cached_pseudo_perceus_sym_borrowed (lambda (used_map_sub_data) (idx used_map_sub_data 0)))
              (pseudo_perceus_just_sub_idx (lambda (used_map_sub_data i) (dlet (
                                                                ;(_ (true_print "doing cached-pseudo-perceus-idx for " (true_str_strip c)))
                                                                ;(_ (true_print "doing cached-pseudo-perceus-idx i " i " " used_map_sub_data))
                                                                ( r (mif used_map_sub_data (idx (idx used_map_sub_data i) 1) (error "pseudo perceus wasn't cached")))
                                                                ;(_ (true_print "done cached-pseudo-perceus-idx"))
                                                                ) r)))
              (pseudo_perceus_just_inline_data (lambda (used_map_sub_data) (idx (pseudo_perceus_just_sub_idx used_map_sub_data -2) 0)))

              (borrow_nil nil)
              (borrow? (rec-lambda borrow? (c b env_id used_map_sub_data) (dlet (
                                                                                 ;(_ (true_print "doing borrow? " b " for " (true_str_strip c)))
                                                                                 (r 
                                                                                 (cond
                        ((val? c)                                                         (array b borrow_nil))
                        ((prim_comb? c)                                                   (array b borrow_nil))
                        ((and (marked_symbol? c) (.marked_symbol_is_val c))               (array b borrow_nil))
                        ((and (marked_array?  c) (.marked_array_is_val  c))               (array b borrow_nil))
                        ; no matter if env is real or not, it's borrowed,
                        ; as it will be cached for the length of the function
                        ((marked_env? c)                                                  (array b borrow_nil)) ; I feel like all of these value ones but esp this one should be true instead of b? must-be-borrowed
                        ((and (marked_symbol? c) (not (.marked_symbol_is_val c)))         (array (and b (not (cached_pseudo_perceus_sym_borrowed used_map_sub_data))) borrow_nil))
                        ; comb value just does its env
                        ((comb? c)                                                        (borrow? (.comb_env c) b env_id used_map_sub_data))

                        ; an array idx can be borrowed if its array can
                        ((is_prim_function_call c 'idx)  (dlet (
                                                             ((array_borrowed array_sub_data) (borrow? (idx (.marked_array_values c) 1) b    env_id (pseudo_perceus_just_sub_idx used_map_sub_data 1)))
                                                             (idx_data                        (borrow? (idx (.marked_array_values c) 2) true env_id (pseudo_perceus_just_sub_idx used_map_sub_data 2)))
                                                         ) (array array_borrowed (array borrow_nil (array array_borrowed array_sub_data) idx_data))))

                        ; len returns an int, so it can be anything,
                        ; and we'd like to borrow it's array (or string)
                        ((is_prim_function_call c 'len)                                   (array b    (array borrow_nil (borrow? (idx (.marked_array_values c) 1) true  env_id (pseudo_perceus_just_sub_idx used_map_sub_data 1)))))
                        ((is_prim_function_call c 'concat)                                (array false (map (lambda (i) (borrow? (idx (.marked_array_values c) i) true  env_id (pseudo_perceus_just_sub_idx used_map_sub_data i))) (range 0 (len (.marked_array_values c))))))
                        ((is_prim_function_call c '=)                                     (array b     (map (lambda (i) (borrow? (idx (.marked_array_values c) i) true  env_id (pseudo_perceus_just_sub_idx used_map_sub_data i))) (range 0 (len (.marked_array_values c))))))
                        ; + and - are kinda hacks until we're sure that both
                        ;     if it konws that a param is a non-rc it won't dup it
                        ;     assertions, flowing from these very opreations,
                        ;     make the pram an int (and non-rc)
                        ((is_prim_function_call c '+)                                     (array b     (map (lambda (i) (borrow? (idx (.marked_array_values c) i) true  env_id (pseudo_perceus_just_sub_idx used_map_sub_data i))) (range 0 (len (.marked_array_values c))))))
                        ((is_prim_function_call c '-)                                     (array b     (map (lambda (i) (borrow? (idx (.marked_array_values c) i) true  env_id (pseudo_perceus_just_sub_idx used_map_sub_data i))) (range 0 (len (.marked_array_values c))))))
                        ((is_prim_function_call c 'array?)                                (array b     (map (lambda (i) (borrow? (idx (.marked_array_values c) i) true  env_id (pseudo_perceus_just_sub_idx used_map_sub_data i))) (range 0 (len (.marked_array_values c))))))
                        ((is_prim_function_call c 'array)                                 (array false (map (lambda (i) (borrow? (idx (.marked_array_values c) i) false env_id (pseudo_perceus_just_sub_idx used_map_sub_data i))) (range 0 (len (.marked_array_values c))))))

                        ((is_prim_function_call c 'veval)  (dlet (
                               (func_param_values (.marked_array_values c))
                               (num_params (- (len func_param_values) 1))
                               (params (slice func_param_values 1 -1))
                               (_ (if (!= 2 num_params) (error "call to veval has != 2 params!")))
                               (_ (if (not (marked_env? (idx params 1))) (error "call to veval has not marked_env second param")))

                              (new_env_id      (.marked_env_id (idx params 1)))
                              ((body_borrowed body_sub_data) (borrow? (idx params 0) b    new_env_id (pseudo_perceus_just_sub_idx used_map_sub_data 1)))
                              ((env_borrowed   env_sub_data) (borrow? (idx params 1) true env_id     (pseudo_perceus_just_sub_idx used_map_sub_data 2)))
                        ) (array body_borrowed (array borrow_nil (array body_borrowed body_sub_data) (array env_borrowed env_sub_data)))))

                        ; cond case
                        ((is_prim_function_call c 'vcond)  (dlet (
                               (func_param_values (.marked_array_values c))
                               (num_params (- (len func_param_values) 1))
                               (params (slice func_param_values 1 -1))
                               ((borrowed sub_data)  (foldl (dlambda ((borrowed sub_data) i) (dlet (
                                                             (pred_data                   (borrow? (idx params (+ (* 2 i) 0)) true env_id (pseudo_perceus_just_sub_idx used_map_sub_data (+ (* 2 i) 1))))
                                                             ((arm_borrowed arm_sub_data) (borrow? (idx params (+ (* 2 i) 1)) b    env_id (pseudo_perceus_just_sub_idx used_map_sub_data (+ (* 2 i) 2))))
                                                         ) (array (and borrowed arm_borrowed) (concat (array pred_data (array arm_borrowed arm_sub_data)) sub_data))))
                                                         (array b (array))
                                                         (range 0 (/ num_params 2))
                                                  ))
                        ) (array borrowed sub_data)))

                        ; call taxonomy a bit simpler this time - if it's not already special cased, it's either an inline or it's owned
                        ; This also has to be adjusted based on possibly dynamic calls with unknown wrap level
                        ((and (marked_array? c) (not (.marked_array_is_val c))) (dlet (
                              (func_param_values (.marked_array_values c))
                              (num_params (- (len func_param_values) 1))
                              (params (slice func_param_values 1 -1))
                              (func (idx func_param_values 0))
                              ;(_ (true_print "doing a borrow call"))

                        ) (mif (let_like_inline_closure func env_id)
                               (dlet (
                                 ;(_ (true_print "     doing a borrow inline!"))
                                 (body (borrow? (.comb_body func) b (.comb_id func) (pseudo_perceus_just_inline_data used_map_sub_data)))
                                 ;(_ (true_print "     did body!"))
                                 ; TODO:
                                 ;        Check perceus to see if params are ever used, if not, get rid early

                                 (param_subs (map (lambda (i) (borrow? (idx (.marked_array_values c) i) false env_id (pseudo_perceus_just_sub_idx used_map_sub_data i))) (range 1 (len (.marked_array_values c)))))
                                 ;(_ (true_print "     did params"))
                               ) (array (idx body 0) (cons body param_subs)))
                               (array false (map (lambda (i) (borrow? (idx (.marked_array_values c) i) false env_id (pseudo_perceus_just_sub_idx used_map_sub_data i))) (range 0 (len (.marked_array_values c))))))))

                        ; fallthrough
                        (true   (array (error "Shouldn't happen, missing case for borrow? " (true_str_strip c))))
              ))
                                                                                 ;(_ (true_print "done borrow!"))
                                                                                 ) r)))

              (function-analysis (lambda (c memo pectx) (dlet (

                      ((wrap_level env_id de? se variadic params body) (.comb c))
                      (full_params (concat params (mif de? (array de?) (array))))

                      (inner_env (make_tmp_inner_env params de? se env_id))

                      ((call_info call_err pectx) (call-info body inner_env pectx))
                      (analysis_err call_err)

                      (inner_type_data     (infer_types body env_id empty_dict-list empty_dict-list))
                      ((used_map_before used_map_sub_data)   (pseudo_perceus body env_id memo (push_used_map empty_use_map full_params)))
                      ((borrowed borrow_sub_data) (borrow? body false env_id used_map_sub_data))
                      (_ (mif borrowed (error "body hast to be borrowed? " borrowed " " (true_str_strip body))))

                      (inner_analysis_data (array inner_type_data used_map_sub_data call_info))

              ) (array inner_analysis_data analysis_err pectx))))

              (cached_analysis_idx (lambda (c env_id cache i) (dlet (
                                                                ;(_ (true_print "doing infer-types-idx for " (true_str_strip c)))
                                                                ;(_ (true_print "doing infer-types-idx i " i))
                                                                ;(_ (true_print "doing infer-types-idx with " cache))
                                                                (_ (true_print "doing infer-types-idx, cache is real? " (mif cache true false)))

                                                                ( t (cached_infer_types_idx c env_id (mif cache (idx cache 0) type_data_nil) i))
                                                                ;( t (cached_infer_types_idx c env_id (idx cache 0) i))
                                                                ;( p (mif cache (pseudo_perceus_just_sub_idx (idx cache 1) i) nil))
                                                                ( p nil )
                                                                ( c nil )

                                                                ;(_ (true_print "done infer-types-idx"))
                                                                ) (array t p c))))


              (compile-inner (rec-lambda compile-inner (ctx c need_value inside_veval outer_s_env_access_code s_env_access_code inline_level tce_data analysis_data) (cond
                    ((val? c)   (dlet ((v (.val c)))
                                     (cond ((int? v)    (array  (mk_int_value v) nil nil ctx))
                                           ((= true v)  (array  true_val nil nil ctx))
                                           ((= false v) (array false_val nil nil ctx))
                                           ((str? v)    (dlet ( ((datasi funcs memo env pectx inline_locals) ctx)
                                                                ((datasi memo str_val) (compile-string-val datasi memo v))
                                                              ) (array str_val nil nil (array datasi funcs memo env pectx inline_locals))))
                                           (true        (error (str "Can't compile impossible value " v))))))
                    ((marked_symbol? c) (cond ((.marked_symbol_is_val c) (dlet ( ((datasi funcs memo env pectx inline_locals) ctx)
                                                                                 ((datasi memo symbol_val) (compile-symbol-val datasi memo (.marked_symbol_value c)))
                                                                               ) (array symbol_val nil nil (array datasi funcs memo env pectx inline_locals))))


                                              (true (dlet ( ((datasi funcs memo env pectx inline_locals) ctx)
                                                            ; not a recoverable error, so just do here
                                                            (_ (if (= nil env) (error "nil env when trying to compile a non-value symbol")))


      (lookup_helper (rec-lambda lookup-recurse (dict key i code level) (cond
          ((and (= i (- (len dict) 1)) (= nil (idx dict i))) (array nil (str "for code-symbol lookup, couldn't find " key)))
          ((= i (- (len dict) 1))                            (lookup-recurse (.env_marked (idx dict i)) key 0 (mif (or inside_veval (> level inline_level)) (i64.load 16 (extract_ptr_code code)) code) (+ level 1)))
          ((= key (idx (idx dict i) 0))                      (if (and (not inside_veval) (<= level inline_level)) (dlet ((s (mif (!= inline_level level)
                                                                                                                                 (str-to-symbol (concat (str (- inline_level
                                                                                                                                                                level))
                                                                                                                                                             (get-text key)))
                                                                                                                                 key))
                                                                                                                        ) (array (local.get s) nil))
                                                                                                                  (array (i64.load (* 8 i) (extract_ptr_code (i64.load 8 (extract_ptr_code code)))) nil)))
          (true                                              (lookup-recurse dict key (+ i 1) code level)))))


                                                            ((val err) (lookup_helper (.env_marked env) (.marked_symbol_value c) 0 (mif inside_veval s_env_access_code outer_s_env_access_code) 0))
                                                            (err (mif err (str "got " err ", started searching in " (str_strip env)) (if need_value (str "needed value, but non val symbol " (.marked_symbol_value c)) nil)))
                                                            (result   (mif val (generate_dup val)))
                                                          ) (array nil result err (array datasi funcs memo env pectx inline_locals))))))



                   ((marked_array? c) (if (.marked_array_is_val c) (or (get_passthrough (.hash c) ctx)
                                                                       (dlet ((actual_len (len (.marked_array_values c))))
                                                                         (if (= 0 actual_len) (array nil_val nil nil ctx)
                                                                             (dlet ( ((comp_values err ctx) (foldr (dlambda (x (a err ctx)) (dlet (((v c e ctx) (compile-inner ctx x need_value inside_veval outer_s_env_access_code s_env_access_code inline_level nil analysis_nil)))
                                                                                                                                         (array (cons (mod_fval_to_wrap v) a) (or (mif err err false) (mif e e false) (mif c (str "got code " c) false)) ctx))) (array (array) nil ctx) (.marked_array_values c)))
                                                                                   ) (mif err (array nil nil (str err ", from an array value compile " (str_strip c)) ctx) (dlet (
                                                                                    ((datasi funcs memo env pectx inline_locals) ctx)
                                                                                    ((c_loc c_len datasi) (alloc_data (apply concat (map i64_le_hexify comp_values)) datasi))
                                                                                    (result (mk_array_value actual_len c_loc))
                                                                                    (memo (put memo (.hash c) result))
                                                                                   ) (array result nil nil (array datasi funcs memo env pectx inline_locals))))))))

                                                        ; This is the other half of where we notice & tie up recursion based on partial eval's noted rec-stops
                                                        ; Other half is below in comb compilation
                                                        (or (and (not dont_y_comb) (!= nil (.marked_array_this_rec_stop c)) (get_passthrough (idx (.marked_array_this_rec_stop c) 0) ctx))
                                                        (if need_value                            (array nil nil (str "errr, needed value and was call " (str_strip c)) ctx)
                                                        (if (= 0 (len (.marked_array_values c)))  (array nil nil (str "errr, empty call array" (str_strip c)) ctx)
                                                                       (dlet (

                                                        ; This can weirdly cause infinate recursion on the compile side, if partial_eval
                                                        ; returns something that, when compiled, will cause partial eval to return that thing again.
                                                        ; Partial eval won't recurse infinately, since it has memo, but it can return something of that
                                                        ; shape in that case which will cause compile to keep stepping.

                                                        ((datasi funcs memo env pectx inline_locals) ctx)

                                                        (func_param_values (.marked_array_values c))
                                                        (num_params (- (len func_param_values) 1))
                                                        (params (slice func_param_values 1 -1))
                                                        (func_value (idx func_param_values 0))
                                                        (_ (true_print "about to get cached_infer_types_idx for call before checking for 'idx"))
                                                        ;(_ (true_print "      cache is " type_data))
                                                        (parameter_subs  (map (lambda (i) (cached_analysis_idx c (.marked_env_id env) analysis_data i)) (range 1 (len func_param_values))))
                                                        (parameter_types (map just_type parameter_subs))
                                                        ; used_data HERE

                                                        ;(_ (true_print "parameter types " parameter_types))
                                                        ;(_ (true_print "parameter subs "  parameter_subs))

                                                        (compile_params (lambda (unval_and_eval ctx cond_tce)
                                                                (foldr (dlambda (x (a err ctx i)) (dlet (

                                                                    ;(_ (true_print "compile param with unval?" unval_and_eval " " (true_str_strip x)))

                                                                    ((datasi funcs memo env pectx inline_locals) ctx)
                                                                    ((x err ctx) (mif err                 (array nil err ctx)
                                                                                 (if (not unval_and_eval) (array x err ctx)
                                                                                                          (dlet (
                                                                                                            ((ok x) (try_unval x (lambda (_) nil)))
                                                                                                            (err (if (not ok) "couldn't unval in compile" err))

                                                                                                            ((pectx e pex) (cond ((!= nil err)  (array pectx err nil))
                                                                                                                                 (true (partial_eval_helper x false env (array nil nil) pectx 1 false))))

                                                                                                            (ctx (array datasi funcs memo env pectx inline_locals))

                                                                                                          ) (array (mif e x pex) err ctx)))))
                                                                    ((datasi funcs memo env pectx inline_locals) ctx)
                                                                    (memo (put memo (.hash c) 'RECURSE_FAIL))
                                                                    (ctx (array datasi funcs memo env pectx inline_locals))
                                                                    ;(_ (true_print "matching up compile-inner " (true_str_strip x) " with " (idx parameter_subs i)))
                                                                    ((val code err ctx) (mif err (array nil nil err ctx)
                                                                                                 (compile-inner ctx x false inside_veval outer_s_env_access_code s_env_access_code inline_level
                                                                                                                                                                     ; 0 b/c foldr
                                                                                                                                                                     ; count from end
                                                                                                                                                           (mif (and (= 0 (% i 2)) cond_tce)
                                                                                                                                                                tce_data
                                                                                                                                                                nil)
                                                                                                                                                           ; if we're unvaling, our old cache for type data is bad
                                                                                                                                                           ; TODO - we should be able to recover for this
                                                                                                                                                           (mif unval_and_eval analysis_nil
                                                                                                                                                                               (idx parameter_subs (- num_params i 1)))
                                                                                                                                                           )))
                                                                    ((datasi funcs memo env pectx inline_locals) ctx)
                                                                    (memo (put memo (.hash c) 'RECURSE_OK))
                                                                    ) (array (cons (mif val (i64.const (mod_fval_to_wrap val)) code) a) err ctx (+ i 1))))

                                                                (array (array) nil ctx 0) params)))
                                                        (wrap_param_codes (lambda (param_codes) (concat (call '$malloc (i32.const (* 8 (len param_codes))))
                                                                                                        ;(apply concat param_codes)
                                                                                                        (flat_map (lambda (i) (concat (local.tee '$param_ptr)
                                                                                                                                      (i64.store (* i 8) (local.get '$param_ptr) (idx param_codes i))))
                                                                                                                  (range 0 (len param_codes)))
                                                                                                        (local.set '$param_ptr)
                                                                                                )))


                                                        (wrap_level (if (or (comb? func_value) (prim_comb? func_value)) (.any_comb_wrap_level func_value) nil))
                                                        ; I don't think it makes any sense for a function literal to have wrap > 0
                                                        (_ (if (and (!= nil wrap_level) (> wrap_level 0)) (error "call to function literal has wrap >0")))

                                                        ;; Test for the function being a constant to inline
                                                        ;; Namely, vcond (also veval!)
                                                        (single_num_type_check (lambda (code) (concat (local.set '$prim_tmp_a code)
                                                                                                      (_if '$not_num
                                                                                                           (is_not_type_code int_tag (local.get '$prim_tmp_a))
                                                                                                           (then (local.set '$prim_tmp_a (call '$debug (call '$array1_alloc (local.get '$prim_tmp_a)) (i64.const nil_val) (i64.const nil_val))))
                                                                                                      )
                                                                                                      (local.get '$prim_tmp_a))))
                                                        (gen_numeric_impl (lambda (operation)
                                                                              (dlet (((param_codes err ctx _) (compile_params false ctx false)))
                                                                                    (mif err (array nil nil (str err " from function params in call to comb " (str_strip c)) ctx)
                                                                                             (array nil (foldl (lambda (running_code val_code) (operation running_code
                                                                                                                                                          (single_num_type_check val_code)))
                                                                                                               (single_num_type_check (idx param_codes 0))
                                                                                                               (slice param_codes 1 -1)) nil ctx)))
                                                                              ))

                                                        (gen_pred_impl    (lambda (tag needs_drop)
                                                                              (dlet (((param_codes err ctx _) (compile_params false ctx false))
                                                                                     (_ (true_print "doing an array? inline!"))
                                                                                     )
                                                                                    (mif err (array nil nil (str err " from function params in call to comb " (str_strip c)) ctx)
                                                                                             (array nil (concat
                                                                                                          (idx param_codes 0)
                                                                                                          (local.set '$prim_tmp_a)
                                                                                                          (_if '$is_pred '(result i64)
                                                                                                              (i64.eq (i64.const tag) (i64.and (i64.const type_mask) (local.get '$prim_tmp_a)))
                                                                                                              (then (i64.const true_val))
                                                                                                              (else (i64.const false_val))
                                                                                                          )
                                                                                                          (mif needs_drop (generate_drop (local.get '$prim_tmp_a)) (array))
                                                                                                        ) nil ctx)))
                                                                              ))
                                                        (gen_cmp_impl (lambda (lt_case eq_case gt_case)
                                                                              (dlet (((param_codes err ctx _) (compile_params false ctx false)))
                                                                                    (mif err (array nil nil (str err " from function params in call to comb " (str_strip c)) ctx)
                                                                                             (array nil
                                                                                                    (concat
                                                                                                          (apply concat param_codes)
                                                                                                          (i64.const true_val)
                                                                                                          (flat_map (lambda (i) (concat
                                                                                                                            (local.set '$prim_tmp_a)
                                                                                                                            (local.set '$prim_tmp_b)
                                                                                                                            (local.set '$prim_tmp_c)
                                                                                                                            (call '$comp_helper_helper (local.get '$prim_tmp_c)
                                                                                                                                                       (local.get '$prim_tmp_b)
                                                                                                                                                       (i64.const lt_case)
                                                                                                                                                       (i64.const eq_case)
                                                                                                                                                       (i64.const gt_case))
                                                                                                                            (local.set '$prim_tmp_a (i64.and (local.get '$prim_tmp_a)))
                                                                                                                            (local.get '$prim_tmp_c)
                                                                                                                            (local.get '$prim_tmp_a)
                                                                                                                      ))
                                                                                                                    (range 1 num_params))
                                                                                                          (_drop) (_drop) (local.get '$prim_tmp_a)
                                                                                                    )
                                                                                                    nil ctx)))
                                                                              ))
                                                        ) (cond
                                                            ((and (prim_comb? func_value) (= (.prim_comb_sym func_value) 'veval)) (dlet (

                            (_ (if (!= 2 (len params)) (error "call to veval has != 2 params!")))
                            ((datasi funcs memo env pectx inline_locals) ctx)
                            ((val code err (datasi funcs memo ienv pectx inline_locals)) (compile-inner (array datasi funcs memo (idx params 1) pectx inline_locals) (idx params 0) false true (local.get '$s_env) (local.get '$s_env) 0 nil analysis_nil))
                            (ctx (array datasi funcs memo env pectx inline_locals))
                            ; If it's actual code, we have to set and reset s_env
                            ((code env_err ctx) (mif code (dlet (
                                                              ((env_val env_code env_err ctx) (compile-inner ctx (idx params 1) false inside_veval outer_s_env_access_code s_env_access_code inline_level nil analysis_nil))
                                                              (full_code (concat (local.get '$s_env)
                                                                                 (local.set '$s_env (mif env_val (i64.const env_val) env_code))
                                                                                 code
                                                                                 (local.set '$tmp)
                                                                                 ; DROP s_env???
                                                                                 (local.set '$s_env)
                                                                                 (local.get '$tmp)))
                                                              ) (array full_code env_err ctx))
                                                           (array code nil ctx)))
                                                     ) (array (mod_fval_to_wrap val) code (mif err err env_err) ctx)))

                                                            ((and (prim_comb? func_value) (= (.prim_comb_sym func_value) 'vcond))
                                                                                                               (dlet (
                                                                                                                ((param_codes err ctx _) (compile_params false ctx true))
                                                                                                               )
                                                                                        (mif err (array nil nil (str err " from function params in call to comb " (str_strip c)) ctx)
                                                                                                                     (array nil ((rec-lambda recurse (codes i) (cond
                                                                                                                        ((< i (- (len codes) 1)) (_if '_cond_flat '(result i64)
                                                                                                                                                    (truthy_test (idx codes i))
                                                                                                                                                    (then (idx codes (+ i 1)))
                                                                                                                                                    (else (recurse codes (+ i 2)))
                                                                                                                                                ))
                                                                                                                        ((= i (- (len codes) 1)) (error "compiling bad length comb"))
                                                                                                                        (true                    (unreachable))
                                                                                                                    )) param_codes 0) err ctx))))


                                                            ((and (not dont_prim_inline) (prim_comb? func_value) (= (.prim_comb_sym func_value) '+)) (gen_numeric_impl i64.add))
                                                            ((and (not dont_prim_inline) (prim_comb? func_value) (= (.prim_comb_sym func_value) '-)) (gen_numeric_impl i64.sub))
                                                            ((and (not dont_prim_inline) (prim_comb? func_value) (= (.prim_comb_sym func_value) '=)) (mif (any_in_array word_value_type? parameter_types)
                                                                                                                                  (dlet (((param_codes err ctx _) (compile_params false ctx false)))
                                                                                                                                          (mif err (array nil nil (str err " from function params in call to comb " (str_strip c)) ctx)
                                                                                                                                                   (dlet (
                                                                                                    (_ (true_print "Doing the better = " parameter_types))
                                                                                                    (word_value_idx  (any_in_array word_value_type? parameter_types))
                                                                                                    (pparameter_types (reverse_e (concat (slice parameter_types 0 word_value_idx)
                                                                                                                                         (slice parameter_types (+ 1 word_value_idx) -1)
                                                                                                                                         (array (idx parameter_types word_value_idx)))))
                                                                                                    (_ (true_print "made reverse"))
                                                                                                    (eq_code 
                                                                                                             (_if '$eq_result '(result i64)
                                                                                                                   (concat
                                                                                                                       (apply concat (concat (slice param_codes 0 word_value_idx)
                                                                                                                                             (slice param_codes (+ 1 word_value_idx) -1)
                                                                                                                                             (array (idx param_codes word_value_idx))))
                                                                                                                       (local.set '$prim_tmp_a)
                                                                                                                       (local.set '$prim_tmp_b)
                                                                                                                       (local.set '$prim_tmp_d (i64.eq (local.get '$prim_tmp_a) (local.get '$prim_tmp_b)))
                                                                                                                       (mif (word_value_type? (idx pparameter_types 1)) (array) (generate_drop (local.get '$prim_tmp_b)))
                                                                                                                       (flat_map (lambda (i) (concat
                                                                                                                         (local.set '$prim_tmp_b)
                                                                                                                         (local.set '$prim_tmp_d (i64.and (local.get '$prim_tmp_d) (i64.eq (local.get '$prim_tmp_a) (local.get '$prim_tmp_b))))
                                                                                                                         (mif (word_value_type? (idx pparameter_types i)) (array) (generate_drop (local.get '$prim_tmp_b)))
                                                                                                                                   ))
                                                                                                                                 (range 2 num_params))
                                                                                                                       (local.get '$prim_tmp_d)
                                                                                                                   )
                                                                                                                   (then (i64.const true_val))
                                                                                                                   (else (i64.const false_val)))
                                                                                                    )
                                                                                                    (_ (true_print "made eq_code"))
                                                                                                                                        ) (array nil eq_code nil ctx))))
                                                                                                                                (dlet ((_ (true_print "missed better = " parameter_types))) (gen_cmp_impl false_val true_val false_val))))

                                                            ((and (not dont_prim_inline) (prim_comb? func_value) (= (.prim_comb_sym func_value) 'array?) (= 1 num_params)) (gen_pred_impl array_tag true))

                                                            ; inline array pretty much always - array does nothing but return it's parameter array anyway!
                                                            ((and (not dont_prim_inline) (prim_comb? func_value) (= (.prim_comb_sym func_value) 'array)) (dlet (
                                                                  (_ (true_print "inlining array ARRAY!!!"))
                                                                  ((param_codes err ctx _) (compile_params false ctx false))
                                                                  (code (mif err nil
                                                                                 (concat  (wrap_param_codes param_codes)
                                                                                          (mk_array_code_rc_const_len (len param_codes) (local.get '$param_ptr)))))
                                                            ) (array nil code err ctx)))

                                                            ; inline idx if we have the type+len of array and idx is a constant
                                                            ((and (not dont_prim_inline) (prim_comb? func_value) (= (.prim_comb_sym func_value) 'idx) (= 2 num_params)
                                                                  (idx parameter_types 0) (= 'arr (idx (idx parameter_types 0) 0)) (idx (idx parameter_types 0) 2)
                                                                  (idx parameter_types 1) (= 'int (idx (idx parameter_types 1) 0)))
                                                                  (val? (idx params 1))                                             (dlet (
                                                                  (_ (true_print "inlining idx IDX!!"))
                                                                  ((param_codes err ctx _) (compile_params false ctx false))
                                                                  (array_len (idx (idx parameter_types 0) 2))
                                                                  (index (.val (idx params 1)))
                                                                  (index (mif (< index 0) (+ index array_len) index))
                                                                  ((code err) (mif (and (>= index 0) (< index array_len))
                                                                                   (array (concat (local.set '$prim_tmp_a (idx param_codes 0))
                                                                                                  (generate_dup (i64.load (* 8 index) (extract_ptr_code (local.get '$prim_tmp_a))))
                                                                                                  (generate_drop (local.get '$prim_tmp_a)))
                                                                                          nil)
                                                                                   (array nil (true_str "bad constant offset into typed array"))))
                                                            ) (array nil code err ctx)))
                                                            ; inline len if we have the type of array
                                                            ((and (not dont_prim_inline) (prim_comb? func_value) (= (.prim_comb_sym func_value) 'len) (= 1 num_params)
                                                                  (idx parameter_types 0) (= 'arr (idx (idx parameter_types 0) 0))) (dlet (
                                                                  (_ (true_print "inlining len LEN!!!"))
                                                                  ((param_codes err ctx _) (compile_params false ctx false))
                                                                  (code (mif err nil
                                                                                 (concat (local.set '$prim_tmp_a (idx param_codes 0))
                                                                                         (extract_size_code_to_int (local.get '$prim_tmp_a))
                                                                                         (generate_drop (local.get '$prim_tmp_a)))))
                                                            ) (array nil code err ctx)))
                                                        


                                                            ; User inline
                                                            ((and (not dont_closure_inline) (let_like_inline_closure func_value (.marked_env_id env))) (dlet (
                        ; To inline, we add all of the parameters + inline_level + 1 to the current functions additional symbols
                        ;       as well as a new se + inline_level + 1 symbol
                        ; fill them with the result of evaling the parameters now
                        ; inline the body's compiled code, called with an updated s_env_access_code
                        ; drop all of the parameters
                        ;(_ (true_print "INLINEING"))
                        (_ (true_print "INLINEING " (.comb_params func_value)))
                        (new_inline_level (+ inline_level 1))
                        (comb_params (.comb_params func_value))
                        (additional_param_symbols (map (lambda (x) (str-to-symbol (concat (str new_inline_level) (get-text x)))) comb_params))
                        (new_s_env_symbol (str-to-symbol (concat "$" (str new_inline_level) "_inline_se")))
                        (additional_symbols (cons new_s_env_symbol additional_param_symbols))
                        (_ (true_print "additional symbols " additional_symbols))

                        ((param_codes first_params_err ctx _) (compile_params false ctx false))

                        (inner_env (make_tmp_inner_env comb_params (.comb_des func_value) (.comb_env func_value) (.comb_id func_value)))
                        ((params_vec _ _ ctx) (compile-inner ctx (marked_array true false nil (map (lambda (k) (marked_symbol nil k)) comb_params) nil) true false outer_s_env_access_code s_env_access_code 0 nil analysis_nil))
                        (new_get_s_env_code (_if '$have_s_env '(result i64)
                                                 (i64.ne (i64.const nil_val) (local.get new_s_env_symbol))
                                                 (then (local.get new_s_env_symbol))
                                                 (else (local.tee new_s_env_symbol (call '$env_alloc (i64.const params_vec)

                                                                                            (local.set '$tmp_ptr (call '$malloc (i32.const (* 8 (len additional_param_symbols)))))
                                                                                            (flat_map (lambda (i) (i64.store (* i 8) (local.get '$tmp_ptr)
                                                                                                                             (generate_dup (local.get (idx additional_param_symbols i))))) 
                                                                                                      (range 0 (len additional_param_symbols)))
                                                                                            (mk_array_code_rc_const_len (len additional_param_symbols) (local.get '$tmp_ptr))
                                                                                            (generate_dup s_env_access_code)))
                                                       )))
                        ((datasi funcs memo env pectx inline_locals) ctx)
                        (_ (true_print "Doing inline compile-inner " comb_params))
                        ((inner_value inner_code err ctx) (compile-inner (array datasi funcs memo inner_env pectx inline_locals)
                                                                         (.comb_body func_value) false false outer_s_env_access_code new_get_s_env_code new_inline_level tce_data
                                                                         (cached_analysis_idx c (.comb_id func_value) analysis_data 0)
                                                                         ))
                        (_ (true_print "Done inline compile-inner " comb_params))
                        (inner_code (mif inner_value (i64.const inner_value) inner_code))
                        (result_code (concat
                                       (apply concat param_codes)
                                       (flat_map (lambda (i) (local.set (idx additional_param_symbols i))) (range (- (len additional_param_symbols) 1) -1))
                                       (local.set new_s_env_symbol (i64.const nil_val))
                                       inner_code
                                       (flat_map (lambda (i) (generate_drop (local.get (idx additional_param_symbols i)))) (range (- (len additional_param_symbols) 1) -1))
                                       (generate_drop (local.get new_s_env_symbol))
                                       (local.set new_s_env_symbol (i64.const nil_val))
                                       ))
                        ; Don't overwrite env with what was our inner env! Env is returned as part of context to our caller!
                        ((datasi funcs memo _was_inner_env pectx inline_locals) ctx)
                        (final_result (array nil result_code (mif first_params_err first_params_err err) (array datasi funcs memo env pectx (concat inline_locals additional_symbols))))
                        (_ (true_print "DONE INLINEING " (.comb_params func_value)))

                                                                  ) final_result))
                                                            ; Normal call
                                                            ;     - static call (based on getting func_val)
                                                            ;           +statically knowable params
                                                            ;                 * s_de/s_no_de & s_wrap=1/s_wrap=2
                                                            ;           +dynamic params
                                                            ;                 * s_de/s_no_de & s_wrap=1/s_wrap=2
                                                            ;     - dynamic call (got func_code)
                                                            ;           + d_de/d_no_de & d_wrap=1/d_wrap=2
                                                            (true (dlet (
                                                                ((param_codes first_params_err ctx _) (compile_params false ctx false))
                                                                ((func_val func_code func_err ctx) (compile-inner ctx func_value false inside_veval outer_s_env_access_code s_env_access_code inline_level nil analysis_nil))
                                                                ((unval_param_codes err ctx _) (compile_params true ctx false))
                                                                ; Generates *tons* of text, needs to be different. Made a 200KB binary 80MB
                                                                ;((bad_unval_params_msg_val _ _ ctx) (compile-inner ctx (marked_val (str "error was with unval-evaling parameters of " (true_str_strip c) " " err)) true inside_veval outer_s_env_access_code s_env_access_code inline_level analysis_nil))
                                                                ((bad_unval_params_msg_val _ _ ctx) (compile-inner ctx (marked_val "error was with unval-evaling parameters of ") true inside_veval outer_s_env_access_code s_env_access_code inline_level nil analysis_nil))
                                                                (wrap_0_inner_code (apply concat param_codes))
                                                                (wrap_0_param_code (wrap_param_codes param_codes))
                                                                (wrap_1_inner_code
                                                                   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                                                                   ; Since we're not sure if it's going to be a vau or not,
                                                                   ; this code might not be compilable, so we gracefully handle
                                                                   ; compiler errors and instead emit code that throws the error if this
                                                                   ; spot is ever reached at runtime.
                                                                   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                                                                   (mif err (concat (call '$print (i64.const bad_not_vau_msg_val))
                                                                                    (call '$print (i64.const bad_unval_params_msg_val))
                                                                                    (unreachable))
                                                                            (apply concat unval_param_codes)))
                                                                (wrap_1_param_code (mif err wrap_1_inner_code
                                                                                            (wrap_param_codes unval_param_codes)))
                                                                (wrap_x_param_code (concat
                                                                                    ; TODO: Handle other wrap levels
                                                                                    (call '$print (i64.const weird_wrap_msg_val))
                                                                                    (unreachable)))

                                                                ((source_code ctx) (mif (.marked_array_source c) (dlet (((code _ _ ctx) (compile-inner ctx (.marked_array_source c) true inside_veval outer_s_env_access_code s_env_access_code inline_level nil analysis_nil))
                                                                                                                        ) (array code ctx))
                                                                                                                 (array bad_source_code_msg_val ctx)))
                                                                (_ (mif (nil? source_code) (error "nil source codepost compile! pre was " (.marked_array_source c))))
                                                                ;((source_code ctx) (mif (nil? source_code) (array bad_source_code_msg_val ctx) (array source_code ctx)))
                                                                ((result_code ctx) (mif func_val
                                                                              (dlet (
                                                                                    (unwrapped                 (extract_unwrapped func_val))
                                                                                    (func_idx                  (- (extract_func_idx func_val) func_id_dynamic_ofset (- 0 num_pre_functions) 1))
                                                                                    (wrap_level                (extract_func_wrap func_val))
                                                                                    (needs_denv                (extract_func_usesde func_val))
                                                                                    ((tce_idx tce_full_params) (mif tce_data tce_data (array nil nil)))
                                                                                    (tce_able                  (and unwrapped (= tce_idx (extract_func_idx func_val))))
                                                                                    (s_env_val                 (extract_func_env func_val))
                                                                                    ((datasi funcs memo env pectx inline_locals) ctx)
                                                                                    (ctx (mif tce_able
                                                                                              (dlet (
                                                                                                  (inline_locals (mif (in_array '___TCE___ inline_locals)
                                                                                                                      inline_locals
                                                                                                                      (cons '___TCE___ inline_locals)))
                                                                                                  (ctx (array datasi funcs memo env pectx inline_locals))
                                                                                              ) ctx)
                                                                                              ctx))
                                                                              )
                                                                              (array (concat
                                                                                (front_half_stack_code (i64.const source_code) (generate_dup s_env_access_code))
                                                                                ;params
                                                                                (mif unwrapped
                                                                                     ; unwrapped, can call directly with parameters on wasm stack
                                                                                     (concat
                                                                                            (cond ((= 0 wrap_level) wrap_0_inner_code)
                                                                                                  ((= 1 wrap_level) wrap_1_inner_code)
                                                                                                  (true             wrap_x_param_code))
                                                                                            ;dynamic env (is caller's static env)
                                                                                            ; hay, we can do this statically! the static version of the dynamic check
                                                                                            (mif needs_denv
                                                                                                 (generate_dup s_env_access_code)
                                                                                                 (array))
                                                                                            (mif tce_able
                                                                                                 (concat
                                                                                                      (generate_drop (local.get '$s_env))
                                                                                                      (local.set '$s_env (i64.const nil_val))
                                                                                                      (generate_drop (local.get '$outer_s_env))
                                                                                                      (local.set '$outer_s_env (i64.const s_env_val))
                                                                                                      (flat_map (lambda (i) (mif (= i '___TCE___) (array)
                                                                                                                                                  (concat (generate_drop (local.get i))
                                                                                                                                                          (local.set i (i64.const nil_val)))))
                                                                                                                inline_locals)
                                                                                                      (flat_map (lambda (i) (concat (generate_drop (local.get i)) (local.set i))) (reverse_e tce_full_params))
                                                                                                      (br '___TCE___)
                                                                                                      (dlet ((_ (true_print "HAYO TCEEE"))) nil)
                                                                                                 )
                                                                                                 (concat
                                                                                                     ; static env
                                                                                                     (i64.const s_env_val)
                                                                                                     (call func_idx)))
                                                                                     )
                                                                                     ; Needs wrapper, must create param array
                                                                                     (concat
                                                                                            (cond ((= 0 wrap_level) wrap_0_param_code)
                                                                                                  ((= 1 wrap_level) wrap_1_param_code)
                                                                                                  (true             wrap_x_param_code))
                                                                                            (mk_array_code_rc_const_len num_params (local.get '$param_ptr))
                                                                                            ;dynamic env (is caller's static env)
                                                                                            ; hay, we can do this statically! the static version of the dynamic check
                                                                                            (mif needs_denv
                                                                                                 (generate_dup s_env_access_code)
                                                                                                 (i64.const nil_val))
                                                                                            ; static env
                                                                                            (i64.const s_env_val)
                                                                                            (call func_idx)
                                                                                      )
                                                                                )
                                                                                back_half_stack_code
                                                                              ) ctx))
                                                                              (array (concat
                                                                                func_code
                                                                                (local.tee '$tmp)
                                                                                (_if '$is_wrap_0
                                                                                    (is_wrap_code 0 (local.get '$tmp))
                                                                                    (then
                                                                                      (global.set '$num_compiled_dzero   (i32.add (i32.const 1) (global.get '$num_compiled_dzero)))
                                                                                       wrap_0_param_code
                                                                                    )
                                                                                    (else
                                                                                        (_if '$is_wrap_1
                                                                                            (is_wrap_code 1 (local.get '$tmp))
                                                                                            (then
                                                                                             (global.set '$num_compiled_done (i32.add (i32.const 1) (global.get '$num_compiled_done)))
                                                                                              wrap_1_param_code
                                                                                            )
                                                                                            (else wrap_x_param_code)
                                                                                        )
                                                                                    )
                                                                                )
                                                                                (front_half_stack_code (i64.const source_code) (generate_dup s_env_access_code))
                                                                                (local.set '$tmp)
                                                                                (call_indirect
                                                                                    ;type
                                                                                    k_vau
                                                                                    ;table
                                                                                    0
                                                                                    ;params
                                                                                    (mk_array_code_rc_const_len num_params (local.get '$param_ptr))
                                                                                    ;dynamic env (is caller's static env)
                                                                                    (_if '$needs_dynamic_env '(result i64)
                                                                                         (needes_de_code (local.get '$tmp))
                                                                                         (then (generate_dup s_env_access_code))
                                                                                         (else (i64.const nil_val)))
                                                                                    ; static env
                                                                                    (extract_func_env_code (local.get '$tmp))
                                                                                    ;func_idx
                                                                                    (extract_func_idx_code (local.get '$tmp))
                                                                                )
                                                                                back_half_stack_code
                                                                               ) ctx)))
                                                                ) (array nil result_code (mif func_err func_err first_params_err) ctx)))
                                                        )))))))

                    ((marked_env? c) (or (get_passthrough (.hash c) ctx) (dlet ((e (.env_marked c))

                                            ;(_ (true_print "gonna compile a marked_env"))

                                            (generate_env_access (dlambda ((datasi funcs memo env pectx inline_locals) env_id reason) ((rec-lambda recurse (code this_env)
                                                (cond
                                                    ((= env_id (.marked_env_id this_env)) (array nil (generate_dup code) nil (array datasi funcs memo env pectx inline_locals)))
                                                    ((= nil (.marked_env_upper this_env))  (array nil nil (str "bad env, upper is nil and we haven't found " env_id ", (this is *possiblely* because we're not recreating val/notval chains?) maxing out at " (str_strip this_env) ",  having started at " (str_strip env) ", we're generating because " reason) (array datasi funcs memo env pectx)))
                                                    (true                                  (recurse (i64.load 16 (extract_ptr_code code)) (.marked_env_upper this_env)))
                                                )
                                            ) s_env_access_code env)))

                                            ) (if (not (marked_env_real? c)) (begin (print_strip "env wasn't real: " (marked_env_real? c) ", so generating access (env was) " c)
                                                                                    (if need_value (array nil nil (str "marked env not real, though we need_value: " (str_strip c)) ctx)
                                                                                                   (generate_env_access ctx (.marked_env_id c) "it wasn't real: " (str_strip c))))
                                            (dlet (
                                            ;(_ (true_print "gonna compile kvs vvs"))


                                            ((kvs vvs ctx) (foldr (dlambda ((k v) (ka va ctx)) (dlet (((kv _    _   ctx) (compile-inner ctx (marked_symbol nil k) true inside_veval outer_s_env_access_code s_env_access_code inline_level nil analysis_nil))
                                                                                                      ((vv code err ctx) (compile-inner ctx v need_value inside_veval outer_s_env_access_code s_env_access_code inline_level nil analysis_nil))
                                                                                                      )
                                                                                                      (if (= false ka) (array false va ctx)
                                                                                                      (if (or (= nil vv) (!= nil err)) (array false (str "vv was " vv " err is " err " and we needed_value? " need_value " based on v " (str_strip v)) ctx)
                                                                                                                                       (array (cons kv ka) (cons (mod_fval_to_wrap vv) va) ctx)))))
                                                                  (array (array) (array) ctx)
                                                                  (slice e 0 -2)))
                                            ;(_ (true_print "gonna compile upper_value"))
                                            ((uv ucode err ctx) (mif (idx e -1) (compile-inner ctx (idx e -1) need_value inside_veval outer_s_env_access_code s_env_access_code inline_level nil analysis_nil)
                                                                                (array nil_val nil nil ctx)))
                                            ) (mif (or (= false kvs) (= nil uv) (!= nil err))
                                                   (begin (true_print "kvs " kvs " vvs " vvs " uv " uv " or err " err " based off of " (true_str_strip c))
                                                          (error "I DON'T LIKE IT - IMPOSSIBLE?")
                                                          (if need_value
                                                              (array nil nil (str "had to generate env access (course " need_value ") for " (str_strip c) "vvs is " vvs " err was " err) ctx)
                                                              (generate_env_access ctx (.marked_env_id c) (str " vvs " vvs " uv " uv " or err " err " based off of " (str_strip c)))))
                                            (dlet (
                                                ((datasi funcs memo env pectx inline_locals) ctx)
                                                ;(_ (true_print "about to kvs_array"))
                                                ((kvs_array datasi) (if (= 0 (len kvs)) (array nil_val datasi)
                                                                                        (dlet (((kvs_loc kvs_len datasi) (alloc_data (apply concat (map i64_le_hexify kvs)) datasi)))
                                                                                              (array (mk_array_value (len kvs) kvs_loc) datasi))))
                                                ;(_ (true_print "about to vvs_array"))
                                                ((vvs_array datasi) (if (= 0 (len vvs)) (array nil_val datasi)
                                                                                        (dlet (((vvs_loc vvs_len datasi) (alloc_data (apply concat (map i64_le_hexify vvs)) datasi)))
                                                                                              (array (mk_array_value (len vvs) vvs_loc) datasi))))
                                                ;(_ (true_print "about to all_hex"))
                                                (all_hex (map i64_le_hexify (array kvs_array vvs_array uv)))
                                                ;(_ (true_print "all_hexed"))
                                                ((c_loc c_len datasi) (alloc_data (apply concat all_hex) datasi))
                                                ;(_ (true_print "alloced"))
                                                (result (mk_env_value c_loc))
                                                ;(_ (true_print "made result " result))
                                                (memo (put memo (.hash c) result))
                                            ) (array result nil nil (array datasi funcs memo env pectx inline_locals)))))))))

                    ((prim_comb? c) (cond ((= 'vau           (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_vau dyn_start)           1 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'cond          (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_cond dyn_start)          1 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'eval          (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_eval dyn_start)          1 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'read-string   (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_read-string dyn_start)   0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'log           (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_log dyn_start)           0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'debug         (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_debug dyn_start)         1 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'error         (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_error dyn_start)         0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'str           (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_str dyn_start)           0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= '>=            (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_geq dyn_start)           0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= '>             (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_gt dyn_start)            0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= '<=            (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_leq dyn_start)           0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= '<             (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_lt dyn_start)            0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= '!=            (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_neq dyn_start)           0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= '=             (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_eq dyn_start)            0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= '%             (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_mod dyn_start)           0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= '/             (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_div dyn_start)           0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= '*             (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_mul dyn_start)           0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= '+             (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_add dyn_start)           0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= '-             (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_sub dyn_start)           0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'band          (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_band dyn_start)          0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'bor           (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_bor dyn_start)           0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'bxor          (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_bxor dyn_start)          0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'bnot          (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_bnot dyn_start)          0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= '<<            (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_ls dyn_start)            0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= '>>            (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_rs dyn_start)            0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'builtin_fib   (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_builtin_fib dyn_start)   0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'array         (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_array dyn_start)         0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'concat        (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_concat dyn_start)        0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'slice         (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_slice dyn_start)         0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'idx           (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_idx dyn_start)           0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'len           (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_len dyn_start)           0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'array?        (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_array? dyn_start)        0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'get-text      (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_get-text dyn_start)      0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'str-to-symbol (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_str-to-symbol dyn_start) 0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'bool?         (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_bool? dyn_start)         0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'nil?          (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_nil? dyn_start)          0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'env?          (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_env? dyn_start)          0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'combiner?     (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_combiner? dyn_start)     0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'string?       (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_string? dyn_start)       0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'int?          (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_int? dyn_start)          0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'symbol?       (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_symbol? dyn_start)       0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'unwrap        (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_unwrap dyn_start)        0 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'vapply        (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_vapply dyn_start)        1 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'lapply        (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_lapply dyn_start)        1 (.prim_comb_wrap_level c)) nil nil ctx))
                                          ((= 'wrap          (.prim_comb_sym c))  (array (mk_comb_val_nil_env (- k_wrap dyn_start)          0 (.prim_comb_wrap_level c)) nil nil ctx))
                                                                                         (error (str "Can't compile prim comb " (.prim_comb_sym c) " right now"))))



                    ((comb? c) (dlet (
                                    ((wrap_level env_id de? se variadic params body) (.comb c))
                                    (_ (mif (> wrap_level 1) (error "wrap level TOO DARN HIGH")))

                                    ;  note that this is just the hash of the func, not the env
                                    (old_hash (.hash c))
                                    (maybe_func (get_passthrough old_hash ctx))
                                    ((datasi funcs memo env pectx inline_locals) ctx)
                                    ((pectx err evaled_body) (mif (or maybe_func dont_partial_eval)
                                                                  (array pectx "don't pe" body)
                                                                  (dlet ((inner_env (make_tmp_inner_env params de? env env_id)))
                                                                         (partial_eval_helper body false inner_env (array nil (array inner_env)) pectx 1 false))))
                                    (body (mif err body evaled_body))
                                    (c (comb_w_body c body))
                                    (new_hash (.hash c))
                                    (ctx (array datasi funcs memo env pectx inline_locals))

                                    ; Let's look and see if we can eta-reduce!
                                    ; This is done here during code gen (when you would expect it earlier, like as part of partial eval)
                                    ; because we currently only "tie the knot" for Y combinator based recursion here
                                    ; at compile time (indeed, part of that happens in the block down below where we put our func value into memo before compiling),
                                    ; and so we can only tell here weather or not it will be safe to remove the level of lazyness (because we get a func value back instead of code)
                                    ; and perform the eta reduction.

                                    ((env_val env_code env_err ctx) (if (and need_value (not (marked_env_real? se)))
                                                                        (array nil nil "Env wasn't real when compiling comb, but need value" ctx)
                                                                        (compile-inner ctx se need_value inside_veval outer_s_env_access_code s_env_access_code inline_level nil analysis_nil)))
                                    (_ (if (not (or (= nil env_val) (int? env_val))) (error "BADBADBADenv_val")))

                               ) (mif (and
                                           (not dont_y_comb)
                                           variadic
                                           (= 1 (len params))
                                           (marked_array? body)
                                           (= 4 (len (.marked_array_values body)))
                                           (prim_comb? (idx (.marked_array_values body) 0))
                                           (= 'lapply (.prim_comb_sym (idx (.marked_array_values body) 0)))
                                           (int? (get-value-or-false memo (.hash (idx (.marked_array_values body) 1))))
                                           (marked_symbol? (idx (.marked_array_values body) 2))
                                           (not (.marked_symbol_is_val (idx (.marked_array_values body) 2)))
                                           (= (idx params 0) (.marked_symbol_value (idx (.marked_array_values body) 2)))
                                           (marked_symbol? (idx (.marked_array_values body) 3))
                                           (not (.marked_symbol_is_val (idx (.marked_array_values body) 3)))
                                           (= de? (.marked_symbol_value (idx (.marked_array_values body) 3)))
                                           env_val
                                      )
                                      (array (combine_env_comb_val env_val (set_wrap_val wrap_level (get-value-or-false memo (.hash (idx (.marked_array_values body) 1))))) nil err ctx)
                                      (dlet (

                                    (maybe_func (or (get_passthrough old_hash ctx) (get_passthrough new_hash ctx)))
                                    ((func_value _ func_err ctx) (mif maybe_func maybe_func
                                        (dlet (

                                        (full_params (concat params (mif de? (array de?) (array))))
                                        (normal_params_length (if variadic (- (len params) 1) (len params)))

                                        ((datasi funcs memo env pectx outer_inline_locals) ctx)
                                        (old_funcs funcs)
                                        (funcs (concat funcs (array nil)))
                                        (our_wrap_func_idx (+ (len funcs) func_id_dynamic_ofset))
                                        (funcs (concat funcs (array nil)))
                                        (our_func_idx (+ (len funcs) func_id_dynamic_ofset))
                                        (calculate_func_val (lambda (wrap) (mk_comb_val_nil_env our_func_idx (mif de? 1 0) wrap)))
                                        (func_value (calculate_func_val wrap_level))
                                        ; if variadic, we just use the wrapper func and don't expect callers to know that we're varidic
                                        (func_value (mif variadic (mod_fval_to_wrap func_value) func_value))
                                        ; Put our eventual func_value in the memo before we actually compile for recursion etc
                                        (memo (put (put memo new_hash func_value) old_hash func_value))

                                        ((inner_analysis_data analysis_err pectx) (function-analysis c memo pectx))
                                        (ctx (array datasi funcs memo env pectx outer_inline_locals))
                                        ; EARLY QUIT IF Analysis Error
                                        ) (mif analysis_err (array nil nil analysis_err ctx) (dlet (
                                        (new_inline_locals (array))
                                        (ctx (array datasi funcs memo env pectx new_inline_locals))


                                        (new_tce_data (array our_func_idx full_params))
                                        (inner_env (make_tmp_inner_env params de? se env_id))

                                        ((params_vec _ _ ctx) (compile-inner ctx (marked_array true false nil (map (lambda (k) (marked_symbol nil k)) full_params) nil) true false outer_s_env_access_code s_env_access_code 0 nil analysis_nil))
                                        (basic_get_s_env_code (local.get '$s_env))
                                        (generate_get_s_env_code (local.tee '$s_env (call '$env_alloc (i64.const params_vec)

                                                                                                            (local.set '$tmp_ptr (call '$malloc (i32.const (* 8 (len full_params)))))
                                                                                                            (flat_map (lambda (i) (i64.store (* i 8) (local.get '$tmp_ptr)
                                                                                                                                             (generate_dup (local.get (idx full_params i))))) 
                                                                                                                      (range 0 (len full_params)))
                                                                                                            (mk_array_code_rc_const_len (len full_params) (local.get '$tmp_ptr))

                                                                                                            (generate_dup (local.get '$outer_s_env)))))
                                        (lazy_get_s_env_code (_if '$have_s_env '(result i64)
                                                                 (i64.ne (i64.const nil_val) (local.get '$s_env))
                                                                 (then basic_get_s_env_code)
                                                                 (else generate_get_s_env_code
                                                                       ;(call '$print (i64.const params_vec))
                                                                       ;(call '$print (i64.const newline_msg_val))
                                                                       ;(local.set '$outer_s_env (i64.const nil_val))
                                                                       )))
                                        (new_get_s_env_code (if dont_lazy_env basic_get_s_env_code lazy_get_s_env_code))
                                        ((datasi funcs memo env pectx inline_locals) ctx)
                                        (inner_ctx (array datasi funcs memo inner_env pectx inline_locals))

                                        ((inner_value inner_code err ctx) (compile-inner inner_ctx body false false (local.get '$outer_s_env) new_get_s_env_code 0 new_tce_data inner_analysis_data))
                                        (_ (true_print "Done compile_body func def compile-inner " full_params))
                                        ; Don't overwrite env with what was our inner env! Env is returned as part of context to our caller!
                                        ((datasi funcs memo _was_inner_env pectx inline_locals) ctx)
                                        (ctx (array datasi funcs memo env pectx inline_locals))


                                        (inner_code (mif inner_value (i64.const (mod_fval_to_wrap inner_value)) inner_code))
                                        (wrapper_func (func '$wrapper_func '(param $params i64) '(param $d_env i64) '(param $outer_s_env i64) '(result i64) '(local $param_ptr i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                                                (_if '$params_len_good
                                                    (if variadic    (i32.lt_u (extract_size_code (local.get '$params)) (i32.const (- (len params) 1)))
                                                                    (i32.ne   (extract_size_code (local.get '$params)) (i32.const (len params))))
                                                    (then
                                                        (generate_drop (local.get '$params))
                                                        (generate_drop (local.get '$outer_s_env))
                                                        (generate_drop (local.get '$d_env))
                                                        (call '$print (i64.const bad_params_number_msg_val))
                                                        (unreachable)
                                                    )
                                                )
                                                (call (+ (len old_funcs) 1 num_pre_functions)
                                                      (local.set '$param_ptr (extract_ptr_code (local.get '$params)))
                                                      (flat_map (lambda (i) (generate_dup (i64.load (* i 8) (local.get '$param_ptr)))) (range 0 normal_params_length))
                                                      (if variadic
                                                           (call '$slice_impl (local.get '$params) (i32.const (- (len params) 1)) (i32.const -1))
                                                           (generate_drop (local.get '$params)))
                                                      (mif de?
                                                            (local.get '$d_env)
                                                            (generate_drop (local.get '$d_env)))
                                                      (local.get '$outer_s_env))
                                        ))
                                        ((datasi funcs memo env pectx inline_locals) ctx)
                                        (parameter_symbols (map (lambda (k) (array 'param k 'i64)) full_params))
                                        (our_inline_locals (map (lambda (k) (array 'local k 'i64)) (filter (lambda (x) (!= '___TCE___ x)) inline_locals)))

                                        (our_func (apply func (concat (array '$userfunc) parameter_symbols (array '(param $outer_s_env i64) '(result i64) '(local $param_ptr i32) '(local $s_env i64) '(local $tmp_ptr i32) '(local $tmp i64) '(local $prim_tmp_a i64) '(local $prim_tmp_b i64) '(local $prim_tmp_c i64) '(local $prim_tmp_d i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)) our_inline_locals (array

                                            ;(local.set '$s_env (i64.const nil_val))
                                            (if dont_lazy_env (_drop generate_get_s_env_code)
                                                              (local.set '$s_env (i64.const nil_val)))
                                            (mif (in_array '___TCE___ inline_locals)
                                                  (concat
                                                        (_loop '___TCE___
                                                              inner_code
                                                              (local.set '$tmp)
                                                        )
                                                        (local.get '$tmp)
                                                  )
                                                  inner_code
                                            )

                                            (generate_drop (local.get '$s_env))
                                            (generate_drop (local.get '$outer_s_env))
                                            (flat_map (lambda (k) (generate_drop (local.get k))) full_params)
                                        ))))
                                        ; replace our placeholder with the real one
                                        (funcs (concat old_funcs wrapper_func our_func (drop funcs (+ 2 (len old_funcs)))))

                                        ) (array func_value nil err (array datasi funcs memo env pectx outer_inline_locals)))
                                    ))))
                                    (_ (print_strip "returning " func_value " for " c))
                                    (_ (if (and (not func_err) (not (int? func_value))) (error "BADBADBADfunc")))

                                    (full_result (cond
                                                      ((!= nil func_err) (array nil nil (str func_err ", from compiling comb body") ctx))
                                                      ((!= nil env_err)  (array nil nil (str env_err  ", from compiling env")       ctx))
                                                      ((!= nil env_val)  (array (combine_env_comb_val env_val func_value) nil nil ctx))
                                                      (true              (array nil (combine_env_code_comb_val_code env_code (mod_fval_to_wrap func_value)) nil ctx))))
                                ) full_result
                                ))))

                   (true        (error (str "Can't compile-inner impossible " c)))
              )))
              (_ (true_print "Made compile-inner closure"))

              ;(_ (println "compiling partial evaled " (str_strip marked_code)))
              ;(_ (true_print "compiling partial evaled " (true_str_strip marked_code)))
              ;(_ (true_print "compiling partial evaled "))
              (ctx (array datasi funcs memo root_marked_env pectx (array)))

              (_ (true_print "About to compile a bunch of symbols & strings"))

              ((run_val _ _ ctx)                (compile-inner ctx (marked_symbol nil 'run)   true false (array) (array) 0 nil analysis_nil))
              ((exit_val _ _ ctx)               (compile-inner ctx (marked_symbol nil 'exit)  true false (array) (array) 0 nil analysis_nil))
              ((args_val _ _ ctx)               (compile-inner ctx (marked_symbol nil 'args)  true false (array) (array) 0 nil analysis_nil))
              ((read_val _ _ ctx)               (compile-inner ctx (marked_symbol nil 'read)  true false (array) (array) 0 nil analysis_nil))
              ((write_val _ _ ctx)              (compile-inner ctx (marked_symbol nil 'write) true false (array) (array) 0 nil analysis_nil))
              ((open_val _ _ ctx)               (compile-inner ctx (marked_symbol nil 'open)  true false (array) (array) 0 nil analysis_nil))
              ((monad_error_msg_val _ _ ctx)    (compile-inner ctx (marked_val "Not a legal monad ( ['args        <cont (arg_array error?)>] / ['read fd len <cont(data error_no)>] / ['write fd data <cont(num_written error_no)>] / ['open fd path <cont(new_fd error_no)>] / ['exit exit_code] / ['run <cont()>])") true false (array) (array) 0 nil analysis_nil))
              ((bad_args_val _ _ ctx)           (compile-inner ctx (marked_val "<error with args>") true false   (array) (array) 0 nil analysis_nil))
              ((bad_read_val _ _ ctx)           (compile-inner ctx (marked_val "<error with read>") true false   (array) (array) 0 nil analysis_nil))
              ((exit_msg_val _ _ ctx)           (compile-inner ctx (marked_val "Exiting with code: ") true false (array) (array) 0 nil analysis_nil))

              (_ (true_print "about ot compile the root_marked_env"))

              ((root_marked_env_val _ _ ctx)    (compile-inner ctx root_marked_env true false (array) (array) 0 nil analysis_nil))

              (_ (true_print "made the vals"))

              (_ (true_print "gonna compile"))
              ((compiled_value_ptr compiled_value_code compiled_value_error ctx) (compile-inner ctx marked_code true false (array) (array) 0 nil analysis_nil))
              ((datasi funcs memo root_marked_env pectx inline_locals) ctx)
              (compiled_value_code (mif compiled_value_ptr (i64.const (mod_fval_to_wrap compiled_value_ptr)) compiled_value_code))

              ; Swap for when need to profile what would be an error
              ;(compiled_value_ptr (mif compiled_value_error 0 compiled_value_ptr))
              (_ (mif compiled_value_error (error compiled_value_error)))

              ; Ok, so the outer loop handles the IO monads
                ; ('args        <cont (arg_array error?)>)
                ; ('exit        code)
                ; ('read        fd   len       <cont (data error?)>)
                ; ('write       fd   "data"    <cont (num_written error?)>)
                ; ('open        fd   path      <cont (opened_fd error?)>)
                ; Could add some to open like lookup flags, o flags, base rights
                ;                             ineriting rights, fdflags

              (start (func '$start '(local $it i64) '(local $tmp i64) '(local $ptr i32) '(local $monad_name i64) '(local $len i32) '(local $buf i32) '(local $traverse i32) '(local $x i32) '(local $y i32) '(local $code i32) '(local $str i64) '(local $result i64) '(local $debug_malloc_print i32) '(local $rc_bytes i64) '(local $rc_ptr i32) '(local $rc_tmp i32)
                    (local.set '$it compiled_value_code)
                    (block '$exit_block
                        (block '$error_block
                            (_loop '$l
                                ; Not array -> out
                                (br_if '$error_block (is_not_type_code array_tag (local.get '$it)))
                                ; less than len 2 -> out
                                (br_if '$error_block (i32.lt_u (extract_size_code (local.get '$it)) (i32.const 2)))
                                (local.set '$ptr (extract_ptr_code (local.get '$it)))
                                (local.set '$monad_name (i64.load (local.get '$ptr)))

                                (_if '$is_args
                                    (i64.eq (i64.const args_val) (local.get '$monad_name))
                                    (then
                                        ; len != 2
                                        (br_if '$error_block (i32.ne (extract_size_code (local.get '$it)) (i32.const 2)))
                                        ; second entry isn't a comb -> out
                                        (br_if '$error_block (is_not_type_code comb_tag (i64.load 8 (local.get '$ptr))))
                                        (local.set '$tmp (generate_dup (i64.load 8 (local.get '$ptr))))
                                        (generate_drop (local.get '$it))
                                        (local.set '$code (call '$args_sizes_get
                                                                (i32.const iov_tmp)
                                                                (i32.const (+ iov_tmp 4))
                                        ))
                                        (local.set '$len (i32.load (i32.const iov_tmp)))
                                        (_if '$is_error
                                            (i32.eqz (local.get '$code))
                                            (then
                                                (local.set '$ptr (call '$malloc (i32.shl (local.get '$len) (i32.const 3))))
                                                (local.set '$buf (call '$malloc (i32.load (i32.const (+ iov_tmp 4)))))
                                                (local.set '$result (mk_array_code_rc (local.get '$len) (local.get '$ptr)))
                                                (local.set '$code (call '$args_get
                                                                        (local.get '$ptr)
                                                                        (local.get '$buf)))
                                                (_if '$is_error2
                                                    (i32.eqz (local.get '$code))
                                                    (then
                                                      (block '$set_ptr_break
                                                            (_loop '$set_ptr
                                                                (br_if '$set_ptr_break (i32.eqz (local.get '$len)))
                                                                (local.set '$len (i32.sub (local.get '$len) (i32.const 1)))
                                                                (local.set '$traverse (local.tee '$x (i32.load (i32.add (local.get '$ptr) (i32.shl (local.get '$len) (i32.const 2))))))
                                                                (block '$str_len_break
                                                                    (_loop '$str_len
                                                                        (br_if '$str_len_break (i32.eqz (i32.load8_u (local.get '$traverse))))
                                                                        (local.set '$traverse (i32.add (local.get '$traverse) (i32.const 1)))
                                                                        (br '$str_len)
                                                                    )
                                                                )
                                                                (local.set '$traverse (i32.sub (local.get '$traverse) (local.get '$x)))
                                                                (local.set '$y (call '$malloc (local.get '$traverse)))
                                                                (memory.copy (local.get '$y)
                                                                             (local.get '$x)
                                                                             (local.get '$traverse))
                                                                (i64.store (i32.add (local.get '$ptr) (i32.shl (local.get '$len) (i32.const 3)))
                                                                           (mk_string_code_rc (local.get '$traverse) (local.get '$y)))
                                                                (br '$set_ptr)
                                                            )
                                                      )
                                                      (call '$free (local.get '$buf))
                                                      (local.set '$result (call '$array2_alloc (local.get '$result)
                                                                                               (i64.const 0)))
                                                    )
                                                    (else
                                                      (call '$free (local.get '$ptr))
                                                      (call '$free (local.get '$buf))
                                                      (local.set '$result (call '$array2_alloc (i64.const bad_args_val)
                                                                                               (mk_int_code_i32u (local.get '$code))))
                                                    )
                                                )
                                            )
                                            (else
                                                (local.set '$result (call '$array2_alloc (i64.const bad_args_val)
                                                                                         (mk_int_code_i32u (local.get '$code))))
                                            )
                                        )

                                        (generate_drop (global.get '$debug_func_to_call))
                                        (generate_drop (global.get '$debug_params_to_call))
                                        (generate_drop (global.get '$debug_env_to_call))
                                        (global.set '$debug_func_to_call   (generate_dup (local.get '$tmp)))
                                        (global.set '$debug_params_to_call (generate_dup (local.get '$result)))
                                        (global.set '$debug_env_to_call (i64.const root_marked_env_val))
                                        (local.set '$it (call_indirect
                                            ;type
                                            k_vau
                                            ;table
                                            0
                                            ;params
                                            (local.get '$result)
                                            ;top_env
                                            (i64.const root_marked_env_val)
                                            ; static env
                                            (extract_func_env_code (local.get '$tmp))
                                            ;func_idx
                                            (extract_func_idx_code (local.get '$tmp))
                                        ))
                                        (br '$l)
                                    )
                                )

				(_if '$is_run
				     (i64.eq (i64.const run_val) (local.get '$monad_name))
				     (then
				      ;; len != 2
				      (br_if '$error_block (i32.ne (extract_size_code (local.get '$it)) (i32.const 2)))
				      ;; second entry isn't a comb -> out
				      (br_if '$error_block (is_not_type_code comb_tag (i64.load 8 (local.get '$ptr))))
				      (local.set '$tmp (generate_dup (i64.load 8 (local.get '$ptr))))
				      (generate_drop (local.get '$it))
				      (generate_drop (global.get '$debug_func_to_call))
				      (generate_drop (global.get '$debug_params_to_call))
				      (generate_drop (global.get '$debug_env_to_call))
				      (global.set '$debug_func_to_call   (generate_dup (local.get '$tmp)))
				      (global.set '$debug_params_to_call (i64.const nil_val))
				      (global.set '$debug_env_to_call (i64.const root_marked_env_val))
				      (local.set '$it (call_indirect
						       ;;type
						       k_vau
						       ;;table
						       0
						       ;;params
						       (i64.const nil_val)
						       ;;top_env
						       (i64.const root_marked_env_val)
						       ;; static env
						       (extract_func_env_code (local.get '$tmp))
						       ;;func_idx
						       (extract_func_idx_code (local.get '$tmp))
						       ))
				      (br '$l)
				      )
				     )

                                ; second entry isn't an int -> out
                                (br_if '$error_block (is_not_type_code int_tag (i64.load 8 (local.get '$ptr))))

                                ; ('exit        code)
                                (_if '$is_exit
                                    (i64.eq (i64.const exit_val) (local.get '$monad_name))
                                    (then
                                        ; len != 2
                                        (br_if '$error_block (i32.ne (extract_size_code (local.get '$it)) (i32.const 2)))
                                        (call '$print (i64.const exit_msg_val))
                                        (call '$print (i64.load 8 (local.get '$ptr)))
                                        (br '$exit_block)
                                    )
                                )

                                ; if len != 4
                                (br_if '$error_block (i32.ne (extract_size_code (local.get '$it)) (i32.const 4)))

                                ; ('read        fd   len       <cont (data error_code)>)
                                (_if '$is_read
                                    (i64.eq (i64.const read_val) (local.get '$monad_name))
                                    (then
                                        ; third entry isn't an int -> out
                                        (br_if '$error_block (is_not_type_code int_tag (i64.load 16 (local.get '$ptr))))
                                        ; fourth entry isn't a comb -> out
                                        (br_if '$error_block (is_not_type_code comb_tag (i64.load 24 (local.get '$ptr))))
                                        ; iov <32bit len><32bit addr> + <32bit num written>
                                        (i32.store 4 (i32.const iov_tmp) (local.tee '$len (i32.wrap_i64 (extract_int_code (i64.load 16 (local.get '$ptr))))))
                                        (i32.store 0 (i32.const iov_tmp) (local.tee '$buf (call '$malloc (local.get '$len))))
                                        (local.set '$code (call '$fd_read
                                              (i32.wrap_i64 (extract_int_code (i64.load 8 (local.get '$ptr))))         ;; file descriptor
                                              (i32.const iov_tmp)                                                      ;; *iovs
                                              (i32.const 1)                                                            ;; iovs_len
                                              (i32.const (+ 8 iov_tmp))                                                ;; nwritten
                                        ))

                                        (local.set '$str (mk_string_code_rc (i32.load 8 (i32.const iov_tmp)) (local.get '$buf)))
                                        (_if '$is_error
                                            (i32.eqz (local.get '$code))
                                            (then
                                                (local.set '$result (call '$array2_alloc (local.get '$str)
                                                                                         (i64.const 0)))
                                            )
                                            (else
                                                (generate_drop (local.get '$str))
                                                (local.set '$result (call '$array2_alloc (i64.const bad_read_val)
                                                                                         (mk_int_code_i32u (local.get '$code))))
                                            )
                                        )

                                        (local.set '$tmp (generate_dup (i64.load 24 (local.get '$ptr))))
                                        (generate_drop (global.get '$debug_func_to_call))
                                        (generate_drop (global.get '$debug_params_to_call))
                                        (generate_drop (global.get '$debug_env_to_call))
                                        (global.set '$debug_func_to_call   (generate_dup (local.get '$tmp)))
                                        (global.set '$debug_params_to_call (generate_dup (local.get '$result)))
                                        (global.set '$debug_env_to_call (i64.const root_marked_env_val))
                                        (generate_drop (local.get '$it))
                                        (local.set '$it (call_indirect
                                            ;type
                                            k_vau
                                            ;table
                                            0
                                            ;params
                                            (local.get '$result)
                                            ;top_env
                                            (i64.const root_marked_env_val)
                                            ; static env
                                            (extract_func_env_code (local.get '$tmp))
                                            ;func_idx
                                            (extract_func_idx_code (local.get '$tmp))
                                        ))
                                        (br '$l)
                                    )
                                )

                                ; ('write       fd   "data"    <cont (num_written error_code)>)
                                (_if '$is_write
                                    (i64.eq (i64.const write_val) (local.get '$monad_name))
                                    (then
                                        ; third entry isn't a string -> out
                                        (br_if '$error_block (is_not_type_code string_tag (i64.load 16 (local.get '$ptr))))
                                        ; fourth entry isn't a comb -> out
                                        (br_if '$error_block (is_not_type_code comb_tag (i64.load 24 (local.get '$ptr))))
                                        ;  <string_size32><string_ptr29>011
                                        (local.set '$str (i64.load 16 (local.get '$ptr)))

                                        ; iov <32bit addr><32bit len> + <32bit num written>
                                        (i32.store 0 (i32.const iov_tmp) (extract_ptr_code  (local.get '$str)))
                                        (i32.store 4 (i32.const iov_tmp) (extract_size_code (local.get '$str)))
                                        (local.set '$code (call '$fd_write
                                              (i32.wrap_i64 (extract_int_code (i64.load 8 (local.get '$ptr))))         ;; file descriptor
                                              (i32.const iov_tmp)                                                      ;; *iovs
                                              (i32.const 1)                                                            ;; iovs_len
                                              (i32.const (+ 8 iov_tmp))                                                ;; nwritten
                                        ))
                                        (local.set '$result (call '$array2_alloc (mk_int_code_i32u (i32.load (i32.const (+ 8 iov_tmp))))
                                                                                 (mk_int_code_i32u (local.get '$code))))

                                        (local.set '$tmp (generate_dup (i64.load 24 (local.get '$ptr))))
                                        (generate_drop (global.get '$debug_func_to_call))
                                        (generate_drop (global.get '$debug_params_to_call))
                                        (generate_drop (global.get '$debug_env_to_call))
                                        (global.set '$debug_func_to_call   (generate_dup (local.get '$tmp)))
                                        (global.set '$debug_params_to_call (generate_dup (local.get '$result)))
                                        (global.set '$debug_env_to_call (i64.const root_marked_env_val))
                                        ;(call '$print (i64.const pre_write_callback))
                                        ;(call '$print (local.get '$tmp))
                                        ;(call '$print (extract_func_env_code (local.get '$tmp)))
                                        ;(call '$print (i64.const newline_msg_val))
                                        ;(call '$print (mk_int_code_i64 (local.get '$tmp)))
                                        ;(call '$print (i64.const newline_msg_val))
                                        ;(call '$print (mk_int_code_i64 (extract_func_env_code (local.get '$tmp))))
                                        ;(call '$print (i64.const newline_msg_val))
                                        (generate_drop (local.get '$it))
                                        (local.set '$it (call_indirect
                                            ;type
                                            k_vau
                                            ;table
                                            0
                                            ;params
                                            (local.get '$result)
                                            ;top_env
                                            (i64.const root_marked_env_val)
                                            ; static env
                                            (extract_func_env_code (local.get '$tmp))
                                            ;func_idx
                                            (extract_func_idx_code (local.get '$tmp))
                                        ))
                                        (br '$l)
                                    )
                                )
                                ; ('open        fd   path      <cont (opened_fd error?)>)
                                (_if '$is_open
                                    (i64.eq (i64.const open_val) (local.get '$monad_name))
                                    (then
                                        ; third entry isn't a string -> out
                                        (br_if '$error_block (is_not_type_code string_tag (i64.load 16 (local.get '$ptr))))
                                        ; fourth entry isn't a comb -> out
                                        (br_if '$error_block (is_not_type_code comb_tag   (i64.load 24 (local.get '$ptr))))
                                        (local.set '$str (i64.load 16 (local.get '$ptr)))

                                        (local.set '$code (call '$path_open
                                            (i32.wrap_i64 (extract_int_code (i64.load 8 (local.get '$ptr))))        ;; file descriptor
                                            (i32.const 0)                                                           ;; lookup flags
                                            (extract_ptr_code  (local.get '$str))                                   ;; path string  *
                                            (extract_size_code (local.get '$str))                                   ;; path string  len
                                            (i32.const 1)                                                           ;; o flags
                                            (i64.const 66)                                                          ;; base rights
                                            (i64.const 66)                                                          ;; inheriting rights
                                            (i32.const 0)                                                           ;; fdflags
                                            (i32.const iov_tmp)                                                     ;; opened fd out ptr
                                        ))

                                        (local.set '$result (call '$array2_alloc (mk_int_code_i32u (i32.load (i32.const iov_tmp)))
                                                                                 (mk_int_code_i32u (local.get '$code))))

                                        (local.set '$tmp (generate_dup (i64.load 24 (local.get '$ptr))))
                                        (generate_drop (global.get '$debug_func_to_call))
                                        (generate_drop (global.get '$debug_params_to_call))
                                        (generate_drop (global.get '$debug_env_to_call))
                                        (global.set '$debug_func_to_call   (generate_dup (local.get '$tmp)))
                                        (global.set '$debug_params_to_call (generate_dup (local.get '$result)))
                                        (global.set '$debug_env_to_call (i64.const root_marked_env_val))
                                        (generate_drop (local.get '$it))
                                        (local.set '$it (call_indirect
                                            ;type
                                            k_vau
                                            ;table
                                            0
                                            ;params
                                            (local.get '$result)
                                            ;top_env
                                            (i64.const root_marked_env_val)
                                            ; static env
                                            (extract_func_env_code (local.get '$tmp))
                                            ;func_idx
                                            (extract_func_idx_code (local.get '$tmp))
                                        ))
                                        (br '$l)
                                    )
                                )
                            )
                        )
                        ; print error
                        (call '$print (i64.const monad_error_msg_val))
                        (call '$print (local.get '$it))
                    )
                    (generate_drop (local.get '$it))
                    (generate_drop (global.get '$debug_func_to_call))
                    (generate_drop (global.get '$debug_params_to_call))
                    (generate_drop (global.get '$debug_env_to_call))
                    ;(generate_drop (global.get '$symbol_intern))


          (mk_int_code_i32s (global.get '$num_array_maxsubdrops))
          (mk_int_code_i32s (global.get '$num_array_subdrops))
          (mk_int_code_i32s (global.get '$num_array_innerdrops))
          (mk_int_code_i32s (global.get '$num_env_innerdrops))



                    (mk_int_code_i32s (global.get '$num_interned_symbols))
                    (mk_int_code_i32s (global.get '$num_frees))
                    (mk_int_code_i32s (global.get '$num_mallocs))
                    (mk_int_code_i32s (global.get '$num_sbrks))

                    (mk_int_code_i32s (global.get '$num_compiled_dzero))
                    (mk_int_code_i32s (global.get '$num_compiled_done))
                    (mk_int_code_i32s (global.get '$num_interp_dzero))
                    (mk_int_code_i32s (global.get '$num_interp_done))
                    (mk_int_code_i32s (global.get '$num_all_evals))
                    (mk_int_code_i32s (global.get '$num_evals))
                    (call '$print (i64.const newline_msg_val))
                    (call '$print (i64.const newline_msg_val))
                    (call '$print (i64.const newline_msg_val))
                    (call '$print (i64.const newline_msg_val))

                    (call '$print )
                    (call '$print (i64.const newline_msg_val))
                    (call '$print )
                    (call '$print (i64.const newline_msg_val))
                    (call '$print )
                    (call '$print (i64.const newline_msg_val))
                    (call '$print )
                    (call '$print (i64.const newline_msg_val))
                    (call '$print )
                    (call '$print (i64.const newline_msg_val))
                    (call '$print )

                    (call '$print (i64.const newline_msg_val))
                    (call '$print (i64.const newline_msg_val))
                    (call '$print (i64.const newline_msg_val))
                    (call '$print (i64.const newline_msg_val))

                    (call '$print (i64.const newline_msg_val))
                    (call '$print )
                    (call '$print (i64.const newline_msg_val))
                    (call '$print )
                    (call '$print (i64.const newline_msg_val))
                    (call '$print )
                    (call '$print (i64.const newline_msg_val))
                    (call '$print )
                    (call '$print (i64.const newline_msg_val))
                    (call '$print (i64.const newline_msg_val))
                    (call '$print )
                    (call '$print (i64.const newline_msg_val))
                    (call '$print )
                    (call '$print (i64.const newline_msg_val))
                    (call '$print )
                    (call '$print (i64.const newline_msg_val))
                    (call '$print )
                    (call '$print (i64.const newline_msg_val))
              ))
              (_ (true_print "Beginning all symbol print"))
              ((datasi symbol_intern_val) (foldl-tree (dlambda ((datasi a) k v) (mif (and (array? k) (marked_symbol? k))
                                                                                     (dlet (
                                                                                            ;(_ (true_print "symbol? " k " " v))
                                                                                            ((a_loc a_len datasi) (alloc_data (concat (i64_le_hexify v)
                                                                                                                                      (i64_le_hexify a))
                                                                                                                              datasi))
                                                                                           ) (array datasi (mk_array_value 2 a_loc)))
                                                                                     (array datasi a))) (array datasi nil_val) memo))
              (_ (true_print "Ending all symbol print"))
              ((watermark datas) datasi)
          ) (concat
              (global '$data_end '(mut i32) (i32.const watermark))
              (global '$symbol_intern '(mut i64) (i64.const symbol_intern_val))
              datas funcs start
              (table  '$tab (len funcs) 'funcref)
              (apply elem (cons (i32.const 0) (range dyn_start (+ num_pre_functions (len funcs)))))
              (memory '$mem (+ 2 (>> watermark 16)))
          ))
          (export "memory" '(memory $mem))
          (export "_start" '(func   $start))
    )))))


    (run_partial_eval_test (lambda (s) (dlet (
                            (_ (print "\n\ngoing to partial eval " s))
                            ((pectx err result) (partial_eval (read-string s)))
                            (_ (true_print "result of test \"" s "\" => " (true_str_strip result) " and err " err))
                            ) nil)))


    (test-most (lambda () (begin
        (print (val? '(val)))
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
        (print ( (dlambda ((a b)) a) '(1337 1338)))
        (print ( (dlambda ((a b)) b) '(1337 1338)))

        (print (str 1 2 3 (array 1 23 4) "a" "B"))

        (print (dlet ( (x 2) ((a b) '(1 2)) (((i i2) i3) '((5 6) 7)) ) (+  x a b i i2 i3)))

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

        (print "mif tests")
        (print (mif true 1 2))
        (print (mif false 1 2))
        (print (mif true 1))
        (print (mif false 1))
        (print "2 nils")
        (print (mif nil 1 2))
        (print (mif nil 1))
        (print "2 1s")
        (print (mif 1 1 2))
        (print (mif 1 1))
        (print "mif tests end")

        (print (get-value (put (put empty_dict 3 4) 1 2) 3))
        (print (get-value (put (put empty_dict 3 4) 1 2) 1))

        (print (get-value-or-false (put (put empty_dict 3 4) 1 2) 3))
        (print (get-value-or-false (put (put empty_dict 3 4) 1 2) 1))
        (print (get-value-or-false (put (put empty_dict 3 4) 1 2) 5))

        (print "zip " (zip '(1 2 3) '(4 5 6) '(7 8 9)))

        (print (run_partial_eval_test "(+ 1 2)"))
        ;(print) (print)
        (print (run_partial_eval_test "(cond false 1 true 2)"))
        (print (run_partial_eval_test "(log 1)"))
        (print (run_partial_eval_test "((vau (x) (+ x 1)) 2)"))


        (print (run_partial_eval_test "(+ 1 2)"))
        (print (run_partial_eval_test "(vau (y) (+ 1 2))"))
        (print (run_partial_eval_test "((vau (y) (+ 1 2)) 4)"))
        (print (run_partial_eval_test "((vau (y) y) 4)"))
        (print (run_partial_eval_test "((vau (y) (+ 13 2 y)) 4)"))
        (print (run_partial_eval_test "((wrap (vau (y) (+ 13 2 y))) (+ 3 4))"))
        (print (run_partial_eval_test "(vau de (y) (+ (eval y de) (+ 1 2)))"))
        (print (run_partial_eval_test "((vau de (y) ((vau dde (z) (+ 1 (eval z dde))) y)) 17)"))

        (print (run_partial_eval_test "(cond false 1 false 2 (+ 1 2) 3 true 1337)"))
        (print (run_partial_eval_test "(vau de (x) (cond false 1 false 2 x 3 true 42))"))
        (print (run_partial_eval_test "(vau de (x) (cond false 1 false 2 3 x true 42))"))

        (print (run_partial_eval_test "(combiner? true)"))
        (print (run_partial_eval_test "(combiner? (vau de (x) x))"))
        (print (run_partial_eval_test "(vau de (x) (combiner? x))"))

        (print (run_partial_eval_test "((vau (x) x) a)"))

        (print (run_partial_eval_test "(env? true)"))
        ; this doesn't partially eval, but it could with a more percise if the marked values were more percise
        (print (run_partial_eval_test "(vau de (x) (env? de))"))
        (print (run_partial_eval_test "(vau de (x) (env? x))"))
        (print (run_partial_eval_test "((vau de (x) (env? de)) 1)"))

        (print (run_partial_eval_test "((wrap (vau (let1) (let1 a 12 (+ a 1)))) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))"))
        (print (run_partial_eval_test "((wrap (vau (let1) (let1 a 12 (vau (x) (+ a 1))))) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))"))
        (print (run_partial_eval_test "((wrap (vau (let1) (let1 a 12 (wrap (vau (x) (+ x a 1)))))) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))"))
        (print (run_partial_eval_test "((wrap (vau (let1) (let1 a 12 (wrap (vau (x) (let1 y (+ a 1) (+ y x a))))))) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))"))

        ;(print "\n\nnil test\n")
        ;(print (run_partial_eval_test "nil"))
        ;(print (run_partial_eval_test "(nil? 1)"))
        ;(print (run_partial_eval_test "(nil? nil)"))

        (print "\n\nlet 4.3\n\n")
        (print (run_partial_eval_test "((wrap (vau (let1)
                                    (let1 a 12 (wrap (vau (x) (let1 y (+ a 1) (+ y x a))))
                                ))) (vau de (s v b) (eval (array (array wrap (array vau (array s) b)) v) de)))"))
        (print "\n\nlet 4.7\n\n")
        (print (run_partial_eval_test "((wrap (vau (let1)
                                    (let1 a 12 (wrap (vau (x) (let1 y (+ x a 1) (+ y x a))))
                                ))) (vau de (s v b) (eval (array (array wrap (array vau (array s) b)) v) de)))"))

        (print "\n\nlet 5\n\n")
        (print (run_partial_eval_test "((wrap (vau (let1)
                                    (let1 a 12 (wrap (vau (x) (let1 y (+ x a 1) (+ y x a))))
                                ))) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))"))

        (print "\n\nlambda 1\n\n")
        (print (run_partial_eval_test "((wrap (vau (let1)
                                   (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
                                   (lambda (x) x)
                                   ))) (vau de (s v b) (eval (array (array wrap (array vau (array s) b)) v) de)))"))
        (print "\n\nlambda 2\n\n")
        (print (run_partial_eval_test "((wrap (vau (let1)
                                   (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
                                   (let1 a 12
                                         (lambda (x) (+ a x)))
                                   ))) (vau de (s v b) (eval (array (array wrap (array vau (array s) b)) v) de)))"))
        (print "\n\nlambda 3\n\n")
        (print (run_partial_eval_test "((wrap (vau (let1)
                                   (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
                                   (let1 a 12
                                         (lambda (x) (let1 b (+ a x)
                                                             (+ a x b))))
                                   ))) (vau de (s v b) (eval (array (array wrap (array vau (array s) b)) v) de)))"))

        (print (run_partial_eval_test "(array 1 2 3 4 5)"))
        (print (run_partial_eval_test "((wrap (vau (a & rest) rest)) 1 2 3 4 5)"))

        (print "\n\nrecursion test\n\n")
        (print (run_partial_eval_test "((wrap (vau (let1)
                                   (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
                                   ((lambda (x n) (x x n)) (lambda (recurse n) (cond (!= 0 n) (* n (recurse recurse (- n 1)))
                                                                                     true     1                               )) 5)
                                   ))) (vau de (s v b) (eval (array (array wrap (array vau (array s) b)) v) de)))"))

        (print "\n\nlambda recursion test\n\n")
        (print (run_partial_eval_test "((wrap (vau (let1)
                                   (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
                                   (lambda (n) ((lambda (x n) (x x n)) (lambda (recurse n) (cond (!= 0 n) (* n (recurse recurse (- n 1)))
                                                                                     true     1                               )) n))
                                   ))) (vau de (s v b) (eval (array (array wrap (array vau (array s) b)) v) de)))"))

        ; The issue with this one is that (x2 x2) trips the infinate recursion protector, but then
        ; that array gets marked as attempted & needing no more evaluation, and is frozen forever.
        ; Then, when the recursion is actually being used, it won't keep going and you only get
        ; the first level.
        (print "\n\nlambda recursion Y combiner test\n\n")
        (print (run_partial_eval_test "((wrap (vau (let1)
                                   (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
                                   (let1 lapply (lambda (f1 p)     (eval (concat (array (unwrap f1)) p)))
                                   (let1 Y (lambda (f3)
                                       ((lambda (x1) (x1 x1))
                                        (lambda (x2) (f3 (lambda (& y) (lapply (x2 x2) y))))))
                                   ((Y (lambda (recurse) (lambda (n) (cond (!= 0 n) (* n (recurse (- n 1)))
                                                                           true     1))))
                                    5)
                                   ))))) (vau de (s v b) (eval (array (array wrap (array vau (array s) b)) v) de)))"))


        (print (run_partial_eval_test "(len \"asdf\")"))
        (print (run_partial_eval_test "(idx \"asdf\" 1)"))
        (print (run_partial_eval_test "(slice \"asdf\" 1 3)"))
        (print (run_partial_eval_test "(concat \"asdf\" \";lkj\")"))


        (true_print "ok, hex of 0 is " (hex_digit #\0))
        (true_print "ok, hex of 1 is " (hex_digit #\1))
        (true_print "ok, hex of a is " (hex_digit #\a))
        (true_print "ok, hex of A is " (hex_digit #\A))
        (true_print "ok, hexify of 1337 is " (i64_le_hexify 1337))
        (true_print "ok, hexify of 10 is " (i64_le_hexify 10))
        (true_print "ok, hexify of 15 is " (i64_le_hexify 15))
        (true_print "ok, hexfy of 15 << 60 is " (i64_le_hexify (<< 15 60)))
        (dlet (
            ;(output1 (wasm_to_binary (module)))
            ;(output2 (wasm_to_binary (module
            ;      (import "wasi_unstable" "path_open"
            ;              '(func $path_open  (param i32 i32 i32 i32 i32 i64 i64 i32 i32)
            ;                                 (result i32)))
            ;      (import "wasi_unstable" "fd_prestat_dir_name"
            ;              '(func $fd_prestat_dir_name  (param i32 i32 i32)
            ;                               (result i32)))
            ;      (import "wasi_unstable" "fd_read"
            ;              '(func $fd_read  (param i32 i32 i32 i32)
            ;                               (result i32)))
            ;      (import "wasi_unstable" "fd_write"
            ;              '(func $fd_write (param i32 i32 i32 i32)
            ;                               (result i32)))
            ;      (memory '$mem 1)
            ;      (global '$gi 'i32       (i32.const 8))
            ;      (global '$gb '(mut i64) (i64.const 9))
            ;      (table  '$tab 2 'funcref)
            ;      (data (i32.const 16) "HellH") ;; adder to put, then data


            ;      (func '$start
            ;            (i32.store (i32.const 8) (i32.const 16))  ;; adder of data
            ;            (i32.store (i32.const 12) (i32.const 5)) ;; len of data
            ;            ;; open file
            ;            (call 0 ;$path_open
            ;                  (i32.const 3) ;; file descriptor
            ;                  (i32.const 0) ;; lookup flags
            ;                  (i32.const 16) ;; path string  *
            ;                  (i32.load (i32.const 12)) ;; path string  len
            ;                  (i32.const 1) ;; o flags
            ;                  (i64.const 66) ;; base rights
            ;                  (i64.const 66) ;; inheriting rights
            ;                  (i32.const 0) ;; fdflags
            ;                  (i32.const 4) ;; opened fd out ptr
            ;             )
            ;            (drop)
            ;            (block '$a
            ;                (block '$b
            ;                    (br '$a)
            ;                    (br_if  '$b
            ;                            (i32.const 3))
            ;                    (_loop '$l
            ;                        (br '$a)
            ;                        (br '$l)
            ;                    )
            ;                    (_if '$myif
            ;                        (i32.const 1)
            ;                        (then
            ;                            (i32.const 1)
            ;                            (drop)
            ;                            (br '$b)
            ;                        )
            ;                        (else
            ;                            (br '$myif)
            ;                        )
            ;                    )
            ;                    (_if '$another
            ;                        (i32.const 1)
            ;                        (br '$b))
            ;                    (i32.const 1)
            ;                    (_if '$third
            ;                        (br '$b))
            ;                    (_if '$fourth
            ;                        (br '$fourth))
            ;                )
            ;            )
            ;            (call '$fd_read
            ;                  (i32.const 0) ;; file descriptor
            ;                  (i32.const 8) ;; *iovs
            ;                  (i32.const 1) ;; iovs_len
            ;                  (i32.const 12) ;; nwritten, overwrite buf len with it
            ;            )
            ;            (drop)

            ;            ;; print name
            ;            (call '$fd_write
            ;                  (i32.load (i32.const 4)) ;; file descriptor
            ;                  (i32.const 8) ;; *iovs
            ;                  (i32.const 1) ;; iovs_len
            ;                  (i32.const 4) ;; nwritten
            ;            )
            ;            (drop)
            ;      )

            ;      (elem (i32.const 0) '$start '$start)
            ;      (export "memory" '(memory $mem))
            ;      (export "_start" '(func   $start))
            ;)))
            (_ (true_print "first compile"))
            (output3 (compile (partial_eval (read-string "(array 1 (array ((vau (x) x) a) (array \"asdf\"))  2)")) false))
            (_ (true_print "end first compile"))
            (output3 (compile (partial_eval (read-string "(array 1 (array 1 2 3 4) 2 (array 1 2 3 4))")) false))
            (output3 (compile (partial_eval (read-string "empty_env")) false))
            (output3 (compile (partial_eval (read-string "(eval (array (array vau ((vau (x) x) (a b)) (array (array vau ((vau (x) x) x) (array) ((vau (x) x) x)))) 1 2) empty_env)")) false))
            (output3 (compile (partial_eval (read-string "(eval (array (array vau ((vau (x) x) (a b)) (array (array vau ((vau (x) x) x) (array) ((vau (x) x) x)))) empty_env 2) empty_env)")) false))
            (output3 (compile (partial_eval (read-string "(eval (array (array vau ((vau (x) x) x) (array) ((vau (x) x) x))))")) false))
            (output3 (compile (partial_eval (read-string "(vau (x) x)")) false))
            (output3 (compile (partial_eval (read-string "(vau (x) 1)")) false))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) exit) 1)")) false))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (array ((vau (x) x) exit) 1)))")) false))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (array ((vau (x) x) exit) written)))")) false))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) written))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) code))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (array 1337 written 1338 code 1339)))")) false))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (cond (= 0 code) written true code)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (str (= 0 code) written true (array) code)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (log (= 0 code) written true (array) code)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (error (= 0 code) written true code)))")) false))
            ;(output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (or (= 0 code) written true code)))")) false))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (+ written code 1337)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (- written code 1337)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (* written 1337)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (/ 1337 written)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (% 1337 written)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (band 1337 written)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (bor 1337 written)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (bnot written)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (bxor 1337 written)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (<< 1337 written)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (>> 1337 written)))")) false))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (<= (array written) (array 1337))))")) false))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (read-string (cond written \"true\" true 3))))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (read-string (cond written \"     true\" true 3))))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (read-string (cond written \"     true   \" true 3))))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (read-string (cond written \"     false\" true 3))))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (read-string (cond written \"(false (true () true) true)\" true 3))))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (read-string (cond written \"(false (true () true) true) true\" true 3))))")) false))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) open) 3 \"test_out\" (vau (fd code) (array ((vau (x) x) write) fd \"waa\" (vau (written code) (array written code)))))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) open) 3 \"test_out\" (vau (fd code) (array ((vau (x) x) read) fd 10 (vau (data code) (array data code)))))")) false))

            ;(_ (print (slurp "test_parse_in")))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) open) 3 \"test_parse_in\" (vau (fd code) (array ((vau (x) x) read) fd 1000 (vau (data code) (read-string data)))))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"test_parse_in\" (vau (written code) (array (array written))))")) false))


            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (slice args 1 -1)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (len args)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (idx args 0)))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (slice (concat args (array 1 2 3 4) args) 1 -2)))")) false))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (str-to-symbol (str args))))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (get-text (str-to-symbol (str args)))))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (wrap (cond args idx true 0))))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (wrap (wrap (cond args idx true 0)))))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (wrap (wrap (wrap (cond args idx true 0))))))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (unwrap (cond args idx true 0))))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (unwrap (cond args vau true 0))))")) false))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (array (nil? written) (array? written) (bool? written) (env? written) (combiner? written) (string? written) (int? written) (symbol? written))))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau de (written code) (array (nil? (cond written (array) true 4)) (array? (cond written (array 1 2) true 4)) (bool? (= 3 written)) (env? de) (combiner? (cond written (vau () 1) true 43)) (string? (cond written \"a\" 3 3)) (int? (cond written \"a\" 3 3)) (symbol? (cond written ((vau (x) x) x) 3 3)) written)))")) false))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) args))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (a & args) a))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (a & args) args))")) false))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) read) 0 10 (vau (data code) data))")) false))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) read) 0 10 (vau (data code) (array ((vau (x) x) write) 1 data (vau (written code) (array written code)))))")) false))

            (output3 (compile (partial_eval (read-string "(wrap (vau (x) x))")) false))
            (output3 (compile (partial_eval (read-string "len")) false))
            (output3 (compile (partial_eval (read-string "vau")) false))
            (output3 (compile (partial_eval (read-string "(array len 3 len)")) false))
            (output3 (compile (partial_eval (read-string "(+ 1 1337 (+ 1 2))")) false))
            (output3 (compile (partial_eval (read-string "\"hello world\"")) false))
            (output3 (compile (partial_eval (read-string "((vau (x) x) asdf)")) false))
            (output3 (compile (partial_eval (read-string "((wrap (vau (let1)
                                   (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
                                   (array ((vau (x) x) write) 1 \"hahah\" (vau (written code) ((lambda (x n) (x x n)) (lambda (recurse n) (cond (!= 0 n) (* n (recurse recurse (- n 1)))
                                                                                                                                                true     1)) written)))
                                   ))) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))")) false))
            (_ (write_file "./csc_out.wasm" output3))
            (output3 (compile (partial_eval (read-string "(nil? 1)")) false))
            ;(output3 (compile (partial_eval (read-string "(nil? nil)")) false))
        ) (void))
    )))

    (single-test (lambda () (dlet (
        ;(output3 (compile (partial_eval (read-string "1337")) false))
        ;(output3 (compile (partial_eval (read-string "\"This is a longish sring to make sure alloc data is working properly\"")) false))
        ;(output3 (compile (partial_eval (read-string "((vau (x) x) write)")) false))
        ;(output3 (compile (partial_eval (read-string "(wrap (vau (x) x))")) false))
        ;(output3 (compile (partial_eval (read-string "(wrap (vau (x) (log 1337)))")) false))
        ;(output3 (compile (partial_eval (read-string "(wrap (vau (x) (+ x 1337)))")) false))
        ;(output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"w\" (vau (written code) (+ written code 1337)))")) false))
        ;(output3 (compile (partial_eval (read-string "((wrap (vau (let1)
        ;                       (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
        ;                       (array ((vau (x) x) write) 1 \"hahah\" (vau (written code) ((lambda (x n) (x x n)) (lambda (recurse n) (cond (!= 0 n) (* n (recurse recurse (- n 1)))
        ;                                                                                                                                    true     1)) written)))
        ;                       ))) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))")) false))


        ;(output3 (compile (partial_eval (read-string
        ;                           "((wrap (vau root_env (quote)
        ;                            ((wrap (vau (let1)

        ;                            (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
        ;                            (let1 current-env (vau de () de)
        ;                            (let1 lapply (lambda (f p)     (eval (concat (array (unwrap f)) p) (current-env)))
        ;                            (array (quote write) 1 \"test_self_out2\" (vau (written code) 1))
        ;                            )))

        ;                            )) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))
        ;                            )) (vau (x5) x5))")) false))
        ;(_ (write_file "./csc_out.wasm" output3))

        ;(_ (write_file "./csc_out.wasm" (compile (partial_eval (read-string
        ;    "(array ((vau (x5) x5) write)  1 \"written\" (vau (written code) (len (cond (= 0 written) \"asdf\" true \"sdf\"))))")) false)))

        ;(_ (write_file "./csc_out.wasm" (compile (partial_eval (read-string
        ;    "(array ((vau (x5) x5) write)  1 \"written\" (vau (written code) (idx (cond (= 0 written) \"asdf\" true \"sdf\") 1)))")) false)))

        ;(_ (write_file "./csc_out.wasm" (compile (partial_eval (read-string
        ;    "(array ((vau (x5) x5) write)  1 \"written\" (vau (written code) (slice (cond (= 0 written) \"asdf\" true \"abcdefghi\") 1 3)))")) false)))

        ;(_ (write_file "./csc_out.wasm" (compile (partial_eval (read-string
        ;    "(array ((vau (x5) x5) write)  1 \"written\" (vau (written code) (concat \"hehe\" (cond (= 0 written) \"asdf\" true \"abcdefghi\"))))")) false)))

        (_ (write_file "./csc_out.wasm" (compile (partial_eval (read-string
            "(array ((vau (x) x) write)  1 \"enter form: \" (vau (written code)
                  (array ((vau (x) x) read) 0 60 (vau (data code)
                        (array ((vau (x) x) exit) (eval (read-string data)))
                  ))

             ))")) false)))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) read) 0 10 (vau (data code) data))")) false))

    ) void)))

    (run-compiler (lambda (dont_partial_eval dont_lazy_env dont_y_comb dont_prim_inline dont_closure_inline f)
      (dlet (
            (_ (true_print "reading in!"))
            (read_in    (read-string (slurp f)))

            ; This is basicaly (compile <comb0 () ('eval <marked_body> root_env)>)
            ;    this does mean that without partial eval this is an extra and unnecessary lookup of 'eval in the root env but w/e, it's a single load
	    ;                   empty partial_eval_ctx empty partial_eval_error      value to compile
            (body_value (marked_array true false nil (array (marked_symbol nil 'eval) (marked_array true false nil (array quote_internal (mark read_in)) true) root_marked_env) true))
            (constructed_body (idx (try_unval body_value (lambda (_) nil)) 1))
            (constructed_func (marked_comb 0 (+ env_id_start 1) 'outer root_marked_env false (array) constructed_body))
            (constructed_value (marked_array true false nil (array (marked_symbol nil 'run) constructed_func) true))
	    (to_compile (array (array (+ env_id_start 1) empty_dict)    nil          constructed_value))
            ;(_ (true_print "done partialy evaling, now compiling"))
            (_ (true_print "going"))
            (bytes      (compile to_compile dont_partial_eval dont_lazy_env dont_y_comb dont_prim_inline dont_closure_inline))
            ;(_ (true_print "compiled, writng out"))
            (_          (write_file "./csc_out.wasm" bytes))
            ;(_ (true_print "written out"))
        ) (void))
    ))

)
   (begin
       ;(test-most)
       ;(single-test)
       ;(run-compiler "small_test.kp")
       ;(run-compiler "to_compile.kp")
       (true_print "args are " args)
       (dlet ( (com (if (> (len args) 0) (idx args 0) "")) )
             (cond ((= "test"   com) (test-most))
                   ((= "single" com) (single-test))
                   (true             (run-compiler 
                                                   (and (>= (len args) 2) (= "no_partial_eval" (idx args 1)))
                                                   (and (>= (len args) 2) (= "no_lazy_env" (idx args 1)))
                                                   (and (>= (len args) 2) (= "no_y_comb" (idx args 1)))
                                                   (and (>= (len args) 2) (= "no_prim_inline" (idx args 1)))
                                                   (and (>= (len args) 2) (= "no_closure_inline" (idx args 1)))
                                                   com))))

       ;(true_print "GLOBAL_MAX was " GLOBAL_MAX)
       ;(profile-dump-html)
   )
)

;;;;;;;;;;;;;;
; Known TODOs
;;;;;;;;;;;;;;
;
; * NON NAIVE REFCOUNTING
; EVENTUALLY: Support some hard core partial_eval that an fully make (foldl or stuff) short circut effeciencly with double-inlining, finally
;   addressing the strict-languages-don't-compose thing
