part of 'finance_screen.dart';

const _financeAmountStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w700,
  height: 1.25,
);

ThemeData _financeTheme(ThemeData theme) {
  final dark = theme.brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: LoanCalculatorScreen.brandPurple,
        brightness: theme.brightness,
      ).copyWith(
        primary: dark
            ? const Color(0xFFE7B5FF)
            : LoanCalculatorScreen.brandPurple,
        onPrimary: dark ? const Color(0xFF340B61) : Colors.white,
      );
  return theme.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurface,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      ),
    ),
    appBarTheme: theme.appBarTheme.copyWith(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: theme.cardTheme.copyWith(
      color: dark ? scheme.surfaceContainerLow : Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
    ),
  );
}

class _FinanceRow extends StatelessWidget {
  const _FinanceRow({
    required this.title,
    this.details,
    this.amount,
    this.icon,
    this.progress,
    this.onTap,
  });

  final String title;
  final String? details, amount;
  final IconData? icon;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(17) / 17;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  amount != null && constraints.maxWidth < 275 * textScale;
              final labels = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _financeAmountStyle.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  if (details case final description?) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              );
              final value = amount == null
                  ? null
                  : Text(
                      amount!,
                      textAlign: TextAlign.end,
                      style: _financeAmountStyle.copyWith(
                        color: scheme.onSurface,
                      ),
                    );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (icon case final symbol?) ...[
                        Icon(symbol, size: 20, color: scheme.primary),
                        const SizedBox(width: 10),
                      ],
                      Expanded(flex: 3, child: labels),
                      if (!stacked && value != null) ...[
                        const SizedBox(width: 12),
                        Flexible(flex: 2, child: value),
                      ],
                      if (value == null && onTap != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                  if (stacked) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: value!,
                    ),
                  ],
                  if (progress case final fraction?) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: fraction,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
