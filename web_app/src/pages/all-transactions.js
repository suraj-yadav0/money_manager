/* Modern Financial Transactions Ledger Module */
import { StateManager } from '../state.js';
import { Formatters } from '../utils/formatters.js';
import { IconHelper, findCategory } from '../utils/icons.js';
import { DbService } from '../db.js';

export const AllTransactionsPage = {
  activeTypeFilter: 'all', // 'all', 'income', 'expense', 'recurring'
  searchQuery: '',

  render(state) {
    const list = this.getFilteredTransactions(state);
    
    // Calculate ledger totals
    let ledgerIncome = 0;
    let ledgerExpense = 0;
    list.forEach(tx => {
      if (tx.type === 'income') ledgerIncome += tx.amount;
      else ledgerExpense += tx.amount;
    });
    const netFlow = ledgerIncome - ledgerExpense;

    return `
      <div class="animate-fade-in" style="display: flex; flex-direction: column; gap: 24px;">
        <!-- Header & Action Controls -->
        <section class="hero-section" style="padding-bottom: 0;">
          <div class="hero-header" style="margin-bottom: 20px;">
            <div>
              <h1 class="hero-welcome-title">Transaction Ledger</h1>
              <p class="hero-subtitle">Comprehensive financial activity, search, filtering, and audit history.</p>
            </div>

            <div style="display: flex; align-items: center; gap: 12px;">
              <button class="btn-secondary" id="export-ledger-btn">
                <span class="material-icons" style="font-size: 16px;">download</span> Export JSON
              </button>
              <button class="btn-primary" id="ledger-add-tx-btn">
                <span class="material-icons" style="font-size: 18px;">add</span> Add Transaction
              </button>
            </div>
          </div>

          <!-- Ledger Summary Bar -->
          <div class="fintech-card" style="padding: 16px 24px; margin-bottom: 20px; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 16px;">
            <div style="display: flex; gap: 24px; align-items: center;">
              <div>
                <div style="font-size: 11px; text-transform: uppercase; font-weight: 700; color: var(--text-muted); letter-spacing: 0.05em;">Entries</div>
                <div style="font-size: 18px; font-weight: 800; color: var(--text-primary);" id="ledger-entries-count">${list.length} records</div>
              </div>
              <div style="height: 28px; width: 1px; background: var(--glass-border);"></div>
              <div>
                <div style="font-size: 11px; text-transform: uppercase; font-weight: 700; color: var(--text-muted); letter-spacing: 0.05em;">Inflow</div>
                <div style="font-size: 18px; font-weight: 800; color: var(--success);" id="ledger-inflow-total">+${Formatters.currency(ledgerIncome)}</div>
              </div>
              <div style="height: 28px; width: 1px; background: var(--glass-border);"></div>
              <div>
                <div style="font-size: 11px; text-transform: uppercase; font-weight: 700; color: var(--text-muted); letter-spacing: 0.05em;">Outflow</div>
                <div style="font-size: 18px; font-weight: 800; color: var(--text-primary);" id="ledger-outflow-total">${Formatters.currency(ledgerExpense)}</div>
              </div>
            </div>

            <div>
              <div style="font-size: 11px; text-transform: uppercase; font-weight: 700; color: var(--text-muted); letter-spacing: 0.05em; text-align: right;">Net Cash Flow</div>
              <div style="font-size: 18px; font-weight: 800; color: ${netFlow >= 0 ? 'var(--success)' : 'var(--error)'};" id="ledger-net-flow">
                ${(netFlow >= 0 ? '+' : '') + Formatters.currency(netFlow)}
              </div>
            </div>
          </div>
        </section>

        <!-- Search Bar and Filter Tabs -->
        <div style="display: flex; gap: 16px; align-items: center; justify-content: space-between; flex-wrap: wrap;">
          <!-- Search Input with Clear Button -->
          <div style="flex: 1 1 320px; max-width: 480px;">
            <div class="search-bar-wrapper" style="position: relative;">
              <span class="material-icons search-icon">search</span>
              <input type="text" class="search-input" id="ledger-search-input" placeholder="Search by note, merchant, or category..." value="${this.searchQuery}" style="padding-right: 38px;">
              <button type="button" class="btn-icon" id="ledger-search-clear-btn" style="position: absolute; right: 8px; width: 28px; height: 28px; display: ${this.searchQuery ? 'flex' : 'none'}; cursor: pointer; border: none; background: transparent;" title="Clear search">
                <span class="material-icons" style="font-size: 16px; color: var(--text-muted);">close</span>
              </button>
            </div>
          </div>

          <!-- Type Filter Chips -->
          <div class="filter-group">
            <button class="filter-chip ${this.activeTypeFilter === 'all' ? 'active' : ''}" data-type="all">All</button>
            <button class="filter-chip ${this.activeTypeFilter === 'income' ? 'active' : ''}" data-type="income">Income</button>
            <button class="filter-chip ${this.activeTypeFilter === 'expense' ? 'active' : ''}" data-type="expense">Expenses</button>
            <button class="filter-chip ${this.activeTypeFilter === 'recurring' ? 'active' : ''}" data-type="recurring">Recurring</button>
          </div>
        </div>

        <!-- Transactions Ledger List -->
        <div class="fintech-card" style="padding: 16px 20px;" id="ledger-card-body">
          ${list.length === 0 ? `
            <div style="text-align: center; padding: 60px 20px; color: var(--text-muted);">
              <div style="width: 56px; height: 56px; border-radius: 50%; background: rgba(255,255,255,0.04); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px;">
                <span class="material-icons" style="font-size: 28px; opacity: 0.5;">search_off</span>
              </div>
              <div style="font-size: 16px; font-weight: 600; color: var(--text-primary); margin-bottom: 4px;">No matching transactions found</div>
              <div style="font-size: 13px;">Try adjusting your search criteria or filter tags.</div>
            </div>
          ` : `
            <div class="tx-list">
              ${list.map(tx => this.renderTransactionRow(tx, state.categories)).join('')}
            </div>
          `}
        </div>
      </div>
    `;
  },

  renderTransactionRow(tx, categories) {
    const cat = findCategory(categories, tx.categoryId || tx.category_id);
    const icon = IconHelper.getMaterialIcon(cat ? cat.icon : 'category');
    const isIncome = tx.type === 'income';
    const formattedAmount = (isIncome ? '+' : '-') + Formatters.currency(tx.amount);

    return `
      <div class="tx-row ledger-tx-row" data-sync-id="${tx.sync_id || ''}" data-id="${tx.id || ''}">
        <div class="tx-left">
          <div class="tx-icon-box">
            <span class="material-icons">${icon}</span>
          </div>
          <div class="tx-info">
            <div class="tx-title">${tx.note || (cat ? cat.name : 'Transaction')}</div>
            <div class="tx-meta">
              <span class="tx-tag">${cat ? cat.name : 'Other'}</span>
              <span>•</span>
              <span>${tx.paymentMode || tx.payment_mode || 'Cash'}</span>
              ${tx.isRecurring || tx.is_recurring ? `<span class="tx-tag">Recurring</span>` : ''}
              ${tx.goalId || tx.goal_id ? `<span class="tx-tag">Goal Linked</span>` : ''}
            </div>
          </div>
        </div>
        <div class="tx-right">
          <div>
            <div class="tx-amount ${isIncome ? 'income' : 'expense'}">${formattedAmount}</div>
            <div class="tx-date">${Formatters.dateTime(tx.timestamp)}</div>
          </div>
          <button class="btn-icon btn-icon-sm delete-tx-btn" data-sync-id="${tx.sync_id || ''}" data-id="${tx.id || ''}" title="Delete transaction">
            <span class="material-icons" style="font-size: 16px;">delete_outline</span>
          </button>
        </div>
      </div>
    `;
  },

  getFilteredTransactions(state) {
    return state.transactions
      .filter(t => {
        // Type filter
        if (this.activeTypeFilter === 'income' && t.type !== 'income') return false;
        if (this.activeTypeFilter === 'expense' && t.type !== 'expense') return false;
        if (this.activeTypeFilter === 'recurring' && !(t.isRecurring || t.is_recurring)) return false;
        
        // Search query
        if (this.searchQuery && this.searchQuery.trim() !== '') {
          const query = this.searchQuery.toLowerCase();
          const noteMatch = t.note && t.note.toLowerCase().includes(query);
          const cat = findCategory(state.categories, t.categoryId || t.category_id);
          const catMatch = cat && cat.name.toLowerCase().includes(query);
          const modeMatch = (t.paymentMode || t.payment_mode || '').toLowerCase().includes(query);
          return noteMatch || catMatch || modeMatch;
        }
        
        return true;
      })
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  },

  updateLedgerView(state) {
    const list = this.getFilteredTransactions(state);
    
    // Calculate ledger totals
    let ledgerIncome = 0;
    let ledgerExpense = 0;
    list.forEach(tx => {
      if (tx.type === 'income') ledgerIncome += tx.amount;
      else ledgerExpense += tx.amount;
    });
    const netFlow = ledgerIncome - ledgerExpense;

    // Update summary counts & totals in place
    const entriesEl = document.getElementById('ledger-entries-count');
    if (entriesEl) entriesEl.textContent = `${list.length} records`;

    const inflowEl = document.getElementById('ledger-inflow-total');
    if (inflowEl) inflowEl.textContent = `+${Formatters.currency(ledgerIncome)}`;

    const outflowEl = document.getElementById('ledger-outflow-total');
    if (outflowEl) outflowEl.textContent = `${Formatters.currency(ledgerExpense)}`;

    const netFlowEl = document.getElementById('ledger-net-flow');
    if (netFlowEl) {
      netFlowEl.textContent = `${(netFlow >= 0 ? '+' : '') + Formatters.currency(netFlow)}`;
      netFlowEl.style.color = netFlow >= 0 ? 'var(--success)' : 'var(--error)';
    }

    // Update filter chip active classes
    document.querySelectorAll('.filter-chip[data-type]').forEach(chip => {
      chip.classList.toggle('active', chip.getAttribute('data-type') === this.activeTypeFilter);
    });

    // Update transactions list container
    const listCardBody = document.getElementById('ledger-card-body');
    if (listCardBody) {
      if (list.length === 0) {
        listCardBody.innerHTML = `
          <div style="text-align: center; padding: 60px 20px; color: var(--text-muted);">
            <div style="width: 56px; height: 56px; border-radius: 50%; background: rgba(255,255,255,0.04); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px;">
              <span class="material-icons" style="font-size: 28px; opacity: 0.5;">search_off</span>
            </div>
            <div style="font-size: 16px; font-weight: 600; color: var(--text-primary); margin-bottom: 4px;">No matching transactions found</div>
            <div style="font-size: 13px;">Try adjusting your search criteria or filter tags.</div>
          </div>
        `;
      } else {
        listCardBody.innerHTML = `
          <div class="tx-list">
            ${list.map(tx => this.renderTransactionRow(tx, state.categories)).join('')}
          </div>
        `;
      }
      this.bindRowEvents(state);
    }
  },

  bindEvents(state) {
    const searchInput = document.getElementById('ledger-search-input');
    const clearBtn = document.getElementById('ledger-search-clear-btn');

    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        this.searchQuery = e.target.value;
        if (clearBtn) clearBtn.style.display = this.searchQuery ? 'flex' : 'none';
        this.updateLedgerView(state);
      });
    }

    if (clearBtn) {
      clearBtn.addEventListener('click', () => {
        this.searchQuery = '';
        if (searchInput) {
          searchInput.value = '';
          searchInput.focus();
        }
        clearBtn.style.display = 'none';
        this.updateLedgerView(state);
      });
    }

    // Filter chips
    const typeChips = document.querySelectorAll('.filter-chip[data-type]');
    typeChips.forEach(chip => {
      chip.addEventListener('click', () => {
        this.activeTypeFilter = chip.getAttribute('data-type');
        this.updateLedgerView(state);
      });
    });

    // Add Transaction CTA
    document.getElementById('ledger-add-tx-btn')?.addEventListener('click', () => {
      import('./add-transaction.js').then(({ AddTransactionModal }) => {
        AddTransactionModal.show(null);
      });
    });

    // Export JSON CTA
    document.getElementById('export-ledger-btn')?.addEventListener('click', () => {
      const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(state.transactions, null, 2));
      const downloadAnchor = document.createElement('a');
      downloadAnchor.setAttribute("href", dataStr);
      downloadAnchor.setAttribute("download", `quantro_ledger_${new Date().toISOString().slice(0, 10)}.json`);
      document.body.appendChild(downloadAnchor);
      downloadAnchor.click();
      downloadAnchor.remove();
    });

    this.bindRowEvents(state);
  },

  bindRowEvents(state) {
    // Transaction click to edit
    const rows = document.querySelectorAll('.ledger-tx-row');
    rows.forEach(row => {
      row.addEventListener('click', (e) => {
        if (e.target.closest('.delete-tx-btn')) return;

        const syncId = row.getAttribute('data-sync-id');
        const localId = row.getAttribute('data-id');
        const tx = state.transactions.find(t => (syncId && t.sync_id === syncId) || (localId && String(t.id) === String(localId)));
        if (tx) {
          import('./add-transaction.js').then(({ AddTransactionModal }) => {
            AddTransactionModal.show(tx);
          });
        }
      });
    });

    // Transaction delete button
    const delBtns = document.querySelectorAll('.delete-tx-btn');
    delBtns.forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const syncId = btn.getAttribute('data-sync-id');
        const localId = btn.getAttribute('data-id');
        if (confirm('Are you sure you want to delete this transaction?')) {
          await DbService.deleteTransaction(syncId, localId);
        }
      });
    });
  }
};
