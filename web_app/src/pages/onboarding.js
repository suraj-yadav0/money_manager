/* Onboarding Page Module */
import { StateManager } from '../state.js';
import { DbService } from '../db.js';
import { Formatters } from '../utils/formatters.js';

export const OnboardingPage = {
  step: 0, // 0 = welcome, 1 = income, 2 = confirmation
  incomeInputVal: '',

  render(state) {
    if (this.step === 0) {
      return this.renderWelcome();
    } else if (this.step === 1) {
      return this.renderIncome();
    } else {
      return this.renderReady();
    }
  },

  renderWelcome() {
    return `
      <div class="onboarding-container animate-fade-in">
        <div></div>
        <div style="text-align: center;">
          <div class="onboarding-logo">
            <span class="material-icons" style="font-size: 60px;">account_balance_wallet</span>
          </div>
          <h1 class="onboarding-title">Welcome to<br>Money Manager</h1>
          <p class="onboarding-desc">Take control of your finances.<br>Know where your money goes.</p>
        </div>
        <div class="flex-col">
          <button class="btn btn-primary" id="welcome-start-btn">Get Started</button>
          <button class="btn btn-outline" id="welcome-guest-btn">Continue as Guest</button>
        </div>
      </div>
    `;
  },

  renderIncome() {
    return `
      <div class="onboarding-container animate-fade-in">
        <div style="display: flex; align-items: center; justify-content: space-between;">
          <button class="btn-icon" id="income-back-btn">
            <span class="material-icons">arrow_back</span>
          </button>
          <div style="font-weight: 600; font-size: 14px;">Step 2 of 3</div>
          <div style="width: 44px;"></div>
        </div>
        
        <div style="margin: 40px 0;">
          <h2 style="font-size: 28px; margin-bottom: 8px;">What's your monthly income?</h2>
          <p style="color: var(--text-secondary); margin-bottom: 32px;">This helps us predict your month-end balance.</p>
          
          <div style="position: relative; display: flex; align-items: center; justify-content: center;">
            <span style="font-size: 32px; font-weight: 700; color: var(--primary); margin-right: 8px;">₹</span>
            <input type="number" class="onboarding-income-input" id="income-field" placeholder="50000" value="${this.incomeInputVal}">
          </div>
          <div id="income-error-msg" style="color: var(--error); text-align: center; font-size: 13px; margin-top: 16px; display: none;">Please enter a valid amount.</div>
        </div>
        
        <button class="btn btn-primary" id="income-next-btn">Continue</button>
      </div>
    `;
  },

  renderReady() {
    const income = parseFloat(this.incomeInputVal) || 0;
    const dailyBudget = income / Formatters.daysInCurrentMonth();

    return `
      <div class="onboarding-container animate-fade-in">
        <div></div>
        <div style="text-align: center;">
          <div style="width: 100px; height: 100px; background: rgba(255, 95, 31, 0.15); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 24px;">
            <span class="material-icons" style="font-size: 50px; color: var(--primary);">done</span>
          </div>
          <h2 style="font-size: 28px; margin-bottom: 16px;">You're all set!</h2>
          
          <div class="glass-card" style="text-align: left; margin-bottom: 24px;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
              <span style="color: var(--text-secondary); font-size: 14px;">Monthly Income</span>
              <span style="font-weight: 700; font-size: 18px; color: var(--primary);">${Formatters.currency(income)}</span>
            </div>
            <div style="height: 1px; background: var(--divider); margin: 12px 0;"></div>
            <div style="display: flex; justify-content: space-between; align-items: center;">
              <span style="color: var(--text-secondary); font-size: 14px;">Daily Budget</span>
              <span style="font-weight: 600; font-size: 18px;">${Formatters.currency(dailyBudget)}</span>
            </div>
          </div>
        </div>
        
        <div class="flex-col">
          <button class="btn btn-primary" id="ready-start-btn">Start Tracking</button>
          <button class="btn btn-outline" id="ready-edit-btn">Edit Income</button>
        </div>
      </div>
    `;
  },

  bindEvents() {
    // Step 0: Welcome events
    const startBtn = document.getElementById('welcome-start-btn');
    if (startBtn) {
      startBtn.addEventListener('click', () => {
        this.step = 1;
        StateManager.notify();
      });
    }

    const guestBtn = document.getElementById('welcome-guest-btn');
    if (guestBtn) {
      guestBtn.addEventListener('click', () => {
        this.step = 1;
        StateManager.notify();
      });
    }

    // Step 1: Income events
    const backBtn = document.getElementById('income-back-btn');
    if (backBtn) {
      backBtn.addEventListener('click', () => {
        this.step = 0;
        StateManager.notify();
      });
    }

    const incomeField = document.getElementById('income-field');
    const nextBtn = document.getElementById('income-next-btn');
    if (nextBtn && incomeField) {
      // Keep track of input value
      incomeField.addEventListener('input', (e) => {
        this.incomeInputVal = e.target.value;
      });

      nextBtn.addEventListener('click', () => {
        const income = parseFloat(this.incomeInputVal);
        if (isNaN(income) || income <= 0) {
          const errorMsg = document.getElementById('income-error-msg');
          if (errorMsg) errorMsg.style.display = 'block';
          return;
        }
        this.step = 2;
        StateManager.notify();
      });
    }

    // Step 2: Ready events
    const readyStartBtn = document.getElementById('ready-start-btn');
    if (readyStartBtn) {
      readyStartBtn.addEventListener('click', async () => {
        const income = parseFloat(this.incomeInputVal) || 0;
        
        // 1. Enable guest mode (offline-first, matches OnboardingScreen.dart logic if not logged in)
        StateManager.enableGuestMode();
        
        // 2. Initialize default structures (default categories, rules, user settings)
        DbService.seedGuestState();
        
        // 3. Save actual onboarded settings
        await DbService.saveUserSettings({
          monthlyIncome: income,
          isOnboarded: true
        });

        // 4. Create Salary Income transaction for 1st of the current month
        const salaryCat = StateManager.state.categories.find(c => c.name === 'Salary');
        if (salaryCat) {
          const now = new Date();
          const firstOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
          await DbService.addTransaction({
            amount: income,
            type: 'income',
            categoryId: salaryCat.id,
            timestamp: firstOfMonth,
            note: 'Monthly Salary',
            isRecurring: true
          });
        }
        
        // Return to app shell (trigger refresh)
        this.step = 0;
        this.incomeInputVal = '';
        
        // Since state change triggers router, it will automatically switch to AuthScreen or AppShell
        StateManager.notify();
      });
    }

    const readyEditBtn = document.getElementById('ready-edit-btn');
    if (readyEditBtn) {
      readyEditBtn.addEventListener('click', () => {
        this.step = 1;
        StateManager.notify();
      });
    }
  }
};
