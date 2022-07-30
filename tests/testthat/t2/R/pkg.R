#' @export
foo <- R7::new_generic("foo", "x")
R7::method(foo, R7::class_double) <- function(x) "t2::foo:double"

bar <- R7::new_external_generic("t0", "bar", "x")
R7::method(bar, R7::class_character) <- function(x) "bar"

.onLoad <- function(libpath, pkgname) {
  R7::methods_register(libpath, pkgname)
  R7::external_methods_register()
}
