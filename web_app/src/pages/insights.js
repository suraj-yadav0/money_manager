/* Insights Screen Module (AI-lite insights card list generated from actual transactions) */
import { StateManager } from '../state.js';
import { Formatters } from '../utils/formatters.js';
import { findCategory } from '../utils/icons.js';
import { Router } from '../router.js';

export const InsightsPage = {
  render(state) {
    const insights = this.generateDailyInsights(state);

    return `
      <div class="modal-card animate-fade-in" style="background:#131124; max-height:90vh; display:flex; flex-direction:column; width:100%; max-width:600px; padding:32px 40px;">
        <div class="modal-header" style="border-bottom: 1px solid var(--divider); padding-bottom:12px; margin-bottom:16px;">
          <div style="display:flex; align-items:center; gap:8px;">
            <span class="material-icons" style="color:var(--primary);">insights</span>
            <h3 style="color:#FFF; font-size:20px;">Financial Insights</h3>
          </div>
          <button class="modal-close" id="insights-close-btn">&times;</button>
        </div>

        <div style="flex:1; overflow-y:auto; display:flex; flex-direction:column; gap:16px;" id="insights-list-container">
          ${insights.length === 0 ? `
            <div style="text-align: center; padding: 60px 20px; color: var(--text-muted);">
              <span class="material-icons" style="font-size: 54px; margin-bottom: 12px;">lightbulb_outline</span>
              <p style="font-size: 15px;">No financial insights available yet.</p>
              <p style="font-size: 12px; margin-top: 4px;">Insights will generate once you log expenses.</p>
            </div>
          ` : insights.map(ins => this.renderInsightCard(ins)).join('')}
        </div>
      </div>
    `;
  },

  renderInsightCard(ins) {
    let cardClass = 'insight-info';
    let icon = 'info_outline';
    if (ins.severity === 'critical') {
      cardClass = 'insight-critical';
      icon = 'warning_amber';
    } else if (ins.severity === 'warning') {
      cardClass = 'insight-warning';
      icon = 'error_outline';
    }

    return `
      <div class="glass-card insight-card ${cardClass}" style="padding:16px;">
        <div class="insight-icon-box">
          <span class="material-icons">${icon}</span>
        </div>
        <div class="insight-content">
          <h4 class="insight-title">${ins.title}</h4>
          <p class="insight-description">${ins.description}</p>
          ${ins.tip ? `<p class="insight-tip">💡 Tip: ${ins.tip}</p>` : ''}
        </div>
      </div>
    `;
  },

  // JavaScript implementation of insights_engine.dart logic
  generateDailyInsights(state) {
    const insights = [];
    const transactions = state.transactions;
    if (transactions.length === 0) return insights;

    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    
    // Filter expenses for this month
    const expenses = transactions.filter(t => {
      const ts = new Date(t.timestamp);
      return t.type === 'expense' && ts >= startOfMonth;
    });

    const totalExpenses = expenses.reduce((sum, t) => sum + t.amount, 0);
    const settings = state.userSettings || { monthlyIncome: 0 };
    const monthlyIncome = settings.monthlyIncome || 0;

    // 1. Spending Spike Detection
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayExpenses = expenses.filter(t => {
      const ts = new Date(t.timestamp);
      return ts.getFullYear() === today.getFullYear() &&
             ts.getMonth() === today.getMonth() &&
             ts.getDate() === today.getDate();
    });

    if (todayExpenses.length > 0) {
      const todayTotal = todayExpenses.reduce((sum, t) => sum + t.amount, 0);
      const otherExpenses = expenses.filter(t => {
        const ts = new Date(t.timestamp);
        return ts.getDate() !== today.getDate();
      });

      if (otherExpenses.length > 0) {
        // Unique days count
        const otherDays = new Set(otherExpenses.map(t => new Date(t.timestamp).toDateString())).size;
        if (otherDays > 0) {
          const dailyAverage = otherExpenses.reduce((sum, t) => sum + t.amount, 0) / otherDays;
          if (todayTotal > dailyAverage * 2.0) {
            insights.push({
              title: 'Spending Spike Detected',
              severity: 'warning',
              description: `Today's spending is ${Formatters.currency(todayTotal)}, which is ${(todayTotal / dailyAverage).toFixed(1)}x your daily average.`,
              tip: 'Try a "no-spend day" tomorrow to balance this out.'
            });
          }
        }
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
        if (ratio > 0.40) {
          insights.push({
            title: `${name} Leads Spending`,
            severity: 'info',
            description: `${(ratio * 100).toFixed(0)}% of your expenses (${Formatters.currency(amount)}) went to ${name} this month.`,
            tip: `Check if there are cheaper alternatives for your major expenses in ${name}.`
          });
        }
      }
    }

    // 3. Budget / Spending Progress
    if (monthlyIncome > 0 && totalExpenses > 0) {
      const ratio = totalExpenses / monthlyIncome;
      const daysElapsed = Formatters.daysElapsedInMonth();
      const totalDays = Formatters.daysInCurrentMonth();
      const expectedRatio = daysElapsed / totalDays;

      if (ratio > expectedRatio + 0.15) {
        insights.push({
          title: 'Spending Ahead of Schedule',
          severity: 'warning',
          description: `You've spent ${Formatters.percentage(ratio)} of your income with ${Formatters.percentage(1 - expectedRatio)} of the month remaining.`,
          tip: 'Consider pausing non-essential subscriptions until next month.'
        });
      }
    }

    // 4. Weekend Spending Pattern
    if (expenses.length >= 7) {
      let weekendTotal = 0;
      let weekdayTotal = 0;
      const weekendDays = new Set();
      const weekdayDays = new Set();

      for (const tx of expenses) {
        const date = new Date(tx.timestamp);
        const day = date.getDay(); // 0 = Sunday, 6 = Saturday
        const isWeekend = day === 0 || day === 6;
        const dateStr = date.toDateString();

        if (isWeekend) {
          weekendTotal += tx.amount;
          weekendDays.add(dateStr);
        } else {
          weekdayTotal += tx.amount;
          weekdayDays.add(dateStr);
        }
      }

      if (weekendDays.size > 0 && weekdayDays.size > 0) {
        const weekendAvg = weekendTotal / weekendDays.size;
        const weekdayAvg = weekdayTotal / weekdayDays.size;

        if (weekendAvg > weekdayAvg * 1.8) {
          insights.push({
            title: 'Weekend Spending Pattern',
            severity: 'info',
            description: `You spend ${(weekendAvg / weekdayAvg).toFixed(1)}x more on weekends (${Formatters.currency(weekendAvg)}/day) than weekdays.`,
            tip: 'Planning weekend activities in advance can help avoid impulse spending.'
          });
        }
      }
    }

    // 5. Forecast / Deficit warnings
    if (monthlyIncome > 0 && totalExpenses > 0) {
      const daysElapsed = Formatters.daysElapsedInMonth();
      const daysRemaining = Formatters.daysRemainingInMonth();
      
      if (daysElapsed > 0) {
        const dailyBurn = totalExpenses / daysElapsed;
        const projectedTotal = totalExpenses + (dailyBurn * daysRemaining);
        const projectedBalance = monthlyIncome - projectedTotal;

        if (projectedBalance < 0) {
          insights.push({
            title: 'Deficit Warning',
            severity: 'critical',
            description: `At this rate, you'll overspend by ${Formatters.currency(-projectedBalance)} this month.`,
            tip: 'Look for one variable expense you can cut this week (e.g., dining out).'
          });
        } else if (projectedBalance < monthlyIncome * 0.1) {
          insights.push({
            title: 'Tight Month Ahead',
            severity: 'warning',
            description: `You'll have only ${Formatters.currency(projectedBalance)} left at month-end.`,
            tip: `Try to limit daily spending to ${Formatters.currency(projectedBalance / daysRemaining)} for the rest of the month.`
          });
        }
      }
    }

    return insights;
  },

  bindEvents(state) {
    // Close button click
    const closeBtn = document.getElementById('insights-close-btn');
    if (closeBtn) {
      closeBtn.addEventListener('click', () => {
        Router.closeOverlay();
      });
    }
  }
};
