import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/animations/app_animations.dart';
import '../../../core/localization/market_localization.dart';
import '../../../core/services/attribution_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/partner_offer.dart';
import '../../../data/providers/app_state.dart';
import 'partner_webview_screen.dart';

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({required this.state, super.key});
  final AppState state;

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  late String market;

  @override
  void initState() {
    super.initState();
    market =
        const {
          'RU': 'RU',
          'AR': 'AR',
          'UZ': 'UZ',
          'MX': 'MX',
          'KZ': 'KZ',
          'VN': 'VN',
        }[widget.state.geoTarget.country] ??
        'RU';
  }

  Future<void> _openOffer(PartnerOffer offer) async {
    final base = Uri.tryParse(offer.url);
    if (base == null) return;
    final target = await AttributionService.decorate(base);
    if (!mounted) return;
    if (offer.openMode == OfferOpenMode.webview) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PartnerWebViewScreen(
            title: offer.providerName,
            initialUrl: target,
          ),
        ),
      );
      return;
    }
    var opened = false;
    try {
      opened = await launchUrl(target, mode: LaunchMode.externalApplication);
      if (!opened) {
        opened = await launchUrl(target, mode: LaunchMode.inAppBrowserView);
      }
    } on PlatformException {
      opened = false;
    } on MissingPluginException {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть предложение')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.zero,
    children: [
      Container(
        height: MediaQuery.paddingOf(context).top + 245,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2D9B4D), Color(0xFF176F42)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/banners/offers-eco-shield-v1.png',
                package: 'subly',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/banners/offers-eco-shield-v1.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xD6052D19), Color(0x00052D19)],
                    stops: [0, .70],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.paddingOf(context).top + 18,
                24,
                26,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: _OfferMarketMenu(
                      value: market,
                      onChanged: (value) {
                        final option = marketFor(value);
                        setState(() => market = value);
                        widget.state.selectMarket(
                          country: option.country,
                          locale: option.locale,
                        );
                      },
                    ),
                  ),
                  const Spacer(),
                  Text(
                    marketText(marketFor(market).locale, 'offers'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    marketText(marketFor(market).locale, 'offerSubtitle'),
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: SublyColors.green.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: SublyColors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(marketText(marketFor(market).locale, 'social')),
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Text(
          '${marketText(marketFor(market).locale, 'available')} · ${widget.state.offers.length}',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
      if (!widget.state.offersLoaded)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (widget.state.offers.isEmpty)
        _OffersError(locale: marketFor(market).locale)
      else
        ...widget.state.offers.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: FadeSlideIn(
              delay: AppAnimations.stagger * entry.key,
              child: _OfferCard(
                offer: entry.value,
                locale: marketFor(market).locale,
                onOpen: () => _openOffer(entry.value),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _PartnerDetailScreen(
                      offer: entry.value,
                      locale: marketFor(market).locale,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SublyColors.orange.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(marketText(marketFor(market).locale, 'disclaimer')),
        ),
      ),
    ],
  );
}

class _OffersError extends StatelessWidget {
  const _OffersError({required this.locale});
  final String locale;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 64),
    child: Column(
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 54,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          marketText(locale, 'unavailable'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(marketText(locale, 'tryLater'), textAlign: TextAlign.center),
      ],
    ),
  );
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.locale,
    required this.onTap,
    required this.onOpen,
  });
  final PartnerOffer offer;
  final String locale;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => AppCard(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _OfferLogo(offer: offer),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.providerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (offer.rating > 0)
                      Text('★ ${offer.rating.toStringAsFixed(1)}'),
                  ],
                ),
              ),
              if (offer.isFeatured)
                const Icon(Icons.verified_rounded, color: SublyColors.purple),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
          if (offer.parameters.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: offer.parameters.entries
                  .take(3)
                  .map(
                    (entry) => _Fact(
                      label: switch (entry.key) {
                        'amount' => marketText(locale, 'amountFact'),
                        'processingTime' => marketText(locale, 'timeFact'),
                        'interestRate' => marketText(locale, 'rateFact'),
                        _ => entry.key,
                      },
                      value: entry.value,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 18),
          Material(
            color: SublyColors.green,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 52,
                child: Center(
                  child: Text(
                    offer.ctaText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OfferMarketMenu extends StatelessWidget {
  const _OfferMarketMenu({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = marketFor(value);
    return InkWell(
      onTap: () => _showOfferMarketSheet(context, value, onChanged),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: Color(0x220B2E18), blurRadius: 14),
          ],
        ),
        child: Text(
          '${selected.flag} ${selected.country} ▾',
          style: const TextStyle(
            color: Color(0xFF203027),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

Future<void> _showOfferMarketSheet(
  BuildContext context,
  String current,
  ValueChanged<String> onChanged,
) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (sheetContext) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FBF5),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(color: Color(0x330B2E18), blurRadius: 32),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFB9CEBB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            ...supportedMarkets.map((item) {
              final active = item.country == current;
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Material(
                  color: active ? const Color(0xFFE2F3DD) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: ListTile(
                    leading: Text(
                      item.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: active
                            ? const Color(0xFF237D42)
                            : const Color(0xFF203027),
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    trailing: active
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF31A85B),
                          )
                        : null,
                    onTap: () => Navigator.pop(sheetContext, item.country),
                  ),
                ),
              );
            }),
          ],
          ),
        ),
      ),
    ),
  );
  if (selected != null) onChanged(selected);
}

class _OfferLogo extends StatelessWidget {
  const _OfferLogo({required this.offer});
  final PartnerOffer offer;
  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: SublyColors.purple.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(18),
    ),
    child: offer.logoUrl.isEmpty
        ? const Icon(Icons.account_balance_rounded, color: SublyColors.purple)
        : Image.network(
            offer.logoUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.account_balance_rounded,
              color: SublyColors.purple,
            ),
          ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 92,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _PartnerDetailScreen extends StatelessWidget {
  const _PartnerDetailScreen({required this.offer, required this.locale});
  final PartnerOffer offer;
  final String locale;

  Future<void> _open(BuildContext context) async {
    final base = Uri.tryParse(offer.url);
    if (base == null) return;
    final target = await AttributionService.decorate(base);
    if (!context.mounted) return;
    if (offer.openMode == OfferOpenMode.webview) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PartnerWebViewScreen(
            title: offer.providerName,
            initialUrl: target,
          ),
        ),
      );
      return;
    }
    var opened = false;
    try {
      opened = await launchUrl(target, mode: LaunchMode.externalApplication);
      if (!opened) {
        opened = await launchUrl(target, mode: LaunchMode.inAppBrowserView);
      }
    } on PlatformException {
      opened = false;
    } on MissingPluginException {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть предложение')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(offer.providerName)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(child: _OfferLogo(offer: offer)),
        const SizedBox(height: 18),
        Text(
          offer.providerName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (offer.rating > 0)
          Text(
            '★ ${offer.rating.toStringAsFixed(1)}',
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 22),
        AppCard(
          child: Column(
            children: offer.parameters.entries
                .map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(switch (entry.key) {
                      'amount' => marketText(locale, 'amountFact'),
                      'processingTime' => marketText(locale, 'timeFact'),
                      'interestRate' => marketText(locale, 'rateFact'),
                      _ => entry.key,
                    }),
                    trailing: Text(
                      entry.value,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: offer.ctaText,
          icon: offer.openMode == OfferOpenMode.browser
              ? Icons.open_in_new_rounded
              : Icons.language_rounded,
          onPressed: () => _open(context),
        ),
      ],
    ),
  );
}
