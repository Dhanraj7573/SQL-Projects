SQL & Python Projects
A collection of SQL and Python projects built around financial data, customer analytics, and business monitoring. Tools used: T-SQL, Python.

Weekly Fraud & Decline Monitor
Monitors weekly payment transaction data to detect spikes in fraud and decline rates by channel. Includes automated alert flags (FRAUD_SPIKE, DECLINE_SPIKE, LOW_VOLUME) using window functions and reusable SQL views.

SaaS Analytics Database
Full SaaS analytics platform built from scratch. Covers schema design, data generation, and business intelligence views including MRR, churn rate, cohort retention (M0–M6), LTV estimation, and trial-to-paid conversion by acquisition channel.
Files: SaaSAnalyticsDB.sql · SaaSAnalytics DB_final.sql

Loan Book Health Analysis
Analyses a lending portfolio to identify repayment gaps and at-risk accounts. Includes a loan portfolio summary, per-loan payment coverage %, and a red flag list of customers with active loans and no payments recorded.

Fraud Data Analysis
Exploratory analysis of fraud transaction data, identifying unusual patterns and data quality issues across payment records.

Customer Cohort & Retention Analysis
Tracks how customer groups behave over time from their signup month. Calculates retention rates by cohort, helping identify when customers drop off and which segments retain best.
Files: Cohort Customer segmentation.sql · Customer retention & cohort.sql · customer cohort.sql

Customer Segmentation & 360 View
Segments customers based on behaviour and builds a unified 360 view combining transaction history and lifecycle stage. Useful for targeting and personalisation analysis.
Files: Customer segmentation & retnetion.sql · Customer 360.sql

Churn Flag Detection
Rule-based SQL logic that flags customers showing early signs of churn based on activity signals. Designed to support proactive retention efforts.

Monthly Sales Dashboard
Aggregates monthly revenue, transaction volume, and growth metrics into a structured format ready for dashboard reporting.

Merchant Health Monitoring
Tracks merchant-level performance including transaction volumes, settlement rates, and decline patterns to monitor the health of the merchant portfolio.

Weekly KPI + Alert System
Weekly KPI monitoring framework with automated alerting logic. Flags metric deviations to support operational reporting and quick decision-making.

Compound Interest Calculator
Python-based compound interest calculator built in a Jupyter Notebook, combining finance domain knowledge with Python scripting.
