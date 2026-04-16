import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart' show debugPrint;
import '../api/api_client.dart';

// ── External JS declarations ───────────────────────────────────────────────

@JS('celumeRegisterPush')
external JSPromise<JSString?> _jsRegisterPush(JSString vapidKey);

@JS('celumeUnsubscribePush')
external JSPromise<JSString?> _jsUnsubscribePush();

// ── Service ────────────────────────────────────────────────────────────────

class PushService {
  final ApiClient _api;
  PushService(this._api);

  /// Call after login: fetches VAPID key, subscribes, and registers with backend.
  Future<void> subscribe() async {
    try {
      final keyRes    = await _api.getVapidPublicKey();
      final publicKey = (keyRes.data as Map)['publicKey'] as String;

      final jsStr = await _jsRegisterPush(publicKey.toJS).toDart;
      if (jsStr == null) {
        debugPrint('[Push] subscribe: browser returned null (permission denied or unsupported)');
        return;
      }

      final sub = jsonDecode(jsStr.toDart) as Map<String, dynamic>;
      await _api.subscribePush(sub);
      debugPrint('[Push] subscribed');
    } catch (e) {
      debugPrint('[Push] subscribe error: $e');
    }
  }

  /// Call before logout: removes subscription from browser and notifies backend.
  Future<void> unsubscribe() async {
    try {
      final jsStr = await _jsUnsubscribePush().toDart;
      if (jsStr == null) {
        debugPrint('[Push] unsubscribe: no active subscription');
        return;
      }

      await _api.unsubscribePush(jsStr.toDart);
      debugPrint('[Push] unsubscribed');
    } catch (e) {
      debugPrint('[Push] unsubscribe error: $e');
    }
  }
}
