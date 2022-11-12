# Motivation

## An S3 use case

When two packages want to

 * provide a standalone generic
 * and be compatible with eachother's generics

They must export their own generics, while also registering methods against
eachother's generics.

If a third package is introduced, each package has to maintain compatibility
with both other packages. 

If you're not aware of packages that export the same generics, your users have
to deal with two incompatible generics and juggle them with namespaced calls.

## Solutions

 * Export methods to all known generics so our methods continue to be picked up
   when our generic is masked
 * Use function name that's unlikely to be masked (`pkg_fn()`, `fnType()`)
 * Move the generic declaration to a `generics`-style package

## Problem

All solutions require action to fix generic conflicts _retroactively_

## Goals

 * Allow generics to work easily both alone and alongside packages that provide
   similar generics
 * Allow generic contract to be articulated _proactively_





# So what is a generic anyways?

> A contract for a behavior, which may require type-specific implementations

_or_

> An extensible API, without claim over behavior

Even if we idealogically aspire to build an ecosystem where the first is true,
prohbiting the latter stiffles ecosystem development.

## In practice we _already_ see both

Both from `generics` package, examples that either restrict use to a specific
intended use, or leave the generic wide open for any behavior by design.

```r
#' Explain details of an object
#'
#' @param x An object. See the individual method for specifics.
#' @param ... other arguments passed to methods
#' 
explain <- [...]
```

```r
#' Interpolate missing values
#'
#' Interpolates missing values provided in the training dataset using the
#' fitted model.
#'
#' @param object A fitted model object
#' @param ... Other arguments passed to methods
#'
interpolate <- [...]
```

## Drawing a line can be hard

When do we collectively want to say that someone is wrong for extending
`interpolate`...

 * `interpolate(<range>)`
   If we just provide a range, is that interpolation? We can consider the "fitted
   data" as the start and end?

 * `interpolate(<motion>)`
   Motion paths are just models for locations over time. But isn't fitted to any
   data. Interpolating motion paths might just mean solving a function at
   multiple timesteps.

 * `interpolate(<colors>)`
   What is color interpretation but interpolation of a model for each channel?

 * `interpolate(<numeric vector>)`
   If we don't provide a model, but instead provide values - is that still
   conforming to this generic?

 * `interpolate(<police-person>) # convert to "interpol-person"`
   Clearly not interpolating of missing values, but if the types aren't
   conflicting, is it worth easier extensibility at the expense of some
   misaligned functions?





# Proposal

Allow "mutual" registration of generics that can operate with or without other
packages that export generics of the same name.

## Details TBD

### Method masking

Methods mask existing methods with the same signature. Unloading a package
should "unmask" the methods that were masked on load. Effectively matches
function masking, but on the level of individual generics.

### Generics with differing signatures

Some ideas:

- Any difference in signature should cause the new generic to mask the old one

- As long as generics do not _conflict_, then they can be reconciled. For
  example, one generic's type signature is identical with additional parameters.

- If the parameter names don't match, dispatch is restricted to using only
  positional arguments

### Ability to restrict mixing of generics

Some ideas:

- Maybe package authors should have the ability to restrict other packages from
  registering methods against their generics unless explicit declared from the
  other package (akin to current registration behavior, but _proactive_)

- Perhaps package authors want to be able to whitelist specific packages that
  can register methods

- Perhaps package users want to have a say in how masking happens? 

### Generic documentation

If multiple packages are providing generics, how can we make them accessible.
One package's generic documentation may not reflect all the ways the generic can
be used. 
