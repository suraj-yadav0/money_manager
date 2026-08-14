/* Modern Account & Settings Modal Module */
import { StateManager } from '../state.js';
import { DbService } from '../db.js';
import { AuthService } from '../auth.js';
import { Formatters } from '../utils/formatters.js';
import { AppConstants } from '../utils/constants.js';
import { Router } from '../router.js';

export const SettingsPage = {
  isSaving: false,
  isSyncing: false,
  incomeInputVal: '',
  selectedCurrency: 'INR',

  render(state) {
    const user = state.user;
    const settings = state.userSettings || {};
    
    if (this.incomeInputVal === '') {
      this.incomeInputVal = settings.monthlyIncome || settings.monthly_income || 0;
      this.selectedCurrency = settings.currency || 'INR';
    }

    const symbol = AppConstants.supportedCurrencies[this.selectedCurrency] || '₹';

    let lastSyncLabel = 'Never';
    if (state.lastSyncedAt) {
      const diffSec = Math.round((Date.now() - new Date(state.lastSyncedAt).getTime()) / 1000);
      if (diffSec < 30) lastSyncLabel = 'Just now';
      else if (diffSec < 3600) lastSyncLabel = `${Math.floor(diffSec / 60)}m ago`;
      else lastSyncLabel = Formatters.time(state.lastSyncedAt);
    }

    return `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 580px;">
        <div class="modal-header">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary);">settings</span>
            <span>Platform Settings</span>
          </div>
          <button class="modal-close-btn" id="settings-close-btn">&times;</button>
        </div>

        <div style="display: flex; flex-direction: column; gap: 20px; max-height: 65vh; overflow-y: auto; padding-right: 4px;">
          
          <!-- Cloud Sync Card -->
          <div style="background: rgba(255, 255, 255, 0.03); border: 1px solid var(--glass-border); border-radius: var(--radius-lg); padding: 18px;">
            <div style="display: flex; align-items: center; gap: 14px; margin-bottom: 14px;">
              <div style="width: 44px; height: 44px; border-radius: 50%; background: ${user ? 'var(--success-bg)' : 'rgba(255,255,255,0.05)'}; display: flex; align-items: center; justify-content: center;">
                <span class="material-icons ${this.isSyncing ? 'animate-spin' : ''}" style="color: ${user ? 'var(--success)' : 'var(--text-muted)'}; font-size: 22px;">
                  ${this.isSyncing ? 'sync' : user ? 'cloud_done' : 'cloud_off'}
                </span>
              </div>
              <div style="flex: 1;">
                <div style="font-weight: 700; font-size: 15px; color: var(--text-primary);">${user ? (user.email || 'Cloud Account') : 'Guest Mode (Offline)'}</div>
                <div style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">
                  ${user ? `Status: ${this.isSyncing ? 'Syncing...' : 'Connected to Cloud Firestore'} • Last: ${lastSyncLabel}` : 'Data is stored locally on this browser'}
                </div>
              </div>
            </div>

            <div style="display: flex; justify-content: flex-end; gap: 10px; border-top: 1px solid var(--glass-border); padding-top: 12px;">
              ${user ? `
                <button class="btn-secondary" id="settings-sync-now-btn" ${this.isSyncing ? 'disabled' : ''} style="padding: 6px 14px; font-size: 13px;">
                  <span class="material-icons ${this.isSyncing ? 'animate-spin' : ''}" style="font-size: 16px;">sync</span>
                  ${this.isSyncing ? 'Syncing...' : 'Sync Now'}
                </button>
                <button class="btn-ghost" id="settings-signout-btn" style="color: var(--error); padding: 6px 14px; font-size: 13px;">
                  <span class="material-icons" style="font-size: 16px;">logout</span> Sign Out
                </button>
              ` : `
                <button class="btn-primary" id="settings-connect-btn" style="padding: 8px 16px; font-size: 13px;">
                  <span class="material-icons" style="font-size: 16px;">login</span> Connect Cloud Account
                </button>
              `}
            </div>
          </div>

          <!-- Monthly Income Baseline -->
          <div class="form-group">
            <label class="form-label">Monthly Inflow Baseline</label>
            <div style="position: relative; display: flex; align-items: center;">
              <span style="position: absolute; left: 16px; font-weight: 700; color: var(--primary); font-size: 16px;">${symbol}</span>
              <input type="number" class="form-control" id="settings-income-field" value="${this.incomeInputVal}" style="padding-left: 36px; font-weight: 700;">
            </div>
            <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">
              Used for daily burn calculations and projection models.
            </div>
          </div>

          <!-- Currency Selector -->
          <div style="display: flex; align-items: center; justify-content: space-between; background: rgba(255, 255, 255, 0.03); border: 1px solid var(--glass-border); padding: 14px 18px; border-radius: var(--radius-md); cursor: pointer;" id="settings-currency-row">
            <div>
              <div style="font-weight: 600; font-size: 14px; color: var(--text-primary);">Base Currency</div>
              <div style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">Active: ${this.selectedCurrency} (${symbol})</div>
            </div>
            <span class="material-icons" style="color: var(--text-muted);">chevron_right</span>
          </div>

          <!-- Data Export -->
          <div style="display: flex; align-items: center; justify-content: space-between; background: rgba(255, 255, 255, 0.03); border: 1px solid var(--glass-border); padding: 14px 18px; border-radius: var(--radius-md); cursor: pointer;" id="settings-export-row">
            <div>
              <div style="font-weight: 600; font-size: 14px; color: var(--text-primary);">Export Local JSON Backup</div>
              <div style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">Download all records to JSON file</div>
            </div>
            <span class="material-icons" style="color: var(--text-muted);">download</span>
          </div>

          <!-- Reset Local Storage -->
          <div style="display: flex; align-items: center; justify-content: space-between; background: rgba(244, 63, 94, 0.04); border: 1px solid rgba(244, 63, 94, 0.2); padding: 14px 18px; border-radius: var(--radius-md); cursor: pointer;" id="settings-reset-row">
            <div>
              <div style="font-weight: 600; font-size: 14px; color: var(--error);">Reset Local Cache</div>
              <div style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">Purge local browser cache without deleting cloud records</div>
            </div>
            <span class="material-icons" style="color: var(--error);">delete_forever</span>
          </div>

        </div>

        <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 24px; padding-top: 16px; border-top: 1px solid var(--glass-border);">
          <button class="btn-secondary" id="settings-cancel-btn" style="width: auto;">Cancel</button>
          <button class="btn-primary" id="settings-save-btn" style="width: auto;">Save Preferences</button>
        </div>
      </div>
    `;
  },

  bindEvents(state) {
    // Close button
    document.getElementById('settings-close-btn')?.addEventListener('click', () => {
      Router.closeOverlay();
    });
    document.getElementById('settings-cancel-btn')?.addEventListener('click', () => {
      Router.closeOverlay();
    });

    // Save preferences
    document.getElementById('settings-save-btn')?.addEventListener('click', async () => {
      const incomeVal = parseFloat(document.getElementById('settings-income-field')?.value) || 0;
      await DbService.saveUserSettings({
        monthlyIncome: incomeVal,
        isOnboarded: true
      });
      Router.closeOverlay();
      StateManager.notify();
    });

    // Manual sync button
    document.getElementById('settings-sync-now-btn')?.addEventListener('click', async () => {
      if (!state.user) return;
      this.isSyncing = true;
      StateManager.setState({});

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

    // Sign out button
    document.getElementById('settings-signout-btn')?.addEventListener('click', async () => {
      if (confirm('Are you sure you want to sign out?')) {
        DbService.stopSync();
        await AuthService.signOut();
        Router.closeOverlay();
      }
    });

    // Connect cloud account
    document.getElementById('settings-connect-btn')?.addEventListener('click', () => {
      StateManager.disableGuestMode();
      Router.closeOverlay();
    });

    // Export row
    document.getElementById('settings-export-row')?.addEventListener('click', () => {
      const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(state.transactions, null, 2));
      const downloadAnchor = document.createElement('a');
      downloadAnchor.setAttribute("href", dataStr);
      downloadAnchor.setAttribute("download", `quantro_data_${new Date().toISOString().slice(0, 10)}.json`);
      document.body.appendChild(downloadAnchor);
      downloadAnchor.click();
      downloadAnchor.remove();
    });

    // Reset local cache row
    document.getElementById('settings-reset-row')?.addEventListener('click', () => {
      if (confirm('Reset offline browser cache? Your Firebase cloud data will remain safe.')) {
        StateManager.clearGuestLocalStorage();
        window.location.reload();
      }
    });
  }
};
