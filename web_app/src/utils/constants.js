/* App-wide constants (exact replica of AppConstants in Flutter) */
export const AppConstants = {
  appName: 'Money Manager',
  appVersion: '1.0.0',
  
  // Currency
  defaultCurrency: 'INR',
  currencySymbol: '₹',
  supportedCurrencies: {
    'INR': '₹',
    'USD': '$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
  },

  // Thresholds for insights
  spendingSpikeFactor: 2.0,       // 2x daily average
  categoryDominanceThreshold: 0.4, // 40% of total
  budgetWarningThreshold: 0.8,     // 80% of budget

  // Forecast status thresholds
  safeBalanceThreshold: 0.2,      // 20% of income remaining
  cautionBalanceThreshold: 0.0,   // 0% remaining
};

export const TransactionType = {
  income: 'income',
  expense: 'expense',
};

export const ForecastStatus = {
  safe: 'safe',
  caution: 'caution',
  deficit: 'deficit',
  
  getLabel(status) {
    switch (status) {
      case this.safe:
        return 'On Track';
      case this.caution:
        return 'Borderline';
      case this.deficit:
        return 'At Risk';
      default:
        return 'On Track';
    }
  }
};
