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
      assets: []
    };
    
    this.loadGuestState();
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
      listener(this.state);
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

    if (isGuest) {
      this.state.userSettings = JSON.parse(localStorage.getItem('money_manager_user_settings')) || this.state.userSettings;
      this.state.transactions = JSON.parse(localStorage.getItem('money_manager_transactions')) || [];
      this.state.categories = JSON.parse(localStorage.getItem('money_manager_categories')) || [];
      this.state.goals = JSON.parse(localStorage.getItem('money_manager_goals')) || [];
      this.state.goalContributions = JSON.parse(localStorage.getItem('money_manager_goal_contributions')) || [];
      this.state.categorizationRules = JSON.parse(localStorage.getItem('money_manager_categorization_rules')) || [];
      this.state.assets = JSON.parse(localStorage.getItem('money_manager_assets')) || [];
    }
  }

  // Save guest state to LocalStorage
  saveGuestState() {
    if (!this.state.isGuestMode) return;
    
    localStorage.setItem('money_manager_user_settings', JSON.stringify(this.state.userSettings));
    localStorage.setItem('money_manager_transactions', JSON.stringify(this.state.transactions));
    localStorage.setItem('money_manager_categories', JSON.stringify(this.state.categories));
    localStorage.setItem('money_manager_goals', JSON.stringify(this.state.goals));
    localStorage.setItem('money_manager_goal_contributions', JSON.stringify(this.state.goalContributions));
    localStorage.setItem('money_manager_categorization_rules', JSON.stringify(this.state.categorizationRules));
    localStorage.setItem('money_manager_assets', JSON.stringify(this.state.assets));
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

  // Clear all local guest storage
  clearGuestData() {
    localStorage.removeItem('money_manager_user_settings');
    localStorage.removeItem('money_manager_transactions');
    localStorage.removeItem('money_manager_categories');
    localStorage.removeItem('money_manager_goals');
    localStorage.removeItem('money_manager_goal_contributions');
    localStorage.removeItem('money_manager_categorization_rules');
    localStorage.removeItem('money_manager_assets');
    
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

export const StateManager = new AppStateManager();
