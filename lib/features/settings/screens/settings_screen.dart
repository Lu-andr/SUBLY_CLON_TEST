import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../../core/animations/app_animations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/providers/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.state,
    required this.onPrivacy,
    required this.onTerms,
    required this.onAbout,
    super.key,
  });
  final AppState state;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final VoidCallback onAbout;
  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить все данные?'),
        content: const Text(
          'Подписки и настройки будут удалены с этого устройства.',
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
      await state.clearData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Локальные данные удалены')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageContainer(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Настройки',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          _ThemeButton(state: state),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'Настройте Sumly под себя.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 22),
      FadeSlideIn(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [SublyColors.navy, SublyColors.purple],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: SublyColors.purple.withValues(alpha: .22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Color(0x26FFFFFF),
                child: Icon(Icons.tune_rounded, color: Colors.white, size: 28),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ваше пространство',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Внешний вид и уведомления',
                      style: TextStyle(color: Color(0xFFD0D5DD)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      const SectionHeader(title: 'Предпочтения'),
      const SizedBox(height: 10),
      AppCard(
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Уведомления'),
              subtitle: const Text('Напоминания о продлении'),
              value: state.settings.notifications,
              onChanged: (value) => state.updateSettings(
                state.settings.copyWith(notifications: value),
              ),
            ),
            _ReminderField(
              value: state.settings.reminderDays,
              enabled: state.settings.notifications,
              onChanged: (value) => state.updateSettings(
                state.settings.copyWith(reminderDays: value),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const SectionHeader(title: 'Данные'),
      const SizedBox(height: 10),
      AppCard(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Экспортировать данные'),
              subtitle: const Text('Скопировать резервную копию'),
              onTap: () async {
                final payload = jsonEncode({
                  'subscriptions': state.subscriptions
                      .map((item) => item.toJson())
                      .toList(),
                  'settings': state.settings.toJson(),
                });
                await Clipboard.setData(ClipboardData(text: payload));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Данные скопированы')),
                  );
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.delete_sweep_outlined,
                color: SublyColors.red,
              ),
              title: const Text('Удалить все данные'),
              onTap: () => _clear(context),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const SectionHeader(title: 'О приложении'),
      const SizedBox(height: 10),
      AppCard(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Политика конфиденциальности'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onPrivacy,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: const Text('Условия использования'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onTerms,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('О Sumly'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onAbout,
            ),
          ],
        ),
      ),
    ],
  );
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: dark ? 'Светлая тема' : 'Тёмная тема',
      child: InkWell(
        onTap: () => state.updateSettings(
          state.settings.copyWith(themeMode: dark ? 'light' : 'dark'),
        ),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: AppAnimations.standard,
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: dark
                  ? [const Color(0xFF2B3448), SublyColors.navy]
                  : [SublyColors.purple, SublyColors.accent],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: SublyColors.purple.withValues(alpha: .22),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: AppAnimations.standard,
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween(begin: .7, end: 1.0).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(dark),
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderField extends StatelessWidget {
  const _ReminderField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : .45,
    child: InkWell(
      onTap: !enabled
          ? null
          : () async {
              final selected = await showModalBottomSheet<int>(
                context: context,
                showDragHandle: true,
                builder: (context) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Когда напомнить',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 14),
                        ...[1, 2, 3, 5, 7].map(
                          (days) => Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: ListTile(
                              onTap: () => Navigator.pop(context, days),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              tileColor: days == value
                                  ? SublyColors.purple.withValues(alpha: .12)
                                  : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: .35),
                              leading: CircleAvatar(
                                backgroundColor: days == value
                                    ? SublyColors.purple
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                child: days == value
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                      )
                                    : Text('$days'),
                              ),
                              title: Text(
                                'За $days дн.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              if (selected != null) onChanged(selected);
            },
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_active_rounded,
              color: SublyColors.purple,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Напоминать заранее',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'За $value дн.',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    ),
  );
}
