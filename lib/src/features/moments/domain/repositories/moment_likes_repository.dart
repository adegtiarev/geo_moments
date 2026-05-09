import '../entities/moment_like_summary.dart';

abstract interface class MomentLikesRepository {
  Future<MomentLikeSummary> fetchSummary(String momentId);

  Future<MomentLikeSummary> likeMoment(String momentId);

  Future<MomentLikeSummary> unlikeMoment(String momentId);
}
