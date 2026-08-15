/* Modern Net Worth & Asset Intelligence Module */
import { StateManager } from '../state.js';
import { DbService } from '../db.js';
import { Formatters } from '../utils/formatters.js';

export const NetWorthPage = {
  render(state) {
    const assets = state.assets || [];
    
    let totalAssets = 0;
    let totalLiabilities = 0;

    assets.forEach(a => {
      const val = Number(a.value || 0);
      if (a.is_liability || a.isLiability) {
        totalLiabilities += val;
      } else {
        totalAssets += val;
      }
    });

    const netWorth = totalAssets - totalLiabilities;
    const debtRatio = totalAssets > 0 ? Math.round((totalLiabilities / totalAssets) * 100) : 0;

    return `
      <div class="animate-fade-in" style="display: flex; flex-direction: column; gap: 20px;">
        
        <!-- Hero Header -->
        <section class="hero-section" style="padding-bottom: 0;">
          <div class="hero-header">
            <div>
              <h1 class="hero-welcome-title">Net Worth & Wealth Matrix</h1>
              <p class="hero-subtitle">Holistic balance sheet evaluation, capital assets, investment portfolios, and liability exposure.</p>
            </div>
            
            <button class="btn-primary" id="add-asset-btn" style="align-self: flex-start;">
              <span class="material-icons" style="font-size: 18px;">add</span> Add Asset / Debt
            </button>
          </div>

          <!-- Net Worth KPI Stat Cards -->
          <div class="kpi-grid">
            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Consolidated Net Worth</span>
                <div class="kpi-icon-box">
                  <span class="material-icons">account_balance</span>
                </div>
              </div>
              <div class="kpi-value">${Formatters.currency(netWorth)}</div>
              <div class="kpi-footer">
                <span class="kpi-badge positive">
                  ${debtRatio}% Debt Ratio
                </span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Gross Capital Assets</span>
                <div class="kpi-icon-box">
                  <span class="material-icons">trending_up</span>
                </div>
              </div>
              <div class="kpi-value">${Formatters.currency(totalAssets)}</div>
              <div class="kpi-footer">
                <span>${assets.filter(a => !(a.is_liability || a.isLiability)).length} Holdings</span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Total Liabilities</span>
                <div class="kpi-icon-box">
                  <span class="material-icons">trending_down</span>
                </div>
              </div>
              <div class="kpi-value">${Formatters.currency(totalLiabilities)}</div>
              <div class="kpi-footer">
                <span>${assets.filter(a => a.is_liability || a.isLiability).length} Active</span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Solvency Status</span>
                <div class="kpi-icon-box">
                  <span class="material-icons">verified</span>
                </div>
              </div>
              <div class="kpi-value">${debtRatio < 30 ? 'Pristine' : debtRatio < 60 ? 'Moderate' : 'Leveraged'}</div>
              <div class="kpi-footer">
                <span>Leverage tier</span>
              </div>
            </div>
          </div>
        </section>

        <!-- Assets & Liabilities Split Grid -->
        <div class="dashboard-split-grid">
          
          <!-- Assets Column -->
          <div class="fintech-card">
            <div class="card-header">
              <div class="card-title">
                <span class="material-icons">account_balance_wallet</span>
                <span>Assets & Holdings (${Formatters.currency(totalAssets)})</span>
              </div>
            </div>

            <div class="assets-grid">
              ${assets.filter(a => !(a.is_liability || a.isLiability)).length === 0 ? `
                <div style="grid-column: 1 / -1; text-align: center; padding: 28px 0; color: var(--text-muted); font-size: 13px;">
                  No asset records added yet. Add bank accounts, investments, or properties.
                </div>
              ` : assets.filter(a => !(a.is_liability || a.isLiability)).map(a => `
                <div class="asset-card">
                  <div>
                    <div style="font-weight: 700; font-size: 14.5px; color: var(--text-primary);">${a.name}</div>
                    <div style="font-size: 11px; text-transform: uppercase; color: var(--text-muted); margin-top: 2px;">${a.type || 'Savings'}</div>
                  </div>
                  <div style="display: flex; align-items: center; gap: 10px;">
                    <div style="font-weight: 700; font-size: 14.5px; color: var(--text-primary);">${Formatters.currency(a.value)}</div>
                    <button class="btn-icon btn-icon-sm delete-asset-btn" data-sync-id="${a.sync_id || ''}" data-id="${a.id || ''}" title="Delete asset">
                      <span class="material-icons" style="font-size: 16px;">delete_outline</span>
                    </button>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>

          <!-- Liabilities Column -->
          <div class="fintech-card">
            <div class="card-header">
              <div class="card-title">
                <span class="material-icons">credit_card</span>
                <span>Liabilities & Debts (${Formatters.currency(totalLiabilities)})</span>
              </div>
            </div>

            <div class="assets-grid">
              ${assets.filter(a => a.is_liability || a.isLiability).length === 0 ? `
                <div style="grid-column: 1 / -1; text-align: center; padding: 28px 0; color: var(--text-muted); font-size: 13px;">
                  Zero liabilities recorded. You have a 100% debt-free profile!
                </div>
              ` : assets.filter(a => a.is_liability || a.isLiability).map(a => `
                <div class="asset-card">
                  <div>
                    <div style="font-weight: 700; font-size: 14.5px; color: var(--text-primary);">${a.name}</div>
                    <div style="font-size: 11px; text-transform: uppercase; color: var(--text-muted); margin-top: 2px;">${a.type || 'Debt'}</div>
                  </div>
                  <div style="display: flex; align-items: center; gap: 10px;">
                    <div style="font-weight: 700; font-size: 14.5px; color: var(--text-secondary);">${Formatters.currency(a.value)}</div>
                    <button class="btn-icon btn-icon-sm delete-asset-btn" data-sync-id="${a.sync_id || ''}" data-id="${a.id || ''}" title="Delete liability">
                      <span class="material-icons" style="font-size: 16px;">delete_outline</span>
                    </button>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>

        </div>
      </div>
    `;
  },

  bindEvents(state) {
    // Add Asset Modal CTA
    document.getElementById('add-asset-btn')?.addEventListener('click', () => {
      this.showAddAssetModal();
    });

    // Delete asset button
    const deleteBtns = document.querySelectorAll('.delete-asset-btn');
    deleteBtns.forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const syncId = btn.getAttribute('data-sync-id');
        const localId = btn.getAttribute('data-id');
        if (confirm('Delete this asset/liability entry?')) {
          await DbService.deleteAsset(syncId, localId);
        }
      });
    });
  },

  showAddAssetModal() {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 500px; padding: 34px 30px;">
        <div class="modal-header" style="margin-bottom: 24px; padding-bottom: 16px;">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary); font-size: 24px;">account_balance</span>
            <span>New Asset / Liability</span>
          </div>
          <button class="modal-close-btn" id="modal-close-asset" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <div class="form-group" style="margin-bottom: 20px;">
          <label class="form-label" style="margin-bottom: 8px;">Name / Asset Description</label>
          <input type="text" class="form-control" id="asset-name-field" placeholder="e.g. HDFC Salary Account, Nifty Index Fund, Home Loan" autofocus>
        </div>

        <!-- Classification Toggle (Segmented Chips) -->
        <div class="form-group" style="margin-bottom: 20px;">
          <label class="form-label" style="margin-bottom: 8px;">Classification</label>
          <div class="filter-group" style="width: 100%; display: flex; gap: 8px;">
            <button type="button" class="filter-chip active" id="asset-class-asset-btn" style="flex: 1; text-align: center;">
              Asset (Positive Capital)
            </button>
            <button type="button" class="filter-chip" id="asset-class-liability-btn" style="flex: 1; text-align: center;">
              Liability / Debt
            </button>
          </div>
        </div>

        <!-- Category Selector (Interactive Pills Grid) -->
        <div class="form-group" style="margin-bottom: 20px;">
          <label class="form-label" style="margin-bottom: 8px;">Category / Instrument</label>
          <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px;" id="asset-type-grid">
            ${[
              { id: 'savings', name: 'Cash / Bank', icon: 'account_balance' },
              { id: 'investment', name: 'Investments', icon: 'trending_up' },
              { id: 'real_estate', name: 'Real Estate', icon: 'domain' },
              { id: 'crypto', name: 'Crypto', icon: 'currency_bitcoin' },
              { id: 'vehicle', name: 'Vehicle', icon: 'directions_car' },
              { id: 'loan', name: 'Personal Loan', icon: 'request_quote' },
              { id: 'credit_card', name: 'Credit Card', icon: 'credit_card' },
              { id: 'other', name: 'Other Asset', icon: 'category' }
            ].map(item => `
              <div class="category-select-pill asset-type-pill ${item.id === 'savings' ? 'active' : ''}" 
                   data-type="${item.id}"
                   style="display: flex; align-items: center; gap: 8px; padding: 10px 12px; border-radius: var(--radius-md); background: ${item.id === 'savings' ? 'var(--bg-surface-elevated)' : 'var(--bg-surface-subtle)'}; border: 1px solid ${item.id === 'savings' ? 'var(--primary)' : 'var(--glass-border)'}; cursor: pointer; transition: var(--transition-fast);">
                <span class="material-icons" style="font-size: 18px; color: ${item.id === 'savings' ? 'var(--text-primary)' : 'var(--text-muted)'};">${item.icon}</span>
                <span style="font-size: 12px; font-weight: 600; color: ${item.id === 'savings' ? 'var(--text-primary)' : 'var(--text-secondary)'}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${item.name}</span>
              </div>
            `).join('')}
          </div>
        </div>

        <div class="form-group" style="margin-bottom: 24px;">
          <label class="form-label" style="margin-bottom: 8px;">Current Valuation / Principal (₹)</label>
          <div style="position: relative; display: flex; align-items: center;">
            <span style="position: absolute; left: 16px; font-size: 20px; font-weight: 700; color: var(--text-muted);">₹</span>
            <input type="number" step="any" class="form-control" id="asset-val-field" placeholder="50000" style="padding-left: 38px; font-size: 18px; font-weight: 700;">
          </div>
        </div>

        <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 24px; padding-top: 20px; border-top: 1px solid var(--glass-border);">
          <button class="btn-secondary" id="modal-cancel-asset" style="width: auto; padding: 10px 20px;">Cancel</button>
          <button class="btn-primary" id="modal-submit-asset" style="width: auto; padding: 10px 22px;">Save Record</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);
    let isLiability = false;
    let selectedType = 'savings';

    const assetBtn = document.getElementById('asset-class-asset-btn');
    const liabilityBtn = document.getElementById('asset-class-liability-btn');

    assetBtn?.addEventListener('click', () => {
      isLiability = false;
      assetBtn.classList.add('active');
      liabilityBtn?.classList.remove('active');
    });

    liabilityBtn?.addEventListener('click', () => {
      isLiability = true;
      liabilityBtn.classList.add('active');
      assetBtn?.classList.remove('active');
    });

    // Category Type Pill selection
    const typePills = overlay.querySelectorAll('.asset-type-pill');
    typePills.forEach(pill => {
      pill.addEventListener('click', () => {
        selectedType = pill.getAttribute('data-type');
        typePills.forEach(p => {
          const active = p === pill;
          p.style.background = active ? 'var(--bg-surface-elevated)' : 'var(--bg-surface-subtle)';
          p.style.borderColor = active ? 'var(--primary)' : 'var(--glass-border)';
          const icon = p.querySelector('.material-icons');
          if (icon) icon.style.color = active ? 'var(--text-primary)' : 'var(--text-muted)';
          const text = p.querySelector('span:last-child');
          if (text) text.style.color = active ? 'var(--text-primary)' : 'var(--text-secondary)';
        });
      });
    });

    const closeModal = () => { if (document.body.contains(overlay)) document.body.removeChild(overlay); };

    document.getElementById('modal-close-asset')?.addEventListener('click', closeModal);
    document.getElementById('modal-cancel-asset')?.addEventListener('click', closeModal);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) closeModal(); });

    document.getElementById('modal-submit-asset')?.addEventListener('click', async () => {
      const name = document.getElementById('asset-name-field').value.trim();
      const val = parseFloat(document.getElementById('asset-val-field').value);

      if (!name || isNaN(val) || val <= 0) {
        alert('Please enter a valid asset name and valuation.');
        return;
      }

      await DbService.addAsset({
        name,
        value: val,
        isLiability,
        is_liability: isLiability,
        type: selectedType
      });

      closeModal();
      StateManager.notify();
    });
  }
};
