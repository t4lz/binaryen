;; NOTE: Assertions have been generated by update_lit_checks.py --all-items and should not be edited.
;; RUN: foreach %s %t wasm-opt --nominal --remove-unused-names --cfp -all -S -o - | filecheck %s
;; (remove-unused-names is added to test fallthrough values without a block
;; name getting in the way)

;; This file contains tests for ConstantFieldPropagation when it uses local
;; information in order to optimize struct.gets to constant values.

(module
  ;; CHECK:      (type $struct.A (struct (field (ref $table.A))))
  (type $struct.A (struct (ref $table.A)))
  ;; CHECK:      (type $table.B (struct (field (ref $B)) (field f64)) (extends $table.A))

  ;; CHECK:      (type $table.A (struct (field (ref $A))))
  (type $table.A (struct (ref $A)))
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (type $B (struct (field i32) (field i64)) (extends $A))

  ;; CHECK:      (type $struct.B (struct (field (ref $table.B)) (field f32)) (extends $struct.A))

  ;; CHECK:      (type $A (struct (field i32)))
  (type $A (struct i32))

  (type $struct.B (struct (field (ref $table.B)) (field f32)) (extends $struct.A))
  (type $table.B (struct (ref $B) f64) (extends $table.A))
  (type $B (struct i32 i64) (extends $A))

  ;; CHECK:      (func $test
  ;; CHECK-NEXT:  (local $a (ref null $struct.A))
  ;; CHECK-NEXT:  (local.set $a
  ;; CHECK-NEXT:   (struct.new_with_rtt $struct.B
  ;; CHECK-NEXT:    (struct.new_with_rtt $table.B
  ;; CHECK-NEXT:     (struct.new_with_rtt $B
  ;; CHECK-NEXT:      (i32.const 1)
  ;; CHECK-NEXT:      (i64.const 2)
  ;; CHECK-NEXT:      (rtt.canon $B)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (f64.const 2.71828)
  ;; CHECK-NEXT:     (rtt.canon $table.B)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (f32.const 3.141590118408203)
  ;; CHECK-NEXT:    (rtt.canon $struct.B)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result i32)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.as_non_null
  ;; CHECK-NEXT:      (struct.get $table.A 0
  ;; CHECK-NEXT:       (struct.get $struct.A 0
  ;; CHECK-NEXT:        (local.get $a)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $test
    (local $a (ref null $struct.A))
    ;; Create a struct.B, but store it to a local of the parent type.
    (local.set $a
      (struct.new_with_rtt $struct.B
        (struct.new_with_rtt $table.B
          (struct.new_with_rtt $B
            (i32.const 1) ;; This value should appear instead of the get.
            (i64.const 2)
            (rtt.canon $B)
          )
          (f64.const 2.71828)
          (rtt.canon $table.B)
        )
        (f32.const 3.14159)
        (rtt.canon $struct.B)
      )
    )
    (drop
      ;; While we get using the type struct.A, the local's actual value is a
      ;; reference to a struct.B, which we can infer, and so forth down the
      ;; chain til we can get a constant value at the end, as the type B always
      ;; has the same constant (1) written to it in the whole program.
      (struct.get $A 0
        (struct.get $table.A 0
          (struct.get $struct.A 0
            (local.get $a)
          )
        )
      )
    )
  )

  ;; CHECK:      (func $support
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $struct.A
  ;; CHECK-NEXT:    (ref.as_non_null
  ;; CHECK-NEXT:     (ref.null $table.A)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (rtt.canon $struct.A)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $struct.B
  ;; CHECK-NEXT:    (ref.as_non_null
  ;; CHECK-NEXT:     (ref.null $table.B)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (f32.const 100)
  ;; CHECK-NEXT:    (rtt.canon $struct.B)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $support
    ;; Create instances of all the structs here, so that the problem is not
    ;; trivial enough to solve without local information in $test
    (drop
      (struct.new_with_rtt $struct.A
        (ref.as_non_null (ref.null $table.A))
        (rtt.canon $struct.A)
      )
      (struct.new_with_rtt $table.A
        (ref.as_non_null (ref.null $A))
        (rtt.canon $table.A)
      )
      (struct.new_with_rtt $A
        (i32.const 300)
        (rtt.canon $A)
      )
    )
    (drop
      (struct.new_with_rtt $struct.B
        (ref.as_non_null (ref.null $table.B))
        (f32.const 100)
        (rtt.canon $struct.B)
      )
      (struct.new_with_rtt $table.B
        (ref.as_non_null (ref.null $B))
        (f64.const 200)
        (rtt.canon $table.B)
      )
      (struct.new_with_rtt $B
        (i32.const 1) ;; This is the same as earlier, see previous comment.
        (i64.const 400)
        (rtt.canon $B)
      )
    )
  )
)

;; As above, but $B does *not* have the same constant written to it everywhere.
;; We must use local information for the field value as well.
(module
  ;; CHECK:      (type $struct.A (struct (field (ref $table.A))))
  (type $struct.A (struct (ref $table.A)))
  ;; CHECK:      (type $table.B (struct (field (ref $B)) (field f64)) (extends $table.A))

  ;; CHECK:      (type $table.A (struct (field (ref $A))))
  (type $table.A (struct (ref $A)))
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (type $B (struct (field i32) (field i64)) (extends $A))

  ;; CHECK:      (type $struct.B (struct (field (ref $table.B)) (field f32)) (extends $struct.A))

  ;; CHECK:      (type $A (struct (field i32)))
  (type $A (struct i32))

  (type $struct.B (struct (field (ref $table.B)) (field f32)) (extends $struct.A))
  (type $table.B (struct (ref $B) f64) (extends $table.A))
  (type $B (struct i32 i64) (extends $A))

  ;; CHECK:      (func $test
  ;; CHECK-NEXT:  (local $a (ref null $struct.A))
  ;; CHECK-NEXT:  (local.set $a
  ;; CHECK-NEXT:   (struct.new_with_rtt $struct.B
  ;; CHECK-NEXT:    (struct.new_with_rtt $table.B
  ;; CHECK-NEXT:     (struct.new_with_rtt $B
  ;; CHECK-NEXT:      (i32.const 2)
  ;; CHECK-NEXT:      (i64.const 3)
  ;; CHECK-NEXT:      (rtt.canon $B)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (f64.const 2.71828)
  ;; CHECK-NEXT:     (rtt.canon $table.B)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (f32.const 3.141590118408203)
  ;; CHECK-NEXT:    (rtt.canon $struct.B)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result i32)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.as_non_null
  ;; CHECK-NEXT:      (struct.get $table.A 0
  ;; CHECK-NEXT:       (struct.get $struct.A 0
  ;; CHECK-NEXT:        (local.get $a)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (i32.const 2)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $test
    (local $a (ref null $struct.A))
    (local.set $a
      (struct.new_with_rtt $struct.B
        (struct.new_with_rtt $table.B
          (struct.new_with_rtt $B
            (i32.const 2) ;; This value should appear instead of the get.
            (i64.const 3)
            (rtt.canon $B)
          )
          (f64.const 2.71828)
          (rtt.canon $table.B)
        )
        (f32.const 3.14159)
        (rtt.canon $struct.B)
      )
    )
    (drop
      (struct.get $A 0
        (struct.get $table.A 0
          (struct.get $struct.A 0
            (local.get $a)
          )
        )
      )
    )
  )

  ;; CHECK:      (func $support
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $struct.A
  ;; CHECK-NEXT:    (ref.as_non_null
  ;; CHECK-NEXT:     (ref.null $table.A)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (rtt.canon $struct.A)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $struct.B
  ;; CHECK-NEXT:    (ref.as_non_null
  ;; CHECK-NEXT:     (ref.null $table.B)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (f32.const 100)
  ;; CHECK-NEXT:    (rtt.canon $struct.B)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $support
    (drop
      (struct.new_with_rtt $struct.A
        (ref.as_non_null (ref.null $table.A))
        (rtt.canon $struct.A)
      )
      (struct.new_with_rtt $table.A
        (ref.as_non_null (ref.null $A))
        (rtt.canon $table.A)
      )
      (struct.new_with_rtt $A
        (i32.const 300)
        (rtt.canon $A)
      )
    )
    (drop
      (struct.new_with_rtt $struct.B
        (ref.as_non_null (ref.null $table.B))
        (f32.const 100)
        (rtt.canon $struct.B)
      )
      (struct.new_with_rtt $table.B
        (ref.as_non_null (ref.null $B))
        (f64.const 200)
        (rtt.canon $table.B)
      )
      (struct.new_with_rtt $B
        (i32.const 3) ;; This is different from earlier.
        (i64.const 400)
        (rtt.canon $B)
      )
    )
  )
)

;; The struct.new is right on top of the struct.get.
(module
  ;; CHECK:      (type $table.B (struct (field i32) (field f64)) (extends $table.A))

  ;; CHECK:      (type $struct.B (struct (field (ref $table.B)) (field f32)) (extends $struct.A))

  ;; CHECK:      (type $table.A (struct (field i32)))

  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (type $struct.A (struct (field (ref $table.A))))
  (type $struct.A (struct (ref $table.A)))
  (type $table.A (struct i32))

  (type $struct.B (struct (ref $table.B) f32) (extends $struct.A))
  (type $table.B (struct i32 f64) (extends $table.A))

  ;; CHECK:      (func $test
  ;; CHECK-NEXT:  (local $a (ref null $struct.A))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result i32)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.as_non_null
  ;; CHECK-NEXT:      (struct.get $struct.B 0
  ;; CHECK-NEXT:       (struct.new_with_rtt $struct.B
  ;; CHECK-NEXT:        (struct.new_with_rtt $table.B
  ;; CHECK-NEXT:         (i32.const 1)
  ;; CHECK-NEXT:         (f64.const 2.71828)
  ;; CHECK-NEXT:         (rtt.canon $table.B)
  ;; CHECK-NEXT:        )
  ;; CHECK-NEXT:        (f32.const 3.141590118408203)
  ;; CHECK-NEXT:        (rtt.canon $struct.B)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $test
    (local $a (ref null $struct.A))
    ;; Create struct.B and store it to struct.A.
    (drop
      (struct.get $table.A 0
        (struct.get $struct.A 0
          (struct.new_with_rtt $struct.B
            (struct.new_with_rtt $table.B
              (i32.const 1) ;; This value should appear instead of the get.
              (f64.const 2.71828)
              (rtt.canon $table.B)
            )
            (f32.const 3.14159)
            (rtt.canon $struct.B)
          )
        )
      )
    )
  )

  ;; CHECK:      (func $support
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $struct.A
  ;; CHECK-NEXT:    (ref.as_non_null
  ;; CHECK-NEXT:     (ref.null $table.A)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (rtt.canon $struct.A)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $table.A
  ;; CHECK-NEXT:    (i32.const 300)
  ;; CHECK-NEXT:    (rtt.canon $table.A)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $struct.B
  ;; CHECK-NEXT:    (ref.as_non_null
  ;; CHECK-NEXT:     (ref.null $table.B)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (f32.const 100)
  ;; CHECK-NEXT:    (rtt.canon $struct.B)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $table.B
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:    (f64.const 400)
  ;; CHECK-NEXT:    (rtt.canon $table.B)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $support
    (drop
      (struct.new_with_rtt $struct.A
        (ref.as_non_null (ref.null $table.A))
        (rtt.canon $struct.A)
      )
    )
    (drop
      (struct.new_with_rtt $table.A
        (i32.const 300)
        (rtt.canon $table.A)
      )
    )
    (drop
      (struct.new_with_rtt $struct.B
        (ref.as_non_null (ref.null $table.B))
        (f32.const 100)
        (rtt.canon $struct.B)
      )
    )
    (drop
      (struct.new_with_rtt $table.B
        (i32.const 1) ;; This is the same as earlier.
        (f64.const 400)
        (rtt.canon $table.B)
      )
    )
  )
)

;; As before, but use a tee and have multiple gets.
(module
  ;; CHECK:      (type $struct.A (struct (field (ref $table.A))))
  (type $struct.A (struct (ref $table.A)))
  ;; CHECK:      (type $table.B (struct (field i32) (field f64)) (extends $table.A))

  ;; CHECK:      (type $table.A (struct (field i32)))
  (type $table.A (struct i32))

  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (type $struct.B (struct (field (ref $table.B)) (field f32)) (extends $struct.A))
  (type $struct.B (struct (ref $table.B) f32) (extends $struct.A))
  (type $table.B (struct i32 f64) (extends $table.A))

  ;; CHECK:      (func $test
  ;; CHECK-NEXT:  (local $a (ref null $struct.A))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result i32)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.as_non_null
  ;; CHECK-NEXT:      (struct.get $struct.A 0
  ;; CHECK-NEXT:       (local.tee $a
  ;; CHECK-NEXT:        (struct.new_with_rtt $struct.B
  ;; CHECK-NEXT:         (struct.new_with_rtt $table.B
  ;; CHECK-NEXT:          (i32.const 1)
  ;; CHECK-NEXT:          (f64.const 2.71828)
  ;; CHECK-NEXT:          (rtt.canon $table.B)
  ;; CHECK-NEXT:         )
  ;; CHECK-NEXT:         (f32.const 3.141590118408203)
  ;; CHECK-NEXT:         (rtt.canon $struct.B)
  ;; CHECK-NEXT:        )
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result i32)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.as_non_null
  ;; CHECK-NEXT:      (struct.get $struct.A 0
  ;; CHECK-NEXT:       (local.get $a)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result i32)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.as_non_null
  ;; CHECK-NEXT:      (struct.get $struct.A 0
  ;; CHECK-NEXT:       (local.get $a)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $test
    (local $a (ref null $struct.A))
    ;; Create struct.B and store it to struct.A.
    (drop
      (struct.get $table.A 0
        (struct.get $struct.A 0
          ;; Use a tee for the first use.
          (local.tee $a
            (struct.new_with_rtt $struct.B
              (struct.new_with_rtt $table.B
                (i32.const 1) ;; This value should appear instead of the get.
                (f64.const 2.71828)
                (rtt.canon $table.B)
              )
              (f32.const 3.14159)
              (rtt.canon $struct.B)
            )
          )
        )
      )
    )
    ;; Add a more uses.
    (drop
      (struct.get $table.A 0
        (struct.get $struct.A 0
          (local.get $a)
        )
      )
    )
    (drop
      (struct.get $table.A 0
        (struct.get $struct.A 0
          (local.get $a)
        )
      )
    )
  )

  ;; CHECK:      (func $support
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $struct.A
  ;; CHECK-NEXT:    (ref.as_non_null
  ;; CHECK-NEXT:     (ref.null $table.A)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (rtt.canon $struct.A)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $table.A
  ;; CHECK-NEXT:    (i32.const 300)
  ;; CHECK-NEXT:    (rtt.canon $table.A)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $struct.B
  ;; CHECK-NEXT:    (ref.as_non_null
  ;; CHECK-NEXT:     (ref.null $table.B)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (f32.const 100)
  ;; CHECK-NEXT:    (rtt.canon $struct.B)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $table.B
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:    (f64.const 400)
  ;; CHECK-NEXT:    (rtt.canon $table.B)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $support
    (drop
      (struct.new_with_rtt $struct.A
        (ref.as_non_null (ref.null $table.A))
        (rtt.canon $struct.A)
      )
    )
    (drop
      (struct.new_with_rtt $table.A
        (i32.const 300)
        (rtt.canon $table.A)
      )
    )
    (drop
      (struct.new_with_rtt $struct.B
        (ref.as_non_null (ref.null $table.B))
        (f32.const 100)
        (rtt.canon $struct.B)
      )
    )
    (drop
      (struct.new_with_rtt $table.B
        (i32.const 1) ;; This is the same as earlier.
        (f64.const 400)
        (rtt.canon $table.B)
      )
    )
  )
)

;; More than one set prevents us from optimizing.
(module
  ;; CHECK:      (type $table.B (struct (field i32) (field f64)) (extends $table.A))

  ;; CHECK:      (type $table.A (struct (field i32)))

  ;; CHECK:      (type $struct.A (struct (field (ref $table.A))))
  (type $struct.A (struct (ref $table.A)))
  (type $table.A (struct i32))

  ;; CHECK:      (type $struct.B (struct (field (ref $table.B)) (field f32)) (extends $struct.A))
  (type $struct.B (struct (ref $table.B) f32) (extends $struct.A))
  (type $table.B (struct i32 f64) (extends $table.A))

  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (func $test
  ;; CHECK-NEXT:  (local $a (ref null $struct.A))
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:   (local.set $a
  ;; CHECK-NEXT:    (struct.new_with_rtt $struct.B
  ;; CHECK-NEXT:     (struct.new_with_rtt $table.B
  ;; CHECK-NEXT:      (i32.const 1)
  ;; CHECK-NEXT:      (f64.const 2.71828)
  ;; CHECK-NEXT:      (rtt.canon $table.B)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (f32.const 3.141590118408203)
  ;; CHECK-NEXT:     (rtt.canon $struct.B)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (local.set $a
  ;; CHECK-NEXT:    (struct.new_with_rtt $struct.B
  ;; CHECK-NEXT:     (struct.new_with_rtt $table.B
  ;; CHECK-NEXT:      (i32.const 1)
  ;; CHECK-NEXT:      (f64.const 2.71828)
  ;; CHECK-NEXT:      (rtt.canon $table.B)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (f32.const 3.141590118408203)
  ;; CHECK-NEXT:     (rtt.canon $struct.B)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.get $table.A 0
  ;; CHECK-NEXT:    (struct.get $struct.A 0
  ;; CHECK-NEXT:     (local.get $a)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $test
    (local $a (ref null $struct.A))
    ;; While we assign 1 in both arms to field 0, the presence of two sets
    ;; prevents any optimization - we just look for a singleton atm.
    (if
      (i32.const 1)
      (local.set $a
        (struct.new_with_rtt $struct.B
          (struct.new_with_rtt $table.B
            (i32.const 1)
            (f64.const 2.71828)
            (rtt.canon $table.B)
          )
          (f32.const 3.14159)
          (rtt.canon $struct.B)
        )
      )
      (local.set $a
        (struct.new_with_rtt $struct.B
          (struct.new_with_rtt $table.B
            (i32.const 1)
            (f64.const 2.71828)
            (rtt.canon $table.B)
          )
          (f32.const 3.14159)
          (rtt.canon $struct.B)
        )
      )
    )
    (drop
      (struct.get $table.A 0
        (struct.get $struct.A 0
          (local.get $a)
        )
      )
    )
  )

  ;; CHECK:      (func $support
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $struct.A
  ;; CHECK-NEXT:    (ref.as_non_null
  ;; CHECK-NEXT:     (ref.null $table.A)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (rtt.canon $struct.A)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $table.A
  ;; CHECK-NEXT:    (i32.const 300)
  ;; CHECK-NEXT:    (rtt.canon $table.A)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $struct.B
  ;; CHECK-NEXT:    (ref.as_non_null
  ;; CHECK-NEXT:     (ref.null $table.B)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (f32.const 100)
  ;; CHECK-NEXT:    (rtt.canon $struct.B)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_with_rtt $table.B
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:    (f64.const 400)
  ;; CHECK-NEXT:    (rtt.canon $table.B)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $support
    (drop
      (struct.new_with_rtt $struct.A
        (ref.as_non_null (ref.null $table.A))
        (rtt.canon $struct.A)
      )
    )
    (drop
      (struct.new_with_rtt $table.A
        (i32.const 300)
        (rtt.canon $table.A)
      )
    )
    (drop
      (struct.new_with_rtt $struct.B
        (ref.as_non_null (ref.null $table.B))
        (f32.const 100)
        (rtt.canon $struct.B)
      )
    )
    (drop
      (struct.new_with_rtt $table.B
        (i32.const 1) ;; This is the same as earlier.
        (f64.const 400)
        (rtt.canon $table.B)
      )
    )
  )
)

;; No set at all should not make us crash or misoptimize.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (type $struct.A (struct (field (ref $table.A))))
  (type $struct.A (struct (ref $table.A)))
  ;; CHECK:      (type $table.A (struct (field i32)))
  (type $table.A (struct i32))

  (type $struct.B (struct (ref $table.B) f32) (extends $struct.A))
  (type $table.B (struct i32 f64) (extends $table.A))

  ;; CHECK:      (func $test
  ;; CHECK-NEXT:  (local $a (ref null $struct.A))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block ;; (replaces something unreachable we can't emit)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (block
  ;; CHECK-NEXT:      (drop
  ;; CHECK-NEXT:       (local.get $a)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (unreachable)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $test
    (local $a (ref null $struct.A))
    (drop
      ;; This get uses the default value of the set.
      (struct.get $table.A 0
        (struct.get $struct.A 0
          (local.get $a)
        )
      )
    )
  )
)

;; An unreachable set should not make us crash or misoptimize.
(module
  ;; CHECK:      (type $table.B (struct (field i32) (field f64)) (extends $table.A))

  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (type $struct.A (struct (field (ref $table.A))))
  (type $struct.A (struct (ref $table.A)))
  ;; CHECK:      (type $struct.B (struct (field (ref $table.B)) (field f32)) (extends $struct.A))

  ;; CHECK:      (type $table.A (struct (field i32)))
  (type $table.A (struct i32))

  (type $struct.B (struct (ref $table.B) f32) (extends $struct.A))
  (type $table.B (struct i32 f64) (extends $table.A))

  ;; CHECK:      (func $test
  ;; CHECK-NEXT:  (local $a (ref null $struct.A))
  ;; CHECK-NEXT:  (local.tee $a
  ;; CHECK-NEXT:   (struct.new_with_rtt $struct.B
  ;; CHECK-NEXT:    (struct.new_with_rtt $table.B
  ;; CHECK-NEXT:     (unreachable)
  ;; CHECK-NEXT:     (unreachable)
  ;; CHECK-NEXT:     (rtt.canon $table.B)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:    (rtt.canon $struct.B)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block ;; (replaces something unreachable we can't emit)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (block
  ;; CHECK-NEXT:      (drop
  ;; CHECK-NEXT:       (local.get $a)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (unreachable)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $test
    (local $a (ref null $struct.A))
    (local.set $a
      (struct.new_with_rtt $struct.B
        (struct.new_with_rtt $table.B
          (unreachable)
          (unreachable)
          (rtt.canon $table.B)
        )
        (unreachable)
        (rtt.canon $struct.B)
      )
    )
    (drop
      (struct.get $table.A 0
        (struct.get $struct.A 0
          (local.get $a)
        )
      )
    )
  )
)

;; A "realistic" test with a proper vtable, method calls with |this| params,
;; etc.
(module
  ;; A function type that receives |this| and returns an i32.
  ;; CHECK:      (type $func (func (param anyref) (result i32)))
  (type $func (func (param anyref) (result i32)))

  ;; A parent struct type, with a vtable.
  ;; CHECK:      (type $parent (struct (field (ref $parent.vtable))))
  (type $parent (struct (field (ref $parent.vtable))))
  ;; CHECK:      (type $parent.vtable (struct (field (ref $func))))
  (type $parent.vtable (struct (field (ref $func))))

  ;; A child struct type that extends the parent. It adds a field to both the
  ;; struct and its vtable.
  ;; CHECK:      (type $child.vtable (struct (field (ref $func)) (field (ref $func))) (extends $parent.vtable))

  ;; CHECK:      (type $none_=>_anyref (func (result anyref)))

  ;; CHECK:      (type $child (struct (field (ref $child.vtable)) (field i32)) (extends $parent))
  (type $child (struct (field (ref $child.vtable)) (field i32)) (extends $parent))
  (type $child.vtable (struct (field (ref $func)) (field (ref $func)))  (extends $parent.vtable))

  ;; Keep a creation of the parent alive, so that we do not end up with no
  ;; creations and a simpler problem to solve.
  ;; CHECK:      (type $none_=>_i32 (func (result i32)))

  ;; CHECK:      (elem declare func $child.func $parent.func)

  ;; CHECK:      (export "keepalive-parent" (func $keepalive-parent))

  ;; CHECK:      (export "keepalive-child" (func $keepalive-child))

  ;; CHECK:      (export "parent" (func $create-parent-call-parent))

  ;; CHECK:      (export "child" (func $create-child-call-parent))

  ;; CHECK:      (func $keepalive-parent (result anyref)
  ;; CHECK-NEXT:  (struct.new_with_rtt $parent
  ;; CHECK-NEXT:   (struct.new_with_rtt $parent.vtable
  ;; CHECK-NEXT:    (ref.func $parent.func)
  ;; CHECK-NEXT:    (rtt.canon $parent.vtable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (rtt.canon $parent)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $keepalive-parent (export "keepalive-parent") (result anyref)
    (struct.new_with_rtt $parent
      (struct.new_with_rtt $parent.vtable
        (ref.func $parent.func)
        (rtt.canon $parent.vtable)
      )
      (rtt.canon $parent)
    )
  )

  ;; Same as above, but for the child.
  ;; CHECK:      (func $keepalive-child (result anyref)
  ;; CHECK-NEXT:  (struct.new_with_rtt $child
  ;; CHECK-NEXT:   (struct.new_with_rtt $child.vtable
  ;; CHECK-NEXT:    (ref.func $child.func)
  ;; CHECK-NEXT:    (ref.func $child.func)
  ;; CHECK-NEXT:    (rtt.canon $child.vtable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (i32.const 9999)
  ;; CHECK-NEXT:   (rtt.canon $child)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $keepalive-child (export "keepalive-child") (result anyref)
    (struct.new_with_rtt $child
      (struct.new_with_rtt $child.vtable
        (ref.func $child.func)
        (ref.func $child.func)
        (rtt.canon $child.vtable)
      )
      (i32.const 9999)
      (rtt.canon $child)
    )
  )

  ;; CHECK:      (func $parent.func (param $this anyref) (result i32)
  ;; CHECK-NEXT:  (i32.const 128)
  ;; CHECK-NEXT: )
  (func $parent.func (param $this anyref) (result i32)
    (i32.const 128)
  )

  ;; CHECK:      (func $child.func (param $this anyref) (result i32)
  ;; CHECK-NEXT:  (i32.const 4096)
  ;; CHECK-NEXT: )
  (func $child.func (param $this anyref) (result i32)
    (i32.const 4096)
  )

  ;; CHECK:      (func $create-parent-call-parent (result i32)
  ;; CHECK-NEXT:  (local $x (ref null $parent))
  ;; CHECK-NEXT:  (local.set $x
  ;; CHECK-NEXT:   (struct.new_with_rtt $parent
  ;; CHECK-NEXT:    (struct.new_with_rtt $parent.vtable
  ;; CHECK-NEXT:     (ref.func $parent.func)
  ;; CHECK-NEXT:     (rtt.canon $parent.vtable)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (rtt.canon $parent)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (i32.add
  ;; CHECK-NEXT:   (call_ref
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:    (block (result (ref $func))
  ;; CHECK-NEXT:     (drop
  ;; CHECK-NEXT:      (ref.as_non_null
  ;; CHECK-NEXT:       (struct.get $parent 0
  ;; CHECK-NEXT:        (local.get $x)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (ref.func $parent.func)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (call_ref
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:    (block (result (ref $func))
  ;; CHECK-NEXT:     (drop
  ;; CHECK-NEXT:      (ref.as_non_null
  ;; CHECK-NEXT:       (struct.get $parent 0
  ;; CHECK-NEXT:        (local.get $x)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (ref.func $parent.func)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $create-parent-call-parent (export "parent") (result i32)
    (local $x (ref null $parent))

    ;; Create a parent.
    (local.set $x
      (struct.new_with_rtt $parent
        (struct.new_with_rtt $parent.vtable
          (ref.func $parent.func)
          (rtt.canon $parent.vtable)
        )
        (rtt.canon $parent)
      )
    )

    ;; Call it a few times. We should be able to infer that the local contains
    ;; exactly a parent instance and not its subtype, and so we can replace the
    ;; struct.get with parent.func.
    (i32.add
      (call_ref
        (local.get $x)
        (struct.get $parent.vtable 0
          (struct.get $parent 0
            (local.get $x)
          )
        )
      )
      (call_ref
        (local.get $x)
        (struct.get $parent.vtable 0
          (struct.get $parent 0
            (local.get $x)
          )
        )
      )
    )
  )

  ;; CHECK:      (func $create-child-call-parent (result i32)
  ;; CHECK-NEXT:  (local $x (ref null $parent))
  ;; CHECK-NEXT:  (local.set $x
  ;; CHECK-NEXT:   (struct.new_with_rtt $child
  ;; CHECK-NEXT:    (struct.new_with_rtt $child.vtable
  ;; CHECK-NEXT:     (ref.func $child.func)
  ;; CHECK-NEXT:     (ref.func $child.func)
  ;; CHECK-NEXT:     (rtt.canon $child.vtable)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (i32.const 42)
  ;; CHECK-NEXT:    (rtt.canon $child)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (i32.add
  ;; CHECK-NEXT:   (call_ref
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:    (block (result (ref $func))
  ;; CHECK-NEXT:     (drop
  ;; CHECK-NEXT:      (ref.as_non_null
  ;; CHECK-NEXT:       (struct.get $parent 0
  ;; CHECK-NEXT:        (local.get $x)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (ref.func $child.func)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (call_ref
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:    (block (result (ref $func))
  ;; CHECK-NEXT:     (drop
  ;; CHECK-NEXT:      (ref.as_non_null
  ;; CHECK-NEXT:       (struct.get $parent 0
  ;; CHECK-NEXT:        (local.get $x)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (ref.func $child.func)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $create-child-call-parent (export "child") (result i32)
    (local $x (ref null $parent))

    ;; Create a child instance, but save it to a parent local.
    (local.set $x
      (struct.new_with_rtt $child
        (struct.new_with_rtt $child.vtable
          (ref.func $child.func)
          (ref.func $child.func)
          (rtt.canon $child.vtable)
        )
        (i32.const 42)
        (rtt.canon $child)
      )
    )

    ;; Call the method. As the local is of the parent, this seems like it could
    ;; call either the parent or the child func, but locally we know that only
    ;; a child can be in this local, and we can replace the struct.gets with
    ;; child.func.
    ;;
    ;; Call it twice to verify we can optimize more than a single call.
    (i32.add
      (call_ref
        (local.get $x)
        (struct.get $parent.vtable 0
          (struct.get $parent 0
            (local.get $x)
          )
        )
      )
      (call_ref
        (local.get $x)
        (struct.get $parent.vtable 0
          (struct.get $parent 0
            (local.get $x)
          )
        )
      )
    )
  )
)
