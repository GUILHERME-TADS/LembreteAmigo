import 'dart:async';
import 'dart:html' as html;

html.WindowBase? _activePopup;
Timer? _popupTimer;

void openJitsiWeb(String url, String? callId, Function(String) endCall) {
  closeJitsiWeb(); // Close any existing popup first
  final popup = html.window.open(url, '_blank');
  _activePopup = popup;
  
  if (callId != null) {
    _popupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      try {
        if (popup == null || popup.closed == true) {
          timer.cancel();
          _popupTimer = null;
          _activePopup = null;
          endCall(callId);
        }
      } catch (e) {
        timer.cancel();
        _popupTimer = null;
        _activePopup = null;
        endCall(callId);
      }
    });
  }
}

void closeJitsiWeb() {
  _popupTimer?.cancel();
  _popupTimer = null;
  if (_activePopup != null && _activePopup!.closed != true) {
    try {
      _activePopup!.close();
    } catch (_) {}
  }
  _activePopup = null;
}
