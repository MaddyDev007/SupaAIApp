import 'dart:io';
import 'package:flutter/material.dart';

class SmartClassErrorPage extends StatelessWidget {
  const SmartClassErrorPage({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.error,
    this.stackTrace,
    this.emoji,
    this.icon,
    this.type = SmartErrorType.generic,
    this.standalone = true, // 👈 NEW: embed-safe mode
  });

  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final Object? error;
  final StackTrace? stackTrace;
  final String? emoji;
  final IconData? icon;
  final SmartErrorType type;

  /// When true, renders with a Scaffold + SafeArea + internal scroll.
  /// When false, renders only the content (no Scaffold/scroll) so you can
  /// safely place it inside ListView/Column/Sliver.
  final bool standalone;

  static SmartErrorType mapToType(Object? error) {
    final text = error.toString().toLowerCase();
    if (text.contains('timeout')) return SmartErrorType.timeout;
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('host') ||
        text.contains('failed host lookup')) {
      return SmartErrorType.network;
    }
    if (text.contains('401') ||
        text.contains('forbidden') ||
        text.contains('unauthorized')) {
      return SmartErrorType.unauthorized;
    }
    if (text.contains('404') ||
        text.contains('not found') ||
        text.contains('empty')) {
      return SmartErrorType.notFound;
    }
    return SmartErrorType.generic;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = _presets[type]!;
    final resolvedTitle = title ?? t.title;
    final resolvedMessage = message ?? t.message;
    final resolvedIcon = emoji != null ? null : (icon ?? t.icon);

    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 👈 important for inline mode
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            _HeroMark(emoji: emoji, icon: resolvedIcon),
            const SizedBox(height: 20),
            Text(
              resolvedTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              resolvedMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _Details(error: error, stackTrace: stackTrace),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );

    if (!standalone) {
      // INLINE MODE: no Scaffold, no internal scrollables
      return Container(
        color: Colors.transparent,
        child: content,
      );
    }

    // STANDALONE PAGE MODE (original behavior)
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: content,
        ),
      ),
    );
  }
}

enum SmartErrorType { generic, network, timeout, notFound, unauthorized, maintenance }

class _Preset {
  final String title;
  final String message;
  final IconData icon;
  const _Preset(this.title, this.message, this.icon);
}

final Map<SmartErrorType, _Preset> _presets = {
  SmartErrorType.generic: const _Preset(
    'Something went wrong',
    'We couldn\'t complete that action. Please try again.',
    Icons.error_outline,
  ),
  SmartErrorType.network: const _Preset(
    'No internet',
    'Your device appears to be offline. Check your connection and retry.',
    Icons.wifi_off_rounded,
  ),
  SmartErrorType.timeout: const _Preset(
    'Request timed out',
    'The server took too long to respond. Try again later.',
    Icons.hourglass_bottom_rounded,
  ),
  SmartErrorType.notFound: const _Preset(
    'Nothing here',
    'This content may have been moved or deleted.',
    Icons.search_off_rounded,
  ),
  SmartErrorType.unauthorized: const _Preset(
    'You need to sign in',
    'Please sign in to continue.',
    Icons.lock_outline_rounded,
  ),
  SmartErrorType.maintenance: const _Preset(
    'We’ll be right back',
    'Our servers are under maintenance. Please come back later.',
    Icons.engineering_rounded,
  ),
};

class _HeroMark extends StatelessWidget {
  const _HeroMark({required this.emoji, required this.icon});
  final String? emoji;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.25), width: 1.2),
      ),
      child: emoji != null
          ? Text(emoji!, style: const TextStyle(fontSize: 40))
          : Icon(icon ?? Icons.error_outline, size: 48, color: Theme.of(context).primaryColor),
    );
  }
}

class _Details extends StatefulWidget {
  const _Details({this.error, this.stackTrace});
  final Object? error;
  final StackTrace? stackTrace;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final technical = _composeTechnical(widget.error, widget.stackTrace);
    if (technical == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          splashColor: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => expanded = !expanded),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(expanded ? Icons.expand_less : Icons.expand_more, color: Theme.of(context).primaryColor),
              const SizedBox(width: 6),
               Text('Technical details', style: TextStyle(color: Theme.of(context).primaryColor)),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: expanded
              ? Container(
                  key: const ValueKey('details'),
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      technical,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  String? _composeTechnical(Object? error, StackTrace? stackTrace) {
    if (error == null && stackTrace == null) return null;

    final lines = <String>[];
    if (error != null) {
      lines..add('Error:')..add(error.toString())..add('');
    }
    if (stackTrace != null) {
      lines..add('Stack trace:')..add(stackTrace.toString());
    }
    try {
      lines.add('\nPlatform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    } catch (_) {}
    return lines.join('\n');
  }
}
