/* Database services: handles Firestore CRUD, real-time sync, and LocalStorage fallbacks */
import { 
  collection, 
  doc, 
  setDoc, 
  addDoc, 
  updateDoc, 
  deleteDoc, 
  onSnapshot, 
  getDocs,
  query, 
  where 
} from 'firebase/firestore';
import { db } from './firebase-config.js';
import { StateManager } from './state.js';

// Helper to generate UUIDs locally (for new documents/IDs)
function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// Active subscription cleanups
let activeListeners = [];

export const DbService = {
  // Start real-time sync listeners for all collections for a logged-in user
  startSync(userId) {
    this.stopSync();

    const userDocRef = doc(db, 'users', userId);

    const setupListener = (subCollectionName, stateKey) => {
      const q = collection(userDocRef, subCollectionName);
      const unsubscribe = onSnapshot(q, (snapshot) => {
        const data = [];
        snapshot.forEach((doc) => {
          const raw = doc.data();
          const normalized = { ...raw, sync_id: doc.id };
          
          // Map snake_case from Flutter Firestore to camelCase for Web App
          if (raw.category_id !== undefined) normalized.categoryId = raw.category_id;
          if (raw.goal_id !== undefined) normalized.goalId = raw.goal_id;
          if (raw.payment_mode !== undefined) normalized.paymentMode = raw.payment_mode;
          if (raw.receipt_image_path !== undefined) normalized.receiptImagePath = raw.receipt_image_path;
          if (raw.is_recurring !== undefined) normalized.isRecurring = raw.is_recurring;
          
          if (raw.monthly_income !== undefined) normalized.monthlyIncome = raw.monthly_income;
          if (raw.is_onboarded !== undefined) normalized.isOnboarded = raw.is_onboarded;
          if (raw.biometric_enabled !== undefined) normalized.biometricEnabled = raw.biometric_enabled;
          if (raw.show_income_chart !== undefined) normalized.showIncomeChart = raw.show_income_chart;
          
          if (raw.target_amount !== undefined) normalized.targetAmount = raw.target_amount;
          if (raw.saved_amount !== undefined) normalized.savedAmount = raw.saved_amount;
          
          if (raw.is_liability !== undefined) normalized.isLiability = raw.is_liability;

          data.push(normalized);
        });
        
        // Map user_settings since it's a single object in state
        if (stateKey === 'userSettings') {
          if (data.length > 0) {
            StateManager.setState({ userSettings: data[0] });
          } else {
            // If settings are completely empty, seed them
            this.seedUserSettings(userId);
          }
        } else {
          StateManager.setState({ [stateKey]: data });
        }
      }, (error) => {
        console.error(`Firestore listener error on ${subCollectionName}:`, error);
      });
      activeListeners.push(unsubscribe);
    };

    // Setup active listeners for all 7 subcollections
    setupListener('user_settings', 'userSettings');
    setupListener('transactions', 'transactions');
    setupListener('categories', 'categories');
    setupListener('goals', 'goals');
    setupListener('goal_contributions', 'goalContributions');
    setupListener('categorization_rules', 'categorizationRules');
    setupListener('assets', 'assets');
  },

  // Stop all active real-time listeners (e.g. on sign out)
  stopSync() {
    for (const unsubscribe of activeListeners) {
      unsubscribe();
    }
    activeListeners = [];
  },

  // Seed default settings in Firestore
  async seedUserSettings(userId) {
    const syncId = generateUUID();
    const payload = {
      sync_id: syncId,
      user_id: userId,
      monthly_income: 0,
      currency: 'INR',
      is_onboarded: false,
      show_income_chart: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    const settingsDoc = doc(db, 'users', userId, 'user_settings', syncId);
    await setDoc(settingsDoc, payload);
    
    // Also seed default categories
    await this.seedDefaultCategories(userId);
  },

  // Seed default categories matching Drift database
  async seedDefaultCategories(userId) {
    const defaultExpenseCategories = [
      { name: 'Food & Dining', icon: 'restaurant', type: 'expense', is_default: true },
      { name: 'Transport', icon: 'directions_car', type: 'expense', is_default: true },
      { name: 'Shopping', icon: 'shopping_bag', type: 'expense', is_default: true },
      { name: 'Entertainment', icon: 'local_movies', type: 'expense', is_default: true },
      { name: 'Bills & Utilities', icon: 'receipt_long', type: 'expense', is_default: true },
      { name: 'Health', icon: 'local_hospital', type: 'expense', is_default: true },
      { name: 'Education', icon: 'school', type: 'expense', is_default: true },
      { name: 'Self Care', icon: 'spa', type: 'expense', is_default: true },
      { name: 'Groceries', icon: 'local_grocery_store', type: 'expense', is_default: true },
      { name: 'Gifts', icon: 'card_giftcard', type: 'expense', is_default: true },
      { name: 'Savings', icon: 'savings', type: 'expense', is_default: true },
      { name: 'Investments', icon: 'show_chart', type: 'expense', is_default: true },
      { name: 'Family', icon: 'family_restroom', type: 'expense', is_default: true },
      { name: 'Other', icon: 'more_horiz', type: 'expense', is_default: true }
    ];

    const defaultIncomeCategories = [
      { name: 'Salary', icon: 'work', type: 'income', is_default: true },
      { name: 'Freelance', icon: 'laptop', type: 'income', is_default: true },
      { name: 'Investment', icon: 'trending_up', type: 'income', is_default: true },
      { name: 'Other Income', icon: 'attach_money', type: 'income', is_default: true }
    ];

    const allCats = [...defaultExpenseCategories, ...defaultIncomeCategories];
    const batchPromises = allCats.map(cat => {
      const syncId = generateUUID();
      const payload = {
        ...cat,
        sync_id: syncId,
        user_id: userId,
        monthly_budget: 0,
        updated_at: new Date().toISOString()
      };
      return setDoc(doc(db, 'users', userId, 'categories', syncId), payload);
    });

    await Promise.all(batchPromises);
    
    // Seed default categorization rules
    await this.seedDefaultRules(userId);
  },

  async seedDefaultRules(userId) {
    // We need to fetch the newly created category document mapping
    const categoriesSnap = await getDocs(collection(db, 'users', userId, 'categories'));
    const categoryMap = {};
    categoriesSnap.forEach(doc => {
      const data = doc.data();
      categoryMap[data.name] = data.sync_id; // map category name to firestore document id
    });

    const defaultRules = [];
    const addRule = (keyword, categoryName) => {
      const catId = categoryMap[categoryName];
      if (catId) {
        defaultRules.push({
          keyword,
          category_id: catId, // standard ID format
          weight: 1
        });
      }
    };

    // Food & Dining
    addRule('zomato', 'Food & Dining');
    addRule('swiggy', 'Food & Dining');
    addRule('restaurant', 'Food & Dining');
    addRule('cafe', 'Food & Dining');
    addRule('food', 'Food & Dining');
    addRule('lunch', 'Food & Dining');
    addRule('dinner', 'Food & Dining');
    addRule('breakfast', 'Food & Dining');

    // Transport
    addRule('uber', 'Transport');
    addRule('ola', 'Transport');
    addRule('rapido', 'Transport');
    addRule('petrol', 'Transport');
    addRule('fuel', 'Transport');
    addRule('metro', 'Transport');

    // Shopping
    addRule('amazon', 'Shopping');
    addRule('flipkart', 'Shopping');
    addRule('myntra', 'Shopping');

    // Entertainment
    addRule('netflix', 'Entertainment');
    addRule('prime', 'Entertainment');
    addRule('hotstar', 'Entertainment');
    addRule('movie', 'Entertainment');
    addRule('spotify', 'Entertainment');

    // Bills
    addRule('electricity', 'Bills & Utilities');
    addRule('water', 'Bills & Utilities');
    addRule('internet', 'Bills & Utilities');
    addRule('mobile', 'Bills & Utilities');
    addRule('rent', 'Bills & Utilities');

    // Groceries
    addRule('bigbasket', 'Groceries');
    addRule('blinkit', 'Groceries');
    addRule('zepto', 'Groceries');
    addRule('instamart', 'Groceries');
    addRule('grocery', 'Groceries');

    const rulesPromises = defaultRules.map(rule => {
      const syncId = generateUUID();
      const payload = {
        ...rule,
        sync_id: syncId,
        user_id: userId,
        updated_at: new Date().toISOString()
      };
      return setDoc(doc(db, 'users', userId, 'categorization_rules', syncId), payload);
    });

    await Promise.all(rulesPromises);
  },

  // GUEST MODE LOCAL SEEDING (Matches Local Database initialization)
  seedGuestState() {
    const syncId = generateUUID();
    StateManager.state.userSettings = {
      sync_id: syncId,
      monthlyIncome: 0,
      currency: 'INR',
      isOnboarded: false,
      showIncomeChart: false,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    const defaultExpenseCategories = [
      { name: 'Food & Dining', icon: 'restaurant', type: 'expense', is_default: true },
      { name: 'Transport', icon: 'directions_car', type: 'expense', is_default: true },
      { name: 'Shopping', icon: 'shopping_bag', type: 'expense', is_default: true },
      { name: 'Entertainment', icon: 'local_movies', type: 'expense', is_default: true },
      { name: 'Bills & Utilities', icon: 'receipt_long', type: 'expense', is_default: true },
      { name: 'Health', icon: 'local_hospital', type: 'expense', is_default: true },
      { name: 'Education', icon: 'school', type: 'expense', is_default: true },
      { name: 'Self Care', icon: 'spa', type: 'expense', is_default: true },
      { name: 'Groceries', icon: 'local_grocery_store', type: 'expense', is_default: true },
      { name: 'Gifts', icon: 'card_giftcard', type: 'expense', is_default: true },
      { name: 'Savings', icon: 'savings', type: 'expense', is_default: true },
      { name: 'Investments', icon: 'show_chart', type: 'expense', is_default: true },
      { name: 'Family', icon: 'family_restroom', type: 'expense', is_default: true },
      { name: 'Other', icon: 'more_horiz', type: 'expense', is_default: true }
    ];

    const defaultIncomeCategories = [
      { name: 'Salary', icon: 'work', type: 'income', is_default: true },
      { name: 'Freelance', icon: 'laptop', type: 'income', is_default: true },
      { name: 'Investment', icon: 'trending_up', type: 'income', is_default: true },
      { name: 'Other Income', icon: 'attach_money', type: 'income', is_default: true }
    ];

    StateManager.state.categories = [...defaultExpenseCategories, ...defaultIncomeCategories].map((cat, index) => ({
      ...cat,
      id: index + 1, // numeric ID to match local database references
      sync_id: generateUUID(),
      monthly_budget: 0,
      updated_at: new Date().toISOString()
    }));

    // Local rules
    StateManager.state.categorizationRules = [];
    const addLocalRule = (keyword, catName) => {
      const cat = StateManager.state.categories.find(c => c.name === catName);
      if (cat) {
        StateManager.state.categorizationRules.push({
          id: StateManager.state.categorizationRules.length + 1,
          sync_id: generateUUID(),
          keyword,
          category_id: cat.id,
          weight: 1,
          updated_at: new Date().toISOString()
        });
      }
    };

    addLocalRule('zomato', 'Food & Dining');
    addLocalRule('swiggy', 'Food & Dining');
    addLocalRule('restaurant', 'Food & Dining');
    addLocalRule('uber', 'Transport');
    addLocalRule('ola', 'Transport');
    addLocalRule('petrol', 'Transport');
    addLocalRule('amazon', 'Shopping');
    addLocalRule('netflix', 'Entertainment');
    addLocalRule('spotify', 'Entertainment');
    addLocalRule('electricity', 'Bills & Utilities');
    addLocalRule('rent', 'Bills & Utilities');

    StateManager.saveGuestState();
    StateManager.notify();
  },

  // ---------------------------------------------------------------------------
  // CRUD ACTIONS (Polymorphic: handles Firebase or LocalStorage depending on mode)
  // ---------------------------------------------------------------------------

  async saveUserSettings(updates) {
    const isGuest = StateManager.state.isGuestMode;
    const settings = { ...StateManager.state.userSettings, ...updates, updatedAt: new Date().toISOString() };
    
    if (isGuest) {
      StateManager.state.userSettings = settings;
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user.uid;
      const syncId = settings.sync_id;
      const docRef = doc(db, 'users', userId, 'user_settings', syncId);
      await setDoc(docRef, settings, { merge: true });
    }
  },

  async addTransaction(tx) {
    const isGuest = StateManager.state.isGuestMode;
    const syncId = generateUUID();
    const newTx = {
      ...tx,
      sync_id: syncId,
      is_synced: !isGuest,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    if (isGuest) {
      newTx.id = StateManager.state.transactions.length + 1;
      StateManager.state.transactions.push(newTx);
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user.uid;
      newTx.user_id = userId;
      const docRef = doc(db, 'users', userId, 'transactions', syncId);
      await setDoc(docRef, newTx);
    }
  },

  async deleteTransaction(syncId, localId) {
    const isGuest = StateManager.state.isGuestMode;
    if (isGuest) {
      StateManager.state.transactions = StateManager.state.transactions.filter(t => t.id !== localId);
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user.uid;
      await deleteDoc(doc(db, 'users', userId, 'transactions', syncId));
    }
  },

  async updateCategoryBudget(syncId, localId, monthlyBudget) {
    const isGuest = StateManager.state.isGuestMode;
    if (isGuest) {
      const cat = StateManager.state.categories.find(c => c.id === localId);
      if (cat) {
        cat.monthly_budget = monthlyBudget;
        cat.updated_at = new Date().toISOString();
      }
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user.uid;
      const docRef = doc(db, 'users', userId, 'categories', syncId);
      await updateDoc(docRef, { monthly_budget: monthlyBudget, updated_at: new Date().toISOString() });
    }
  },

  async addAsset(asset) {
    const isGuest = StateManager.state.isGuestMode;
    const syncId = generateUUID();
    const newAsset = {
      ...asset,
      sync_id: syncId,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    if (isGuest) {
      newAsset.id = StateManager.state.assets.length + 1;
      StateManager.state.assets.push(newAsset);
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user.uid;
      newAsset.user_id = userId;
      await setDoc(doc(db, 'users', userId, 'assets', syncId), newAsset);
    }
  },

  async deleteAsset(syncId, localId) {
    const isGuest = StateManager.state.isGuestMode;
    if (isGuest) {
      StateManager.state.assets = StateManager.state.assets.filter(a => a.id !== localId);
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user.uid;
      await deleteDoc(doc(db, 'users', userId, 'assets', syncId));
    }
  },

  async addGoal(goal) {
    const isGuest = StateManager.state.isGuestMode;
    const syncId = generateUUID();
    const newGoal = {
      ...goal,
      sync_id: syncId,
      saved_amount: 0,
      is_active: true,
      is_completed: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    if (isGuest) {
      newGoal.id = StateManager.state.goals.length + 1;
      StateManager.state.goals.push(newGoal);
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user.uid;
      newGoal.user_id = userId;
      await setDoc(doc(db, 'users', userId, 'goals', syncId), newGoal);
    }
  },

  async deleteGoal(syncId, localId) {
    const isGuest = StateManager.state.isGuestMode;
    if (isGuest) {
      StateManager.state.goals = StateManager.state.goals.filter(g => g.id !== localId);
      StateManager.state.goalContributions = StateManager.state.goalContributions.filter(c => c.goal_id !== localId);
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user.uid;
      // Delete goal
      await deleteDoc(doc(db, 'users', userId, 'goals', syncId));
      // Delete goal contributions (typically handled in transactions/functions, or manually in client)
      const contributionsRef = collection(db, 'users', userId, 'goal_contributions');
      const q = query(contributionsRef, where('goal_id', '==', localId));
      const querySnapshot = await getDocs(q);
      const deletePromises = [];
      querySnapshot.forEach(doc => {
        deletePromises.push(deleteDoc(doc.ref));
      });
      await Promise.all(deletePromises);
    }
  },

  async addGoalContribution(goalSyncId, goalLocalId, amount, note) {
    const isGuest = StateManager.state.isGuestMode;
    const syncId = generateUUID();
    
    // Add contribution
    const newContribution = {
      sync_id: syncId,
      goal_id: goalLocalId,
      amount: amount,
      note: note || '',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    if (isGuest) {
      newContribution.id = StateManager.state.goalContributions.length + 1;
      StateManager.state.goalContributions.push(newContribution);
      
      // Update Goal locally
      const goal = StateManager.state.goals.find(g => g.id === goalLocalId);
      if (goal) {
        goal.saved_amount += amount;
        goal.is_completed = goal.saved_amount >= goal.target_amount;
        goal.updated_at = new Date().toISOString();
      }
      
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user.uid;
      newContribution.user_id = userId;
      
      // Insert contribution document
      await setDoc(doc(db, 'users', userId, 'goal_contributions', syncId), newContribution);
      
      // Fetch latest Goal and update
      const goalDocRef = doc(db, 'users', userId, 'goals', goalSyncId);
      // Retrieve the current saved_amount to increment
      const goalSnap = StateManager.state.goals.find(g => g.sync_id === goalSyncId);
      if (goalSnap) {
        const newSaved = goalSnap.saved_amount + amount;
        await updateDoc(goalDocRef, {
          saved_amount: newSaved,
          is_completed: newSaved >= goalSnap.target_amount,
          updated_at: new Date().toISOString()
        });
      }
    }
  },

  async deleteGoalContribution(contributionSyncId, contributionLocalId, goalSyncId, goalLocalId) {
    const isGuest = StateManager.state.isGuestMode;
    
    if (isGuest) {
      const contribution = StateManager.state.goalContributions.find(c => c.id === contributionLocalId);
      if (contribution) {
        // Decrement goal savings amount
        const goal = StateManager.state.goals.find(g => g.id === goalLocalId);
        if (goal) {
          goal.saved_amount = Math.max(0, goal.saved_amount - contribution.amount);
          goal.is_completed = goal.saved_amount >= goal.target_amount;
        }
        StateManager.state.goalContributions = StateManager.state.goalContributions.filter(c => c.id !== contributionLocalId);
      }
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user.uid;
      const contributionObj = StateManager.state.goalContributions.find(c => c.sync_id === contributionSyncId);
      if (contributionObj) {
        // Delete document
        await deleteDoc(doc(db, 'users', userId, 'goal_contributions', contributionSyncId));
        
        // Update goal saved amount
        const goalObj = StateManager.state.goals.find(g => g.sync_id === goalSyncId);
        if (goalObj) {
          const newSaved = Math.max(0, goalObj.saved_amount - contributionObj.amount);
          await updateDoc(doc(db, 'users', userId, 'goals', goalSyncId), {
            saved_amount: newSaved,
            is_completed: newSaved >= goalObj.target_amount,
            updated_at: new Date().toISOString()
          });
        }
      }
    }
  },

  async archiveGoal(syncId, localId) {
    const isGuest = StateManager.state.isGuestMode;
    if (isGuest) {
      const goal = StateManager.state.goals.find(g => g.id === localId);
      if (goal) {
        goal.is_active = false;
        goal.updated_at = new Date().toISOString();
      }
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user.uid;
      await updateDoc(doc(db, 'users', userId, 'goals', syncId), {
        is_active: false,
        updated_at: new Date().toISOString()
      });
    }
  },

  async addRule(keyword, categoryId) {
    const isGuest = StateManager.state.isGuestMode;
    const syncId = generateUUID();
    const newRule = {
      keyword,
      category_id: categoryId,
      weight: 1,
      sync_id: syncId,
      updated_at: new Date().toISOString()
    };

    if (isGuest) {
      newRule.id = StateManager.state.categorizationRules.length + 1;
      StateManager.state.categorizationRules.push(newRule);
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user.uid;
      newRule.user_id = userId;
      await setDoc(doc(db, 'users', userId, 'categorization_rules', syncId), newRule);
    }
  },

  async updateRuleWeight(syncId, localId, newWeight) {
    const isGuest = StateManager.state.isGuestMode;
    if (isGuest) {
      const rule = StateManager.state.categorizationRules.find(r => r.id === localId);
      if (rule) {
        rule.weight = newWeight;
        rule.updated_at = new Date().toISOString();
      }
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user.uid;
      await updateDoc(doc(db, 'users', userId, 'categorization_rules', syncId), {
        weight: newWeight,
        updated_at: new Date().toISOString()
      });
    }
  },

  // ---------------------------------------------------------------------------
  // SYNC GUEST DATA TO FIRESTORE ON LOG IN
  // ---------------------------------------------------------------------------
  async syncGuestDataToCloud(userId) {
    const localSettings = JSON.parse(localStorage.getItem('money_manager_user_settings'));
    if (!localSettings) return; // No guest data to sync

    const localTransactions = JSON.parse(localStorage.getItem('money_manager_transactions')) || [];
    const localCategories = JSON.parse(localStorage.getItem('money_manager_categories')) || [];
    const localGoals = JSON.parse(localStorage.getItem('money_manager_goals')) || [];
    const localContributions = JSON.parse(localStorage.getItem('money_manager_goal_contributions')) || [];
    const localRules = JSON.parse(localStorage.getItem('money_manager_categorization_rules')) || [];
    const localAssets = JSON.parse(localStorage.getItem('money_manager_assets')) || [];

    const userDocRef = doc(db, 'users', userId);

    // 1. Settings
    if (localSettings.isOnboarded) {
      const syncId = localSettings.sync_id || generateUUID();
      await setDoc(doc(userDocRef, 'user_settings', syncId), {
        ...localSettings,
        sync_id: syncId,
        user_id: userId,
        updated_at: new Date().toISOString()
      }, { merge: true });
    }

    // 2. Categories
    const catPromises = localCategories.map(cat => {
      const syncId = cat.sync_id || generateUUID();
      return setDoc(doc(userDocRef, 'categories', syncId), {
        ...cat,
        sync_id: syncId,
        user_id: userId,
        updated_at: new Date().toISOString()
      }, { merge: true });
    });
    await Promise.all(catPromises);

    // 3. Transactions
    const txPromises = localTransactions.map(tx => {
      const syncId = tx.sync_id || generateUUID();
      return setDoc(doc(userDocRef, 'transactions', syncId), {
        ...tx,
        sync_id: syncId,
        user_id: userId,
        is_synced: true,
        updated_at: new Date().toISOString()
      }, { merge: true });
    });
    await Promise.all(txPromises);

    // 4. Goals
    const goalPromises = localGoals.map(g => {
      const syncId = g.sync_id || generateUUID();
      return setDoc(doc(userDocRef, 'goals', syncId), {
        ...g,
        sync_id: syncId,
        user_id: userId,
        updated_at: new Date().toISOString()
      }, { merge: true });
    });
    await Promise.all(goalPromises);

    // 5. Goal Contributions
    const contribPromises = localContributions.map(c => {
      const syncId = c.sync_id || generateUUID();
      return setDoc(doc(userDocRef, 'goal_contributions', syncId), {
        ...c,
        sync_id: syncId,
        user_id: userId,
        updated_at: new Date().toISOString()
      }, { merge: true });
    });
    await Promise.all(contribPromises);

    // 6. Rules
    const rulePromises = localRules.map(r => {
      const syncId = r.sync_id || generateUUID();
      return setDoc(doc(userDocRef, 'categorization_rules', syncId), {
        ...r,
        sync_id: syncId,
        user_id: userId,
        updated_at: new Date().toISOString()
      }, { merge: true });
    });
    await Promise.all(rulePromises);

    // 7. Assets
    const assetPromises = localAssets.map(a => {
      const syncId = a.sync_id || generateUUID();
      return setDoc(doc(userDocRef, 'assets', syncId), {
        ...a,
        sync_id: syncId,
        user_id: userId,
        updated_at: new Date().toISOString()
      }, { merge: true });
    });
    await Promise.all(assetPromises);

    // Clear local guest storage after success
    this.clearGuestDataAndDisable();
  },

  clearGuestDataAndDisable() {
    StateManager.clearGuestData();
  }
};
