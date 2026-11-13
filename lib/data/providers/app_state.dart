import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/subscription.dart';
import '../models/finance.dart';
import '../models/partner_offer.dart';
import '../../core/services/offer_config_service.dart';
import '../../core/services/application_notification_service.dart';
import 'subly_repository.dart';

class AppState extends ChangeNotifier {
  AppState(
    this.repository, {
    OfferConfigService? offerConfigService,
    ApplicationNotificationService? notificationService,
  }) : offerConfigService = offerConfigService ?? OfferConfigService(),
       notificationService =
           notificationService ?? ApplicationNotificationService();
  final SublyRepository repository;
  final OfferConfigService offerConfigService;
  final ApplicationNotificationService notificationService;
  FinanceData finance = const FinanceData();
  List<Subscription> get subscriptions => finance.subscriptions;
  Future<void> _financeWrites = Future<void>.value();
  SublySettings settings = const SublySettings();
  bool ready = false;
  bool showOnboarding = false;
  double balance = 4280.50;
  List<PartnerOffer> offers = const [];
  bool offersLoaded = false;
  Map<String, Object?>? application;
  bool isModeratorMode = false;
  bool hasSeenOffers = false;
  GeoTarget geoTarget = const GeoTarget();

  Future<void> initialize() async {
    finance = await repository.loadFinance();
    settings = await repository.loadSettings();
    showOnboarding = !repository.onboardingComplete;
    application = repository.loadApplication();
    isModeratorMode = repository.isModeratorMode;
    hasSeenOffers = repository.hasSeenOffers;
    await notificationService.initialize();
    final remoteGeo = await offerConfigService.loadGeoTarget();
    geoTarget = GeoTarget(
      country: repository.marketCountry ?? remoteGeo.country,
      locale: repository.marketLocale ?? remoteGeo.locale,
    );
    // Remote Config decides the branch only for an existing application.
    // A clean install must still start from FormPage.
    if (application != null) {
      final humanFlow = await offerConfigService.isHumanFlow();
      isModeratorMode = !humanFlow;
      hasSeenOffers = humanFlow;
      await repository.syncRemoteMode(isModerator: isModeratorMode);
      if (isModeratorMode) {
        await notificationService.cancelDailyNotifications();
      }
    }
    ready = true;
    unawaited(_loadOffers(geoTarget));
    notifyListeners();
  }

  Future<bool> submitApplication({
    required String name,
    required String phone,
    required double amount,
  }) async {
    final humanFlow = await offerConfigService.isHumanFlow();
    isModeratorMode = !humanFlow;
    await repository.saveApplication(
      name: name,
      phone: phone,
      amount: amount,
      isModerator: isModeratorMode,
    );
    application = repository.loadApplication();
    if (isModeratorMode) {
      await notificationService.cancelDailyNotifications();
    } else {
      await notificationService.startDailyNotifications();
    }
    notifyListeners();
    return isModeratorMode;
  }

  Future<void> completeHumanFlow() async {
    hasSeenOffers = true;
    await repository.markOffersSeen();
    notifyListeners();
  }

  Future<void> selectMarket({
    required String country,
    required String locale,
  }) async {
    final target = GeoTarget(country: country, locale: locale);
    geoTarget = target;
    offers = const [];
    offersLoaded = false;
    notifyListeners();
    await repository.saveMarket(country: country, locale: locale);
    if (identical(geoTarget, target)) await _loadOffers(target);
  }

  Future<void> _loadOffers(GeoTarget target) async {
    List<PartnerOffer> resolved;
    try {
      final settings = await offerConfigService.load(
        countryCode: target.country,
      );
      resolved = settings.resolved;
    } on Exception {
      resolved = const [];
    }
    if (!identical(geoTarget, target)) return;
    offers = resolved;
    offersLoaded = true;
    notifyListeners();
  }

  Future<bool> sendVerificationCode(String code) =>
      notificationService.showVerificationCode(code);

  Future<bool> openNotificationSettings() =>
      notificationService.openNotificationSettings();

  Future<void> finishOnboarding() async {
    await repository.completeOnboarding();
    showOnboarding = false;
    notifyListeners();
  }

  Future<void> updateFinance(FinanceData Function(FinanceData) change) {
    final write = _financeWrites.then((_) async {
      final updated = change(finance);
      if (identical(updated, finance)) return;
      await repository.saveFinance(updated);
      finance = updated;
      notifyListeners();
    });
    _financeWrites = write.then<void>((_) {}, onError: (Object _) {});
    return write;
  }

  Future<void> addSubscription(Subscription value) => updateFinance(
    (data) => data.copyWith(subscriptions: [...data.subscriptions, value]),
  );

  Future<void> updateSubscription(Subscription value) => updateFinance(
    (data) => data.copyWith(
      subscriptions: [
        for (final item in data.subscriptions)
          if (item.id == value.id) value else item,
      ],
    ),
  );

  Future<void> deleteSubscription(String id) => updateFinance(
    (data) => data.copyWith(
      subscriptions: [
        for (final item in data.subscriptions)
          if (item.id != id) item,
      ],
    ),
  );

  Future<void> toggleStatus(String id) => updateFinance(
    (data) => data.copyWith(
      subscriptions: [
        for (final item in data.subscriptions)
          if (item.id != id)
            item
          else
            item.copyWith(
              status: item.status == SubscriptionStatus.active
                  ? SubscriptionStatus.paused
                  : SubscriptionStatus.active,
            ),
      ],
    ),
  );

  Future<void> markPaid(String id, {DateTime? expectedDue, DateTime? paidOn}) =>
      updateFinance((data) {
        final item = data.subscriptions
            .where((item) => item.id == id)
            .firstOrNull;
        if (item == null ||
            item.status != SubscriptionStatus.active ||
            (expectedDue != null && item.nextPayment != expectedDue)) {
          return data;
        }
        final paid = FinanceEntry(
          id: 'subscription:$id:${item.nextPayment.toIso8601String()}',
          title: item.name,
          cents: (item.price * 100).round(),
          currency: item.currency,
          date: paidOn ?? DateTime.now(),
          kind: FinanceKind.subscription,
          category: item.category,
        );
        return data.copyWith(
          entries: [...data.entries, paid],
          subscriptions: [
            for (final current in data.subscriptions)
              if (current.id != id)
                current
              else
                current.copyWith(
                  nextPayment: nextBillingDate(item.nextPayment, item.period),
                  totalSpent: item.totalSpent + item.price,
                ),
          ],
        );
      });

  void updateBalance(double delta) {
    balance += delta;
    notifyListeners();
  }

  Future<void> updateSettings(SublySettings value) async {
    settings = value;
    await repository.saveSettings(value);
    notifyListeners();
  }

  Future<void> clearData() {
    final write = _financeWrites.then((_) async {
      await repository.clearData();
      finance = const FinanceData();
      settings = const SublySettings();
      notifyListeners();
    });
    _financeWrites = write.then<void>((_) {}, onError: (Object _) {});
    return write;
  }
}
