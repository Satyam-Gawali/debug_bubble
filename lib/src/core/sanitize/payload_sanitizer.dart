import 'redactor.dart';

/// Result of converting and budgeting a payload object.
class PayloadSanitizationResult {
  const PayloadSanitizationResult({
    required this.data,
    required this.serializedSize,
    required this.truncated,
    required this.nodesVisited,
  });

  /// The sanitized, JSON-safe data structure.
  final Object? data;

  /// Approximate serialized character length.
  final int serializedSize;

  /// True if any cap, budget, depth limit, cycle, or collection limit was triggered.
  final bool truncated;

  /// Total count of visited AST/payload nodes.
  final int nodesVisited;
}

/// JSON-safe bounded traversal converter for payloads per DATA_MODELS.md §7.
///
/// Implements caps for depth, node counts, collection items, string lengths,
/// and key lengths, while handling cycles, throwing toString()/iterables,
/// and value pattern redaction.
class PayloadSanitizer {
  /// Creates a payload sanitizer using [redactor] for sensitive data masking.
  PayloadSanitizer({DebugRedactor? redactor})
    : redactor = redactor ?? DebugRedactor();

  /// The redactor used to evaluate sensitive keys and value patterns.
  final DebugRedactor redactor;

  /// Truncation marker appended when strings or collections exceed budgets.
  static const String truncationMarker = '…[truncated]';
  static const int markerLength = 12;

  /// Maximum allowed traversal depth before replacing with `[MaxDepth]`.
  static const int maxDepth = 8;

  /// Maximum number of visited nodes per payload before replacing with `[Truncated]`.
  static const int maxNodes = 2000;

  /// Maximum items retained per collection (List or Map).
  static const int maxCollectionItems = 200;

  /// Maximum character length for string values in payloads.
  static const int maxStringLength = 2000;

  /// Maximum character length for map keys.
  static const int maxKeyLength = 200;

  /// Converts and bounds [input] within the specified serialized character [budget].
  PayloadSanitizationResult sanitize(Object? input, {int budget = 32000}) {
    final state = _SanitizationState(budget: budget, redactor: redactor);
    final result = state.sanitizeNode(input, depth: 0);

    return PayloadSanitizationResult(
      data: result,
      serializedSize: state.currentSerializedSize,
      truncated: state.truncated,
      nodesVisited: state.nodesVisited,
    );
  }

  /// Truncates [text] to [allowed] characters, appending [truncationMarker]
  /// without splitting UTF-16 surrogate pairs.
  static String truncateString(
    String text,
    int allowed, {
    required void Function() onTruncated,
  }) {
    if (text.length <= allowed) {
      return text;
    }

    onTruncated();

    if (allowed < markerLength) {
      return '';
    }

    var keepLen = allowed - markerLength;
    if (keepLen > 0 && keepLen < text.length) {
      final unit = text.codeUnitAt(keepLen - 1);
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        keepLen--;
      }
    }

    return '${text.substring(0, keepLen)}$truncationMarker';
  }
}

class _SanitizationState {
  _SanitizationState({required this.budget, required this.redactor});

  final int budget;
  final DebugRedactor redactor;

  int nodesVisited = 0;
  int currentSerializedSize = 0;
  bool truncated = false;
  final List<Object> _ancestorPath = <Object>[];

  Object? sanitizeNode(Object? node, {required int depth}) {
    nodesVisited++;

    if (nodesVisited > PayloadSanitizer.maxNodes) {
      truncated = true;
      currentSerializedSize += 13;
      return '[Truncated]';
    }

    if (currentSerializedSize >= budget) {
      truncated = true;
      currentSerializedSize += 13;
      return '[Truncated]';
    }

    if (depth > PayloadSanitizer.maxDepth) {
      truncated = true;
      currentSerializedSize += 10;
      return '[MaxDepth]';
    }

    // Reference cycle check on ancestor path
    if (node != null && (node is Map || node is Iterable)) {
      for (final ancestor in _ancestorPath) {
        if (identical(ancestor, node)) {
          truncated = true;
          currentSerializedSize += 10;
          return '[Circular]';
        }
      }
    }

    if (node == null) {
      currentSerializedSize += 4;
      return null;
    }

    if (node is bool) {
      currentSerializedSize += node ? 4 : 5;
      return node;
    }

    if (node is num) {
      if (node.isNaN) {
        currentSerializedSize += 5;
        return 'NaN';
      }
      if (node == double.infinity) {
        currentSerializedSize += 10;
        return 'Infinity';
      }
      if (node == double.negativeInfinity) {
        currentSerializedSize += 11;
        return '-Infinity';
      }
      currentSerializedSize += node.toString().length;
      return node;
    }

    if (node is DateTime) {
      final str = node.toUtc().toIso8601String();
      currentSerializedSize += str.length + 2;
      return str;
    }

    if (node is String) {
      var str = redactor.redactPayloadString(node);
      if (str.length > PayloadSanitizer.maxStringLength) {
        str = PayloadSanitizer.truncateString(
          str,
          PayloadSanitizer.maxStringLength,
          onTruncated: () => truncated = true,
        );
      }
      currentSerializedSize += str.length + 2;
      return str;
    }

    if (node is Map) {
      _ancestorPath.add(node);
      final resultMap = <String, Object?>{};
      currentSerializedSize += 2; // `{}`

      var itemCount = 0;
      final totalEntries = node.length;

      for (final entry in node.entries) {
        if (itemCount >= PayloadSanitizer.maxCollectionItems) {
          truncated = true;
          final omitted = totalEntries - PayloadSanitizer.maxCollectionItems;
          final omittedMsg = omitted > 0
              ? '$omitted more entries omitted'
              : 'more entries omitted';
          resultMap['[truncated]'] = omittedMsg;
          currentSerializedSize += omittedMsg.length + 18;
          break;
        }

        if (currentSerializedSize >= budget ||
            nodesVisited >= PayloadSanitizer.maxNodes) {
          truncated = true;
          resultMap['[truncated]'] = 'budget exhausted';
          currentSerializedSize += 35;
          break;
        }

        itemCount++;

        String keyStr;
        try {
          keyStr = entry.key?.toString() ?? 'null';
        } catch (e) {
          keyStr = '[Unprintable: ${_safeTypeName(entry.key)}]';
          truncated = true;
        }

        if (keyStr.length > PayloadSanitizer.maxKeyLength) {
          keyStr = PayloadSanitizer.truncateString(
            keyStr,
            PayloadSanitizer.maxKeyLength,
            onTruncated: () => truncated = true,
          );
        }

        currentSerializedSize += keyStr.length + 3;

        if (redactor.isSensitiveKey(keyStr)) {
          resultMap[keyStr] = redactor.replacement;
          currentSerializedSize += redactor.replacement.length + 2;
        } else {
          final val = sanitizeNode(entry.value, depth: depth + 1);
          resultMap[keyStr] = val;
        }
      }

      _ancestorPath.removeLast();
      return resultMap;
    }

    if (node is Iterable) {
      _ancestorPath.add(node);
      final resultList = <Object?>[];
      currentSerializedSize += 2; // `[]`

      var itemCount = 0;
      var hasMore = false;

      try {
        final iterator = node.iterator;
        while (itemCount < PayloadSanitizer.maxCollectionItems &&
            iterator.moveNext()) {
          if (currentSerializedSize >= budget ||
              nodesVisited >= PayloadSanitizer.maxNodes) {
            truncated = true;
            resultList.add('[Truncated]');
            currentSerializedSize += 13;
            break;
          }

          itemCount++;
          final val = sanitizeNode(iterator.current, depth: depth + 1);
          resultList.add(val);
          currentSerializedSize += 1;
        }

        if (itemCount >= PayloadSanitizer.maxCollectionItems &&
            iterator.moveNext()) {
          hasMore = true;
        }
      } catch (e) {
        truncated = true;
        final errText = '[IterationError: ${_safeTypeName(e)}]';
        resultList.add(errText);
        currentSerializedSize += errText.length + 2;
      }

      if (hasMore) {
        truncated = true;
        int? remainingCount;
        try {
          remainingCount = node.length - PayloadSanitizer.maxCollectionItems;
        } catch (_) {
          remainingCount = null;
        }

        final omittedMsg = (remainingCount != null && remainingCount > 0)
            ? '[$remainingCount more items omitted]'
            : '[more items omitted]';
        resultList.add(omittedMsg);
        currentSerializedSize += omittedMsg.length + 2;
      }

      _ancestorPath.removeLast();
      return resultList;
    }

    // Anything else: Future, Stream, custom objects
    String str;
    try {
      str = node.toString();
    } catch (_) {
      truncated = true;
      final errStr = '[Unprintable: ${_safeTypeName(node)}]';
      currentSerializedSize += errStr.length + 2;
      return errStr;
    }

    str = redactor.redactPayloadString(str);
    if (str.length > PayloadSanitizer.maxStringLength) {
      str = PayloadSanitizer.truncateString(
        str,
        PayloadSanitizer.maxStringLength,
        onTruncated: () => truncated = true,
      );
    }
    currentSerializedSize += str.length + 2;
    return str;
  }

  static String _safeTypeName(Object? obj) {
    if (obj == null) return 'Null';
    try {
      return obj.runtimeType.toString();
    } catch (_) {
      return 'Unknown';
    }
  }
}
