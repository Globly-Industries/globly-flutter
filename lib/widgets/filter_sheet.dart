import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/filter_state.dart';
import '../theme.dart';
import 'common.dart';

/// Bottom sheet for choosing media types, age and minimum score.
Future<void> showFilterSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<FilterState>(),
        child: const _FilterSheet(),
      ),
    );

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<MediaType> _types;
  Duration? _maxAge;
  bool _positiveOnly = false;

  @override
  void initState() {
    super.initState();
    final f = context.read<FilterState>().filter;
    _types = {...f.types};
    _maxAge = f.maxAge;
    _positiveOnly = f.minScore != null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final ages = <Duration?, String>{
      null: l.anyTime,
      const Duration(days: 1): l.last24h,
      const Duration(days: 7): l.last7d,
      const Duration(days: 30): l.last30d,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.filters, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text(l.contentType, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in MediaType.values)
                FilterChip(
                  avatar: Icon(mediaIcon(t), size: 18, color: AppTheme.mediaColor(t)),
                  label: Text(mediaLabel(context, t)),
                  selected: _types.contains(t),
                  onSelected: (on) => setState(() => on ? _types.add(t) : _types.remove(t)),
                ),
            ]),
            const SizedBox(height: 20),
            Text(l.posted, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in ages.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _maxAge == e.key,
                  onSelected: (_) => setState(() => _maxAge = e.key),
                ),
            ]),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.positiveOnly),
              value: _positiveOnly,
              onChanged: (v) => setState(() => _positiveOnly = v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    context.read<FilterState>().filter = const PostFilter();
                    Navigator.pop(context);
                  },
                  child: Text(l.reset),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    context.read<FilterState>().filter =
                        PostFilter(types: _types, maxAge: _maxAge, minScore: _positiveOnly ? 1 : null);
                    Navigator.pop(context);
                  },
                  child: Text(l.apply),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
