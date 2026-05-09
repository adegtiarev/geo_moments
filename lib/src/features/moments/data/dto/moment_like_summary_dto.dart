import '../../domain/entities/moment_like_summary.dart';

class MomentLikeSummaryDto {
  const MomentLikeSummaryDto({
    required this.momentId,
    required this.likeCount,
    required this.isLikedByMe,
  });

  final String momentId;
  final int likeCount;
  final bool isLikedByMe;

  factory MomentLikeSummaryDto.fromJson(Map<String, dynamic> json) {
    return MomentLikeSummaryDto(
      momentId: json['moment_id'] as String,
      likeCount: (json['like_count'] as num).toInt(),
      isLikedByMe: json['is_liked_by_me'] as bool,
    );
  }

  MomentLikeSummary toDomain() {
    return MomentLikeSummary(
      momentId: momentId,
      likeCount: likeCount,
      isLikedByMe: isLikedByMe,
    );
  }
}
