/* Modern AI Financial Intelligence & Wealth Matrix Insights Module */
import { StateManager } from '../state.js';
import { Formatters } from '../utils/formatters.js';
import { findCategory, isInvestmentCategory } from '../utils/icons.js';

export const InsightsPage = {
  activeCategoryFilter: 'all', // 'all', 'wealth', 'budget', 'solvency'

  render(state) {
    const analysis = this.analyzeFinances(state);
    const filteredInsights = this.getFilteredInsights(analysis.insights);

    return `
      <div class="animate-fade-in" style="display: flex; flex-direction: column; gap: 24px;">
        
        <!-- Hero Header -->
        <section class="hero-section" style="padding-bottom: 0;">
          <div class="hero-header">
            <div>
              <h1 class="hero-welcome-title">Financial Intelligence</h1>
              <p class="hero-subtitle">Algorithmic capital allocation scoring, wealth velocity tracking, and proactive financial engineering.</p>
            </div>

            <div style="display: flex; gap: 10px; align-items: center;">
              <div class="kpi-badge ${analysis.healthScore >= 80 ? 'positive' : analysis.healthScore >= 60 ? 'neutral' : 'negative'}" style="padding: 8px 16px; font-size: 13px; font-weight: 700;">
                <span class="material-icons" style="font-size: 16px;">verified</span>
                ${analysis.healthTier}
              </div>
            </div>
          </div>
        </section>

        <!-- Financial Health Score & 50/30/20 Breakdown Grid -->
        <div class="health-score-grid">
          
          <!-- Health Score Box -->
          <div class="score-main-box">
            <div style="display: flex; justify-content: space-between; align-items: center;">
              <span style="font-size: 14px; font-weight: 700; color: var(--text-primary);">Financial Health Score</span>
              <span class="kpi-badge ${analysis.healthScore >= 80 ? 'positive' : 'neutral'}">${analysis.healthScore}/100</span>
            </div>

            <div class="score-circle-wrap">
              <div class="score-badge-huge">
                ${analysis.healthScore}
                <span style="font-size: 18px; font-weight: 600; color: var(--text-muted);">/100</span>
              </div>
              <div style="flex: 1;">
                <div style="font-size: 15px; font-weight: 800; color: var(--text-primary); margin-bottom: 4px;">${analysis.healthTier}</div>
                <div style="font-size: 12px; color: var(--text-secondary); line-height: 1.4;">${analysis.healthSummary}</div>
              </div>
            </div>

            <!-- Health Sub-Scores Meter -->
            <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; padding-top: 14px; border-top: 1px solid var(--glass-border);">
              <div>
                <div style="display: flex; justify-content: space-between; font-size: 11px; color: var(--text-muted); margin-bottom: 4px;">
                  <span>Wealth Velocity</span>
                  <span style="font-weight: 700; color: var(--success);">${analysis.scores.wealthRate}/35</span>
                </div>
                <div class="progress-track" style="height: 4px;">
                  <div class="progress-bar-fill safe" style="width: ${(analysis.scores.wealthRate / 35) * 100}%;"></div>
                </div>
              </div>

              <div>
                <div style="display: flex; justify-content: space-between; font-size: 11px; color: var(--text-muted); margin-bottom: 4px;">
                  <span>Budget Control</span>
                  <span style="font-weight: 700; color: var(--primary);">${analysis.scores.budgetControl}/25</span>
                </div>
                <div class="progress-track" style="height: 4px;">
                  <div class="progress-bar-fill info" style="width: ${(analysis.scores.budgetControl / 25) * 100}%;"></div>
                </div>
              </div>

              <div>
                <div style="display: flex; justify-content: space-between; font-size: 11px; color: var(--text-muted); margin-bottom: 4px;">
                  <span>Debt Solvency</span>
                  <span style="font-weight: 700; color: #a855f7;">${analysis.scores.solvency}/20</span>
                </div>
                <div class="progress-track" style="height: 4px;">
                  <div class="progress-bar-fill" style="width: ${(analysis.scores.solvency / 20) * 100}%; background: #a855f7;"></div>
                </div>
              </div>

              <div>
                <div style="display: flex; justify-content: space-between; font-size: 11px; color: var(--text-muted); margin-bottom: 4px;">
                  <span>Runway Cushion</span>
                  <span style="font-weight: 700; color: #f59e0b;">${analysis.scores.runway}/20</span>
                </div>
                <div class="progress-track" style="height: 4px;">
                  <div class="progress-bar-fill warning" style="width: ${(analysis.scores.runway / 20) * 100}%;"></div>
                </div>
              </div>
            </div>
          </div>

          <!-- 50/30/20 Macro Allocation Card -->
          <div class="score-breakdown-card">
            <div>
              <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
                <span style="font-size: 14px; font-weight: 700; color: var(--text-primary);">50/30/20 Capital Allocation Matrix</span>
                <span style="font-size: 12px; font-weight: 700; color: ${analysis.wealthPct >= 20 ? 'var(--success)' : 'var(--text-muted)'};">
                  ${analysis.wealthPct >= 20 ? '🎉 Wealth Target Beaten!' : 'Target: 20%+ Wealth'}
                </span>
              </div>
              <p style="font-size: 12px; color: var(--text-muted); margin-bottom: 12px;">Needs (50%) • Wants (30%) • Wealth & Investments (20%+)</p>

              <!-- Segmented Bar -->
              <div class="allocation-bar">
                <div class="alloc-seg needs" style="width: ${analysis.needsPct}%;" title="Needs: ${analysis.needsPct}%"></div>
                <div class="alloc-seg wants" style="width: ${analysis.wantsPct}%;" title="Wants: ${analysis.wantsPct}%"></div>
                <div class="alloc-seg wealth" style="width: ${analysis.wealthPct}%;" title="Wealth & Savings: ${analysis.wealthPct}%"></div>
              </div>

              <!-- Allocation Legend -->
              <div class="alloc-legend-grid">
                <div class="alloc-legend-item">
                  <div style="font-size: 12px; font-weight: 700; color: var(--text-primary);">
                    <span class="alloc-dot" style="background: var(--primary);"></span>Needs (${analysis.needsPct}%)
                  </div>
                  <div style="font-size: 13px; font-weight: 800; color: var(--text-secondary); margin-left: 14px;">
                    ${Formatters.currency(analysis.needsAmount)}
                  </div>
                </div>

                <div class="alloc-legend-item">
                  <div style="font-size: 12px; font-weight: 700; color: var(--text-primary);">
                    <span class="alloc-dot" style="background: #f59e0b;"></span>Wants (${analysis.wantsPct}%)
                  </div>
                  <div style="font-size: 13px; font-weight: 800; color: var(--text-secondary); margin-left: 14px;">
                    ${Formatters.currency(analysis.wantsAmount)}
                  </div>
                </div>

                <div class="alloc-legend-item">
                  <div style="font-size: 12px; font-weight: 700; color: var(--success);">
                    <span class="alloc-dot" style="background: var(--success);"></span>Wealth & Assets (${analysis.wealthPct}%)
                  </div>
                  <div style="font-size: 13px; font-weight: 800; color: var(--success); margin-left: 14px;">
                    ${Formatters.currency(analysis.wealthAmount)}
                  </div>
                </div>
              </div>
            </div>

            <div style="background: rgba(255,255,255,0.03); border: 1px solid var(--glass-border); padding: 10px 14px; border-radius: var(--radius-md); font-size: 12px; color: var(--text-secondary);">
              <b>Allocation Verdict:</b> ${analysis.allocationVerdict}
            </div>
          </div>

        </div>

        <!-- Filter Chips Bar -->
        <div style="display: flex; gap: 8px; flex-wrap: wrap; align-items: center; justify-content: space-between;">
          <div class="filter-group" style="padding: 4px;">
            ${[
              { id: 'all', label: 'All Intelligence', count: analysis.insights.length },
              { id: 'wealth', label: 'Wealth & Investments', count: analysis.insights.filter(i => i.type === 'wealth').length },
              { id: 'budget', label: 'Budget & Leakages', count: analysis.insights.filter(i => i.type === 'budget').length },
              { id: 'solvency', label: 'Safety & Solvency', count: analysis.insights.filter(i => i.type === 'solvency').length },
            ].map(tab => `
              <button class="filter-chip ${this.activeCategoryFilter === tab.id ? 'active' : ''}" data-type-filter="${tab.id}">
                ${tab.label} (${tab.count})
              </button>
            `).join('')}
          </div>

          <div style="font-size: 12px; color: var(--text-muted);">
            Showing ${filteredInsights.length} active observations
          </div>
        </div>

        <!-- Insights List Feed -->
        ${filteredInsights.length === 0 ? `
          <div class="fintech-card" style="text-align: center; padding: 60px 20px; color: var(--text-muted);">
            <div style="width: 56px; height: 56px; border-radius: 50%; background: rgba(255,255,255,0.04); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px;">
              <span class="material-icons" style="font-size: 28px; opacity: 0.5;">check_circle</span>
            </div>
            <div style="font-size: 16px; font-weight: 600; color: var(--text-primary); margin-bottom: 6px;">No alerts in this category</div>
            <div style="font-size: 13px;">Your financial behavior is running in optimal balance.</div>
          </div>
        ` : `
          <div class="insights-feed">
            ${filteredInsights.map(item => {
              const isWarning = item.severity === 'warning';
              const isPraise = item.severity === 'praise' || item.severity === 'success';
              
              let iconName = item.icon || 'lightbulb';
              let iconColor = 'var(--primary)';
              let iconBg = 'rgba(56, 189, 248, 0.12)';
              let badgeClass = 'neutral';

              if (isPraise) {
                iconName = item.icon || 'trending_up';
                iconColor = 'var(--success)';
                iconBg = 'var(--success-bg)';
                badgeClass = 'positive';
              } else if (isWarning) {
                iconName = item.icon || 'warning_amber';
                iconColor = 'var(--error)';
                iconBg = 'var(--error-bg)';
                badgeClass = 'negative';
              }

              return `
                <div class="insight-card">
                  <div class="insight-icon-box" style="background: ${iconBg}; color: ${iconColor};">
                    <span class="material-icons">${iconName}</span>
                  </div>
                  <div class="insight-content">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; flex-wrap: wrap; gap: 8px;">
                      <div class="insight-title">${item.title}</div>
                      <span class="kpi-badge ${badgeClass}">
                        ${item.badge || item.severity.toUpperCase()}
                      </span>
                    </div>
                    <div class="insight-desc">${item.description}</div>
                    ${item.tip ? `
                      <div class="insight-tip" style="${isPraise ? 'border-left-color: var(--success); background: rgba(0, 229, 153, 0.05);' : ''}">
                        <b>${isPraise ? '💡 Wealth Acceleration Strategy:' : '💡 Actionable Strategy:'}</b> ${item.tip}
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

  getFilteredInsights(insights) {
    if (this.activeCategoryFilter === 'all') return insights;
    return insights.filter(i => i.type === this.activeCategoryFilter);
  },

  analyzeFinances(state) {
    const insights = [];
    const transactions = state.transactions || [];
    const categories = state.categories || [];
    const assets = state.assets || [];
    const goals = state.goals || [];
    const userSettings = state.userSettings || {};

    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    
    // Transactions this month
    const thisMonthTx = transactions.filter(t => new Date(t.timestamp || t.created_at) >= startOfMonth);
    const expenses = thisMonthTx.filter(t => t.type === 'expense');
    const incomes = thisMonthTx.filter(t => t.type === 'income');

    const monthlyIncomeSetting = Number(userSettings.monthlyIncome || userSettings.monthly_income || 0);
    const loggedIncome = incomes.reduce((sum, t) => sum + Number(t.amount || 0), 0);
    const totalIncome = loggedIncome > 0 ? loggedIncome : (monthlyIncomeSetting > 0 ? monthlyIncomeSetting : 0);

    // Breakdown categories: Needs, Wants, Wealth
    let needsAmount = 0;
    let wantsAmount = 0;
    let investmentAmount = 0;
    let savingsAmount = 0;

    const needsCategoryNames = ['bills & utilities', 'groceries', 'transport', 'health', 'education', 'family'];
    const categoryExpenses = {};

    for (const tx of expenses) {
      const amount = Number(tx.amount || 0);
      const cat = findCategory(categories, tx.categoryId || tx.category_id);
      const catName = (cat ? cat.name : 'Other').toLowerCase();

      categoryExpenses[cat ? cat.name : 'Other'] = (categoryExpenses[cat ? cat.name : 'Other'] || 0) + amount;

      if (isInvestmentCategory(categories, tx.categoryId || tx.category_id)) {
        investmentAmount += amount;
      } else if (catName === 'savings' || cat?.icon === 'savings' || tx.goalId || tx.goal_id) {
        savingsAmount += amount;
      } else if (needsCategoryNames.some(n => catName.includes(n))) {
        needsAmount += amount;
      } else {
        wantsAmount += amount;
      }
    }

    const wealthAmount = investmentAmount + savingsAmount;
    const totalOutflow = expenses.reduce((sum, t) => sum + Number(t.amount || 0), 0);
    const pureConsumptionExpense = needsAmount + wantsAmount;

    // Macro percentages
    const baseTotal = totalOutflow > 0 ? totalOutflow : 1;
    const needsPct = Math.round((needsAmount / baseTotal) * 100);
    const wantsPct = Math.round((wantsAmount / baseTotal) * 100);
    const wealthPct = Math.min(100, Math.max(0, 100 - needsPct - wantsPct));

    // 1. WEALTH SCENARIOS (Praising Investments & Savings!)
    if (investmentAmount > 0) {
      const investRatio = Math.round((investmentAmount / baseTotal) * 100);
      insights.push({
        type: 'wealth',
        title: `Asset Compounding: ${Formatters.currency(investmentAmount)} Deployed`,
        severity: 'praise',
        badge: 'WEALTH ACCUMULATION',
        icon: 'trending_up',
        description: `Outstanding capital allocation! You channeled ${Formatters.currency(investmentAmount)} (${investRatio}% of your outflow) into Investments this month. Unlike consumable expenses, this directly increases your Net Worth and compounds future wealth.`,
        tip: 'Maintaining steady monthly investments across equity index funds, SIPs, and growth assets is the single most reliable driver of financial independence.'
      });
    }

    if (savingsAmount > 0) {
      insights.push({
        type: 'wealth',
        title: `Capital Preservation: ${Formatters.currency(savingsAmount)} Retained`,
        severity: 'praise',
        badge: 'DISCIPLINED SAVER',
        icon: 'savings',
        description: `You successfully allocated ${Formatters.currency(savingsAmount)} into dedicated savings reserves and milestone goals this month.`,
        tip: 'Ensure your liquid cash safety buffer covers at least 3-6 months of essential living expenses before directing additional capital to growth assets.'
      });
    }

    if (wealthPct >= 20) {
      insights.push({
        type: 'wealth',
        title: `50/30/20 Wealth Rule Exceeded (${wealthPct}%)`,
        severity: 'praise',
        badge: 'ELITE WEALTH RATE',
        icon: 'auto_awesome',
        description: `Personal finance benchmarks recommend a 20% savings/investment rate. You achieved ${wealthPct}%, retaining the majority of your earnings for your balance sheet.`,
        tip: 'Consider automating your monthly investment transfers right on payday to lock in this compounding advantage.'
      });
    }

    // 2. OPERATING CONSUMPTION EFFICIENCY
    const dailyConsumption = now.getDate() > 0 ? pureConsumptionExpense / now.getDate() : 0;
    if (pureConsumptionExpense > 0 && (totalIncome === 0 || pureConsumptionExpense < totalIncome * 0.6)) {
      insights.push({
        type: 'wealth',
        title: `Lean Consumption Burn Rate: ${Formatters.currency(Math.round(dailyConsumption))}/day`,
        severity: 'praise',
        badge: 'OPTIMAL EFFICIENCY',
        icon: 'speed',
        description: `Your pure lifestyle consumption (excluding investments and savings) is only ${Formatters.currency(pureConsumptionExpense)} this month. You are maintaining low consumer overhead while expanding asset equity.`,
        tip: 'Keeping fixed lifestyle overhead lean creates permanent financial freedom.'
      });
    }

    // 3. BUDGET & LEAKAGE AUDIT (Nuanced: NEVER warns on Investments/Savings)
    for (const [name, amount] of Object.entries(categoryExpenses)) {
      const lowerName = name.toLowerCase();
      // Skip wealth categories completely from overspending warnings!
      if (lowerName === 'investments' || lowerName === 'investment' || lowerName === 'savings') {
        continue;
      }

      const ratio = pureConsumptionExpense > 0 ? amount / pureConsumptionExpense : 0;
      if (ratio >= 0.35 && amount > 2000) {
        insights.push({
          type: 'budget',
          title: `${name} Dominates ${Math.round(ratio * 100)}% of Lifestyle Outflow`,
          severity: 'warning',
          badge: 'BUDGET ADVISORY',
          icon: 'pie_chart',
          description: `${Formatters.currency(amount)} of your consumption spending went to ${name}. Setting a weekly budget cap will prevent month-end cash flow pressure.`,
          tip: `Head to the Budget tab to set an active monthly target cap for ${name}.`
        });
      }
    }

    // 4. WEEKEND LEISURE BEHAVIOR
    const leisureCategories = ['food & dining', 'shopping', 'entertainment', 'self care'];
    const leisureTx = expenses.filter(t => {
      const cat = findCategory(categories, t.categoryId || t.category_id);
      return leisureCategories.some(l => (cat?.name || '').toLowerCase().includes(l));
    });

    if (leisureTx.length >= 3) {
      let weekendSpend = 0;
      let totalLeisure = 0;
      for (const t of leisureTx) {
        const d = new Date(t.timestamp || t.created_at);
        const day = d.getDay(); // 0 = Sun, 5 = Fri, 6 = Sat
        const amt = Number(t.amount || 0);
        totalLeisure += amt;
        if (day === 0 || day === 5 || day === 6) {
          weekendSpend += amt;
        }
      }

      if (totalLeisure > 3000 && (weekendSpend / totalLeisure) >= 0.55) {
        const weekendPct = Math.round((weekendSpend / totalLeisure) * 100);
        insights.push({
          type: 'budget',
          title: `Weekend Leisure Clustering (${weekendPct}%)`,
          severity: 'info',
          badge: 'BEHAVIORAL HABIT',
          icon: 'weekend',
          description: `${Formatters.currency(weekendSpend)} of your discretionary dining & entertainment spending occurs on weekends (Fri-Sun).`,
          tip: 'Allocating a designated weekly "Weekend Fun Envelope" lets you enjoy social outings guilt-free without exceeding your overall target.'
        });
      }
    }

    // 5. RECURRING SUBSCRIPTION COMMITMENTS
    const recurringExpenses = expenses.filter(t => t.isRecurring || t.is_recurring);
    if (recurringExpenses.length > 0) {
      const recurringTotal = recurringExpenses.reduce((sum, t) => sum + Number(t.amount || 0), 0);
      const annualized = recurringTotal * 12;
      insights.push({
        type: 'budget',
        title: `${recurringExpenses.length} Fixed Subscriptions (${Formatters.currency(annualized)}/yr)`,
        severity: 'info',
        badge: 'RECURRING AUDIT',
        icon: 'autorenew',
        description: `You have ${recurringExpenses.length} automated commitments totaling ${Formatters.currency(recurringTotal)}/mo, which equals ${Formatters.currency(annualized)} annually.`,
        tip: 'Regularly audit recurring subscriptions to eliminate unused streaming, SaaS, or fitness memberships.'
      });
    }

    // 6. EMERGENCY RUNWAY & BUFFER
    let liquidCash = 0;
    let totalAssetsVal = 0;
    let totalLiabVal = 0;

    assets.forEach(a => {
      const val = Number(a.value || 0);
      if (a.is_liability || a.isLiability) {
        totalLiabVal += val;
      } else {
        totalAssetsVal += val;
        if (a.type === 'savings' || a.name?.toLowerCase().includes('cash') || a.name?.toLowerCase().includes('bank') || a.name?.toLowerCase().includes('savings')) {
          liquidCash += val;
        }
      }
    });

    const monthlyEssentialBurn = needsAmount > 0 ? needsAmount : (totalOutflow > 0 ? totalOutflow * 0.5 : 20000);
    const runwayMonths = monthlyEssentialBurn > 0 ? (liquidCash / monthlyEssentialBurn) : 0;

    if (runwayMonths >= 6) {
      insights.push({
        type: 'solvency',
        title: `Fortress Emergency Runway: ${runwayMonths.toFixed(1)} Months`,
        severity: 'praise',
        badge: 'FORTRESS BUFFER',
        icon: 'security',
        description: `You have ${Formatters.currency(liquidCash)} in liquid savings, providing over ${runwayMonths.toFixed(0)} months of essential living expenses safely preserved.`,
        tip: 'Your liquid safety cushion is secure. Any new surplus capital can now be directed toward higher-yielding equity or goal acceleration.'
      });
    } else if (runwayMonths >= 3) {
      insights.push({
        type: 'solvency',
        title: `Optimal Safety Cushion: ${runwayMonths.toFixed(1)} Months`,
        severity: 'success',
        badge: 'SOLID RUNWAY',
        icon: 'shield',
        description: `Your liquid cash reserves (${Formatters.currency(liquidCash)}) cover ${runwayMonths.toFixed(1)} months of baseline living costs.`,
        tip: 'Continue maintaining 3-6 months in high-yield liquid accounts before taking on higher-risk investments.'
      });
    }

    // 7. DEBT-FREE FREEDOM / SOLVENCY
    const debtRatio = totalAssetsVal > 0 ? Math.round((totalLiabVal / totalAssetsVal) * 100) : 0;
    if (totalLiabVal === 0 && totalAssetsVal > 0) {
      insights.push({
        type: 'solvency',
        title: '100% Debt-Free Solvency Status',
        severity: 'praise',
        badge: 'DEBT FREE TIER',
        icon: 'workspace_premium',
        description: `You have zero liabilities across your entire balance sheet. 100% of your ${Formatters.currency(totalAssetsVal)} asset base belongs completely to you.`,
        tip: 'Staying debt-free eliminates compound interest drag and maximizes the capital available for personal wealth creation.'
      });
    } else if (debtRatio > 50) {
      insights.push({
        type: 'solvency',
        title: `Elevated Leverage Exposure (${debtRatio}% Debt Ratio)`,
        severity: 'warning',
        badge: 'DE-LEVERAGE PRIORITY',
        icon: 'account_balance',
        description: `Total liabilities (${Formatters.currency(totalLiabVal)}) represent ${debtRatio}% of your gross asset holdings.`,
        tip: 'Prioritize high-interest debt payoffs using the Avalanche method to reduce interest leakage.'
      });
    }

    // 8. GOAL MILESTONE FINISH FORECASTS
    const activeGoals = goals.filter(g => g.is_active !== false && !g.is_completed);
    for (const g of activeGoals.slice(0, 2)) {
      const target = Number(g.targetAmount || g.target_amount || 0);
      const saved = Number(g.savedAmount || g.saved_amount || 0);
      const remaining = Math.max(0, target - saved);
      
      if (remaining > 0 && totalIncome > 0) {
        const estimatedPace = Math.max(savingsAmount, 5000);
        const monthsLeft = Math.ceil(remaining / estimatedPace);
        insights.push({
          type: 'solvency',
          title: `Goal Pacing: "${g.name}" (~${monthsLeft} mo to Completion)`,
          severity: 'info',
          badge: 'MILESTONE PROJECTION',
          icon: 'flag',
          description: `You have accumulated ${Formatters.currency(saved)} of ${Formatters.currency(target)} for "${g.name}". At your current savings momentum, this goal will be fully funded in ~${monthsLeft} months.`,
          tip: `Keep adding regular contributions to celebrate this milestone on schedule!`
        });
      }
    }

    // SCORING ENGINE (0-100 pts)
    // 1. Wealth Rate Score (0-35)
    let wealthScore = Math.min(35, Math.round((wealthPct / 30) * 35));
    if (investmentAmount > 0) wealthScore = Math.max(wealthScore, 28);
    
    // 2. Budget Control Score (0-25)
    const budgetScore = pureConsumptionExpense <= (totalIncome > 0 ? totalIncome * 0.7 : 50000) ? 25 : 16;
    
    // 3. Solvency Score (0-20)
    const solvencyScore = totalLiabVal === 0 ? 20 : (debtRatio < 30 ? 15 : 8);

    // 4. Runway Buffer Score (0-20)
    const runwayScore = runwayMonths >= 6 ? 20 : (runwayMonths >= 3 ? 16 : (runwayMonths >= 1 ? 10 : 5));

    const totalHealthScore = Math.min(100, wealthScore + budgetScore + solvencyScore + runwayScore);

    let healthTier = 'Wealth Builder';
    let healthSummary = 'Great financial balance. Continue investing and growing your safety cushion.';
    if (totalHealthScore >= 90) {
      healthTier = 'Elite Wealth Accumulator';
      healthSummary = 'Top 5% financial discipline. High investment velocity, low consumption drag, and zero toxic debt.';
    } else if (totalHealthScore >= 80) {
      healthTier = 'Pristine Financial Health';
      healthSummary = 'Solid capital retention rate and strong asset allocation trajectory.';
    } else if (totalHealthScore >= 65) {
      healthTier = 'Stable Capital Stance';
      healthSummary = 'Consistent pacing. Consider expanding monthly investment contributions.';
    } else {
      healthTier = 'Building Foundation';
      healthSummary = 'Focus on trimming discretionary leakages and building a 3-month liquid buffer.';
    }

    let allocationVerdict = 'Optimal 50/30/20 balance. High wealth allocation and lean living costs.';
    if (wealthPct >= 30) {
      allocationVerdict = `🔥 Supercharged Wealth Velocity! You are routing ${wealthPct}% of your money into assets and compounding investments.`;
    } else if (wealthPct >= 20) {
      allocationVerdict = `✅ Golden Rule Met! ${wealthPct}% allocated to wealth creation exceeds standard 20% financial independence targets.`;
    } else if (wantsPct > 45) {
      allocationVerdict = `⚠️ Discretionary Wants (${wantsPct}%) are higher than recommended. Shift 10% into automated investments.`;
    }

    return {
      healthScore: totalHealthScore,
      healthTier,
      healthSummary,
      allocationVerdict,
      needsAmount,
      wantsAmount,
      wealthAmount,
      needsPct,
      wantsPct,
      wealthPct,
      scores: {
        wealthRate: wealthScore,
        budgetControl: budgetScore,
        solvency: solvencyScore,
        runway: runwayScore
      },
      insights
    };
  },

  bindEvents(state) {
    // Filter chip clicks for intelligence categories
    const chips = document.querySelectorAll('.filter-chip[data-type-filter]');
    chips.forEach(chip => {
      chip.addEventListener('click', () => {
        this.activeCategoryFilter = chip.getAttribute('data-type-filter');
        StateManager.notify();
      });
    });
  }
};
