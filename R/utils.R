# =============================================================================
# utils.R: helper functions
#   - weighted_rate():  weighted share of a 0/1 variable by group
#   - logit_ame():      average marginal effects of a logit, delta-method SEs
#   - auc_rank():       area under the ROC curve (rank formula)
#   - roc_points():     points of the ROC curve
# =============================================================================

library(dplyr)
library(ggplot2)
library(survey)

# Weighted share (%) of a 0/1 outcome by group
weighted_rate <- function(data, outcome, group, weight = "weight") {
  data %>%
    filter(!is.na(.data[[group]])) %>%
    group_by(group = .data[[group]]) %>%
    summarise(rate = 100 * sum(.data[[outcome]] * .data[[weight]]) / sum(.data[[weight]]),
              n = n(), .groups = "drop") %>%
    mutate(variable = group)
}

# Average marginal effects (AME) of a logit model with weights.
# Numeric variables: derivative of the predicted probability (finite difference).
# Factors: change in the predicted probability from the reference level.
# Standard errors: delta method with a numerical gradient and vcov(fit).
logit_ame <- function(fit, data, weights, eps = 1e-4) {
  tt <- delete.response(terms(fit))
  mm <- function(nd) model.matrix(tt, data = nd, xlev = fit$xlevels)
  w  <- weights / sum(weights)
  b  <- coef(fit)
  V  <- vcov(fit)
  vars <- all.vars(tt)
  out <- list()

  for (v in vars) {
    x <- data[[v]]
    if (is.numeric(x)) {
      nd1 <- data; nd1[[v]] <- x + eps
      X0 <- mm(data); X1 <- mm(nd1)
      f <- function(beta) sum(w * (plogis(X1 %*% beta) - plogis(X0 %*% beta))) / eps
      levs <- list(list(label = v, f = f))
    } else {
      lv <- levels(x)
      nd0 <- data; nd0[[v]] <- factor(lv[1], levels = lv)
      X0 <- mm(nd0)
      levs <- lapply(lv[-1], function(l) {
        nd1 <- data; nd1[[v]] <- factor(l, levels = lv)
        X1 <- mm(nd1)
        list(label = paste0(v, ": ", l, " (vs ", lv[1], ")"),
             f = function(beta) sum(w * (plogis(X1 %*% beta) - plogis(X0 %*% beta))))
      })
    }
    for (L in levs) {
      est  <- L$f(b)
      grad <- sapply(seq_along(b), function(j) {
        h <- 1e-6 * max(1, abs(b[j])); bp <- b; bm <- b
        bp[j] <- bp[j] + h; bm[j] <- bm[j] - h
        (L$f(bp) - L$f(bm)) / (2 * h)
      })
      se <- sqrt(as.numeric(t(grad) %*% V %*% grad))
      out[[length(out) + 1]] <- data.frame(term = L$label, ame = est, se = se)
    }
  }
  res <- do.call(rbind, out)
  res$z       <- res$ame / res$se
  res$p_value <- 2 * pnorm(-abs(res$z))
  res$ci_low  <- res$ame - 1.96 * res$se
  res$ci_high <- res$ame + 1.96 * res$se
  res
}

# Area under the ROC curve (equivalent to the Mann-Whitney statistic)
auc_rank <- function(y, p) {
  r <- rank(p)
  n1 <- sum(y == 1); n0 <- sum(y == 0)
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

# True and false positive rates for every cut-off
roc_points <- function(y, p) {
  o <- order(p, decreasing = TRUE)
  y <- y[o]
  data.frame(fpr = c(0, cumsum(y == 0) / sum(y == 0)),
             tpr = c(0, cumsum(y == 1) / sum(y == 1)))
}
