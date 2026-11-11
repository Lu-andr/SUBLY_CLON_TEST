import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/market_localization.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/providers/app_state.dart';
import '../calculator/screens/loan_calculator_screen.dart';
import '../partners/screens/partners_screen.dart';
import 'loan_workspace_text.dart';

class LoanWorkspace extends StatefulWidget {
  const LoanWorkspace({required this.state, super.key});

  final AppState state;

  @override
  State<LoanWorkspace> createState() => _LoanWorkspaceState();
}

class _LoanWorkspaceState extends State<LoanWorkspace> {
  int _index = 1;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) {
      final market = marketFor(widget.state.geoTarget.country);
      final theme = Theme.of(context);
      final accent = theme.brightness == Brightness.dark
          ? LoanCalculatorScreen.brandFuchsia
          : LoanCalculatorScreen.brandPurple;
      final pages = [
        LoanCalculatorScreen(key: ValueKey(market.country), market: market),
        PartnersScreen(state: widget.state),
        _LoanSettings(state: widget.state, market: market),
      ];
      return Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (final (index, page) in pages.indexed)
              TickerMode(enabled: _index == index, child: page),
          ],
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: theme.navigationBarTheme.copyWith(
            indicatorColor: accent.withValues(alpha: .15),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontSize: 11,
                color: states.contains(WidgetState.selected)
                    ? accent
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? accent
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) {
              HapticFeedback.selectionClick();
              setState(() => _index = index);
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.calculate_outlined),
                selectedIcon: const Icon(Icons.calculate_rounded),
                label: LoanText.calculator.inMarket(market),
              ),
              NavigationDestination(
                icon: const Icon(Icons.local_offer_outlined),
                selectedIcon: const Icon(Icons.local_offer_rounded),
                label: LoanText.offers.inMarket(market),
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: LoanText.settings.inMarket(market),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _LoanSettings extends StatelessWidget {
  const _LoanSettings({required this.state, required this.market});

  final AppState state;
  final MarketOption market;

  static final _privacyPolicy = Uri.https(
    'cashadvance.agency',
    '/privacy.html',
  );
  static final _terms = Uri.https('cashadvance.agency', '/terms.html');

  Future<void> _openLegalPage(BuildContext context, Uri url) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } on PlatformException {
      // The device could not open the URL in an external app.
    } on MissingPluginException {
      // No URL launcher is available on this platform.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to open this page.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String text(LoanText label) => label.inMarket(market);
    final modes = {
      'system': text(LoanText.system),
      'light': text(LoanText.light),
      'dark': text(LoanText.dark),
    };
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            text(LoanText.settings),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(text(LoanText.language)),
                  subtitle: Text('${market.flag} ${market.label}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final selected = await showModalBottomSheet<MarketOption>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (context) => SafeArea(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * .75,
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final option in supportedMarkets)
                                ListTile(
                                  leading: Text(option.flag),
                                  title: Text(option.label),
                                  selected: option.country == market.country,
                                  onTap: () => Navigator.pop(context, option),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                    if (context.mounted &&
                        selected != null &&
                        selected.country != market.country) {
                      await state.selectMarket(
                        country: selected.country,
                        locale: selected.locale,
                      );
                    }
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: Text(text(LoanText.theme)),
                  subtitle: Text(
                    modes[state.settings.themeMode] ?? modes['system']!,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final selected = await showDialog<String>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: Text(text(LoanText.theme)),
                        children: [
                          for (final entry in modes.entries)
                            SimpleDialogOption(
                              onPressed: () =>
                                  Navigator.pop(context, entry.key),
                              child: Text(entry.value),
                            ),
                        ],
                      ),
                    );
                    if (context.mounted && selected != null) {
                      await state.updateSettings(
                        state.settings.copyWith(themeMode: selected),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => _openLegalPage(context, _privacyPolicy),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms & Conditions'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => _openLegalPage(context, _terms),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
