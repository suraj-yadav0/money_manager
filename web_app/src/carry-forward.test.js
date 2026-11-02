import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { BudgetPage } from './pages/budget.js';
import { DashboardPage } from './pages/dashboard.js';

describe('Web Budget Carry Forward Dynamics', () => {
  const categories = [
    { id: 1, sync_id: 'cat-food', name: 'Food & Dining', icon: 'restaurant', type: 'expense', monthly_budget: 5000 },
    { id: 2, sync_id: 'cat-ent', name: 'Entertainment', icon: 'movie', type: 'expense', monthly_budget: 2000 },
    { id: 3, sync_id: 'cat-shop', name: 'Shopping', icon: 'shopping_bag', type: 'expense', monthly_budget: 4000 }
  ];

  it('rolls over surplus unspent budget to the next month', () => {
    const state = {
      categories,
      userSettings: { carryForwardEnabled: true },
      transactions: [
        // Oct 2026: Spent 3500 of 5000 in Food (1500 leftover)
        { amount: 3500, type: 'expense', categoryId: 1, timestamp: '2026-10-15T12:00:00.000Z' }
      ]
    };

    BudgetPage.currentDate = new Date(2026, 10, 1); // November 2026
    const stats = BudgetPage.calculateBudgetStats(state);

    const food = stats.categoryStats.find(c => c.name === 'Food & Dining');
    assert.ok(food);
    assert.equal(food.baseBudget, 5000);
    assert.equal(food.rollover, 1500);
    assert.equal(food.budget, 6500); // 5000 + 1500
    assert.equal(food.spent, 0);
    assert.equal(food.budget - food.spent, 6500);
    assert.equal(stats.totalRollover, 1500);
  });

  it('rolls over deficit when a category is overspent', () => {
    const state = {
      categories,
      userSettings: { carryForwardEnabled: true },
      transactions: [
        // Oct 2026: Spent 2600 of 2000 in Entertainment (-600 deficit)
        { amount: 2600, type: 'expense', categoryId: 2, timestamp: '2026-10-20T12:00:00.000Z' }
      ]
    };

    BudgetPage.currentDate = new Date(2026, 10, 1); // November 2026
    const stats = BudgetPage.calculateBudgetStats(state);

    const ent = stats.categoryStats.find(c => c.name === 'Entertainment');
    assert.ok(ent);
    assert.equal(ent.baseBudget, 2000);
    assert.equal(ent.rollover, -600);
    assert.equal(ent.budget, 1400); // 2000 - 600
    assert.equal(stats.totalRollover, -600);
  });

  it('chains multi-month carry forward across successive months', () => {
    const state = {
      categories,
      userSettings: { carryForwardEnabled: true },
      transactions: [
        // Aug 2026: Base 4000, spent 3000 -> +1000 leftover
        { amount: 3000, type: 'expense', categoryId: 3, timestamp: '2026-08-10T10:00:00.000Z' },
        // Sep 2026: Effective 5000, spent 5500 -> -500 deficit
        { amount: 5500, type: 'expense', categoryId: 3, timestamp: '2026-09-12T10:00:00.000Z' },
        // Oct 2026: Effective 3500, spent 2000 -> +1500 leftover
        { amount: 2000, type: 'expense', categoryId: 3, timestamp: '2026-10-05T10:00:00.000Z' }
      ]
    };

    BudgetPage.currentDate = new Date(2026, 10, 1); // November 2026
    const stats = BudgetPage.calculateBudgetStats(state);

    const shop = stats.categoryStats.find(c => c.name === 'Shopping');
    assert.ok(shop);
    assert.equal(shop.baseBudget, 4000);
    assert.equal(shop.rollover, 1500);
    assert.equal(shop.budget, 5500);
  });

  it('isolates budget when carryForwardEnabled is false', () => {
    const state = {
      categories,
      userSettings: { carryForwardEnabled: false },
      transactions: [
        { amount: 2000, type: 'expense', categoryId: 1, timestamp: '2026-10-10T10:00:00.000Z' }
      ]
    };

    BudgetPage.currentDate = new Date(2026, 10, 1); // November 2026
    const stats = BudgetPage.calculateBudgetStats(state);

    const food = stats.categoryStats.find(c => c.name === 'Food & Dining');
    assert.equal(food.rollover, 0);
    assert.equal(food.budget, 5000);
    assert.equal(stats.totalRollover, 0);
  });
});

describe('Web Dashboard Carry Forward Dynamics', () => {
  it('carries forward prior net savings into monthly net balance', () => {
    const state = {
      categories: [],
      dateFilter: 'thisMonth',
      userSettings: { carryForwardEnabled: true },
      transactions: [
        // Prior month: Income 60,000, Expense 40,000 -> 20,000 net left
        { amount: 60000, type: 'income', timestamp: '2026-10-01T10:00:00.000Z' },
        { amount: 40000, type: 'expense', timestamp: '2026-10-05T10:00:00.000Z' },
        // Current month: Income 15,000, Expense 5,000 -> 10,000 period net
        { amount: 15000, type: 'income', timestamp: new Date().toISOString() },
        { amount: 5000, type: 'expense', timestamp: new Date().toISOString() }
      ]
    };

    const stats = DashboardPage.calculateStats(state);
    assert.equal(stats.carriedForward, 20000);
    assert.equal(stats.periodNet, 10000);
    assert.equal(stats.balance, 30000);
  });

  it('isolates dashboard net balance when carry forward is disabled', () => {
    const state = {
      categories: [],
      dateFilter: 'thisMonth',
      userSettings: { carryForwardEnabled: false },
      transactions: [
        { amount: 60000, type: 'income', timestamp: '2026-10-01T10:00:00.000Z' },
        { amount: 40000, type: 'expense', timestamp: '2026-10-05T10:00:00.000Z' },
        { amount: 15000, type: 'income', timestamp: new Date().toISOString() },
        { amount: 5000, type: 'expense', timestamp: new Date().toISOString() }
      ]
    };

    const stats = DashboardPage.calculateStats(state);
    assert.equal(stats.carriedForward, 0);
    assert.equal(stats.periodNet, 10000);
    assert.equal(stats.balance, 10000);
  });
});
