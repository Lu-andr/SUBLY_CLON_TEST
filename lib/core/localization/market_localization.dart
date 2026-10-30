import 'package:intl/intl.dart';

class MarketOption {
  const MarketOption({
    required this.country,
    required this.locale,
    required this.flag,
    required this.label,
    required this.currency,
    required this.dialCode,
    required this.minAmount,
    required this.maxAmount,
    required this.initialAmount,
    required this.amountStep,
  });

  final String country;
  final String locale;
  final String flag;
  final String label;
  final String currency;
  final String dialCode;
  final double minAmount;
  final double maxAmount;
  final double initialAmount;
  final double amountStep;

  int get amountDivisions => ((maxAmount - minAmount) / amountStep).round();
}

const supportedMarkets = <MarketOption>[
  MarketOption(
    country: 'RU',
    locale: 'ru',
    flag: '🇷🇺',
    label: 'Русский',
    currency: '₽',
    dialCode: '7',
    minAmount: 1000,
    maxAmount: 100000,
    initialAmount: 15000,
    amountStep: 1000,
  ),
  MarketOption(
    country: 'AR',
    locale: 'es-ar',
    flag: '🇦🇷',
    label: 'Español · Argentina',
    currency: r'$',
    dialCode: '54',
    minAmount: 10000,
    maxAmount: 1000000,
    initialAmount: 200000,
    amountStep: 10000,
  ),
  MarketOption(
    country: 'UZ',
    locale: 'uz',
    flag: '🇺🇿',
    label: "O‘zbekcha",
    currency: "so‘m",
    dialCode: '998',
    minAmount: 100000,
    maxAmount: 20000000,
    initialAmount: 3000000,
    amountStep: 100000,
  ),
  MarketOption(
    country: 'MX',
    locale: 'es-mx',
    flag: '🇲🇽',
    label: 'Español · México',
    currency: r'$',
    dialCode: '52',
    minAmount: 1000,
    maxAmount: 100000,
    initialAmount: 15000,
    amountStep: 1000,
  ),
  MarketOption(
    country: 'KZ',
    locale: 'kk',
    flag: '🇰🇿',
    label: 'Қазақша',
    currency: '₸',
    dialCode: '7',
    minAmount: 10000,
    maxAmount: 2000000,
    initialAmount: 300000,
    amountStep: 10000,
  ),
  MarketOption(
    country: 'VN',
    locale: 'vi',
    flag: '🇻🇳',
    label: 'Tiếng Việt',
    currency: '₫',
    dialCode: '84',
    minAmount: 500000,
    maxAmount: 30000000,
    initialAmount: 5000000,
    amountStep: 500000,
  ),
  MarketOption(
    country: 'ZA',
    locale: 'en',
    flag: '🇿🇦',
    label: 'English',
    currency: 'R',
    dialCode: '27',
    minAmount: 1000,
    maxAmount: 100000,
    initialAmount: 15000,
    amountStep: 1000,
  ),
  MarketOption(
    country: 'PH',
    locale: 'fil',
    flag: '🇵🇭',
    label: 'Filipino',
    currency: '₱',
    dialCode: '63',
    minAmount: 1000,
    maxAmount: 40000,
    initialAmount: 10000,
    amountStep: 1000,
  ),
];

MarketOption marketFor(String country) => supportedMarkets.firstWhere(
  (item) => item.country == country.toUpperCase(),
  orElse: () => supportedMarkets.first,
);

String formatMarketAmount(num amount, MarketOption market) {
  // Filipino UI uses the same grouping and decimal separators as English.
  final numberLocale = market.locale == 'fil' ? 'en' : market.locale;
  return '${NumberFormat.decimalPattern(numberLocale).format(amount.round())} ${market.currency}';
}

const _texts = <String, Map<String, String>>{
  'en': {
    'title': "90% of applications approved",
    'approved': "Approval in 5 minutes",
    'amount': "Loan amount",
    'name': "What is your name?",
    'nameHint': "Name",
    'phone': "Phone number",
    'consent': "I agree to the processing of my personal data",
    'submit': "Submit application",
    'secure': "Your data is protected",
    'offers': "Offers for you",
    'cabinet': "Personal account",
  },
  'fil': {
    'title': "90% ng mga aplikasyon ay naaprubahan",
    'approved': "Pag-apruba sa loob ng 5 minuto",
    'amount': "Halaga ng pautang",
    'name': "Ano ang pangalan mo?",
    'nameHint': "Pangalan",
    'phone': "Numero ng telepono",
    'consent': "Pumapayag ako sa pagproseso ng aking personal na datos",
    'submit': "Isumite ang aplikasyon",
    'secure': "Protektado ang iyong datos",
    'offers': "Mga alok para sa iyo",
    'cabinet': "Personal na account",
  },
  'ru': {
    'title': '90% заявок одобрено',
    'approved': 'Одобрение за 5 минут',
    'amount': 'Сумма займа',
    'name': 'Как вас зовут?',
    'nameHint': 'Имя',
    'phone': 'Номер телефона',
    'consent': 'Я согласен на обработку персональных данных',
    'submit': 'Оставить заявку',
    'secure': 'Ваши данные надёжно защищены',
    'offers': 'Предложения для вас',
    'cabinet': 'Личный кабинет',
  },
  'es-ar': {
    'title': '90% de las solicitudes aprobadas',
    'approved': 'Aprobación en 5 minutos',
    'amount': 'Monto del préstamo',
    'name': '¿Cómo te llamas?',
    'nameHint': 'Nombre',
    'phone': 'Número de teléfono',
    'consent': 'Acepto el tratamiento de mis datos personales',
    'submit': 'Enviar solicitud',
    'secure': 'Tus datos están protegidos',
    'offers': 'Ofertas para ti',
    'cabinet': 'Área personal',
  },
  'es-mx': {
    'title': '90% de las solicitudes aprobadas',
    'approved': 'Aprobación en 5 minutos',
    'amount': 'Monto del préstamo',
    'name': '¿Cómo te llamas?',
    'nameHint': 'Nombre',
    'phone': 'Número de teléfono',
    'consent': 'Acepto el tratamiento de mis datos personales',
    'submit': 'Enviar solicitud',
    'secure': 'Tus datos están protegidos',
    'offers': 'Ofertas para ti',
    'cabinet': 'Área personal',
  },
  'uz': {
    'title': 'Arizalarning 90% tasdiqlangan',
    'approved': '5 daqiqada tasdiqlash',
    'amount': 'Qarz miqdori',
    'name': 'Ismingiz nima?',
    'nameHint': 'Ism',
    'phone': 'Telefon raqami',
    'consent': "Shaxsiy ma’lumotlarimni qayta ishlashga roziman",
    'submit': 'Ariza qoldirish',
    'secure': "Ma’lumotlaringiz himoyalangan",
    'offers': 'Siz uchun takliflar',
    'cabinet': 'Shaxsiy kabinet',
  },
  'kk': {
    'title': 'Өтінімдердің 90%-ы мақұлданды',
    'approved': '5 минутта мақұлдау',
    'amount': 'Қарыз сомасы',
    'name': 'Атыңыз кім?',
    'nameHint': 'Аты',
    'phone': 'Телефон нөмірі',
    'consent': 'Жеке деректерімді өңдеуге келісемін',
    'submit': 'Өтінім беру',
    'secure': 'Деректеріңіз қорғалған',
    'offers': 'Сізге арналған ұсыныстар',
    'cabinet': 'Жеке кабинет',
  },
  'vi': {
    'title': '90% hồ sơ được phê duyệt',
    'approved': 'Duyệt trong 5 phút',
    'amount': 'Số tiền vay',
    'name': 'Tên của bạn?',
    'nameHint': 'Họ tên',
    'phone': 'Số điện thoại',
    'consent': 'Tôi đồng ý xử lý dữ liệu cá nhân',
    'submit': 'Gửi đăng ký',
    'secure': 'Dữ liệu của bạn được bảo vệ',
    'offers': 'Ưu đãi dành cho bạn',
    'cabinet': 'Tài khoản cá nhân',
  },
};

const _dashboardTexts = <String, Map<String, String>>{
  'en': {
    'tools': "Useful tools",
    'application': "Application for",
    'pending': "Awaiting a decision",
    'calculator': "Calculator",
    'calcAmount': "Amount",
    'term': "Term",
    'days': "days",
    'rate': "Interest rate",
    'repay': "Total repayment",
    'tips': "Useful tips",
    'tipsDesc': "Recommendations to help you make an informed decision.",
  },
  'fil': {
    'tools': "Mga kapaki-pakinabang na tool",
    'application': "Aplikasyon para sa",
    'pending': "Naghihintay ng desisyon",
    'calculator': "Kalkulador",
    'calcAmount': "Halaga",
    'term': "Tagal",
    'days': "araw",
    'rate': "Rate ng interes",
    'repay': "Kabuuang babayaran",
    'tips': "Mga kapaki-pakinabang na payo",
    'tipsDesc': "Mga mungkahing makatutulong sa iyong gumawa ng tamang desisyon.",
  },
  'ru': {
    'tools': 'Полезные инструменты',
    'application': 'Заявка на',
    'pending': 'Ожидает решения',
    'calculator': 'Калькулятор',
    'calcAmount': 'Сумма',
    'term': 'Срок',
    'days': 'дней',
    'rate': 'Ставка',
    'repay': 'К возврату',
    'tips': 'Полезные советы',
    'tipsDesc': 'Рекомендации, которые помогут принять правильное решение.',
  },
  'es-ar': {
    'tools': 'Herramientas útiles',
    'application': 'Solicitud por',
    'pending': 'Pendiente de decisión',
    'calculator': 'Calculadora',
    'calcAmount': 'Monto',
    'term': 'Plazo',
    'days': 'días',
    'rate': 'Tasa',
    'repay': 'Total a devolver',
    'tips': 'Consejos útiles',
    'tipsDesc': 'Recomendaciones para tomar una decisión informada.',
  },
  'es-mx': {
    'tools': 'Herramientas útiles',
    'application': 'Solicitud por',
    'pending': 'Pendiente de decisión',
    'calculator': 'Calculadora',
    'calcAmount': 'Monto',
    'term': 'Plazo',
    'days': 'días',
    'rate': 'Tasa',
    'repay': 'Total a devolver',
    'tips': 'Consejos útiles',
    'tipsDesc': 'Recomendaciones para tomar una decisión informada.',
  },
  'uz': {
    'tools': 'Foydali vositalar',
    'application': 'Ariza summasi',
    'pending': 'Qaror kutilmoqda',
    'calculator': 'Kalkulyator',
    'calcAmount': 'Summa',
    'term': 'Muddat',
    'days': 'kun',
    'rate': 'Stavka',
    'repay': 'Qaytarish summasi',
    'tips': 'Foydali maslahatlar',
    'tipsDesc': 'To‘g‘ri qaror qabul qilishga yordam beradigan tavsiyalar.',
  },
  'kk': {
    'tools': 'Пайдалы құралдар',
    'application': 'Өтінім сомасы',
    'pending': 'Шешім күтілуде',
    'calculator': 'Калькулятор',
    'calcAmount': 'Сома',
    'term': 'Мерзім',
    'days': 'күн',
    'rate': 'Мөлшерлеме',
    'repay': 'Қайтарылатын сома',
    'tips': 'Пайдалы кеңестер',
    'tipsDesc': 'Дұрыс шешім қабылдауға көмектесетін ұсыныстар.',
  },
  'vi': {
    'tools': 'Công cụ hữu ích',
    'application': 'Đơn đăng ký',
    'pending': 'Đang chờ quyết định',
    'calculator': 'Máy tính',
    'calcAmount': 'Số tiền',
    'term': 'Thời hạn',
    'days': 'ngày',
    'rate': 'Lãi suất',
    'repay': 'Tổng hoàn trả',
    'tips': 'Lời khuyên hữu ích',
    'tipsDesc': 'Các đề xuất giúp bạn đưa ra quyết định phù hợp.',
  },
};

const _offerTexts = <String, Map<String, String>>{
  'en': {
    'offerSubtitle': "Compare and choose",
    'social': "Today 1558 people received a loan",
    'available': "Available offers",
    'amountFact': "Amount",
    'timeFact': "Processing time",
    'rateFact': "Interest rate",
    'openApp': "Open in app",
    'openBrowser': "Open in browser",
    'disclaimer': "Sumly is not a lender. Check the full cost and product terms on the partner website.",
    'unavailable': "Offers are temporarily unavailable",
    'tryLater': "Please try opening this section again later.",
  },
  'fil': {
    'offerSubtitle': "Ihambing at pumili",
    'social': "Ngayong araw, 1558 katao ang nakatanggap ng pautang",
    'available': "Mga available na alok",
    'amountFact': "Halaga",
    'timeFact': "Oras ng pagproseso",
    'rateFact': "Rate ng interes",
    'openApp': "Buksan sa app",
    'openBrowser': "Buksan sa browser",
    'disclaimer': "Hindi nagpapautang ang Sumly. Suriin ang kabuuang gastos at mga kondisyon ng produkto sa website ng kasosyo.",
    'unavailable': "Pansamantalang walang mga alok",
    'tryLater': "Pakisubukang buksan muli ang seksiyong ito mamaya.",
  },
  'ru': {
    'offerSubtitle': 'Сравнивай и выбирай',
    'social': 'Сегодня 1558 человек получили займ',
    'available': 'Доступные предложения',
    'amountFact': 'Сумма',
    'timeFact': 'Срок рассмотрения',
    'rateFact': 'Ставка',
    'openApp': 'Открыть в приложении',
    'openBrowser': 'Открыть в браузере',
    'disclaimer':
        'Sumly не является кредитором. Проверяйте полную стоимость и условия продукта на сайте партнёра.',
    'unavailable': 'Предложения временно недоступны',
    'tryLater': 'Попробуйте открыть этот раздел позже.',
  },
  'es-ar': {
    'offerSubtitle': 'Compará y elegí',
    'social': 'Hoy 1558 personas recibieron un préstamo',
    'available': 'Ofertas disponibles',
    'amountFact': 'Monto',
    'timeFact': 'Tiempo de revisión',
    'rateFact': 'Tasa',
    'openApp': 'Abrir en la aplicación',
    'openBrowser': 'Abrir en el navegador',
    'disclaimer':
        'Sumly no es un prestamista. Consulta el coste total y las condiciones en el sitio del socio.',
    'unavailable': 'Ofertas no disponibles',
    'tryLater': 'Inténtalo de nuevo más tarde.',
  },
  'es-mx': {
    'offerSubtitle': 'Compara y elige',
    'social': 'Hoy 1558 personas recibieron un préstamo',
    'available': 'Ofertas disponibles',
    'amountFact': 'Monto',
    'timeFact': 'Tiempo de revisión',
    'rateFact': 'Tasa',
    'openApp': 'Abrir en la aplicación',
    'openBrowser': 'Abrir en el navegador',
    'disclaimer':
        'Sumly no es un prestamista. Consulta el coste total y las condiciones en el sitio del socio.',
    'unavailable': 'Ofertas no disponibles',
    'tryLater': 'Inténtalo de nuevo más tarde.',
  },
  'uz': {
    'offerSubtitle': 'Solishtir va tanla',
    'social': 'Bugun 1558 kishi qarz oldi',
    'available': 'Mavjud takliflar',
    'amountFact': 'Summa',
    'timeFact': 'Ko‘rib chiqish muddati',
    'rateFact': 'Stavka',
    'openApp': 'Ilovada ochish',
    'openBrowser': 'Brauzerda ochish',
    'disclaimer':
        'Sumly kreditor emas. To‘liq narx va shartlarni hamkor saytida tekshiring.',
    'unavailable': 'Takliflar vaqtincha mavjud emas',
    'tryLater': 'Keyinroq qayta urinib ko‘ring.',
  },
  'kk': {
    'offerSubtitle': 'Салыстыр және таңда',
    'social': 'Бүгін 1558 адам қарыз алды',
    'available': 'Қолжетімді ұсыныстар',
    'amountFact': 'Сома',
    'timeFact': 'Қарау мерзімі',
    'rateFact': 'Мөлшерлеме',
    'openApp': 'Қосымшада ашу',
    'openBrowser': 'Браузерде ашу',
    'disclaimer':
        'Sumly кредитор емес. Толық құны мен шарттарын серіктес сайтынан тексеріңіз.',
    'unavailable': 'Ұсыныстар уақытша қолжетімсіз',
    'tryLater': 'Кейінірек қайталап көріңіз.',
  },
  'vi': {
    'offerSubtitle': 'So sánh và lựa chọn',
    'social': 'Hôm nay 1558 người đã nhận khoản vay',
    'available': 'Ưu đãi hiện có',
    'amountFact': 'Số tiền',
    'timeFact': 'Thời gian xét duyệt',
    'rateFact': 'Lãi suất',
    'openApp': 'Mở trong ứng dụng',
    'openBrowser': 'Mở trong trình duyệt',
    'disclaimer':
        'Sumly không phải là bên cho vay. Hãy kiểm tra đầy đủ chi phí và điều kiện trên trang đối tác.',
    'unavailable': 'Ưu đãi tạm thời không khả dụng',
    'tryLater': 'Vui lòng thử lại sau.',
  },
};

String marketText(String locale, String key) {
  final normalized = locale.toLowerCase().replaceAll('_', '-');
  final language = normalized == 'en' || normalized.startsWith('en-')
      ? 'en'
      : normalized == 'fil' ||
            normalized == 'tl' ||
            normalized.startsWith('fil-') ||
            normalized.startsWith('tl-')
      ? 'fil'
      : normalized;
  return _texts[language]?[key] ??
      _dashboardTexts[language]?[key] ??
      _offerTexts[language]?[key] ??
      _texts['ru']?[key] ??
      _dashboardTexts['ru']?[key] ??
      _offerTexts['ru']?[key] ??
      key;
}

