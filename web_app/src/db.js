/* Database services: handles Firestore CRUD, real-time sync, and LocalStorage fallbacks */
import { 
  collection, 
  doc, 
  setDoc, 
  updateDoc, 
  deleteDoc, 
  onSnapshot, 
  getDocs,
  query, 
  where 
} from 'firebase/firestore';
import { db } from './firebase-config.js';
import { StateManager } from './state.js';
import { DEFAULT_CATEGORIES } from './utils/icons.js';

// Helper to generate UUIDs locally (for new documents/IDs)
function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// Active subscription cleanups
let activeListeners = [];

// Robust timestamp parser supporting Firestore Timestamp, ISO strings, and epoch millis
function parseTimestamp(val) {
  if (!val) return new Date().toISOString();
  if (typeof val.toDate === 'function') {
    try {
      return val.toDate().toISOString();
    } catch (_) {}
  }
  if (typeof val === 'object' && val.seconds !== undefined) {
    return new Date(val.seconds * 1000).toISOString();
  }
  if (typeof val === 'number') {
    return new Date(val).toISOString();
  }
  if (typeof val === 'string') {
    const d = new Date(val);
    if (!isNaN(d.getTime())) return d.toISOString();
  }
  return new Date().toISOString();
}

// Normalization Helpers
function normalizeCategory(raw, docId) {
  const syncId = raw.sync_id || docId;
  let id = raw.id;
  
  // If id is not set in Firestore, map against standard default categories
  if (id === undefined || id === null) {
    const defIndex = DEFAULT_CATEGORIES.findIndex(c => c.name.toLowerCase() === (raw.name || '').toLowerCase());
    if (defIndex !== -1) {
      id = defIndex + 1;
    }
  }

  return {
    ...raw,
    id: id !== undefined ? id : syncId,
    sync_id: syncId,
    name: raw.name || 'Category',
    icon: raw.icon || 'category',
    type: raw.type || 'expense',
    monthly_budget: Number(raw.monthly_budget || raw.monthlyBudget || 0),
    monthlyBudget: Number(raw.monthly_budget || raw.monthlyBudget || 0),
    is_default: raw.is_default !== undefined ? raw.is_default : Boolean(raw.isDefault),
    isDefault: raw.is_default !== undefined ? raw.is_default : Boolean(raw.isDefault),
    updated_at: parseTimestamp(raw.updated_at || raw.updatedAt)
  };
}

function normalizeTransaction(raw, docId) {
  const syncId = raw.sync_id || docId;
  const categoryId = raw.category_id !== undefined ? raw.category_id : raw.categoryId;
  const goalId = raw.goal_id !== undefined ? raw.goal_id : raw.goalId;
  const paymentMode = raw.payment_mode || raw.paymentMode || 'Cash';
  const isRecurring = raw.is_recurring !== undefined ? Boolean(raw.is_recurring) : Boolean(raw.isRecurring);

  return {
    ...raw,
    sync_id: syncId,
    amount: Number(raw.amount || 0),
    type: raw.type || 'expense',
    categoryId,
    category_id: categoryId,
    goalId,
    goal_id: goalId,
    timestamp: parseTimestamp(raw.timestamp),
    note: raw.note || '',
    paymentMode,
    payment_mode: paymentMode,
    receiptImagePath: raw.receipt_image_path || raw.receiptImagePath || null,
    receipt_image_path: raw.receipt_image_path || raw.receiptImagePath || null,
    isRecurring,
    is_recurring: isRecurring,
    is_synced: true,
    created_at: parseTimestamp(raw.created_at || raw.createdAt),
    updated_at: parseTimestamp(raw.updated_at || raw.updatedAt)
  };
}

function normalizeGoal(raw, docId) {
  const syncId = raw.sync_id || docId;
  const targetAmount = Number(raw.target_amount !== undefined ? raw.target_amount : (raw.targetAmount || 0));
  const savedAmount = Number(raw.saved_amount !== undefined ? raw.saved_amount : (raw.savedAmount || 0));
  const isActive = raw.is_active !== undefined ? Boolean(raw.is_active) : (raw.isActive !== false);
  const isCompleted = raw.is_completed !== undefined ? Boolean(raw.is_completed) : Boolean(raw.isCompleted || (savedAmount >= targetAmount && targetAmount > 0));

  return {
    ...raw,
    sync_id: syncId,
    name: raw.name || 'Savings Goal',
    targetAmount,
    target_amount: targetAmount,
    savedAmount,
    saved_amount: savedAmount,
    deadline: parseTimestamp(raw.deadline || new Date(Date.now() + 90 * 86400000).toISOString()),
    isActive,
    is_active: isActive,
    isCompleted,
    is_completed: isCompleted,
    created_at: parseTimestamp(raw.created_at || raw.createdAt),
    updated_at: parseTimestamp(raw.updated_at || raw.updatedAt)
  };
}

function normalizeContribution(raw, docId) {
  const syncId = raw.sync_id || docId;
  const goalId = raw.goal_id !== undefined ? raw.goal_id : raw.goalId;

  return {
    ...raw,
    sync_id: syncId,
    goalId,
    goal_id: goalId,
    amount: Number(raw.amount || 0),
    note: raw.note || '',
    created_at: parseTimestamp(raw.created_at || raw.createdAt),
    updated_at: parseTimestamp(raw.updated_at || raw.updatedAt)
  };
}

function normalizeRule(raw, docId) {
  const syncId = raw.sync_id || docId;
  const categoryId = raw.category_id !== undefined ? raw.category_id : raw.categoryId;

  return {
    ...raw,
    sync_id: syncId,
    keyword: (raw.keyword || '').toLowerCase(),
    categoryId,
    category_id: categoryId,
    weight: Number(raw.weight || 1),
    updated_at: parseTimestamp(raw.updated_at || raw.updatedAt)
  };
}

function normalizeAsset(raw, docId) {
  const syncId = raw.sync_id || docId;
  const isLiability = raw.is_liability !== undefined ? Boolean(raw.is_liability) : Boolean(raw.isLiability);

  return {
    ...raw,
    sync_id: syncId,
    name: raw.name || 'Asset',
    type: raw.type || 'savings',
    value: Number(raw.value || 0),
    isLiability,
    is_liability: isLiability,
    note: raw.note || '',
    created_at: parseTimestamp(raw.created_at || raw.createdAt),
    updated_at: parseTimestamp(raw.updated_at || raw.updatedAt)
  };
}

function normalizeSettings(raw, docId) {
  const syncId = raw.sync_id || docId;
  const monthlyIncome = Number(raw.monthly_income !== undefined ? raw.monthly_income : (raw.monthlyIncome || 0));
  const isOnboarded = raw.is_onboarded !== undefined ? Boolean(raw.is_onboarded) : (raw.isOnboarded !== undefined ? Boolean(raw.isOnboarded) : true);

  return {
    ...raw,
    sync_id: syncId,
    monthlyIncome,
    monthly_income: monthlyIncome,
    currency: raw.currency || 'INR',
    isOnboarded,
    is_onboarded: isOnboarded,
    showIncomeChart: Boolean(raw.show_income_chart || raw.showIncomeChart),
    show_income_chart: Boolean(raw.show_income_chart || raw.showIncomeChart),
    created_at: parseTimestamp(raw.created_at || raw.createdAt),
    updated_at: parseTimestamp(raw.updated_at || raw.updatedAt)
  };
}

export const DbService = {
  // Start real-time sync listeners for all collections for a logged-in user
  startSync(userId) {
    if (!userId) return;
    this.stopSync();

    StateManager.setState({ syncStatus: 'syncing', syncError: null });

    // 1. Trigger immediate parallel getDocs to populate UI instantly
    this.syncNow(userId).catch(err => {
      console.warn('[Quantro Sync] Initial syncNow warning:', err.message);
    });

    // 2. Settings listener
    const unsubSettings = onSnapshot(collection(db, 'users', userId, 'user_settings'), (snapshot) => {
      if (!snapshot.empty) {
        const firstDoc = snapshot.docs[0];
        const normalized = normalizeSettings(firstDoc.data(), firstDoc.id);
        StateManager.setState({ 
          userSettings: normalized,
          syncStatus: 'synced',
          lastSyncedAt: new Date().toISOString()
        });
      } else {
        // First time cloud user -> seed cloud settings as onboarded
        this.seedUserSettings(userId);
      }
    }, (err) => {
      console.error('[Quantro Sync] Firestore user_settings error:', err);
      StateManager.setState({ syncStatus: 'error', syncError: err.message || err.code });
    });
    activeListeners.push(unsubSettings);

    // 3. Categories listener
    const unsubCategories = onSnapshot(collection(db, 'users', userId, 'categories'), (snapshot) => {
      if (!snapshot.empty) {
        const cats = snapshot.docs.map(d => normalizeCategory(d.data(), d.id));
        StateManager.setState({ 
          categories: cats,
          syncStatus: 'synced',
          lastSyncedAt: new Date().toISOString()
        });
      } else {
        // If categories are empty in cloud, seed standard categories
        this.seedDefaultCategories(userId);
      }
    }, (err) => {
      console.error('[Quantro Sync] Firestore categories error:', err);
      StateManager.setState({ syncStatus: 'error', syncError: err.message || err.code });
    });
    activeListeners.push(unsubCategories);

    // 4. Transactions listener
    const unsubTransactions = onSnapshot(collection(db, 'users', userId, 'transactions'), (snapshot) => {
      const txs = snapshot.docs.map(d => normalizeTransaction(d.data(), d.id));
      console.log(`[Quantro Sync] Received ${txs.length} transactions from cloud for user ${userId}`);
      StateManager.setState({ 
        transactions: txs,
        syncStatus: 'synced',
        lastSyncedAt: new Date().toISOString(),
        syncError: null
      });
    }, (err) => {
      console.error('[Quantro Sync] Firestore transactions error:', err);
      StateManager.setState({ syncStatus: 'error', syncError: err.message || err.code });
    });
    activeListeners.push(unsubTransactions);

    // 5. Goals listener
    const unsubGoals = onSnapshot(collection(db, 'users', userId, 'goals'), (snapshot) => {
      const goals = snapshot.docs.map(d => normalizeGoal(d.data(), d.id));
      StateManager.setState({ 
        goals: goals,
        syncStatus: 'synced',
        lastSyncedAt: new Date().toISOString()
      });
    }, (err) => {
      console.error('[Quantro Sync] Firestore goals error:', err);
    });
    activeListeners.push(unsubGoals);

    // 6. Goal Contributions listener
    const unsubContributions = onSnapshot(collection(db, 'users', userId, 'goal_contributions'), (snapshot) => {
      const contribs = snapshot.docs.map(d => normalizeContribution(d.data(), d.id));
      StateManager.setState({ 
        goalContributions: contribs,
        syncStatus: 'synced',
        lastSyncedAt: new Date().toISOString()
      });
    }, (err) => {
      console.error('[Quantro Sync] Firestore goal_contributions error:', err);
    });
    activeListeners.push(unsubContributions);

    // 7. Categorization Rules listener
    const unsubRules = onSnapshot(collection(db, 'users', userId, 'categorization_rules'), (snapshot) => {
      const rules = snapshot.docs.map(d => normalizeRule(d.data(), d.id));
      StateManager.setState({ 
        categorizationRules: rules,
        syncStatus: 'synced',
        lastSyncedAt: new Date().toISOString()
      });
    }, (err) => {
      console.error('[Quantro Sync] Firestore categorization_rules error:', err);
    });
    activeListeners.push(unsubRules);

    // 8. Assets listener
    const unsubAssets = onSnapshot(collection(db, 'users', userId, 'assets'), (snapshot) => {
      const assets = snapshot.docs.map(d => normalizeAsset(d.data(), d.id));
      StateManager.setState({ 
        assets: assets,
        syncStatus: 'synced',
        lastSyncedAt: new Date().toISOString()
      });
    }, (err) => {
      console.error('[Quantro Sync] Firestore assets error:', err);
    });
    activeListeners.push(unsubAssets);
  },

  // Stop all active real-time listeners (e.g. on sign out)
  stopSync() {
    for (const unsubscribe of activeListeners) {
      try {
        unsubscribe();
      } catch (e) {
        console.error('Error unsubscribing listener:', e);
      }
    }
    activeListeners = [];
    StateManager.setState({ syncStatus: 'idle' });
  },

  // Manual forced sync trigger with summary result
  async syncNow(userId) {
    if (!userId) {
      if (StateManager.state.user) {
        userId = StateManager.state.user.uid;
      } else {
        throw new Error('No user logged in to sync.');
      }
    }

    StateManager.setState({ syncStatus: 'syncing' });

    try {
      const [settingsSnap, catSnap, txSnap, goalsSnap, contribSnap, rulesSnap, assetsSnap] = await Promise.all([
        getDocs(collection(db, 'users', userId, 'user_settings')),
        getDocs(collection(db, 'users', userId, 'categories')),
        getDocs(collection(db, 'users', userId, 'transactions')),
        getDocs(collection(db, 'users', userId, 'goals')),
        getDocs(collection(db, 'users', userId, 'goal_contributions')),
        getDocs(collection(db, 'users', userId, 'categorization_rules')),
        getDocs(collection(db, 'users', userId, 'assets')),
      ]);

      const updates = {
        syncStatus: 'synced',
        lastSyncedAt: new Date().toISOString(),
        syncError: null
      };

      if (!settingsSnap.empty) {
        updates.userSettings = normalizeSettings(settingsSnap.docs[0].data(), settingsSnap.docs[0].id);
      }
      if (!catSnap.empty) {
        updates.categories = catSnap.docs.map(d => normalizeCategory(d.data(), d.id));
      }
      updates.transactions = txSnap.docs.map(d => normalizeTransaction(d.data(), d.id));
      updates.goals = goalsSnap.docs.map(d => normalizeGoal(d.data(), d.id));
      updates.goalContributions = contribSnap.docs.map(d => normalizeContribution(d.data(), d.id));
      updates.categorizationRules = rulesSnap.docs.map(d => normalizeRule(d.data(), d.id));
      updates.assets = assetsSnap.docs.map(d => normalizeAsset(d.data(), d.id));

      StateManager.setState(updates);

      console.log(`[Quantro Sync] syncNow completed: ${updates.transactions.length} txs, ${updates.goals.length} goals, ${(updates.categories || []).length} categories`);

      return {
        success: true,
        count: {
          transactions: updates.transactions.length,
          categories: (updates.categories || []).length,
          goals: updates.goals.length,
          assets: updates.assets.length
        },
        syncedAt: updates.lastSyncedAt
      };
    } catch (err) {
      console.error('[Quantro Sync] Manual syncNow error:', err);
      StateManager.setState({ syncStatus: 'error', syncError: err.message });
      throw err;
    }
  },

  // Seed default settings in Firestore for new user
  async seedUserSettings(userId, initialIncome = 0) {
    const syncId = generateUUID();
    const payload = {
      sync_id: syncId,
      user_id: userId,
      monthly_income: initialIncome,
      currency: 'INR',
      is_onboarded: true, // Logged in cloud user is considered onboarded
      show_income_chart: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    const settingsDoc = doc(db, 'users', userId, 'user_settings', syncId);
    await setDoc(settingsDoc, payload, { merge: true });
    
    // Also seed default categories and rules
    await this.seedDefaultCategories(userId);
  },

  // Seed default categories matching Drift database
  async seedDefaultCategories(userId) {
    // Check if categories already exist
    const existingSnap = await getDocs(collection(db, 'users', userId, 'categories'));
    if (!existingSnap.empty) return;

    const batchPromises = DEFAULT_CATEGORIES.map(cat => {
      const syncId = generateUUID();
      const payload = {
        sync_id: syncId,
        user_id: userId,
        name: cat.name,
        icon: cat.icon,
        type: cat.type,
        is_default: true,
        monthly_budget: 0,
        updated_at: new Date().toISOString()
      };
      return setDoc(doc(db, 'users', userId, 'categories', syncId), payload);
    });

    await Promise.all(batchPromises);
    await this.seedDefaultRules(userId);
  },

  async seedDefaultRules(userId) {
    const existingRules = await getDocs(collection(db, 'users', userId, 'categorization_rules'));
    if (!existingRules.empty) return;

    const categoriesSnap = await getDocs(collection(db, 'users', userId, 'categories'));
    const categoryMap = {};
    categoriesSnap.forEach(d => {
      const data = d.data();
      categoryMap[data.name] = data.sync_id || d.id;
    });

    const defaultKeywords = [
      { kw: 'zomato', cat: 'Food & Dining' },
      { kw: 'swiggy', cat: 'Food & Dining' },
      { kw: 'restaurant', cat: 'Food & Dining' },
      { kw: 'cafe', cat: 'Food & Dining' },
      { kw: 'food', cat: 'Food & Dining' },
      { kw: 'lunch', cat: 'Food & Dining' },
      { kw: 'dinner', cat: 'Food & Dining' },
      { kw: 'breakfast', cat: 'Food & Dining' },
      { kw: 'uber', cat: 'Transport' },
      { kw: 'ola', cat: 'Transport' },
      { kw: 'rapido', cat: 'Transport' },
      { kw: 'petrol', cat: 'Transport' },
      { kw: 'fuel', cat: 'Transport' },
      { kw: 'metro', cat: 'Transport' },
      { kw: 'amazon', cat: 'Shopping' },
      { kw: 'flipkart', cat: 'Shopping' },
      { kw: 'myntra', cat: 'Shopping' },
      { kw: 'netflix', cat: 'Entertainment' },
      { kw: 'prime', cat: 'Entertainment' },
      { kw: 'hotstar', cat: 'Entertainment' },
      { kw: 'movie', cat: 'Entertainment' },
      { kw: 'spotify', cat: 'Entertainment' },
      { kw: 'electricity', cat: 'Bills & Utilities' },
      { kw: 'water', cat: 'Bills & Utilities' },
      { kw: 'internet', cat: 'Bills & Utilities' },
      { kw: 'mobile', cat: 'Bills & Utilities' },
      { kw: 'rent', cat: 'Bills & Utilities' },
      { kw: 'bigbasket', cat: 'Groceries' },
      { kw: 'blinkit', cat: 'Groceries' },
      { kw: 'zepto', cat: 'Groceries' },
      { kw: 'instamart', cat: 'Groceries' },
      { kw: 'grocery', cat: 'Groceries' }
    ];

    const rulePromises = [];
    for (const item of defaultKeywords) {
      const catId = categoryMap[item.cat];
      if (catId) {
        const syncId = generateUUID();
        const payload = {
          sync_id: syncId,
          user_id: userId,
          keyword: item.kw,
          category_id: catId,
          weight: 1,
          updated_at: new Date().toISOString()
        };
        rulePromises.push(setDoc(doc(db, 'users', userId, 'categorization_rules', syncId), payload));
      }
    }

    await Promise.all(rulePromises);
  },

  // GUEST MODE LOCAL SEEDING
  seedGuestState() {
    const syncId = generateUUID();
    StateManager.state.userSettings = {
      sync_id: syncId,
      monthlyIncome: 0,
      monthly_income: 0,
      currency: 'INR',
      isOnboarded: false,
      is_onboarded: false,
      showIncomeChart: false,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    StateManager.state.categories = DEFAULT_CATEGORIES.map((cat) => ({
      ...cat,
      sync_id: generateUUID(),
      monthly_budget: 0,
      monthlyBudget: 0,
      updated_at: new Date().toISOString()
    }));

    StateManager.state.categorizationRules = [];
    const addLocalRule = (keyword, catName) => {
      const cat = StateManager.state.categories.find(c => c.name === catName);
      if (cat) {
        StateManager.state.categorizationRules.push({
          id: StateManager.state.categorizationRules.length + 1,
          sync_id: generateUUID(),
          keyword,
          category_id: cat.id,
          categoryId: cat.id,
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
    const isGuest = StateManager.state.isGuestMode && !StateManager.state.user;
    const current = StateManager.state.userSettings || {};
    const settings = { 
      ...current, 
      ...updates, 
      updatedAt: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    
    if (updates.monthlyIncome !== undefined) settings.monthly_income = updates.monthlyIncome;
    if (updates.isOnboarded !== undefined) settings.is_onboarded = updates.isOnboarded;
    if (updates.showIncomeChart !== undefined) settings.show_income_chart = updates.showIncomeChart;

    if (isGuest) {
      StateManager.state.userSettings = settings;
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user?.uid;
      if (!userId) return;
      const syncId = settings.sync_id || generateUUID();
      settings.sync_id = syncId;
      settings.user_id = userId;

      StateManager.setState({ userSettings: settings });
      const docRef = doc(db, 'users', userId, 'user_settings', syncId);
      await setDoc(docRef, settings, { merge: true });
    }
  },

  async addTransaction(tx) {
    const isGuest = StateManager.state.isGuestMode && !StateManager.state.user;
    const syncId = tx.sync_id || generateUUID();
    
    const catId = tx.categoryId !== undefined ? tx.categoryId : (tx.category_id !== undefined ? tx.category_id : 1);
    const goalId = tx.goalId !== undefined ? tx.goalId : (tx.goal_id !== undefined ? tx.goal_id : null);
    const paymentMode = tx.paymentMode || tx.payment_mode || 'Cash';
    const isRecurring = tx.isRecurring !== undefined ? Boolean(tx.isRecurring) : Boolean(tx.is_recurring);

    const newTx = {
      ...tx,
      sync_id: syncId,
      amount: Number(tx.amount || 0),
      type: tx.type || 'expense',
      categoryId: catId,
      category_id: catId,
      goalId: goalId,
      goal_id: goalId,
      paymentMode,
      payment_mode: paymentMode,
      isRecurring,
      is_recurring: isRecurring,
      timestamp: tx.timestamp || new Date().toISOString(),
      note: tx.note || '',
      is_synced: !isGuest,
      created_at: tx.created_at || new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    if (isGuest) {
      newTx.id = StateManager.state.transactions.length + 1;
      StateManager.state.transactions.unshift(newTx);
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user?.uid;
      if (!userId) return;
      newTx.user_id = userId;
      
      // Optimistic update in state
      const existingIdx = StateManager.state.transactions.findIndex(t => t.sync_id === syncId);
      if (existingIdx !== -1) {
        StateManager.state.transactions[existingIdx] = newTx;
      } else {
        StateManager.state.transactions.unshift(newTx);
      }
      StateManager.notify();

      const docRef = doc(db, 'users', userId, 'transactions', syncId);
      await setDoc(docRef, newTx, { merge: true });
    }
  },

  async deleteTransaction(syncId, localId) {
    const isGuest = StateManager.state.isGuestMode && !StateManager.state.user;
    if (isGuest) {
      StateManager.state.transactions = StateManager.state.transactions.filter(t => t.id !== localId && t.sync_id !== syncId);
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user?.uid;
      if (!userId) return;
      
      // Optimistic local removal
      StateManager.state.transactions = StateManager.state.transactions.filter(t => t.sync_id !== syncId);
      StateManager.notify();

      if (syncId) {
        await deleteDoc(doc(db, 'users', userId, 'transactions', syncId));
      }
    }
  },

  async updateCategoryBudget(syncId, localId, monthlyBudget) {
    const isGuest = StateManager.state.isGuestMode && !StateManager.state.user;
    if (isGuest) {
      const cat = StateManager.state.categories.find(c => c.id === localId || c.sync_id === syncId);
      if (cat) {
        cat.monthly_budget = monthlyBudget;
        cat.monthlyBudget = monthlyBudget;
        cat.updated_at = new Date().toISOString();
      }
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user?.uid;
      if (!userId) return;

      const cat = StateManager.state.categories.find(c => c.sync_id === syncId || c.id === localId);
      if (cat) {
        cat.monthly_budget = monthlyBudget;
        cat.monthlyBudget = monthlyBudget;
        cat.updated_at = new Date().toISOString();
        StateManager.notify();
      }

      if (syncId) {
        const docRef = doc(db, 'users', userId, 'categories', syncId);
        await updateDoc(docRef, { 
          monthly_budget: monthlyBudget, 
          updated_at: new Date().toISOString() 
        });
      }
    }
  },

  async addAsset(asset) {
    const isGuest = StateManager.state.isGuestMode && !StateManager.state.user;
    const syncId = asset.sync_id || generateUUID();
    const isLiability = asset.isLiability !== undefined ? Boolean(asset.isLiability) : Boolean(asset.is_liability);

    const newAsset = {
      ...asset,
      sync_id: syncId,
      value: Number(asset.value || 0),
      isLiability,
      is_liability: isLiability,
      created_at: asset.created_at || new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    if (isGuest) {
      newAsset.id = StateManager.state.assets.length + 1;
      StateManager.state.assets.push(newAsset);
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user?.uid;
      if (!userId) return;
      newAsset.user_id = userId;

      const existingIdx = StateManager.state.assets.findIndex(a => a.sync_id === syncId);
      if (existingIdx !== -1) {
        StateManager.state.assets[existingIdx] = newAsset;
      } else {
        StateManager.state.assets.push(newAsset);
      }
      StateManager.notify();

      await setDoc(doc(db, 'users', userId, 'assets', syncId), newAsset, { merge: true });
    }
  },

  async deleteAsset(syncId, localId) {
    const isGuest = StateManager.state.isGuestMode && !StateManager.state.user;
    if (isGuest) {
      StateManager.state.assets = StateManager.state.assets.filter(a => a.id !== localId && a.sync_id !== syncId);
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user?.uid;
      if (!userId) return;

      StateManager.state.assets = StateManager.state.assets.filter(a => a.sync_id !== syncId);
      StateManager.notify();

      if (syncId) {
        await deleteDoc(doc(db, 'users', userId, 'assets', syncId));
      }
    }
  },

  async addGoal(goal) {
    const isGuest = StateManager.state.isGuestMode && !StateManager.state.user;
    const syncId = goal.sync_id || generateUUID();
    const targetAmount = Number(goal.targetAmount !== undefined ? goal.targetAmount : (goal.target_amount || 0));
    const savedAmount = Number(goal.savedAmount !== undefined ? goal.savedAmount : (goal.saved_amount || 0));

    const newGoal = {
      ...goal,
      sync_id: syncId,
      targetAmount,
      target_amount: targetAmount,
      savedAmount,
      saved_amount: savedAmount,
      is_active: goal.is_active !== undefined ? goal.is_active : (goal.isActive !== false),
      isActive: goal.is_active !== undefined ? goal.is_active : (goal.isActive !== false),
      is_completed: savedAmount >= targetAmount && targetAmount > 0,
      isCompleted: savedAmount >= targetAmount && targetAmount > 0,
      created_at: goal.created_at || new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    if (isGuest) {
      newGoal.id = StateManager.state.goals.length + 1;
      StateManager.state.goals.push(newGoal);
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user?.uid;
      if (!userId) return;
      newGoal.user_id = userId;

      const existingIdx = StateManager.state.goals.findIndex(g => g.sync_id === syncId);
      if (existingIdx !== -1) {
        StateManager.state.goals[existingIdx] = newGoal;
      } else {
        StateManager.state.goals.push(newGoal);
      }
      StateManager.notify();

      await setDoc(doc(db, 'users', userId, 'goals', syncId), newGoal, { merge: true });
    }
  },

  async deleteGoal(syncId, localId) {
    const isGuest = StateManager.state.isGuestMode && !StateManager.state.user;
    if (isGuest) {
      StateManager.state.goals = StateManager.state.goals.filter(g => g.id !== localId && g.sync_id !== syncId);
      StateManager.state.goalContributions = StateManager.state.goalContributions.filter(c => c.goal_id !== localId && c.goal_id !== syncId);
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user?.uid;
      if (!userId) return;

      StateManager.state.goals = StateManager.state.goals.filter(g => g.sync_id !== syncId);
      StateManager.state.goalContributions = StateManager.state.goalContributions.filter(c => c.goal_id !== syncId && c.goalId !== syncId);
      StateManager.notify();

      if (syncId) {
        await deleteDoc(doc(db, 'users', userId, 'goals', syncId));
        
        // Delete linked contributions
        try {
          const contributionsRef = collection(db, 'users', userId, 'goal_contributions');
          const q = query(contributionsRef, where('goal_id', '==', syncId));
          const querySnapshot = await getDocs(q);
          const deletePromises = [];
          querySnapshot.forEach(d => deletePromises.push(deleteDoc(d.ref)));
          await Promise.all(deletePromises);
        } catch (e) {
          console.error('Error cleaning up linked contributions:', e);
        }
      }
    }
  },

  async addGoalContribution(goalSyncId, goalLocalId, amount, note) {
    const isGuest = StateManager.state.isGuestMode && !StateManager.state.user;
    const syncId = generateUUID();
    const parsedAmount = Number(amount || 0);

    const newContribution = {
      sync_id: syncId,
      goal_id: goalSyncId || goalLocalId,
      goalId: goalSyncId || goalLocalId,
      amount: parsedAmount,
      note: note || '',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    if (isGuest) {
      newContribution.id = StateManager.state.goalContributions.length + 1;
      StateManager.state.goalContributions.push(newContribution);
      
      const goal = StateManager.state.goals.find(g => g.id === goalLocalId || g.sync_id === goalSyncId);
      if (goal) {
        goal.saved_amount = (goal.saved_amount || 0) + parsedAmount;
        goal.savedAmount = goal.saved_amount;
        goal.is_completed = goal.saved_amount >= goal.target_amount;
        goal.isCompleted = goal.is_completed;
        goal.updated_at = new Date().toISOString();
      }
      
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user?.uid;
      if (!userId) return;
      newContribution.user_id = userId;

      StateManager.state.goalContributions.push(newContribution);
      const goal = StateManager.state.goals.find(g => g.sync_id === goalSyncId);
      if (goal) {
        const newSaved = (goal.saved_amount || 0) + parsedAmount;
        goal.saved_amount = newSaved;
        goal.savedAmount = newSaved;
        goal.is_completed = newSaved >= goal.target_amount;
        goal.isCompleted = goal.is_completed;
        goal.updated_at = new Date().toISOString();
      }
      StateManager.notify();

      await setDoc(doc(db, 'users', userId, 'goal_contributions', syncId), newContribution);
      
      if (goalSyncId && goal) {
        const goalDocRef = doc(db, 'users', userId, 'goals', goalSyncId);
        await updateDoc(goalDocRef, {
          saved_amount: goal.saved_amount,
          is_completed: goal.is_completed,
          updated_at: new Date().toISOString()
        });
      }
    }
  },

  async deleteGoalContribution(contributionSyncId, contributionLocalId, goalSyncId, goalLocalId) {
    const isGuest = StateManager.state.isGuestMode && !StateManager.state.user;
    
    if (isGuest) {
      const contribution = StateManager.state.goalContributions.find(c => c.id === contributionLocalId || c.sync_id === contributionSyncId);
      if (contribution) {
        const goal = StateManager.state.goals.find(g => g.id === goalLocalId || g.sync_id === goalSyncId);
        if (goal) {
          goal.saved_amount = Math.max(0, (goal.saved_amount || 0) - contribution.amount);
          goal.savedAmount = goal.saved_amount;
          goal.is_completed = goal.saved_amount >= goal.target_amount;
          goal.isCompleted = goal.is_completed;
        }
        StateManager.state.goalContributions = StateManager.state.goalContributions.filter(c => c.id !== contributionLocalId && c.sync_id !== contributionSyncId);
      }
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user?.uid;
      if (!userId) return;

      const contributionObj = StateManager.state.goalContributions.find(c => c.sync_id === contributionSyncId);
      if (contributionObj) {
        StateManager.state.goalContributions = StateManager.state.goalContributions.filter(c => c.sync_id !== contributionSyncId);
        
        const goalObj = StateManager.state.goals.find(g => g.sync_id === goalSyncId);
        if (goalObj) {
          const newSaved = Math.max(0, (goalObj.saved_amount || 0) - contributionObj.amount);
          goalObj.saved_amount = newSaved;
          goalObj.savedAmount = newSaved;
          goalObj.is_completed = newSaved >= goalObj.target_amount;
          goalObj.isCompleted = goalObj.is_completed;
        }
        StateManager.notify();

        await deleteDoc(doc(db, 'users', userId, 'goal_contributions', contributionSyncId));
        
        if (goalSyncId && goalObj) {
          await updateDoc(doc(db, 'users', userId, 'goals', goalSyncId), {
            saved_amount: goalObj.saved_amount,
            is_completed: goalObj.is_completed,
            updated_at: new Date().toISOString()
          });
        }
      }
    }
  },

  async archiveGoal(syncId, localId) {
    const isGuest = StateManager.state.isGuestMode && !StateManager.state.user;
    if (isGuest) {
      const goal = StateManager.state.goals.find(g => g.id === localId || g.sync_id === syncId);
      if (goal) {
        goal.is_active = false;
        goal.isActive = false;
        goal.updated_at = new Date().toISOString();
      }
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user?.uid;
      if (!userId) return;

      const goal = StateManager.state.goals.find(g => g.sync_id === syncId);
      if (goal) {
        goal.is_active = false;
        goal.isActive = false;
        StateManager.notify();
      }

      if (syncId) {
        await updateDoc(doc(db, 'users', userId, 'goals', syncId), {
          is_active: false,
          updated_at: new Date().toISOString()
        });
      }
    }
  },

  async addRule(keyword, categoryId) {
    const isGuest = StateManager.state.isGuestMode && !StateManager.state.user;
    const syncId = generateUUID();
    const newRule = {
      keyword: (keyword || '').toLowerCase(),
      category_id: categoryId,
      categoryId: categoryId,
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
      const userId = StateManager.state.user?.uid;
      if (!userId) return;
      newRule.user_id = userId;

      StateManager.state.categorizationRules.push(newRule);
      StateManager.notify();

      await setDoc(doc(db, 'users', userId, 'categorization_rules', syncId), newRule);
    }
  },

  async updateRuleWeight(syncId, localId, newWeight) {
    const isGuest = StateManager.state.isGuestMode && !StateManager.state.user;
    if (isGuest) {
      const rule = StateManager.state.categorizationRules.find(r => r.id === localId || r.sync_id === syncId);
      if (rule) {
        rule.weight = newWeight;
        rule.updated_at = new Date().toISOString();
      }
      StateManager.saveGuestState();
      StateManager.notify();
    } else {
      const userId = StateManager.state.user?.uid;
      if (!userId) return;

      const rule = StateManager.state.categorizationRules.find(r => r.sync_id === syncId);
      if (rule) {
        rule.weight = newWeight;
        StateManager.notify();
      }

      if (syncId) {
        await updateDoc(doc(db, 'users', userId, 'categorization_rules', syncId), {
          weight: newWeight,
          updated_at: new Date().toISOString()
        });
      }
    }
  },

  // ---------------------------------------------------------------------------
  // SYNC GUEST DATA TO FIRESTORE ON LOG IN (Non-destructive merge)
  // ---------------------------------------------------------------------------
  async syncGuestDataToCloud(userId) {
    if (!userId) return;

    try {
      const localTransactions = JSON.parse(localStorage.getItem('money_manager_transactions')) || [];
      const localGoals = JSON.parse(localStorage.getItem('money_manager_goals')) || [];
      const localAssets = JSON.parse(localStorage.getItem('money_manager_assets')) || [];
      const localSettings = JSON.parse(localStorage.getItem('money_manager_user_settings'));

      const userDocRef = doc(db, 'users', userId);

      // Only push non-empty custom records that aren't already synced
      if (localTransactions.length > 0) {
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
      }

      if (localGoals.length > 0) {
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
      }

      if (localAssets.length > 0) {
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
      }

      // If user had custom monthly income in guest settings, save it if cloud settings is empty
      if (localSettings && localSettings.monthlyIncome > 0) {
        const cloudSettingsSnap = await getDocs(collection(userDocRef, 'user_settings'));
        if (cloudSettingsSnap.empty) {
          await this.seedUserSettings(userId, localSettings.monthlyIncome);
        }
      }

      // Safely purge ONLY guest local storage keys without clearing in-memory state
      StateManager.clearGuestLocalStorage();
    } catch (err) {
      console.error('Error in syncGuestDataToCloud:', err);
    }
  }
};
