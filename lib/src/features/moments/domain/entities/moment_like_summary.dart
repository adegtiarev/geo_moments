class MomentLikeSummary {
  const MomentLikeSummary({
    required this.momentId,
    required this.likeCount,
    required this.isLikedByMe,
  });

  final String momentId;
  final int likeCount;
  final bool isLikedByMe;
}
