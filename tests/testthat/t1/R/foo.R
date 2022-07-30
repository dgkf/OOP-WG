#' @export
foo <- R7::new_generic("foo", "x")
R7::method(foo, R7::class_numeric) <- function(x) "t1::foo:numeric"

.onLoad <- function(libpath, pkgname) {
  R7::methods_register(libpath, pkgname)
}
