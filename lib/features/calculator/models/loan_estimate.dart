import 'dart:math' as math;

class LoanEstimate {
  LoanEstimate({
    required this.principal,
    required this.months,
    required this.annualRate,
  }) : assert(principal > 0),
       assert(months > 0),
       assert(annualRate >= 0);

  final double principal;
  final int months;
  final double annualRate;

  double get _monthlyRate => annualRate / 1200;

  late final double monthlyPayment = _monthlyRate == 0
      ? principal / months
      : principal * _monthlyRate / (1 - math.pow(1 + _monthlyRate, -months));

  double get total => monthlyPayment * months;
  double get interest => _monthlyRate == 0 ? 0 : total - principal;
  double get interestPercent => interest / principal * 100;

  Iterable<LoanPayment> get schedule sync* {
    var balance = principal;
    for (var month = 1; month <= months; month++) {
      final interest = balance * _monthlyRate;
      final principalPaid = month == months
          ? balance
          : monthlyPayment - interest;
      balance -= principalPaid;
      yield LoanPayment(
        month: month,
        principal: principalPaid,
        interest: interest,
        remaining: balance,
      );
    }
  }
}

class LoanPayment {
  const LoanPayment({
    required this.month,
    required this.principal,
    required this.interest,
    required this.remaining,
  });

  final int month;
  final double principal;
  final double interest;
  final double remaining;

  double get amount => principal + interest;
}
