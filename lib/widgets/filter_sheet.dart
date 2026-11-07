import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/filter_state.dart';
import 'common.dart';

/// Bottom sheet for choosing media types, age and minimum score.
Future<void> showFilterSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      showDragHandle: true,
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
  static const _ages = <String, Duration?>{
    'Any time': null,
    '24 h': Duration(days: 1),
    'Week': Duration(days: 7),
    'Month': Duration(days: 30),
  };

  late Set<MediaType> _types;
  Duration? _maxAge;
  bool _popularOnly = false;

  @override
  void initState() {
    super.initState();
    final f = context.read<FilterState>().filter;
    _types = {...f.types};
    _maxAge = f.maxAge;
    _popularOnly = f.minScore != null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Content type', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: [
                for (final t in MediaType.values)
                  FilterChip(
                    avatar: Icon(mediaIcon(t), size: 18),
                    label: Text(t.apiName),
                    selected: _types.contains(t),
                    onSelected: (on) => setState(() => on ? _types.add(t) : _types.remove(t)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Posted within', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: [
                for (final e in _ages.entries)
                  ChoiceChip(
                    label: Text(e.key),
                    selected: _maxAge == e.value,
                    onSelected: (_) => setState(() => _maxAge = e.value),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Only positively rated'),
              value: _popularOnly,
              onChanged: (v) => setState(() => _popularOnly = v),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    context.read<FilterState>().filter = const PostFilter();
                    Navigator.pop(context);
                  },
                  child: const Text('Reset'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    context.read<FilterState>().filter =
                        PostFilter(types: _types, maxAge: _maxAge, minScore: _popularOnly ? 1 : null);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
