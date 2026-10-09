import 'dart:async';
import 'failure.dart';

class CleanupFailure {
  const CleanupFailure(this.stage, this.error, this.stackTrace);
  final String stage;
  final Object error;
  final StackTrace stackTrace;
}

/// Performs dependent steps in order without skipping resources after failures.
class Cleanup {
  Cleanup({this.timeout = const Duration(seconds: 10)});
  final Duration timeout;
  final List<CleanupFailure> _failures = [];

  Future<void> run(String stage, FutureOr<void> Function() release) async {
    try {
      await Future<void>.sync(release).timeout(timeout);
    } catch (error, stack) {
      _failures.add(CleanupFailure(stage, error, stack));
    }
  }

  void finish({String? domain, Object? cause}) {
    if (_failures.isEmpty) return;
    if (cause != null) {
      // Rollback is secondary to the failed operation. Preserve the original
      // classification and attach every cleanup failure for diagnostics.
      // A standalone dispose (without a primary error) remains cleanupFailed.
      final primary = normalizeRealtimeException(cause, domain: domain);
      throw RealtimeException(
        code: primary.code,
        message: primary.message,
        domain: primary.domain,
        operation: primary.operation,
        providerId: primary.providerId,
        statusCode: primary.statusCode,
        recoverable: primary.recoverable,
        suggestedAction: primary.suggestedAction,
        cause: primary.cause ?? cause,
        details: {
          if (primary.details != null) 'originalDetails': primary.details,
          'cleanupFailures': List<CleanupFailure>.unmodifiable(_failures),
        },
        stackTrace: primary.stackTrace,
      );
    }
    throw RealtimeException(
      code: RealtimeErrorCode.cleanupFailed,
      message:
          'Unable to release: ${_failures.map((f) => f.stage).join(', ')}.',
      domain: domain,
      operation: 'dispose',
      cause: cause,
      details: List<CleanupFailure>.unmodifiable(_failures),
      stackTrace: _failures.first.stackTrace,
    );
  }
}
