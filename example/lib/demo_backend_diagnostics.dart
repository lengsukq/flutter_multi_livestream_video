import 'package:flutter/foundation.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

/// Observed state of the Demo backend. No Flutter widget owns the request.
class DemoBackendDiagnostics extends ChangeNotifier {
  final _diagnostics = <RealtimeException>[];
  List<RealtimeException> get diagnostics => List.unmodifiable(_diagnostics);
  bool? online;
  String? providerInfo;
  String? mediaProviderId;
  String? chatProviderId;
  bool testing = false;
  bool _requestInFlight = false;
  bool _disposed = false;
  int _generation = 0;

  void clear() => _setStatus(null, null, null, null);

  Future<void> refresh({
    required String url,
    required String Function() currentUrl,
    required Future<MediaDoctorReport> Function() diagnose,
    bool silent = false,
  }) async {
    if (_requestInFlight || _disposed) return;
    if (url.isEmpty) {
      _setStatus(false, 'No URL specified', null, null);
      return;
    }
    _requestInFlight = true;
    final generation = ++_generation;
    if (!silent) {
      testing = true;
      notifyListeners();
    }
    try {
      final report = await diagnose();
      if (_disposed || currentUrl() != url || generation != _generation) {
        return;
      }
      final backend = report.checkById('backend');
      final reachable = backend?.status != MediaDoctorStatus.fail;
      final info = reachable
          ? backend?.status == MediaDoctorStatus.warning
                ? 'Reachable (health unavailable)'
                : report.activeProvider == null
                ? 'Ready'
                : 'Default: ${mediaProviderDisplayName(report.activeProvider!)}'
          : report.backendReachable
          ? 'Health check failed'
          : 'Unreachable';
      _setStatus(
        reachable,
        info,
        report.activeProvider,
        report.activeChatProvider,
      );
    } catch (error, stack) {
      final failure = normalizeRealtimeException(error, domain: 'demo.backend', operation: 'diagnose', stackTrace: stack);
      if (_diagnostics.length == 32) _diagnostics.removeAt(0);
      _diagnostics.add(failure);
      if (!_disposed && currentUrl() == url && generation == _generation) {
        _setStatus(false, 'Unreachable', null, null);
      }
    } finally {
      _requestInFlight = false;
      if (!_disposed && !silent) {
        testing = false;
        notifyListeners();
      }
    }
  }

  void _setStatus(
    bool? nextOnline,
    String? nextInfo,
    String? nextMedia,
    String? nextChat,
  ) {
    if (_disposed ||
        (online == nextOnline &&
            providerInfo == nextInfo &&
            mediaProviderId == nextMedia &&
            chatProviderId == nextChat)) {
      return;
    }
    online = nextOnline;
    providerInfo = nextInfo;
    mediaProviderId = nextMedia;
    chatProviderId = nextChat;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
