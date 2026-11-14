import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import 'common.dart';

/// Award colour, used wherever awards show.
const awardColor = Color(0xFFFFC53D);

/// Gives [post] an award after showing what it costs. Returns the updated post, or null if nothing changed.
Future<Post?> giveAward(BuildContext context, Post post) async {
  final l = context.l10n;
  final auth = context.read<AuthState>();
  final api = context.read<ApiClient>();
  if (!auth.isSignedIn) {
    showMessage(context, l.signInToAward);
    return null;
  }
  if (auth.user?.id == post.author.id) {
    showMessage(context, l.errCannotAwardOwn);
    return null;
  }
  if (post.myAward) {
    showMessage(context, l.errAlreadyAwarded);
    return null;
  }
  try {
    final info = await api.points();
    if (!context.mounted) return null;
    if (info.awardsLeftToday == 0) {
      showMessage(context, l.errAwardLimit);
      return null;
    }
    if (info.balance < info.awardCost) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.awardTitle),
          content: Text(l.awardTooPoor(info.awardCost, info.balance)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok))],
        ),
      );
      return null;
    }
    final ok = await confirm(
      context,
      l.awardTitle,
      l.awardBody(info.awardCost, post.author.userName, info.balance, info.awardsLeftToday),
      action: l.award,
    );
    if (!ok) return null;
    final r = await api.award(post.id);
    if (context.mounted) showMessage(context, l.awardDone(post.author.userName, r.balance));
    return post.copyWith(awardCount: r.awardCount, myAward: true);
  } catch (e) {
    if (context.mounted) showMessage(context, e);
    return null;
  }
}
