import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'provider_driver.dart';

class RealtimePlatformReports {
  RealtimePlatformReports(this.driverRegistry);
  final RealtimeDriverRegistry? driverRegistry;
  MediaPreJoinResult preJoin(MediaPreJoinResult result) {
    final registry = driverRegistry;
    final providerId = result.providerId;
    if (registry == null ||
        providerId == null ||
        !registry.knowsProvider(providerId) ||
        registry.supportsProvider(providerId)) {
      return result;
    }

    final platformCheck = MediaPreJoinCheck(
      type: MediaPreJoinCheckType.provider,
      status: MediaPreJoinStatus.unsupported,
      severity: MediaPreJoinSeverity.blocking,
      message:
          'Provider "$providerId" has no driver for '
          '${registry.platform.name}.',
      details: {'platform': registry.platform.name},
    );
    final checks = <MediaPreJoinCheck>[];
    var replaced = false;
    for (final check in result.checks) {
      if (check.type == MediaPreJoinCheckType.provider && !replaced) {
        checks.add(platformCheck);
        replaced = true;
      } else {
        checks.add(check);
      }
    }
    if (!replaced) checks.add(platformCheck);
    return MediaPreJoinResult(
      role: result.role,
      meetingMode: result.meetingMode,
      providerId: providerId,
      checks: List.unmodifiable(checks),
      backgroundCapabilities: result.backgroundCapabilities,
    );
  }

  MediaDoctorReport doctor(MediaDoctorReport report) {
    final registry = driverRegistry;
    final providerId = report.activeProvider;
    if (registry == null || providerId == null) {
      return report;
    }

    final known = registry.knowsProvider(providerId);
    final supported = known && registry.supportsProvider(providerId);

    final checks = report.checks
        .map((check) {
          if (check.id == 'providers') {
            return MediaDoctorCheck(
              id: check.id,
              status: registry.supportedProviderIds().isEmpty
                  ? MediaDoctorStatus.fail
                  : MediaDoctorStatus.pass,
              message:
                  'Registered public providers: '
                  '${registry.supportedProviderIds().join(', ')}.',
            );
          }
          if (check.id != 'active-provider') return check;
          if (supported) {
            return MediaDoctorCheck(
              id: check.id,
              status: MediaDoctorStatus.pass,
              message:
                  'Backend active provider $providerId is available on '
                  '${registry.platform.name}.',
            );
          }
          if (!known) return check;
          return MediaDoctorCheck(
            id: check.id,
            status: MediaDoctorStatus.fail,
            message:
                'Backend active provider $providerId has no driver for '
                '${registry.platform.name}.',
          );
        })
        .toList(growable: false);
    return MediaDoctorReport(
      List.unmodifiable(checks),
      activeProvider: report.activeProvider,
      activeChatProvider: report.activeChatProvider,
      backendReachable: report.backendReachable,
    );
  }
}
