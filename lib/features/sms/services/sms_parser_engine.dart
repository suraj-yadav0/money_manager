/// Represents a parsed transaction from an SMS message
class ParsedSmsTransaction {
  final String smsId;
  final String sender;
  final String rawBody;
  final double amount;
  final String type; // 'expense' | 'income'
  final String? paymentMode; // 'UPI', 'Debit Card', 'Credit Card', 'Net Banking'
  final String? bankName; // 'HDFC Bank', 'State Bank of India', 'ICICI Bank', etc.
  final String? accountNumberLast4; // e.g. '1234'
  final String? merchant; // 'Swiggy', 'Zomato', 'Amazon', etc.
  final String? refNumber; // '423456789012'
  final double? balance; // Available balance if mentioned
  final DateTime timestamp;

  const ParsedSmsTransaction({
    required this.smsId,
    required this.sender,
    required this.rawBody,
    required this.amount,
    required this.type,
    this.paymentMode,
    this.bankName,
    this.accountNumberLast4,
    this.merchant,
    this.refNumber,
    this.balance,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'smsId': smsId,
        'sender': sender,
        'rawBody': rawBody,
        'amount': amount,
        'type': type,
        'paymentMode': paymentMode,
        'bankName': bankName,
        'accountNumberLast4': accountNumberLast4,
        'merchant': merchant,
        'refNumber': refNumber,
        'balance': balance,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Represents a parsed credit card bill statement from an SMS
class ParsedSmsBillStatement {
  final String smsId;
  final String sender;
  final String rawBody;
  final double totalDue;
  final double? minDue;
  final DateTime? dueDate;
  final String? bankName;
  final String? cardLast4;
  final DateTime timestamp;

  const ParsedSmsBillStatement({
    required this.smsId,
    required this.sender,
    required this.rawBody,
    required this.totalDue,
    this.minDue,
    this.dueDate,
    this.bankName,
    this.cardLast4,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'smsId': smsId,
        'sender': sender,
        'rawBody': rawBody,
        'totalDue': totalDue,
        'minDue': minDue,
        'dueDate': dueDate?.toIso8601String(),
        'bankName': bankName,
        'cardLast4': cardLast4,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Intelligent parser for financial SMS messages from banks, UPI apps, and cards
class SmsParserEngine {
  static final RegExp _otpPattern = RegExp(
    r'\b(otp|one time password|verification code|security code|login code|secret code|do not share|is your verification|is your secret|authorization code)\b',
    caseSensitive: false,
  );

  static final RegExp _amountPattern1 = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _amountPattern2 = RegExp(
    r'(?:debited|credited|spent|paid|withdrawn|transferred|txn of|transfer of|sent)\s+(?:by|for|of|with|amount of)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _amountPattern3 = RegExp(
    r'([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr|₹)',
    caseSensitive: false,
  );

  static final RegExp _avlBalancePattern = RegExp(
    r'(?:avl\s*bal|avail(?:able)?\s*bal(?:ance)?|bal(?:ance)?\s*is|bal\s*[:\-])\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _accountLast4Pattern = RegExp(
    r'(?:a/c|ac|account|acct|card|ending with|ending in|ending)\s*(?:no\.?)?\s*[:\s]*[*xX]*([0-9]{3,4})',
    caseSensitive: false,
  );

  static final RegExp _maskedAccountPattern = RegExp(
    r'[*xX]{2,}([0-9]{3,4})',
  );

  static final RegExp _refNumberPattern = RegExp(
    r'(?:ref(?:\s*no)?|utr(?:\s*no)?|txn\s*id|reference\s*no|upi\s*ref(?:\s*no)?)\s*[:\s-]*([A-Za-z0-9]+)',
    caseSensitive: false,
  );

  static final List<String> _expenseKeywords = [
    'debited',
    'debited by',
    'spent',
    'paid',
    'transferred to',
    'sent to',
    'sent rs',
    'purchase of',
    'purchase at',
    'txn of',
    'withdrawn',
    'deducted',
    'used for a transaction',
    'payment of',
  ];

  static final List<String> _incomeKeywords = [
    'credited',
    'credited to',
    'credited with',
    'received',
    'deposited',
    'refund',
    'refunded',
    'cashback',
    'added to your',
    'reversal',
  ];

  /// Parses an SMS message and returns a [ParsedSmsTransaction] or null if not a transaction
  static ParsedSmsTransaction? parse({
    required String id,
    required String sender,
    required String body,
    DateTime? timestamp,
  }) {
    final cleanBody = body.trim();
    if (cleanBody.isEmpty) return null;

    // 1. Filter out OTPs and Non-transactional messages
    if (_isOtpOrSpam(cleanBody)) {
      return null;
    }

    // 2. Extract Amount
    final amount = _extractAmount(cleanBody);
    if (amount == null || amount <= 0) {
      return null;
    }

    // 3. Determine Transaction Type (Expense vs Income)
    final type = _determineType(cleanBody);
    if (type == null) {
      return null;
    }

    // 4. Determine Payment Mode (UPI, Credit Card, Debit Card, Net Banking)
    final paymentMode = _extractPaymentMode(cleanBody, sender);

    // 5. Extract Bank Name
    final bankName = _extractBankName(sender, cleanBody);

    // 6. Extract Account / Card Last 4 digits
    final accountLast4 = _extractAccountLast4(cleanBody);

    // 7. Extract Merchant / Beneficiary / Payee
    final merchant = _extractMerchant(cleanBody, type);

    // 8. Extract Reference / UTR Number
    final refNumber = _extractRefNumber(cleanBody);

    // 9. Extract Available Balance
    final balance = _extractBalance(cleanBody);

    return ParsedSmsTransaction(
      smsId: id.isNotEmpty ? id : _generateHash(sender, cleanBody, timestamp),
      sender: sender,
      rawBody: cleanBody,
      amount: amount,
      type: type,
      paymentMode: paymentMode,
      bankName: bankName,
      accountNumberLast4: accountLast4,
      merchant: merchant,
      refNumber: refNumber,
      balance: balance,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  static bool _isOtpOrSpam(String body) {
    // If it contains OTP keywords and does NOT clearly state a successful completed transaction
    if (_otpPattern.hasMatch(body)) {
      final isCompletedTxn = body.toLowerCase().contains('has been debited') ||
          body.toLowerCase().contains('has been credited') ||
          body.toLowerCase().contains('was spent on') ||
          body.toLowerCase().contains('successfully paid');
      if (!isCompletedTxn) return true;
    }
    return false;
  }

  static double? _extractAmount(String body) {
    // Check amount pattern 1 (Rs. 500, INR 1,200)
    var match = _amountPattern1.firstMatch(body);
    if (match != null && match.group(1) != null) {
      final str = match.group(1)!.replaceAll(',', '');
      final val = double.tryParse(str);
      if (val != null && val > 0 && val < 100000000) return val;
    }

    // Check amount pattern 2 (debited by 500)
    match = _amountPattern2.firstMatch(body);
    if (match != null && match.group(1) != null) {
      final str = match.group(1)!.replaceAll(',', '');
      final val = double.tryParse(str);
      if (val != null && val > 0 && val < 100000000) return val;
    }

    // Check amount pattern 3 (500 Rs)
    match = _amountPattern3.firstMatch(body);
    if (match != null && match.group(1) != null) {
      final str = match.group(1)!.replaceAll(',', '');
      final val = double.tryParse(str);
      if (val != null && val > 0 && val < 100000000) return val;
    }

    return null;
  }

  static String? _determineType(String body) {
    final lower = body.toLowerCase();

    int firstExpenseIndex = 999999;
    for (final kw in _expenseKeywords) {
      final idx = lower.indexOf(kw);
      if (idx != -1 && idx < firstExpenseIndex) {
        firstExpenseIndex = idx;
      }
    }

    int firstIncomeIndex = 999999;
    for (final kw in _incomeKeywords) {
      final idx = lower.indexOf(kw);
      if (idx != -1 && idx < firstIncomeIndex) {
        firstIncomeIndex = idx;
      }
    }

    if (firstExpenseIndex == 999999 && firstIncomeIndex == 999999) {
      return null;
    }

    // Return the keyword type that appeared earlier or more prominent
    if (firstExpenseIndex <= firstIncomeIndex) {
      return 'expense';
    } else {
      return 'income';
    }
  }

  static String _extractPaymentMode(String body, String sender) {
    final lower = body.toLowerCase();
    final lowerSender = sender.toLowerCase();

    if (lower.contains('upi') ||
        lower.contains('vpa') ||
        lower.contains('gpay') ||
        lower.contains('phonepe') ||
        lower.contains('paytm upi') ||
        lower.contains('@ok') ||
        lower.contains('@ybl') ||
        lower.contains('@okhdfcbank') ||
        lower.contains('@oksbi') ||
        lower.contains('@okaxis') ||
        lower.contains('@okicici') ||
        lowerSender.contains('upipay') ||
        lowerSender.contains('sbipay')) {
      return 'UPI';
    }

    if (lower.contains('credit card') ||
        lower.contains('card ending') ||
        lower.contains('spent on your card') ||
        lowerSender.contains('hdfccc') ||
        lowerSender.contains('icicic') ||
        lowerSender.contains('sbicrd')) {
      return 'Credit Card';
    }

    if (lower.contains('debit card') ||
        lower.contains('dc ending') ||
        lower.contains('atm') ||
        lower.contains('pos txn') ||
        lower.contains('card ending in')) {
      return 'Debit Card';
    }

    if (lower.contains('netbanking') ||
        lower.contains('net banking') ||
        lower.contains('neft') ||
        lower.contains('rtgs') ||
        lower.contains('imps') ||
        lower.contains('internet banking') ||
        lower.contains('transfer to')) {
      return 'Net Banking';
    }

    return 'UPI';
  }

  static String? _extractBankName(String sender, String body) {
    final s = sender.toUpperCase();
    final b = body.toUpperCase();

    if (s.contains('HDFC') || b.contains('HDFC BANK') || b.contains('HDFC')) {
      return 'HDFC Bank';
    }
    if (s.contains('SBI') || b.contains('STATE BANK OF INDIA') || b.contains('SBI')) {
      return 'State Bank of India';
    }
    if (s.contains('ICICI') || b.contains('ICICI BANK') || b.contains('ICICI')) {
      return 'ICICI Bank';
    }
    if (s.contains('AXIS') || b.contains('AXIS BANK') || b.contains('AXIS')) {
      return 'Axis Bank';
    }
    if (s.contains('KOTAK') || b.contains('KOTAK MAHINDRA') || b.contains('KOTAK')) {
      return 'Kotak Mahindra Bank';
    }
    if (s.contains('PNB') || b.contains('PUNJAB NATIONAL BANK') || b.contains('PNB')) {
      return 'Punjab National Bank';
    }
    if (s.contains('BOB') || b.contains('BANK OF BARODA') || b.contains('BOB')) {
      return 'Bank of Baroda';
    }
    if (s.contains('CAN') || b.contains('CANARA BANK') || b.contains('CANARA')) {
      return 'Canara Bank';
    }
    if (s.contains('INDUS') || b.contains('INDUSIND BANK') || b.contains('INDUSIND')) {
      return 'IndusInd Bank';
    }
    if (s.contains('YES') || b.contains('YES BANK')) {
      return 'Yes Bank';
    }
    if (s.contains('IDFC') || b.contains('IDFC FIRST BANK') || b.contains('IDFC')) {
      return 'IDFC FIRST Bank';
    }
    if (s.contains('PAYTM') || b.contains('PAYTM PAYMENTS BANK') || b.contains('PAYTM')) {
      return 'Paytm Payments Bank';
    }
    if (s.contains('FED') || b.contains('FEDERAL BANK')) {
      return 'Federal Bank';
    }
    if (s.contains('AU') || b.contains('AU SMALL FINANCE BANK')) {
      return 'AU Small Finance Bank';
    }
    if (s.contains('CITI') || b.contains('CITIBANK')) {
      return 'Citibank';
    }
    if (s.contains('AMEX') || b.contains('AMERICAN EXPRESS')) {
      return 'American Express';
    }

    return null;
  }

  static String? _extractAccountLast4(String body) {
    var match = _accountLast4Pattern.firstMatch(body);
    if (match != null && match.group(1) != null) {
      return match.group(1);
    }

    match = _maskedAccountPattern.firstMatch(body);
    if (match != null && match.group(1) != null) {
      return match.group(1);
    }

    return null;
  }

  static String? _extractMerchant(String body, String type) {
    // Common patterns: "at SWIGGY", "to ZOMATO", "info: BIL/UBER", "towards NETFLIX", "from JOHN"
    final regexes = [
      RegExp(r'(?:at|towards)\s+([A-Za-z0-9\s*._&/-]{2,35}?)(?:\s+(?:on|via|ref|upi|avl|bal|avail|using|date|is|\.|$))', caseSensitive: false),
      RegExp(r'(?:to|transferred to|sent to|paid to)\s+([A-Za-z0-9\s*._&/-]{2,35}?)(?:\s+(?:on|via|ref|upi|avl|bal|avail|using|date|is|\.|$))', caseSensitive: false),
      RegExp(r'info\s*[:\s-]+\s*([A-Za-z0-9\s*._&/-]{2,35}?)(?:\s+(?:on|via|ref|upi|avl|bal|avail|using|date|is|\.|$))', caseSensitive: false),
      RegExp(r'(?:from|transfer from)\s+([A-Za-z0-9\s*._&/-]{2,35}?)(?:\s+(?:on|via|ref|upi|avl|bal|avail|using|date|is|\.|$))', caseSensitive: false),
    ];

    for (final reg in regexes) {
      final match = reg.firstMatch(body);
      if (match != null && match.group(1) != null) {
        var name = match.group(1)!.trim();
        name = _cleanMerchantName(name);
        if (name.isNotEmpty && name.length >= 2) {
          return name;
        }
      }
    }

    return null;
  }

  static String _cleanMerchantName(String raw) {
    var clean = raw;
    // Strip common banking technical prefixes
    clean = clean.replaceAll(RegExp(r'^(bil/|onl/|ecom/|upi/|pos/|vpa/|pay/|in\*)', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    clean = clean.replaceAll(RegExp(r'[^\w\s@.&-]'), '').trim();

    // Clean trailing keywords
    final stopwords = ['via', 'on', 'ref', 'using', 'account', 'bank', 'avl', 'bal', 'upi'];
    final words = clean.split(' ');
    final filtered = words.where((w) => !stopwords.contains(w.toLowerCase())).toList();

    clean = filtered.join(' ').trim();
    if (clean.length > 30) {
      clean = clean.substring(0, 30).trim();
    }

    // Format title case if all caps
    if (clean.length > 2 && clean == clean.toUpperCase()) {
      clean = clean.split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : '');
      }).join(' ');
    }

    return clean;
  }

  static String? _extractRefNumber(String body) {
    final match = _refNumberPattern.firstMatch(body);
    if (match != null && match.group(1) != null) {
      return match.group(1);
    }
    return null;
  }

  static double? _extractBalance(String body) {
    final match = _avlBalancePattern.firstMatch(body);
    if (match != null && match.group(1) != null) {
      final str = match.group(1)!.replaceAll(',', '');
      return double.tryParse(str);
    }
    return null;
  }

  static String _generateHash(String sender, String body, DateTime? timestamp) {
    final ts = timestamp?.millisecondsSinceEpoch ?? 0;
    return '${sender}_${body.hashCode}_$ts';
  }

  static final RegExp _totalDuePattern = RegExp(
    r'(?:total\s*(?:amt\s*)?due|total\s*due\s*(?:is|:)?|due\s*amt|amount\s*due|statement\s*amount)\s*[:\s-]*\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _minDuePattern = RegExp(
    r'(?:min(?:imum)?\s*(?:amt\s*)?due|min\s*due\s*(?:is|:)?)\s*[:\s-]*\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _dueDatePattern = RegExp(
    r'(?:due\s*date|pay\s*by|before|payment\s*due\s*date)\s*(?:is|:)?\s*(\d{1,2}[-/\.](?:[A-Za-z]{3}|\d{1,2})[-/\.]\d{2,4})',
    caseSensitive: false,
  );

  static DateTime? _parseDueDate(String raw) {
    try {
      final clean = raw.trim();
      final parts = clean.split(RegExp(r'[-/\.]'));
      if (parts.length != 3) return null;

      final day = int.tryParse(parts[0]);
      if (day == null || day < 1 || day > 31) return null;

      int? month;
      final mStr = parts[1].toLowerCase();
      const monthNames = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
      };
      if (monthNames.containsKey(mStr)) {
        month = monthNames[mStr];
      } else {
        month = int.tryParse(parts[1]);
      }
      if (month == null || month < 1 || month > 12) return null;

      int? year = int.tryParse(parts[2]);
      if (year == null) return null;
      if (year < 100) year += 2000;

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// Parses an SMS message for credit card bill statement details
  static ParsedSmsBillStatement? parseBillStatement({
    required String id,
    required String sender,
    required String body,
    DateTime? timestamp,
  }) {
    final cleanBody = body.trim();
    if (cleanBody.isEmpty) return null;
    if (_isOtpOrSpam(cleanBody)) return null;

    final lower = cleanBody.toLowerCase();
    final hasStatementKeywords = lower.contains('statement') ||
        lower.contains('total due') ||
        lower.contains('total amt due') ||
        lower.contains('bill generated') ||
        (lower.contains('amt due') && lower.contains('due date'));

    if (!hasStatementKeywords) return null;

    // 1. Extract total due
    double? totalDue;
    final totalMatch = _totalDuePattern.firstMatch(cleanBody);
    if (totalMatch != null && totalMatch.group(1) != null) {
      final str = totalMatch.group(1)!.replaceAll(',', '');
      totalDue = double.tryParse(str);
    }
    totalDue ??= _extractAmount(cleanBody);
    if (totalDue == null || totalDue <= 0) return null;

    // 2. Extract min due
    double? minDue;
    final minMatch = _minDuePattern.firstMatch(cleanBody);
    if (minMatch != null && minMatch.group(1) != null) {
      final str = minMatch.group(1)!.replaceAll(',', '');
      minDue = double.tryParse(str);
    }

    // 3. Extract due date
    DateTime? dueDate;
    final dueMatch = _dueDatePattern.firstMatch(cleanBody);
    if (dueMatch != null && dueMatch.group(1) != null) {
      dueDate = _parseDueDate(dueMatch.group(1)!);
    }

    // 4. Extract Card Last 4 & Bank Name
    final cardLast4 = _extractAccountLast4(cleanBody);
    final bankName = _extractBankName(sender, cleanBody);

    return ParsedSmsBillStatement(
      smsId: id.isNotEmpty ? id : _generateHash(sender, cleanBody, timestamp),
      sender: sender,
      rawBody: cleanBody,
      totalDue: totalDue,
      minDue: minDue,
      dueDate: dueDate,
      bankName: bankName,
      cardLast4: cardLast4,
      timestamp: timestamp ?? DateTime.now(),
    );
  }
}
