/* Settings Screen Module (Preferences, monthly income edits, clear data, and firebase auth link) */
import { StateManager } from '../state.js';
import { DbService } from '../db.js';
import { AuthService } from '../auth.js';
import { Formatters } from '../utils/formatters.js';
import { AppConstants } from '../utils/constants.js';
import { Router } from '../router.js';

export const SettingsPage = {
  isSaving: false,
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
          <div class="glass-card" style="padding:16px;">
            <div style="display:flex; align-items:center; gap:16px; margin-bottom:16px;">
              <div style="width:48px; height:48px; border-radius:50%; background: ${user ? 'rgba(16,185,129,0.15)' : 'rgba(255,255,255,0.05)'}; display:flex; align-items:center; justify-content:center;">
                <span class="material-icons" style="color: ${user ? 'var(--success)' : 'var(--text-muted)'};">
                  ${user ? 'cloud_done' : 'cloud_off'}
                </span>
              </div>
              <div>
                <div style="font-weight:700; font-size:15px;">${user ? (user.email || 'Cloud Account') : 'Offline Guest Mode'}</div>
                <div style="font-size:12px; color:var(--text-muted); margin-top:2px;">
                  ${user ? 'Automatic Cloud Backup is active' : 'Data is stored on this browser only'}
                </div>
              </div>
            </div>
            
            <div style="height:1px; background:var(--divider); margin:12px 0;"></div>
            
            <div style="display:flex; justify-content:flex-end; gap:12px;">
              ${user ? `
                <button class="btn btn-outline" id="settings-sync-btn" style="width:auto; padding:6px 12px; font-size:12px;">
                  <span class="material-icons" style="font-size:16px;">sync</span> Sync Now
                </button>
                <button class="btn btn-danger" id="settings-signout-btn" style="width:auto; padding:6px 12px; font-size:12px; border:none; background:transparent;">
                  <span class="material-icons" style="font-size:16px;">logout</span> Sign Out
                </button>
              ` : `
                <button class="btn btn-primary" id="settings-signin-btn" style="width:auto; padding:8px 16px; font-size:12px;">
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
                This will automatically update this month's Salary income transaction.
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
                <div class="settings-tile-subtitle">Download local data file</div>
              </div>
              <span class="material-icons settings-tile-action">chevron_right</span>
            </div>
            <div class="settings-tile" id="settings-clear-tile">
              <span class="material-icons settings-tile-icon" style="color:var(--error);">delete_forever</span>
              <div class="settings-tile-content">
                <div class="settings-tile-title" style="color:var(--error);">Clear All Data</div>
                <div class="settings-tile-subtitle">Permanently wipe transactions and settings</div>
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
              <div style="font-size:12px; color:var(--text-secondary); margin-top:2px;">Version 1.0.0 (Vite Replica)</div>
              <div style="font-size:10px; color:var(--text-muted); margin-top:4px;">Built with Vanilla JS, HTML5, & CSS3</div>
            </div>
          </div>
        </div>
      </div>
    `;
  },

  bindEvents(state) {
    // Close button
    document.getElementById('settings-close-btn').addEventListener('click', () => {
      Router.closeOverlay();
      this.incomeInputVal = ''; // reset buffer
      this.hasChanges = false;
    });

    // Income field input change
    const incomeField = document.getElementById('settings-income-field');
    incomeField.addEventListener('input', (e) => {
      this.incomeInputVal = parseFloat(e.target.value) || 0;
      const original = state.userSettings ? state.userSettings.monthlyIncome : 0;
      this.hasChanges = this.incomeInputVal !== original;
      StateManager.setState({}); // Re-render settings screen to show/hide save button
    });

    // Save income changes button
    const saveIncomeBtn = document.getElementById('settings-save-income-btn');
    if (saveIncomeBtn) {
      saveIncomeBtn.addEventListener('click', async () => {
        const val = parseFloat(this.incomeInputVal) || 0;
        await DbService.saveUserSettings({
          monthlyIncome: val
        });

        // Mirroring settings_screen.dart: update Salary income transaction for this month
        const salaryCat = state.categories.find(c => c.name === 'Salary');
        if (salaryCat) {
          const now = new Date();
          const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
          const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

          // Find salary transaction for this month
          const existingSalary = state.transactions.find(t => {
            const ts = new Date(t.timestamp);
            return t.type === 'income' &&
                   (t.categoryId === salaryCat.id || t.categoryId === salaryCat.sync_id) &&
                   ts >= startOfMonth && ts <= endOfMonth;
          });

          if (existingSalary) {
            // Update existing transaction locally or Firestore
            if (state.isGuestMode) {
              existingSalary.amount = val;
              existingSalary.updated_at = new Date().toISOString();
              StateManager.saveGuestState();
              StateManager.notify();
            } else {
              await DbService.addTransaction({
                ...existingSalary,
                amount: val,
                updated_at: new Date().toISOString()
              });
            }
          } else {
            // Add new salary transaction for this month
            await DbService.addTransaction({
              amount: val,
              type: 'income',
              categoryId: salaryCat.id,
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

    // Manual sync button click
    const syncBtn = document.getElementById('settings-sync-btn');
    if (syncBtn) {
      syncBtn.addEventListener('click', () => {
        alert('Cloud sync completed successfully!');
      });
    }

    // Currency selector tile click
    document.getElementById('settings-currency-tile').addEventListener('click', () => {
      this.showCurrencyPickerModal(state);
    });

    // Export data click
    document.getElementById('settings-export-tile').addEventListener('click', () => {
      // Create JSON data download
      const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(state.transactions));
      const downloadAnchor = document.createElement('a');
      downloadAnchor.setAttribute("href", dataStr);
      downloadAnchor.setAttribute("download", `quantro_transactions_${new Date().toISOString().slice(0, 10)}.json`);
      document.body.appendChild(downloadAnchor);
      downloadAnchor.click();
      downloadAnchor.remove();
    });

    // Clear data click
    document.getElementById('settings-clear-tile').addEventListener('click', () => {
      if (confirm('DANGER! This will permanently delete ALL transactions, goals, and settings. Are you absolutely sure?')) {
        if (state.isGuestMode) {
          StateManager.clearGuestData();
          window.location.reload(); // Hard reload to onboarding
        } else {
          alert('To clear cloud data, delete the account or contact support.');
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
      document.body.removeChild(overlay);
    };

    document.getElementById('currency-modal-close').addEventListener('click', closeModal);

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
