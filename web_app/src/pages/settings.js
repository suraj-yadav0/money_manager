/* Modern Account & Settings Modal Module */
import { StateManager } from '../state.js';
import { DbService } from '../db.js';
import { AuthService } from '../auth.js';
import { Formatters } from '../utils/formatters.js';
import { AppConstants } from '../utils/constants.js';
import { Router } from '../router.js';
import { CloudConfigModal } from './cloud-config-modal.js';
import { SetupGuideModal } from './setup-guide-modal.js';
import { isUsingCustomFirebase, getActiveProjectId } from '../firebase-config.js';
import { ColorSchemes, getTheme, isLightTheme } from '../utils/theme.js';

export const SettingsPage = {
  isSaving: false,
  isSyncing: false,
  incomeInputVal: '',
  selectedCurrency: 'INR',
  initialTheme: null,

  render(state) {
    const user = state.user;
    const settings = state.userSettings || {};
    const isCustom = isUsingCustomFirebase();
    const activeProject = getActiveProjectId();
    
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

    if (this.initialTheme === null) {
      this.initialTheme = state.theme || 'dark';
    }
    const currentTheme = getTheme(state.theme);

    return `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 660px;">
        <div class="modal-header">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary);">settings</span>
            <span>Platform Settings</span>
          </div>
          <button class="modal-close-btn" id="settings-close-btn" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <div style="display: flex; flex-direction: column; gap: 22px; max-height: 65vh; overflow-y: auto; padding-right: 4px;">
          
          <!-- Cloud Sync Card -->
          <div style="background: var(--bg-surface-subtle); border: 1px solid var(--glass-border); border-radius: var(--radius-lg); padding: 20px;">
            <div style="display: flex; align-items: center; gap: 16px; margin-bottom: 16px;">
              <div style="width: 46px; height: 46px; border-radius: 50%; background: ${user ? 'var(--success-bg)' : 'var(--bg-surface-hover)'}; display: flex; align-items: center; justify-content: center;">
                <span class="material-icons ${this.isSyncing ? 'animate-spin' : ''}" style="color: ${user ? 'var(--success)' : 'var(--text-muted)'}; font-size: 24px;">
                  ${this.isSyncing ? 'sync' : user ? 'cloud_done' : 'cloud_off'}
                </span>
              </div>
              <div style="flex: 1;">
                <div style="font-weight: 700; font-size: 16px; color: var(--text-primary);">${user ? (user.email || 'Cloud Account') : 'Private Local Storage (Offline)'}</div>
                <div style="font-size: 13px; color: var(--text-secondary); margin-top: 2px;">
                  ${user ? `Connected to ${isCustom ? `Custom Firebase (${activeProject})` : 'Cloud Firestore'} • Last synced: ${lastSyncLabel}` : 'Data is stored securely in this browser without cloud dependencies'}
                </div>
              </div>
            </div>

            <div style="display: flex; justify-content: flex-end; gap: 10px; border-top: 1px solid var(--glass-border); padding-top: 14px; flex-wrap: wrap;">
              <button class="btn-ghost" id="settings-cloud-config-btn" style="padding: 7px 14px; font-size: 12.5px;">
                <span class="material-icons" style="font-size: 15px;">tune</span>
                <span>${isCustom ? 'Manage Custom Cloud' : 'Configure Custom Cloud'}</span>
              </button>
              ${user ? `
                <button class="btn-secondary" id="settings-sync-now-btn" ${this.isSyncing ? 'disabled' : ''} style="padding: 7px 16px; font-size: 13px;">
                  <span class="material-icons ${this.isSyncing ? 'animate-spin' : ''}" style="font-size: 16px;">sync</span>
                  ${this.isSyncing ? 'Syncing...' : 'Sync Now'}
                </button>
                <button class="btn-ghost" id="settings-signout-btn" style="color: var(--error); padding: 7px 16px; font-size: 13px;">
                  <span class="material-icons" style="font-size: 16px;">logout</span> Sign Out
                </button>
              ` : `
                <button class="btn-primary" id="settings-connect-btn" style="padding: 8px 18px; font-size: 13px;">
                  <span class="material-icons" style="font-size: 16px;">login</span> Connect Cloud Account
                </button>
              `}
            </div>
          </div>

          <!-- Appearance & Color Scheme Selector -->
          <div style="background: var(--bg-surface-subtle); border: 1px solid var(--glass-border); border-radius: var(--radius-lg); padding: 20px;">
            <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px; flex-wrap: wrap; gap: 8px;">
              <div>
                <div style="font-weight: 700; font-size: 15px; color: var(--text-primary); display: flex; align-items: center; gap: 8px;">
                  <span class="material-icons" style="font-size: 18px; color: var(--primary);">palette</span>
                  <span>Website Color Scheme & Look</span>
                </div>
                <div style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">
                  Active: <strong style="color: var(--text-primary);">${currentTheme.name}</strong> (${currentTheme.badge}) • Instant live preview
                </div>
              </div>
              <button class="btn-secondary" id="settings-theme-quick-toggle" style="padding: 6px 14px; font-size: 12.5px;">
                <span class="material-icons" style="font-size: 15px;">${isLightTheme(state.theme) ? 'dark_mode' : 'light_mode'}</span>
                <span>${isLightTheme(state.theme) ? 'Switch to Dark' : 'Switch to Light'}</span>
              </button>
            </div>

            <div class="theme-selector-grid">
              ${ColorSchemes.map(scheme => {
                const isActive = (state.theme || 'dark') === scheme.id;
                return `
                  <div class="theme-card ${isActive ? 'active' : ''}" data-theme-id="${scheme.id}" title="Activate ${scheme.name}">
                    <div class="theme-card-header">
                      <div class="theme-swatch-strip">
                        <span class="theme-swatch-dot" style="background: ${scheme.bg}; border: 1px solid rgba(255,255,255,0.2);"></span>
                        <span class="theme-swatch-dot" style="background: ${scheme.surface}; border: 1px solid rgba(255,255,255,0.2);"></span>
                        <span class="theme-swatch-dot" style="background: ${scheme.primary}; box-shadow: 0 0 6px ${scheme.primary}66;"></span>
                      </div>
                      <span class="theme-mode-tag">${scheme.badge}</span>
                    </div>
                    <div class="theme-card-body">
                      <div class="theme-card-title">
                        <span>${scheme.name}</span>
                        <div class="theme-card-check">
                          <span class="material-icons">${isActive ? 'check_circle' : 'radio_button_unchecked'}</span>
                        </div>
                      </div>
                      <div class="theme-card-desc">${scheme.description}</div>
                    </div>
                  </div>
                `;
              }).join('')}
            </div>
          </div>

          <!-- Monthly Income Baseline -->
          <div class="form-group" style="margin-bottom: 0;">
            <label class="form-label">Monthly Inflow Baseline</label>
            <div style="position: relative; display: flex; align-items: center;">
              <span style="position: absolute; left: 18px; font-weight: 800; color: var(--primary); font-size: 17px;">${symbol}</span>
              <input type="number" class="form-control" id="settings-income-field" value="${this.incomeInputVal}" style="padding-left: 40px; font-weight: 700;">
            </div>
            <div style="font-size: 12px; color: var(--text-muted); margin-top: 6px;">
              Baseline benchmark for monthly savings rates and budget burn forecasts.
            </div>
          </div>

          <!-- Currency Selector -->
          <div style="display: flex; align-items: center; justify-content: space-between; background: var(--bg-surface-subtle); border: 1px solid var(--glass-border); padding: 16px 20px; border-radius: var(--radius-md); cursor: pointer;" id="settings-currency-row">
            <div>
              <div style="font-weight: 700; font-size: 15px; color: var(--text-primary);">Base Currency</div>
              <div style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">Active: ${this.selectedCurrency} (${symbol})</div>
            </div>
            <span class="material-icons" style="color: var(--text-muted);">chevron_right</span>
          </div>

          <!-- Data Export -->
          <div style="display: flex; align-items: center; justify-content: space-between; background: var(--bg-surface-subtle); border: 1px solid var(--glass-border); padding: 16px 20px; border-radius: var(--radius-md); cursor: pointer;" id="settings-export-row">
            <div>
              <div style="font-weight: 700; font-size: 15px; color: var(--text-primary);">Export Complete Backup</div>
              <div style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">Download all transactions, categories, goals, and assets as JSON</div>
            </div>
            <span class="material-icons" style="color: var(--text-muted);">download</span>
          </div>

          <!-- Data Import -->
          <input type="file" id="settings-import-file-input" accept=".json" style="display: none;">
          <div style="display: flex; align-items: center; justify-content: space-between; background: var(--bg-surface-subtle); border: 1px solid var(--glass-border); padding: 16px 20px; border-radius: var(--radius-md); cursor: pointer;" id="settings-import-row">
            <div>
              <div style="font-weight: 700; font-size: 15px; color: var(--text-primary);">Import Backup from JSON</div>
              <div style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">Restore transactions and assets onto this device</div>
            </div>
            <span class="material-icons" style="color: var(--text-muted);">upload</span>
          </div>

          <!-- Self-Hosting & Network Guide -->
          <div style="display: flex; align-items: center; justify-content: space-between; background: var(--bg-surface-subtle); border: 1px solid var(--glass-border); padding: 16px 20px; border-radius: var(--radius-md); cursor: pointer;" id="settings-setup-guide-row">
            <div>
              <div style="font-weight: 700; font-size: 15px; color: var(--text-primary);">Self-Hosting & Network Guide</div>
              <div style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">Instructions for Docker, Wi-Fi LAN access, and custom Firebase</div>
            </div>
            <span class="material-icons" style="color: var(--text-muted);">menu_book</span>
          </div>

          <!-- Purge Demo / Sample Records from Cloud (if logged in) -->
          ${user ? `
          <div style="display: flex; align-items: center; justify-content: space-between; background: var(--bg-surface-subtle); border: 1px solid var(--glass-border); padding: 16px 20px; border-radius: var(--radius-md); cursor: pointer;" id="settings-purge-demo-row">
            <div>
              <div style="font-weight: 700; font-size: 15px; color: var(--text-primary);">Purge Demo Records from Cloud</div>
              <div style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">Remove mock landing page sample records from your cloud database</div>
            </div>
            <span class="material-icons" style="color: var(--text-muted);">cleaning_services</span>
          </div>
          ` : ''}

          <!-- Reset Local Storage -->
          <div style="display: flex; align-items: center; justify-content: space-between; background: var(--error-bg); border: 1px solid rgba(255, 51, 102, 0.25); padding: 16px 20px; border-radius: var(--radius-md); cursor: pointer;" id="settings-reset-row">
            <div>
              <div style="font-weight: 700; font-size: 15px; color: var(--error);">Reset Local Cache</div>
              <div style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">Purge local browser cache without affecting cloud data</div>
            </div>
            <span class="material-icons" style="color: var(--error);">delete_forever</span>
          </div>

        </div>

        <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 28px; padding-top: 18px; border-top: 1px solid var(--glass-border);">
          <button class="btn-secondary" id="settings-cancel-btn" style="width: auto;">Cancel</button>
          <button class="btn-primary" id="settings-save-btn" style="width: auto;">Save Preferences</button>
        </div>
      </div>
    `;
  },

  bindEvents(state) {
    // Close & Cancel buttons
    const resetAndClose = (revertTheme = false) => {
      if (revertTheme && this.initialTheme && this.initialTheme !== state.theme) {
        StateManager.setTheme(this.initialTheme);
      }
      this.initialTheme = null;
      this.incomeInputVal = '';
      Router.closeOverlay();
    };

    document.getElementById('settings-close-btn')?.addEventListener('click', () => {
      resetAndClose(false);
    });
    document.getElementById('settings-cancel-btn')?.addEventListener('click', () => {
      resetAndClose(true);
    });

    // Theme selector card interactions
    const themeCards = document.querySelectorAll('.theme-card');
    themeCards.forEach(card => {
      card.addEventListener('click', () => {
        const themeId = card.getAttribute('data-theme-id');
        if (themeId) {
          StateManager.setTheme(themeId);
        }
      });
    });

    // Quick theme toggle button
    document.getElementById('settings-theme-quick-toggle')?.addEventListener('click', () => {
      StateManager.toggleTheme();
    });

    // Save preferences
    document.getElementById('settings-save-btn')?.addEventListener('click', async () => {
      const incomeVal = parseFloat(document.getElementById('settings-income-field')?.value) || 0;
      await DbService.saveUserSettings({
        monthlyIncome: incomeVal,
        isOnboarded: true,
        theme: StateManager.state.theme
      });
      this.initialTheme = null;
      this.incomeInputVal = '';
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

    // Cloud Config modal
    document.getElementById('settings-cloud-config-btn')?.addEventListener('click', () => {
      CloudConfigModal.show();
    });

    // Export complete backup
    document.getElementById('settings-export-row')?.addEventListener('click', () => {
      const backupData = StateManager.exportBackupData();
      const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(backupData, null, 2));
      const downloadAnchor = document.createElement('a');
      downloadAnchor.setAttribute("href", dataStr);
      downloadAnchor.setAttribute("download", `quantro_backup_${new Date().toISOString().slice(0, 10)}.json`);
      document.body.appendChild(downloadAnchor);
      downloadAnchor.click();
      downloadAnchor.remove();
    });

    // Import backup
    const fileInput = document.getElementById('settings-import-file-input');
    document.getElementById('settings-import-row')?.addEventListener('click', () => {
      fileInput?.click();
    });

    fileInput?.addEventListener('change', (e) => {
      const file = e.target.files?.[0];
      if (!file) return;

      const reader = new FileReader();
      reader.onload = async (event) => {
        try {
          const content = event.target?.result;
          const parsed = JSON.parse(content);

          if (state.user) {
            const res = await DbService.importBackupToCloud(state.user.uid, parsed);
            await DbService.syncNow(state.user.uid);
            alert(`Backup restored to cloud successfully!\n\nImported:\n• ${res.transactionsCount} Transactions\n• ${res.categoriesCount} Categories\n• ${res.goalsCount} Goals\n• ${res.assetsCount} Assets`);
          } else {
            const res = StateManager.importBackupData(parsed);
            alert(`Backup restored successfully!\n\nImported:\n• ${res.transactionsCount} Transactions\n• ${res.categoriesCount} Categories\n• ${res.goalsCount} Goals\n• ${res.assetsCount} Assets`);
          }
          Router.closeOverlay();
        } catch (err) {
          alert('Import failed: ' + (err.message || 'Invalid backup file'));
        }
      };
      reader.readAsText(file);
    });

    // Self-Hosting Guide modal
    document.getElementById('settings-setup-guide-row')?.addEventListener('click', () => {
      SetupGuideModal.show();
    });

    // Purge demo records from cloud
    document.getElementById('settings-purge-demo-row')?.addEventListener('click', async () => {
      if (!state.user) return;
      const row = document.getElementById('settings-purge-demo-row');
      if (row) row.style.opacity = '0.5';
      try {
        const res = await DbService.purgePollutedDemoData(state.user.uid);
        alert(`Cleanup complete!\n\nPurged ${res.purged} demo records from your cloud account:\n• ${res.transactions} Transactions\n• ${res.goals} Goals\n• ${res.assets} Assets`);
      } catch (err) {
        alert('Cleanup failed: ' + err.message);
      } finally {
        if (row) row.style.opacity = '1';
      }
    });

    // Reset local cache row
    document.getElementById('settings-reset-row')?.addEventListener('click', () => {
      if (confirm('Reset offline browser cache? Your cloud data will remain safe.')) {
        StateManager.clearGuestLocalStorage();
        window.location.reload();
      }
    });
  }
};
