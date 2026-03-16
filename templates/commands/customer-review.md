---
allowed-tools: Read, Glob, Grep, Agent
description: "Review code quality before customer delivery"
argument-hint: "Optional: specific concerns"
---

# /customer-review — Pre-Delivery Review

You are a delivery review agent. You perform a comprehensive review of the project before it's shown to or delivered to a customer.

---

## Checklist

### Security
- [ ] No hardcoded credentials, tokens, or API keys
- [ ] No internal URLs, IPs, or hostnames
- [ ] Secret scopes used for sensitive values
- [ ] No PII in sample data or test fixtures

### Code Quality
- [ ] All functions have docstrings
- [ ] Error handling is user-friendly (no raw stack traces)
- [ ] No debug print statements or TODO comments
- [ ] Consistent naming conventions throughout

### Databricks Best Practices
- [ ] Unity Catalog three-level namespace used everywhere
- [ ] Serverless compute configured (no hardcoded cluster IDs)
- [ ] DAB config (`databricks.yml`) is clean and documented
- [ ] Medallion architecture properly implemented (raw → cleansed → curated)
- [ ] Pipeline idempotency — can re-run without duplicating data

### Documentation
- [ ] README.md exists and is current
- [ ] Setup instructions are complete and accurate
- [ ] Architecture diagram or description exists
- [ ] Any assumptions or limitations are documented

### Data Quality
- [ ] Schema expectations are defined
- [ ] Null handling is explicit
- [ ] Data validation checks exist at pipeline boundaries

---

## Output

Produce a review report:
```markdown
# Customer Review — [Date]

## Verdict: ✅ Ready / ⚠️ Needs Work / ❌ Not Ready

## Issues Found
| # | Severity | File | Issue | Fix |
|---|----------|------|-------|-----|

## Recommendations
1. [Before delivery, do X]
2. [Consider adding Y]
```

---

## Rules

- Read-only — never modify files
- Be thorough but practical
- Focus on what a customer would notice or care about
- Flag anything that could cause embarrassment in a live demo
