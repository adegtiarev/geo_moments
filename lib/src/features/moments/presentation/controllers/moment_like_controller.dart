import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'moments_providers.dart';

typedef MomentLikeSeed = ({String momentId, int initialLikeCount});

class MomentLikeState {
  const MomentLikeState({
    required this.momentId,
    required this.likeCount,
    this.isLikedByMe = false,
    this.isBusy = false,
    this.error,
  });

  final String momentId;
  final int likeCount;
  final bool isLikedByMe;
  final bool isBusy;
  final Object? error;

  MomentLikeState copyWith({
    int? likeCount,
    bool? isLikedByMe,
    bool? isBusy,
    Object? error,
    bool clearError = false,
  }) {
    return MomentLikeState(
      momentId: momentId,
      likeCount: likeCount ?? this.likeCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final momentLikeControllerProvider =
    NotifierProvider.family<
      MomentLikeController,
      MomentLikeState,
      MomentLikeSeed
    >(MomentLikeController.new);

class MomentLikeController extends Notifier<MomentLikeState> {
  MomentLikeController(this._seed);

  final MomentLikeSeed _seed;

  @override
  MomentLikeState build() {
    unawaited(Future<void>.microtask(_loadSummary));

    return MomentLikeState(
      momentId: _seed.momentId,
      likeCount: _seed.initialLikeCount,
    );
  }

  Future<void> setLiked(bool shouldLike) async {
    final previous = state;

    if (previous.isBusy || previous.isLikedByMe == shouldLike) {
      return;
    }

    state = previous.copyWith(
      isLikedByMe: shouldLike,
      likeCount: _optimisticCount(previous, shouldLike),
      isBusy: true,
      clearError: true,
    );

    try {
      final repository = ref.read(momentLikesRepositoryProvider);
      final summary = shouldLike
          ? await repository.likeMoment(_seed.momentId)
          : await repository.unlikeMoment(_seed.momentId);

      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(
        likeCount: summary.likeCount,
        isLikedByMe: summary.isLikedByMe,
        isBusy: false,
        clearError: true,
      );

      ref.invalidate(momentDetailsProvider(_seed.momentId));
      ref.invalidate(nearbyMomentsProvider);
    } catch (error) {
      if (!ref.mounted) {
        return;
      }

      state = previous.copyWith(isBusy: false, error: error);
    }
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await ref
          .read(momentLikesRepositoryProvider)
          .fetchSummary(_seed.momentId);

      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(
        likeCount: summary.likeCount,
        isLikedByMe: summary.isLikedByMe,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(error: error);
    }
  }

  int _optimisticCount(MomentLikeState previous, bool shouldLike) {
    if (shouldLike) {
      return previous.likeCount + 1;
    }

    final next = previous.likeCount - 1;
    return next < 0 ? 0 : next;
  }
}
