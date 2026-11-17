import 'package:flutter_test/flutter_test.dart';

import 'package:spark/core/presence.dart';

void main() {
  test('PresenceData parses wire format', () {
    final data = PresenceData.fromMap({
      'state': 'active',
      'lastChanged': 1700000000000,
      'lastSeen': 1700000000000,
      'device': 'android',
    });
    expect(data.state, PresenceState.active);
    expect(data.updatedAt, 1700000000000);
    expect(data.lastSeen, 1700000000000);
  });

  test('Unknown / missing state falls back to offline', () {
    final data = PresenceData.fromMap({'state': 'bogus'});
    expect(data.state, PresenceState.offline);
    final empty = PresenceData.fromMap(null);
    expect(empty.state, PresenceState.offline);
    expect(empty.isEmpty, isTrue);
  });

  test('displayFor maps states to labels and colors', () {
    final active = displayFor(
      const PresenceData(state: PresenceState.active, updatedAt: 1, lastSeen: 1),
      isFriend: true,
    );
    expect(active.label, 'Active Now');
    expect(active.pulsing, isTrue);

    final ghost = displayFor(
      const PresenceData(state: PresenceState.ghost, updatedAt: 1, lastSeen: 1),
      isFriend: true,
    );
    expect(ghost.label, 'Ghost Mode');

    final stranger = displayFor(null, isFriend: false);
    expect(stranger.label, 'Not connected');
  });

  test('PresenceState.fromWire handles all wire values', () {
    expect(PresenceState.fromWire('active'), PresenceState.active);
    expect(PresenceState.fromWire('screenOn'), PresenceState.screenOn);
    expect(PresenceState.fromWire('inactive'), PresenceState.inactive);
    expect(PresenceState.fromWire('ghost'), PresenceState.ghost);
    expect(PresenceState.fromWire('offline'), PresenceState.offline);
    expect(PresenceState.fromWire(null), PresenceState.offline);
  });
}
