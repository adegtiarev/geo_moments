import 'package:geo_moments/src/features/moments/domain/entities/moment_like_summary.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moment_likes_repository.dart';

class FakeMomentLikesRepository implements MomentLikesRepository {
  const FakeMomentLikesRepository();

  @override
  Future<MomentLikeSummary> fetchSummary(String momentId) async {
    return MomentLikeSummary(
      momentId: momentId,
      likeCount: 0,
      isLikedByMe: false,
    );
  }

  @override
  Future<MomentLikeSummary> likeMoment(String momentId) async {
    return MomentLikeSummary(
      momentId: momentId,
      likeCount: 1,
      isLikedByMe: true,
    );
  }

  @override
  Future<MomentLikeSummary> unlikeMoment(String momentId) async {
    return MomentLikeSummary(
      momentId: momentId,
      likeCount: 0,
      isLikedByMe: false,
    );
  }
}
