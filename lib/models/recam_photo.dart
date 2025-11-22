class ReCamPhoto {
  final String path;
  final DateTime createdAt;
  final String? filterId;
  final String? frameId;

  const ReCamPhoto({
    required this.path,
    required this.createdAt,
    this.filterId,
    this.frameId,
  });
}
