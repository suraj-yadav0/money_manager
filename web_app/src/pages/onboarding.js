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
      <div class="onboarding-container animate-fade-in" style="min-height: 100vh; display: flex; flex-direction: column; justify-content: space-between; padding: 40px 20px;">
        <div style="display: flex; justify-content: flex-end;">
          <button class="btn btn-outline" id="welcome-signin-link" style="width: auto; padding: 6px 14px; font-size: 13px; border-color: rgba(255,255,255,0.15);">
            <span class="material-icons" style="font-size: 16px; margin-right: 4px;">login</span> Sign In
          </button>
        </div>
        
        <div style="text-align: center;">
          <div class="onboarding-logo" style="width: 80px; height: 80px; background: linear-gradient(135deg, var(--primary) 0%, #FF8C42 100%); border-radius: 24px; display: flex; align-items: center; justify-content: center; margin: 0 auto 24px; box-shadow: 0 12px 30px rgba(255, 95, 31, 0.35);">
            <span class="material-icons" style="font-size: 48px; color: #FFF;">account_balance_wallet</span>
          </div>
          <h1 class="onboarding-title" style="font-size: 32px; font-weight: 800; margin-bottom: 12px;">Welcome to<br>Money Manager</h1>
          <p class="onboarding-desc" style="color: var(--text-secondary); font-size: 15px; line-height: 1.5;">Take full control of your finances.<br>Know exactly where your money goes.</p>
        </div>

        <div class="flex-col" style="gap: 12px;">
          <button class="btn btn-primary" id="welcome-start-btn" style="font-weight: 700; font-size: 15px; padding: 14px;">Get Started</button>
          <button class="btn btn-outline" id="welcome-guest-btn" style="font-weight: 600; font-size: 14px; padding: 12px;">Continue in Offline Mode</button>
        </div>
      </div>
    `;
  },

  renderIncome() {
    return `
      <div class="onboarding-container animate-fade-in" style="min-height: 100vh; display: flex; flex-direction: column; justify-content: space-between; padding: 40px 20px;">
        <div style="display: flex; align-items: center; justify-content: space-between;">
          <button class="btn-icon" id="income-back-btn">
            <span class="material-icons">arrow_back</span>
          </button>
          <div style="font-weight: 600; font-size: 14px; color: var(--text-muted);">Step 2 of 3</div>
          <div style="width: 44px;"></div>
        </div>
        
        <div style="margin: 40px 0; text-align: center;">
          <h2 style="font-size: 26px; font-weight: 700; margin-bottom: 8px;">What's your monthly income?</h2>
          <p style="color: var(--text-secondary); font-size: 14px; margin-bottom: 36px;">This helps predict your month-end balance and budget.</p>
          
          <div style="position: relative; display: flex; align-items: center; justify-content: center;">
            <span style="font-size: 32px; font-weight: 700; color: var(--primary); margin-right: 8px;">₹</span>
            <input type="number" class="onboarding-income-input" id="income-field" placeholder="50000" value="${this.incomeInputVal}" style="font-size: 36px; font-weight: 700; width: 220px; text-align: center; border-bottom: 2px solid var(--primary); background: transparent; color: #FFF;">
          </div>
          <div id="income-error-msg" style="color: var(--error); text-align: center; font-size: 13px; margin-top: 16px; display: none;">Please enter a valid amount.</div>
        </div>
        
        <button class="btn btn-primary" id="income-next-btn" style="font-weight: 700; font-size: 15px; padding: 14px;">Continue</button>
      </div>
    `;
  },

  renderReady() {
    const income = parseFloat(this.incomeInputVal) || 0;
    const dailyBudget = income / Formatters.daysInCurrentMonth();

    return `
      <div class="onboarding-container animate-fade-in" style="min-height: 100vh; display: flex; flex-direction: column; justify-content: space-between; padding: 40px 20px;">
        <div></div>
        <div style="text-align: center;">
          <div style="width: 90px; height: 90px; background: rgba(255, 95, 31, 0.15); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 24px; border: 1px solid rgba(255, 95, 31, 0.3);">
            <span class="material-icons" style="font-size: 46px; color: var(--primary);">done</span>
          </div>
          <h2 style="font-size: 28px; font-weight: 700; margin-bottom: 16px;">You're all set!</h2>
          
          <div class="glass-card" style="text-align: left; margin-bottom: 24px; padding: 20px;">
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
        
        <div class="flex-col" style="gap: 12px;">
          <button class="btn btn-primary" id="ready-start-btn" style="font-weight: 700; font-size: 15px; padding: 14px;">Start Tracking</button>
          <button class="btn btn-outline" id="ready-edit-btn" style="font-weight: 600; font-size: 14px; padding: 12px;">Edit Income</button>
        </div>
      </div>
    `;
  },

  bindEvents() {
    // Step 0: Sign in link
    const signinLink = document.getElementById('welcome-signin-link');
    if (signinLink) {
      signinLink.addEventListener('click', () => {
        StateManager.disableGuestMode();
        this.step = 0;
        this.incomeInputVal = '';
      });
    }

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
      incomeField.addEventListener('input', (e) => {
        this.incomeInputVal = e.target.value;
      });

      incomeField.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          nextBtn.click();
        }
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
        const user = StateManager.state.user;

        if (user) {
          // User is already logged in with Firebase
          await DbService.saveUserSettings({
            monthlyIncome: income,
            isOnboarded: true
          });
        } else {
          // Guest mode
          StateManager.enableGuestMode();
          DbService.seedGuestState();
          await DbService.saveUserSettings({
            monthlyIncome: income,
            isOnboarded: true
          });
        }

        // Create Salary Income transaction for 1st of the current month
        const salaryCat = StateManager.state.categories.find(c => c.name === 'Salary');
        if (salaryCat) {
          const now = new Date();
          const firstOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
          await DbService.addTransaction({
            amount: income,
            type: 'income',
            categoryId: salaryCat.id || salaryCat.sync_id,
            timestamp: firstOfMonth,
            note: 'Monthly Salary',
            isRecurring: true
          });
        }
        
        this.step = 0;
        this.incomeInputVal = '';
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
