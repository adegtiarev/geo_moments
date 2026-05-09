import '../entities/create_moment_command.dart';
import '../entities/moment.dart';

abstract interface class MomentsRepository {
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  });

  Future<Moment> fetchMomentById(String id);

  Future<Moment> createMoment(CreateMomentCommand command);
}
