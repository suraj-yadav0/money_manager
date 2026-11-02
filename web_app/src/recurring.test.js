import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { DbService } from './db.js';
import { StateManager } from './state.js';
import { AllTransactionsPage } from './pages/all-transactions.js';
import { DashboardPage } from './pages/dashboard.js';

describe('Web Recurring Liabilities Auto-Addition Engine', () => {
  beforeEach(() => {
    // Reset state to isolated guest mode
    StateManager.state = {
      isGuestMode: true,
      user: null,
      transactions: [],
      categories: [
        { id: 1, name: 'Bills & Utilities', icon: 'receipt', type: 'expense' },
        { id: 2, name: 'Entertainment', icon: 'movie', type: 'expense' },
        { id: 3, name: 'Salary', icon: 'payments', type: 'income' }
      ],
      bankAccounts: [
        { id: 'acc-1', sync_id: 'acc-1', name: 'Savings Account', account_type: 'savings', balance: 50000 },
        { id: 'acc-2', sync_id: 'acc-2', name: 'Credit Card', account_type: 'credit_card', balance: 2000 }
      ],
      goals: [],
      assets: []
    };
    DbService._isProcessingRecurring = false;
  });

  it('skips recurring liability when scheduled day has not arrived yet', async () => {
    // Template created in previous month (October 2026) due on 15th
    StateManager.state.transactions = [
      {
        id: 'tx-template-1',
        sync_id: 'tx-template-1',
        amount: 2500,
        type: 'expense',
        categoryId: 1,
        timestamp: '2026-10-15T10:00:00.000Z',
        note: 'Fiber Internet Bill',
        is_recurring: true,
        isRecurring: true
      }
    ];

    // Today is Nov 10, 2026 (day 10 < day 15)
    await DbService.processRecurringTransactions(new Date(2026, 10, 10));

    const novTxs = StateManager.state.transactions.filter(t => {
      const d = new Date(t.timestamp);
      return d.getFullYear() === 2026 && d.getMonth() === 10;
    });

    assert.equal(novTxs.length, 0);
  });

  it('automatically adds recurring liability on or after the scheduled date', async () => {
    // Template from Oct 15
    StateManager.state.transactions = [
      {
        id: 'tx-template-1',
        sync_id: 'tx-template-1',
        amount: 2500,
        type: 'expense',
        categoryId: 1,
        timestamp: '2026-10-15T10:00:00.000Z',
        note: 'Fiber Internet Bill',
        is_recurring: true,
        isRecurring: true
      }
    ];

    // Today is Nov 16, 2026 (day 16 >= day 15)
    await DbService.processRecurringTransactions(new Date(2026, 10, 16));

    const novTxs = StateManager.state.transactions.filter(t => {
      const d = new Date(t.timestamp);
      return d.getFullYear() === 2026 && d.getMonth() === 10;
    });

    assert.equal(novTxs.length, 1);
    const instance = novTxs[0];
    assert.equal(instance.amount, 2500);
    assert.equal(instance.note, 'Fiber Internet Bill');
    assert.equal(instance.categoryId, 1);
    assert.equal(Boolean(instance.isRecurring || instance.is_recurring), false);
    assert.equal(instance.is_recurring_instance, true);
    assert.equal(instance.recurring_parent_id, 'tx-template-1');

    const instanceDate = new Date(instance.timestamp);
    assert.equal(instanceDate.getDate(), 15); // Scheduled day
  });

  it('does not duplicate recurring liability on multiple runs in the same month', async () => {
    StateManager.state.transactions = [
      {
        id: 'tx-template-netflix',
        sync_id: 'tx-template-netflix',
        amount: 649,
        type: 'expense',
        categoryId: 2,
        timestamp: '2026-10-05T08:00:00.000Z',
        note: 'Netflix Subscription',
        is_recurring: true,
        isRecurring: true
      }
    ];

    // Run on Nov 5th, then Nov 6th, then Nov 7th
    await DbService.processRecurringTransactions(new Date(2026, 10, 5));
    await DbService.processRecurringTransactions(new Date(2026, 10, 6));
    await DbService.processRecurringTransactions(new Date(2026, 10, 7));

    const netflixTxs = StateManager.state.transactions.filter(t => {
      const d = new Date(t.timestamp);
      return d.getFullYear() === 2026 && d.getMonth() === 10 && (t.note || '').includes('Netflix');
    });

    assert.equal(netflixTxs.length, 1);
  });

  it('unrelated expense in same category does not block generation', async () => {
    StateManager.state.transactions = [
      // Recurring utility bill template
      {
        id: 'tx-template-elec',
        sync_id: 'tx-template-elec',
        amount: 4500,
        type: 'expense',
        categoryId: 1,
        timestamp: '2026-09-12T10:00:00.000Z',
        note: 'Electricity Bill',
        is_recurring: true,
        isRecurring: true
      },
      // Unrelated ad-hoc expense in Bills category earlier in Nov
      {
        id: 'tx-nov-adhoc',
        sync_id: 'tx-nov-adhoc',
        amount: 800,
        type: 'expense',
        categoryId: 1,
        timestamp: '2026-11-03T12:00:00.000Z',
        note: 'Water Tanker',
        is_recurring: false,
        isRecurring: false
      }
    ];

    // Today is Nov 12th
    await DbService.processRecurringTransactions(new Date(2026, 10, 12));

    const novTxs = StateManager.state.transactions.filter(t => {
      const d = new Date(t.timestamp);
      return d.getFullYear() === 2026 && d.getMonth() === 10 && (t.categoryId === 1 || t.category_id === 1);
    });

    assert.equal(novTxs.length, 2);
    assert.ok(novTxs.some(t => t.note === 'Water Tanker'));
    assert.ok(novTxs.some(t => t.note === 'Electricity Bill' && new Date(t.timestamp).getDate() === 12));
  });

  it('updates linked bank account and credit card balances', async () => {
    StateManager.state.transactions = [
      // 1. Rent template linked to savings account
      {
        id: 'tx-rent',
        sync_id: 'tx-rent',
        amount: 15000,
        type: 'expense',
        categoryId: 1,
        account_id: 'acc-1',
        accountId: 'acc-1',
        timestamp: '2026-10-01T10:00:00.000Z',
        note: 'House Rent',
        is_recurring: true,
        isRecurring: true
      },
      // 2. Cloud hosting template linked to credit card
      {
        id: 'tx-cloud',
        sync_id: 'tx-cloud',
        amount: 1200,
        type: 'expense',
        categoryId: 2,
        account_id: 'acc-2',
        accountId: 'acc-2',
        timestamp: '2026-10-01T10:00:00.000Z',
        note: 'Cloud Hosting',
        is_recurring: true,
        isRecurring: true
      }
    ];

    // Process on Nov 1
    await DbService.processRecurringTransactions(new Date(2026, 10, 1));

    const savings = StateManager.state.bankAccounts.find(a => a.id === 'acc-1');
    const card = StateManager.state.bankAccounts.find(a => a.id === 'acc-2');

    // Savings: 50000 - 15000 = 35000
    assert.equal(savings.balance, 35000);
    // Credit card debt: 2000 + 1200 = 3200
    assert.equal(card.balance, 3200);
  });

  it('does not auto-credit recurring income or salary', async () => {
    StateManager.state.transactions = [
      {
        id: 'tx-salary',
        sync_id: 'tx-salary',
        amount: 75000,
        type: 'income',
        categoryId: 3,
        timestamp: '2026-10-01T10:00:00.000Z',
        note: 'Monthly Salary',
        is_recurring: true,
        isRecurring: true
      }
    ];

    await DbService.processRecurringTransactions(new Date(2026, 10, 1));

    const novIncome = StateManager.state.transactions.filter(t => {
      const d = new Date(t.timestamp);
      return d.getFullYear() === 2026 && d.getMonth() === 10 && t.type === 'income';
    });

    assert.equal(novIncome.length, 0);
    // Verified template was unmarked
    const salaryTemplate = StateManager.state.transactions.find(t => t.id === 'tx-salary');
    assert.equal(Boolean(salaryTemplate.isRecurring || salaryTemplate.is_recurring), false);
  });

  it('ledger recurring filter includes templates and auto-generated instances', async () => {
    StateManager.state.transactions = [
      {
        id: 'tx-template-gym',
        sync_id: 'tx-template-gym',
        amount: 1500,
        type: 'expense',
        categoryId: 1,
        timestamp: '2026-10-01T10:00:00.000Z',
        note: 'Gym Membership',
        is_recurring: true,
        isRecurring: true
      },
      {
        id: 'tx-adhoc-groceries',
        sync_id: 'tx-adhoc-groceries',
        amount: 850,
        type: 'expense',
        categoryId: 1,
        timestamp: '2026-11-01T10:00:00.000Z',
        note: 'Supermarket Groceries',
        is_recurring: false,
        isRecurring: false
      }
    ];

    // Process on Nov 1
    await DbService.processRecurringTransactions(new Date(2026, 10, 1));

    AllTransactionsPage.activeTypeFilter = 'recurring';
    const filtered = AllTransactionsPage.getFilteredTransactions(StateManager.state);

    // Both template and auto-generated November instance match the recurring filter
    assert.ok(filtered.length >= 2);
    assert.ok(filtered.every(t => (t.note || '').includes('Gym')));
    assert.ok(!filtered.some(t => (t.note || '').includes('Supermarket')));
  });

  it('handles string and number category id coercion in deduplication', async () => {
    StateManager.state.transactions = [
      {
        id: 'tx-template-str',
        sync_id: 'tx-template-str',
        amount: 500,
        type: 'expense',
        categoryId: '2', // String category ID
        timestamp: '2026-10-04T10:00:00.000Z',
        note: 'Music Streaming',
        is_recurring: true,
        isRecurring: true
      },
      {
        id: 'tx-existing-num',
        sync_id: 'tx-existing-num',
        amount: 500,
        type: 'expense',
        categoryId: 2, // Number category ID
        timestamp: '2026-11-04T10:00:00.000Z',
        note: 'Music Streaming',
        is_recurring: false,
        isRecurring: false
      }
    ];

    await DbService.processRecurringTransactions(new Date(2026, 10, 5));

    const novTxs = StateManager.state.transactions.filter(t => {
      const d = new Date(t.timestamp);
      return d.getFullYear() === 2026 && d.getMonth() === 10 && (t.note || '').includes('Music');
    });

    // Should not create duplicate because string '2' matches number 2
    assert.equal(novTxs.length, 1);
  });

  it('dashboard recurring liabilities list shows all commitments with live status', async () => {
    StateManager.state.transactions = [
      {
        id: 'tx-fiber',
        amount: 2500,
        type: 'expense',
        categoryId: 1,
        timestamp: '2026-10-04T10:00:00.000Z',
        note: 'Fiber Internet',
        is_recurring: true,
        isRecurring: true
      },
      {
        id: 'tx-cloud',
        amount: 1200,
        type: 'expense',
        categoryId: 2,
        timestamp: '2026-10-18T10:00:00.000Z',
        note: 'Cloud Hosting',
        is_recurring: true,
        isRecurring: true
      },
      // Fiber has already been paid for November
      {
        id: 'tx-fiber-nov',
        amount: 2500,
        type: 'expense',
        categoryId: 1,
        timestamp: '2026-11-04T10:00:00.000Z',
        note: 'Fiber Internet',
        is_recurring: false,
        isRecurring: false
      }
    ];

    const commitments = DashboardPage.getRecurringCommitments(StateManager.state);
    assert.equal(commitments.length, 2);

    const fiberCommitment = commitments.find(c => c.name === 'Fiber Internet');
    assert.equal(fiberCommitment.status, 'processed');

    const cloudCommitment = commitments.find(c => c.name === 'Cloud Hosting');
    assert.equal(cloudCommitment.status, 'upcoming');
  });
});
