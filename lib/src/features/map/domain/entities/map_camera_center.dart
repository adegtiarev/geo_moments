class MapCameraCenter {
  const MapCameraCenter({required this.latitude, required this.longitude});

  static const buenosAires = MapCameraCenter(
    latitude: -34.6037,
    longitude: -58.3816,
  );

  final double latitude;
  final double longitude;

  bool isCloseTo(MapCameraCenter other) {
    const threshold = 0.0005;

    return (latitude - other.latitude).abs() < threshold &&
        (longitude - other.longitude).abs() < threshold;
  }

  @override
  bool operator ==(Object other) {
    return other is MapCameraCenter &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
