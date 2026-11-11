import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/subscription.dart';
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
  List<Subscription> subscriptions = const [];
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
    subscriptions = await repository.loadSubscriptions();
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

  Future<void> addSubscription(Subscription value) async {
    subscriptions = [...subscriptions, value];
    await repository.saveSubscriptions(subscriptions);
    notifyListeners();
  }

  Future<void> updateSubscription(Subscription value) async {
    subscriptions = subscriptions
        .map((item) => item.id == value.id ? value : item)
        .toList();
    await repository.saveSubscriptions(subscriptions);
    notifyListeners();
  }

  Future<void> deleteSubscription(String id) async {
    subscriptions = subscriptions.where((item) => item.id != id).toList();
    await repository.saveSubscriptions(subscriptions);
    notifyListeners();
  }

  Future<void> toggleStatus(String id) async {
    subscriptions = subscriptions.map((item) {
      if (item.id != id) return item;
      final status = item.status == SubscriptionStatus.active
          ? SubscriptionStatus.paused
          : SubscriptionStatus.active;
      return item.copyWith(status: status);
    }).toList();
    await repository.saveSubscriptions(subscriptions);
    notifyListeners();
  }

  Future<void> markPaid(String id) async {
    subscriptions = subscriptions.map((item) {
      if (item.id != id) return item;
      return item.copyWith(
        nextPayment: DateTime(
          item.nextPayment.year,
          item.nextPayment.month + 1,
          item.nextPayment.day,
        ),
      );
    }).toList();
    await repository.saveSubscriptions(subscriptions);
    notifyListeners();
  }

  void updateBalance(double delta) {
    balance += delta;
    notifyListeners();
  }

  Future<void> updateSettings(SublySettings value) async {
    settings = value;
    await repository.saveSettings(value);
    notifyListeners();
  }

  Future<void> clearData() async {
    await repository.clearData();
    subscriptions = const [];
    settings = const SublySettings();
    notifyListeners();
  }
}
