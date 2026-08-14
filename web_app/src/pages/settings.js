/* Settings Screen Module (Preferences, monthly income edits, clear data, and firebase auth link) */
import { StateManager } from '../state.js';
import { DbService } from '../db.js';
import { AuthService } from '../auth.js';
import { Formatters } from '../utils/formatters.js';
import { AppConstants } from '../utils/constants.js';
import { Router } from '../router.js';

export const SettingsPage = {
  isSaving: false,
  isSyncing: false,
  hasChanges: false,
  incomeInputVal: '',
  selectedCurrency: 'INR',

  render(state) {
    const user = state.user;
    const settings = state.userSettings || {};
    
    if (this.incomeInputVal === '') {
      this.incomeInputVal = settings.monthlyIncome || 0;
      this.selectedCurrency = settings.currency || 'INR';
    }

    const symbol = AppConstants.supportedCurrencies[this.selectedCurrency] || '₹';

    let lastSyncLabel = 'Never';
    if (state.lastSyncedAt) {
      const diffSec = Math.round((Date.now() - new Date(state.lastSyncedAt).getTime()) / 1000);
      if (diffSec < 30) lastSyncLabel = 'Just now';
      else if (diffSec < 3600) lastSyncLabel = `${Math.floor(diffSec / 60)} min ago`;
      else lastSyncLabel = Formatters.time(state.lastSyncedAt);
    }

    return `
      <div class="modal-card animate-fade-in" style="background:#131124; max-height:90vh; display:flex; flex-direction:column; width:100%; max-width:600px; padding:32px 40px;">
        <div class="modal-header" style="border-bottom:1px solid var(--divider); padding-bottom:12px; margin-bottom:16px;">
          <div style="display:flex; align-items:center; gap:8px;">
            <span class="material-icons" style="color:var(--primary);">settings</span>
            <h3 style="color:#FFF; font-size:20px;">Settings</h3>
          </div>
          <button class="modal-close" id="settings-close-btn">&times;</button>
        </div>

        <div style="flex:1; overflow-y:auto; display:flex; flex-direction:column; gap:20px;" id="settings-list-container">
          <!-- Account & Cloud Sync card -->
          <h4 style="font-size:13px; color:var(--text-muted); text-transform:uppercase; letter-spacing:0.05em;">Account & Cloud Sync</h4>
          <div class="glass-card" style="padding:18px;">
            <div style="display:flex; align-items:center; gap:16px; margin-bottom:14px;">
              <div style="width:48px; height:48px; border-radius:50%; background: ${user ? 'rgba(16,185,129,0.15)' : 'rgba(255,255,255,0.05)'}; display:flex; align-items:center; justify-content:center;">
                <span class="material-icons ${this.isSyncing ? 'animate-spin' : ''}" style="color: ${user ? 'var(--success)' : 'var(--text-muted)'}; font-size:24px;">
                  ${this.isSyncing ? 'sync' : user ? 'cloud_done' : 'cloud_off'}
                </span>
              </div>
              <div style="flex:1;">
                <div style="font-weight:700; font-size:15px; color:#FFF;">${user ? (user.email || 'Cloud Account') : 'Offline Guest Mode'}</div>
                <div style="font-size:12px; color:var(--text-muted); margin-top:2px;">
                  ${user ? `Status: ${this.isSyncing ? 'Syncing...' : 'Connected to Firebase Cloud'} • Last Synced: ${lastSyncLabel}` : 'Data is stored on this browser only'}
                </div>
              </div>
            </div>
            
            <div style="height:1px; background:var(--divider); margin:12px 0;"></div>
            
            <div style="display:flex; justify-content:flex-end; gap:12px;">
              ${user ? `
                <button class="btn btn-outline" id="settings-sync-btn" ${this.isSyncing ? 'disabled' : ''} style="width:auto; padding:6px 14px; font-size:12px; display:flex; align-items:center; gap:6px;">
                  <span class="material-icons ${this.isSyncing ? 'animate-spin' : ''}" style="font-size:16px;">sync</span> 
                  ${this.isSyncing ? 'Syncing...' : 'Sync Now'}
                </button>
                <button class="btn btn-danger" id="settings-signout-btn" style="width:auto; padding:6px 14px; font-size:12px; border:none; background:rgba(239,68,68,0.1); color:var(--error); display:flex; align-items:center; gap:6px;">
                  <span class="material-icons" style="font-size:16px;">logout</span> Sign Out
                </button>
              ` : `
                <button class="btn btn-primary" id="settings-signin-btn" style="width:auto; padding:8px 16px; font-size:12px; display:flex; align-items:center; gap:6px;">
                  <span class="material-icons" style="font-size:16px;">login</span> Connect Cloud Account
                </button>
              `}
            </div>
          </div>

          <!-- Monthly Income Section -->
          <h4 style="font-size:13px; color:var(--text-muted); text-transform:uppercase; letter-spacing:0.05em;">Income</h4>
          <div class="glass-card">
            <div class="form-group" style="margin-bottom:12px;">
              <label class="form-label">Monthly Income</label>
              <div class="form-input-container">
                <span style="position:absolute; left:16px; font-weight:700; color:var(--primary); font-size:18px;">${symbol}</span>
                <input type="number" class="form-input" id="settings-income-field" value="${this.incomeInputVal}" style="padding-left:36px; font-weight:600;">
              </div>
            </div>
            
            <div style="display:flex; justify-content:space-between; align-items:center;">
              <div style="font-size:11px; color:var(--text-muted); line-height:1.4; max-width:70%;">
                Updating this adjusts your monthly budget baseline and income projections.
              </div>
              ${this.hasChanges ? `
                <button class="btn btn-primary animate-fade-in" id="settings-save-income-btn" style="width:auto; padding:8px 16px; font-size:12px;">
                  Save
                </button>
              ` : ''}
            </div>
          </div>

          <!-- Preferences -->
          <h4 style="font-size:13px; color:var(--text-muted); text-transform:uppercase; letter-spacing:0.05em;">Preferences</h4>
          <div class="glass-card" style="padding:10px 20px;">
            <div class="settings-tile" id="settings-currency-tile">
              <span class="material-icons settings-tile-icon">payments</span>
              <div class="settings-tile-content">
                <div class="settings-tile-title">Currency</div>
                <div class="settings-tile-subtitle">Active: ${this.selectedCurrency} (${symbol})</div>
              </div>
              <span class="material-icons settings-tile-action">chevron_right</span>
            </div>
          </div>

          <!-- Data Management -->
          <h4 style="font-size:13px; color:var(--text-muted); text-transform:uppercase; letter-spacing:0.05em;">Data Management</h4>
          <div class="glass-card" style="padding:10px 20px;">
            <div class="settings-tile" id="settings-export-tile">
              <span class="material-icons settings-tile-icon">download</span>
              <div class="settings-tile-content">
                <div class="settings-tile-title">Export Transactions</div>
                <div class="settings-tile-subtitle">Download local JSON data backup</div>
              </div>
              <span class="material-icons settings-tile-action">chevron_right</span>
            </div>
            <div class="settings-tile" id="settings-clear-tile">
              <span class="material-icons settings-tile-icon" style="color:var(--error);">delete_forever</span>
              <div class="settings-tile-content">
                <div class="settings-tile-title" style="color:var(--error);">Reset Local Data</div>
                <div class="settings-tile-subtitle">Wipe offline cached entries</div>
              </div>
              <span class="material-icons settings-tile-action">chevron_right</span>
            </div>
          </div>

          <!-- About Card -->
          <h4 style="font-size:13px; color:var(--text-muted); text-transform:uppercase; letter-spacing:0.05em;">About</h4>
          <div class="glass-card" style="display:flex; align-items:center; gap:16px;">
            <div style="width:48px; height:48px; border-radius:12px; background:linear-gradient(135deg, var(--primary) 0%, #FF8C42 100%); display:flex; align-items:center; justify-content:center;">
              <span class="material-icons" style="color:#FFF; font-size:24px;">account_balance_wallet</span>
            </div>
            <div>
              <div style="font-weight:700; font-size:16px;">Quantro Finance</div>
              <div style="font-size:12px; color:var(--text-secondary); margin-top:2px;">Version 1.0.0 (Cloud Synced)</div>
              <div style="font-size:10px; color:var(--text-muted); margin-top:4px;">Built with Firebase & Vanilla JS</div>
            </div>
          </div>
        </div>
      </div>
    `;
  },

  bindEvents(state) {
    // Close button
    document.getElementById('settings-close-btn')?.addEventListener('click', () => {
      Router.closeOverlay();
      this.incomeInputVal = ''; // reset buffer
      this.hasChanges = false;
    });

    // Income field input change
    const incomeField = document.getElementById('settings-income-field');
    if (incomeField) {
      incomeField.addEventListener('input', (e) => {
        this.incomeInputVal = parseFloat(e.target.value) || 0;
        const original = state.userSettings ? (state.userSettings.monthlyIncome || state.userSettings.monthly_income || 0) : 0;
        this.hasChanges = this.incomeInputVal !== original;
        StateManager.setState({}); // Re-render settings screen to show/hide save button
      });
    }

    // Save income changes button
    const saveIncomeBtn = document.getElementById('settings-save-income-btn');
    if (saveIncomeBtn) {
      saveIncomeBtn.addEventListener('click', async () => {
        const val = parseFloat(this.incomeInputVal) || 0;
        await DbService.saveUserSettings({
          monthlyIncome: val,
          isOnboarded: true
        });

        // Update or add Salary income transaction for this month
        const salaryCat = state.categories.find(c => c.name === 'Salary');
        if (salaryCat) {
          const now = new Date();
          const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
          const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

          const existingSalary = state.transactions.find(t => {
            const ts = new Date(t.timestamp);
            return t.type === 'income' &&
                   (t.categoryId === salaryCat.id || t.categoryId === salaryCat.sync_id || t.category_id === salaryCat.id || t.category_id === salaryCat.sync_id) &&
                   ts >= startOfMonth && ts <= endOfMonth;
          });

          if (existingSalary) {
            await DbService.addTransaction({
              ...existingSalary,
              amount: val,
              updated_at: new Date().toISOString()
            });
          } else {
            await DbService.addTransaction({
              amount: val,
              type: 'income',
              categoryId: salaryCat.id || salaryCat.sync_id,
              timestamp: startOfMonth.toISOString(),
              note: 'Monthly Salary',
              isRecurring: true
            });
          }
        }

        this.hasChanges = false;
        StateManager.notify();
        alert('Monthly income updated successfully!');
      });
    }

    // Connect cloud account (signs out of guest mode and triggers Auth)
    const signinBtn = document.getElementById('settings-signin-btn');
    if (signinBtn) {
      signinBtn.addEventListener('click', () => {
        StateManager.disableGuestMode();
        Router.closeOverlay();
      });
    }

    // Sign out click
    const signoutBtn = document.getElementById('settings-signout-btn');
    if (signoutBtn) {
      signoutBtn.addEventListener('click', async () => {
        if (confirm('Are you sure you want to sign out?')) {
          DbService.stopSync();
          await AuthService.signOut();
          Router.closeOverlay();
        }
      });
    }

    // Manual sync button click (Real Firestore trigger)
    const syncBtn = document.getElementById('settings-sync-btn');
    if (syncBtn && state.user) {
      syncBtn.addEventListener('click', async () => {
        this.isSyncing = true;
        StateManager.setState({}); // Re-render to show spinning animation

        try {
          const res = await DbService.syncNow(state.user.uid);
          this.isSyncing = false;
          StateManager.notify();
          alert(`Cloud sync complete!\n\nSynced:\n• ${res.count.transactions} Transactions\n• ${res.count.categories} Categories\n• ${res.count.goals} Goals\n• ${res.count.assets} Assets`);
        } catch (err) {
          this.isSyncing = false;
          StateManager.notify();
          alert('Sync failed: ' + (err.message || 'Network error'));
        }
      });
    }

    // Currency selector tile click
    document.getElementById('settings-currency-tile')?.addEventListener('click', () => {
      this.showCurrencyPickerModal(state);
    });

    // Export data click
    document.getElementById('settings-export-tile')?.addEventListener('click', () => {
      const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(state.transactions, null, 2));
      const downloadAnchor = document.createElement('a');
      downloadAnchor.setAttribute("href", dataStr);
      downloadAnchor.setAttribute("download", `quantro_transactions_${new Date().toISOString().slice(0, 10)}.json`);
      document.body.appendChild(downloadAnchor);
      downloadAnchor.click();
      downloadAnchor.remove();
    });

    // Clear local data click
    document.getElementById('settings-clear-tile')?.addEventListener('click', () => {
      if (confirm('Are you sure you want to reset offline cached data? (Your cloud data in Firebase will not be deleted)')) {
        StateManager.clearGuestLocalStorage();
        if (state.user) {
          DbService.syncNow(state.user.uid);
        } else {
          window.location.reload();
        }
      }
    });
  },

  showCurrencyPickerModal(state) {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modal-card animate-fade-in" style="background:#1E1E2C; width:90%; max-width:320px;">
        <div class="modal-header" style="margin-bottom:12px;">
          <h3 style="color:#FFF;">Select Currency</h3>
          <button class="modal-close" id="currency-modal-close">&times;</button>
        </div>
        <div style="display:flex; flex-direction:column; gap:8px;">
          ${Object.entries(AppConstants.supportedCurrencies).map(([code, symbol]) => {
            const isSelected = code === this.selectedCurrency;
            return `
              <div class="settings-tile currency-select-row" 
                   data-code="${code}"
                   style="border:none; padding:12px; border-radius:8px; background: ${isSelected ? 'rgba(255,95,31,0.15)' : 'var(--glass-bg)'}; border:1px solid ${isSelected ? 'var(--primary)' : 'var(--glass-border)'}; cursor:pointer;">
                <div style="font-weight:700; font-size:16px; width:36px; height:36px; border-radius:50%; background:rgba(255,255,255,0.05); display:flex; align-items:center; justify-content:center; color:var(--primary); margin-right:12px;">
                  ${symbol}
                </div>
                <div style="flex:1; font-weight:600; font-size:14px;">${code}</div>
                ${isSelected ? '<span class="material-icons" style="color:var(--primary); font-size:20px;">check_circle</span>' : ''}
              </div>
            `;
          }).join('')}
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    const closeModal = () => {
      if (document.body.contains(overlay)) {
        document.body.removeChild(overlay);
      }
    };

    document.getElementById('currency-modal-close')?.addEventListener('click', closeModal);

    const rows = overlay.querySelectorAll('.currency-select-row');
    rows.forEach(row => {
      row.addEventListener('click', async () => {
        const code = row.getAttribute('data-code');
        this.selectedCurrency = code;
        await DbService.saveUserSettings({
          currency: code
        });
        closeModal();
        StateManager.notify();
      });
    });
  }
};
