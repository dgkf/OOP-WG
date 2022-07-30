# R7 Mutual Generics Playground

This fork of R7 is a sandbox for exploring the concept of _mutually registered
generics_ (If this concept has an existing formal name, forgive me for not
knowing it).

## What is a _mutually registered generic_?

In contrast to generics systems where there is an origin to each generic (for
example, a package that exports the generic), the concept of mutually registered
generics allows for _any_ package to export _methods_ against a global generic
name. There is no concept of ownership over generics, only over method
implementations. Methods may be masked, but the generic construct is shared
across all packages.

There are still plenty of design decisions about how much work such a system
should do to put guardrails on such behavior. For now, the implementation is
quite constrained. Methods may only register against the shared generic if they
differ only in which methods they implement. 

## Examples

Provided two packages that export generics of the name `foo`, which dispatch on
a single argument `x`:

`pkgA`
```r
#' @export
foo <- R7::new_generic("foo", "x")
R7::method(foo, R7::class_numeric) <- function(x) "pkgA::foo(<numeric>)"

.onLoad <- function(libpath, pkgname) R7::methods_register(libpath, pkgname)
```

`pkgB`
```r
#' @export
foo <- R7::new_generic("foo", "x")
R7::method(foo, R7::class_double) <- function(x) "pkgB::foo(<double>)"

.onLoad <- function(libpath, pkgname) R7::methods_register(libpath, pkgname)
```

### Packages in isolation

Both packagees will provide functional generics and methods in isolation. 

```r
library(pkgA)
foo
# <R7_generic> foo(x, ...) with 2 methods:
# 1: method(foo, class_integer) [pkgA]
# 2: method(foo, class_double) [pkgA]

foo(1)
# [1] "pkgA::foo(<numeric>)"
```

### Packages in combination

Loading both packages, in either order, will provide a single generic, which
will have multiple implementations of the method for signature `<double>`. Which
method is dispatched to is determined by the order that the packages were
loaded, with the latter package's `<double>` method masking the former's.

```r
library(pkgA)
library(pkgB)
# method foo(<double>) from 'pkgA' masked by method in 'pkgB'

foo
# <R7_generic> foo(x, ...) with 3 methods:
# 1: method(foo, class_integer) [pkgA]
# 2: method(foo, class_double) [pkgB]
# 3: method(foo, class_double) [pkgA]

foo(1)
# [1] "pkgB::foo(<double>)"
```
