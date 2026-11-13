import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription.dart';
import '../models/finance.dart';

class SublyRepository {
  SublyRepository(this._preferences);
  static const _financeKey = 'subly.finance.v1';
  static const _subscriptionsKey = 'subly.subscriptions.v1';
  static const _settingsKey = 'subly.settings.v1';
  static const _onboardingKey = 'subly.onboarding.complete.v1';
  static const _applicationKey = 'subly.application.v1';
  static const _moderatorModeKey = 'subly.application.moderator.v1';
  static const _seenOffersKey = 'subly.offers.seen.v1';
  static const _marketCountryKey = 'subly.market.country.v1';
  static const _marketLocaleKey = 'subly.market.locale.v1';
  final SharedPreferences _preferences;

  Future<FinanceData> loadFinance() async {
    final raw = _preferences.getString(_financeKey);
    if (raw != null) {
      try {
        return FinanceData.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } on FormatException {
        return const FinanceData();
      } on TypeError {
        return const FinanceData();
      } on ArgumentError {
        return const FinanceData();
      }
    }
    final previous = _preferences.getString(_subscriptionsKey);
    if (previous == null) return const FinanceData();
    try {
      final items = (jsonDecode(previous) as List).map(
        (item) => Subscription.fromJson(Map<String, Object?>.from(item as Map)),
      );
      return FinanceData(
        subscriptions: items
            .where(
              (item) => !const {
                'netflix',
                'spotify',
                'icloud',
                'youtube',
              }.contains(item.id),
            )
            .toList(),
      );
    } on Object {
      return const FinanceData();
    }
  }

  Future<void> saveFinance(FinanceData data) async {
    if (!await _preferences.setString(_financeKey, jsonEncode(data.toJson()))) {
      throw StateError('Could not save finances');
    }
  }

  Future<List<Subscription>> loadSubscriptions() async {
    final raw = _preferences.getString(_subscriptionsKey);
    if (raw == null) return demoSubscriptions();
    try {
      final decoded = jsonDecode(raw) as List<Object?>;
      return decoded
          .map(
            (item) => _normalize(
              Subscription.fromJson(Map<String, Object?>.from(item! as Map)),
            ),
          )
          .toList();
    } on Object {
      return demoSubscriptions();
    }
  }

  Future<void> saveSubscriptions(List<Subscription> values) =>
      _preferences.setString(
        _subscriptionsKey,
        jsonEncode(values.map((e) => e.toJson()).toList()),
      );

  Future<SublySettings> loadSettings() async {
    final raw = _preferences.getString(_settingsKey);
    if (raw == null) return const SublySettings();
    try {
      return SublySettings.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      return const SublySettings();
    }
  }

  Future<void> saveSettings(SublySettings settings) =>
      _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  bool get onboardingComplete => _preferences.getBool(_onboardingKey) ?? false;
  Future<void> completeOnboarding() =>
      _preferences.setBool(_onboardingKey, true);

  Map<String, Object?>? loadApplication() {
    final raw = _preferences.getString(_applicationKey);
    if (raw == null) return null;
    try {
      return Map<String, Object?>.from(jsonDecode(raw) as Map);
    } on Object {
      return null;
    }
  }

  bool get isModeratorMode => _preferences.getBool(_moderatorModeKey) ?? false;
  bool get hasSeenOffers => _preferences.getBool(_seenOffersKey) ?? false;
  String? get marketCountry => _preferences.getString(_marketCountryKey);
  String? get marketLocale => _preferences.getString(_marketLocaleKey);

  Future<void> saveMarket({
    required String country,
    required String locale,
  }) async {
    await _preferences.setString(_marketCountryKey, country);
    await _preferences.setString(_marketLocaleKey, locale);
  }

  Future<void> saveApplication({
    required String name,
    required String phone,
    required double amount,
    required bool isModerator,
  }) async {
    await _preferences.setString(
      _applicationKey,
      jsonEncode({
        'name': name,
        'phone': phone,
        'amount': amount,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    );
    await _preferences.setBool(_moderatorModeKey, isModerator);
  }

  Future<void> markOffersSeen() => _preferences.setBool(_seenOffersKey, true);

  Future<void> syncRemoteMode({required bool isModerator}) async {
    await _preferences.setBool(_moderatorModeKey, isModerator);
    await _preferences.setBool(_seenOffersKey, !isModerator);
  }

  Future<void> clearData() async {
    await _preferences.remove(_financeKey);
    await _preferences.remove(_subscriptionsKey);
    await _preferences.remove(_settingsKey);
    await _preferences.remove(_applicationKey);
    await _preferences.remove(_moderatorModeKey);
    await _preferences.remove(_seenOffersKey);
    await _preferences.remove(_marketCountryKey);
    await _preferences.remove(_marketLocaleKey);
  }

  static List<Subscription> demoSubscriptions() {
    final now = DateTime.now();
    return [
      Subscription(
        id: 'netflix',
        name: 'Netflix',
        category: 'Entertainment',
        price: 799,
        currency: 'RUB',
        period: BillingPeriod.monthly,
        nextPayment: now.add(const Duration(days: 2)),
        colorValue: 0xFFE50914,
        totalSpent: 185.88,
      ),
      Subscription(
        id: 'spotify',
        name: 'Spotify',
        category: 'Music',
        price: 299,
        currency: 'RUB',
        period: BillingPeriod.monthly,
        nextPayment: now.add(const Duration(days: 5)),
        colorValue: 0xFF1DB954,
        totalSpent: 131.88,
      ),
      Subscription(
        id: 'icloud',
        name: 'iCloud',
        category: 'Cloud',
        price: 199,
        currency: 'RUB',
        period: BillingPeriod.monthly,
        nextPayment: now.add(const Duration(days: 8)),
        colorValue: 0xFF147EFB,
        totalSpent: 35.88,
      ),
      Subscription(
        id: 'youtube',
        name: 'YouTube Premium',
        category: 'Entertainment',
        price: 499,
        currency: 'RUB',
        period: BillingPeriod.monthly,
        nextPayment: now.add(const Duration(days: 12)),
        colorValue: 0xFFFF0033,
        totalSpent: 167.88,
      ),
    ];
  }

  static Subscription _normalize(Subscription value) => value.copyWith(
    currency: 'RUB',
    price: const {
      'netflix': 799.0,
      'spotify': 299.0,
      'icloud': 199.0,
      'youtube': 499.0,
    }[value.id],
  );
}
