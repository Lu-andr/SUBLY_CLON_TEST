import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) => const _LegalPage(
    title: 'Политика конфиденциальности',
    sections: [
      (
        'Данные остаются на устройстве',
        'Sumly хранит подписки, финансовые записи, настройки и статус знакомства с приложением локально. Аккаунт не требуется, данные не отправляются на наши серверы.',
      ),
      (
        'Разрешения и отслеживание',
        'Sumly не запрашивает чувствительные разрешения и не содержит рекламы, аналитики или средств межприложного отслеживания.',
      ),
      (
        'Управление данными',
        'Локальные данные можно удалить в настройках. При удалении приложения они также могут быть удалены в зависимости от настроек резервного копирования устройства.',
      ),
      (
        'Расчёты',
        'Данные калькуляторов обрабатываются только на устройстве и никуда не загружаются.',
      ),
    ],
  );
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _LegalPage(
    title: 'Условия использования',
    sections: [
      (
        'Назначение',
        'Sumly — инструмент для личного учёта и примерных расчётов. Приложение не подключается к банкам, не переводит деньги и не отменяет подписки.',
      ),
      (
        'Ответственность пользователя',
        'Вы отвечаете за точность введённых данных и проверку дат и сумм у поставщиков услуг.',
      ),
      (
        'Финансовая оговорка',
        'Расчёты кредита, накоплений, процентов и расходов являются ориентировочными и не считаются финансовой, кредитной, налоговой или инвестиционной рекомендацией.',
      ),
      (
        'Доступность',
        'Возможности приложения могут меняться. Сохраняйте отдельные копии важной информации.',
      ),
    ],
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => const _LegalPage(
    title: 'О Sumly',
    sections: [
      (
        'Sumly 1.0.0',
        'Спокойный и приватный способ следить за регулярными платежами, понимать расходы и выполнять повседневные финансовые расчёты.',
      ),
      (
        'Создано для ясности',
        'Sumly показывает подписки без подключения банковского счёта.',
      ),
    ],
  );
}

class _LegalPage extends StatelessWidget {
  const _LegalPage({required this.title, required this.sections});
  final String title;
  final List<(String, String)> sections;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: sections
          .map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.$1,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.$2,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.55),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    ),
  );
}
