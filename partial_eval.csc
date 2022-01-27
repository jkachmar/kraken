(import (chicken process-context))
(import (chicken port))
(import (chicken io))
(import (chicken bitwise))
(import (chicken string))
(import (r5rs))
(define-syntax rec-lambda
    (er-macro-transformer
         (lambda (x r c)
                (let (
                         (name (car (cdr x)))
                         (params (car (cdr (cdr x))))
                         (body (car (cdr (cdr (cdr x)))))
                     )
                     `(rec ,name (lambda ,params ,body))))))

(define-syntax dlet
    (er-macro-transformer
        (lambda (x r c)
            (let* (
                   (items (list-ref x 1))
                   (body (list-ref x 2))
                   (flat_map_i (lambda (f l) ((rec recurse (lambda (f l i) (cond
                                                                            ((equal? '() l) '())
                                                                            (#t      (append (f i (car l)) (recurse f (cdr l) (+ i 1)))))
                                                           )) f l 0)))
                   (flatten-helper (rec recurse (lambda (items)
                                                 (cond
                                                  ((equal? '() items) '())
                                                  (#t           (let* (
                                                                       (clause (car items))
                                                                       (result (cond
                                                                                ((list? (car clause)) (let ((s (gensym)))
                                                                                    (cons `(,s ,(car (cdr clause)))
                                                                                     (flat_map_i (lambda (i x)
                                                                                                  (recurse `((,x (list-ref ,s ,i))))
                                                                                                 )
                                                                                      (car clause)))))
                                                                                (#t                (list clause))))
                                                                      ) (append result (recurse (cdr items)))))
                                                 ))))

                    (flat_items (flatten-helper items))
                  ) `(let* ,flat_items ,body)
             ))))
(define-syntax dlambda
    (er-macro-transformer
         (lambda (x r c)
                (let (
                         (params (list-ref x 1))
                         (param_sym (gensym))
                         (body (list-ref x 2))
                     )
                     `(lambda ,param_sym (dlet ( (,params ,param_sym) ) ,body))))))

(define-syntax needs_params_val_lambda
    (er-macro-transformer
         (lambda (x r c)
                (let ((f_sym (list-ref x 1)))
                     `(needs_params_val_lambda_inner ',f_sym ,f_sym)))))


(define-syntax give_up_eval_params
    (er-macro-transformer
         (lambda (x r c)
                (let ((f_sym (list-ref x 1)))
                     `(give_up_eval_params_inner ',f_sym ,f_sym)))))


(define-syntax mif
    (er-macro-transformer
         (lambda (x r c)
                (let (
                        (cond (list-ref x 1))
                        (v (gensym))
                        (then (list-ref x 2))
                        (else (if (equal? 4 (length x)) (list-ref x 3) ''()))
                     )
                     `(let ((,v ,cond)) (if (and (not (equal? (array) ,v)) ,v) ,then ,else))))))

; Adapted from https://stackoverflow.com/questions/16335454/reading-from-file-using-scheme WTH
(define (slurp path)
 (list->string (call-with-input-file path
    (lambda (input-port)
         (let loop ((x (read-char input-port)))
                (cond
                        ((eof-object? x) '())
                                (#t (begin (cons x (loop (read-char input-port)))))))))))

(let* (
       (= equal?)
       (!= (lambda (a b) (not (= a b))))
       (array list)
       (array? list?)
       (concat (lambda args (cond ((equal?  (length args) 0)   (list))
                                  ((list?   (list-ref args 0)) (apply append args))
                                  ((string? (list-ref args 0)) (apply conc args))
                                  (#t          (begin (print "the bad concat is " args) (error "bad value to concat"))))))
       (len    (lambda (x)  (cond ((list? x)   (length x))
                                  ((string? x) (string-length x))
                                  (#t          (begin (print "the bad len is " x) (error "bad value to len"))))))
       (idx (lambda (x i) (list-ref x (mif (< i 0) (+ i (len x)) i))))
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
       (true_print print)
       (print (lambda x 0))
       ;(true_print print)
       (println print)

       (read-string (lambda (s) (read (open-input-string s))))

       (zip (lambda args (apply map list args)))

       (empty_dict (array))
       (put (lambda (m k v) (cons (array k v) m)))
       (get-value (lambda (d k) (let ((result (alist-ref k d)))
                                     (if (array? result) (idx result 0)
                                                         (error (print "could not find " k " in " d))))))
       (get-value-or-false (lambda (d k) (let ((result (alist-ref k d)))
                                     (if (array? result) (idx result 0)
                                                         false))))

       (% modulo)
       (int? integer?)
       (str? string?)
       (env? (lambda (x) false))
       (combiner? (lambda (x) false))
       (drop (rec-lambda recurse (x i) (mif (= 0 i) x (recurse (cdr x) (- i 1)))))
       (take (rec-lambda recurse (x i) (mif (= 0 i) (array) (cons (car x) (recurse (cdr x) (- i 1))))))
       (slice (lambda (x s e) (let* ( (l (len x))
                                      (s (mif (< s 0) (+ s l 1) s))
                                      (e (mif (< e 0) (+ e l 1) e))
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
                            ((rec-lambda recurse (x) (mif x (begin (display (car x) mp) (recurse (cdr x))) nil)) args)
                            (get-output-string mp))))

       (write_file (lambda (file bytes) (call-with-output-file file (lambda (out) (foldl (lambda (_ o) (write-byte o out)) (void) bytes)))))
      )
(let* (

    (in_array (let ((helper (rec-lambda recurse (x a i) (cond ((= i (len a))   false)
                                                              ((= x (idx a i)) true)
                                                              (true            (recurse x a (+ i 1)))))))
                   (lambda (x a) (helper x a 0))))


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

    (.marked_symbol_needed_for_progress (lambda (x) (idx x 2)))
    (.marked_symbol_is_val              (lambda (x) (= nil (.marked_symbol_needed_for_progress x))))
    (.marked_symbol_value               (lambda (x) (idx x 3)))
    (.comb                              (lambda (x) (slice x 2 -1)))
    (.comb_id                           (lambda (x) (idx x 3)))
    (.comb_env                          (lambda (x) (idx x 5)))
    (.comb_body                         (lambda (x) (idx x 8)))
    (.prim_comb_sym                     (lambda (x) (idx x 3)))
    (.prim_comb                         (lambda (x) (idx x 2)))

    (.marked_env                        (lambda (x) (slice x 2 -1)))
    (.marked_env_has_vals               (lambda (x) (idx x 2)))
    (.marked_env_needed_for_progress    (lambda (x) (idx x 3)))
    (.marked_env_idx                    (lambda (x) (idx x 4)))
    (.marked_env_upper                  (lambda (x) (idx (idx x 5) -1)))
    (.env_marked                        (lambda (x) (idx x 5)))
    (marked_env_real?                   (lambda (x) (= nil (.marked_env_needed_for_progress x))))

    ; Results are either
    ; #t            - any eval will do something
    ; nil           - is a value, no eval will do anything
    ; (3 4 1...)    - list of env de Bruijn indicies that would allow forward progress
    (needed_for_progress (rec-lambda needed_for_progress (x) (cond ((marked_array? x)       (.marked_array_needed_for_progress  x))
                                                                   ((marked_symbol? x)      (.marked_symbol_needed_for_progress x))
                                                                   ((marked_env? x)         (.marked_env_needed_for_progress    x))
                                                                   ((comb? x)               (dlet ((id (.comb_id x))
                                                                                                   (body_needed (needed_for_progress (.comb_body x)))
                                                                                                   (se_needed   (needed_for_progress (.comb_env x))))
                                                                                                (if (or (= true body_needed) (= true se_needed)) true
                                                                                                        (foldl (lambda (a xi) (if (or (= id xi) (in_array xi a)) a (cons xi a)))
                                                                                                               (array) (concat body_needed se_needed))
                                                                                                )))
                                                                   ((prim_comb? x)          nil)
                                                                   ((val? x)                nil)
                                                                   (true                    (error "what is this? in need for progress")))))

    (combine_hash     (lambda (a b) (+ (* 37 a) b)))
    (hash_bool        (lambda (b) (if b 2 3)))
    (hash_num         (lambda (n) (combine_hash 5 n)))
    (hash_string      (lambda (s) (foldl combine_hash 7  (map char->integer (string->list s)))))
    (hash_symbol      (lambda (progress_idxs s) (combine_hash (if (= true progress_idxs) 11 (foldl combine_hash 13 (map (lambda (x) (if (= true x) 13 (+ 1 x))) progress_idxs))) (hash_string (symbol->string s)))))

    (hash_array       (lambda (is_val attempted a) (foldl combine_hash (if is_val 17 (if attempted 19 61)) (map .hash a))))
    (hash_env         (lambda (progress_idxs dbi arrs) (combine_hash (mif dbi (hash_num dbi) 59) (let* (
                                                                (inner_hash (foldl (dlambda (c (s v)) (combine_hash c (combine_hash (hash_symbol true s) (.hash v))))
                                                                                   (cond ((= nil progress_idxs)     23)
                                                                                         ((= true progress_idxs)    29)
                                                                                         (true                      (foldl combine_hash 31 progress_idxs)))
                                                                                   (slice arrs 0 -2)))
                                                                (end (idx arrs -1))
                                                                (end_hash (mif end (.hash end) 41))
                                                                                                         ) (combine_hash inner_hash end_hash)))))
    (hash_comb        (lambda (wrap_level env_id de? se variadic params body)
                                                                              (combine_hash 43 env_id)))
                                                                             ;(combine_hash 43
                                                                             ;(combine_hash env_id
                                                                             ;(combine_hash (mif de? (hash_symbol true de?) 47)
                                                                             ;(combine_hash (.hash se)
                                                                             ;(combine_hash (hash_bool variadic)
                                                                             ;(combine_hash (foldl (lambda (c x) (combine_hash c (hash_symbol true x))) 53 params)
                                                                             ;(.hash body)))))))))
    (hash_prim_comb   (lambda (handler_fun real_or_name) (combine_hash 59 (hash_symbol true real_or_name))))
    (hash_val         (lambda (x) (cond ((bool? x)     (hash_bool x))
                                        ((string? x)   (hash_string x))
                                        ((int? x)      (hash_num x))
                                        (true          (error (str "bad thing to hash_val " x))))))
    ; 89 97 101 103 107 109 113 127 131 137 139 149 151 157 163 167 173

    (marked_symbol    (lambda (progress_idxs x)                        (array 'marked_symbol    (hash_symbol progress_idxs x)                      progress_idxs x)))
    (marked_array     (lambda (is_val attempted x)                     (dlet (
                                                                            ; If not is_val, then if the first entry (combiner) is not done or is a combiner and not function
                                                                            ; shouldn't add the rest of them, since they'll have to be passed without eval
                                                                            ; We do this by ignoring trues for non-first
                                                                            ((_ sub_progress_idxs) (foldl (dlambda ((f a) x)
                                                                                                    (cond ((or (= true a) (and f (= true x))) (array false true))
                                                                                                          ((= true x)                         (array false a))
                                                                                                          (true                               (array false (foldl (lambda (a xi) (if (in_array xi a) a (cons xi a))) a x)))
                                                                                                    )
                                                                                                 ) (array true (array)) (map needed_for_progress x)))
                                                                            ;(_ (print "got " sub_progress_idxs " out of " x))
                                                                            ;(_ (print "\twhich evalated to " (map needed_for_progress x)))
                                                                            (progress_idxs (cond ((and (= nil sub_progress_idxs) (not is_val) attempted)       nil)
                                                                                                 ((and (= nil sub_progress_idxs) (not is_val) (not attempted)) true)
                                                                                                 (true                                                        sub_progress_idxs)))
                                                                        ) (array 'marked_array  (hash_array is_val attempted x)                    is_val attempted progress_idxs x))))
    (marked_env       (lambda (has_vals progress_idxs dbi arrs)        (array 'env              (hash_env progress_idxs dbi arrs)                  has_vals progress_idxs dbi arrs)))
    (marked_val       (lambda (x)                                      (array 'val              (hash_val x)                                       x)))
    (marked_comb      (lambda (wrap_level env_id de? se variadic params body) (array 'comb      (hash_comb wrap_level env_id de? se variadic params body) wrap_level env_id de? se variadic params body)))
    (marked_prim_comb (lambda (handler_fun real_or_name)               (array 'prim_comb        (hash_prim_comb handler_fun real_or_name)          handler_fun real_or_name)))



    (later_head? (rec-lambda recurse (x) (or (and (marked_array? x)  (or (= false (.marked_array_is_val x)) (foldl (lambda (a x) (or a (recurse x))) false (.marked_array_values x))))
                                             (and (marked_symbol? x) (= false (.marked_symbol_is_val x)))
                                         )))

    ; array and comb are the ones wherewhere (= nil (needed_for_progress x)) == total_value? isn't true.
    ; Right now we only call functions when all parameters are values, which means you can't
    ; create a true_value array with non-value memebers (*right now* anyway), but it does mean that
    ; you can create a nil needed for progress array that isn't a value, namely for the give_up_*
    ; primitive functions (extra namely, log and error, which are our two main sources of non-purity besides implicit runtime errors).
    ; For combs, being a value is having your env-chain be real?
    (total_value?  (lambda (x) (if (marked_array? x) (.marked_array_is_val x)
                                                     (= nil (needed_for_progress x)))))


    (is_all_values (lambda (evaled_params) (foldl (lambda (a x) (and a (total_value? x))) true evaled_params)))
    ;(is_all_head_values (lambda (evaled_params) (foldl (lambda (a x) (and a (not (later_head? x)))) true evaled_params)))

    (false? (lambda (x) (cond ((and (marked_array? x)  (= false (.marked_array_is_val x)))    (error "got a later marked_array passed to false? " x))
                              ((and (marked_symbol? x) (= false (.marked_symbol_is_val x)))   (error "got a later marked_symbol passed to false? " x))
                              ((val? x)                                                       (not (.val x)))
                              (true                                                           false))))


    (mark (rec-lambda recurse (x) (cond   ((env? x)        (error "called mark with an env " x))
                                          ((combiner? x)   (error "called mark with a combiner " x))
                                          ((symbol? x)     (cond ((= 'true x)  (marked_val #t))
                                                                 ((= 'false x) (marked_val #f))
                                                                 (#t           (marked_symbol true x))))
                                          ((array? x)      (marked_array false false (map recurse x)))
                                          (true            (marked_val x)))))

    (indent_str (rec-lambda recurse (i) (mif (= i 0) ""
                                                   (str "   " (recurse (- i 1))))))

    (str_strip (lambda args (apply str (concat (slice args 0 -2) (array (idx ((rec-lambda recurse (x done_envs)
        (cond ((= nil x)          (array "<nil>" done_envs))
              ((val? x)           (array (str (.val x)) done_envs))
              ((marked_array? x)  (dlet (((stripped_values done_envs) (foldl (dlambda ((vs de) x) (dlet (((v de) (recurse x de))) (array (concat vs (array v)) de)))
                                                                             (array (array) done_envs) (.marked_array_values x))))
                                        (mif (.marked_array_is_val x) (array (str "[" stripped_values "]") done_envs)
                                                                      (array (str "<a" (.marked_array_is_attempted x) ",n" (.marked_array_needed_for_progress x) ",r" (needed_for_progress x) ">" stripped_values) done_envs))))
              ((marked_symbol? x) (mif (.marked_symbol_is_val x) (array (str "'" (.marked_symbol_value x)) done_envs)
                                                                 (array (str (.marked_symbol_needed_for_progress x) "#" (.marked_symbol_value x)) done_envs)))
              ((comb? x)          (dlet (((wrap_level env_id de? se variadic params body) (.comb x))
                                         ((se_s done_envs)   (recurse se done_envs))
                                         ((body_s done_envs) (recurse body done_envs)))
                                      (array (str "<n" (needed_for_progress x) "(comb " wrap_level " " env_id " " de? " " se_s " " params " " body_s ")>") done_envs)))
              ((prim_comb? x)     (array (str (idx x 3)) done_envs))
              ((marked_env? x)    (dlet ((e (.env_marked x))
                                         (index (.marked_env_idx x))
                                         (u (idx e -1))
                                         (already (in_array index done_envs))
                                         (opening (str "{" (mif (marked_env_real? x) "real" "fake") (mif (.marked_env_has_vals x) " real vals" " fake vals")  " ENV idx: " (str index) ", "))
                                         ((middle done_envs) (if already (array "" done_envs) (foldl (dlambda ((vs de) (k v)) (dlet (((x de) (recurse v de))) (array (concat vs (array (array k x))) de)))
                                                                                                     (array (array) done_envs)
                                                                                                     (slice e 0 -2))))
                                         ((upper  done_envs) (if already (array "" done_envs) (mif u (recurse u done_envs) (array "no_upper_likely_root_env" done_envs))))
                                         (done_envs (if already done_envs (cons index done_envs)))
                                       ) (array (if already (str opening "omitted}")
                                                            (if (> (len e) 30) (str "{" (len e) "env}")
                                                                               (str opening middle " upper: " upper "}"))) done_envs)
                                               ))
              (true               (error (str "some other str_strip? |" x "|")))
        )
    ) (idx args -1) (array)) 0))))))
    (true_str_strip str_strip)
    (str_strip (lambda args 0))
    ;(true_str_strip str_strip)
    (print_strip (lambda args (println (apply str_strip args))))

    (env-lookup-helper (rec-lambda recurse (dict key i fail success) (cond ((and (= i (- (len dict) 1)) (= nil (idx dict i)))  (fail))
                                                                           ((= i (- (len dict) 1))                             (recurse (.env_marked (idx dict i)) key 0 fail success))
                                                                           ((= key (idx (idx dict i) 0))                       (success (idx (idx dict i) 1)))
                                                                           (true                                               (recurse dict key (+ i 1) fail success)))))
    (env-lookup (lambda (env key) (env-lookup-helper (.env_marked env) key 0 (lambda () (error (print_strip key " not found in env " env))) (lambda (x) x))))

    (strip (let ((helper (rec-lambda recurse (x need_value)
        (cond ((val? x)           (.val x))
              ((marked_array? x)  (let ((stripped_values (map (lambda (x) (recurse x need_value)) (.marked_array_values x))))
                                      (mif (.marked_array_is_val x) (mif need_value (error (str "needed value for this strip but got" x)) (cons array stripped_values))
                                                                   stripped_values)))
              ((marked_symbol? x) (mif (.marked_symbol_is_val x) (mif need_value (error (str "needed value for this strip but got" x)) (array quote (.marked_symbol_value x)))
                                                               (.marked_symbol_value x)))
              ((comb? x)          (dlet (((wrap_level env_id de? se variadic params body) (.comb x))
                                         (de_entry (mif de? (array de?) (array)))
                                         (final_params (mif variadic (concat (slice params 0 -2) '& (array (idx params -1))) params))
                                         ; Honestly, could trim down the env to match what could be evaluated in the comb
                                         ; Also mif this isn't real, lower to a call to vau
                                         (se_env (mif (marked_env_real? se) (recurse se true) nil))
                                         (body_v (recurse body false))
                                         (ve (concat (array vau) de_entry (array final_params) (array body_v)))
                                         (fe ((rec-lambda recurse (x i) (mif (= i 0) x (recurse (array wrap x) (- i 1)))) ve wrap_level))
                                  ) (mif se_env (eval fe se_env) fe)))
              ((prim_comb? x)     (idx x 2))
                                         ; env emitting doesn't pay attention to real value right now, not sure mif that makes sense
                                         ; TODO: properly handle de Bruijn indexed envs
              ((marked_env? x)    (cond ((and (not need_value) (= 0 (.marked_env_idx x))) (array current-env))
                                        (true                                             (let ((_ (mif (not (marked_env_real? x)) (error (str_strip "trying to emit fake env!" x)))))
                                                                                                (upper (idx (.env_marked x) -1))
                                                                                                (upper_env (mif upper (recurse upper true) empty_env))
                                                                                                (just_entries (slice (.env_marked x) 0 -2))
                                                                                                (vdict (map (dlambda ((k v)) (array k (recurse v true))) just_entries))
                                                                                        ) (add-dict-to-env upper_env vdict))))
              (true               (error (str "some other strip? " x)))
        )
    )))  (lambda (x) (let* ((_ (print_strip "stripping: " x)) (r (helper x false)) (_ (println "result of strip " r))) r))))

    ; A bit wild, but what if instead of is_value we had an evaluation level integer, kinda like wrap?
    ; when lowering, it could just turn into multiple evals or somesuch, though we'd have to be careful of envs...
    (try_unval (rec-lambda recurse (x fail_f)
        (cond ((marked_array? x) (mif (not (.marked_array_is_val x)) (array false (fail_f x))
                                                                    (dlet (((sub_ok subs) (foldl (dlambda ((ok a) x) (dlet (((nok p) (recurse x fail_f)))
                                                                                                                       (array (and ok nok) (concat a (array p)))))
                                                                                               (array true (array))
                                                                                               (.marked_array_values x))))
                                                                         (array sub_ok (marked_array false false subs)))))
              ((marked_symbol? x) (mif (.marked_symbol_is_val x) (array true (marked_symbol true (.marked_symbol_value x)))
                                                                (array false (fail_f x))))
              (true               (array true x))
        )
    ))
    (try_unval_array (lambda (x) (foldl (dlambda ((ok a) x) (dlet (((nok p) (try_unval x (lambda (_) nil))))
                                                                   (array (and ok nok) (concat a (array p)))))
                                        (array true (array))
                                        x)))

    (ensure_val (rec-lambda recurse (x)
        (cond ((marked_array? x)  (marked_array true false (map recurse (.marked_array_values x))))
              ((marked_symbol? x) (marked_symbol nil (.marked_symbol_value x)))
              (true               x)
        )
    ))
    ; This is a conservative analysis, since we can't always tell what constructs introduce
    ; a new binding scope & would be shadowing... we should at least be able to implement it for
    ; vau/lambda, but we won't at first
    ; TODO: make this check for stop envs using de Bruijn indicies
    (contains_symbols (rec-lambda recurse (stop_envs symbols x) (cond
              ((val? x)           false)
              ((marked_symbol? x) (let* ((r (in_array (.marked_symbol_value x) symbols))
                                         (_ (if r (println "!!! contains symbols found " x " in symbols " symbols))))
                                        r))
              ((marked_array? x)  (foldl (lambda (a x) (or a (recurse stop_envs symbols x))) false (.marked_array_values x)))
              ((comb? x)          (dlet (((wrap_level env_id de? se variadic params body) (.comb x)))
                                      (or (recurse stop_envs symbols se) (recurse stop_envs (filter (lambda (y) (not (or (= de? y) (in_array y params)))) symbols) body))))

              ((prim_comb? x)    false)
              ((marked_env? x)   (let ((inner (.env_marked x)))
                                     (cond ((in_array (.marked_env_idx x) stop_envs)                                                     false)
                                           ((foldl (lambda (a x) (or a (recurse stop_envs symbols (idx x 1)))) false (slice inner 0 -2)) true)
                                           ((!= nil (idx inner -1))                                                                      (recurse stop_envs symbols (idx inner -1)))
                                           (true                                                                                         false))))
              (true              (error (str "Something odd passed to contains_symbols " x)))
    )))

    (check_for_env_id_in_result (rec-lambda check_for_env_id_in_result (s_env_id x) (dlet (
        (fp (needed_for_progress x))
        ) (cond
              ((= nil fp)         false)
              ((!= true fp)       (in_array s_env_id fp))
              ((val? x)           false)
              ((marked_symbol? x) false)
              ((marked_array? x)  (foldl (lambda (a x) (or a (check_for_env_id_in_result s_env_id x))) false (.marked_array_values x)))
              ((comb? x)          (dlet (((wrap_level i_env_id de? se variadic params body) (.comb x)))
                                      (or (check_for_env_id_in_result s_env_id se) (and (!= s_env_id i_env_id) (check_for_env_id_in_result s_env_id body)))))

              ((prim_comb? x)    false)
              ((marked_env? x)   (let ((inner (.env_marked x)))
                                     (cond ((and (not (marked_env_real? x)) (= s_env_id (.marked_env_idx x)))           true)
                                           ((foldl (lambda (a x) (or a (check_for_env_id_in_result s_env_id (idx x 1))))
                                                   false (slice inner 0 -2))                                            true)
                                           ((!= nil (idx inner -1))                                                     (check_for_env_id_in_result s_env_id (idx inner -1)))
                                           (true                                                                        false))))
              (true              (error (str "Something odd passed to check_for_env_id_in_result " x)))
    ))))

    ; TODO: instead of returning the later symbols, we could create a new value of a new type
    ; ['ref de_bruijn_index_of_env index_into_env] or somesuch. Could really simplify
    ; compiling, and I think make partial-eval more efficient. More accurate closes_over analysis too, I think
    (make_tmp_inner_env (lambda (params de? de env_id)
        (dlet ((param_entries       (map (lambda (p) (array p (marked_symbol (array env_id) p))) params))
               (possible_de_entry   (mif (= nil de?) (array) (array (array de? (marked_symbol (array env_id) de?)))))
               (progress_idxs       (cons env_id (needed_for_progress de)))
            ) (marked_env false progress_idxs env_id (concat param_entries possible_de_entry (array de))))))


    (pe_memo_hash (lambda (x only_head progress_now) (combine_hash                           (.hash x)
                                                     (combine_hash (if only_head             67
                                                                                             71)
                                                                   (if (= true progress_now) 79
                                                                                             (* 83 progress_now))
                                                     ))))
    (get_pe_passthrough (dlambda (hash (env_counter memo) x) (let ((r (get-value-or-false memo hash)))
                                                                  (cond ((= r false) false)
                                                                        ((= r nil)   (array (array env_counter memo) nil x)) ; Nil is for preventing infinite recursion
                                                                        (true   false)
                                                                        ; This is causing bad compiles!
                                                                        ; Temporarily disabled. Somehow is re-introducing fake envs that aren't in scope or somesuch
                                                                        ;(true        (array (array env_counter memo) nil r))
                                                                        ))))

    (partial_eval_helper (rec-lambda partial_eval_helper (x only_head env env_stack pectx indent)
        (dlet ((for_progress (needed_for_progress x))
               (_ (print_strip (indent_str indent) "for_progress " for_progress " for " x))
               (progress_now (or (= for_progress true)  ((rec-lambda rr (i) (if (= i (len for_progress)) false
                                                                       (dlet (
                                                                       ; possible if called from a value context in the compiler
                                                                       ; TODO: I think this should be removed and instead the value/code compilers should
                                                                       ; keep track of actual env stacks
                                                                       (this_now ((rec-lambda ir (j) (cond ((= j (len env_stack))                                              false)
                                                                                                           ((and (= (idx for_progress i) (.marked_env_idx (idx env_stack j)))
                                                                                                                 (.marked_env_has_vals (idx env_stack j)))                     (idx for_progress i))
                                                                                                           (true                                                               (ir (+ j 1))))
                                                                                  ) 0))
                                                                        ) (if this_now this_now (rr (+ i 1))))
                                                           )) 0)))
              )
        (if progress_now
        ; Man this like doubles the interpret length
        (or (get_pe_passthrough (pe_memo_hash x only_head progress_now) pectx x)
        (cond   ((val? x)            (array pectx nil x))
                ((marked_env? x)     (let ((dbi (.marked_env_idx x)))
                                          ; compiler calls with empty env stack
                                          (mif dbi (let* ( (new_env ((rec-lambda rec (i) (cond ((= i (len env_stack))                           nil)
                                                                                               ((= dbi (.marked_env_idx (idx env_stack i)))     (idx env_stack i))
                                                                                               (true                                            (rec (+ i 1)))))
                                                                     0))
                                                         (_ (println (str_strip "replacing " x) (str_strip " with (if nonnil) " new_env)))
                                                        )
                                                        (array pectx nil (if (!= nil new_env) new_env x)))
                                                  (array pectx nil x))))

                ((comb? x)           (dlet (((wrap_level env_id de? se variadic params body) (.comb x)))
                                        (mif (or (and (not (marked_env_real? env)) (not (marked_env_real? se)))   ; both aren't real, re-evaluation of creation site
                                                 (and      (marked_env_real? env)  (not (marked_env_real? se))))  ; new env real, but se isn't - creation!
                                             (dlet ((inner_env (make_tmp_inner_env params de? env env_id))
                                                    ((pectx err evaled_body) (partial_eval_helper body false inner_env (cons inner_env env_stack) pectx (+ indent 1))))
                                                   (array pectx err (mif err nil (marked_comb wrap_level env_id de? env variadic params evaled_body))))
                                             (array pectx nil x))))
                ((prim_comb? x)      (array pectx nil x))
                ((marked_symbol? x)  (mif (.marked_symbol_is_val x) x
                                                                    (env-lookup-helper (.env_marked env) (.marked_symbol_value x) 0
                                                                                       (lambda ()  (array pectx (str "could't find " (str_strip x) " in " (str_strip env))  nil))
                                                                                       (lambda (x) (array pectx nil x)))))
                ((marked_array? x)   (cond ((.marked_array_is_val x) (dlet ( ((pectx err inner_arr) (foldl (dlambda ((c er ds) p) (dlet (((c e d) (partial_eval_helper p false env env_stack c (+ 1 indent)))) (array c (mif er er e) (concat ds (array d)))))
                                                                                                             (array pectx nil (array))
                                                                                                             (.marked_array_values x)))
                                                                           ) (array pectx err (mif err nil (marked_array true false inner_arr)))))
                                           ((= 0 (len (.marked_array_values x))) (array pectx "Partial eval on empty array" nil))
                                           (true (dlet ((values (.marked_array_values x))
                                                        (_ (print_strip (indent_str indent) "partial_evaling comb " (idx values 0)))

                                                        ((pectx err comb) (partial_eval_helper (idx values 0) true env env_stack pectx (+ 1 indent)))
                                                        ; If we haven't evaluated the function before at all, we would like to partially evaluate it so we know
                                                        ; what it needs. We'll see if this re-introduces exponentail (I think this should limit it to twice?)
                                                        ((pectx err comb) (if (and (= nil err) (= true (needed_for_progress comb)))
                                                                                    (partial_eval_helper comb false env env_stack pectx (+ 1 indent))
                                                                                    (array pectx err comb)))
                                                        (literal_params (slice values 1 -1))
                                                        (_ (println (indent_str indent) "Going to do an array call!"))
                                                        ;(_ (true_print (indent_str indent) "Going to do an array call!"))
                                                        (indent (+ 1 indent))
                                                        (_ (print_strip (indent_str indent) "total is " x))
                                                        ;(_ (true_print (indent_str indent) "total is " (true_str_strip x)))
                                                     )
                                                     (mif err (array pectx err nil)
                                                     (cond ((prim_comb? comb) ((.prim_comb comb) only_head env env_stack pectx literal_params (+ 1 indent)))
                                                           ((comb? comb)      (dlet (

                                                                                 (map_rp_eval (lambda (pectx ps) (foldl (dlambda ((c er ds) p) (dlet ((_ (print_strip (indent_str indent) "rp_evaling " p)) ((c e d) (partial_eval_helper p false env env_stack c (+ 1 indent))) (_ (print_strip (indent_str indent) "result of rp_eval was err " e " and value " d))) (array c (mif er er e) (concat ds (array d)))))
                                                                                                             (array pectx nil (array))
                                                                                                             ps)))


                                                                                 ((wrap_level env_id de? se variadic params body) (.comb comb))
                                                                                 (ensure_val_params (map ensure_val literal_params))
                                                                                 ((ok pectx err single_eval_params_if_appropriate appropriatly_evaled_params) ((rec-lambda param-recurse (wrap cparams pectx single_eval_params_if_appropriate)
                                                                                        (dlet (
                                                                                               (_ (print (indent_str indent) "For initial rp_eval:"))
                                                                                               (_ (map (lambda (x) (print_strip (indent_str indent) "item " x)) cparams))
                                                                                               ((pectx er pre_evaled) (map_rp_eval pectx cparams))
                                                                                               (_ (print (indent_str indent) "er for intial  rp_eval: " er))
                                                                                              )
                                                                                            (mif er (array false pectx er nil nil)
                                                                                            (mif (!= 0 wrap)
                                                                                                (dlet (((ok unval_params) (try_unval_array pre_evaled)))
                                                                                                     (mif (not ok) (array ok pectx nil single_eval_params_if_appropriate nil)
                                                                                                        (dlet (
                                                                                                               (_ (print (indent_str indent) "For second rp_eval:"))
                                                                                                               (_ (map (lambda (x) (print_strip (indent_str indent) "item " x)) unval_params))
                                                                                                               ((pectx err evaled_params) (map_rp_eval pectx unval_params))
                                                                                                               (_ (print (indent_str indent) "er for second  rp_eval: " err))
                                                                                                              )
                                                                                                              (mif err (array false pectx nil single_eval_params_if_appropriate nil)
                                                                                                              (param-recurse (- wrap 1) evaled_params pectx
                                                                                                                             (cond ((= nil single_eval_params_if_appropriate) 1)
                                                                                                                                   ((= 1   single_eval_params_if_appropriate) pre_evaled)
                                                                                                                                   (true               single_eval_params_if_appropriate))
                                                                                                                             )))))
                                                                                                (array true pectx nil (if (= 1 single_eval_params_if_appropriate) pre_evaled single_eval_params_if_appropriate) pre_evaled))))
                                                                                    ) wrap_level ensure_val_params pectx nil))
                                                                                 (correct_fail_params (if (and (!= 1 single_eval_params_if_appropriate) (!= nil single_eval_params_if_appropriate))
                                                                                                          single_eval_params_if_appropriate
                                                                                                          literal_params))
                                                                                 (ok_and_non_later (and ok (is_all_values appropriatly_evaled_params)))
                                                                                 ) (mif err (array pectx err nil)
                                                                                   (mif (not ok_and_non_later) (begin (print_strip (indent_str indent) "Can't evaluate params properly, delying" x)
                                                                                                                      (print_strip (indent_str indent) "so returning with " (marked_array false true (cons comb correct_fail_params)))
                                                                                                                      (array pectx nil (marked_array false true (cons comb correct_fail_params))))
                                                                                 (dlet (
                                                                                 (final_params (mif variadic (concat (slice appropriatly_evaled_params 0 (- (len params) 1))
                                                                                                                   (array (marked_array true false (slice appropriatly_evaled_params (- (len params) 1) -1))))
                                                                                                           appropriatly_evaled_params))
                                                                                 ((de_progress_idxs de_entry) (mif (!= nil de?)
                                                                                                                     (array (needed_for_progress env) (array (array de? env)))
                                                                                                                     (array nil (array))))
                                                                                 ;  Don't need to check params, they're all values!
                                                                                 (inner_env_progress_idxs (concat de_progress_idxs (needed_for_progress se)))
                                                                                 (inner_env (marked_env true inner_env_progress_idxs env_id (concat (zip params final_params) de_entry (array se))))
                                                                                 (_ (print_strip (indent_str indent) " with inner_env is " inner_env))
                                                                                 (_ (print_strip (indent_str indent) "going to eval " body))

                                                                                 ; prevent infinite recursion
                                                                                 ((env_counter memo) pectx)
                                                                                 (this_hash (pe_memo_hash x only_head progress_now))
                                                                                 (memo (put memo this_hash nil))
                                                                                 (pectx (array env_counter memo))

                                                                                 ((pectx func_err func_result) (partial_eval_helper body only_head inner_env (cons inner_env env_stack) pectx (+ 1 indent)))
                                                                                 ) (mif func_err (array pectx func_err nil) (dlet (
                                                                                 (_ (print_strip (indent_str indent) "evaled result of function call  is " func_result))
                                                                                 (able_to_sub_env (not (check_for_env_id_in_result env_id func_result)))
                                                                                 (result_is_later (later_head? func_result))
                                                                                 (_ (print (indent_str indent) "success? " able_to_sub_env))
                                                                                 (stop_envs ((rec-lambda ser (a e) (mif e (ser (cons (.marked_env_idx e) a) (idx (.env_marked e) -1)) a)) (array) se))
                                                                                 (result_closes_over (contains_symbols stop_envs (concat params (mif de? (array de?) (array))) func_result))
                                                                                 (_ (println (indent_str indent) "func call able_to_sub: " able_to_sub_env " (based on env_id " env_id ") result is later_head? " result_is_later " and result_closes_over " result_closes_over))
                                                                                 ; This could be improved to a specialized version of the function
                                                                                 ; just by re-wrapping it in a comb instead mif we wanted.
                                                                                 ; Something to think about!
                                                                                 (result (mif (or (not able_to_sub_env) (and result_is_later result_closes_over))
                                                                                                (marked_array false true (cons comb correct_fail_params))
                                                                                                func_result))
                                                                                 ((env_counter memo) pectx)
                                                                                 (memo (put memo this_hash result))
                                                                                 (pectx (array env_counter memo))
                                                                             )    (array pectx nil result))))))))
                                                           ((later_head? comb)    (array pectx nil (marked_array false true (cons comb literal_params))))
                                                           (true                  (array pectx (str "impossible comb value " x) nil))))))))
                (true                (array pectx (str "impossible partial_eval value " x) nil))
        ))
        ; otherwise, we can't make progress yet
        (begin (print_strip (indent_str indent) "Not evaluating " x)
               ;(print (indent_str indent) "comparing to env stack " env_stack)
               (array pectx nil x))))
    ))

    ; !!!!!!
    ; ! I think needs_params_val_lambda should be combined with parameters_evaled_proxy
    ; !!!!!!
    (parameters_evaled_proxy (rec-lambda recurse (pasthr_ie inner_f) (lambda (only_head de env_stack pectx params indent) (dlet (
        ;(_ (println "partial_evaling params in parameters_evaled_proxy is " params))
        ((evaled_params l err pectx) (foldl (dlambda ((ac i err pectx) p) (dlet (((pectx er p) (partial_eval_helper p (if (and only_head (= i pasthr_ie)) only_head false) de env_stack pectx (+ 1 indent))))
                                                         (array (concat ac (array p)) (+ i 1) (mif err err er) pectx)))
                                           (array (array) 0 nil pectx)
                                           params))
    ) (mif err (array pectx err nil)
               (inner_f (lambda args (apply (recurse pasthr_ie inner_f) args)) only_head de env_stack pectx evaled_params indent))))))

    (needs_params_val_lambda_inner (lambda (f_sym actual_function) (let* (
        (handler (rec-lambda recurse (only_head de env_stack pectx params indent) (dlet (
                ;_ (println "partial_evaling params in need_params_val_lambda for " f_sym " is " params)
                ((pectx err evaled_params) (foldl (dlambda ((c err ds) p) (dlet (((c er d) (partial_eval_helper p false de env_stack c (+ 1 indent))))
                                                                                (array c (mif err err er) (concat ds (array d)))))
                                                        (array pectx nil (array)) params))
            )
            ; TODO: Should this be  is_all_head_values?
            (mif err (array pectx err nil)
            (array pectx nil (mif (is_all_values evaled_params) (mark (apply actual_function (map strip evaled_params)))
                                                                      (marked_array false true (cons (marked_prim_comb recurse f_sym) evaled_params))))))))
        ) (array f_sym (marked_prim_comb handler f_sym)))))

    (give_up_eval_params_inner (lambda (f_sym actual_function) (let* (
        (handler (rec-lambda recurse (only_head de env_stack pectx params indent) (dlet (
                ;_ (println "partial_evaling params in give_up_eval_params for " f_sym " is " params)
                ((pectx err evaled_params) (foldl (dlambda ((c err ds) p) (dlet (((c er d) (partial_eval_helper p only_head de env_stack c (+ 1 indent))))
                                                                                (array c (mif err err er) (concat ds (array d)))))
                                                        (array pectx nil (array)) params))
            )
            (mif err (array pectx err nil)
                     (array pectx nil (marked_array false true (cons (marked_prim_comb recurse f_sym) evaled_params)))))))
        ) (array f_sym (marked_prim_comb handler f_sym)))))


    (root_marked_env (marked_env true nil nil (array

        (array 'vau (marked_prim_comb (rec-lambda recurse (only_head de env_stack pectx params indent) (dlet (
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
            (body        (mif (= nil de?) (idx params 1) (idx params 2)))
            ((env_counter memo) pectx)
            (new_id env_counter)
            (env_counter (+ 1 env_counter))
            (pectx (array env_counter memo))
            ((pectx err pe_body) (if only_head (begin (print "skipping inner eval cuz only_head") (array pectx nil body))
                                       (dlet (
                                            (inner_env (make_tmp_inner_env vau_params de? de new_id))
                                            (_ (print_strip (indent_str indent) "in vau, evaluating body with 'later params - " body))
                                            ((pectx err pe_body) (partial_eval_helper body false inner_env (cons inner_env env_stack) pectx (+ 1 indent)))
                                            (_ (print_strip (indent_str indent) "in vau, result of evaluating body was " pe_body))
                                        ) (array pectx err pe_body))))
        ) (mif err (array pectx err nil) (array pectx nil (marked_comb 0 new_id de? de variadic vau_params pe_body)))
        )) 'vau))

        (array 'wrap (marked_prim_comb (parameters_evaled_proxy 0 (dlambda (recurse only_head de env_stack pectx (evaled) indent)
              (array pectx nil (mif (comb? evaled) (dlet (((wrap_level env_id de? se variadic params body) (.comb evaled))
                                           (wrapped_marked_fun (marked_comb (+ 1 wrap_level) env_id de? se variadic params body))
                                          ) wrapped_marked_fun)
                                     (marked_array false true (array (marked_prim_comb recurse 'wrap) evaled)))))
        ) 'wrap))

        (array 'unwrap (marked_prim_comb (parameters_evaled_proxy 0 (dlambda (recurse only_head de env_stack pectx (evaled) indent)
             (array pectx nil (mif (comb? evaled) (dlet (((wrap_level env_id de? se variadic params body) (.comb evaled))
                                           (unwrapped_marked_fun (marked_comb (- wrap_level 1) env_id de? se variadic params body))
                                         ) unwrapped_marked_fun)
                                    (marked_array false true (array (marked_prim_comb recurse 'unwrap) evaled)))))
        ) 'unwrap))

        (array 'eval (marked_prim_comb (rec-lambda recurse (only_head de env_stack pectx params indent) (dlet (
            (self (marked_prim_comb recurse 'eval))

            (_ (print_strip (indent_str indent) " partial_evaling_body the first time " (idx params 0)))
            ((pectx body_err body1) (partial_eval_helper (idx params 0) false de env_stack pectx (+ 1 indent)))
            (_ (print_strip (indent_str indent) "after first eval of param " body1))

            ((pectx env_err eval_env) (mif (= 2 (len params)) (partial_eval_helper (idx params 1) false de env_stack pectx (+ 1 indent))
                                                                    (array pectx nil de)))
            (eval_env_v (mif (= 2 (len params)) (array eval_env) (array)))
         ) (mif (or (!= nil body_err) (!= nil env_err)) (array pectx (mif body_err body_err env_err) nil)
           (mif (not (marked_env? eval_env)) (array pectx (mif body_err body_err env_err) (marked_array false true (concat (array self body1) eval_env_v)))
                                            (dlet (
            ; Is this safe? Could this not move eval_env_v inside a comb?
            ; With this, we don't actually fail as this is always a legitimate uneval
            (fail_handler (lambda (failed) (marked_array false true (concat (array self failed) eval_env_v))))
            ((ok unval_body) (try_unval body1 fail_handler))
            (self_fallback (fail_handler body1))
            (_ (print_strip (indent_str indent) "partial_evaling body for the second time in eval " unval_body))
            ((pectx err body2) (mif (= self_fallback unval_body) (array pectx nil self_fallback)
                                                                       (partial_eval_helper unval_body only_head eval_env env_stack pectx (+ 1 indent))))
            (_ (print_strip (indent_str indent) "and body2 is " body2))
            ) (mif err (array pectx err nil) (array pectx nil body2)))))
        )) 'eval))

        (array 'cond (marked_prim_comb (rec-lambda recurse (only_head de env_stack pectx params indent)
            (mif (!= 0 (% (len params) 2)) (array pectx (str "partial eval cond with odd params " params) nil)
                ((rec-lambda recurse_inner (i so_far pectx)
                                          (dlet (((pectx err evaled_cond) (partial_eval_helper (idx params i) false de env_stack pectx (+ 1 indent)))
                                                 (_ (print (indent_str indent) "in cond cond " (idx params i) " evaluated to " evaled_cond)))
                                          (cond ((!= nil err)                   (array pectx err nil))
                                                ((later_head? evaled_cond)      (dlet ( ((pectx err arm) (if only_head (array pectx nil (idx params (+ i 1)))
                                                                                                                             (partial_eval_helper (idx params (+ i 1)) false de env_stack pectx (+ 1 indent))))
                                                                                      ) (mif err (array pectx err nil)
                                                                                                 (recurse_inner (+ 2 i) (concat so_far (array evaled_cond arm)) pectx))))
                                                ((false? evaled_cond)            (recurse_inner (+ 2 i) so_far pectx))
                                                ((= (len params) i)              (array pectx nil (marked_array false true (cons (marked_prim_comb recurse 'cond) so_far))))
                                                (true                            (dlet (((pectx err evaled_body) (partial_eval_helper (idx params (+ 1 i)) only_head de env_stack pectx (+ 1 indent))))
                                                                                       (mif err (array pectx err nil) (array pectx nil (mif (!= (len so_far) 0) (marked_array false true (cons (marked_prim_comb recurse 'cond) (concat so_far (array evaled_cond evaled_body))))
                                                                                                                                   evaled_body)))))
                 ))) 0 (array) pectx)
            )
        ) 'cond))

        (needs_params_val_lambda symbol?)
        (needs_params_val_lambda int?)
        (needs_params_val_lambda string?)

        (array 'combiner? (marked_prim_comb (parameters_evaled_proxy nil (dlambda (recurse only_head de env_stack pectx (evaled_param) indent)
            (array pectx nil (cond
                  ((comb? evaled_param)          (marked_val true))
                  ((prim_comb? evaled_param)     (marked_val true))
                  ((later_head? evaled_param)    (marked_array false true (array (marked_prim_comb recurse 'combiner?) evaled_param)))
                  (true                          (marked_val false))
            ))
        )) 'combiner?))
        (array 'env? (marked_prim_comb (parameters_evaled_proxy nil (dlambda (recurse only_head de env_stack pectx (evaled_param) indent)
            (array pectx nil (cond
                  ((marked_env? evaled_param)    (marked_val true))
                  ((later_head? evaled_param)    (marked_array false true (array (marked_prim_comb recurse 'env?) evaled_param)))
                  (true                          (marked_val false))
            ))
        )) 'env?))
        (needs_params_val_lambda nil?)
        (needs_params_val_lambda bool?)
        (needs_params_val_lambda str-to-symbol)
        (needs_params_val_lambda get-text)

        (array 'array? (marked_prim_comb (parameters_evaled_proxy nil (dlambda (recurse only_head de env_stack pectx (evaled_param) indent)
            (array pectx nil (cond
                  ((later_head? evaled_param)    (marked_array false true (array (marked_prim_comb recurse 'array?) evaled_param)))
                  ((marked_array? evaled_param)  (marked_val true))
                  (true                          (marked_val false))
            ))
        )) 'array?))

        ; This one's sad, might need to come back to it.
        ; We need to be able to differentiate between half-and-half arrays
        ; for when we ensure_params_values or whatever, because that's super wrong
        ; Maybe we can now with progress_idxs?
        (array 'array (marked_prim_comb (parameters_evaled_proxy nil (lambda (recurse only_head de env_stack pectx evaled_params indent)
                                                (array pectx nil (mif (is_all_values evaled_params) (marked_array true false evaled_params)
                                                                                                          (marked_array false true (cons (marked_prim_comb recurse 'array) evaled_params))))
        )) 'array))
        (array 'len (marked_prim_comb (parameters_evaled_proxy nil (dlambda (recurse only_head de env_stack pectx (evaled_param) indent)
            (array pectx nil (cond
                  ((later_head? evaled_param)    (marked_array false true (array (marked_prim_comb recurse 'len) evaled_param)))
                  ((marked_array? evaled_param)  (marked_val (len (.marked_array_values evaled_param))))
                  (true                          (error (str "bad type to len " evaled_param)))
            ))
        )) 'len))
        (array 'idx (marked_prim_comb (parameters_evaled_proxy nil (dlambda (recurse only_head de env_stack pectx (evaled_array evaled_idx) indent)
            (array pectx nil (cond
                  ((and (val? evaled_idx) (marked_array? evaled_array) (.marked_array_is_val evaled_array)) (idx (.marked_array_values evaled_array) (.val evaled_idx)))
                  (true                                                                                     (marked_array false true (array (marked_prim_comb recurse 'idx) evaled_array evaled_idx)))
            ))
        )) 'idx))
        (array 'slice (marked_prim_comb (parameters_evaled_proxy nil (dlambda (recurse only_head de env_stack pectx (evaled_array evaled_begin evaled_end) indent)
            (array pectx nil (cond
                  ((and (val? evaled_begin) (val? evaled_end) (marked_array? evaled_array) (.marked_array_is_val evaled_array))
                            (marked_array true false (slice (.marked_array_values evaled_array) (.val evaled_begin) (.val evaled_end))))
                  (true     (marked_array false true (array (marked_prim_comb recurse 'slice) evaled_array evaled_begin evaled_end)))
            ))
        )) 'slice))
        (array 'concat (marked_prim_comb (parameters_evaled_proxy nil (lambda (recurse only_head de env_stack pectx evaled_params indent)
            (array pectx nil (cond
                  ((foldl (lambda (a x) (and a (and (marked_array? x) (.marked_array_is_val x)))) true evaled_params) (marked_array true false (lapply concat (map (lambda (x)
                                                                                                                                                             (.marked_array_values x))
                                                                                                                                                            evaled_params))))
                  (true                                                                                               (marked_array false true (cons (marked_prim_comb recurse 'concat) evaled_params)))
            ))
        )) 'concat))

        (needs_params_val_lambda +)
        (needs_params_val_lambda -)
        (needs_params_val_lambda *)
        (needs_params_val_lambda /)
        (needs_params_val_lambda %)
        (needs_params_val_lambda band)
        (needs_params_val_lambda bor)
        (needs_params_val_lambda bnot)
        (needs_params_val_lambda bxor)
        (needs_params_val_lambda <<)
        (needs_params_val_lambda >>)
        (needs_params_val_lambda =)
        (needs_params_val_lambda !=)
        (needs_params_val_lambda <)
        (needs_params_val_lambda <=)
        (needs_params_val_lambda >)
        (needs_params_val_lambda >=)
        (needs_params_val_lambda str)
        ;(needs_params_val_lambda pr-str)
        ;(needs_params_val_lambda prn)
        (give_up_eval_params log)
        ; really do need to figure out mif we want to keep meta, and add it mif so
        ;(give_up_eval_params meta)
        ;(give_up_eval_params with-meta)
        ; mif we want to get fancy, we could do error/recover too
        (give_up_eval_params error)
        ;(give_up_eval_params recover)
        (needs_params_val_lambda read-string)
        (array 'empty_env (marked_env true nil nil (array nil)))

        nil
    )))


    (partial_eval (lambda (x) (partial_eval_helper (mark x) false root_marked_env (array) (array 0 (array)) 0)))
    ;; WASM

    ; Vectors and Values
    ; Bytes encode themselves

    ; Note that the shift must be arithmatic
    (encode_LEB128 (rec-lambda recurse (x)
        (let ((b (band #x7F x))
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
    (hex_digit (lambda (digit) (let ((d (char->integer digit)))
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
        (let (
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
        (let (
            (encoded (encode_vector encode_import x))
        ) (concat (array #x02) (encode_LEB128 (len encoded)) encoded ))
    ))

    (encode_table_type (lambda (t) (concat (encode_ref_type (idx t 0)) (encode_limits (idx t 1)))))

    (encode_table_section (lambda (x)
        (let (
            (encoded (encode_vector encode_table_type x))
        ) (concat (array #x04) (encode_LEB128 (len encoded)) encoded ))
    ))
    (encode_memory_section (lambda (x)
        (let (
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
        (let (
            ;(_ (print "encoding element " x))
            (encoded (encode_vector encode_export x))
            ;(_ (print "donex"))
        ) (concat (array #x07) (encode_LEB128 (len encoded)) encoded ))
    ))

    (encode_start_section (lambda (x)
        (cond ((= 0 (len x)) (array))
              ((= 1 (len x)) (let ((encoded (encode_LEB128 (idx x 0)))) (concat (array #x08) (encode_LEB128 (len encoded)) encoded )))
              (true          (error (str "bad lenbgth for start section " (len x) " was " x))))
    ))

    (encode_function_section (lambda (x)
        (let* (                                     ; nil functions are placeholders for improted functions
            ;(_ (println "encoding function section " x))
            (filtered (filter (lambda (i) (!= nil i)) x))
            ;(_ (println "post filtered " filtered))
            (encoded (encode_vector encode_LEB128 filtered))
        ) (concat (array #x03) (encode_LEB128 (len encoded)) encoded ))
    ))
    (encode_blocktype (lambda (type) (cond ((symbol? type)   (encode_valtype type))
                                           ((= (array) type) (array #x40)) ; empty type
                                           (true             (encode_LEB128 type))
                                   )))

    (encode_ins (rec-lambda recurse (ins)
        (let (
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
        (let (
            (encoded (encode_vector encode_code x))
        ) (concat (array #x0A) (encode_LEB128 (len encoded)) encoded ))
    ))

    (encode_global_type (lambda (t) (concat (encode_valtype (idx t 0)) (cond ((= (idx t 1) 'const) (array #x00))
                                                                             ((= (idx t 1) 'mut)   (array #x01))
                                                                             (true                 (error (str "bad mutablity " (idx t 1))))))))
    (encode_global_section (lambda (global_section)
        (let (
            ;(_ (print "encoding exprs " global_section))
            (encoded (encode_vector (lambda (x) (concat (encode_global_type (idx x 0)) (encode_expr (idx x 1)))) global_section))
        ) (concat (array #x06) (encode_LEB128 (len encoded)) encoded ))
    ))

    ; only supporting one type of element section for now, active funcrefs with offset
    (encode_element (lambda (x) (concat (array #x00) (encode_expr (idx x 0)) (encode_vector encode_LEB128 (idx x 1)))))
    (encode_element_section (lambda (x)
        (let (
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
        (let (
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
            ;data_count (let (body (encode_LEB128 (len data_section))) (concat (array #x0C) (encode_LEB128 (len body)) body))
            (data_count (array))
        ) (concat magic version type import function table memory global export data_count start elem code data))
    ))

    (module (lambda args (let (
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
            (concat code (array (array compressed_locals our_code ) ))
            ; data
            data
        ))
    ))))

    ;;;;;;;;;;;;;;;
    ; Instructions
    ;;;;;;;;;;;;;;;
    (unreachable    (lambda ()                                           (array (lambda (name_dict) (array 'unreachable)))))
    (drop           (lambda flatten  (concat (apply concat flatten)      (array (lambda (name_dict) (array 'drop))))))
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

    (block_like_body (lambda (name_dict name inner) (let* (
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
                                           ) (concat flattened      (array (lambda (name_dict) (concat (array 'if result_t (block_like_body name_dict name then_section))
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

    ; Int - should maximize int
    ;  xxxxx0

    ; String - should be close to array, bitpacked, just different ptr rep?
    ;  <string_size32><string_ptr29>011

    ; Symbol - ideally interned (but not yet) also probs small-symbol-opt (def not yet)
    ;  <symbol_size32><symbol_ptr29>111

    ; Array / Nil
    ;  <array_size32><array_ptr29>101 / 0..0 101

    ; Combiner - a double of func index and closure (which could just be the env, actually, even if we trim...)
    ;  <func_idx29>|<env_ptr29><wrap2>0001

    ; Env
    ; 0..0<env_ptr32 but still aligned>01001
    ;   Env object is <key_array_value><value_array_value><upper_env_value>
    ;       each being the full 64 bit objects.
    ;       This lets key_array exist in constant mem, and value array to come directly from passed params.

    ; True          / False
    ;  0..0 1 11001  /  0..0 0 11001

    (to_hex_digit (lambda (x) (string (integer->char (if (< x 10) (+ x #x30)
                                                                  (+ x #x37))))))
    (le_hexify_helper (rec-lambda recurse (x i) (if (= i 0) ""
                                                                  (concat "\\" (to_hex_digit (remainder (quotient x 16) 16)) (to_hex_digit (remainder x 16)) (recurse (quotient x 256) (- i 1))))))
    (i64_le_hexify (lambda (x) (le_hexify_helper x 8)))
    (i32_le_hexify (lambda (x) (le_hexify_helper x 4)))

    (compile (dlambda ((pectx partial_eval_err marked_code)) (mif partial_eval_err (error partial_eval_err) (wasm_to_binary (module
          (import "wasi_unstable" "path_open"
                  '(func $path_open  (param i32 i32 i32 i32 i32 i64 i64 i32 i32)
                                     (result i32)))
          (import "wasi_unstable" "fd_read"
                  '(func $fd_read  (param i32 i32 i32 i32)
                                   (result i32)))
          (import "wasi_unstable" "fd_write"
                  '(func $fd_write (param i32 i32 i32 i32)
                                   (result i32)))
          (memory '$mem 1)
          (global '$malloc_head  '(mut i32) (i32.const 0))
          (global '$phs          '(mut i32) (i32.const 0))
          (global '$phl          '(mut i32) (i32.const 0))
          (dlet (
              (nil_val        #b0101)
              (true_val  #b000111001)
              (false_val #b000011001)
              (alloc_data (dlambda (d (watermark datas)) (cond ((str? d)      (let ((size (+ 8 (band (len d) -8))))
                                                                                   (array (+ watermark 8)
                                                                                          (len d)
                                                                                          (array (+ watermark 8 size)
                                                                                                 (concat datas
                                                                                                         (data (i32.const watermark)
                                                                                                               (concat (i32_le_hexify size) "\\00\\00\\00\\80" d)))))))
                                                               (true          (error (str "can't alloc_data for anything else besides strings yet" d)))
                                                         )
              ))
              ; We won't use 0 because some impls seem to consider that NULL and crash on reading/writing?
              (iov_tmp 8) ; <32bit len><32bit ptr> + <32bit numwitten>
              (datasi (array (+ iov_tmp 16) (array)))
              ((true_loc true_length datasi) (alloc_data "true" datasi))
              ((false_loc false_length datasi) (alloc_data "false" datasi))
              ((bad_params_loc bad_params_length datasi) (alloc_data "\nError: passed a bad number (or type) of parameters\n" datasi))
              (bad_params_msg_val (bor (<< bad_params_length 32) bad_params_loc #b011))
              ((error_loc error_length datasi) (alloc_data "\nError: " datasi))
              (error_msg_val (bor (<< error_length 32) error_loc #b011))
              ((log_loc log_length datasi) (alloc_data "\nLog: " datasi))
              (log_msg_val (bor (<< log_length 32) log_loc #b011))
              ((newline_loc newline_length datasi) (alloc_data "\n" datasi))
              (newline_msg_val (bor (<< newline_length 32) newline_loc #b011))

              ((remaining_eval_loc remaining_eval_length datasi) (alloc_data "\nError: trying to call remainin eval\n" datasi))
              (remaining_eval_msg_val (bor (<< remaining_eval_length 32) remaining_eval_loc #b011))
              ((remaining_vau_loc remaining_vau_length datasi) (alloc_data "\nError: trying to call remainin vau (primitive)\n" datasi))
              (remaining_vau_msg_val (bor (<< remaining_vau_length 32) remaining_vau_loc #b011))
              ((remaining_cond_loc remaining_cond_length datasi) (alloc_data "\nError: trying to call remainin cond\n" datasi))
              (remaining_cond_msg_val (bor (<< remaining_cond_length 32) remaining_cond_loc #b011))

              ((remaining_vau_loc remaining_vau_length datasi) (alloc_data "\nError: trying to call a remainin vau\n" datasi))
              (remaining_vau_msg_val (bor (<< remaining_vau_length 32) remaining_vau_loc #b011))

              ((bad_not_vau_loc bad_not_vau_length datasi) (alloc_data "\nError: Trying to call a function (not vau) but the parameters caused a compile error\n" datasi))
              (bad_not_vau_msg_val (bor (<< bad_not_vau_length 32) bad_not_vau_loc #b011))

              ((couldnt_parse_1_loc              couldnt_parse_1_length datasi) (alloc_data "\nError: Couldn't parse:\n" datasi))
              ( couldnt_parse_1_msg_val (bor (<< couldnt_parse_1_length 32) couldnt_parse_1_loc #b011))
              ((couldnt_parse_2_loc              couldnt_parse_2_length datasi) (alloc_data "\nAt character:\n" datasi))
              ( couldnt_parse_2_msg_val (bor (<< couldnt_parse_2_length 32) couldnt_parse_2_loc #b011))
              ((parse_remaining_loc              parse_remaining_length datasi) (alloc_data "\nLeft over after parsing, starting at byte offset:\n" datasi))
              ( parse_remaining_msg_val (bor (<< parse_remaining_length 32) parse_remaining_loc #b011))

              ((quote_sym_loc quote_sym_length datasi) (alloc_data "quote" datasi))
              (quote_sym_val (bor (<< quote_sym_length 32) quote_sym_loc #b111))

              ; 0 is path_open, 1 is fd_read, 2 is fd_write
              ;(num_pre_functions 2)
              (num_pre_functions 3)
              ((func_idx funcs) (array num_pre_functions (array)))

              ; malloc allocates with size and refcount in header
              ((k_malloc func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$malloc '(param $bytes i32) '(result i32) '(local $result i32) '(local $ptr i32) '(local $last i32) '(local $pages i32)
                (local.set '$bytes (i32.add (i32.const 8) (local.get '$bytes)))
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
                        (local.set '$pages (i32.add (i32.const 1) (i32.shr_u (local.get '$bytes) (i32.const 16))))
                        (local.set '$result (i32.shl (memory.grow (local.get '$pages)) (i32.const 16)))
                        (i32.store 0 (local.get '$result) (i32.shl (local.get '$pages) (i32.const 16)))
                    )
                )
                (i32.store 4 (local.get '$result) (i32.const 1))
                (i32.add (local.get '$result) (i32.const 8))
              ))))

              ((k_free func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$free '(param $bytes i32)
                    (local.set '$bytes (i32.sub (local.get '$bytes) (i32.const 8)))
                    (i32.store 4 (local.get '$bytes) (global.get '$malloc_head))
                    (global.set '$malloc_head (local.get '$bytes))
              ))))

              ((k_get_ptr func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$get_ptr '(param $bytes i64) '(result i32)
                    (_if '$is_not_string_symbol_array_int '(result i32)
                         (i64.eq (i64.const #b001) (i64.and (i64.const #b111) (local.get '$bytes)))
                         (then
                            (_if '$is_true_false '(result i32)
                                 (i64.eq (i64.const #b11001) (i64.and (i64.const #b11111) (local.get '$bytes)))
                                 (then (i32.const 0))
                                 (else
                                    (_if '$is_env '(result i32)
                                        (i64.eq (i64.const #b01001) (i64.and (i64.const #b11111) (local.get '$bytes)))
                                        (then (i32.wrap_i64 (i64.shr_u (local.get '$bytes) (i64.const 5))))
                                        (else (i32.wrap_i64 (i64.and (i64.const #xFFFFFFF8) (i64.shr_u (local.get '$bytes) (i64.const 3))))) ; is comb
                                    )
                                 )
                             )
                         )
                         (else
                            (_if '$is_int '(result i32)
                                 (i64.eq (i64.const #b0) (i64.and (i64.const #b1) (local.get '$bytes)))
                                 (then (i32.const 0))
                                 (else (i32.wrap_i64 (i64.and (i64.const -8) (local.get '$bytes)))) ; str symbol and array all get ptrs just masking FFFFFFF8
                             )
                         )
                     )
              ))))
              ((k_dup func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$dup '(param $bytes i64) '(result i64) '(local $ptr i32) '(local $old_val i32)
                    (local.set '$ptr (call '$get_ptr (local.get '$bytes)))
                    (_if '$not_null
                        (i32.ne (i32.const 0) (local.get '$ptr))
                        (then
                            (local.set '$ptr (i32.sub (local.get '$ptr) (i32.const 8)))
                            (_if '$not_max_neg
                                ;(i32.ne (i32.const (- #x80000000)) (local.tee '$old_val (i32.load 4 (local.get '$ptr))))
                                (i32.gt_s  (local.tee '$old_val (i32.load 4 (local.get '$ptr))) (i32.const 0))
                                (then
                                    (i32.store 4 (local.get '$ptr) (i32.add (local.get '$old_val) (i32.const 1)))
                                )
                            )
                        )
                    )
                    (local.get '$bytes)
              ))))
              ((k_drop func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$drop '(param $it i64) '(local $ptr i32) '(local $old_val i32) '(local $new_val i32) '(local $i i32)
                    (local.set '$ptr (call '$get_ptr (local.get '$it)))
                    (_if '$not_null
                        (i32.ne (i32.const 0) (local.get '$ptr))
                        (then
                            (_if '$not_max_neg
                                ;(i32.ne (i32.const (- #x80000000)) (local.tee '$old_val (i32.load (i32.add (i32.const -4) (local.get '$ptr)))))
                                (i32.gt_s  (local.tee '$old_val (i32.load (i32.add (i32.const -4) (local.get '$ptr)))) (i32.const 0))
                                (then
                                    (_if '$zero
                                        (i32.eqz (local.tee '$new_val (i32.sub (local.get '$old_val) (i32.const 1))))
                                        (then
                                            (_if '$needs_inner_drop
                                                (i64.eq (i64.const #b01) (i64.and (i64.const #b11) (local.get '$it)))
                                                (then
                                                    (_if '$is_array
                                                        (i64.eq (i64.const #b101) (i64.and (i64.const #b111) (local.get '$it)))
                                                        (then
                                                            (local.set '$i (i32.wrap_i64 (i64.shr_u (local.get '$it) (i64.const 32))))
                                                            (_loop '$l
                                                                (call '$drop (i64.load (local.get '$ptr)))
                                                                (local.set '$ptr (i32.add (local.get '$ptr) (i32.const 8)))
                                                                (local.set '$i (i32.sub (local.get '$i) (i32.const 1)))
                                                                (br_if '$l (i32.ne (i32.const 0) (local.get '$i)))
                                                            )
                                                        )
                                                        (else
                                                            (call '$drop (i64.load  0 (local.get '$ptr)))
                                                            (call '$drop (i64.load  8 (local.get '$ptr)))
                                                            (call '$drop (i64.load 16 (local.get '$ptr)))
                                                        )
                                                    )
                                                )
                                            )
                                            (call '$free (local.get '$ptr))
                                        )
                                        (else (i32.store (i32.add (i32.const -4) (local.get '$ptr)) (local.get '$new_val)))
                                    )
                                )
                            )
                        )
                    )
              ))))

              ; 0..0<env_ptr32 but still aligned>01001
              ((k_env_alloc func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$env_alloc '(param $keys i64) '(param $vals i64) '(param $upper i64) '(result i64) '(local $tmp i32)
                    (local.set '$tmp (call '$malloc (i32.const (* 8 3))))
                    (i64.store 0  (local.get '$tmp) (local.get '$keys))
                    (i64.store 8  (local.get '$tmp) (local.get '$vals))
                    (i64.store 16 (local.get '$tmp) (local.get '$upper))
                    (i64.or (i64.shl (i64.extend_i32_u (local.get '$tmp)) (i64.const 5)) (i64.const #b01001))
              ))))

              ;  <array_size32><array_ptr29>101 / 0..0 101
              ((k_array1_alloc func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$array1_alloc '(param $item i64) '(result i64) '(local $tmp i32)
                    (local.set '$tmp (call '$malloc (i32.const 8)))
                    (i64.store 0  (local.get '$tmp) (local.get '$item))
                    (i64.or (i64.extend_i32_u (local.get '$tmp)) (i64.const #x0000000100000005))
              ))))
              ((k_array2_alloc func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$array2_alloc '(param $a i64) '(param $b i64) '(result i64) '(local $tmp i32)
                    (local.set '$tmp (call '$malloc (i32.const 16)))
                    (i64.store 0  (local.get '$tmp) (local.get '$a))
                    (i64.store 8  (local.get '$tmp) (local.get '$b))
                    (i64.or (i64.extend_i32_u (local.get '$tmp)) (i64.const #x0000000200000005))
              ))))

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
                                         (i64.eq (i64.const #b11) (i64.and (i64.const #b11) (local.get '$to_str_len)))
                                         (then (_if '$is_str '(result i32)
                                                 (i64.eq (i64.const #b000) (i64.and (i64.const #b100)  (local.get '$to_str_len)))
                                                 (then (i32.add (i32.const 2) (i32.wrap_i64 (i64.shr_u (local.get '$to_str_len) (i64.const 32)))))
                                                 (else (i32.add (i32.const 1) (i32.wrap_i64 (i64.shr_u (local.get '$to_str_len) (i64.const 32)))))
                                               ))
                                         (else
                                            (_if '$is_array '(result i32)
                                                 (i64.eq (i64.const #b101) (i64.and (i64.const #b111) (local.get '$to_str_len)))
                                                 (then
                                                    (local.set '$running_len_tmp (i32.const 1))
                                                    (local.set '$i_tmp (i32.wrap_i64 (i64.shr_u (local.get '$to_str_len) (i64.const 32))))
                                                    (local.set '$x_tmp (i32.wrap_i64 (i64.and (local.get '$to_str_len) (i64.const -8))))
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
                                                        (i64.eq (i64.const #b01001) (i64.and (i64.const #b11111) (local.get '$to_str_len)))
                                                        (then
                                                            (local.set '$running_len_tmp (i32.const 0))

                                                            ; ptr to env
                                                            (local.set '$ptr_tmp (i32.wrap_i64 (i64.shr_u (local.get '$to_str_len) (i64.const 5))))
                                                            ; ptr to start of array of symbols
                                                            (local.set '$x_tmp (i32.wrap_i64 (i64.and (i64.load (local.get '$ptr_tmp)) (i64.const -8))))
                                                            ; ptr to start of array of values
                                                            (local.set '$y_tmp (i32.wrap_i64 (i64.and (i64.load 8 (local.get '$ptr_tmp)) (i64.const -8))))
                                                            ; lenght of both arrays, pulled from array encoding of x
                                                            (local.set '$i_tmp (i32.wrap_i64 (i64.shr_u (i64.load (local.get '$ptr_tmp)) (i64.const 32))))

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
                                                                (i64.eq (i64.const #b01001) (i64.and (i64.const #b11111) (local.get '$item)))
                                                                (then
                                                                    (local.set '$running_len_tmp (i32.add (local.get '$running_len_tmp) (i32.const 1)))
                                                                    (local.set '$running_len_tmp (i32.add (local.get '$running_len_tmp) (call '$str_len (local.get '$item))))
                                                                )
                                                            )

                                                            (local.get '$running_len_tmp)
                                                        )
                                                        (else
                                                            (_if '$is_comb '(result i32)
                                                                (i64.eq (i64.const #b0001) (i64.and (i64.const #b1111) (local.get '$to_str_len)))
                                                                (then
                                                                    (i32.const 5)
                                                                )
                                                                (else
                                                                    ;; must be int
                                                                    (call '$int_digits (i64.shr_s (local.get '$to_str_len) (i64.const 1)))
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
                                         (i64.eq (i64.const #b11) (i64.and (i64.const #b11) (local.get '$to_str)))
                                         (then (_if '$is_str '(result i32)
                                                 (i64.eq (i64.const #b000) (i64.and (i64.const #b100) (local.get '$to_str)))
                                                 (then
                                                    (i32.store8 (local.get '$buf) (i32.const #x22))
                                                    (memory.copy (i32.add (i32.const 1) (local.get '$buf))
                                                                 (i32.wrap_i64 (i64.and (i64.const -8) (local.get '$to_str)))
                                                                 (local.tee '$len_tmp (i32.wrap_i64 (i64.shr_u (local.get '$to_str) (i64.const 32)))))
                                                    (i32.store8 1 (i32.add (local.get '$buf) (local.get '$len_tmp)) (i32.const #x22))
                                                    (i32.add (i32.const 2) (local.get '$len_tmp))
                                                 )
                                                 (else
                                                    (i32.store8 (local.get '$buf) (i32.const #x27))
                                                    (memory.copy (i32.add (i32.const 1) (local.get '$buf))
                                                                 (i32.wrap_i64 (i64.and (i64.const -8) (local.get '$to_str)))
                                                                 (local.tee '$len_tmp (i32.wrap_i64 (i64.shr_u (local.get '$to_str) (i64.const 32)))))
                                                    (i32.add (i32.const 1) (local.get '$len_tmp))
                                                )
                                               ))
                                         (else
                                            (_if '$is_array '(result i32)
                                                 (i64.eq (i64.const #b101) (i64.and (i64.const #b101) (local.get '$to_str)))
                                                 (then
                                                    (local.set '$len_tmp (i32.const 0))
                                                    (local.set '$i_tmp (i32.wrap_i64 (i64.shr_u (local.get '$to_str) (i64.const 32))))
                                                    (local.set '$ptr_tmp (i32.wrap_i64 (i64.and (local.get '$to_str) (i64.const -8))))
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
                                                        (i64.eq (i64.const #b01001) (i64.and (i64.const #b11111) (local.get '$to_str)))
                                                        (then
                                                            (local.set '$len_tmp (i32.const 0))

                                                            ; ptr to env
                                                            (local.set '$ptr_tmp (i32.wrap_i64 (i64.shr_u (local.get '$to_str) (i64.const 5))))
                                                            ; ptr to start of array of symbols
                                                            (local.set '$x_tmp (i32.wrap_i64 (i64.and (i64.load (local.get '$ptr_tmp)) (i64.const -8))))
                                                            ; ptr to start of array of values
                                                            (local.set '$y_tmp (i32.wrap_i64 (i64.and (i64.load 8 (local.get '$ptr_tmp)) (i64.const -8))))
                                                            ; lenght of both arrays, pulled from array encoding of x
                                                            (local.set '$i_tmp (i32.wrap_i64 (i64.shr_u (i64.load (local.get '$ptr_tmp)) (i64.const 32))))

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
                                                                (i64.eq (i64.const #b01001) (i64.and (i64.const #b11111) (local.get '$item)))
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
                                                                (i64.eq (i64.const #b0001) (i64.and (i64.const #b1111) (local.get '$to_str)))
                                                                (then
                                                                    (i32.store (local.get '$buf) (i32.const #x626D6F63))
                                                                    (i32.store8 4 (local.get '$buf)
                                                                                (i32.add (i32.const #x30)
                                                                                         (i32.and (i32.const #b11)
                                                                                                  (i32.wrap_i64 (i64.shr_u (local.get '$to_str) (i64.const 4))))))
                                                                    (i32.const 5)
                                                                )
                                                                (else
                                                                    ;; must be int
                                                                    (local.set '$to_str (i64.shr_s (local.get '$to_str) (i64.const 1)))
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
                    (drop (call '$str_helper (local.get '$to_print) (i32.add (i32.const 8) (local.get '$iov))))
                    (i32.store (local.get '$iov)                         (i32.add (i32.const 8) (local.get '$iov))) ;; adder of data
                    (i32.store 4 (local.get '$iov) (local.get '$data_size))                   ;; len of data
                    (drop (call '$fd_write
                              (i32.const 1)     ;; file descriptor
                              (local.get '$iov) ;; *iovs
                              (i32.const 1)     ;; iovs_len
                              (local.get '$iov) ;; nwritten
                    ))
                    (call '$free (local.get '$iov))
              ))))

              ; Utility method, but does refcount
              ((k_slice_impl func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$slice_impl '(param $array i64) '(param $s i32) '(param $e i32) '(result i64) '(local $size i32) '(local $new_size i32) '(local $i i32) '(local $ptr i32) '(local $new_ptr i32)
                    (local.set '$size (i32.wrap_i64 (i64.shr_u (local.get '$array) (i64.const 32))))
                    (local.set '$ptr  (i32.wrap_i64 (i64.and   (local.get '$array) (i64.const -8))))
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
                            (i64.const nil_val)
                        )
                        (else
                            (local.set '$new_ptr  (call '$malloc (i32.shl (local.get '$new_size) (i32.const 3)))) ; malloc(size*8)

                            (local.set '$i (i32.const 0))
                            (block '$exit_loop
                                (_loop '$l
                                    (br_if '$exit_loop (i32.eq (local.get '$i) (local.get '$new_size)))
                                    (i64.store (i32.add (i32.shl (local.get '$i) (i32.const 3)) (local.get '$new_ptr))
                                               (call '$dup (i64.load (i32.add (i32.shl (i32.add (local.get '$s) (local.get '$i)) (i32.const 3)) (local.get '$ptr))))) ; n[i] = dup(o[i+s])
                                    (local.set '$i (i32.add (i32.const 1) (local.get '$i)))
                                    (br '$l)
                                )
                            )
                            (call '$drop (local.get '$array))

                            (i64.or (i64.or  (i64.extend_i32_u (local.get '$new_ptr))  (i64.const #x5))
                                    (i64.shl (i64.extend_i32_u (local.get '$new_size)) (i64.const 32)))
                        )
                    )
              ))))

              ; chose k_slice_impl because it will never be called, so that
              ; no function will have a 0 func index and count as falsy
              (dyn_start (+ 0 k_slice_impl))


              ; This and is 1111100011
              ; The end ensuring 01 makes only
              ; array comb env and bool apply
              ; catching only 0array and false
              ; and a comb with func idx 0
              ; and null env. If we prevent
              ; this from happening, it's
              ; exactly what we want
              (truthy_test (lambda (x) (i64.ne (i64.const #b01) (i64.and (i64.const -29) x))))
              (falsey_test (lambda (x) (i64.eq (i64.const #b01) (i64.and (i64.const -29) x))))

              (set_len_ptr (concat (local.set '$len (i32.wrap_i64 (i64.shr_u (local.get '$p) (i64.const 32))))
                                   (local.set '$ptr (i32.wrap_i64 (i64.and (local.get '$p) (i64.const -8))))
              ))
              (ensure_not_op_n_params_set_ptr_len (lambda (op n) (concat set_len_ptr
                                                                (_if '$is_2_params
                                                                    (op (local.get '$len) (i32.const n))
                                                                    (then
                                                                        (call '$print (i64.const bad_params_msg_val))
                                                                        (unreachable)
                                                                    )
                                                                )
                                                        )))
              (drop_p_d (concat 
                    (call '$drop (local.get '$p))
                    (call '$drop (local.get '$d))))

              ((k_log           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$log           '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$print (i64.const log_msg_val))
                (call '$print (local.get '$p))
                (call '$print (i64.const newline_msg_val))
                drop_p_d
                (i64.const nil_val)
              ))))
              ((k_error         func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$error         '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$print (i64.const error_msg_val))
                (call '$print (local.get '$p))
                (call '$print (i64.const newline_msg_val))
                drop_p_d
                (unreachable)
              ))))
              ((k_str           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$str           '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $buf i32) '(local $size i32)
                (local.set '$buf (call '$malloc (local.tee '$size (call '$str_len (local.get '$p)))))
                (drop (call '$str_helper (local.get '$p) (local.get '$buf)))
                drop_p_d
                (i64.or (i64.or (i64.shl (i64.extend_i32_u (local.get '$size)) (i64.const 32))
                                (i64.extend_i32_u (local.get '$buf)))
                        (i64.const #b011))
              ))))

              (typecheck (dlambda (idx result_type op (mask value) then_branch else_branch)
                (apply _if (concat (array '$matches) result_type
                    (array (op (i64.const value) (i64.and (i64.const mask) (i64.load (* 8 idx) (local.get '$ptr)))))
                    then_branch
                    else_branch
                ))
              ))

              (pred_func    (lambda (name type_check) (func name '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (typecheck 0 (array '(result i64))
                    i64.eq type_check
                    (array (then (i64.const true_val)))
                    (array (else (i64.const false_val)))
                )
                drop_p_d
              )))

              (type_assert (lambda (i type_check)
                (typecheck i (array)
                    i64.ne type_check
                    (array (then
                        (call '$print (i64.const bad_params_msg_val))
                        (unreachable)
                    ))
                    nil
                )
              ))

              (type_int      (array #b1      #b0))
              (type_string   (array #b111    #b011))
              (type_symbol   (array #b111    #b111))
              (type_array    (array #b111    #b101))
              (type_combiner (array #b1111   #b0001))
              (type_env      (array #b11111  #b01001))
              (type_bool     (array #b11111  #b11001))

              ((k_nil?          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$nil?      (array -1 #x0000000000000005)))))
              ((k_array?        func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$array?    type_array))))
              ((k_bool?         func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$bool?     type_bool))))
              ((k_env?          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$env?      type_env))))
              ((k_combiner?     func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$combiner  type_combiner))))
              ((k_string?       func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$string?   type_string))))
              ((k_int?          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$int?      type_int))))
              ((k_symbol?       func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (pred_func '$symbol?   type_symbol))))

              ((k_str_sym_comp func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$str_sym_comp '(param $a i64) '(param $b i64) '(param $lt_val i64) '(param $eq_val i64) '(param $gt_val i64) '(result i64) '(local $result i64) '(local $a_len i32) '(local $b_len i32) '(local $a_ptr i32) '(local $b_ptr i32)
                (local.set '$result (local.get '$eq_val))
                (local.set '$a_len (i32.wrap_i64 (i64.shr_u (local.get '$a) (i64.const 32))))
                (local.set '$b_len (i32.wrap_i64 (i64.shr_u (local.get '$b) (i64.const 32))))
                (local.set '$a_ptr (i32.wrap_i64 (i64.and (local.get '$a) (i64.const #xFFFFFFF8))))
                (local.set '$b_ptr (i32.wrap_i64 (i64.and (local.get '$b) (i64.const #xFFFFFFF8))))
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

              ((k_comp_helper_helper func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$comp_helper_helper '(param $a i64) '(param $b i64) '(param $lt_val i64) '(param $eq_val i64) '(param $gt_val i64) '(result i64) '(local $result i64) '(local $a_tmp i32) '(local $b_tmp i32) '(local $a_ptr i32) '(local $b_ptr i32) '(local $result_tmp i64)
                (block '$b
                    ;; INT
                    (_if '$a_int
                        (i64.eqz (i64.and (i64.const 1) (local.get '$a)))
                        (then
                            (_if '$b_int
                                (i64.eqz (i64.and (i64.const 1) (local.get '$b)))
                                (then
                                    (_if '$a_lt_b
                                        (i64.lt_s (local.get '$a) (local.get '$b))
                                        (then (local.set '$result (local.get '$lt_val))
                                              (br '$b)))
                                    (_if '$a_gt_b
                                        (i64.gt_s (local.get '$a) (local.get '$b))
                                        (then (local.set '$result (local.get '$gt_val))
                                              (br '$b)))
                                    (local.set '$result (local.get '$eq_val))
                                    (br '$b)
                                )
                            )
                            ; Else, b is not an int, so a < b
                            (local.set '$result (local.get '$lt_val))
                            (br '$b)
                        )
                    )
                    (_if '$b_int
                        (i64.eqz (i64.and (i64.const 1) (local.get '$b)))
                        (then
                            (local.set '$result (local.get '$gt_val))
                            (br '$b))
                    )
                    ;; STRING
                    (_if '$a_string
                        (i64.eq (i64.const #b011) (i64.and (i64.const #b111) (local.get '$a)))
                        (then
                            (_if '$b_string
                                (i64.eq (i64.const #b011) (i64.and (i64.const #b111) (local.get '$b)))
                                (then
                                    (local.set '$result (call '$str_sym_comp (local.get '$a) (local.get '$b) (local.get '$lt_val) (local.get '$eq_val) (local.get '$gt_val)))
                                    (br '$b))
                            )
                            ; else b is not an int or string, so bigger
                            (local.set '$result (local.get '$lt_val))
                            (br '$b)
                        )
                    )
                    (_if '$b_string
                        (i64.eq (i64.const #b011) (i64.and (i64.const #b111) (local.get '$b)))
                        (then
                            (local.set '$result (local.get '$gt_val))
                            (br '$b))
                    )
                    ;; SYMBOL
                    (_if '$a_symbol
                        (i64.eq (i64.const #b111) (i64.and (i64.const #b111) (local.get '$a)))
                        (then
                            (_if '$b_symbol
                                (i64.eq (i64.const #b111) (i64.and (i64.const #b111) (local.get '$b)))
                                (then
                                    (local.set '$result (call '$str_sym_comp (local.get '$a) (local.get '$b) (local.get '$lt_val) (local.get '$eq_val) (local.get '$gt_val)))
                                    (br '$b))
                            )
                            ; else b is not an int or string or symbol, so bigger
                            (local.set '$result (local.get '$lt_val))
                            (br '$b)
                        )
                    )
                    (_if '$b_symbol
                        (i64.eq (i64.const #b111) (i64.and (i64.const #b111) (local.get '$b)))
                        (then
                            (local.set '$result (local.get '$gt_val))
                            (br '$b))
                    )
                    ;; ARRAY
                    (_if '$a_array
                        (i64.eq (i64.const #b101) (i64.and (i64.const #b111) (local.get '$a)))
                        (then
                            (_if '$b_array
                                (i64.eq (i64.const #b101) (i64.and (i64.const #b111) (local.get '$b)))
                                (then
                                    (local.set '$a_tmp (i32.wrap_i64 (i64.shr_u (local.get '$a) (i64.const 32))))
                                    (local.set '$b_tmp (i32.wrap_i64 (i64.shr_u (local.get '$b) (i64.const 32))))

                                    (_if '$a_len_lt_b_len
                                        (i32.lt_s (local.get '$a_tmp) (local.get '$b_tmp))
                                        (then (local.set '$result (local.get '$lt_val))
                                              (br '$b)))
                                    (_if '$a_len_gt_b_len
                                        (i32.gt_s (local.get '$a_tmp) (local.get '$b_tmp))
                                        (then (local.set '$result (local.get '$gt_val))
                                              (br '$b)))

                                    (local.set '$a_ptr (i32.wrap_i64 (i64.and (local.get '$a) (i64.const #xFFFFFFF8))))
                                    (local.set '$b_ptr (i32.wrap_i64 (i64.and (local.get '$b) (i64.const #xFFFFFFF8))))

                                    (_loop '$l
                                        (br_if '$b (i32.eqz (local.get '$a_tmp)))

                                        (local.set '$result_tmp (call '$comp_helper_helper (i64.load (local.get '$a_ptr))
                                                                                           (i64.load (local.get '$b_ptr))
                                                                                           (i64.const -1) (i64.const 0) (i64.const 1)))

                                        (_if '$a_lt_b
                                            (i64.eq (local.get '$result_tmp) (i64.const -1))
                                            (then (local.set '$result (local.get '$lt_val))
                                                  (br '$b)))
                                        (_if '$a_gt_b
                                            (i64.eq (local.get '$result_tmp) (i64.const 1))
                                            (then (local.set '$result (local.get '$gt_val))
                                                  (br '$b)))

                                        (local.set '$a_tmp (i32.sub (local.get '$a_tmp) (i32.const 1)))
                                        (local.set '$a_ptr (i32.add (local.get '$a_ptr) (i32.const 8)))
                                        (local.set '$b_ptr (i32.add (local.get '$b_ptr) (i32.const 8)))
                                        (br '$l)
                                    )
                                    (br '$b))
                            )
                            ; else b is not an int or string or symbol or array, so bigger
                            (local.set '$result (local.get '$lt_val))
                            (br '$b)
                        )
                    )
                    (_if '$b_array
                        (i64.eq (i64.const #b111) (i64.and (i64.const #b111) (local.get '$b)))
                        (then
                            (local.set '$result (local.get '$gt_val))
                            (br '$b))
                    )
                    ;; COMBINER
                    (_if '$a_comb
                        (i64.eq (i64.const #b0001) (i64.and (i64.const #b1111) (local.get '$a)))
                        (then
                            (_if '$b_comb
                                (i64.eq (i64.const #b0001) (i64.and (i64.const #b1111) (local.get '$b)))
                                (then
                                    ; compare func indicies first
                                    (local.set '$a_tmp (i32.wrap_i64 (i64.shr_u (local.get '$a) (i64.const 35))))
                                    (local.set '$b_tmp (i32.wrap_i64 (i64.shr_u (local.get '$b) (i64.const 35))))
                                    (_if '$a_tmp_lt_b_tmp
                                        (i32.lt_s (local.get '$a_tmp) (local.get '$b_tmp))
                                        (then
                                            (local.set '$result (local.get '$lt_val))
                                            (br '$b))
                                    )
                                    (_if '$a_tmp_eq_b_tmp
                                        (i32.gt_s (local.get '$a_tmp) (local.get '$b_tmp))
                                        (then
                                            (local.set '$result (local.get '$gt_val))
                                            (br '$b))
                                    )
                                    ; Idx was the same, so recursively comp envs
                                    (local.set '$result (call '$comp_helper_helper (i64.or (i64.shl (i64.extend_i32_u (local.get '$a_tmp)) (i64.const 5)) (i64.const #b01001))
                                                                                   (i64.or (i64.shl (i64.extend_i32_u (local.get '$b_tmp)) (i64.const 5)) (i64.const #b01001))
                                                                                   (local.get '$lt_val) (local.get '$eq_val) (local.get '$gt_val)))
                                    (br '$b))
                            )
                            ; else b is not an int or string or symbol or array or combiner, so bigger
                            (local.set '$result (local.get '$lt_val))
                            (br '$b)
                        )
                    )
                    (_if '$b_comb
                        (i64.eq (i64.const #b0001) (i64.and (i64.const #b1111) (local.get '$b)))
                        (then
                            (local.set '$result (local.get '$gt_val))
                            (br '$b))
                    )
                    ;; ENV
                    (_if '$a_env
                        (i64.eq (i64.const #b01001) (i64.and (i64.const #b11111) (local.get '$a)))
                        (then
                            (_if '$b_comb
                                (i64.eq (i64.const #b01001) (i64.and (i64.const #b11111) (local.get '$b)))
                                (then
                                    (local.set '$a_ptr (i32.wrap_i64 (i64.shr_u (local.get '$a) (i64.const 5))))
                                    (local.set '$b_ptr (i32.wrap_i64 (i64.shr_u (local.get '$b) (i64.const 5))))

                                    ; First, compare their symbol arrays
                                    (local.set '$result_tmp (call '$comp_helper_helper (i64.load 0 (local.get '$a_ptr))
                                                                                       (i64.load 0 (local.get '$b_ptr))
                                                                                       (i64.const -1) (i64.const 0) (i64.const 1)))
                                    (_if '$a_lt_b
                                        (i64.eq (local.get '$result_tmp) (i64.const -1))
                                        (then (local.set '$result (local.get '$lt_val))
                                              (br '$b)))
                                    (_if '$a_gt_b
                                        (i64.eq (local.get '$result_tmp) (i64.const 1))
                                        (then (local.set '$result (local.get '$gt_val))
                                              (br '$b)))

                                    ; Second, compare their value arrays
                                    (local.set '$result_tmp (call '$comp_helper_helper (i64.load 8 (local.get '$a_ptr))
                                                                                       (i64.load 8 (local.get '$b_ptr))
                                                                                       (i64.const -1) (i64.const 0) (i64.const 1)))
                                    (_if '$a_lt_b
                                        (i64.eq (local.get '$result_tmp) (i64.const -1))
                                        (then (local.set '$result (local.get '$lt_val))
                                              (br '$b)))
                                    (_if '$a_gt_b
                                        (i64.eq (local.get '$result_tmp) (i64.const 1))
                                        (then (local.set '$result (local.get '$gt_val))
                                              (br '$b)))

                                    ; Finally, just accept the result of recursion
                                    (local.set '$result (call '$comp_helper_helper (i64.load 16 (local.get '$a_ptr))
                                                                                   (i64.load 16 (local.get '$b_ptr))
                                                                                   (local.get '$lt_val) (local.get '$eq_val) (local.get '$gt_val)))

                                    (br '$b))
                            )
                            ; else b is bool, so bigger
                            (local.set '$result (local.get '$lt_val))
                            (br '$b)
                        )
                    )
                    (_if '$b_env
                        (i64.eq (i64.const #b01001) (i64.and (i64.const #b11111) (local.get '$b)))
                        (then
                            (local.set '$result (local.get '$gt_val))
                            (br '$b))
                    )
                    ;; BOOL hehe
                    (_if '$a_lt_b
                        (i64.lt_s (local.get '$a) (local.get '$b))
                        (then
                            (local.set '$result (local.get '$lt_val))
                            (br '$b))
                    )
                    (_if '$a_eq_b
                        (i64.eq (local.get '$a) (local.get '$b))
                        (then
                            (local.set '$result (local.get '$eq_val))
                            (br '$b))
                    )
                    (local.set '$result (local.get '$gt_val))
                    (br '$b)
                )
                (local.get '$result)
              ))))

              ((k_comp_helper   func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$comp_helper '(param $p i64) '(param $d i64) '(param $s i64) '(param $lt_val i64) '(param $eq_val i64) '(param $gt_val i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $result i64) '(local $a i64) '(local $b i64)
                set_len_ptr
                (local.set '$result (i64.const true_val))
                (block '$b
                    (_loop '$l
                        (br_if '$b (i32.le_u (local.get '$len) (i32.const 1)))
                        (local.set '$a (i64.load (local.get '$ptr)))
                        (local.set '$ptr (i32.add (local.get '$ptr) (i32.const 8)))
                        (local.set '$b (i64.load (local.get '$ptr)))
                        (_if '$was_false
                            (i64.eq (i64.const false_val) (call '$comp_helper_helper (local.get '$a) (local.get '$b) (local.get '$lt_val) (local.get '$eq_val) (local.get '$gt_val)))
                            (then
                                (local.set '$result (i64.const false_val))
                                (br '$b)
                            )
                        )
                        (local.set '$len (i32.sub (local.get '$len) (i32.const 1)))
                        (br '$l)
                    )
                )
                (local.get '$result)
                drop_p_d
              ))))

              ((k_eq            func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$eq  '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$comp_helper (local.get '$p) (local.get '$d) (local.get '$s) (i64.const false_val)  (i64.const true_val)  (i64.const false_val))
              ))))
              ((k_neq           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$neq '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$comp_helper (local.get '$p) (local.get '$d) (local.get '$s) (i64.const true_val)   (i64.const false_val) (i64.const true_val))
              ))))
              ((k_geq           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$geq '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$comp_helper (local.get '$p) (local.get '$d) (local.get '$s) (i64.const false_val)  (i64.const true_val)  (i64.const true_val))
              ))))
              ((k_gt            func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$gt  '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$comp_helper (local.get '$p) (local.get '$d) (local.get '$s) (i64.const false_val)  (i64.const false_val) (i64.const true_val))
              ))))
              ((k_leq           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$leq '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$comp_helper (local.get '$p) (local.get '$d) (local.get '$s) (i64.const true_val)   (i64.const true_val)  (i64.const false_val))
              ))))
              ((k_lt            func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$lt  '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$comp_helper (local.get '$p) (local.get '$d) (local.get '$s) (i64.const true_val)   (i64.const false_val) (i64.const false_val))
              ))))

              (math_function (lambda (name sensitive op)
                (func name           '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $i i32) '(local $cur i64) '(local $next i64)
                    (ensure_not_op_n_params_set_ptr_len i32.eq 0)
                    (local.set '$i   (i32.const 1))
                    (local.set '$cur (i64.load (local.get '$ptr)))
                    (_if '$not_num (i64.ne (i64.const 0) (i64.and (i64.const 1) (local.get '$cur)))
                        (then (unreachable))
                    )
                    (block '$b
                        (_loop '$l
                            (br_if '$b (i32.eq (local.get '$len) (local.get '$i)))
                            (local.set '$ptr (i32.add (i32.const 8) (local.get '$ptr)))
                            (local.set '$next (i64.load (local.get '$ptr)))
                            (_if '$not_num (i64.ne (i64.const 0) (i64.and (i64.const 1) (local.get '$next)))
                                (then (unreachable))
                            )
                            (local.set '$cur (if sensitive (i64.shl (op (i64.shr_s (local.get '$cur) (i64.const 1)) (i64.shr_s (local.get '$next) (i64.const 1))) (i64.const 1))
                                                           (op (local.get '$cur) (local.get '$next))))
                            (local.set '$i (i32.add (local.get '$i) (i32.const 1)))
                            (br '$l)
                        )
                    )
                    (local.get '$cur)
                )
              ))

              ((k_mod           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$mod  true  i64.rem_s))))
              ((k_div           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$div  true  i64.div_s))))
              ((k_mul           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$mul  true  i64.mul))))
              ((k_sub           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$sub  true  i64.sub))))
              ((k_add           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$add  false i64.add))))
              ((k_band          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$band false i64.and))))
              ((k_bor           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$bor  false i64.or))))
              ((k_bxor          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (math_function '$bxor false i64.xor))))

              ((k_bnot          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$bnot   '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 type_int)
                (i64.xor (i64.const -2) (i64.load (local.get '$ptr)))
                drop_p_d
              ))))

              ((k_ls            func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$ls  '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 2)
                (type_assert 0 type_int)
                (type_assert 1 type_int)
                (i64.shl (i64.load 0 (local.get '$ptr)) (i64.shr_s (i64.load 8 (local.get '$ptr)) (i64.const 1)))
                drop_p_d
              ))))
              ((k_rs            func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$rs  '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 2)
                (type_assert 0 type_int)
                (type_assert 1 type_int)
                (i64.and (i64.const -2) (i64.shr_s (i64.load 0 (local.get '$ptr)) (i64.shr_s (i64.load 8 (local.get '$ptr)) (i64.const 1))))
                drop_p_d
              ))))

              ((k_concat        func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$concat  '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $size i32) '(local $i i32) '(local $it i64) '(local $new_ptr i32) '(local $inner_ptr i32) '(local $inner_size i32) '(local $new_ptr_traverse i32)
                set_len_ptr
                (local.set '$size (i32.const 0))
                (local.set '$i (i32.const 0))
                (block '$b
                    (_loop '$l
                        (br_if '$b (i32.eq (local.get '$len) (local.get '$i)))
                        (local.set '$it (i64.load (i32.add (i32.shl (local.get '$i) (i32.const 3)) (local.get '$ptr))))
                        (_if '$not_array (i64.ne (i64.const #b101) (i64.and (i64.const #b111) (local.get '$it)))
                            (then (unreachable))
                        )
                        (local.set '$size (i32.add (local.get '$size) (i32.wrap_i64 (i64.shr_u (local.get '$it) (i64.const 32)))))
                        (local.set '$i    (i32.add (local.get '$i)    (i32.const 1)))
                        (br '$l)
                    )
                )
                (_if '$size_0 '(result i64)
                    (i32.eqz (local.get '$size))
                    (then (i64.const nil_val))
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

                                (local.set '$inner_ptr  (i32.wrap_i64 (i64.and   (local.get '$it) (i64.const -8))))
                                (local.set '$inner_size (i32.wrap_i64 (i64.shr_u (local.get '$it) (i64.const 32))))

                                (block '$exit_inner_loop
                                    (_loop '$inner_loop
                                        (br_if '$exit_inner_loop (i32.eqz (local.get '$inner_size)))
                                        (i64.store (local.get '$new_ptr_traverse)
                                                   (call '$dup (i64.load (local.get '$inner_ptr))))
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

                        (i64.or (i64.or  (i64.extend_i32_u (local.get '$new_ptr)) (i64.const #x5))
                                (i64.shl (i64.extend_i32_u (local.get '$size))    (i64.const 32)))
                    )
                )
                drop_p_d
              ))))
              ((k_slice         func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$slice   '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 3)
                (type_assert 0 type_array)
                (type_assert 1 type_int)
                (type_assert 2 type_int)
                (call '$slice_impl (call '$dup (i64.load  0 (local.get '$ptr)))
                                   (i32.wrap_i64 (i64.shr_s (i64.load  8 (local.get '$ptr)) (i64.const 1)))
                                   (i32.wrap_i64 (i64.shr_s (i64.load 16 (local.get '$ptr)) (i64.const 1))))
                drop_p_d
              ))))
              ((k_idx           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$idx     '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $array i64) '(local $idx i32) '(local $size i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 2)
                (type_assert 0 type_array)
                (type_assert 1 type_int)
                (local.set '$array (i64.load 0 (local.get '$ptr)))
                (local.set '$idx  (i32.wrap_i64 (i64.shr_s (i64.load 8 (local.get '$ptr)) (i64.const 1))))
                (local.set '$size (i32.wrap_i64 (i64.shr_u (local.get '$array) (i64.const 32))))

                (_if '$i_lt_0     (i32.lt_s (local.get '$idx) (i32.const 0))      (then (unreachable)))
                (_if '$i_ge_s     (i32.ge_s (local.get '$idx) (local.get '$size)) (then (unreachable)))

                (call '$dup (i64.load (i32.add (i32.wrap_i64 (i64.and (local.get '$array) (i64.const -8)))
                                               (i32.shl (local.get '$idx) (i32.const 3)))))
                drop_p_d
              ))))
              ((k_len           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$len     '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 type_array)
                (i64.and (i64.shr_u (i64.load 0 (local.get '$ptr)) (i64.const 31)) (i64.const -2))
                drop_p_d
              ))))
              ((k_array         func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$array   '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (local.get '$p)
                (call '$drop (local.get '$d))
                ; s is 0
              ))))

              ((k_get-text      func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$get-text      '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 type_symbol)
                (call '$dup (i64.and (i64.const -5) (i64.load (local.get '$ptr))))
                drop_p_d
              ))))
              ((k_str-to-symbol func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$str-to-symbol '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 type_string)
                (call '$dup (i64.or (i64.const #b100) (i64.load (local.get '$ptr))))
                drop_p_d
              ))))

              ((k_unwrap        func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$unwrap        '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $comb i64) '(local $wrap_level i64)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 type_combiner)
                (local.set '$comb (i64.load (local.get '$ptr)))
                (local.set '$wrap_level (i64.and (i64.shr_u (local.get '$comb) (i64.const 4)) (i64.const #b11)))
                (_if '$wrap_level_0
                    (i64.eqz (local.get '$wrap_level))
                    (then (unreachable))
                )
                (call '$dup (i64.or (i64.and (local.get '$comb) (i64.const -49))
                                    (i64.shl (i64.sub (local.get '$wrap_level) (i64.const 1)) (i64.const 4))))
                drop_p_d
              ))))
              ((k_wrap          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$wrap          '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $comb i64) '(local $wrap_level i64)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 type_combiner)
                (local.set '$comb (i64.load (local.get '$ptr)))
                (local.set '$wrap_level (i64.and (i64.shr_u (local.get '$comb) (i64.const 4)) (i64.const #b11)))
                (_if '$wrap_level_3
                    (i64.eq (i64.const 3) (local.get '$wrap_level))
                    (then (unreachable))
                )
                (call '$dup (i64.or (i64.and (local.get '$comb) (i64.const -49))
                                    (i64.shl (i64.add (local.get '$wrap_level) (i64.const 1)) (i64.const 4))))
                drop_p_d
              ))))

              ;true_val          #b000111001
              ;false_val         #b00001100)
              (empty_parse_value #b00101100)
              (close_peren_value #b01001100)
              (error_parse_value #b01101100)
              ; *GLOBAL ALERT*
              ((k_parse_helper  func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$parse_helper  '(result i64) '(local $result i64) '(local $tmp i32) '(local $sub_result i64) '(local $asiz i32) '(local $acap i32) '(local $aptr i32) '(local $bptr i32) '(local $bcap i32) '(local $neg_multiplier i64) '(local $radix i64)
                (block '$b1
                    (block '$b2
                        (_loop '$l
                            (br_if '$b2 (i32.eqz (global.get '$phl)))
                            (local.set '$tmp (i32.load8_u (global.get '$phs)))
                            (call '$print (i64.shl (i64.extend_i32_u (local.get '$tmp)) (i64.const 1)))
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
                                    (local.set '$result (i64.or (i64.or  (i64.extend_i32_u (local.get '$aptr)) (i64.const #x3))
                                                                (i64.shl (i64.extend_i32_u (local.get '$asiz)) (i64.const 32))))
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
                                    (local.set '$result (i64.shl (i64.mul (local.get '$neg_multiplier) (local.get '$result)) (i64.const 1)))
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
                                    (local.set '$result (i64.or (i64.or  (i64.extend_i32_u (local.get '$aptr)) (i64.const #x7))
                                                                (i64.shl (i64.extend_i32_u (local.get '$asiz)) (i64.const 32))))
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
                                                        (local.set '$result (i64.or (i64.or  (i64.extend_i32_u (local.get '$aptr)) (i64.const #x5))
                                                                                    (i64.shl (i64.extend_i32_u (local.get '$asiz)) (i64.const 32))))
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
              ((k_read-string   func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$read-string   '(param $p i64) '(param $d i64) '(param $s i64) '(result i64) '(local $ptr i32) '(local $len i32) '(local $str i64) '(local $result i64) '(local $tmp_result i64) '(local $tmp_offset i32)
                (ensure_not_op_n_params_set_ptr_len i32.ne 1)
                (type_assert 0 type_string)
                (local.set '$str (i64.load (local.get '$ptr)))
                (call '$print (local.get '$str))
                (global.set '$phl (i32.wrap_i64 (i64.shr_u (local.get '$str) (i64.const 32))))
                (global.set '$phs (i32.wrap_i64 (i64.and   (local.get '$str) (i64.const #xFFFFFFF8))))
                (local.set '$result (call '$parse_helper))
                (_if '$was_empty_parse
                    (i32.or         (i64.eq (i64.const error_parse_value) (local.get '$result))
                            (i32.or (i64.eq (i64.const empty_parse_value) (local.get '$result))
                                    (i64.eq (i64.const close_peren_value) (local.get '$result))))
                    (then
                        (call '$print (i64.const couldnt_parse_1_msg_val))
                        (call '$print (local.get '$str))
                        (call '$print (i64.const couldnt_parse_2_msg_val))
                        (call '$print (i64.shl (i64.add (i64.const 1) (i64.sub (i64.shr_u (local.get '$str) (i64.const 32)) (i64.extend_i32_u (global.get '$phl)))) (i64.const 1)))
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
                                (call '$print (i64.shl (i64.sub (i64.shr_u (local.get '$str) (i64.const 32)) (i64.extend_i32_u (local.get '$tmp_offset))) (i64.const 1)))
                                (call '$print (i64.const newline_msg_val))
                                (unreachable)
                            )
                        )
                    )
                )
                (local.get '$result)
                drop_p_d
              ))))
              ((k_eval          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$eval          '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)

                (call '$print (i64.const remaining_eval_msg_val))
                (unreachable)
              ))))
              ((k_vau           func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$vau           '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$print (i64.const remaining_vau_msg_val))
                (unreachable)
              ))))
              ((k_cond          func_idx funcs) (array func_idx (+ 1 func_idx) (concat funcs (func '$cond          '(param $p i64) '(param $d i64) '(param $s i64) '(result i64)
                (call '$print (i64.const remaining_cond_msg_val))
                (unreachable)
              ))))

              (get_passthrough (dlambda (hash (datasi funcs memo env pectx)) (let ((r (get-value-or-false memo hash)))
                                                                     (if r (array r nil nil (array datasi funcs memo env pectx)) #f))))

              ; This is the second run at this, and is a little interesting
              ; It can return a value OR code OR an error string. An error string should be propegated,
              ; unless it was expected as a possiblity, which can happen when compling a call that may or
              ; may not be a Vau. When it recurses, if the thing you're currently compiling could be a value
              ; but your recursive calls return code, you will likely have to swap back to code.

              ; ctx is (datasi funcs memo env pectx)
              ; return is (value? code? error? (datasi funcs memo env pectx))
              (compile-inner (rec-lambda compile-inner (ctx c need_value) (cond
                    ((val? c)   (let ((v (.val c)))
                                     (cond ((int? v)    (array  (<< v 1) nil nil ctx))
                                           ((= true v)  (array  true_val nil nil ctx))
                                           ((= false v) (array false_val nil nil ctx))
                                           ((str? v)    (or (get_passthrough (.hash c) ctx)
                                                            (dlet ( ((datasi funcs memo env pectx) ctx)
                                                                    ((c_loc c_len datasi) (alloc_data v datasi))
                                                                    (a (bor (<< c_len 32) c_loc #b011))
                                                                    (memo (put memo (.hash c) a))
                                                                  ) (array a nil nil (array datasi funcs memo env pectx)))))
                                           (true        (error (str "Can't compile impossible value " v))))))
                    ((marked_symbol? c) (cond ((.marked_symbol_is_val c) (or ;(begin (print "pre get_passthrough " (.hash c) "ctx is " ctx )
                                                                                    (get_passthrough (.hash c) ctx)
                                                                             ;)
                                                                             (dlet ( ((datasi funcs memo env pectx) ctx)
                                                                                     ((c_loc c_len datasi) (alloc_data (symbol->string (.marked_symbol_value c))  datasi))
                                                                                     (result (bor (<< c_len 32) c_loc #b111))
                                                                                     (memo (put memo (.hash c) result))
                                                                                   ) (array result nil nil (array datasi funcs memo env pectx)))))



                                              (true (dlet ( ((datasi funcs memo env pectx) ctx)
                                                            ; not a recoverable error, so just do here
                                                            (_ (if (= nil env) (error "nil env when trying to compile a non-value symbol")))
                                                            (lookup_helper (rec-lambda lookup-recurse (dict key i code) (cond
                                                                ((and (= i (- (len dict) 1)) (= nil (idx dict i))) (array nil (str "for code-symbol lookup, couldn't find " key)))
                                                                ((= i (- (len dict) 1))                            (lookup-recurse (.env_marked (idx dict i)) key 0 (i64.load 16 (i32.wrap_i64 (i64.shr_u code (i64.const 5))))))
                                                                ((= key (idx (idx dict i) 0))                      (array (i64.load (* 8 i)                                               ; offset in array to value
                                                                                                                        (i32.wrap_i64 (i64.and (i64.const -8)                       ; get ptr from array value
                                                                                                                        (i64.load 8 (i32.wrap_i64 (i64.shr_u code
                                                                                                                                                             (i64.const 5))))))) nil))
                                                                (true                                              (lookup-recurse dict key (+ i 1) code)))))


                                                            ((val err) (lookup_helper (.env_marked env) (.marked_symbol_value c) 0 (local.get '$s_env)))
                                                            (err (mif err (str "got " err ", started searching in " (str_strip env)) (if need_value (str "needed value, but non val symbol " (.marked_symbol_value c)) nil)))
                                                            (result (mif val (call '$dup val)))
                                                          ) (array nil result err (array datasi funcs memo env pectx))))))
                   ((marked_array? c) (if (.marked_array_is_val c) (or (get_passthrough (.hash c) ctx)
                                                                       (let ((actual_len (len (.marked_array_values c))))
                                                                         (if (= 0 actual_len) (array nil_val nil nil ctx)
                                                                             (dlet (((comp_values err ctx) (foldr (dlambda (x (a err ctx)) (dlet (((v c e ctx) (compile-inner ctx x need_value)))
                                                                                                                                         (array (cons v a) (or (mif err err false) (mif e e false) (mif c (str "got code " c) false)) ctx))) (array (array) nil ctx) (.marked_array_values c)))
                                                                                   ) (mif err (array nil nil (str err ", from an array value compile " (str_strip c)) ctx) (dlet (
                                                                                    ((datasi funcs memo env pectx) ctx)
                                                                                    ;(_ (print_strip "made from " c))
                                                                                    ;(_ (print "pre le_hexify " comp_values))
                                                                                    ;(_ (print "pre le_hexify, err was " err))
                                                                                    ;(_ (mif err (error err)))
                                                                                    ((c_loc c_len datasi) (alloc_data (apply concat (map i64_le_hexify comp_values)) datasi))
                                                                                    (result (bor (<< actual_len 32) c_loc #b101))
                                                                                    (memo (put memo (.hash c) result))
                                                                                   ) (array result nil nil (array datasi funcs memo env pectx))))))))

                                                        (if need_value (array nil nil "errr, needed value and was call" ctx)

                                                                    (dlet (
                                                        (func_param_values (.marked_array_values c))
                                                        (num_params (- (len func_param_values) 1))

                                                        ; In the paths where this is used, we know we can partial_evaluate the parameters


                                                        ;(_ (print_strip "doing further partial eval for " c))
                                                        (_ (true_print "doing further partial eval for "))
                                                        (_ (true_print "\t" (true_str_strip c)))
                                                        ; This can weirdly cause infinate recursion on the compile side, if partial_eval
                                                        ; returns something that, when compiled, will cause partial eval to return that thing again.
                                                        ; Partial eval won't recurse infinately, since it has memo, but it can return something of that
                                                        ; shape in that case which will cause compile to keep stepping.
                                                        ((datasi funcs memo env pectx) ctx)
                                                        ((pectx err evaled_params) (if (= 'RECURSE_FAIL (get-value-or-false memo (.hash c))) (begin (true_print "got a recurse, stoping") (array pectx "RECURSE FAIL" nil))
                                                                                   (foldl (dlambda ((c er ds) p) (dlet (((c e d) (partial_eval_helper p false env (array) c 1)))
                                                                                                                      (array c (mif er er e) (concat ds (array d)))))
                                                                                                (array pectx nil (array))
                                                                                                (slice func_param_values 1 -1))))
                                                        (_ (true_print "DONE further partial eval for "))
                                                        (_ (true_print "\t" (true_str_strip c)))
                                                        ; TODO: This might fail because we don't have the real env stack, which we *should*!
                                                        ; In the mean time, if it does, just fall back to the non-more-evaled ones.
                                                        (to_code_params (mif err (slice func_param_values 1 -1) evaled_params))

                                                        (memo (put memo (.hash c) 'RECURSE_FAIL))
                                                        (ctx (array datasi funcs memo env pectx))
                                                        ((param_codes err ctx) (foldr (dlambda (x (a err ctx))
                                                                                                   (mif err (array a err ctx)
                                                                                                            (dlet (((val code new_err ctx) (compile-inner ctx x false)))
                                                                                                                  (array (cons (mif code code (i64.const val)) a) new_err ctx))))
                                                                                (array (array) nil ctx) to_code_params))
                                                        ((datasi funcs memo env pectx) ctx)
                                                        (memo (put memo (.hash c) 'RECURSE_OK))
                                                        (ctx (array datasi funcs memo env pectx))
                                                        (func_value (idx func_param_values 0))
                                                        ((func_val func_code func_err ctx) (compile-inner ctx func_value false))
                                                        ;(_ (mif err (error err)))
                                                        ;(_ (mif func_err (error func_err)))
                                                        (_ (mif func_code (print_strip  "Got code for function " func_value)))
                                                        (_ (print_strip "func val " func_val " func code " func_code " func err " func_err " param_codes " param_codes " err " err " from " func_value))
                                                        (func_code (mif func_val (i64.const func_val) func_code))
                                                        ;; Insert test for the function being a constant to inline
                                                        ;; Namely, cond
                                                        ) (cond
                                                            ((or (!= nil err) (!= nil func_err))    (array nil nil (mif err (str err " from function params in call " (str_strip c)) (str func_err " from function itself  in call " (str_strip c))) ctx))
                                                            ((and (prim_comb? func_value) (= (.prim_comb_sym func_value) 'cond))
                                                                                                               (dlet (
                                                                                                                ((datasi funcs memo env pectx) ctx)
                                                                                                               ) (array nil ((rec-lambda recurse (codes i) (cond
                                                                                                                        ((< i (- (len codes) 1)) (_if '_cond_flat '(result i64)
                                                                                                                                                    (truthy_test (idx codes i))
                                                                                                                                                    (then (idx codes (+ i 1)))
                                                                                                                                                    (else (recurse codes (+ i 2)))
                                                                                                                                                ))
                                                                                                                        ((= i (- (len codes) 1)) (error "compiling bad length comb"))
                                                                                                                        (true                    (unreachable))
                                                                                                                    )) param_codes 0) err ctx)))
                                                            (true (dlet (
                                                                (result_code (concat
                                                                                func_code
                                                                                (local.set '$tmp)
                                                                                (_if '$is_wrap_1
                                                                                    (i64.eq (i64.const #x10) (i64.and (local.get '$tmp) (i64.const #x30)))
                                                                                    (then
                                                                                         ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                                                                                         ; Since we're not sure if it's going to be a vau or not,
                                                                                         ; this code might not be compilable, so we gracefully handle
                                                                                         ; compiler errors and instead emit code that throws the error if this
                                                                                         ; spot is ever reached at runtime.
                                                                                         ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                                                                                         (mif err (concat
                                                                                                    (call '$print (i64.const bad_not_vau_msg_val))
                                                                                                    (unreachable)
                                                                                                  )
                                                                                                  (concat
                                                                                                     (local.get '$tmp) ; saving ito restore it
                                                                                                     (apply concat param_codes)
                                                                                                     (local.set '$param_ptr (call '$malloc (i32.const (* 8 num_params))))
                                                                                                     (flat_map (lambda (i) (i64.store (* i 8) (local.set '$tmp) (local.get '$param_ptr) (local.get '$tmp)))
                                                                                                               (range (- num_params 1) -1))
                                                                                                     (local.set '$tmp) ; restoring tmp
                                                                                                  ))
                                                                                    )
                                                                                    (else
                                                                                        ; TODO: Handle other wrap levels
                                                                                        (call '$print (i64.const remaining_vau_msg_val))
                                                                                        (unreachable)
                                                                                    )
                                                                                )
                                                                                (call_indirect
                                                                                    ;type
                                                                                    k_vau
                                                                                    ;table
                                                                                    0
                                                                                    ;params
                                                                                    (i64.or (i64.extend_i32_u (local.get '$param_ptr))
                                                                                            (i64.const (bor (<< num_params 32) #x5)))
                                                                                    ;dynamic env (is caller's static env)
                                                                                    (call '$dup (local.get '$s_env))
                                                                                    ; static env
                                                                                    (i64.or (i64.shl (i64.and (local.get '$tmp) (i64.const #x3FFFFFFC0))
                                                                                                     (i64.const 2)) (i64.const #b01001))
                                                                                    ;func_idx
                                                                                    (i32.wrap_i64 (i64.shr_u (local.get '$tmp) (i64.const 35)))
                                                                                )))
                                                                ) (array nil result_code func_err ctx)))
                                                        )))))

                    ((marked_env? c) (or (get_passthrough (.hash c) ctx) (dlet ((e (.env_marked c))

                                            (generate_env_access (dlambda ((datasi funcs memo env pectx) env_id reason) ((rec-lambda recurse (code this_env)
                                                (cond
                                                    ((= env_id (.marked_env_idx this_env)) (array nil (call '$dup code) nil (array datasi funcs memo env pectx)))
                                                    ((= nil (.marked_env_upper this_env))  (array nil nil (str "bad env, upper is nil and we haven't found " env_id ", maxing out at " (str_strip this_env) ",  having started at " (str_strip env) ", we're generating because " reason) (array datasi funcs memo env pectx)))
                                                    (true                                  (recurse (i64.load 16 (i32.wrap_i64 (i64.shr_u code (i64.const 5))))
                                                                                                    (.marked_env_upper this_env)))
                                                )
                                            ) (local.get '$s_env) env)))

                                            ) (if (not (marked_env_real? c)) (begin (print_strip "env wasn't real: " (marked_env_real? c) ", so generating access (env was) " c) (if need_value (array nil nil (str "marked env not real, though we need_value: " (str_strip c)) ctx) (generate_env_access ctx (.marked_env_idx c) "it wasn't real: " (str_strip c))))
                                            (dlet (


                                            ((kvs vvs ctx) (foldr (dlambda ((k v) (ka va ctx)) (dlet (((kv _    _   ctx) (compile-inner ctx (marked_symbol nil k) true))
                                                                                                      ((vv code err ctx) (compile-inner ctx v need_value))
                                                                                                      (_ (print_strip "result of (kv is " kv ") v compile-inner vv " vv " code " code " err " err ", based on " v))
                                                                                                      (_ (if (= nil vv) (print_strip "VAL NIL CODE IN ENV B/C " k " = " v) nil))
                                                                                                      (_ (if (!= nil err) (print_strip "ERRR IN ENV B/C " err " " k " = " v) nil))
                                                                                                      )
                                                                                                      (if (= false ka) (array false va ctx)
                                                                                                      (if (or (= nil vv) (!= nil err)) (array false (str "vv was " vv " err is " err " and we needed_value? " need_value " based on v " (str_strip v)) ctx)
                                                                                                                                       (array (cons kv ka) (cons vv va) ctx)))))
                                                                  (array (array) (array) ctx)
                                                                  (slice e 0 -2)))

                                            ((uv ucode err ctx) (mif (idx e -1) (compile-inner ctx (idx e -1) need_value)
                                                                                (array nil_val nil nil ctx)))
                                            ) (mif (or (= false kvs) (= nil uv) (!= nil err)) (begin (print_strip "kvs " kvs " vvs " vvs " uv " uv " or err " err " based off of " c) (if need_value (array nil nil (str "had to generate env access (course " need_value ") for " (str_strip c) "vvs is " vvs " err was " err) ctx) (generate_env_access ctx (.marked_env_idx c) (str " vvs " vvs " uv " uv " or err " err " based off of " (str_strip c)))))
                                            (dlet (
                                                ((datasi funcs memo env pectx) ctx)
                                                ((kvs_array datasi) (if (= 0 (len kvs)) (array nil_val datasi)
                                                                                        (dlet (((kvs_loc kvs_len datasi) (alloc_data (apply concat (map i64_le_hexify kvs)) datasi)))
                                                                                              (array (bor (<< (len kvs) 32) kvs_loc #b101) datasi))))
                                                ((vvs_array datasi) (if (= 0 (len vvs)) (array nil_val datasi)
                                                                                        (dlet (((vvs_loc vvs_len datasi) (alloc_data (apply concat (map i64_le_hexify vvs)) datasi)))
                                                                                              (array (bor (<< (len vvs) 32) vvs_loc #b101) datasi))))
                                                (all_hex (map i64_le_hexify (array kvs_array vvs_array uv)))
                                                ((c_loc c_len datasi) (alloc_data (apply concat all_hex) datasi))
                                                (result (bor (<< c_loc 5) #b01001))
                                                (memo (put memo (.hash c) result))
                                            ) (array result nil nil (array datasi funcs memo env pectx)))))))))

                    ((prim_comb? c) (cond ((= 'vau            (.prim_comb_sym c))  (array (bor (<< (- k_vau dyn_start)           35) (<< 0 4) #b0001) nil nil ctx))
                                          ((= 'cond           (.prim_comb_sym c))  (array (bor (<< (- k_cond dyn_start)          35) (<< 0 4) #b0001) nil nil ctx))
                                          ((= 'eval           (.prim_comb_sym c))  (array (bor (<< (- k_eval dyn_start)          35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'read-string    (.prim_comb_sym c))  (array (bor (<< (- k_read-string dyn_start)   35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'log            (.prim_comb_sym c))  (array (bor (<< (- k_log dyn_start)           35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'error          (.prim_comb_sym c))  (array (bor (<< (- k_error dyn_start)         35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'str            (.prim_comb_sym c))  (array (bor (<< (- k_str dyn_start)           35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= '>=             (.prim_comb_sym c))  (array (bor (<< (- k_geq dyn_start)           35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= '>              (.prim_comb_sym c))  (array (bor (<< (- k_gt dyn_start)            35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= '<=             (.prim_comb_sym c))  (array (bor (<< (- k_leq dyn_start)           35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= '<              (.prim_comb_sym c))  (array (bor (<< (- k_lt dyn_start)            35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= '!=             (.prim_comb_sym c))  (array (bor (<< (- k_neq dyn_start)           35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= '=              (.prim_comb_sym c))  (array (bor (<< (- k_eq dyn_start)            35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= '%              (.prim_comb_sym c))  (array (bor (<< (- k_mod dyn_start)           35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= '/              (.prim_comb_sym c))  (array (bor (<< (- k_div dyn_start)           35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= '*              (.prim_comb_sym c))  (array (bor (<< (- k_mul dyn_start)           35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= '+              (.prim_comb_sym c))  (array (bor (<< (- k_add dyn_start)           35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= '-              (.prim_comb_sym c))  (array (bor (<< (- k_sub dyn_start)           35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'band           (.prim_comb_sym c))  (array (bor (<< (- k_band dyn_start)          35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'bor            (.prim_comb_sym c))  (array (bor (<< (- k_bor dyn_start)           35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'bxor           (.prim_comb_sym c))  (array (bor (<< (- k_bxor dyn_start)          35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'bnot           (.prim_comb_sym c))  (array (bor (<< (- k_bnot dyn_start)          35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= '<<             (.prim_comb_sym c))  (array (bor (<< (- k_ls dyn_start)            35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= '>>             (.prim_comb_sym c))  (array (bor (<< (- k_rs dyn_start)            35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'array          (.prim_comb_sym c))  (array (bor (<< (- k_array dyn_start)         35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'concat         (.prim_comb_sym c))  (array (bor (<< (- k_concat dyn_start)        35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'slice          (.prim_comb_sym c))  (array (bor (<< (- k_slice dyn_start)         35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'idx            (.prim_comb_sym c))  (array (bor (<< (- k_idx dyn_start)           35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'len            (.prim_comb_sym c))  (array (bor (<< (- k_len dyn_start)           35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'array?         (.prim_comb_sym c))  (array (bor (<< (- k_array? dyn_start)        35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'get-text       (.prim_comb_sym c))  (array (bor (<< (- k_get-text dyn_start)      35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'str-to-symbol  (.prim_comb_sym c))  (array (bor (<< (- k_str-to-symbol dyn_start) 35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'bool?          (.prim_comb_sym c))  (array (bor (<< (- k_bool? dyn_start)         35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'nil?           (.prim_comb_sym c))  (array (bor (<< (- k_nil? dyn_start)          35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'env?           (.prim_comb_sym c))  (array (bor (<< (- k_env? dyn_start)          35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'combiner?      (.prim_comb_sym c))  (array (bor (<< (- k_combiner? dyn_start)     35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'string?        (.prim_comb_sym c))  (array (bor (<< (- k_string? dyn_start)       35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'int?           (.prim_comb_sym c))  (array (bor (<< (- k_int? dyn_start)          35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'symbol?        (.prim_comb_sym c))  (array (bor (<< (- k_symbol? dyn_start)       35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'unwrap         (.prim_comb_sym c))  (array (bor (<< (- k_unwrap dyn_start)        35) (<< 1 4) #b0001) nil nil ctx))
                                          ((= 'wrap           (.prim_comb_sym c))  (array (bor (<< (- k_wrap dyn_start)          35) (<< 1 4) #b0001) nil nil ctx))
                                          (true                                  (error (str "Can't compile prim comb " (.prim_comb_sym c) " right now")))))




                    ((comb? c) (dlet (
                                    (maybe_func (get_passthrough (.hash c) ctx))
                                    ((func_value _ func_err ctx) (mif maybe_func maybe_func
                                        (dlet (
                                        ((wrap_level env_id de? se variadic params body) (.comb c))
                                        ; Continued in the following TODO, but this is kinda nasty
                                        ; because it's not unified with make_tmp_env because the compiler
                                        ; splits de out into it's own environment so that it doesn't have to shift
                                        ; all of the passed parameters, whereas the partial_eval keeps it in
                                        ; the same env as the parameters.
                                        ((name_msg_value _ _ ctx) (compile-inner ctx (marked_val (str "\n\ncalling function " (str_strip c) " with: ")) true))
                                        ((inner_env setup_code ctx) (cond
                                            ((= 0 (len params))                (array se (array) ctx))
                                            ((and (= 1 (len params)) variadic) (dlet (
                                                ((params_vec _ _ _) (compile-inner ctx (marked_array true false (array (marked_symbol nil (idx params 0)))) true))
                                                ;(make_tmp_inner_env (array (idx params 0)) de? se env_id)
                                                ) (array (make_tmp_inner_env (array (idx params 0)) nil se env_id)
                                                         (local.set '$s_env (call '$env_alloc (i64.const params_vec)
                                                                                              (call '$array1_alloc (local.get '$params))
                                                                                              (local.get '$s_env)))
                                                         ctx
                                                  )))
                                            (true                              (dlet (
                                                ((params_vec _ _ ctx) (compile-inner ctx (marked_array true false (map (lambda (k) (marked_symbol nil k)) params)) true))
                                                (params_code (if variadic (concat
                                                                             (local.set '$param_ptr (i32.wrap_i64 (i64.and (i64.const -8) (local.get '$params))))
                                                                             (local.set '$tmp_ptr (call '$malloc (i32.const (* 8 (len params)))))
                                                                             (flat_map (lambda (i) (i64.store (* i 8) (local.get '$tmp_ptr) (call '$dup (i64.load (* i 8) (local.get '$param_ptr)))))
                                                                                       (range 0 (- (len params) 1)))
                                                                             (i64.store (* 8 (- (len params) 1)) (local.get '$tmp_ptr)
                                                                                        (call '$slice_impl (local.get '$params) (i32.const (- (len params) 1)) (i32.const -1)))
                                                                             (i64.or (i64.extend_i32_u (local.get '$tmp_ptr))
                                                                                     (i64.const (bor (<< (len params) 32) #x5)))
                                                                          )
                                                                          (local.get '$params)))
                                                (new_code (local.set '$s_env (call '$env_alloc (i64.const params_vec) params_code (local.get '$s_env))))
                                                ) (array (make_tmp_inner_env params nil se env_id) new_code ctx)))
                                        ))
                                        ((inner_env setup_code ctx) (if (= nil de?) (array inner_env (concat setup_code (call '$drop (local.get '$d_env))) ctx)
                                                                                                     (dlet (
                                            ((de_array_val _ _ ctx) (compile-inner ctx (marked_array true false (array (marked_symbol nil de?))) true))
                                            ) (array (make_tmp_inner_env (array de?) nil inner_env env_id)
                                                     (concat setup_code
                                                            (local.set '$s_env (call '$env_alloc (i64.const de_array_val)
                                                                                          (call '$array1_alloc (local.get '$d_env))
                                                                                          (local.get '$s_env))))
                                                      ctx
                                              )
                                        )))
                                        (setup_code (concat
                                            (call '$print (i64.const name_msg_value))
                                            (call '$print (local.get '$params))
                                            (call '$print (i64.shl (i64.shr_u (local.get '$params) (i64.const 32)) (i64.const 1)))
                                            (call '$print (i64.const (<< (len params) 1)))
                                            (call '$print (i64.const newline_msg_val))
                                            (call '$print (i64.const newline_msg_val))
                                            (_if '$params_len_good
                                                (if variadic    (i64.lt_u (i64.shr_u (local.get '$params) (i64.const 32)) (i64.const (- (len params) 1)))
                                                                (i64.ne   (i64.shr_u (local.get '$params) (i64.const 32)) (i64.const (len params))))
                                                (then
                                                    (call '$drop (local.get '$params))
                                                    (call '$drop (local.get '$s_env))
                                                    (call '$drop (local.get '$d_env))
                                                    (call '$print (i64.const bad_params_msg_val))
                                                    (unreachable)
                                                )
                                            ) setup_code
                                        ))

                                        ((datasi funcs memo env pectx) ctx)
                                        ((inner_value inner_code err ctx) (compile-inner (array datasi funcs memo inner_env pectx) body false))
                                        ; Don't overwrite env with what was our inner env! Env is returned as part of context to our caller!
                                        ((datasi funcs memo _was_inner_env pectx) ctx)
                                        ;(_ (print_strip "inner_value for maybe const is " inner_value " inner_code is " inner_code " err is " err " this was for " body))
                                        (inner_code (mif inner_value (i64.const inner_value) inner_code))
                                        (end_code (call '$drop (local.get '$s_env)))
                                        (our_func (func '$len '(param $params i64) '(param $d_env i64) '(param $s_env i64) '(result i64) '(local $param_ptr i32) '(local $tmp_ptr i32) '(local $tmp i64)
                                                    (concat setup_code inner_code end_code)
                                                  ))
                                        (funcs (concat funcs our_func))
                                        (our_func_idx (+ (- (len funcs) dyn_start) (- num_pre_functions 1)))
                                        (func_value (bor (<< our_func_idx 35) (<< wrap_level 4) #b0001))
                                        (memo (put memo (.hash c) func_value))
                                        (_ (print_strip "the hash " (.hash c) " with value " func_value " corresponds to " c))

                                        ) (array func_value nil err (array datasi funcs memo env pectx)))
                                    ))
                                    (_ (print_strip "returning " func_value " for " c))
                                    (_ (if (not (int? func_value)) (error "BADBADBADfunc")))

                                    ((wrap_level env_id de? se variadic params body) (.comb c))
                                    ((env_val env_code env_err ctx) (if (marked_env_real? se) (compile-inner ctx se need_value)
                                                                                              (if need_value (array nil nil "Env wasn't real when compiling comb, but need value" ctx)
                                                                                                             (array nil (call '$dup (local.get '$s_env)) nil ctx))))
                                    (_ (print_strip "result of compiling env for comb is val " env_val " code " env_code " err " env_err " and it was real? " (marked_env_real? se) " based off of env " se))
                                    (_ (if (not (or (= nil env_val) (int? env_val))) (error "BADBADBADenv_val")))
                                    ;  <func_idx29>|<env_ptr29><wrap2>0001
                                    ;                       e29><2><4> = 6
                                    ; 0..0<env_ptr29><3 bits>01001
                                    ;                       e29><3><5> = 8
                                    ; 0..0<env_ptr32 but still aligned>01001
                                    ; x+2+4 = y + 3 + 5
                                    ; x + 6 = y + 8
                                    ; x - 2 = y
                                ) (mif env_val  (array (bor (band #x7FFFFFFC0 (>> env_val 2)) func_value) nil (mif func_err (str func_err ", from compiling comb body") (mif env_err (str env_err ", from compiling comb env") nil)) ctx)
                                                (array nil (i64.or (i64.const func_value) (i64.and (i64.const #x7FFFFFFC0) (i64.shr_u env_code (i64.const 2)))) (mif func_err (str func_err ", from compiling comb body (env as code)") (mif env_err (str env_err ", from compiling comb env (as code)") nil)) ctx))
                                ))

                   (true        (error (str "Can't compile-inner impossible " c)))
              )))

              (_ (println "compiling partial evaled " (str_strip marked_code)))
              (_ (true_print "compiling partial evaled " (true_str_strip marked_code)))
              (memo empty_dict)
              (ctx (array datasi funcs memo root_marked_env pectx))

              ((exit_val _ _ ctx)               (compile-inner ctx (marked_symbol nil 'exit) true))
              ((read_val _ _ ctx)               (compile-inner ctx (marked_symbol nil 'read) true))
              ((write_val _ _ ctx)              (compile-inner ctx (marked_symbol nil 'write) true))
              ((open_val _ _ ctx)               (compile-inner ctx (marked_symbol nil 'open) true))
              ((monad_error_msg_val _ _ ctx)    (compile-inner ctx (marked_val "Not a legal monad ( ['read fd len <cont(data error_no)>] / ['write fd data <cont(num_written error_no)>] / ['open fd path <cont(new_fd error_no)>] /['exit exit_code])") true))
              ((bad_read_val _ _ ctx)           (compile-inner ctx (marked_val "<error with read>") true))
              ((exit_msg_val _ _ ctx)           (compile-inner ctx (marked_val "Exiting with code:") true))
              ((root_marked_env_val _ _ ctx)    (compile-inner ctx root_marked_env true))


              ((compiled_value_ptr compiled_value_code compiled_value_error ctx) (compile-inner ctx marked_code true))
              ((datasi funcs memo root_marked_env pectx) ctx)
              (_ (mif compiled_value_error (error compiled_value_error)))
              (_ (if (= nil compiled_value_ptr) (error (str "compiled top-level to code for some reason!? have code " compiled_value_code))))

              ; Ok, so the outer loop handles the IO monads
                ; ('exit        code)
                ; ('read        fd   len       <cont (data error?)>)
                ; ('write       fd   "data"    <cont (num_written error?)>)
                ; ('open        fd   path      <cont (opened_fd error?)>)
                ; Could add some to open like lookup flags, o flags, base rights
                ;                             ineriting rights, fdflags

              (start (func '$start '(local $it i64) '(local $tmp i64) '(local $ptr i32) '(local $monad_name i64) '(local $len i32) '(local $buf i32) '(local $code i32) '(local $str i64) '(local $result i64)
                    (local.set '$it (i64.const compiled_value_ptr))
                    (block '$exit_block
                        (block '$error_block
                            (_loop '$l
                                ; Not array -> out
                                (br_if '$error_block (i64.ne (i64.const #b101) (i64.and (i64.const #b101) (local.get '$it))))
                                ; less than len 2 -> out
                                (br_if '$error_block (i64.lt_u (i64.shr_u (local.get '$it) (i64.const 32)) (i64.const 2)))
                                (local.set '$ptr (i32.wrap_i64 (i64.and (local.get '$it) (i64.const -8))))
                                ; second entry isn't an int -> out
                                (br_if '$error_block (i64.ne (i64.and (i64.load 8 (local.get '$ptr)) (i64.const #b1)) (i64.const #b0)))
                                (local.set '$monad_name (i64.load (local.get '$ptr)))

                                ; ('exit        code)
                                (_if '$is_exit
                                    (i64.eq (i64.const exit_val) (local.get '$monad_name))
                                    (then
                                        ; len != 2
                                        (br_if '$error_block (i64.ne (i64.shr_u (local.get '$it) (i64.const 32)) (i64.const 2)))
                                        (call '$print (i64.const exit_msg_val))
                                        (call '$print (i64.load 8 (local.get '$ptr)))
                                        (br '$exit_block)
                                    )
                                )

                                ; if len != 4
                                (br_if '$error_block (i64.ne (i64.shr_u (local.get '$it) (i64.const 32)) (i64.const 4)))

                                ; ('read        fd   len       <cont (data error_code)>)
                                (_if '$is_read
                                    (i64.eq (i64.const read_val) (local.get '$monad_name))
                                    (then
                                        ; third entry isn't an int -> out
                                        (br_if '$error_block (i64.ne (i64.and (i64.load 16 (local.get '$ptr)) (i64.const #b1)) (i64.const #b0)))
                                        ; fourth entry isn't a comb -> out
                                        (br_if '$error_block (i64.ne (i64.and (i64.load 24 (local.get '$ptr)) (i64.const #b1111)) (i64.const #b0001)))
                                        ; iov <32bit len><32bit addr> + <32bit num written>
                                        (i32.store 0 (i32.const iov_tmp) (local.tee '$buf (call '$malloc (local.get '$len))))
                                        (i32.store 4 (i32.const iov_tmp) (local.tee '$len (i32.wrap_i64 (i64.shr_u (i64.load 16 (local.get '$ptr)) (i64.const 1)))))
                                        (local.set '$code (call '$fd_read
                                              (i32.wrap_i64 (i64.shr_u (i64.load 8 (local.get '$ptr)) (i64.const 1)))    ;; file descriptor
                                              (i32.const iov_tmp)                                                      ;; *iovs
                                              (i32.const 1)                                                            ;; iovs_len
                                              (i32.const (+ 8 iov_tmp))                                                ;; nwritten
                                        ))
                                        ;  <string_size32><string_ptr29>011
                                        (local.set '$str (i64.or (i64.shl (i64.extend_i32_u (i32.load 8 (i32.const iov_tmp))) (i64.const 32))
                                                                 (i64.extend_i32_u (i32.or (local.get '$buf) (i32.const #b011)))))
                                        (_if '$is_error
                                            (i32.eqz (local.get '$code))
                                            (then
                                                (local.set '$result (call '$array2_alloc (local.get '$str)
                                                                                         (i64.const 0)))
                                            )
                                            (else
                                                (call '$drop (local.get '$str))
                                                (local.set '$result (call '$array2_alloc (i64.const bad_read_val)
                                                                                         (i64.shl (i64.extend_i32_u (local.get '$code)) (i64.const 1))))
                                            )
                                        )

                                        (local.set '$tmp (call '$dup (i64.load 24 (local.get '$ptr))))
                                        (call '$drop (local.get '$it))
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
                                            (i64.or (i64.shl (i64.and (local.get '$tmp) (i64.const #x3FFFFFFC0)) (i64.const 2)) (i64.const #b01001))
                                            ;func_idx
                                            (i32.wrap_i64 (i64.shr_u (local.get '$tmp) (i64.const 35)))
                                        ))
                                        (br '$l)
                                    )
                                )

                                ; ('write       fd   "data"    <cont (num_written error_code)>)
                                (_if '$is_write
                                    (i64.eq (i64.const write_val) (local.get '$monad_name))
                                    (then
                                        ; third entry isn't a string -> out
                                        (br_if '$error_block (i64.ne (i64.and (i64.load 16 (local.get '$ptr)) (i64.const #b111)) (i64.const #b011)))
                                        ; fourth entry isn't a comb -> out
                                        (br_if '$error_block (i64.ne (i64.and (i64.load 24 (local.get '$ptr)) (i64.const #b1111)) (i64.const #b0001)))
                                        ;  <string_size32><string_ptr29>011
                                        (local.set '$str (i64.load 16 (local.get '$ptr)))

                                        ; iov <32bit addr><32bit len> + <32bit num written>
                                        (i32.store 0 (i32.const iov_tmp) (i32.wrap_i64 (i64.and   (local.get '$str) (i64.const #xFFFFFFF8))))
                                        (i32.store 4 (i32.const iov_tmp) (i32.wrap_i64 (i64.shr_u (local.get '$str) (i64.const 32))))
                                        (local.set '$code (call '$fd_write
                                              (i32.wrap_i64 (i64.shr_u (i64.load 8 (local.get '$ptr)) (i64.const 1)))  ;; file descriptor
                                              (i32.const iov_tmp)                                                      ;; *iovs
                                              (i32.const 1)                                                            ;; iovs_len
                                              (i32.const (+ 8 iov_tmp))                                                ;; nwritten
                                        ))
                                        (local.set '$result (call '$array2_alloc (i64.shl (i64.extend_i32_u (i32.load (i32.const (+ 8 iov_tmp)))) (i64.const 1))
                                                                                 (i64.shl (i64.extend_i32_u (local.get '$code))                   (i64.const 1))))

                                        (local.set '$tmp (call '$dup (i64.load 24 (local.get '$ptr))))
                                        (call '$drop (local.get '$it))
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
                                            (i64.or (i64.shl (i64.and (local.get '$tmp) (i64.const #x3FFFFFFC0)) (i64.const 2)) (i64.const #b01001))
                                            ;func_idx
                                            (i32.wrap_i64 (i64.shr_u (local.get '$tmp) (i64.const 35)))
                                        ))
                                        (br '$l)
                                    )
                                )
                                ; ('open        fd   path      <cont (opened_fd error?)>)
                                (_if '$is_open
                                    (i64.eq (i64.const open_val) (local.get '$monad_name))
                                    (then
                                        ; third entry isn't a string -> out
                                        (br_if '$error_block (i64.ne (i64.and (i64.load 16 (local.get '$ptr)) (i64.const #b111)) (i64.const #b011)))
                                        ; fourth entry isn't a comb -> out
                                        (br_if '$error_block (i64.ne (i64.and (i64.load 24 (local.get '$ptr)) (i64.const #b1111)) (i64.const #b0001)))
                                        ;  <string_size32><string_ptr29>011
                                        (local.set '$str (i64.load 16 (local.get '$ptr)))

                                        (local.set'$code (call '$path_open
                                            (i32.wrap_i64 (i64.shr_u (i64.load 8 (local.get '$ptr)) (i64.const 1))) ;; file descriptor
                                            (i32.const 0)                                                           ;; lookup flags
                                            (i32.wrap_i64 (i64.and   (local.get '$str) (i64.const #xFFFFFFF8)))     ;; path string  *
                                            (i32.wrap_i64 (i64.shr_u (local.get '$str) (i64.const 32)))             ;; path string  len
                                            (i32.const 1)                                                           ;; o flags
                                            (i64.const 66)                                                          ;; base rights
                                            (i64.const 66)                                                          ;; inheriting rights
                                            (i32.const 0)                                                           ;; fdflags
                                            (i32.const iov_tmp)                                                     ;; opened fd out ptr
                                        ))

                                        (local.set '$result (call '$array2_alloc (i64.shl (i64.extend_i32_u (i32.load (i32.const iov_tmp))) (i64.const 1))
                                                                                 (i64.shl (i64.extend_i32_u (local.get '$code))             (i64.const 1))))

                                        (local.set '$tmp (call '$dup (i64.load 24 (local.get '$ptr))))
                                        (call '$drop (local.get '$it))
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
                                            (i64.or (i64.shl (i64.and (local.get '$tmp) (i64.const #x3FFFFFFC0)) (i64.const 2)) (i64.const #b01001))
                                            ;func_idx
                                            (i32.wrap_i64 (i64.shr_u (local.get '$tmp) (i64.const 35)))
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
                    (call '$drop (local.get '$it))
              ))
              ((watermark datas) datasi)
          ) (concat
              (global '$data_end '(mut i32) (i32.const watermark))
              datas funcs start
              (table  '$tab (len funcs) 'funcref)
              (apply elem (cons (i32.const 0) (range dyn_start (+ num_pre_functions (len funcs)))))
          ))
          (export "memory" '(memory $mem))
          (export "_start" '(func   $start))
    )))))


    (run_partial_eval_test (lambda (s) (dlet (
                            (_ (print "\n\ngoing to partial eval " s))
                            ((pectx err result) (partial_eval (read-string s)))
                            (_ (print "result of test \"" s "\" => " (str_strip result) " and err " err))
                            (_ (print "with a hash of " (.hash result)))
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
        (print ( (dlambda ((a b)) a) '(1337 1338)))
        (print ( (dlambda ((a b)) b) '(1337 1338)))

        (print (str 1 2 3 (array 1 23 4) "a" "B"))

        (print (dlet ( (x 2) ((a b) '(1 2)) (((i i2) i3) '((5 6) 7)) ) (+  x a b i i2 i3)))

        (print (array 1 2 3))
        (print (command-line-arguments))

        (print (call-with-input-string "'(1 2)" (lambda (p) (read p))))
        (print (read (open-input-string "'(3 4)")))

        (print "mif tests")
        (print (mif true 1 2))
        (print (mif false 1 2))
        (print (mif true 1))
        (print (mif false 1))
        (print "mif tests end")

        (print "zip " (zip '(1 2 3) '(4 5 6) '(7 8 9)))

        (print (run_partial_eval_test "(+ 1 2)"))
        (print) (print)
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
                                   ))) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))"))
        (print "\n\nlambda 2\n\n")
        (print (run_partial_eval_test "((wrap (vau (let1)
                                   (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
                                   (let1 a 12
                                         (lambda (x) (+ a x)))
                                   ))) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))"))
        (print "\n\nlambda 3\n\n")
        (print (run_partial_eval_test "((wrap (vau (let1)
                                   (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
                                   (let1 a 12
                                         (lambda (x) (let1 b (+ a x)
                                                             (+ a x b))))
                                   ))) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))"))

        (print (run_partial_eval_test "(array 1 2 3 4 5)"))
        (print (run_partial_eval_test "((wrap (vau (a & rest) rest)) 1 2 3 4 5)"))

        (print "\n\nrecursion test\n\n")
        (print (run_partial_eval_test "((wrap (vau (let1)
                                   (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
                                   ((lambda (x n) (x x n)) (lambda (recurse n) (cond (!= 0 n) (* n (recurse recurse (- n 1)))
                                                                                     true     1                               )) 5)
                                   ))) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))"))

        (print "\n\nlambda recursion test\n\n")
        (print (run_partial_eval_test "((wrap (vau (let1)
                                   (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
                                   (lambda (n) ((lambda (x n) (x x n)) (lambda (recurse n) (cond (!= 0 n) (* n (recurse recurse (- n 1)))
                                                                                     true     1                               )) n))
                                   ))) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))"))
        (print "ok, hex of 0 is " (hex_digit #\0))
        (print "ok, hex of 1 is " (hex_digit #\1))
        (print "ok, hex of a is " (hex_digit #\a))
        (print "ok, hex of A is " (hex_digit #\A))
        (print "ok, hexify of 1337 is " (i64_le_hexify 1337))
        (print "ok, hexify of 10 is " (i64_le_hexify 10))
        (print "ok, hexify of 15 is " (i64_le_hexify 15))
        (print "ok, hexfy of 15 << 60 is " (i64_le_hexify (<< 15 60)))
        (let* (
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
            (output3 (compile (partial_eval (read-string "(array 1 (array ((vau (x) x) a) (array \"asdf\"))  2)"))))
            (output3 (compile (partial_eval (read-string "(array 1 (array 1 2 3 4) 2 (array 1 2 3 4))"))))
            (output3 (compile (partial_eval (read-string "empty_env"))))
            (output3 (compile (partial_eval (read-string "(eval (array (array vau ((vau (x) x) (a b)) (array (array vau ((vau (x) x) x) (array) ((vau (x) x) x)))) 1 2) empty_env)"))))
            (output3 (compile (partial_eval (read-string "(eval (array (array vau ((vau (x) x) (a b)) (array (array vau ((vau (x) x) x) (array) ((vau (x) x) x)))) empty_env 2) empty_env)"))))
            (output3 (compile (partial_eval (read-string "(eval (array (array vau ((vau (x) x) x) (array) ((vau (x) x) x))))"))))
            (output3 (compile (partial_eval (read-string "(vau (x) x)"))))
            (output3 (compile (partial_eval (read-string "(vau (x) 1)"))))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) exit) 1)"))))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (array ((vau (x) x) exit) 1)))"))))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (array ((vau (x) x) exit) written)))"))))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) written))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) code))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (array 1337 written 1338 code 1339)))"))))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (cond (= 0 code) written true code)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (str (= 0 code) written true (array) code)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (log (= 0 code) written true (array) code)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (error (= 0 code) written true code)))"))))
            ;(output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (or (= 0 code) written true code)))"))))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (+ written code 1337)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (- written code 1337)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (* written 1337)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (/ 1337 written)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (% 1337 written)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (band 1337 written)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (bor 1337 written)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (bnot written)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (bxor 1337 written)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (<< 1337 written)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (>> 1337 written)))"))))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (<= (array written) (array 1337))))"))))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (read-string (cond written \"true\" true 3))))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (read-string (cond written \"     true\" true 3))))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (read-string (cond written \"     true   \" true 3))))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (read-string (cond written \"     false\" true 3))))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (read-string (cond written \"(false (true () true) true)\" true 3))))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (read-string (cond written \"(false (true () true) true) true\" true 3))))"))))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) open) 3 \"test_out\" (vau (fd code) (array ((vau (x) x) write) fd \"waa\" (vau (written code) (array written code)))))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) open) 3 \"test_out\" (vau (fd code) (array ((vau (x) x) read) fd 10 (vau (data code) (array data code)))))"))))

            ;(_ (print (slurp "test_parse_in")))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) open) 3 \"test_parse_in\" (vau (fd code) (array ((vau (x) x) read) fd 1000 (vau (data code) (read-string data)))))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"test_parse_in\" (vau (written code) (array (array written))))"))))


            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (slice args 1 -1)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (len args)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (idx args 0)))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (slice (concat args (array 1 2 3 4) args) 1 -2)))"))))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (str-to-symbol (str args))))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (get-text (str-to-symbol (str args)))))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (wrap (cond args idx true 0))))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (wrap (wrap (cond args idx true 0)))))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (wrap (wrap (wrap (cond args idx true 0))))))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (unwrap (cond args idx true 0))))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) (unwrap (cond args vau true 0))))"))))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (written code) (array (nil? written) (array? written) (bool? written) (env? written) (combiner? written) (string? written) (int? written) (symbol? written))))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau de (written code) (array (nil? (cond written (array) true 4)) (array? (cond written (array 1 2) true 4)) (bool? (= 3 written)) (env? de) (combiner? (cond written (vau () 1) true 43)) (string? (cond written \"a\" 3 3)) (int? (cond written \"a\" 3 3)) (symbol? (cond written ((vau (x) x) x) 3 3)) written)))"))))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (& args) args))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (a & args) a))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"waa\" (vau (a & args) args))"))))

            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) read) 0 10 (vau (data code) data))"))))
            (output3 (compile (partial_eval (read-string "(array ((vau (x) x) read) 0 10 (vau (data code) (array ((vau (x) x) write) 1 data (vau (written code) (array written code)))))"))))

            (output3 (compile (partial_eval (read-string "(wrap (vau (x) x))"))))
            (output3 (compile (partial_eval (read-string "len"))))
            (output3 (compile (partial_eval (read-string "vau"))))
            (output3 (compile (partial_eval (read-string "(array len 3 len)"))))
            (output3 (compile (partial_eval (read-string "(+ 1 1337 (+ 1 2))"))))
            (output3 (compile (partial_eval (read-string "\"hello world\""))))
            (output3 (compile (partial_eval (read-string "((vau (x) x) asdf)"))))
            (output3 (compile (partial_eval (read-string "((wrap (vau (let1)
                                   (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
                                   (array ((vau (x) x) write) 1 \"hahah\" (vau (written code) ((lambda (x n) (x x n)) (lambda (recurse n) (cond (!= 0 n) (* n (recurse recurse (- n 1)))
                                                                                     true     1                               )) written)))
                                   ))) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))"))))
            (_ (write_file "./csc_out.wasm" output3))
        ) (void))
    )))

    (single-test (lambda () (dlet (
        ;(output3 (compile (partial_eval (read-string "1337"))))
        ;(output3 (compile (partial_eval (read-string "\"This is a longish sring to make sure alloc data is working properly\""))))
        ;(output3 (compile (partial_eval (read-string "((vau (x) x) write)"))))
        ;(output3 (compile (partial_eval (read-string "(wrap (vau (x) x))"))))
        ;(output3 (compile (partial_eval (read-string "(wrap (vau (x) (log 1337)))"))))
        ;(output3 (compile (partial_eval (read-string "(wrap (vau (x) (+ x 1337)))"))))
        ;(output3 (compile (partial_eval (read-string "(array ((vau (x) x) write) 1 \"w\" (vau (written code) (+ written code 1337)))"))))
        ;(output3 (compile (partial_eval (read-string "((wrap (vau (let1)
        ;                       (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
        ;                       (array ((vau (x) x) write) 1 \"hahah\" (vau (written code) ((lambda (x n) (x x n)) (lambda (recurse n) (cond (!= 0 n) (* n (recurse recurse (- n 1)))
        ;                                                                                                                                    true     1)) written)))
        ;                       ))) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))"))))


        (output3 (compile (partial_eval (read-string
                                   "((wrap (vau root_env (quote)
                                    ((wrap (vau (let1)

                                    (let1 lambda (vau se (p b) (wrap (eval (array vau p b) se)))
                                    (let1 current-env (vau de () de)
                                    (let1 lapply (lambda (f p)     (eval (concat (array (unwrap f)) p) (current-env)))
                                    (array (quote write) 1 \"test_self_out2\" (vau (written code) 1))
                                    )))

                                    )) (vau de (s v b) (eval (array (array vau (array s) b) (eval v de)) de)))
                                    )) (vau (x5) x5))"))))
        (_ (write_file "./csc_out.wasm" output3))
    ) void)))

    (run-compiler (lambda ()
        (write_file "./csc_out.wasm" (compile (partial_eval (read-string (slurp "to_compile.kp")))))
    ))

;) (test-most))
) (run-compiler))
;) (single-test))
)

;;;;;;;;;;;;;;
; Known TODOs
;;;;;;;;;;;;;;
;
; * ARRAY FUNCTIONS FOR STRINGS, in both PARTIAL_EVAL *AND* COMPILED
; * Finish supporting calling vaus in compiled code
; * NON NAIVE REFCOUNTING
; * Of course, memoizing partial_eval
;
;
; EVENTUALLY: Support some hard core partial_eval that an fully make (foldl or stuff) short circut effeciencly with double-inlining, finally
;   addressing the strict-languages-don't-compose thing
;
; If function result has a closed over symbol, but also we have a real env it would resolve too, that should be fine
;   Not sure if this is a mod to the function call or the close over
;
