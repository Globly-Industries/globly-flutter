import 'package:flutter/material.dart';

import 'common.dart';

// Same rule as the API's NotificationService: "@name" not preceded by a user-name character.
final _mention = RegExp(r'(?<![A-Za-z0-9._-])@[A-Za-z0-9._-]{3,32}');

/// Comment text with @mentions highlighted.
class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const MentionText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final mentionStyle = TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600);
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _mention.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(TextSpan(text: m[0], style: mentionStyle));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

/// Small "Reply" link under a comment.
class ReplyButton extends StatelessWidget {
  final VoidCallback onPressed;
  const ReplyButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            context.l10n.reply,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Starts a reply to [userName]: puts "@userName " at the front of the comment field and focuses it.
void startReply(TextEditingController controller, FocusNode focus, String userName) {
  final tag = '@$userName ';
  final text = controller.text.startsWith(tag) ? controller.text : tag + controller.text;
  controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  focus.requestFocus();
}
