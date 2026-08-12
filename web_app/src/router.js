/* Client-side Single Page Application router matching Flutter screen logic */
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

export const Router = {
  // Mount target container
  targetElement: null,
  activeOverlayPage: null, // Settings, Insights, Calendar, AllTransactions

  init(selector) {
    this.targetElement = document.querySelector(selector);
    
    // Subscribe to State Changes to automatically re-route/re-render
    StateManager.subscribe((state) => {
      this.render(state);
    });

    // Initial render
    this.render(StateManager.state);
  },

  // Navigate to overlays (Settings, Insights, Calendar)
  navigateToOverlay(pageKey) {
    this.activeOverlayPage = pageKey;
    StateManager.notify(); // Trigger re-render with overlay active
  },

  closeOverlay() {
    this.activeOverlayPage = null;
    StateManager.notify();
  },

  render(state) {
    if (!this.targetElement) return;

    // 1. Check Onboarding
    const isOnboarded = state.userSettings && (state.userSettings.is_onboarded === true || state.userSettings.isOnboarded === true);
    if (!isOnboarded) {
      this.targetElement.innerHTML = OnboardingPage.render(state);
      OnboardingPage.bindEvents();
      return;
    }

    // 2. Check Authentication
    const isLoggedIn = state.user !== null;
    const isGuest = state.isGuestMode;
    
    if (!isLoggedIn && !isGuest) {
      this.targetElement.innerHTML = AuthPage.render(state);
      AuthPage.bindEvents();
      return;
    }

    // 3. Render Main App Shell Structure
    this.renderAppShell(state);
  },

  renderAppShell(state) {
    const navIndex = state.navIndex;
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';

    let pageTitle = 'Quantro';
    let contentHtml = '';
    
    // Render main pages based on navIndex
    if (navIndex === 0) {
      pageTitle = 'Dashboard';
      contentHtml = DashboardPage.render(state);
    } else if (navIndex === 1) {
      pageTitle = 'Budget';
      contentHtml = BudgetPage.render(state);
    } else if (navIndex === 2) {
      pageTitle = 'Net Worth';
      contentHtml = NetWorthPage.render(state);
    } else if (navIndex === 3) {
      pageTitle = 'Goals';
      contentHtml = GoalsPage.render(state);
    }

    // Desktop App Shell HTML
    const shellHtml = `
      <div class="app-container">
        <!-- Floating animated blobs in shell background -->
        <div class="bg-blobs">
          <div class="blob blob-orange"></div>
          <div class="blob blob-blue"></div>
          <div class="blob blob-red"></div>
        </div>

        <!-- Desktop Sidebar -->
        <aside class="sidebar">
          <div class="sidebar-header">
            <div style="width:36px; height:36px; background:linear-gradient(135deg, var(--primary) 0%, #FF8C42 100%); border-radius:10px; display:flex; align-items:center; justify-content:center;">
              <span class="material-icons" style="color:#FFF; font-size:20px;">account_balance_wallet</span>
            </div>
            <div class="sidebar-title">Quantro</div>
          </div>

          <button class="nav-fab-desktop" id="nav-add-btn">
            <span class="material-icons">add</span> Add Transaction
          </button>

          <div class="nav-links">
            <div class="nav-item ${navIndex === 0 ? 'active' : ''}" data-index="0">
              <span class="material-icons">grid_view</span> Dashboard
            </div>
            <div class="nav-item ${navIndex === 1 ? 'active' : ''}" data-index="1">
              <span class="material-icons">account_balance_wallet</span> Budget
            </div>
            <div class="nav-item ${navIndex === 2 ? 'active' : ''}" data-index="2">
              <span class="material-icons">account_balance</span> Net Worth
            </div>
            <div class="nav-item ${navIndex === 3 ? 'active' : ''}" data-index="3">
              <span class="material-icons">savings</span> Goals
            </div>
            <div class="divider" style="background: rgba(255,255,255,0.05); margin:8px 0;"></div>
            <div class="nav-item" id="sidebar-insights-btn">
              <span class="material-icons">insights</span> Insights
              ${state.transactions.length > 5 ? '<div style="margin-left:auto; width:8px; height:8px; background:var(--primary); border-radius:50%;"></div>' : ''}
            </div>
            <div class="nav-item" id="sidebar-calendar-btn">
              <span class="material-icons">calendar_month</span> Calendar
            </div>
            <div class="nav-item" id="sidebar-transactions-btn">
              <span class="material-icons">receipt_long</span> All Transactions
            </div>
          </div>

          <div class="sidebar-footer">
            <div class="nav-item" id="sidebar-settings-btn">
              <span class="material-icons">settings</span> Settings
            </div>
          </div>
        </aside>

        <!-- Main Content -->
        <main class="main-content">
          <header class="desktop-header">
            <div class="header-title">${pageTitle}</div>
            <div class="header-actions">
              <div style="font-size:14px; font-weight:600; color:var(--text-secondary); background:rgba(255,255,255,0.05); padding:8px 16px; border-radius:20px;">
                ${state.isGuestMode ? 'Guest Mode' : state.user?.email || 'User'}
              </div>
            </div>
          </header>
          
          <div class="app-body" id="app-content-body">
            ${contentHtml}
          </div>
        </main>
      </div>

      <!-- Full-Screen Overlays -->
      <div class="modal-overlay" id="overlay-container">
        <!-- Dynamic overlay page container -->
      </div>
    `;

    this.targetElement.innerHTML = shellHtml;

    // Bind navigation and overlay buttons
    this.bindShellEvents(state);

    // Call active page bindings
    if (navIndex === 0) DashboardPage.bindEvents(state);
    else if (navIndex === 1) BudgetPage.bindEvents(state);
    else if (navIndex === 2) NetWorthPage.bindEvents(state);
    else if (navIndex === 3) GoalsPage.bindEvents(state);

    // Render active overlay if any exists
    if (this.activeOverlayPage) {
      const overlayOverlay = document.getElementById('overlay-container');
      overlayOverlay.classList.add('active');
      
      if (this.activeOverlayPage === 'settings') {
        overlayOverlay.innerHTML = SettingsPage.render(state);
        SettingsPage.bindEvents(state);
      } else if (this.activeOverlayPage === 'insights') {
        overlayOverlay.innerHTML = InsightsPage.render(state);
        InsightsPage.bindEvents(state);
      } else if (this.activeOverlayPage === 'calendar') {
        overlayOverlay.innerHTML = CalendarPage.render(state);
        CalendarPage.bindEvents(state);
      } else if (this.activeOverlayPage === 'all-transactions') {
        overlayOverlay.innerHTML = AllTransactionsPage.render(state);
        AllTransactionsPage.bindEvents(state);
      }
    }
  },

  bindShellEvents(state) {
    // Navigation items click
    const navItems = document.querySelectorAll('.nav-links .nav-item[data-index]');
    navItems.forEach(item => {
      item.addEventListener('click', () => {
        const index = parseInt(item.getAttribute('data-index'), 10);
        StateManager.setState({ navIndex: index });
      });
    });

    // Add Transaction button click
    const addBtn = document.getElementById('nav-add-btn');
    if (addBtn) {
      addBtn.addEventListener('click', () => {
        import('./pages/add-transaction.js').then(({ AddTransactionModal }) => {
          AddTransactionModal.show(null);
        });
      });
    }

    // Overlays click
    document.getElementById('sidebar-settings-btn')?.addEventListener('click', () => {
      this.navigateToOverlay('settings');
    });

    document.getElementById('sidebar-insights-btn')?.addEventListener('click', () => {
      this.navigateToOverlay('insights');
    });

    document.getElementById('sidebar-calendar-btn')?.addEventListener('click', () => {
      this.navigateToOverlay('calendar');
    });

    document.getElementById('sidebar-transactions-btn')?.addEventListener('click', () => {
      this.navigateToOverlay('all-transactions');
    });
  }
};
