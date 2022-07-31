#' Register methods on generics from an environment
#'
#' @param from An environment whose generics should be registered. By default,
#'   the parent environment is used.
#'
#' @export
#'
methods_register <- function(libpath, package = packageName(parent.frame())) {
  package_env <- getNamespace(package)
  search_envs <- lapply(search(), as.environment)
  generics <- exported_generics_get(package_env, libpath)

  masking_notes <- list()
  for (generic in generics) {
    existing_generic_env <- Find(
      function(env) exists(x = generic@name, inherits = FALSE, envir = env),
      search_envs
    )

    # no existing generic, use regular namespace export mechanics
    if (is.null(existing_generic_env))
      next

    # otherwise, reexport any existing generic with new methods overlayed
    existing_generic <- existing_generic_env[[generic@name]]
    compat <- methods_check_compatibility(generic, existing_generic)
    if (!is.null(compat)) {
      masking_notes[length(masking_notes) + 1] <- list(compat)
      next
    }

    # mask with the existing generic in the attached package namespace
    new_generic <- assign(generic@name, existing_generic, package_env)

    for (method_name in names(generic@methods)) {
      # coerce to a list of methods for signature... sorry for hack
      methods <- generic@methods[[method_name]]
      if (!is.list(methods)) methods <- list(methods)

      # for method in methods currently registered with signature
      for (method in methods) {
        for (signature in method@signature) {
          register_method(new_generic, signature, method)
        }
      }
    }

    # add .onUnload hook to unregister methods from this namespace
    setHook(packageEvent(package, "onUnload"), unregistrar(package, new_generic))
  }

  if (length(masking_notes)) {
    packageStartupMessage(generic_masking_notes_format(masking_notes))
  }
}

#' Generate a function to remove a package's contributed methods
#'
#' @param package A package name, whose namespace may be the originating
#'   namespace for some number of methods registered to generic
#' @param generic An R7 generic
#'
#' @return A function, which may be used as a package event hook to remove a
#'   package's contributed methods
#'
#' @keywords internal
#'
unregistrar <- function(package, generic) {
  function(...) {
    package_env <- getNamespace(package)
    unregister_methods(generic@methods, package_env)
  }
}

unregister_methods <- function(x, from) {
  UseMethod("unregister_methods")
}

unregister_methods.environment <- function(x, from) {
  for (method_name in names(x)) {
    method <- x[[method_name]]
    if (is.environment(method)) {
      unregister_methods(method, from)
    } else if (is.list(method)) {
      x[[method_name]] <- unregister_methods(method, from)
    } else if (identical(environment(method), from)) {
      rm(list = method_name, envir = x, inherits = FALSE)
    }
  }
}

unregister_methods.list <- function(x, from) {
  is_from <- vlapply(x, function(xi) identical(environment(xi), from))
  x[!is_from]
}

generic_masking_notes_format <- function(masks) {
  masks <- masks[order(lapply(masks, `[[`, "reason"))]
  paste0(collapse = "",
    "The following generics will be masked:\n\n",
    sprintf("    %s from %s (due to %s)\n",
      vcapply(masks, `[[`, "name"),
      vcapply(masks, function(i) paste0("'", i$masks_from, "'", collapse = ", ")),
      vcapply(masks, `[[`, "reason")
    )
  )
}

methods_mismatch_note <- function(generic, existing_generic, reason) {
  method_sources <- generic_method_sources(existing_generic)
  list(name = generic@name, masks_from = method_sources, reason = reason)
}

#' Check whether two generics can be merged
#'
#' Currently, this is as conservative as possible and will not allow any
#' differences between methods provided by different sources.
#'
#' @note
#' It would be interesting to explore how lenient this could be.
#' - Perhaps a difference of the dispatch body could individually mask the
#'   dispatching body of the existing generic.
#' - Perhaps mismatches in arguments (so long as the dispatch args are
#'   consistent) need not be consistent
#' - Perhaps differences in dispatch args can force the method to be used with
#'   only positional arguments to disambiguate dispatch args.
#' - Maybe these more lenient interop behaviors could be user-configurable
#'
methods_check_compatibility <- function(new, old) {
  if (!identical(body(new), body(old))) {
    methods_mismatch_note(new, old, "mismatched dispatch body")
  } else if (!identical(formals(new), formals(old))) {
    methods_mismatch_note(new, old, "mismatched generic arguments")
  } else if (!identical(new@dispatch_args, old@dispatch_args)) {
    methods_mismatch_note(new, old, "mismatched dispatch arguments")
  }
}

method_source <- function(method) {
  env <- topenv(environment(method))
  if (isNamespace(env)) {
    getNamespaceName(env)
  } else {
    gsub("<environment: (.*)>", "\\1", format(env))
  }
}

generic_method_sources <- function(generic) {
  envs <- eapply(generic@methods, method_source)
  envs <- Filter(Negate(is.null), envs)
  unique(as.character(envs))
}

exported_generics_get <- function(ns, libpath) {
  # when called via .onLoad, namespace info exports haven't been populated yet,
  # needs to be parsed independently from the NAMESPACE file
  # TODO: also handle package/Meta/nsInfo.rds
  ns_info <- parseNamespaceFile(getNamespaceName(ns), libpath)
  exports <- ns_info$exports

  obj_is_generic <- eapply(ns, is_generic)
  mode(obj_is_generic) <- "logical"

  generics <- intersect(names(obj_is_generic), exports)
  names(generics) <- generics

  generics <- lapply(generics, get0, envir = ns, inherits = FALSE)
  Filter(Negate(is.null), generics)
}
