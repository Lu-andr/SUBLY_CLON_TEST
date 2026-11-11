import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subly/core/services/application_notification_service.dart';
import 'package:subly/core/services/offer_config_service.dart';
import 'package:subly/data/models/partner_offer.dart';
import 'package:subly/data/providers/app_state.dart';
import 'package:subly/data/providers/subly_repository.dart';
import 'package:subly/features/calculator/models/loan_estimate.dart';
import 'package:subly/features/loan_workspace/loan_workspace.dart';

class _PendingCatalogue extends OfferConfigService {
  final response = Completer<OfferSettings>();

  @override
  Future<GeoTarget> loadGeoTarget() async =>
      const GeoTarget(country: 'RU', locale: 'ru');

  @override
  Future<OfferSettings> load({String? countryCode}) => response.future;
}

class _TestNotifications extends ApplicationNotificationService {
  @override
  Future<void> initialize() async {}
}

void main() {
  test('matches the example payment and balances the schedule', () {
    final loan = LoanEstimate(principal: 1691000, months: 12, annualRate: 60);

    expect(loan.monthlyPayment.round(), 190788);
    expect(loan.total.round(), 2289453);
    expect(loan.interest.round(), 598453);
    expect(loan.interestPercent, closeTo(35.4, .01));
    final schedule = loan.schedule.toList();
    expect(schedule, hasLength(12));
    expect(schedule.last.remaining, 0);
    expect(
      schedule.fold<double>(0, (sum, row) => sum + row.principal),
      closeTo(loan.principal, .001),
    );
    expect(
      schedule.fold<double>(0, (sum, row) => sum + row.interest),
      closeTo(loan.interest, .001),
    );
  });

  test('zero interest splits the principal evenly', () {
    final loan = LoanEstimate(principal: 12000, months: 12, annualRate: 0);
    expect(loan.monthlyPayment, 1000);
    expect(loan.total, 12000);
    expect(loan.interest, 0);
    expect(loan.schedule.every((row) => row.amount == 1000), isTrue);
  });

  testWidgets('calculator works with no offers and keeps slider values', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final catalogue = _PendingCatalogue();
    final state = AppState(
      SublyRepository(preferences),
      offerConfigService: catalogue,
      notificationService: _TestNotifications(),
    );
    await state.initialize();
    expect(state.offersLoaded, isFalse);

    await tester.pumpWidget(MaterialApp(home: LoanWorkspace(state: state)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Калькулятор'));
    await tester.pumpAndSettle();
    expect(find.text('Платёж в месяц'), findsOneWidget);

    catalogue.response.complete(
      const OfferSettings(offers: [], fallbackOffers: []),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Предложения'));
    await tester.pumpAndSettle();
    expect(find.text('Предложения временно недоступны'), findsOneWidget);
    await tester.tap(find.text('Калькулятор'));
    await tester.pumpAndSettle();

    final sliders = find.byType(Slider);
    expect(sliders, findsNWidgets(3));
    final initial = tester
        .widgetList<Slider>(sliders)
        .map((s) => s.value)
        .toList();
    for (var i = 0; i < initial.length; i++) {
      final slider = sliders.at(i);
      final bounds = tester.getRect(slider);
      await tester.tapAt(
        Offset(bounds.left + bounds.width * .3, bounds.center.dy),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(slider).value, isNot(initial[i]));
    }
    final changed = tester
        .widgetList<Slider>(sliders)
        .map((s) => s.value)
        .toList();

    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Язык и страна'), findsOneWidget);
    await tester.tap(find.text('Калькулятор'));
    await tester.pumpAndSettle();
    expect(tester.widgetList<Slider>(sliders).map((s) => s.value), changed);

    final schedule = find.text('График платежей').hitTestable();
    await tester.scrollUntilVisible(
      schedule,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(schedule);
    await tester.pumpAndSettle();
    expect(find.text('Месяц 1'), findsOneWidget);

    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Язык и страна'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filipino'));
    await tester.pumpAndSettle();
    expect(state.repository.marketCountry, 'PH');
    await tester.tap(find.text('Kalkulador'));
    await tester.pumpAndSettle();
    expect(find.text('PHP'), findsOneWidget);
    expect(find.text('Kalkulador ng pautang'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
