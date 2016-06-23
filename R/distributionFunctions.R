################################################################################
synonyms <- list(
  poisson = "pois",
  'negative-binomial' = "nbinom",
  uniform = "unif",
  laplace = "lapl",
  logistic = "logis",
  normal = "norm",
  'normal-mixture' = "mixnorm",
  'two-piece-exponential' = "2pexp",
  'two-piece-normal' = "2pnorm",
  exponential = "exp",
  'log-laplace' = "llapl",
  'log-logistic' = "llogis",
  'log-normal' = "lnorm",
  'censored-exponential' = "cexp"
)

################################################################################

flapl <- function(x, location, scale) {
  dexp(abs(x - location), 1/scale) / 2
}

fnorm <- function(x, location, scale,
                  lower = -Inf, upper = Inf,
                  lmass = 0, umass = 0, log = FALSE) {
  out <- dnorm(x, location, scale, log)
  
  ind1 <- any(is.finite(lower))
  ind2 <- any(is.finite(upper))
  if (!ind1 & !ind2) {
    return(out)
  }
  
  
  if (is.character(lmass)) {
    Plb <- numeric(length(lmass))
    Plb[lmass == "cens"] <- pnorm(lower, location, scale)
  } else {
    Plb <- lmass
  }
  if (is.character(umass)) {
    Pub <- numeric(length(lmass))
    Pub[umass == "cens"] <-
      pnorm(upper, location, scale, lower.tail = FALSE)
  } else {
    Pub <- umass
  }
  
  
  if (ind1 & ind2) {
    if (any(lower > upper)) {
      stop("Parameter 'lower' contains values greater than 'upper'.")
    }
    if (any(Plb != 0 | Pub != 0)) {
      warning("Not a probability density due to point masses in 'lower' and/or 'upper'.")
    }
    a <- (1 - Pub - Plb) /
      (pnorm(upper, location, scale) - pnorm(lower, location, scale))
    ind <- x < lower | x > upper
  } else if (ind1 & !ind2) {
    if (any(lmass != 0)) {
      warning("Not a probability density due to a point mass in 'lower'.")
    }
    a <- (1 - Pub - Plb) / (1 - pnorm(lower, location, scale))
    ind <- x < lower
  } else if (!ind1 & ind2) {
    if (any(umass != 0)) {
      warning("Not a probability density due to a point mass in 'upper'.")
    }
    a <- (1 - Pub - Plb) / pnorm(upper, location, scale)
    ind <- x > upper
  }
  
  if (!log) {
    out <- out * a
    out[ind] <- 0
  } else {
    out <- out + log(a)
    out[ind] <- -Inf
  }
  return(out)
}

ft <- function(x, df, location, scale) {
  z <- (x - location) / scale
  1/scale * dt(z, df)
}

f2pexp <- function(x, location, scale1, scale2) {
  n <- max(length(x), length(location), length(scale1), length(scale2))
  z <- rep(x - location, len = n)
  s <- ifelse(z < 0, scale1, scale2)
  s / (scale1 + scale2) * dexp(abs(z), 1/s)
}

f2pnorm <- function(x, location, scale1, scale2) {
  n <- max(length(x), length(location), length(scale1), length(scale2))
  z <- rep(x - location, len = n)
  s <- ifelse(z < 0, scale1, scale2)
  2 * s / (scale1 + scale2) * dnorm(z, 0, s)
}

fmixnorm <- function(x, m, s, w) {
  if (!is.vector(x)) stop("object 'x' not a vector")
  p <- length(x)
  
  if (is.matrix(m)) {
    m.q <- dim(m)[2]
    if (dim(m)[1] != p) stop("number of rows of object 'm' does not match length of object 'x'")
  } else if (length(m) != 1) {
    stop("object 'm' is neither a matrix nor a single number")
  }
  
  if (is.matrix(s)) {
    s.q <- dim(s)[2]
    if (dim(s)[1] != p) stop("number of rows of object 's' does not match length of object 'x'")
    if (exists("m.q")) {
      if (s.q != m.q) stop("number of mixture components in 's' and 'm' do not match")
    }
  } else if (length(s) != 1) {
    stop("object 's' is neither a matrix nor a single number")
  }
  
  if (is.matrix(w)) {
    w.q <- dim(w)[2]
    if (dim(w)[1] != p) stop("number of rows of object 'w' does not match length of object 'x'")
    if (exists("m.q")) {
      if (w.q != m.q) stop("number of mixture components in 'w' and 'm' do not match")
    }
    if (exists("s.q")) {
      if (w.q != s.q) stop("number of mixture components in 'w' and 's' do not match")
    }
  } else if (length(w) == 1) {
    w <- 1/max(dim(m)[2], dim(s)[2], 1)
  } else {
    stop("object 'w' is neither a matrix nor a single number")
  }
  
  rowSums(dnorm(as.matrix(x), m, s) * w)
}

### log distributions

fllapl <- function(x, locationlog, scalelog) {
  x1 <- log(pmax(x, 0))
  ind <- is.infinite(x1)
  d <- 1/x * flapl(x1, locationlog, scalelog)
  d[ind] <- 0
  return(d)
}

fllogis <- function(x, locationlog, scalelog) {
  x1 <- log(pmax(x, 0))
  ind <- is.infinite(x1)
  d <- 1/x * dlogis(x1, locationlog, scalelog)
  d[ind] <- 0
  return(d)
}

###

fgpd <- function(x, location, scale, shape) {
  z <- (x - location) / scale
  
  ind <- abs(shape) < 1e-12
  if (any(ind)) {
    if (length(z) < length(shape))
      z <- rep(z, len = length(shape))
    if (length(scale) < length(z))
      scale <- rep(scale, len = length(z))
    out <- numeric(length(z))
    out[ind] <- 1/scale[ind] * dexp(z[ind], 1)
    out[!ind] <- 1/scale[!ind] * fgpd(z[!ind], 0, 1, shape[!ind])
  } else {
    out <- 1/scale * (1 + shape * z)^(- 1 - 1/shape)
    out[z < 0] <- 0
    out[z > -1/shape & shape < 0] <- 0
  }
  
  return(out)
}

fgev <- function(x, location, scale, shape) {
  z <- (x - location) / scale
  
  ind <- abs(shape) < 1e-12
  if (any(ind)) {
    if (length(z) < length(shape))
      z <- rep(z, len = length(shape))
    if (length(scale) < length(z))
      scale <- rep(scale, len = length(z))
    out <- numeric(length(z))
    out[ind] <- 1 / scale[ind] * exp(-z[ind] - exp(-z[ind]))
    out[!ind] <- 1 / scale[!ind] * fgev(z[!ind], 0, 1, shape[!ind])
  } else {
    zz <- 1 + shape * z
    out <-
      1 / scale * exp(log1p(shape * z) * (-1 - 1 / shape) - zz ^ (-1 / shape))
    out[z * sign(shape) < -1 / abs(shape)] <- 0
  }
  
  return(out)
}