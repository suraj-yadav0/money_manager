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
      <div class="animate-fade-in" style="display: flex; flex-direction: column; gap: 28px;">
        
        <!-- Hero Header -->
        <section class="hero-section" style="padding-bottom: 0;">
          <div class="hero-header">
            <div>
              <h1 class="hero-welcome-title">Net Worth & Wealth Matrix</h1>
              <p class="hero-subtitle">Holistic balance sheet evaluation, capital assets, investment portfolios, and liability exposure.</p>
            </div>
            
            <button class="btn-primary" id="add-asset-btn">
              <span class="material-icons" style="font-size: 18px;">add</span> Add Asset / Debt
            </button>
          </div>

          <!-- Net Worth KPI Stat Cards -->
          <div class="kpi-grid">
            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Consolidated Net Worth</span>
                <div class="kpi-icon-box" style="background: rgba(16, 185, 129, 0.12); color: var(--primary);">
                  <span class="material-icons" style="font-size: 20px;">account_balance</span>
                </div>
              </div>
              <div class="kpi-value" style="color: ${netWorth >= 0 ? 'var(--text-primary)' : 'var(--error)'};">
                ${Formatters.currency(netWorth)}
              </div>
              <div class="kpi-footer">
                <span class="kpi-badge ${netWorth >= 0 ? 'positive' : 'negative'}">
                  ${debtRatio}% Debt Ratio
                </span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Gross Capital Assets</span>
                <div class="kpi-icon-box" style="background: rgba(56, 189, 248, 0.12); color: var(--secondary);">
                  <span class="material-icons" style="font-size: 20px;">trending_up</span>
                </div>
              </div>
              <div class="kpi-value" style="color: var(--secondary);">${Formatters.currency(totalAssets)}</div>
              <div class="kpi-footer">
                <span>${assets.filter(a => !(a.is_liability || a.isLiability)).length} Asset Holdings</span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Total Liabilities & Debt</span>
                <div class="kpi-icon-box" style="background: rgba(244, 63, 94, 0.12); color: var(--error);">
                  <span class="material-icons" style="font-size: 20px;">trending_down</span>
                </div>
              </div>
              <div class="kpi-value" style="color: var(--error);">${Formatters.currency(totalLiabilities)}</div>
              <div class="kpi-footer">
                <span>${assets.filter(a => a.is_liability || a.isLiability).length} Active Liabilities</span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Financial Solvency</span>
                <div class="kpi-icon-box" style="background: rgba(99, 102, 241, 0.12); color: var(--indigo);">
                  <span class="material-icons" style="font-size: 20px;">verified</span>
                </div>
              </div>
              <div class="kpi-value" style="font-size: 22px;">${debtRatio < 30 ? 'Pristine' : debtRatio < 60 ? 'Moderate' : 'Leveraged'}</div>
              <div class="kpi-footer">
                <span>Leverage profile tier</span>
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
                <span class="material-icons" style="color: var(--secondary);">account_balance_wallet</span>
                <span>Assets & Holdings (${Formatters.currency(totalAssets)})</span>
              </div>
            </div>

            <div class="assets-grid">
              ${assets.filter(a => !(a.is_liability || a.isLiability)).length === 0 ? `
                <div style="grid-column: 1 / -1; text-align: center; padding: 32px 0; color: var(--text-muted); font-size: 13px;">
                  No asset records added yet. Add bank accounts, investments, or properties.
                </div>
              ` : assets.filter(a => !(a.is_liability || a.isLiability)).map(a => `
                <div class="asset-card">
                  <div>
                    <div style="font-weight: 700; font-size: 15px; color: var(--text-primary);">${a.name}</div>
                    <div style="font-size: 11px; text-transform: uppercase; color: var(--text-muted); margin-top: 2px;">${a.type || 'Savings'}</div>
                  </div>
                  <div style="display: flex; align-items: center; gap: 12px;">
                    <div style="font-weight: 800; font-size: 15px; color: var(--secondary);">${Formatters.currency(a.value)}</div>
                    <button class="btn-icon btn-icon-sm delete-asset-btn" data-sync-id="${a.sync_id || ''}" data-id="${a.id || ''}" style="color: var(--error); border: none;">
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
                <span class="material-icons" style="color: var(--error);">credit_card</span>
                <span>Liabilities & Debts (${Formatters.currency(totalLiabilities)})</span>
              </div>
            </div>

            <div class="assets-grid">
              ${assets.filter(a => a.is_liability || a.isLiability).length === 0 ? `
                <div style="grid-column: 1 / -1; text-align: center; padding: 32px 0; color: var(--text-muted); font-size: 13px;">
                  Zero liabilities recorded. You have a 100% debt-free profile!
                </div>
              ` : assets.filter(a => a.is_liability || a.isLiability).map(a => `
                <div class="asset-card">
                  <div>
                    <div style="font-weight: 700; font-size: 15px; color: var(--text-primary);">${a.name}</div>
                    <div style="font-size: 11px; text-transform: uppercase; color: var(--text-muted); margin-top: 2px;">${a.type || 'Debt'}</div>
                  </div>
                  <div style="display: flex; align-items: center; gap: 12px;">
                    <div style="font-weight: 800; font-size: 15px; color: var(--error);">${Formatters.currency(a.value)}</div>
                    <button class="btn-icon btn-icon-sm delete-asset-btn" data-sync-id="${a.sync_id || ''}" data-id="${a.id || ''}" style="color: var(--error); border: none;">
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

        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 20px;">
          <div class="form-group">
            <label class="form-label" style="margin-bottom: 8px;">Classification</label>
            <select class="form-control" id="asset-is-liability-field">
              <option value="false">Asset (Positive Capital)</option>
              <option value="true">Liability / Debt</option>
            </select>
          </div>

          <div class="form-group">
            <label class="form-label" style="margin-bottom: 8px;">Category</label>
            <select class="form-control" id="asset-type-field">
              <option value="savings">Cash / Bank Account</option>
              <option value="investment">Investments & Stocks</option>
              <option value="real_estate">Real Estate</option>
              <option value="crypto">Cryptocurrency</option>
              <option value="vehicle">Vehicle</option>
              <option value="loan">Personal / Home Loan</option>
              <option value="credit_card">Credit Card Debt</option>
              <option value="other">Other</option>
            </select>
          </div>
        </div>

        <div class="form-group" style="margin-bottom: 24px;">
          <label class="form-label" style="margin-bottom: 8px;">Current Valuation / Principal (₹)</label>
          <div style="position: relative; display: flex; align-items: center;">
            <span style="position: absolute; left: 16px; font-size: 20px; font-weight: 800; color: var(--text-muted);">₹</span>
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
    const closeModal = () => { if (document.body.contains(overlay)) document.body.removeChild(overlay); };

    document.getElementById('modal-close-asset')?.addEventListener('click', closeModal);
    document.getElementById('modal-cancel-asset')?.addEventListener('click', closeModal);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) closeModal(); });

    document.getElementById('modal-submit-asset')?.addEventListener('click', async () => {
      const name = document.getElementById('asset-name-field').value.trim();
      const val = parseFloat(document.getElementById('asset-val-field').value);
      const isLiability = document.getElementById('asset-is-liability-field').value === 'true';
      const type = document.getElementById('asset-type-field').value;

      if (!name || isNaN(val) || val <= 0) {
        alert('Please enter a valid asset name and valuation.');
        return;
      }

      await DbService.addAsset({
        name,
        value: val,
        isLiability,
        is_liability: isLiability,
        type
      });

      closeModal();
      StateManager.notify();
    });
  }
};
