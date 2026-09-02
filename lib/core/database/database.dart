import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// Transaction table - stores all income and expenses
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().nullable()(); // UUID string for cloud sync
  RealColumn get amount => real()();
  TextColumn get type => text()(); // 'income' | 'expense'
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get goalId =>
      integer().nullable().references(Goals, #id)(); // Optional goal link
  IntColumn get accountId =>
      integer().nullable().references(BankAccounts, #id)(); // Optional bank account link
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get paymentMode => text().nullable()(); // 'Cash', 'UPI', etc.
  TextColumn get receiptImagePath =>
      text().nullable()(); // Path to receipt/photo
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().nullable().withDefault(currentDateAndTime)();
}

/// Category table - predefined and user categories
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().nullable()();
  TextColumn get name => text().unique()();
  TextColumn get icon => text()(); // Material icon name
  RealColumn get monthlyBudget => real().nullable()();
  TextColumn get type =>
      text().withDefault(const Constant('expense'))(); // 'income' | 'expense'
  BoolColumn get isDefault =>
      boolean().withDefault(const Constant(true))(); // System vs user-created
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().nullable().withDefault(currentDateAndTime)();
}

/// User settings table - stores user preferences
class UserSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().nullable()();
  RealColumn get monthlyIncome => real().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  BoolColumn get isOnboarded => boolean().withDefault(const Constant(false))();
  BoolColumn get biometricEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showIncomeChart =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().nullable().withDefault(currentDateAndTime)();
}

/// Goal table - savings goals
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().nullable()();
  TextColumn get name => text()();
  RealColumn get targetAmount => real()();
  DateTimeColumn get deadline => dateTime()();
  RealColumn get savedAmount => real().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().nullable().withDefault(currentDateAndTime)();
}

/// Goal contributions table - tracks individual savings contributions
class GoalContributions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().nullable()();
  IntColumn get goalId => integer().references(Goals, #id)();
  RealColumn get amount => real()();
  TextColumn get note => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().nullable().withDefault(currentDateAndTime)();
}

/// Categorization rules table - learns from user corrections
class CategorizationRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().nullable()();
  TextColumn get keyword => text()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get weight =>
      integer().withDefault(const Constant(1))(); // Higher = stronger match
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().nullable().withDefault(currentDateAndTime)();
}

/// Assets table - tracks wealth items (savings, investments, loans, gold, etc.)
class Assets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().nullable()();
  TextColumn get name => text()(); // e.g. "SBI Savings", "Gold Chain"
  TextColumn get type =>
      text()(); // 'savings' | 'investment' | 'loan' | 'gold' | 'property' | 'other'
  RealColumn get value => real()(); // Current value (always positive)
  BoolColumn get isLiability =>
      boolean().withDefault(const Constant(false))(); // true for loans
  TextColumn get note => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().nullable().withDefault(currentDateAndTime)();
}

/// Bank accounts table - tracks user bank accounts and cards
class BankAccounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().nullable()();
  TextColumn get name => text()(); // e.g. "HDFC Salary Account", "SBI Savings"
  TextColumn get bankName => text()(); // e.g. "HDFC Bank", "SBI", "ICICI Bank"
  TextColumn get accountNumberLast4 => text().nullable()(); // e.g. "1234"
  TextColumn get accountType =>
      text().withDefault(const Constant('savings'))(); // 'savings' | 'current' | 'credit_card' | 'wallet'
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  TextColumn get colorHex => text().nullable()(); // Color hex string
  BoolColumn get isDefault =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().nullable().withDefault(currentDateAndTime)();
}

/// Detected SMS transactions table - stores parsed messages pending user review
class SmsTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().nullable()();
  TextColumn get smsId => text().unique()(); // Android SMS message ID or hash
  TextColumn get sender => text()(); // e.g. "VM-HDFCBK"
  TextColumn get body => text()(); // Full raw SMS body
  RealColumn get amount => real()();
  TextColumn get type => text()(); // 'expense' | 'income'
  TextColumn get paymentMode =>
      text().nullable()(); // 'UPI' | 'Debit Card' | 'Credit Card' | 'Net Banking'
  TextColumn get bankName => text().nullable()();
  TextColumn get accountNumberLast4 => text().nullable()();
  TextColumn get merchant => text().nullable()();
  TextColumn get refNumber => text().nullable()(); // UTR or Ref number
  RealColumn get balance => real().nullable()(); // Available balance parsed from SMS
  IntColumn get suggestedCategoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get suggestedAccountId =>
      integer().nullable().references(BankAccounts, #id)();
  DateTimeColumn get smsTimestamp => dateTime()();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))(); // 'pending' | 'accepted' | 'rejected'
  IntColumn get transactionId =>
      integer().nullable().references(Transactions, #id)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().nullable().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [
    Transactions,
    Categories,
    UserSettings,
    Goals,
    GoalContributions,
    CategorizationRules,
    Assets,
    BankAccounts,
    SmsTransactions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        // Fix any null updated_at fields from legacy schema migrations
        final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        for (final table in [
          'transactions',
          'categories',
          'user_settings',
          'goals',
          'goal_contributions',
          'categorization_rules',
          'assets',
          'bank_accounts',
          'sms_transactions'
        ]) {
          try {
            await customStatement(
              'UPDATE $table SET updated_at = $nowSeconds WHERE updated_at IS NULL',
            );
          } catch (_) {}
        }
      },
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedDefaultCategories();
        await _seedDefaultRules();
        await _seedDefaultBankAccounts();
        await _createDefaultUserSettings();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await _seedNewCategoriesV2();
        }
        if (from < 3) {
          await m.createTable(goalContributions);
          // Add isCompleted column to existing goals table
          await customStatement(
            'ALTER TABLE goals ADD COLUMN is_completed INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 4) {
          // Add optional goal_id column to transactions table
          await customStatement(
            'ALTER TABLE transactions ADD COLUMN goal_id INTEGER REFERENCES goals(id)',
          );
        }
        if (from < 5) {
          // Add payment_mode column to transactions table
          await customStatement(
            'ALTER TABLE transactions ADD COLUMN payment_mode TEXT',
          );
        }
        if (from < 6) {
          // Add receipt_image_path column to transactions table
          await customStatement(
            'ALTER TABLE transactions ADD COLUMN receipt_image_path TEXT',
          );
        }
        if (from < 7) {
          // Add show_income_chart column to user_settings table
          await customStatement(
            'ALTER TABLE user_settings ADD COLUMN show_income_chart INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 8) {
          // Create assets table for wealth tracking
          await m.createTable(assets);
        }
        if (from < 9) {
          // Add cloud synchronization columns
          for (final table in [
            'transactions',
            'categories',
            'user_settings',
            'goals',
            'goal_contributions',
            'categorization_rules',
            'assets'
          ]) {
            await customStatement('ALTER TABLE $table ADD COLUMN sync_id TEXT');
            await customStatement(
                'ALTER TABLE $table ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0');
          }
          final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          await customStatement('ALTER TABLE transactions ADD COLUMN updated_at INTEGER NOT NULL DEFAULT $nowSec');
          await customStatement('ALTER TABLE categories ADD COLUMN updated_at INTEGER NOT NULL DEFAULT $nowSec');
          await customStatement('ALTER TABLE user_settings ADD COLUMN updated_at INTEGER NOT NULL DEFAULT $nowSec');
          await customStatement('ALTER TABLE goals ADD COLUMN updated_at INTEGER NOT NULL DEFAULT $nowSec');
          await customStatement('ALTER TABLE goal_contributions ADD COLUMN updated_at INTEGER NOT NULL DEFAULT $nowSec');
          await customStatement('ALTER TABLE categorization_rules ADD COLUMN updated_at INTEGER NOT NULL DEFAULT $nowSec');
        }
        if (from < 10) {
          // Create bank accounts and sms transactions tables
          await m.createTable(bankAccounts);
          await m.createTable(smsTransactions);
          await customStatement(
            'ALTER TABLE transactions ADD COLUMN account_id INTEGER REFERENCES bank_accounts(id)',
          );
          await _seedDefaultBankAccounts();
        }
      },
    );
  }

  /// Seed new categories for version 2
  Future<void> _seedNewCategoriesV2() async {
    final newCategories = [
      CategoriesCompanion.insert(
        name: 'Gifts',
        icon: 'card_giftcard',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Savings',
        icon: 'savings',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Investments',
        icon:
            'show_chart', // distinct from 'trending_up' used by Investment income
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Family',
        icon: 'family_restroom',
        type: const Value('expense'),
      ),
    ];

    await batch((batch) {
      // Use insertMode: InsertMode.replace or check existence?
      // Since names are unique, we just try to insert.
      // However, drift batch insert doesn't easily support ignore on conflict per row without raw sql in some versions.
      // But standard insert throws.
      // Let's safe-guard by checking or just inserting.
      // For simplicity in this environment, I'll rely on the fact that these shouldn't exist.
      // But to be robust against re-runs or partial states, I should be careful.
      // Actually, standard batch insert is fine for migration of a known previous state.
      batch.insertAll(
        categories,
        newCategories,
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// Seed default expense categories
  Future<void> _seedDefaultCategories() async {
    final defaultCategories = [
      // Expense categories
      CategoriesCompanion.insert(
        name: 'Food & Dining',
        icon: 'restaurant',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Transport',
        icon: 'directions_car',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Shopping',
        icon: 'shopping_bag',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Entertainment',
        icon: 'movie',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Bills & Utilities',
        icon: 'receipt_long',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Health',
        icon: 'local_hospital',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Education',
        icon: 'school',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Self Care',
        icon: 'spa',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Groceries',
        icon: 'local_grocery_store',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Gifts',
        icon: 'card_giftcard',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Savings',
        icon: 'savings',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Investments',
        icon: 'show_chart',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Family',
        icon: 'family_restroom',
        type: const Value('expense'),
      ),
      CategoriesCompanion.insert(
        name: 'Other',
        icon: 'more_horiz',
        type: const Value('expense'),
      ),
      // Income categories
      CategoriesCompanion.insert(
        name: 'Salary',
        icon: 'work',
        type: const Value('income'),
      ),
      CategoriesCompanion.insert(
        name: 'Freelance',
        icon: 'laptop',
        type: const Value('income'),
      ),
      CategoriesCompanion.insert(
        name: 'Investment',
        icon: 'trending_up',
        type: const Value('income'),
      ),
      CategoriesCompanion.insert(
        name: 'Other Income',
        icon: 'attach_money',
        type: const Value('income'),
      ),
    ];

    await batch((batch) {
      batch.insertAll(categories, defaultCategories);
    });
  }

  /// Seed default categorization rules
  Future<void> _seedDefaultRules() async {
    // Get category IDs after they're created
    final allCategories = await select(categories).get();
    final categoryMap = {for (var c in allCategories) c.name: c.id};

    final rules = [
      // Food & Dining
      if (categoryMap['Food & Dining'] != null) ...[
        CategorizationRulesCompanion.insert(
          keyword: 'zomato',
          categoryId: categoryMap['Food & Dining']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'swiggy',
          categoryId: categoryMap['Food & Dining']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'restaurant',
          categoryId: categoryMap['Food & Dining']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'cafe',
          categoryId: categoryMap['Food & Dining']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'food',
          categoryId: categoryMap['Food & Dining']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'lunch',
          categoryId: categoryMap['Food & Dining']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'dinner',
          categoryId: categoryMap['Food & Dining']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'breakfast',
          categoryId: categoryMap['Food & Dining']!,
        ),
      ],
      // Transport
      if (categoryMap['Transport'] != null) ...[
        CategorizationRulesCompanion.insert(
          keyword: 'uber',
          categoryId: categoryMap['Transport']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'ola',
          categoryId: categoryMap['Transport']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'rapido',
          categoryId: categoryMap['Transport']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'petrol',
          categoryId: categoryMap['Transport']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'fuel',
          categoryId: categoryMap['Transport']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'metro',
          categoryId: categoryMap['Transport']!,
        ),
      ],
      // Shopping
      if (categoryMap['Shopping'] != null) ...[
        CategorizationRulesCompanion.insert(
          keyword: 'amazon',
          categoryId: categoryMap['Shopping']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'flipkart',
          categoryId: categoryMap['Shopping']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'myntra',
          categoryId: categoryMap['Shopping']!,
        ),
      ],
      // Entertainment
      if (categoryMap['Entertainment'] != null) ...[
        CategorizationRulesCompanion.insert(
          keyword: 'netflix',
          categoryId: categoryMap['Entertainment']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'prime',
          categoryId: categoryMap['Entertainment']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'hotstar',
          categoryId: categoryMap['Entertainment']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'movie',
          categoryId: categoryMap['Entertainment']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'spotify',
          categoryId: categoryMap['Entertainment']!,
        ),
      ],
      // Bills & Utilities
      if (categoryMap['Bills & Utilities'] != null) ...[
        CategorizationRulesCompanion.insert(
          keyword: 'electricity',
          categoryId: categoryMap['Bills & Utilities']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'water',
          categoryId: categoryMap['Bills & Utilities']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'internet',
          categoryId: categoryMap['Bills & Utilities']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'mobile',
          categoryId: categoryMap['Bills & Utilities']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'rent',
          categoryId: categoryMap['Bills & Utilities']!,
        ),
      ],
      // Groceries
      if (categoryMap['Groceries'] != null) ...[
        CategorizationRulesCompanion.insert(
          keyword: 'bigbasket',
          categoryId: categoryMap['Groceries']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'blinkit',
          categoryId: categoryMap['Groceries']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'zepto',
          categoryId: categoryMap['Groceries']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'instamart',
          categoryId: categoryMap['Groceries']!,
        ),
        CategorizationRulesCompanion.insert(
          keyword: 'grocery',
          categoryId: categoryMap['Groceries']!,
        ),
      ],
    ];

    if (rules.isNotEmpty) {
      await batch((batch) {
        batch.insertAll(categorizationRules, rules);
      });
    }
  }

  /// Seed default bank accounts
  Future<void> _seedDefaultBankAccounts() async {
    final defaultAccounts = [
      BankAccountsCompanion.insert(
        name: 'Primary Account',
        bankName: 'HDFC Bank',
        accountNumberLast4: const Value('1234'),
        accountType: const Value('savings'),
        balance: const Value(25000.0),
        colorHex: const Value('#1E88E5'),
        isDefault: const Value(true),
      ),
      BankAccountsCompanion.insert(
        name: 'Secondary Account',
        bankName: 'State Bank of India',
        accountNumberLast4: const Value('5678'),
        accountType: const Value('savings'),
        balance: const Value(10000.0),
        colorHex: const Value('#00897B'),
        isDefault: const Value(false),
      ),
      BankAccountsCompanion.insert(
        name: 'Credit Card',
        bankName: 'ICICI Bank',
        accountNumberLast4: const Value('4001'),
        accountType: const Value('credit_card'),
        balance: const Value(0.0),
        colorHex: const Value('#E53935'),
        isDefault: const Value(false),
      ),
      BankAccountsCompanion.insert(
        name: 'Cash Wallet',
        bankName: 'Cash',
        accountNumberLast4: const Value(null),
        accountType: const Value('wallet'),
        balance: const Value(2000.0),
        colorHex: const Value('#43A047'),
        isDefault: const Value(false),
      ),
    ];

    await batch((batch) {
      batch.insertAll(bankAccounts, defaultAccounts, mode: InsertMode.insertOrIgnore);
    });
  }

  /// Create default user settings
  Future<void> _createDefaultUserSettings() async {
    await into(userSettings).insert(UserSettingsCompanion.insert());
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'money_manager.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
