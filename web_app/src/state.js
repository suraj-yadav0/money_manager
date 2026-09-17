/* Reactive App State Management and Offline LocalStorage Fallbacks */

import { getTheme, isLightTheme } from './utils/theme.js';

class AppStateManager {
  constructor() {
    this.listeners = new Set();
    this.lastDarkTheme = 'dark';
    
    // Initial State Structure
    this.state = {
      // Auth & Mode State
      user: null,               // Firebase User Object or null
      isGuestMode: false,       // Offline Local-Only Mode
      navIndex: 0,              // Current view (0=Home, 1=Budget, 2=NetWorth, 3=Goals)
      dateFilter: 'thisMonth',  // Selected date filter (thisWeek, lastWeek, thisMonth, lastMonth, thisYear, allTime)
      
      // Database Collections
      userSettings: {
        monthlyIncome: 0,
        currency: 'INR',
        isOnboarded: false,
        showIncomeChart: false,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      
      transactions: [],
      categories: [],
      goals: [],
      goalContributions: [],
      categorizationRules: [],
      assets: [],
      bankAccounts: [],

      // Theme State (supported theme IDs from ColorSchemes)
      theme: localStorage.getItem('money_manager_theme') || localStorage.getItem('quantro_theme') || (typeof window !== 'undefined' && window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark'),

      // Cloud Sync Metadata
      syncStatus: 'idle',        // 'idle' | 'syncing' | 'synced' | 'error'
      lastSyncedAt: null,       // ISO timestamp of last successful sync
      syncError: null
    };
    
    // Apply theme on load
    document.documentElement.setAttribute('data-theme', this.state.theme);
    this.updateMetaThemeColor(this.state.theme);

    this.loadGuestState();
  }

  // Update browser mobile toolbar color
  updateMetaThemeColor(themeId) {
    if (typeof document === 'undefined') return;
    const scheme = getTheme(themeId);
    const metaTag = document.getElementById('meta-theme-color') || document.querySelector('meta[name="theme-color"]');
    if (metaTag && scheme?.bg) {
      metaTag.setAttribute('content', scheme.bg);
    }
  }

  // Set Theme
  setTheme(theme) {
    const validTheme = getTheme(theme)?.id || 'dark';
    this.state.theme = validTheme;
    localStorage.setItem('money_manager_theme', validTheme);
    localStorage.setItem('quantro_theme', validTheme);
    document.documentElement.setAttribute('data-theme', validTheme);
    this.updateMetaThemeColor(validTheme);
    if (!isLightTheme(validTheme)) {
      this.lastDarkTheme = validTheme;
    }
    if (this.state.userSettings) {
      this.state.userSettings.theme = validTheme;
      if (this.state.isGuestMode) {
        this.saveGuestState();
      }
    }
    this.notify();
  }

  // Toggle Theme
  toggleTheme() {
    const current = document.documentElement.getAttribute('data-theme') || this.state.theme || 'dark';
    const isLight = isLightTheme(current);
    if (isLight) {
      this.setTheme(this.lastDarkTheme || 'dark');
    } else {
      this.lastDarkTheme = current;
      this.setTheme('light');
    }
  }

  // Register listener for state changes
  subscribe(listener) {
    this.listeners.add(listener);
    // Return unsubscribe function
    return () => this.listeners.delete(listener);
  }

  // Notify all listeners
  notify() {
    for (const listener of this.listeners) {
      try {
        listener(this.state);
      } catch (err) {
        console.error('State subscriber listener error:', err);
      }
    }
  }

  // Update specific state fields
  setState(updates) {
    this.state = { ...this.state, ...updates };
    this.notify();
  }

  // Load from LocalStorage if user was in guest mode
  loadGuestState() {
    const isGuest = localStorage.getItem('quantro_is_guest_mode') === 'true';
    this.state.isGuestMode = isGuest;

    if (isGuest && !this.state.user) {
      try {
        const savedSettings = localStorage.getItem('money_manager_user_settings');
        if (savedSettings) this.state.userSettings = JSON.parse(savedSettings);
        
        const savedTx = localStorage.getItem('money_manager_transactions');
        if (savedTx) this.state.transactions = JSON.parse(savedTx);
        
        const savedCats = localStorage.getItem('money_manager_categories');
        if (savedCats) this.state.categories = JSON.parse(savedCats);
        
        const savedGoals = localStorage.getItem('money_manager_goals');
        if (savedGoals) this.state.goals = JSON.parse(savedGoals);
        
        const savedContribs = localStorage.getItem('money_manager_goal_contributions');
        if (savedContribs) this.state.goalContributions = JSON.parse(savedContribs);
        
        const savedRules = localStorage.getItem('money_manager_categorization_rules');
        if (savedRules) this.state.categorizationRules = JSON.parse(savedRules);
        
        const savedAssets = localStorage.getItem('money_manager_assets');
        if (savedAssets) this.state.assets = JSON.parse(savedAssets);
        
        const savedBankAccs = localStorage.getItem('money_manager_bank_accounts');
        if (savedBankAccs) this.state.bankAccounts = JSON.parse(savedBankAccs);
      } catch (err) {
        console.error('Error loading guest state from localStorage:', err);
      }
    }
  }

  // Save guest state to LocalStorage (Only if explicitly in guest mode and not logged in)
  saveGuestState() {
    if (!this.state.isGuestMode || this.state.user) return;
    
    try {
      localStorage.setItem('money_manager_user_settings', JSON.stringify(this.state.userSettings));
      localStorage.setItem('money_manager_transactions', JSON.stringify(this.state.transactions));
      localStorage.setItem('money_manager_categories', JSON.stringify(this.state.categories));
      localStorage.setItem('money_manager_goals', JSON.stringify(this.state.goals));
      localStorage.setItem('money_manager_goal_contributions', JSON.stringify(this.state.goalContributions));
      localStorage.setItem('money_manager_categorization_rules', JSON.stringify(this.state.categorizationRules));
      localStorage.setItem('money_manager_assets', JSON.stringify(this.state.assets));
      localStorage.setItem('money_manager_bank_accounts', JSON.stringify(this.state.bankAccounts));
    } catch (err) {
      console.error('Error saving guest state to localStorage:', err);
    }
  }

  // Turn on guest mode
  enableGuestMode() {
    localStorage.setItem('quantro_is_guest_mode', 'true');
    this.state.isGuestMode = true;
    this.loadGuestState();
    this.notify();
  }

  // Turn off guest mode
  disableGuestMode() {
    localStorage.setItem('quantro_is_guest_mode', 'false');
    this.state.isGuestMode = false;
    this.notify();
  }

  // Clear ONLY the local guest storage keys without wiping in-memory state for logged-in users
  clearGuestLocalStorage() {
    localStorage.removeItem('money_manager_user_settings');
    localStorage.removeItem('money_manager_transactions');
    localStorage.removeItem('money_manager_categories');
    localStorage.removeItem('money_manager_goals');
    localStorage.removeItem('money_manager_goal_contributions');
    localStorage.removeItem('money_manager_categorization_rules');
    localStorage.removeItem('money_manager_assets');
    localStorage.removeItem('money_manager_bank_accounts');
    localStorage.removeItem('quantro_is_guest_mode');
    this.state.isGuestMode = false;
  }

  // Full reset (used on hard reset / wipe data when in guest mode or on sign-out)
  clearGuestData() {
    this.clearGuestLocalStorage();
    
    // Only reset in-memory state if user is NOT logged in with Firebase
    if (!this.state.user) {
      this.state.userSettings = {
        monthlyIncome: 0,
        currency: 'INR',
        isOnboarded: false,
        showIncomeChart: false,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
      this.state.transactions = [];
      this.state.categories = [];
      this.state.goals = [];
      this.state.goalContributions = [];
      this.state.categorizationRules = [];
      this.state.assets = [];
      this.state.bankAccounts = [];
      this.notify();
    }
  }

  // Export all local data to a portable JSON object
  exportBackupData() {
    return {
      version: 1,
      exportedAt: new Date().toISOString(),
      userSettings: this.state.userSettings,
      categories: this.state.categories,
      transactions: this.state.transactions,
      goals: this.state.goals,
      goalContributions: this.state.goalContributions,
      categorizationRules: this.state.categorizationRules,
      assets: this.state.assets,
      bankAccounts: this.state.bankAccounts
    };
  }

  // Check if there is genuine user data (not demo data) in local guest storage or state
  hasGuestData() {
    try {
      const isReal = item => item && !item.is_demo && !item.isDemo;
      if (Array.isArray(this.state.transactions) && this.state.transactions.some(isReal)) return true;
      if (Array.isArray(this.state.goals) && this.state.goals.some(isReal)) return true;
      if (Array.isArray(this.state.assets) && this.state.assets.some(isReal)) return true;

      const txStr = localStorage.getItem('money_manager_transactions');
      if (txStr) {
        const txs = JSON.parse(txStr);
        if (Array.isArray(txs) && txs.some(isReal)) return true;
      }
      const goalStr = localStorage.getItem('money_manager_goals');
      if (goalStr) {
        const goals = JSON.parse(goalStr);
        if (Array.isArray(goals) && goals.some(isReal)) return true;
      }
      const assetStr = localStorage.getItem('money_manager_assets');
      if (assetStr) {
        const assets = JSON.parse(assetStr);
        if (Array.isArray(assets) && assets.some(isReal)) return true;
      }
      const accStr = localStorage.getItem('money_manager_bank_accounts');
      if (accStr) {
        const accs = JSON.parse(accStr);
        if (Array.isArray(accs) && accs.length > 0) return true;
      }
    } catch (err) {
      console.warn('Error checking guest data:', err);
    }
    return false;
  }

  // Import JSON backup data and persist to local storage
  importBackupData(jsonString) {
    try {
      const data = typeof jsonString === 'string' ? JSON.parse(jsonString) : jsonString;
      if (!data || typeof data !== 'object') throw new Error('Invalid JSON format');

      const generateId = () => {
        if (typeof crypto !== 'undefined' && crypto.randomUUID) {
          return crypto.randomUUID();
        }
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
          const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
          return v.toString(16);
        });
      };

      const normalize = (items) => {
        if (!Array.isArray(items)) return [];
        return items.map(item => ({
          ...item,
          sync_id: item.sync_id || item.id || generateId(),
          is_demo: false,
          isDemo: false
        }));
      };

      if (Array.isArray(data.transactions)) this.state.transactions = normalize(data.transactions);
      if (Array.isArray(data.categories)) this.state.categories = normalize(data.categories);
      if (Array.isArray(data.goals)) this.state.goals = normalize(data.goals);
      if (Array.isArray(data.goalContributions)) this.state.goalContributions = normalize(data.goalContributions);
      if (Array.isArray(data.categorizationRules)) this.state.categorizationRules = data.categorizationRules;
      if (Array.isArray(data.assets)) this.state.assets = normalize(data.assets);
      if (Array.isArray(data.bankAccounts)) this.state.bankAccounts = normalize(data.bankAccounts);
      if (data.userSettings && typeof data.userSettings === 'object') {
        this.state.userSettings = { ...this.state.userSettings, ...data.userSettings, is_demo: false };
      }

      this.saveGuestState();
      this.notify();
      return {
        transactionsCount: this.state.transactions.length,
        categoriesCount: this.state.categories.length,
        goalsCount: this.state.goals.length,
        assetsCount: this.state.assets.length
      };
    } catch (err) {
      throw new Error('Failed to import backup: ' + err.message);
    }
  }
}

export const StateManager = new AppStateManager();
