import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/features/sms/services/sms_parser_engine.dart';

void main() {
  group('SmsParserEngine Tests', () {
    test('Parses HDFC Bank UPI Debit SMS correctly', () {
      const body =
          'Dear Customer, INR 450.00 has been debited from your A/c ending 1234 on 15-AUG-26 at SWIGGY via UPI. Avl Bal: INR 24,550.00. Ref: 423456789012';
      const sender = 'VM-HDFCBK';

      final result = SmsParserEngine.parse(
        id: 'msg_1',
        sender: sender,
        body: body,
      );

      expect(result, isNotNull);
      expect(result!.amount, 450.0);
      expect(result.type, 'expense');
      expect(result.paymentMode, 'UPI');
      expect(result.bankName, 'HDFC Bank');
      expect(result.accountNumberLast4, '1234');
      expect(result.merchant?.toLowerCase(), contains('swiggy'));
      expect(result.refNumber, '423456789012');
      expect(result.balance, 24550.0);
    });

    test('Parses SBI Salary Credit SMS correctly', () {
      const body =
          'Dear Customer, your A/c 5678 has been credited by Rs. 65,000.00 on 01-AUG-26 by Salary/NEFT from ACME TECH. Avail Bal: Rs. 75,000.00 - SBI';
      const sender = 'AD-SBISMS';

      final result = SmsParserEngine.parse(
        id: 'msg_2',
        sender: sender,
        body: body,
      );

      expect(result, isNotNull);
      expect(result!.amount, 65000.0);
      expect(result.type, 'income');
      expect(result.bankName, 'State Bank of India');
      expect(result.accountNumberLast4, '5678');
      expect(result.balance, 75000.0);
    });

    test('Parses ICICI Credit Card Transaction SMS correctly', () {
      const body =
          'Dear Customer, your ICICI Bank Credit Card ending 4001 has been used for a transaction of INR 3,499.00 at AMAZON on 10-AUG-26. Info: BIL*AMAZON. Avail Limit: INR 85,000.00.';
      const sender = 'VK-ICICIB';

      final result = SmsParserEngine.parse(
        id: 'msg_3',
        sender: sender,
        body: body,
      );

      expect(result, isNotNull);
      expect(result!.amount, 3499.0);
      expect(result.type, 'expense');
      expect(result.paymentMode, 'Credit Card');
      expect(result.bankName, 'ICICI Bank');
      expect(result.accountNumberLast4, '4001');
      expect(result.merchant?.toLowerCase(), contains('amazon'));
    });

    test('Parses Axis Bank UPI Uber Ride SMS correctly', () {
      const body =
          'INR 320.00 debited from A/C no. XX3456 on 14-08-26 at UBER via UPI Ref 498765432101. Avail bal INR 11,680.00 - Axis Bank';
      const sender = 'AX-AXISBK';

      final result = SmsParserEngine.parse(
        id: 'msg_4',
        sender: sender,
        body: body,
      );

      expect(result, isNotNull);
      expect(result!.amount, 320.0);
      expect(result.type, 'expense');
      expect(result.paymentMode, 'UPI');
      expect(result.bankName, 'Axis Bank');
      expect(result.accountNumberLast4, '3456');
      expect(result.merchant?.toLowerCase(), contains('uber'));
    });

    test('Parses Paytm UPI payment SMS correctly', () {
      const body =
          'Paid Rs. 120 to Chai Point on 14 Aug 2026 using Paytm UPI from Bank A/c ending 1234. UPI Ref: 41238910';
      const sender = 'PAYTMB';

      final result = SmsParserEngine.parse(
        id: 'msg_5',
        sender: sender,
        body: body,
      );

      expect(result, isNotNull);
      expect(result!.amount, 120.0);
      expect(result.type, 'expense');
      expect(result.paymentMode, 'UPI');
      expect(result.accountNumberLast4, '1234');
      expect(result.merchant?.toLowerCase(), contains('chai point'));
    });

    test('Filters out OTP messages', () {
      const body =
          'Your OTP for transaction of Rs 1,500.00 at Swiggy is 492810. Do not share your OTP with anyone.';
      const sender = 'VM-HDFCBK';

      final result = SmsParserEngine.parse(
        id: 'otp_msg',
        sender: sender,
        body: body,
      );

      expect(result, isNull);
    });

    test('Filters out login verification codes', () {
      const body =
          '829103 is your verification code for Quantro. Valid for 10 minutes.';
      const sender = 'BW-QUANTRO';

      final result = SmsParserEngine.parse(
        id: 'login_msg',
        sender: sender,
        body: body,
      );

      expect(result, isNull);
    });

    test('Parses HDFC Credit Card statement SMS correctly', () {
      const body =
          'Statement for HDFC Bank Credit Card ending 1234 for Feb 2026. Total Amt Due: Rs 24,500.00, Min Amt Due: Rs 1,225.00, Due Date: 15-Mar-2026.';
      const sender = 'VM-HDFCBK';

      final result = SmsParserEngine.parseBillStatement(
        id: 'stmt_1',
        sender: sender,
        body: body,
      );

      expect(result, isNotNull);
      expect(result!.totalDue, 24500.0);
      expect(result.minDue, 1225.0);
      expect(result.cardLast4, '1234');
      expect(result.bankName, 'HDFC Bank');
      expect(result.dueDate, DateTime(2026, 3, 15));
    });

    test('Parses ICICI Credit Card statement SMS correctly', () {
      const body =
          'Dear Customer, ICICI Bank Credit Card XX4001 statement generated. Total Due: INR 12,300.00, Min Due: INR 650.00, Pay by 10-Mar-26.';
      const sender = 'VK-ICICIB';

      final result = SmsParserEngine.parseBillStatement(
        id: 'stmt_2',
        sender: sender,
        body: body,
      );

      expect(result, isNotNull);
      expect(result!.totalDue, 12300.0);
      expect(result.minDue, 650.0);
      expect(result.cardLast4, '4001');
      expect(result.bankName, 'ICICI Bank');
      expect(result.dueDate, DateTime(2026, 3, 10));
    });

    test('Parses SBI Card statement SMS correctly', () {
      const body =
          'SBI Card ending 5678: Total Amt Due is Rs. 18,900.00, Min Amt Due Rs. 950.00. Payment due date 22/03/2026.';
      const sender = 'AD-SBISMS';

      final result = SmsParserEngine.parseBillStatement(
        id: 'stmt_3',
        sender: sender,
        body: body,
      );

      expect(result, isNotNull);
      expect(result!.totalDue, 18900.0);
      expect(result.minDue, 950.0);
      expect(result.cardLast4, '5678');
      expect(result.bankName, 'State Bank of India');
      expect(result.dueDate, DateTime(2026, 3, 22));
    });
  });
}
