/* Reactive App State Management and Offline LocalStorage Fallbacks */

class AppStateManager {
  constructor() {
    this.listeners = new Set();
    
    // Default Initial State
    this.state = {
      user: null,               // Firebase User object
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

      // Theme State ('dark' | 'light')
      theme: localStorage.getItem('quantro_theme') || 'dark',

      // Cloud Sync Metadata
      syncStatus: 'idle',        // 'idle' | 'syncing' | 'synced' | 'error'
      lastSyncedAt: null,       // ISO timestamp of last successful sync
      syncError: null
    };
    
    // Apply theme on load
    document.documentElement.setAttribute('data-theme', this.state.theme);

    this.loadGuestState();
  }

  // Set Theme
  setTheme(theme) {
    this.state.theme = theme;
    localStorage.setItem('quantro_theme', theme);
    document.documentElement.setAttribute('data-theme', theme);
    this.notify();
  }

  // Toggle Theme
  toggleTheme() {
    const nextTheme = this.state.theme === 'dark' ? 'light' : 'dark';
    this.setTheme(nextTheme);
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
      this.notify();
    }
  }
}

export const StateManager = new AppStateManager();
