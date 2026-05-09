import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../../core/backend/supabase_client_provider.dart';
import '../../domain/entities/create_comment_command.dart';
import '../../domain/entities/moment_comment.dart';
import 'moments_providers.dart';

final momentCommentsControllerProvider =
    AsyncNotifierProvider.family<
      MomentCommentsController,
      List<MomentComment>,
      String
    >(MomentCommentsController.new);

final momentCommentsRealtimeEnabledProvider = Provider<bool>((ref) {
  return true;
});

class MomentCommentsController extends AsyncNotifier<List<MomentComment>> {
  MomentCommentsController(this._momentId);

  final String _momentId;
  RealtimeChannel? _channel;

  @override
  Future<List<MomentComment>> build() async {
    if (ref.read(momentCommentsRealtimeEnabledProvider)) {
      _subscribeToRealtime();
    }
    return _fetch();
  }

  Future<void> addRootComment(String body) {
    return _create(body: body);
  }

  Future<void> addReply({required String parentId, required String body}) {
    return _create(body: body, parentId: parentId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> _create({required String body, String? parentId}) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final previous = state.value ?? const <MomentComment>[];

    state = await AsyncValue.guard(() async {
      await ref
          .read(momentCommentsRepositoryProvider)
          .createComment(
            CreateCommentCommand(
              momentId: _momentId,
              parentId: parentId,
              body: trimmed,
            ),
          );

      final comments = await _fetch();

      ref.invalidate(momentDetailsProvider(_momentId));
      ref.invalidate(nearbyMomentsProvider);

      return comments;
    });

    if (state.hasError) {
      final error = state.error!;
      if (previous.isNotEmpty) {
        state = AsyncData(previous);
      }
      Error.throwWithStackTrace(error, state.stackTrace ?? StackTrace.current);
    }
  }

  Future<List<MomentComment>> _fetch() {
    return ref
        .read(momentCommentsRepositoryProvider)
        .fetchCommentsPage(momentId: _momentId);
  }

  void _subscribeToRealtime() {
    if (_channel != null) {
      return;
    }

    final client = ref.read(supabaseClientProvider);
    final channel = client.channel('moment-comments:$_momentId');
    _channel = channel;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'moment_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'moment_id',
            value: _momentId,
          ),
          callback: (_) {
            unawaited(refresh());
          },
        )
        .subscribe();

    ref.onDispose(() {
      final activeChannel = _channel;
      if (activeChannel != null) {
        unawaited(client.removeChannel(activeChannel));
      }
    });
  }
}
