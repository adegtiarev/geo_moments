import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment_like_summary.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moment_likes_repository.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/moment_like_controller.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/moments_providers.dart';

void main() {
  test('likes moment optimistically and stores backend result', () async {
    final repository = FakeMomentLikesRepository();
    final seed = (momentId: 'moment-id', initialLikeCount: 2);
    final container = ProviderContainer(
      overrides: [momentLikesRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    expect(container.read(momentLikeControllerProvider(seed)).likeCount, 2);

    await Future<void>.delayed(Duration.zero);

    await container
        .read(momentLikeControllerProvider(seed).notifier)
        .setLiked(true);

    final state = container.read(momentLikeControllerProvider(seed));

    expect(repository.likeCalls, 1);
    expect(state.isLikedByMe, isTrue);
    expect(state.likeCount, 3);
    expect(state.isBusy, isFalse);
  });

  test('rolls back optimistic like when backend fails', () async {
    final repository = FakeMomentLikesRepository(shouldThrowOnLike: true);
    final seed = (momentId: 'moment-id', initialLikeCount: 2);
    final container = ProviderContainer(
      overrides: [momentLikesRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await Future<void>.delayed(Duration.zero);

    await container
        .read(momentLikeControllerProvider(seed).notifier)
        .setLiked(true);

    final state = container.read(momentLikeControllerProvider(seed));

    expect(repository.likeCalls, 1);
    expect(state.isLikedByMe, isFalse);
    expect(state.likeCount, 2);
    expect(state.error, isNotNull);
  });
}

class FakeMomentLikesRepository implements MomentLikesRepository {
  FakeMomentLikesRepository({this.shouldThrowOnLike = false});

  final bool shouldThrowOnLike;
  int likeCalls = 0;

  @override
  Future<MomentLikeSummary> fetchSummary(String momentId) async {
    return MomentLikeSummary(
      momentId: momentId,
      likeCount: 2,
      isLikedByMe: false,
    );
  }

  @override
  Future<MomentLikeSummary> likeMoment(String momentId) async {
    likeCalls += 1;

    if (shouldThrowOnLike) {
      throw StateError('like failed');
    }

    return MomentLikeSummary(
      momentId: momentId,
      likeCount: 3,
      isLikedByMe: true,
    );
  }

  @override
  Future<MomentLikeSummary> unlikeMoment(String momentId) async {
    return MomentLikeSummary(
      momentId: momentId,
      likeCount: 2,
      isLikedByMe: false,
    );
  }
}
