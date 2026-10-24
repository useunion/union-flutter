import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every call on the Union channel; replies with [replies] by method (default null).
class ChannelRecorder {
  ChannelRecorder({Map<String, Object? Function(MethodCall)> replies = const {}}) : _replies = replies {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.useunion/union'),
      (call) async {
        calls.add(call);
        final reply = _replies[call.method];
        return reply?.call(call);
      },
    );
  }

  final Map<String, Object? Function(MethodCall)> _replies;
  final List<MethodCall> calls = [];

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.useunion/union'),
      null,
    );
  }

  List<MethodCall> named(String method) => calls.where((c) => c.method == method).toList();

  Map<Object?, Object?> args(int index) => calls[index].arguments as Map<Object?, Object?>;
}

/// `sendUnion` is fire-and-forget; let the mock messenger deliver before asserting.
Future<void> settle() => Future<void>.delayed(Duration.zero);
