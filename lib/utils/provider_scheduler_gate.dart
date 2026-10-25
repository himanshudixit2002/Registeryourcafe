import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Best-effort: [SchedulerBinding.instance] can throw during unusual engine
// teardown (e.g. web hot restart); microtask fallback still completes the gate.

/// Defers async tenant work until after the next frame (or [ref] disposal).
///
/// On Flutter web, hot restart can dispose the old [EngineFlutterView] while
/// Firestore still delivers callbacks; starting heavy work on the next frame
/// reduces "Trying to render a disposed EngineFlutterView" noise.
Future<void> awaitProviderSchedulerFrame(
  Ref ref,
  void Function() onRefDisposed,
) async {
  final done = Completer<void>();
  ref.onDispose(() {
    onRefDisposed();
    if (!done.isCompleted) done.complete();
  });
  try {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!done.isCompleted) done.complete();
    });
  } catch (_) {
    // Best-effort: see file-level note.
    scheduleMicrotask(() {
      if (!done.isCompleted) done.complete();
    });
  }
  await done.future;

  if (kIsWeb) {
    final done2 = Completer<void>();
    ref.onDispose(() {
      if (!done2.isCompleted) done2.complete();
    });
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!done2.isCompleted) done2.complete();
      });
    } catch (_) {
      // Best-effort: see file-level note.
      scheduleMicrotask(() {
        if (!done2.isCompleted) done2.complete();
      });
    }
    await done2.future;
  }

  // Let the web engine finish tearing down the previous view after hot restart
  // before Firestore/async work resumes (reduces disposed-view render assertions).
  if (kIsWeb) {
    await Future<void>.delayed(Duration.zero);
    // One extra macrotask + ~half frame at 60Hz — helps races where the first
    // post-restart frame is still bound to the disposed view.
    await Future<void>.delayed(const Duration(milliseconds: 32));
  }
}
