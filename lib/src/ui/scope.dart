import 'package:flutter/widgets.dart';

import '../app/ledger_state.dart';

class LedgerScope extends InheritedNotifier<LedgerState> {
  const LedgerScope({
    super.key,
    required LedgerState state,
    required super.child,
  }) : super(notifier: state);

  static LedgerState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LedgerScope>();
    assert(scope != null, 'LedgerScope not found');
    return scope!.notifier!;
  }
}
