import 'dart:math';

import '../debug_error_info.dart';
import 'payload_sanitizer.dart';
import 'redactor.dart';

/// Structured result of entry-level sanitization and budgeting.
class SanitizedEntryResult {
  const SanitizedEntryResult({
    required this.message,
    this.tag,
    this.subTag,
    this.error,
    this.stackTrace,
    this.metadata,
    this.json,
    required this.truncated,
  });

  /// The sanitized, redacted, and bounded log message.
  final String message;

  /// Optional sanitized primary tag.
  final String? tag;

  /// Optional sanitized secondary sub-tag.
  final String? subTag;

  /// Optional sanitized error info.
  final DebugErrorInfo? error;

  /// Optional sanitized stack trace.
  final String? stackTrace;

  /// Optional sanitized JSON-safe metadata map.
  final Map<String, Object?>? metadata;

  /// Optional sanitized JSON-safe payload.
  final Object? json;

  /// Whether any field cut, omission, or traversal cap occurred.
  final bool truncated;
}

/// Enforces the combined per-entry character budget and deterministic retention
/// priority per DATA_MODELS.md §6.
///
/// Priority order: tag/subTag -> message -> error -> stack trace -> metadata -> json.
class EntrySanitizer {
  /// Creates an entry sanitizer with [redactor] and [payloadSanitizer].
  EntrySanitizer({DebugRedactor? redactor, PayloadSanitizer? payloadSanitizer})
    : redactor = redactor ?? DebugRedactor(),
      payloadSanitizer =
          payloadSanitizer ??
          PayloadSanitizer(redactor: redactor ?? DebugRedactor());

  /// The redactor used for key matching and value pattern substitution.
  final DebugRedactor redactor;

  /// The payload sanitizer used for JSON-safe metadata and payload conversion.
  final PayloadSanitizer payloadSanitizer;

  /// Field caps defined in DATA_MODELS.md §6 and SECURITY_PERFORMANCE.md §4.
  static const int tagCap = 100;
  static const int errorTypeCap = 200;

  /// Sanitizes all entry fields according to the retention priority and budgets.
  SanitizedEntryResult sanitize({
    required String rawMessage,
    String? rawTag,
    String? rawSubTag,
    Object? rawError,
    StackTrace? rawStackTrace,
    Map<String, Object?>? rawMetadata,
    Object? rawJson,
    int maxEntryChars = 40000,
    int maxMessageLength = 8000,
    int maxStackTraceLength = 16000,
    int maxPayloadLength = 32000,
  }) {
    var remaining = maxEntryChars;
    var isTruncated = false;

    // 1. Tag (priority 1)
    String? sanitizedTag;
    if (rawTag != null) {
      final redactedTag = redactor.redactTag(rawTag);
      final allowed = min(tagCap, remaining);
      if (allowed < PayloadSanitizer.markerLength) {
        sanitizedTag = null;
        isTruncated = true;
      } else {
        sanitizedTag = PayloadSanitizer.truncateString(
          redactedTag,
          allowed,
          onTruncated: () => isTruncated = true,
        );
        remaining -= sanitizedTag.length;
      }
    }

    // 2. SubTag (priority 1)
    String? sanitizedSubTag;
    if (rawSubTag != null) {
      final redactedSubTag = redactor.redactTag(rawSubTag);
      final allowed = min(tagCap, remaining);
      if (allowed < PayloadSanitizer.markerLength) {
        sanitizedSubTag = null;
        isTruncated = true;
      } else {
        sanitizedSubTag = PayloadSanitizer.truncateString(
          redactedSubTag,
          allowed,
          onTruncated: () => isTruncated = true,
        );
        remaining -= sanitizedSubTag.length;
      }
    }

    // 3. Message (priority 2)
    final redactedMessage = redactor.redactMessage(
      rawMessage,
      maxMessageLength: maxMessageLength,
    );
    final msgAllowed = min(maxMessageLength, remaining);
    String sanitizedMessage;
    if (msgAllowed < PayloadSanitizer.markerLength) {
      sanitizedMessage = '';
      isTruncated = true;
    } else {
      sanitizedMessage = PayloadSanitizer.truncateString(
        redactedMessage,
        msgAllowed,
        onTruncated: () => isTruncated = true,
      );
      remaining -= sanitizedMessage.length;
    }

    // 4. Error (priority 3)
    DebugErrorInfo? sanitizedError;
    if (rawError != null) {
      String rawType;
      String rawMsg;
      if (rawError is DebugErrorInfo) {
        rawType = rawError.type;
        rawMsg = rawError.message;
      } else {
        try {
          rawType = rawError.runtimeType.toString();
        } catch (_) {
          rawType = 'UnknownError';
        }
        try {
          rawMsg = rawError.toString();
        } catch (_) {
          rawMsg = '[Unprintable]';
        }
      }

      final redactedErrorMsg = redactor.redactErrorMessage(
        rawMsg,
        maxMessageLength: maxMessageLength,
      );

      final typeAllowed = min(errorTypeCap, remaining);
      String typeStr;
      if (typeAllowed < PayloadSanitizer.markerLength) {
        typeStr = '';
        isTruncated = true;
      } else {
        typeStr = PayloadSanitizer.truncateString(
          rawType,
          typeAllowed,
          onTruncated: () => isTruncated = true,
        );
        remaining -= typeStr.length;
      }

      final errorMsgAllowed = min(maxMessageLength, remaining);
      String errStr;
      if (errorMsgAllowed < PayloadSanitizer.markerLength) {
        errStr = '';
        isTruncated = true;
      } else {
        errStr = PayloadSanitizer.truncateString(
          redactedErrorMsg,
          errorMsgAllowed,
          onTruncated: () => isTruncated = true,
        );
        remaining -= errStr.length;
      }

      if (typeStr.isNotEmpty || errStr.isNotEmpty) {
        sanitizedError = DebugErrorInfo(type: typeStr, message: errStr);
      } else {
        sanitizedError = null;
        isTruncated = true;
      }
    }

    // 5. Stack trace (priority 4)
    String? sanitizedStackTrace;
    if (rawStackTrace != null) {
      String stackStr;
      try {
        stackStr = rawStackTrace.toString();
      } catch (_) {
        stackStr = '[Unprintable StackTrace]';
      }

      final redactedStack = redactor.redactStackTrace(
        stackStr,
        maxStackTraceLength: maxStackTraceLength,
      );

      final allowed = min(maxStackTraceLength, remaining);
      if (allowed < PayloadSanitizer.markerLength) {
        sanitizedStackTrace = null;
        isTruncated = true;
      } else {
        sanitizedStackTrace = PayloadSanitizer.truncateString(
          redactedStack,
          allowed,
          onTruncated: () => isTruncated = true,
        );
        remaining -= sanitizedStackTrace.length;
      }
    }

    // 6. Metadata and JSON share maxPayloadLength (priority 5 and 6)
    Map<String, Object?>? sanitizedMetadata;
    var metadataUsed = 0;
    if (rawMetadata != null) {
      final metadataBudget = max(0, min(maxPayloadLength, remaining));
      if (metadataBudget < PayloadSanitizer.markerLength) {
        sanitizedMetadata = null;
        isTruncated = true;
      } else {
        final metaResult = payloadSanitizer.sanitize(
          rawMetadata,
          budget: metadataBudget,
        );
        if (metaResult.truncated) isTruncated = true;

        if (metaResult.data is Map<String, Object?>) {
          sanitizedMetadata = metaResult.data as Map<String, Object?>;
        } else if (metaResult.data is Map) {
          sanitizedMetadata = Map<String, Object?>.from(metaResult.data as Map);
        } else {
          sanitizedMetadata = null;
          isTruncated = true;
        }

        metadataUsed = metaResult.serializedSize;
        remaining -= metadataUsed;
      }
    }

    Object? sanitizedJson;
    if (rawJson != null) {
      final remainingPayloadBudget = max(0, maxPayloadLength - metadataUsed);
      final jsonBudget = max(0, min(remainingPayloadBudget, remaining));

      if (jsonBudget < PayloadSanitizer.markerLength) {
        sanitizedJson = null;
        isTruncated = true;
      } else {
        final jsonResult = payloadSanitizer.sanitize(
          rawJson,
          budget: jsonBudget,
        );
        if (jsonResult.truncated) isTruncated = true;
        sanitizedJson = jsonResult.data;
        remaining -= jsonResult.serializedSize;
      }
    }

    return SanitizedEntryResult(
      message: sanitizedMessage,
      tag: sanitizedTag,
      subTag: sanitizedSubTag,
      error: sanitizedError,
      stackTrace: sanitizedStackTrace,
      metadata: sanitizedMetadata,
      json: sanitizedJson,
      truncated: isTruncated,
    );
  }
}
