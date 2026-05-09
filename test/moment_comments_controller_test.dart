import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/features/moments/domain/entities/create_comment_command.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment_comment.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moment_comments_repository.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/moment_comments_controller.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/moments_providers.dart';

void main() {
  test('loads comments with fake repository override', () async {
    final repository = FakeMomentCommentsRepository();
    final container = ProviderContainer(
      overrides: [
        momentCommentsRepositoryProvider.overrideWithValue(repository),
        momentCommentsRealtimeEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    final comments = await container.read(
      momentCommentsControllerProvider('moment-id').future,
    );

    expect(repository.fetchCalls, 1);
    expect(comments, hasLength(1));
    expect(comments.single.body, 'First comment');
  });

  test('addRootComment sends command without parent id', () async {
    final repository = FakeMomentCommentsRepository();
    final container = ProviderContainer(
      overrides: [
        momentCommentsRepositoryProvider.overrideWithValue(repository),
        momentCommentsRealtimeEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    await container.read(momentCommentsControllerProvider('moment-id').future);
    await container
        .read(momentCommentsControllerProvider('moment-id').notifier)
        .addRootComment(' Root comment ');

    expect(repository.created, hasLength(1));
    expect(repository.created.single.momentId, 'moment-id');
    expect(repository.created.single.parentId, isNull);
    expect(repository.created.single.body, 'Root comment');
  });

  test('addReply sends command with parent id', () async {
    final repository = FakeMomentCommentsRepository();
    final container = ProviderContainer(
      overrides: [
        momentCommentsRepositoryProvider.overrideWithValue(repository),
        momentCommentsRealtimeEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    await container.read(momentCommentsControllerProvider('moment-id').future);
    await container
        .read(momentCommentsControllerProvider('moment-id').notifier)
        .addReply(parentId: 'comment-1', body: 'Reply text');

    expect(repository.created, hasLength(1));
    expect(repository.created.single.parentId, 'comment-1');
    expect(repository.created.single.body, 'Reply text');
  });

  test('restores previous comments and rethrows when create fails', () async {
    final repository = FakeMomentCommentsRepository(shouldThrowOnCreate: true);
    final container = ProviderContainer(
      overrides: [
        momentCommentsRepositoryProvider.overrideWithValue(repository),
        momentCommentsRealtimeEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    final initialComments = await container.read(
      momentCommentsControllerProvider('moment-id').future,
    );

    await expectLater(
      container
          .read(momentCommentsControllerProvider('moment-id').notifier)
          .addRootComment('Will fail'),
      throwsStateError,
    );

    expect(
      container.read(momentCommentsControllerProvider('moment-id')).value,
      initialComments,
    );
  });
}

class FakeMomentCommentsRepository implements MomentCommentsRepository {
  FakeMomentCommentsRepository({this.shouldThrowOnCreate = false});

  final bool shouldThrowOnCreate;
  final created = <CreateCommentCommand>[];
  int fetchCalls = 0;

  @override
  Future<List<MomentComment>> fetchCommentsPage({
    required String momentId,
    int limit = 20,
    DateTime? before,
  }) async {
    fetchCalls += 1;

    return [
      MomentComment(
        id: 'comment-1',
        momentId: momentId,
        authorId: 'user-1',
        body: 'First comment',
        createdAt: DateTime.utc(2026, 5, 9),
        authorDisplayName: 'Test User',
      ),
    ];
  }

  @override
  Future<MomentComment> createComment(CreateCommentCommand command) async {
    if (shouldThrowOnCreate) {
      throw StateError('create failed');
    }

    created.add(command);
    return MomentComment(
      id: 'created-comment',
      momentId: command.momentId,
      authorId: 'user-1',
      parentId: command.parentId,
      body: command.body,
      createdAt: DateTime.utc(2026, 5, 9),
      authorDisplayName: 'Test User',
    );
  }
}
