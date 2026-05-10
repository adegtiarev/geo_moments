import 'package:geo_moments/src/app/config/app_config.dart';
import 'package:geo_moments/src/features/auth/domain/entities/app_user.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment.dart';

const testAppConfig = AppConfig(
  supabaseUrl: 'https://test.supabase.co',
  supabaseAnonKey: 'test-anon-key',
  authRedirectUrl: 'test_redirect_url',
  mapboxAccessToken: 'test_token',
);

const testUser = AppUser(
  id: 'test-user-id',
  email: 'test@example.com',
  displayName: 'Test User',
);

final testMoment = Moment(
  id: 'test-moment-id',
  authorId: testUser.id,
  latitude: -34.6037,
  longitude: -58.3816,
  text: 'Test coffee moment',
  mediaType: 'none',
  createdAt: DateTime.utc(2026, 5, 5),
  authorDisplayName: testUser.displayName,
);

final testMoments = [testMoment];
