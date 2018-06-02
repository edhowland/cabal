# Bugs

## Trying to call lambda with more than defined formals rasies exception

```
(define code (lambda (a b) b))
(code 1 2 3 4)
; Excpetion raised
```


