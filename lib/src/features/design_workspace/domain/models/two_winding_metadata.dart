class TwoWindingMetadata {
  const TwoWindingMetadata({
    required this.routeId,
    required this.entityId,
    required this.designId,
    required this.createdAt,
  });

  const TwoWindingMetadata.initial({required this.routeId})
    : entityId = '',
      designId = '',
      createdAt = '';

  final String routeId;
  final String entityId;
  final String designId;
  final String createdAt;

  TwoWindingMetadata copyWith({
    String? routeId,
    String? entityId,
    String? designId,
    String? createdAt,
  }) {
    return TwoWindingMetadata(
      routeId: routeId ?? this.routeId,
      entityId: entityId ?? this.entityId,
      designId: designId ?? this.designId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
