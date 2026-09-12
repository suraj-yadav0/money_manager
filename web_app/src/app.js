/* Main Web App Entry Point: CSS imports, auth state binding, and router initialization */
import './css/variables.css';
import './css/base.css';
import './css/components.css';
import './css/layout.css';
import './css/pages.css';

import { StateManager } from './state.js';
import { AuthService } from './auth.js';
import { DbService } from './db.js';
import { Router } from './router.js';

// Setup theme switcher baseline (default: dark theme)
function initializeTheme() {
  const savedTheme = localStorage.getItem('money_manager_theme') || localStorage.getItem('quantro_theme') || 'dark';
  document.documentElement.setAttribute('data-theme', savedTheme);
}

// Initialise Application
async function initApp() {
  initializeTheme();

  // Populate realistic sample data if demo query param is set
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get('demo') === 'true' || urlParams.get('demo') === '1') {
    const now = new Date();
    const isoDate = (dayOffset, hour = 12) => {
      const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - dayOffset, hour, 0, 0);
      return d.toISOString();
    };

    StateManager.state.isGuestMode = true;
    StateManager.state.userSettings = {
      sync_id: 'demo-settings',
      monthlyIncome: 120000,
      monthly_income: 120000,
      currency: 'INR',
      isOnboarded: true,
      is_onboarded: true,
      showIncomeChart: true,
      createdAt: now.toISOString(),
      updatedAt: now.toISOString()
    };

    StateManager.state.categories = [
      { id: 1, name: 'Salary', icon: 'payments', type: 'income', color: '#10b981' },
      { id: 2, name: 'Freelance', icon: 'laptop', type: 'income', color: '#3b82f6' },
      { id: 3, name: 'Food & Dining', icon: 'restaurant', type: 'expense', color: '#f59e0b', monthly_budget: 20000 },
      { id: 4, name: 'Transport', icon: 'directions_car', type: 'expense', color: '#6366f1', monthly_budget: 10000 },
      { id: 5, name: 'Shopping', icon: 'shopping_bag', type: 'expense', color: '#ec4899', monthly_budget: 15000 },
      { id: 6, name: 'Bills & Utilities', icon: 'receipt', type: 'expense', color: '#ef4444', monthly_budget: 18000 },
      { id: 7, name: 'Entertainment', icon: 'movie', type: 'expense', color: '#8b5cf6', monthly_budget: 8000 },
      { id: 8, name: 'Investments', icon: 'trending_up', type: 'expense', color: '#06b6d4', monthly_budget: 30000 }
    ];

    StateManager.state.transactions = [
      { id: 'tx-1', amount: 120000, type: 'income', category_id: 1, note: 'Monthly Salary Credit', timestamp: isoDate(2) },
      { id: 'tx-2', amount: 35000, type: 'income', category_id: 2, note: 'UI Design Consulting', timestamp: isoDate(5) },
      { id: 'tx-3', amount: 14500, type: 'expense', category_id: 3, note: 'Gourmet Dinner & Bistro', timestamp: isoDate(1) },
      { id: 'tx-4', amount: 4200, type: 'expense', category_id: 4, note: 'Uber Commute', timestamp: isoDate(1) },
      { id: 'tx-5', amount: 12800, type: 'expense', category_id: 5, note: 'Electronics & Peripherals', timestamp: isoDate(3) },
      { id: 'tx-6', amount: 16500, type: 'expense', category_id: 6, note: 'Apartment Utilities & Fiber', timestamp: isoDate(4) },
      { id: 'tx-7', amount: 5400, type: 'expense', category_id: 7, note: 'Concert & Streaming Subs', timestamp: isoDate(6) },
      { id: 'tx-8', amount: 25000, type: 'expense', category_id: 8, note: 'Index Mutual Fund SIP', timestamp: isoDate(7) },
      { id: 'tx-9', amount: 3800, type: 'expense', category_id: 3, note: 'Weekly Groceries Mart', timestamp: isoDate(8) }
    ];

    StateManager.state.goals = [
      { id: 'goal-1', name: 'Emergency Reserve', target_amount: 300000, saved_amount: 225000, deadline: new Date(now.getFullYear(), now.getMonth() + 4, 1).toISOString(), is_active: true, is_completed: false },
      { id: 'goal-2', name: 'Tech Workspace Upgrade', target_amount: 150000, saved_amount: 95000, deadline: new Date(now.getFullYear(), now.getMonth() + 2, 1).toISOString(), is_active: true, is_completed: false }
    ];

    StateManager.state.assets = [
      { id: 'ast-1', name: 'Primary HDFC Savings', type: 'savings', typeLabel: 'Savings', value: 380000, is_liability: false, icon: 'account_balance' },
      { id: 'ast-2', name: 'Equities Portfolio', type: 'investment', typeLabel: 'Investments', value: 850000, is_liability: false, icon: 'trending_up' },
      { id: 'ast-3', name: 'Car Loan Facility', type: 'loan', typeLabel: 'Loan', value: 120000, is_liability: true, icon: 'directions_car' }
    ];

    StateManager.saveGuestState();
  }
  
  // 1. Initialize client-side SPA routing inside '#app' element
  Router.init('#app');

  // 2. Watch Firebase Auth state changes
  AuthService.watchAuthState(async (user) => {
    if (user) {
      // User is logged in, sync with cloud Firestore in real-time
      DbService.startSync(user.uid);
      
      // Auto transition/close Auth overlays if active
      if (Router.activeOverlayPage === 'auth') {
        Router.closeOverlay();
      }
    } else {
      // User is logged out, disable Firestore listeners
      DbService.stopSync();
      
      // Check if user was using Guest/Offline Mode
      if (StateManager.state.isGuestMode) {
        StateManager.loadGuestState();
      } else {
        // Clear active data lists since they are logged out and not guest
        StateManager.setState({
          transactions: [],
          categories: [],
          goals: [],
          goalContributions: [],
          categorizationRules: [],
          assets: []
        });
      }
    }
  });
}

// Start app on DOMContentLoaded
window.addEventListener('DOMContentLoaded', initApp);
