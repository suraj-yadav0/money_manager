/* Modern Savings Goals & Milestones Module */
import { StateManager } from '../state.js';
import { DbService } from '../db.js';
import { Formatters } from '../utils/formatters.js';
import { findCategory } from '../utils/icons.js';

export const GoalsPage = {
  activeGoalFilter: 'active', // 'active', 'completed', 'archived'

  render(state) {
    const goals = this.getFilteredGoals(state);
    
    // Stats
    let totalTarget = 0;
    let totalSaved = 0;
    state.goals.forEach(g => {
      if (g.is_active !== false) {
        totalTarget += Number(g.targetAmount || g.target_amount || 0);
        totalSaved += Number(g.savedAmount || g.saved_amount || 0);
      }
    });
    const overallProgress = totalTarget > 0 ? Math.min(100, Math.round((totalSaved / totalTarget) * 100)) : 0;

    return `
      <div class="animate-fade-in" style="display: flex; flex-direction: column; gap: 28px;">
        
        <!-- Hero Header -->
        <section class="hero-section" style="padding-bottom: 0;">
          <div class="hero-header">
            <div>
              <h1 class="hero-welcome-title">Savings Goals</h1>
              <p class="hero-subtitle">Define capital accumulation targets, automate milestone tracking, and watch your wealth compound.</p>
            </div>
            
            <button class="btn-primary" id="create-goal-btn">
              <span class="material-icons" style="font-size: 18px;">add</span> Create New Goal
            </button>
          </div>

          <!-- Goals KPI Stat Cards -->
          <div class="kpi-grid">
            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Total Capital Saved</span>
                <div class="kpi-icon-box" style="background: rgba(16, 185, 129, 0.12); color: var(--primary);">
                  <span class="material-icons" style="font-size: 20px;">savings</span>
                </div>
              </div>
              <div class="kpi-value" style="color: var(--primary);">${Formatters.currency(totalSaved)}</div>
              <div class="kpi-footer">
                <span class="kpi-badge positive">${overallProgress}% Overall Target</span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Cumulative Target</span>
                <div class="kpi-icon-box" style="background: rgba(56, 189, 248, 0.12); color: var(--secondary);">
                  <span class="material-icons" style="font-size: 20px;">flag</span>
                </div>
              </div>
              <div class="kpi-value">${Formatters.currency(totalTarget)}</div>
              <div class="kpi-footer">
                <span>Across all active goals</span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Remaining to Goal</span>
                <div class="kpi-icon-box" style="background: rgba(99, 102, 241, 0.12); color: var(--indigo);">
                  <span class="material-icons" style="font-size: 20px;">trending_up</span>
                </div>
              </div>
              <div class="kpi-value">${Formatters.currency(Math.max(0, totalTarget - totalSaved))}</div>
              <div class="kpi-footer">
                <span>Required capital</span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Active Milestones</span>
                <div class="kpi-icon-box" style="background: rgba(245, 158, 11, 0.12); color: var(--warning);">
                  <span class="material-icons" style="font-size: 20px;">stars</span>
                </div>
              </div>
              <div class="kpi-value">${state.goals.filter(g => g.is_active !== false && !g.is_completed).length}</div>
              <div class="kpi-footer">
                <span>${state.goals.filter(g => g.is_completed).length} completed</span>
              </div>
            </div>
          </div>
        </section>

        <!-- Filter Chips -->
        <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 16px;">
          <div class="filter-group">
            <button class="filter-chip ${this.activeGoalFilter === 'active' ? 'active' : ''}" data-status="active">Active Goals</button>
            <button class="filter-chip ${this.activeGoalFilter === 'completed' ? 'active' : ''}" data-status="completed">Completed</button>
            <button class="filter-chip ${this.activeGoalFilter === 'archived' ? 'active' : ''}" data-status="archived">Archived</button>
          </div>
        </div>

        <!-- Goals Cards Grid -->
        ${goals.length === 0 ? `
          <div class="fintech-card" style="text-align: center; padding: 60px 20px; color: var(--text-muted);">
            <div style="width: 56px; height: 56px; border-radius: 50%; background: rgba(255,255,255,0.04); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px;">
              <span class="material-icons" style="font-size: 28px; opacity: 0.5;">savings</span>
            </div>
            <div style="font-size: 16px; font-weight: 600; color: var(--text-primary); margin-bottom: 6px;">No goals found in this view</div>
            <div style="font-size: 13px; margin-bottom: 20px;">Create a new milestone like emergency fund, vacation, or down payment.</div>
            <button class="btn-primary" id="empty-goal-btn" style="width: auto;">
              <span class="material-icons" style="font-size: 16px;">add</span> Create Goal
            </button>
          </div>
        ` : `
          <div class="goals-grid">
            ${goals.map(goal => {
              const target = Number(goal.targetAmount || goal.target_amount || 0);
              const saved = Number(goal.savedAmount || goal.saved_amount || 0);
              const pct = target > 0 ? Math.min(100, Math.round((saved / target) * 100)) : 0;
              const isCompleted = goal.is_completed || pct >= 100;

              return `
                <div class="goal-card">
                  <div>
                    <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px;">
                      <div style="font-weight: 800; font-size: 18px; color: var(--text-primary);">${goal.name}</div>
                      <span class="kpi-badge ${isCompleted ? 'positive' : 'neutral'}">
                        ${isCompleted ? 'Completed' : `${pct}%`}
                      </span>
                    </div>

                    <div style="font-size: 24px; font-weight: 800; color: var(--text-primary); font-family: var(--font-heading); margin-bottom: 4px;">
                      ${Formatters.currency(saved)}
                      <span style="font-size: 14px; font-weight: 600; color: var(--text-muted);">/ ${Formatters.currency(target)}</span>
                    </div>

                    <div class="progress-track" style="margin: 12px 0 16px;">
                      <div class="progress-bar-fill safe" style="width: ${pct}%;"></div>
                    </div>

                    <div style="display: flex; justify-content: space-between; font-size: 12px; color: var(--text-muted); margin-bottom: 20px;">
                      <span>Deadline: ${Formatters.shortDate(goal.deadline)}</span>
                      <span>${Math.max(0, target - saved) > 0 ? `${Formatters.currency(target - saved)} left` : 'Fully Funded'}</span>
                    </div>
                  </div>

                  <div style="display: flex; justify-content: space-between; align-items: center; padding-top: 14px; border-top: 1px solid var(--glass-border);">
                    <div style="display: flex; gap: 8px;">
                      <button class="btn-ghost view-goal-contribs-btn" 
                              data-sync-id="${goal.sync_id || ''}" 
                              data-id="${goal.id || ''}" 
                              style="padding: 6px 10px; font-size: 12px;">
                        <span class="material-icons" style="font-size: 14px;">history</span> History
                      </button>
                      <button class="btn-ghost delete-goal-btn" 
                              data-sync-id="${goal.sync_id || ''}" 
                              data-id="${goal.id || ''}" 
                              style="padding: 6px 10px; font-size: 12px; color: var(--error);">
                        <span class="material-icons" style="font-size: 14px;">delete_outline</span>
                      </button>
                    </div>

                    ${!isCompleted ? `
                      <button class="btn-primary add-goal-contrib-btn" 
                              data-sync-id="${goal.sync_id || ''}" 
                              data-id="${goal.id || ''}"
                              style="padding: 6px 14px; font-size: 12px;">
                        <span class="material-icons" style="font-size: 14px;">add</span> Add Capital
                      </button>
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

  getFilteredGoals(state) {
    return state.goals.filter(g => {
      if (this.activeGoalFilter === 'active') {
        return g.is_active !== false && !g.is_completed;
      } else if (this.activeGoalFilter === 'completed') {
        return g.is_completed === true;
      } else if (this.activeGoalFilter === 'archived') {
        return g.is_active === false;
      }
      return true;
    });
  },

  bindEvents(state) {
    // Filter chip clicks
    const chips = document.querySelectorAll('.filter-chip[data-status]');
    chips.forEach(chip => {
      chip.addEventListener('click', () => {
        this.activeGoalFilter = chip.getAttribute('data-status');
        StateManager.notify();
      });
    });

    // Create Goal buttons
    const openCreate = () => this.showCreateGoalModal();
    document.getElementById('create-goal-btn')?.addEventListener('click', openCreate);
    document.getElementById('empty-goal-btn')?.addEventListener('click', openCreate);

    // Delete Goal button
    const deleteBtns = document.querySelectorAll('.delete-goal-btn');
    deleteBtns.forEach(btn => {
      btn.addEventListener('click', async () => {
        const syncId = btn.getAttribute('data-sync-id');
        const localId = btn.getAttribute('data-id');
        if (confirm('Delete this goal and linked records?')) {
          await DbService.deleteGoal(syncId, localId);
        }
      });
    });

    // Add Contribution button
    const addContribBtns = document.querySelectorAll('.add-goal-contrib-btn');
    addContribBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const syncId = btn.getAttribute('data-sync-id');
        const localId = btn.getAttribute('data-id');
        const goal = state.goals.find(g => (syncId && g.sync_id === syncId) || (localId && String(g.id) === String(localId)));
        if (goal) this.showAddContributionModal(goal);
      });
    });

    // History button
    const historyBtns = document.querySelectorAll('.view-goal-contribs-btn');
    historyBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const syncId = btn.getAttribute('data-sync-id');
        const localId = btn.getAttribute('data-id');
        const goal = state.goals.find(g => (syncId && g.sync_id === syncId) || (localId && String(g.id) === String(localId)));
        if (goal) this.showContributionHistoryModal(goal, state.goalContributions);
      });
    });
  },

  showCreateGoalModal() {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 440px;">
        <div class="modal-header">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary);">savings</span>
            <span>New Savings Goal</span>
          </div>
          <button class="modal-close-btn" id="modal-close-create-goal" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <div class="form-group">
          <label class="form-label">Goal Title</label>
          <input type="text" class="form-control" id="goal-name-field" placeholder="e.g. Emergency Fund, New Laptop">
        </div>

        <div class="form-group">
          <label class="form-label">Target Capital (₹)</label>
          <input type="number" class="form-control" id="goal-target-field" placeholder="100000">
        </div>

        <div class="form-group">
          <label class="form-label">Target Deadline</label>
          <input type="date" class="form-control" id="goal-deadline-field" value="${new Date(Date.now() + 90 * 86400000).toISOString().substring(0, 10)}">
        </div>

        <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 24px; padding-top: 16px; border-top: 1px solid var(--glass-border);">
          <button class="btn-secondary" id="modal-cancel-goal" style="width: auto;">Cancel</button>
          <button class="btn-primary" id="modal-submit-goal" style="width: auto;">Create Goal</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);
    const closeModal = () => { if (document.body.contains(overlay)) document.body.removeChild(overlay); };

    document.getElementById('modal-close-goal')?.addEventListener('click', closeModal);
    document.getElementById('modal-cancel-goal')?.addEventListener('click', closeModal);
    document.getElementById('modal-close-create-goal')?.addEventListener('click', closeModal);

    document.getElementById('modal-submit-goal')?.addEventListener('click', async () => {
      const name = document.getElementById('goal-name-field').value.trim();
      const target = parseFloat(document.getElementById('goal-target-field').value);
      const deadline = document.getElementById('goal-deadline-field').value;

      if (!name || isNaN(target) || target <= 0) {
        alert('Please provide a valid goal name and target amount.');
        return;
      }

      await DbService.addGoal({
        name,
        targetAmount: target,
        deadline: new Date(deadline).toISOString()
      });

      closeModal();
      StateManager.notify();
    });
  },

  showAddContributionModal(goal) {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 420px;">
        <div class="modal-header">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary);">add_circle</span>
            <span>Fund: ${goal.name}</span>
          </div>
          <button class="modal-close-btn" id="modal-close-contrib" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <div class="form-group">
          <label class="form-label">Contribution Amount (₹)</label>
          <input type="number" class="form-control" id="contrib-amount-field" placeholder="5000" autofocus>
        </div>

        <div class="form-group">
          <label class="form-label">Note / Reference (Optional)</label>
          <input type="text" class="form-control" id="contrib-note-field" placeholder="e.g. Monthly allocation">
        </div>

        <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 24px; padding-top: 16px; border-top: 1px solid var(--glass-border);">
          <button class="btn-secondary" id="modal-cancel-contrib" style="width: auto;">Cancel</button>
          <button class="btn-primary" id="modal-submit-contrib" style="width: auto;">Confirm Deposit</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);
    const closeModal = () => { if (document.body.contains(overlay)) document.body.removeChild(overlay); };

    document.getElementById('modal-close-contrib')?.addEventListener('click', closeModal);
    document.getElementById('modal-cancel-contrib')?.addEventListener('click', closeModal);

    document.getElementById('modal-submit-contrib')?.addEventListener('click', async () => {
      const amount = parseFloat(document.getElementById('contrib-amount-field').value);
      const note = document.getElementById('contrib-note-field').value.trim();

      if (isNaN(amount) || amount <= 0) {
        alert('Please enter a valid amount.');
        return;
      }

      await DbService.addGoalContribution(goal.sync_id, goal.id, amount, note);
      
      const now = new Date().toISOString();
      const savingsCategory = findCategory(StateManager.state.categories, 'Savings');
      const catId = savingsCategory ? (savingsCategory.id || savingsCategory.sync_id) : 11;
      const cleanGoalId = goal.sync_id || goal.id;
      
      await DbService.addTransaction({
        amount: amount,
        type: 'expense',
        categoryId: catId,
        category_id: catId,
        goalId: cleanGoalId,
        goal_id: cleanGoalId,
        timestamp: now,
        note: `Goal Deposit: ${goal.name}${note ? ' - ' + note : ''}`,
        paymentMode: 'Bank Transfer',
        payment_mode: 'Bank Transfer'
      });

      closeModal();
      StateManager.notify();
    });
  },

  showContributionHistoryModal(goal, allContributions) {
    const goalContribs = allContributions
      .filter(c => c.goal_id === goal.id || c.goal_id === goal.sync_id || c.goalId === goal.id || c.goalId === goal.sync_id)
      .sort((a, b) => new Date(b.created_at || b.createdAt) - new Date(a.created_at || a.createdAt));

    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 460px;">
        <div class="modal-header">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary);">history</span>
            <span>Deposits: ${goal.name}</span>
          </div>
          <button class="modal-close-btn" id="modal-close-history" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <div style="max-height: 50vh; overflow-y: auto; display: flex; flex-direction: column; gap: 10px; padding-right: 4px;">
          ${goalContribs.length === 0 ? `
            <div style="text-align: center; padding: 32px 0; color: var(--text-muted); font-size: 13px;">No deposits recorded for this goal yet.</div>
          ` : goalContribs.map(c => `
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 12px 14px; background: rgba(255,255,255,0.03); border: 1px solid var(--glass-border); border-radius: var(--radius-md);">
              <div>
                <div style="font-weight: 700; font-size: 15px; color: var(--success);">+${Formatters.currency(c.amount)}</div>
                <div style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">${c.note || 'Savings Deposit'}</div>
              </div>
              <div style="font-size: 11px; color: var(--text-muted);">${Formatters.dateTime(c.created_at || c.createdAt)}</div>
            </div>
          `).join('')}
        </div>
      </div>
    `;

    document.body.appendChild(overlay);
    const closeModal = () => { if (document.body.contains(overlay)) document.body.removeChild(overlay); };
    document.getElementById('modal-close-history')?.addEventListener('click', closeModal);
  }
};
