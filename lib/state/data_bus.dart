import 'package:flutter/widgets.dart';

/// App-wide "something changed" signal.
///
/// Service methods call [ping] after a successful write. Pages that mix in
/// [DataBusRefreshMixin] refresh after the current Flutter frame finishes.
///
/// Important:
/// Multiple pings that happen before the same frame finishes are collapsed
/// into ONE refresh per listener. This prevents donation/inventory workflows
/// from starting several overlapping reloads at once.
class DataChangeBus extends ChangeNotifier {
  DataChangeBus._();

  static final DataChangeBus instance = DataChangeBus._();

  void ping() => notifyListeners();
}

/// Mix this into pages/widgets that should silently refresh when shared data
/// changes.
///
/// This implementation is intentionally small:
/// - never calls the page refresh synchronously from notifyListeners()
/// - allows only one queued refresh at a time
/// - refreshes only while this route is current
/// - does not attach animation listeners or wait on route transitions
mixin DataBusRefreshMixin<T extends StatefulWidget> on State<T> {
  bool _dataBusRefreshQueued = false;

  @override
  void initState() {
    super.initState();
    DataChangeBus.instance.addListener(_onDataBusPing);
  }

  @override
  void dispose() {
    DataChangeBus.instance.removeListener(_onDataBusPing);
    super.dispose();
  }

  void _onDataBusPing() {
    if (!mounted || _dataBusRefreshQueued) {
      return;
    }

    _dataBusRefreshQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dataBusRefreshQueued = false;

      if (!mounted) {
        return;
      }

      final route = ModalRoute.of(context);

      // A page that is covered by another route should not refresh in the
      // background. Shell widgets may not have their own ModalRoute, so null
      // is intentionally allowed.
      if (route != null && !route.isCurrent) {
        return;
      }

      onExternalDataChanged();
    });

    // addPostFrameCallback does not itself guarantee another frame, so make
    // sure Flutter has one available for the queued refresh.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void onExternalDataChanged();
}
