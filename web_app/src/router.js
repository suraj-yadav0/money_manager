/* Client-side Single Page Application router with Modern Website Architecture */
import { StateManager } from './state.js';
import { AuthPage } from './pages/auth.js';
import { OnboardingPage } from './pages/onboarding.js';
import { DashboardPage } from './pages/dashboard.js';
import { BudgetPage } from './pages/budget.js';
import { NetWorthPage } from './pages/net-worth.js';
import { GoalsPage } from './pages/goals.js';
import { SettingsPage } from './pages/settings.js';
import { InsightsPage } from './pages/insights.js';
import { CalendarPage } from './pages/calendar.js';
import { AllTransactionsPage } from './pages/all-transactions.js';
import { DbService } from './db.js';

export const Router = {
  targetElement: null,
  activeOverlayPage: null, // 'settings', 'insights', 'calendar', 'all-transactions'

  init(selector) {
    this.targetElement = document.querySelector(selector);
    
    // Subscribe to State Changes to automatically re-render
    StateManager.subscribe((state) => {
      this.render(state);
    });

    // Initial render
    this.render(StateManager.state);
  },

  // Open modal overlay
  openOverlay(pageKey) {
    this.activeOverlayPage = pageKey;
    StateManager.notify();
  },

  closeOverlay() {
    this.activeOverlayPage = null;
    StateManager.notify();
  },

  render(state) {
    if (!this.targetElement) return;

    // 1. If user is authenticated with Firebase:
    if (state.user) {
      this.renderWebsite(state);
      return;
    }

    // 2. If user is in guest mode:
    if (state.isGuestMode) {
      const isOnboarded = state.userSettings && (state.userSettings.is_onboarded === true || state.userSettings.isOnboarded === true);
      if (isOnboarded) {
        this.renderWebsite(state);
        return;
      }
      this.targetElement.innerHTML = OnboardingPage.render(state);
      OnboardingPage.bindEvents();
      return;
    }

    // 3. Unauthenticated landing / auth view
    this.targetElement.innerHTML = AuthPage.render(state);
    AuthPage.bindEvents();
  },

  renderWebsite(state) {
    const navIndex = state.navIndex || 0;

    let contentHtml = '';
    
    if (navIndex === 0) {
      contentHtml = DashboardPage.render(state);
    } else if (navIndex === 1) {
      contentHtml = AllTransactionsPage.render(state);
    } else if (navIndex === 2) {
      contentHtml = BudgetPage.render(state);
    } else if (navIndex === 3) {
      contentHtml = GoalsPage.render(state);
    } else if (navIndex === 4) {
      contentHtml = NetWorthPage.render(state);
    } else if (navIndex === 5) {
      contentHtml = InsightsPage.render(state);
    } else if (navIndex === 6) {
      contentHtml = CalendarPage.render(state);
    } else {
      contentHtml = DashboardPage.render(state);
    }

    // Sync Status badge indicators
    let syncLabel = 'Cloud Synced';
    let syncClass = '';
    if (state.syncStatus === 'syncing') {
      syncLabel = 'Syncing...';
      syncClass = 'syncing';
    } else if (state.syncStatus === 'error') {
      syncLabel = 'Sync Warning';
      syncClass = 'error';
    }

    const html = `
      <div class="site-wrapper animate-fade-in">
        <!-- Ambient lighting mesh -->
        <div class="ambient-glow">
          <div class="ambient-circle-1"></div>
          <div class="ambient-circle-2"></div>
        </div>

        <!-- Top Navigation Header -->
        <header class="site-header">
          <div class="site-container">
            <div class="header-inner">
              <!-- Brand Logo -->
              <div class="brand-link" id="brand-logo-btn">
                <div class="brand-icon">
                  <span class="material-icons">account_balance_wallet</span>
                </div>
                <div class="brand-name">
                  Quantro
                  <span class="brand-tag">PRO</span>
                </div>
              </div>

              <!-- Main Navigation Links -->
              <nav class="header-nav">
                <button class="nav-link-btn ${navIndex === 0 ? 'active' : ''}" data-nav="0">
                  <span class="material-icons">dashboard</span> Overview
                </button>
                <button class="nav-link-btn ${navIndex === 1 ? 'active' : ''}" data-nav="1">
                  <span class="material-icons">receipt_long</span> Ledger
                </button>
                <button class="nav-link-btn ${navIndex === 2 ? 'active' : ''}" data-nav="2">
                  <span class="material-icons">pie_chart</span> Budget
                </button>
                <button class="nav-link-btn ${navIndex === 3 ? 'active' : ''}" data-nav="3">
                  <span class="material-icons">savings</span> Goals
                </button>
                <button class="nav-link-btn ${navIndex === 4 ? 'active' : ''}" data-nav="4">
                  <span class="material-icons">account_balance</span> Net Worth
                </button>
                <button class="nav-link-btn ${navIndex === 5 ? 'active' : ''}" data-nav="5">
                  <span class="material-icons">insights</span> Insights
                </button>
                <button class="nav-link-btn ${navIndex === 6 ? 'active' : ''}" data-nav="6">
                  <span class="material-icons">calendar_month</span> Calendar
                </button>
              </nav>

              <!-- Header Action Controls -->
              <div class="header-actions">
                ${state.user ? `
                  <div class="sync-pill ${syncClass}" id="header-sync-btn" title="Click to trigger full Cloud Sync">
                    <span class="sync-dot"></span>
                    <span>${syncLabel}</span>
                  </div>
                ` : `
                  <div class="sync-pill" id="header-connect-btn" style="border-color: rgba(255,255,255,0.12);" title="Connect Firebase account">
                    <span class="material-icons" style="font-size: 14px; color: var(--text-muted);">cloud_off</span>
                    <span>Guest Mode</span>
                  </div>
                `}

                <button class="btn-icon" id="header-theme-btn" title="Toggle Light / Dark Mode">
                  <span class="material-icons" style="font-size: 18px;">${state.theme === 'light' ? 'dark_mode' : 'light_mode'}</span>
                </button>

                <button class="btn-primary" id="header-add-tx-btn">
                  <span class="material-icons" style="font-size: 18px;">add</span> Record
                </button>

                <button class="btn-icon" id="header-settings-btn" title="Account & Preferences">
                  <span class="material-icons">settings</span>
                </button>
              </div>
            </div>
          </div>
        </header>

        <!-- Main Content Area -->
        <main class="main-content-section" style="flex: 1;">
          <div class="site-container">
            ${contentHtml}
          </div>
        </main>

        <!-- Footer -->
        <footer class="site-footer">
          <div class="site-container">
            <div class="footer-inner">
              <div style="display: flex; align-items: center; gap: 8px;">
                <div style="width: 20px; height: 20px; border-radius: 6px; background: var(--primary); display: flex; align-items: center; justify-content: center;">
                  <span class="material-icons" style="font-size: 12px; color: #FFF;">account_balance_wallet</span>
                </div>
                <span style="font-weight: 700; color: var(--text-primary);">Quantro Finance</span>
                <span>• Privacy-first Cloud Synced Wealth Platform</span>
              </div>
              <div>
                <span>Encrypted with Cloud Firestore • Real-time Cross-Platform Sync</span>
              </div>
            </div>
          </div>
        </footer>
      </div>

      <!-- Global Overlay Container for Modals -->
      <div class="modal-overlay ${this.activeOverlayPage ? 'active' : ''}" id="app-overlay-container">
        <!-- Render Active Overlay Dialog -->
      </div>
    `;

    this.targetElement.innerHTML = html;

    // Bind Page Events
    if (navIndex === 0) DashboardPage.bindEvents(state);
    else if (navIndex === 1) AllTransactionsPage.bindEvents(state);
    else if (navIndex === 2) BudgetPage.bindEvents(state);
    else if (navIndex === 3) GoalsPage.bindEvents(state);
    else if (navIndex === 4) NetWorthPage.bindEvents(state);
    else if (navIndex === 5) InsightsPage.bindEvents(state);
    else if (navIndex === 6) CalendarPage.bindEvents(state);

    // Bind Global Header Navigation Events
    this.bindHeaderEvents(state);

    // Render Overlay if active
    this.renderActiveOverlay(state);
  },

  bindHeaderEvents(state) {
    // Brand click returns to overview
    document.getElementById('brand-logo-btn')?.addEventListener('click', () => {
      StateManager.setState({ navIndex: 0 });
    });

    // Nav Link tabs
    const navButtons = document.querySelectorAll('.header-nav .nav-link-btn');
    navButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        const index = parseInt(btn.getAttribute('data-nav'), 10);
        StateManager.setState({ navIndex: index });
      });
    });

    // Cloud Sync trigger in header
    const syncBtn = document.getElementById('header-sync-btn');
    if (syncBtn && state.user) {
      syncBtn.addEventListener('click', async () => {
        try {
          const res = await DbService.syncNow(state.user.uid);
          alert(`Cloud sync complete!\n\nSynced:\n• ${res.count.transactions} Transactions\n• ${res.count.categories} Categories\n• ${res.count.goals} Goals\n• ${res.count.assets} Assets`);
        } catch (e) {
          console.error('Header sync error:', e);
          alert('Sync error: ' + (e.message || 'Unknown network error'));
        }
      });
    }

    // Connect cloud account button for guests
    document.getElementById('header-connect-btn')?.addEventListener('click', () => {
      StateManager.disableGuestMode();
    });

    // Record Transaction quick action button
    document.getElementById('header-add-tx-btn')?.addEventListener('click', () => {
      import('./pages/add-transaction.js').then(({ AddTransactionModal }) => {
        AddTransactionModal.show(null);
      });
    });

    // Theme toggle button in header
    document.getElementById('header-theme-btn')?.addEventListener('click', () => {
      StateManager.toggleTheme();
    });

    // Settings trigger button
    document.getElementById('header-settings-btn')?.addEventListener('click', () => {
      this.openOverlay('settings');
    });
  },

  renderActiveOverlay(state) {
    const overlayContainer = document.getElementById('app-overlay-container');
    if (!overlayContainer) return;

    if (!this.activeOverlayPage) {
      overlayContainer.innerHTML = '';
      overlayContainer.classList.remove('active');
      return;
    }

    overlayContainer.classList.add('active');

    if (this.activeOverlayPage === 'settings') {
      overlayContainer.innerHTML = SettingsPage.render(state);
      SettingsPage.bindEvents(state);
    }

    // Close overlay on backdrop click
    overlayContainer.addEventListener('click', (e) => {
      if (e.target === overlayContainer) {
        this.closeOverlay();
      }
    });
  }
};
