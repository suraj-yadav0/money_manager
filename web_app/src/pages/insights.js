/* Modern AI Financial Intelligence & Insights Module */
import { StateManager } from '../state.js';
import { Formatters } from '../utils/formatters.js';
import { findCategory } from '../utils/icons.js';

export const InsightsPage = {
  render(state) {
    const insights = this.generateDailyInsights(state);

    return `
      <div class="animate-fade-in" style="display: flex; flex-direction: column; gap: 28px;">
        
        <!-- Hero Header -->
        <section class="hero-section" style="padding-bottom: 0;">
          <div class="hero-header">
            <div>
              <h1 class="hero-welcome-title">Financial Intelligence</h1>
              <p class="hero-subtitle">Algorithmic spending anomaly detection, recurring leakage prevention, and wealth acceleration advice.</p>
            </div>

            <div style="font-size: 13px; font-weight: 700; color: var(--primary); background: var(--success-bg); padding: 8px 16px; border-radius: var(--radius-full); border: 1px solid rgba(16, 185, 129, 0.2);">
              ${insights.length} Active Observations
            </div>
          </div>
        </section>

        <!-- Insights List -->
        ${insights.length === 0 ? `
          <div class="fintech-card" style="text-align: center; padding: 60px 20px; color: var(--text-muted);">
            <div style="width: 56px; height: 56px; border-radius: 50%; background: rgba(255,255,255,0.04); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px;">
              <span class="material-icons" style="font-size: 28px; opacity: 0.5;">insights</span>
            </div>
            <div style="font-size: 16px; font-weight: 600; color: var(--text-primary); margin-bottom: 6px;">Need more transaction data</div>
            <div style="font-size: 13px;">Add more expenses and income to generate smart AI pacing insights.</div>
          </div>
        ` : `
          <div class="insights-feed">
            ${insights.map(item => {
              const isWarning = item.severity === 'warning';
              const isSuccess = item.severity === 'success';
              const iconName = isWarning ? 'warning_amber' : isSuccess ? 'verified' : 'lightbulb';
              const iconColor = isWarning ? 'var(--error)' : isSuccess ? 'var(--success)' : 'var(--secondary)';
              const iconBg = isWarning ? 'var(--error-bg)' : isSuccess ? 'var(--success-bg)' : 'rgba(56, 189, 248, 0.12)';

              return `
                <div class="insight-card">
                  <div class="insight-icon-box" style="background: ${iconBg}; color: ${iconColor};">
                    <span class="material-icons">${iconName}</span>
                  </div>
                  <div class="insight-content">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                      <div class="insight-title">${item.title}</div>
                      <span class="kpi-badge ${isWarning ? 'negative' : isSuccess ? 'positive' : 'neutral'}">
                        ${item.severity.toUpperCase()}
                      </span>
                    </div>
                    <div class="insight-desc">${item.description}</div>
                    ${item.tip ? `
                      <div class="insight-tip">
                        <b>Actionable Tip:</b> ${item.tip}
                      </div>
                    ` : ''}
                  </div>
                </div>
              `;
            }).join('')}
          </div>
        `}
      </div>
    `;
  },

  generateDailyInsights(state) {
    const insights = [];
    const transactions = state.transactions;
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    
    const expenses = transactions.filter(t => t.type === 'expense' && new Date(t.timestamp) >= startOfMonth);
    const incomes = transactions.filter(t => t.type === 'income' && new Date(t.timestamp) >= startOfMonth);

    const totalExpenses = expenses.reduce((acc, t) => acc + t.amount, 0);
    const totalIncome = incomes.reduce((acc, t) => acc + t.amount, 0);

    // 1. Savings Rate
    if (totalIncome > 0) {
      const savingsRate = ((totalIncome - totalExpenses) / totalIncome) * 100;
      if (savingsRate >= 30) {
        insights.push({
          title: 'Exceptional Savings Discipline',
          severity: 'success',
          description: `You have maintained a ${savingsRate.toFixed(0)}% savings rate this month, outpacing standard 20% benchmarks.`,
          tip: 'Consider routing excess capital into active savings goals or high-yield investments.'
        });
      } else if (savingsRate < 10 && savingsRate >= 0) {
        insights.push({
          title: 'Tight Cash Flow Margin',
          severity: 'warning',
          description: `Your monthly savings rate is currently ${savingsRate.toFixed(0)}%. Most of your inflow is being consumed by outgoing expenses.`,
          tip: 'Audit non-essential categories (Dining, Shopping, Entertainment) to increase your safety buffer.'
        });
      } else if (savingsRate < 0) {
        insights.push({
          title: 'Negative Cash Flow Alert',
          severity: 'warning',
          description: `Outflows exceed inflows by ${Formatters.currency(totalExpenses - totalIncome)} this month.`,
          tip: 'Pause discretionary purchases until the next income cycle to prevent drawing from reserve capital.'
        });
      }
    }

    // 2. Category Dominance
    if (expenses.length > 0 && totalExpenses > 0) {
      const categoryTotals = {};
      for (const tx of expenses) {
        const cat = findCategory(state.categories, tx.categoryId || tx.category_id);
        const catName = cat ? cat.name : 'Other';
        categoryTotals[catName] = (categoryTotals[catName] || 0) + tx.amount;
      }

      for (const [name, amount] of Object.entries(categoryTotals)) {
        const ratio = amount / totalExpenses;
        if (ratio > 0.35) {
          insights.push({
            title: `${name} Represents ${Math.round(ratio * 100)}% of Outflow`,
            severity: 'info',
            description: `${Formatters.currency(amount)} of your total monthly expenditures went toward ${name}.`,
            tip: `Set a dedicated category budget cap for ${name} to keep this category under control.`
          });
        }
      }
    }

    // 3. Recurring Subscriptions
    const recurringExpenses = expenses.filter(t => t.isRecurring || t.is_recurring);
    if (recurringExpenses.length > 0) {
      const recurringTotal = recurringExpenses.reduce((acc, t) => acc + t.amount, 0);
      insights.push({
        title: `${recurringExpenses.length} Fixed Subscriptions Active`,
        severity: 'info',
        description: `Recurring charges amount to ${Formatters.currency(recurringTotal)} this month across ${recurringExpenses.length} commitments.`,
        tip: 'Regularly audit automated subscriptions to ensure you are actively using all active memberships.'
      });
    }

    return insights;
  },

  bindEvents() {}
};
