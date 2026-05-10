import 'package:geo_moments/src/features/moments/domain/entities/create_moment_command.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moments_repository.dart';

class FakeMomentsRepository implements MomentsRepository {
  const FakeMomentsRepository(this.moments);

  final List<Moment> moments;

  @override
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) async {
    return moments.take(limit).toList();
  }

  @override
  Future<Moment> fetchMomentById(String id) async {
    return moments.singleWhere((moment) => moment.id == id);
  }

  @override
  Future<Moment> createMoment(CreateMomentCommand command) async {
    return Moment(
      id: 'created-moment-id',
      authorId: command.authorId,
      latitude: command.latitude,
      longitude: command.longitude,
      text: command.text,
      emotion: command.emotion,
      mediaUrl: command.mediaUrl,
      mediaType: command.mediaType,
      createdAt: DateTime.utc(2026, 5, 10),
      authorDisplayName: 'Test User',
    );
  }
}

class ThrowingMomentsRepository implements MomentsRepository {
  const ThrowingMomentsRepository();

  @override
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) {
    throw StateError('offline');
  }

  @override
  Future<Moment> fetchMomentById(String id) {
    throw StateError('offline');
  }

  @override
  Future<Moment> createMoment(CreateMomentCommand command) {
    throw StateError('insert failed');
  }
}
