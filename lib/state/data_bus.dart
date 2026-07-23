import 'package:flutter/widgets.dart';

/// App-wide "something changed" signal. Every mutating service method
/// (create/update/delete/adjustStock, mock and Supabase alike) calls
/// [ping] once its write succeeds; pages mix in [DataBusRefreshMixin] to
/// silently re-fetch while they're the one currently on screen, instead of
/// only ever seeing fresh data after a full navigate-away-and-back.
///
/// Deliberately a single undifferentiated signal rather than a per-table/
/// topic system: this app's router never keeps more than one page mounted
/// at a time (no IndexedStack/keep-alive), so "the one visible page
/// refetches on every write anywhere" costs at most one extra fetch, not
/// a fan-out -- not worth a topic taxonomy to avoid that.
class DataChangeBus extends ChangeNotifier {
  DataChangeBus._();
  static final DataChangeBus instance = DataChangeBus._();

  void ping() => notifyListeners();
}

/// Mix into a data-displaying page's State to silently re-fetch whenever
/// [DataChangeBus] pings, so changes made elsewhere (another page reached
/// via `push` and popped back to, a dialog, another user on the real
/// backend) show up without the user navigating away and back. Implement
/// [onExternalDataChanged] to call your page's existing load method with
/// its silent/background variant (no loading spinner, no error screen --
/// an unrelated background refresh failing shouldn't blank out already-
/// displayed data).
mixin DataBusRefreshMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    DataChangeBus.instance.addListener(_onPing);
  }

  @override
  void dispose() {
    DataChangeBus.instance.removeListener(_onPing);
    super.dispose();
  }

  void _onPing() {
    // Deferred to a post-frame callback rather than called straight from
    // notifyListeners(): ping() often fires mid-await inside a dialog's
    // onPressed handler or right before a Navigator pop/push, i.e. while
    // Flutter is already mid-build/layout/transition for that same frame.
    // Triggering setState synchronously in that window corrupts the
    // render tree (layout/constraint assertion failures); a post-frame
    // callback runs once the current frame is safely done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onExternalDataChanged();
    });
  }

  void onExternalDataChanged();
}
