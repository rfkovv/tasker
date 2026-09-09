import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/timezone_util.dart';

import '../../domain/app_settings_data.dart';
import '../providers/app_settings_provider.dart';
import '../providers/calendar_settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.settingsTheme,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppThemePreference>(
            segments: [
              ButtonSegment(
                value: AppThemePreference.system,
                icon: const Icon(Icons.brightness_auto),
                label: Text(l10n.themeSystem),
              ),
              ButtonSegment(
                value: AppThemePreference.light,
                icon: const Icon(Icons.light_mode),
                label: Text(l10n.themeLight),
              ),
              ButtonSegment(
                value: AppThemePreference.dark,
                icon: const Icon(Icons.dark_mode),
                label: Text(l10n.themeDark),
              ),
            ],
            selected: {settings.themePreference},
            onSelectionChanged: (selection) =>
                notifier.setThemePreference(selection.first),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.settingsLanguage,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppLanguage>(
            segments: [
              ButtonSegment(
                value: AppLanguage.en,
                label: Text(l10n.languageEnglish),
              ),
              ButtonSegment(
                value: AppLanguage.pl,
                label: Text(l10n.languagePolish),
              ),
            ],
            selected: {settings.language},
            onSelectionChanged: (selection) =>
                notifier.setLanguage(selection.first),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.settingsDefaultDueTime,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.access_time),
            label: Text(settings.defaultDueTime),
            onPressed: () async {
              final dueTime = ref.watch(defaultDueTimeProvider);
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: dueTime.hour,
                  minute: dueTime.minute,
                ),
              );
              if (picked != null) {
                await notifier.setDefaultDueTime(
                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                );
              }
            },
          ),
          const SizedBox(height: 24),
          Text(
            l10n.settingsTimezone,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _TimezoneSelector(
            value: settings.timezoneName.isEmpty
                ? tz.local.name
                : settings.timezoneName,
            onChanged: (name) => notifier.setTimezone(name),
          ),
        ],
      ),
    );
  }
}

class _TimezoneSelector extends StatefulWidget {
  const _TimezoneSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TimezoneSelector> createState() => _TimezoneSelectorState();
}

class _TimezoneSelectorState extends State<_TimezoneSelector> {
  @override
  void initState() {
    super.initState();
    initAppTimeZones();
  }

  @override
  Widget build(BuildContext context) {
    final zones = (tz.timeZoneDatabase.locations.keys).toList()..sort();
    final labelStyle = Theme.of(context).textTheme.bodyMedium;
    return DropdownButtonFormField<String>(
      initialValue: widget.value,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final name in zones)
          DropdownMenuItem(value: name, child: Text(name, style: labelStyle)),
      ],
      onChanged: (name) {
        if (name != null) widget.onChanged(name);
      },
    );
  }
}