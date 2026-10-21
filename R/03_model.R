# =============================================================================
# 03_model.R: logit of online purchase among employees, marginal effects and fit
# Input:  data/tich_2024_clean.rds
# Output: output/tables/logit_coefficients.csv, output/tables/marginal_effects.csv,
#         output/tables/model_fit.csv, output/figures/marginal_effects.png,
#         output/figures/roc_curve.png
# =============================================================================

tich <- readRDS(here::here("data", "tich_2024_clean.rds"))

# Contract type and ICT occupation are only asked to employees, so the model
# is estimated for employees aged 16-74.
model_data <- tich %>%
  filter(employment == "Employee") %>%
  select(online_purchase, age, sex, education, contract, ict_worker, income,
         children_10_15, weight) %>%
  na.omit()
message("Model sample (employees aged 16-74): ", nrow(model_data))

form <- online_purchase ~ age + sex + education + contract + ict_worker +
  income + children_10_15

# Logit with person weights. The public file has no cluster or strata
# identifiers, so the standard errors only account for the weights.
design <- svydesign(ids = ~1, weights = ~weight, data = model_data)
fit    <- svyglm(form, design = design, family = quasibinomial())

coefs <- data.frame(term = names(coef(fit)), estimate = coef(fit),
                    se = sqrt(diag(vcov(fit))), row.names = NULL)
coefs$odds_ratio <- exp(coefs$estimate)
coefs$p_value    <- 2 * pnorm(-abs(coefs$estimate / coefs$se))
write.csv(coefs, here::here("output", "tables", "logit_coefficients.csv"), row.names = FALSE)

# -----------------------------------------------------------------------------
# Average marginal effects (percentage points)
# -----------------------------------------------------------------------------
ame <- logit_ame(fit, model_data, model_data$weight)
labels <- c("^age$" = "Age (one more year)", "^children_10_15$" = "Children aged 10-15 (one more)",
            "^sex:" = "Sex:", "^education:" = "Education:", "^contract:" = "Contract:",
            "^ict_worker:" = "Occupation:", "^income:" = "Household income:")
for (k in names(labels)) ame$term <- sub(k, labels[[k]], ame$term)
write.csv(ame, here::here("output", "tables", "marginal_effects.csv"), row.names = FALSE)
print(transform(ame[, c("term", "ame", "se", "p_value")], ame = round(100 * ame, 1),
                se = round(100 * se, 1), p_value = round(p_value, 3)), row.names = FALSE)

p_ame <- ggplot(ame, aes(x = 100 * ame, y = reorder(term, ame))) +
  geom_vline(xintercept = 0, colour = "grey50") +
  geom_errorbar(aes(xmin = 100 * ci_low, xmax = 100 * ci_high), width = 0.2,
                orientation = "y", colour = "#1f4e79") +
  geom_point(size = 2.2, colour = "#1f4e79") +
  labs(title = "Average marginal effects on the probability of buying online",
       subtitle = "Employees aged 16-74, Spain 2024. Weighted logit, 95% confidence intervals",
       x = "Percentage points", y = NULL,
       caption = "Source: INE, TIC-H 2024 microdata. Own calculations.") +
  theme_minimal(base_size = 11) +
  theme(plot.title.position = "plot")
ggsave(here::here("output", "figures", "marginal_effects.png"), p_ame, width = 9, height = 6, dpi = 150)

# -----------------------------------------------------------------------------
# Fit and predictive performance
# -----------------------------------------------------------------------------
y <- model_data$online_purchase
p <- as.numeric(predict(fit, type = "response"))
pred <- as.integer(p >= 0.5)

fit_stats <- data.frame(
  statistic = c("Observations", "Share of buyers in the sample",
                "Pseudo R2 (1 - deviance / null deviance, weighted)",
                "Accuracy (cut-off 0.5)", "No-information rate (always predict the majority class)",
                "Sensitivity (buyers correctly predicted)", "Specificity (non-buyers correctly predicted)",
                "Area under the ROC curve"),
  value = c(length(y), mean(y),
            1 - fit$deviance / fit$null.deviance,
            mean(pred == y), max(mean(y), 1 - mean(y)),
            mean(pred[y == 1] == 1), mean(pred[y == 0] == 0),
            auc_rank(y, p)))
fit_stats$value <- round(fit_stats$value, 3)
write.csv(fit_stats, here::here("output", "tables", "model_fit.csv"), row.names = FALSE)
print(fit_stats, row.names = FALSE)

roc <- roc_points(y, p)
p_roc <- ggplot(roc, aes(fpr, tpr)) +
  geom_abline(linetype = "dashed", colour = "grey50") +
  geom_line(colour = "#1f4e79", linewidth = 1) +
  coord_equal() +
  labs(title = "ROC curve", subtitle = sprintf("AUC = %.3f", auc_rank(y, p)),
       x = "False positive rate (1 - specificity)", y = "True positive rate (sensitivity)") +
  theme_minimal(base_size = 11)
ggsave(here::here("output", "figures", "roc_curve.png"), p_roc, width = 5.5, height = 5.5, dpi = 150)
