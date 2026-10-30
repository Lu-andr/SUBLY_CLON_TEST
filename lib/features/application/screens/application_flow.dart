import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/animations/app_animations.dart';
import '../../../core/localization/market_localization.dart';
import '../../../data/providers/app_state.dart';

enum _ApplicationStep { form, confirmation, processing, waiting }

final _allPhoneCountries = CountryService().getAll();

Country? phoneCountryFor(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  try {
    final parsed = PhoneNumber.parse('+$digits');
    final parsedCountry = CountryService().findByCode(
      parsed.isoCode.name.toUpperCase(),
    );
    if (parsedCountry != null) return parsedCountry;
  } on Object {
    // An incomplete number can still identify its international dial code.
  }
  final candidates =
      _allPhoneCountries
          .where((country) => digits.startsWith(country.phoneCode))
          .toList()
        ..sort((a, b) {
          final codeLength = b.phoneCode.length.compareTo(a.phoneCode.length);
          return codeLength != 0 ? codeLength : a.e164Sc.compareTo(b.e164Sc);
        });
  return candidates.isEmpty ? null : candidates.first;
}

String? validatePhoneNumber(String? value) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) return 'Введите номер телефона';
  final country = phoneCountryFor(phone);
  if (country == null) return 'Некорректный код страны';
  try {
    final parsed = PhoneNumber.parse(phone);
    return parsed.isValidLength() ? null : 'Введите номер полностью';
  } on Object {
    return 'Введите номер полностью';
  }
}

String? validateMarketPhoneNumber(String? value, MarketOption market) {
  final error = validatePhoneNumber(value);
  if (error != null) return error;
  final digits = value!.replaceAll(RegExp(r'\D'), '');
  if (!digits.startsWith(market.dialCode)) {
    return 'Введите номер страны ${market.flag} +${market.dialCode}';
  }
  return null;
}

class CountryPhoneFormatter extends TextInputFormatter {
  const CountryPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '+',
        selection: TextSelection.collapsed(offset: 1),
      );
    }
    final country = phoneCountryFor(digits);
    final exampleLength = country?.example.replaceAll(RegExp(r'\D'), '').length;
    final countryLimit =
        country != null && exampleLength != null && exampleLength > 0
        ? country.phoneCode.length + exampleLength
        : 15;
    final maxDigits = countryLimit.clamp(1, 15);
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    if (country == null) {
      final text = '+$digits';
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    final national = digits.substring(country.phoneCode.length);
    var formattedNational = national;
    try {
      final isoCode = IsoCode.values.firstWhere(
        (iso) => iso.name.toUpperCase() == country.countryCode,
      );
      formattedNational = PhoneNumber(
        isoCode: isoCode,
        nsn: national,
      ).formatNsn(format: NsnFormat.international);
    } on Object {
      // Keep accepting partial input even if formatting metadata is absent.
    }
    final text =
        '+${country.phoneCode}${formattedNational.isEmpty ? '' : ' $formattedNational'}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class MarketPhoneFormatter extends TextInputFormatter {
  const MarketPhoneFormatter(this.dialCode);
  final String dialCode;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty || !digits.startsWith(dialCode)) {
      final locked = '+$dialCode ';
      return TextEditingValue(
        text: locked,
        selection: TextSelection.collapsed(offset: locked.length),
      );
    }
    return const CountryPhoneFormatter().formatEditUpdate(oldValue, newValue);
  }
}

class ApplicationFlow extends StatefulWidget {
  const ApplicationFlow({
    required this.state,
    required this.onComplete,
    super.key,
  });

  final AppState state;
  final VoidCallback onComplete;

  @override
  State<ApplicationFlow> createState() => _ApplicationFlowState();
}

class _ApplicationFlowState extends State<ApplicationFlow>
    with WidgetsBindingObserver {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final confirmationController = TextEditingController();
  _ApplicationStep step = _ApplicationStep.form;
  bool moderator = false;
  bool submitting = false;
  bool phoneIsValid = false;
  String? phoneCountryCode;
  bool codeDelivered = false;
  bool sendingCode = false;
  bool waitingForNotificationSettings = false;
  String code = '';
  String? confirmationError;
  late double selectedAmount;
  bool consent = false;
  late String phoneMarketCountry;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final market = marketFor(widget.state.geoTarget.country);
    selectedAmount = market.initialAmount;
    phoneMarketCountry = market.country;
    phoneController.text = '+${market.dialCode} ';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    nameController.dispose();
    phoneController.dispose();
    confirmationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && waitingForNotificationSettings) {
      waitingForNotificationSettings = false;
      _sendCodeNotification();
    }
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false) || !consent) {
      if (!consent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Подтвердите согласие на обработку данных'),
          ),
        );
      }
      return;
    }
    setState(() => submitting = true);
    moderator = await widget.state.submitApplication(
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      amount: selectedAmount,
    );
    if (!mounted) return;
    code = moderator
        ? '2544'
        : (1000 + Random.secure().nextInt(9000)).toString();
    final delivered = await widget.state.sendVerificationCode(code);
    if (!mounted) return;
    setState(() {
      submitting = false;
      step = _ApplicationStep.confirmation;
      codeDelivered = delivered;
      sendingCode = false;
    });
    if (delivered) unawaited(_autofillVerificationCode());
  }

  Future<void> _autofillVerificationCode() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || step != _ApplicationStep.confirmation) return;
    confirmationController.text = code;
    _verifyCode();
  }

  Future<void> _resendCode() async {
    if (sendingCode) return;
    if (!codeDelivered) {
      waitingForNotificationSettings = true;
      final opened = await widget.state.openNotificationSettings();
      if (!opened && mounted) {
        waitingForNotificationSettings = false;
        await _sendCodeNotification();
      }
      return;
    }
    await _sendCodeNotification();
  }

  Future<void> _sendCodeNotification() async {
    if (sendingCode || !mounted) return;
    setState(() => sendingCode = true);
    final delivered = await widget.state.sendVerificationCode(code);
    if (!mounted) return;
    setState(() {
      codeDelivered = delivered;
      sendingCode = false;
    });
    if (delivered) unawaited(_autofillVerificationCode());
  }

  void _verifyCode() {
    if (confirmationController.text.trim() != code) {
      setState(() => confirmationError = 'Неверный код. Проверьте уведомление');
      return;
    }
    setState(() {
      confirmationError = null;
      codeDelivered = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    _beginProcessing();
  }

  void _beginProcessing() {
    if (!mounted) return;
    setState(() => step = _ApplicationStep.processing);
    timer = Timer(const Duration(seconds: 2), finish);
  }

  Future<void> finish() async {
    if (!mounted) return;
    if (moderator) {
      setState(() => step = _ApplicationStep.waiting);
    } else {
      await widget.state.completeHumanFlow();
      if (mounted) widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (step) {
        _ApplicationStep.form => _form(),
        _ApplicationStep.confirmation => _confirmation(),
        _ApplicationStep.processing => _processing(),
        _ApplicationStep.waiting => ModeratorWaitingScreen(state: widget.state),
      },
    ),
  );

  String get maskedPhone {
    final phone = phoneController.text.trim();
    if (phone.length <= 4) return phone;
    return '${phone.substring(0, 2)} ••• ••• ${phone.substring(phone.length - 2)}';
  }

  Widget _confirmation() => Container(
    key: const ValueKey('confirmation'),
    color: const Color(0xFFF8FCF7),
    child: Stack(
      children: [
        const Positioned(top: -70, left: -80, child: _SoftGreenOrb(size: 220)),
        const Positioned(
          bottom: 30,
          right: -90,
          child: _SoftGreenOrb(size: 210),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: .82, end: 1),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutBack,
                  builder: (_, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA6DA62), Color(0xFF21A864)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x553BAA61),
                          blurRadius: 34,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.fact_check_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
                const SizedBox(height: 58),
                _OtpBoxes(
                  controller: confirmationController,
                  hasError: confirmationError != null,
                  onChanged: (value) {
                    if (value.length < 4 && confirmationError != null) {
                      setState(() => confirmationError = null);
                    } else {
                      setState(() {});
                    }
                    if (value.length == 4) _verifyCode();
                  },
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: confirmationError == null
                      ? const SizedBox(height: 0)
                      : Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            confirmationError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFD64242),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 34),
                if (!sendingCode && !codeDelivered) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF2D9),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Android не разрешил показать уведомление. Ваш код: $code',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF704C00),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextButton.icon(
                  onPressed: sendingCode ? null : _resendCode,
                  icon: sendingCode
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications_active_rounded),
                  label: Text(
                    sendingCode
                        ? 'Отправляем код…'
                        : codeDelivered
                        ? 'Отправить уведомление ещё раз'
                        : 'Открыть настройки уведомлений',
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF8E9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF59B94F),
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Код действует ограниченное время.\nНикому его не сообщайте.',
                          style: TextStyle(color: Color(0xFF667064)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _form() => Form(
    key: formKey,
    autovalidateMode: AutovalidateMode.disabled,
    child: ListView(
      key: const ValueKey('application-form'),
      padding: EdgeInsets.zero,
      children: [
        Container(
          height: MediaQuery.paddingOf(context).top + 220,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2D9B4D), Color(0xFF176F42)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/banners/form-eco-zero-v1.png',
                  package: 'subly',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/banners/form-eco-zero-v1.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xCC052D19), Color(0x00052D19)],
                      stops: [0, .72],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.paddingOf(context).top + 20,
                  24,
                  30,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(
                              '✓ ${marketText(widget.state.geoTarget.locale, 'approved')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _MarketMenu(
                          value: marketFor(
                            widget.state.geoTarget.country,
                          ).country,
                          onChanged: (country) {
                            final option = marketFor(country);
                            widget.state.selectMarket(
                              country: option.country,
                              locale: option.locale,
                            );
                            setState(
                              () => selectedAmount = option.initialAmount,
                            );
                          },
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      marketText(widget.state.geoTarget.locale, 'title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(width: 38, height: 2, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
          child: Column(
            children: [
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: _AmountSlider(
                  value: selectedAmount,
                  market: marketFor(widget.state.geoTarget.country),
                  label: marketText(widget.state.geoTarget.locale, 'amount'),
                  onChanged: (value) => setState(() => selectedAmount = value),
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marketText(widget.state.geoTarget.locale, 'name'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    _FormFieldShell(
                      child: TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _fieldDecoration(
                          hint: marketText(
                            widget.state.geoTarget.locale,
                            'nameHint',
                          ),
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'Введите имя'
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FadeSlideIn(
                delay: const Duration(milliseconds: 220),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marketText(widget.state.geoTarget.locale, 'phone'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    _FormFieldShell(
                      child: TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          MarketPhoneFormatter(
                            marketFor(phoneMarketCountry).dialCode,
                          ),
                        ],
                        onChanged: (value) {
                          final valid =
                              validateMarketPhoneNumber(
                                value,
                                marketFor(phoneMarketCountry),
                              ) ==
                              null;
                          final countryCode = phoneCountryFor(
                            value,
                          )?.countryCode;
                          if (valid != phoneIsValid ||
                              countryCode != phoneCountryCode) {
                            setState(() {
                              phoneIsValid = valid;
                              phoneCountryCode = countryCode;
                            });
                          }
                        },
                        validator: (value) => validateMarketPhoneNumber(
                          value,
                          marketFor(phoneMarketCountry),
                        ),
                        decoration: _fieldDecoration(
                          hint: marketText(
                            widget.state.geoTarget.locale,
                            'phone',
                          ),
                          prefix: _PhoneMarketPicker(
                            value: phoneMarketCountry,
                            onChanged: (country) {
                              final option = marketFor(country);
                              setState(() {
                                phoneMarketCountry = option.country;
                                phoneController.text = '+${option.dialCode} ';
                                phoneIsValid = false;
                                phoneCountryCode = option.country;
                              });
                            },
                          ),
                          suffix: phoneIsValid
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: SublyColors.green,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                value: consent,
                onChanged: (value) => setState(() => consent = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  marketText(widget.state.geoTarget.locale, 'consent'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: _GradientSubmitButton(
                  loading: submitting,
                  label: marketText(widget.state.geoTarget.locale, 'submit'),
                  onPressed: submitting ? null : submit,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 17,
                    color: SublyColors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    marketText(widget.state.geoTarget.locale, 'secure'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  InputDecoration _fieldDecoration({
    String? label,
    String? hint,
    IconData? icon,
    Widget? prefix,
    Widget? suffix,
    String? suffixText,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    prefixIcon: prefix ?? (icon == null ? null : Icon(icon)),
    suffixIcon: suffix,
    suffixText: suffixText,
    filled: true,
    fillColor: Theme.of(context).colorScheme.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: SublyColors.purple, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
  );

  Widget _processing() => _CenteredStep(
    key: const ValueKey('processing'),
    icon: Icons.hourglass_top_rounded,
    title: 'Обрабатываем заявку',
    description: moderator
        ? 'Проверяем данные. Это займёт пару секунд.'
        : 'Подбираем доступные варианты. Это займёт пару секунд.',
    child: moderator
        ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: LinearProgressIndicator(minHeight: 8),
          )
        : const SizedBox.shrink(),
  );
}

class ModeratorWaitingScreen extends StatefulWidget {
  const ModeratorWaitingScreen({this.state, super.key});

  final AppState? state;

  @override
  State<ModeratorWaitingScreen> createState() => _ModeratorWaitingScreenState();
}

class _ModeratorWaitingScreenState extends State<ModeratorWaitingScreen> {
  late String market;

  @override
  void initState() {
    super.initState();
    market = marketFor(widget.state?.geoTarget.country ?? 'RU').country;
  }

  @override
  Widget build(BuildContext context) {
    // Flutter Inspector can leave these visual debugging flags enabled across
    // hot restarts. Never let them leak into this user-facing status screen.
    debugPaintBaselinesEnabled = false;
    debugPaintSizeEnabled = false;
    debugPaintPointersEnabled = false;

    final colors = Theme.of(context).colorScheme;
    final marketOption = marketFor(market);
    final application = widget.state?.application;
    final amount = application?['amount'];
    final amountText = amount is num
        ? formatMarketAmount(amount, marketOption)
        : 'Сумма не указана';
    final createdAt = DateTime.tryParse(
      application?['createdAt']?.toString() ?? '',
    );
    final createdText = createdAt == null
        ? 'Текущая заявка'
        : '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}';
    return MediaQuery.withNoTextScaling(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FBF5),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: MediaQuery.paddingOf(context).top + 235,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2D9B4D), Color(0xFF176F42)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(34),
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/banners/cabinet-eco-finance-v1.png',
                      package: 'subly',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/banners/cabinet-eco-finance-v1.png',
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
                          stops: [0, .72],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      MediaQuery.paddingOf(context).top + 24,
                      24,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                marketText(marketFor(market).locale, 'cabinet'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  height: 1.05,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            _MarketMenu(
                              value: market,
                              light: true,
                              onChanged: (value) {
                                final option = marketFor(value);
                                widget.state?.selectMarket(
                                  country: option.country,
                                  locale: option.locale,
                                );
                                setState(() => market = value);
                              },
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          marketText(marketOption.locale, 'tools'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(width: 34, height: 2, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x130F2A1B),
                      blurRadius: 28,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF6E8),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: const Icon(
                            Icons.assignment_turned_in_outlined,
                            color: Color(0xFF258A43),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${marketText(marketOption.locale, 'application')} $amountText',
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                createdText,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF7EB),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: Color(0xFF258A43),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            marketText(marketOption.locale, 'pending'),
                            style: const TextStyle(
                              color: Color(0xFF258A43),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _InlineCalculator(
                initialAmount: amount is num
                    ? amount.toDouble()
                    : marketOption.initialAmount,
                market: marketOption,
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _TipCard(
                icon: Icons.lightbulb_outline_rounded,
                title: marketText(marketOption.locale, 'tips'),
                text: marketText(marketOption.locale, 'tipsDesc'),
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

class _MarketMenu extends StatelessWidget {
  const _MarketMenu({
    required this.value,
    required this.onChanged,
    this.light = false,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final selected = marketFor(value);
    return InkWell(
      onTap: () => _showEcoMarketSheet(context, value, onChanged),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: light ? Colors.white : Colors.white.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white30),
        ),
        child: Text(
          '${selected.flag} ${selected.country} ▾',
          style: TextStyle(
            color: light ? const Color(0xFF243029) : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PhoneMarketPicker extends StatelessWidget {
  const _PhoneMarketPicker({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = marketFor(value);
    return InkWell(
      onTap: () =>
          _showEcoMarketSheet(context, value, onChanged, showCode: true),
      child: SizedBox(
        width: 68,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(selected.flag, style: const TextStyle(fontSize: 22)),
            const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

Future<void> _showEcoMarketSheet(
  BuildContext context,
  String current,
  ValueChanged<String> onChanged, {
  bool showCode = false,
}) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
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
                    trailing: showCode
                        ? Text(
                            '+${item.dialCode}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          )
                        : active
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
  );
  if (selected != null) onChanged(selected);
}

class _InlineCalculator extends StatefulWidget {
  const _InlineCalculator({required this.initialAmount, required this.market});
  final double initialAmount;
  final MarketOption market;

  @override
  State<_InlineCalculator> createState() => _InlineCalculatorState();
}

class _InlineCalculatorState extends State<_InlineCalculator> {
  late double amount = widget.initialAmount.clamp(
    widget.market.minAmount,
    widget.market.maxAmount,
  );
  double days = 30;
  double annualRate = 0;

  double get total => amount + amount * annualRate / 100 * days / 365;

  @override
  Widget build(BuildContext context) => FadeSlideIn(
    delay: const Duration(milliseconds: 120),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140C1020),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFA7D95F), Color(0xFF21A864)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.calculate_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                marketText(widget.market.locale, 'calculator'),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _CalculatorControl(
            label: marketText(widget.market.locale, 'calcAmount'),
            displayValue: formatMarketAmount(amount, widget.market),
            value: amount,
            min: widget.market.minAmount,
            max: widget.market.maxAmount,
            divisions: widget.market.amountDivisions,
            onChanged: (value) => setState(() => amount = value),
          ),
          const SizedBox(height: 12),
          _CalculatorControl(
            label: marketText(widget.market.locale, 'term'),
            displayValue:
                '${days.round()} ${marketText(widget.market.locale, 'days')}',
            value: days,
            min: 7,
            max: 365,
            divisions: 358,
            onChanged: (value) => setState(() => days = value),
          ),
          const SizedBox(height: 12),
          _CalculatorControl(
            label: marketText(widget.market.locale, 'rate'),
            displayValue: '${annualRate.toStringAsFixed(1)} %',
            value: annualRate,
            min: 0,
            max: 50,
            divisions: 100,
            onChanged: (value) => setState(() => annualRate = value),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 17, 14, 17),
            decoration: BoxDecoration(
              color: SublyColors.purple.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marketText(widget.market.locale, 'repay'),
                        style: const TextStyle(color: Color(0xFF36834A)),
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: total),
                        duration: const Duration(milliseconds: 260),
                        builder: (_, value, _) => Text(
                          formatMarketAmount(value, widget.market),
                          style: const TextStyle(
                            color: Color(0xFF258A43),
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Colors.white70,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Color(0xFF36A95F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CalculatorControl extends StatelessWidget {
  const _CalculatorControl({
    required this.label,
    required this.displayValue,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String label;
  final String displayValue;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Container(
            constraints: const BoxConstraints(minWidth: 104),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EEE8)),
              boxShadow: const [
                BoxShadow(color: Color(0x0D000000), blurRadius: 12),
              ],
            ),
            child: Text(
              displayValue,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    ],
  );
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x120F2A1B),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF7EB),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: SublyColors.green),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(text),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF667066)),
      ],
    ),
  );
}

class _FormFieldShell extends StatelessWidget {
  const _FormFieldShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: SublyColors.purple.withValues(alpha: .08),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
}

class _AmountSlider extends StatelessWidget {
  const _AmountSlider({
    required this.value,
    required this.market,
    required this.label,
    required this.onChanged,
  });
  final double value;
  final MarketOption market;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0EEFF),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: SublyColors.purple.withValues(alpha: .10),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 5),
        TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 220),
          builder: (_, animated, _) => Text(
            formatMarketAmount(animated, market),
            style: const TextStyle(
              color: Color(0xFF461091),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Slider(
          activeColor: const Color(0xFF461091),
          thumbColor: const Color(0xFF461091),
          inactiveColor: const Color(0xFFE4DCEE),
          value: value,
          min: market.minAmount,
          max: market.maxAmount,
          divisions: market.amountDivisions,
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatMarketAmount(market.minAmount, market)),
            Text(formatMarketAmount(market.maxAmount, market)),
          ],
        ),
      ],
    ),
  );
}

class _GradientSubmitButton extends StatefulWidget {
  const _GradientSubmitButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });
  final bool loading;
  final String label;
  final VoidCallback? onPressed;

  @override
  State<_GradientSubmitButton> createState() => _GradientSubmitButtonState();
}

class _GradientSubmitButtonState extends State<_GradientSubmitButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: pressed ? .97 : 1,
    duration: AppAnimations.fast,
    curve: AppAnimations.curve,
    child: GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) => setState(() => pressed = true),
      onTapCancel: widget.onPressed == null
          ? null
          : () => setState(() => pressed = false),
      onTapUp: widget.onPressed == null
          ? null
          : (_) {
              setState(() => pressed = false);
              HapticFeedback.lightImpact();
              widget.onPressed?.call();
            },
      child: AnimatedOpacity(
        opacity: widget.onPressed == null ? .65 : 1,
        duration: AppAnimations.fast,
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3716B1), Color(0xFF6028EF)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: SublyColors.purple.withValues(alpha: .28),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: AppAnimations.fast,
            child: widget.loading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}

class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({
    required this.controller,
    required this.hasError,
    required this.onChanged,
  });
  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = controller.text;
    return SizedBox(
      width: 286,
      height: 70,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) {
              final filled = index < value.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 62,
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: filled
                      ? const Color(0xFFEAF7E4)
                      : Colors.white.withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: hasError
                        ? const Color(0xFFE04B4B)
                        : filled
                        ? const Color(0xFF50B85A)
                        : const Color(0xFF9BCB93),
                    width: filled ? 2 : 1.3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x183F9D55),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  child: Text(
                    filled ? value[index] : '',
                    key: ValueKey(filled ? value[index] : 'empty-$index'),
                    style: TextStyle(
                      color: hasError
                          ? const Color(0xFFD64242)
                          : const Color(0xFF268A4D),
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: .01,
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: onChanged,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftGreenOrb extends StatelessWidget {
  const _SoftGreenOrb({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [Color(0x558DD66B), Color(0x008DD66B)]),
    ),
  );
}

class _CenteredStep extends StatelessWidget {
  const _CenteredStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
    super.key,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          _FlowIcon(icon: icon),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(description, textAlign: TextAlign.center),
          const SizedBox(height: 28),
          child,
        ],
      ),
    ),
  );
}

class _FlowIcon extends StatelessWidget {
  const _FlowIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 76,
    height: 76,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [SublyColors.purple, SublyColors.accent],
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Icon(icon, size: 38, color: Colors.white),
  );
}
