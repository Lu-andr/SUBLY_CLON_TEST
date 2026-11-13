import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/subscription.dart';
import '../../../data/providers/app_state.dart';
import 'subscriptions_screen.dart';

class SubscriptionDetailScreen extends StatelessWidget {
  const SubscriptionDetailScreen({
    required this.state,
    required this.id,
    required this.onBack,
    super.key,
  });
  final AppState state;
  final String id;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final subscription = state.subscriptions
        .where((item) => item.id == id)
        .firstOrNull;
    if (subscription == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: onBack)),
        body: const Center(child: Text('Подписка не найдена')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: const Text('Детали подписки'),
        actions: [
          IconButton(
            onPressed: () async {
              final updated = await showModalBottomSheet<Subscription>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (_) => AddSubscriptionSheet(initial: subscription),
              );
              if (updated != null) {
                await state.updateSubscription(updated);
              }
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Удалить подписку?'),
                  content: Text(
                    '${subscription.name} будет удалена с устройства.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Удалить'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await state.deleteSubscription(id);
                onBack();
              }
            },
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: SublyColors.red,
            ),
          ),
        ],
      ),
      body: PageContainer(
        children: [
          Center(
            child: Column(
              children: [
                ServiceIcon(subscription: subscription, size: 82),
                const SizedBox(height: 14),
                Text(
                  subscription.name,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Chip(
                  label: Text(
                    subscription.status == SubscriptionStatus.active
                        ? 'Активна'
                        : 'Приостановлена',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Info(
                        label: 'Стоимость',
                        value: '₽${subscription.price.toStringAsFixed(2)}',
                      ),
                    ),
                    Expanded(
                      child: _Info(
                        label: 'Следующий платёж',
                        value: DateFormat('dd.MM')
                            .format(subscription.nextPayment),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 34),
                Row(
                  children: [
                    Expanded(
                      child: _Info(
                        label: 'Потрачено всего',
                        value: '₽${subscription.totalSpent.toStringAsFixed(2)}',
                      ),
                    ),
                    Expanded(
                      child: _Info(
                        label: 'Расходы за год',
                        value:
                            '₽${(subscription.monthlyPrice * 12).toStringAsFixed(2)}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Информация',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                _Line(
                  label: 'Категория',
                  value: _categoryName(subscription.category),
                ),
                _Line(label: 'Период', value: _periodName(subscription.period)),
                _Line(
                  label: 'Напоминание',
                  value: subscription.reminders
                      ? 'За ${subscription.reminderDays} дн.'
                      : 'Выключено',
                ),
                _Line(
                  label: 'Заметка',
                  value: subscription.note.isEmpty
                      ? 'Нет заметки'
                      : subscription.note,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'История платежей',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                if (subscription.totalSpent == 0)
                  const Text('Платежей пока нет')
                else
                  ...List.generate(
                    3,
                    (i) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.check_rounded),
                      ),
                      title: Text(
                        DateFormat('dd.MM.yyyy').format(
                          DateTime(
                            subscription.nextPayment.year,
                            subscription.nextPayment.month - i - 1,
                            subscription.nextPayment.day,
                          ),
                        ),
                      ),
                      trailing: Text(
                        '₽${subscription.price.toStringAsFixed(2)}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Отметить оплаченным',
            icon: Icons.check_rounded,
            onPressed: () async {
              await state.markPaid(id, expectedDue: subscription.nextPayment);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Платёж записан')));
              }
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => state.toggleStatus(id),
            icon: Icon(
              subscription.status == SubscriptionStatus.active
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
            label: Text(
              subscription.status == SubscriptionStatus.active
                  ? 'Приостановить подписку'
                  : 'Возобновить подписку',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 5),
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

String _periodName(BillingPeriod value) => switch (value) {
  BillingPeriod.weekly => 'Еженедельно',
  BillingPeriod.monthly => 'Ежемесячно',
  BillingPeriod.quarterly => 'Раз в 3 месяца',
  BillingPeriod.halfYearly => 'Раз в 6 месяцев',
  BillingPeriod.yearly => 'Ежегодно',
  BillingPeriod.custom => 'Другой',
};

String _categoryName(String value) =>
    const {
      'Entertainment': 'Развлечения',
      'Music': 'Музыка',
      'Productivity': 'Продуктивность',
      'Cloud': 'Облако',
      'Health': 'Здоровье',
      'Other': 'Другое',
    }[value] ??
    value;
