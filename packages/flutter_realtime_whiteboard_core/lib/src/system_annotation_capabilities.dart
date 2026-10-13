/// Availability of an actual system overlay, distinct from in-app annotation.
class SystemAnnotationCapabilities {
  const SystemAnnotationCapabilities({
    required this.supported,
    this.permissionRequired = false,
    this.reason = '',
  });
  final bool supported, permissionRequired;
  final String reason;
}
