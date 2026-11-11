import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/market_localization.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../loan_workspace/loan_workspace_text.dart';
import '../models/loan_estimate.dart';

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({required this.market, super.key});

  static const brandPurple = Color(0xFF461091);
  static const brandFuchsia = Color(0xFFF020BD);
  static const brandGradient = LinearGradient(
    colors: [brandPurple, brandFuchsia],
  );

  final MarketOption market;

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  late double _amount = widget.market.country == 'RU'
      ? 1691000
      : widget.market.initialAmount;
  int _months = 12;
  int _rate = 60;
  bool _showSchedule = false;

  String _text(LoanText text) => text.inMarket(widget.market);
  String _money(num amount) => formatMarketAmount(amount, widget.market);
  String _detailMoney(num amount) =>
      '${NumberFormat.decimalPatternDigits(locale: _numberLocale, decimalDigits: 2).format(amount)} ${widget.market.currency}';
  String get _numberLocale =>
      widget.market.locale == 'fil' ? 'en' : widget.market.locale;

  @override
  Widget build(BuildContext context) {
    final market = widget.market;
    final maxAmount = market.country == 'RU' ? 2000000.0 : market.maxAmount;
    final estimate = LoanEstimate(
      principal: _amount,
      months: _months,
      annualRate: _rate.toDouble(),
    );
    final theme = Theme.of(context);
    final sliderColor = theme.brightness == Brightness.dark
        ? LoanCalculatorScreen.brandFuchsia
        : LoanCalculatorScreen.brandPurple;
    final amountLabel = _money(_amount);
    final termLabel = '$_months ${_text(LoanText.months)}';
    final rateLabel = '$_rate%';
    final percent = NumberFormat.decimalPatternDigits(
      locale: _numberLocale,
      decimalDigits: 1,
    ).format(estimate.interestPercent);

    return Column(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LoanCalculatorScreen.brandGradient,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text(LoanText.title),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _text(LoanText.subtitle),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      market.currencyCode,
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.black26,
                    side: BorderSide.none,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  children: [
                    _control(
                      label: marketText(market.locale, 'amount'),
                      valueLabel: amountLabel,
                      semanticValue: _money,
                      value: _amount,
                      min: market.minAmount,
                      max: maxAmount,
                      divisions:
                          ((maxAmount - market.minAmount) / market.amountStep)
                              .round(),
                      color: sliderColor,
                      onChanged: (value) => setState(() => _amount = value),
                    ),
                    _control(
                      label: _text(LoanText.term),
                      valueLabel: termLabel,
                      semanticValue: (value) =>
                          '${value.round()} ${_text(LoanText.months)}',
                      value: _months.toDouble(),
                      min: 1,
                      max: 72,
                      divisions: 71,
                      color: sliderColor,
                      onChanged: (value) =>
                          setState(() => _months = value.round()),
                    ),
                    _control(
                      label: _text(LoanText.rate),
                      valueLabel: rateLabel,
                      semanticValue: (value) => '${value.round()}%',
                      value: _rate.toDouble(),
                      min: 0,
                      max: 120,
                      divisions: 120,
                      color: sliderColor,
                      onChanged: (value) =>
                          setState(() => _rate = value.round()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LoanCalculatorScreen.brandGradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    Text(
                      _text(LoanText.payment),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _money(estimate.monthlyPayment),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(
                      _text(LoanText.principal),
                      _money(estimate.principal),
                    ),
                    _line(_text(LoanText.interest), _money(estimate.interest)),
                    _line(
                      _text(LoanText.total),
                      _money(estimate.total),
                      bold: true,
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (estimate.interestPercent / 100)
                            .clamp(0.0, 1.0)
                            .toDouble(),
                        color: sliderColor,
                        backgroundColor: sliderColor.withValues(alpha: .16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('$percent% ${_text(LoanText.percentOfPrincipal)}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  initiallyExpanded: _showSchedule,
                  onExpansionChanged: (value) =>
                      setState(() => _showSchedule = value),
                  title: Text(_text(LoanText.schedule)),
                  children: [
                    if (_showSchedule)
                      for (final payment in estimate.schedule)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 12),
                              _line(
                                '${_text(LoanText.month)} ${payment.month}',
                                _detailMoney(payment.amount),
                                bold: true,
                              ),
                              Text(
                                '${_text(LoanText.principal)}: ${_detailMoney(payment.principal)}',
                              ),
                              Text(
                                '${_text(LoanText.interest)}: ${_detailMoney(payment.interest)}',
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(_text(LoanText.notice), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _control({
    required String label,
    required String valueLabel,
    required String Function(double) semanticValue,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Color color,
    required ValueChanged<double> onChanged,
  }) => Column(
    children: [
      _line(label, valueLabel, bold: true),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 8,
          inactiveTrackColor: color.withValues(alpha: .15),
          tickMarkShape: SliderTickMarkShape.noTickMark,
        ),
        child: Semantics(
          label: label,
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: color,
            thumbColor: color,
            label: valueLabel,
            semanticFormatterCallback: semanticValue,
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );

  Widget _line(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
