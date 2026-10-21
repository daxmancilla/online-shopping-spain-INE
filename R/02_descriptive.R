# =============================================================================
# 02_descriptive.R: weighted share of people who bought online, by group
# Input:  data/tich_2024_clean.rds
# Output: output/tables/purchase_rates.csv, output/figures/purchase_rates.png
# =============================================================================

tich <- readRDS(here::here("data", "tich_2024_clean.rds"))

overall <- 100 * sum(tich$online_purchase * tich$weight) / sum(tich$weight)
message("Bought online in the last 3 months (16-74): ", round(overall, 1), "%")

groups <- c(sex = "Sex", age_group = "Age group", education = "Education",
            income = "Household income (euros/month)", employment = "Employment status")

rates <- bind_rows(lapply(names(groups), function(g) {
  weighted_rate(tich, "online_purchase", g) %>%
    mutate(variable = groups[[g]], group = as.character(group))
}))
rates$variable <- factor(rates$variable, levels = unname(groups))

write.csv(rates %>% select(variable, group, rate, n),
          here::here("output", "tables", "purchase_rates.csv"), row.names = FALSE)

# The category order follows the order in which the groups appear
rates$group <- factor(rates$group, levels = unique(rates$group))

p <- ggplot(rates, aes(x = rate, y = group)) +
  geom_col(fill = "#1f4e79", width = 0.7) +
  geom_text(aes(label = sprintf("%.1f%%", rate)), hjust = -0.15, size = 3.2) +
  geom_vline(xintercept = overall, linetype = "dashed", colour = "grey40") +
  facet_wrap(~ variable, scales = "free_y", ncol = 2) +
  scale_x_continuous(limits = c(0, 100), expand = expansion(mult = c(0, 0.02))) +
  labs(title = "Share of people aged 16-74 who bought online in the last 3 months, Spain 2024",
       subtitle = sprintf("Weighted estimates. Dashed line: total (%.1f%%)", overall),
       x = "%", y = NULL, caption = "Source: INE, TIC-H 2024 microdata. Own calculations.") +
  theme_minimal(base_size = 11) +
  theme(plot.title.position = "plot", panel.grid.major.y = element_blank())

ggsave(here::here("output", "figures", "purchase_rates.png"), p, width = 10, height = 8, dpi = 150)
