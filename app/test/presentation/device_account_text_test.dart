import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../support/random_inputs.dart';
import '../support/sample_scopes.dart';

void main() {
  test('test_describe_last_seen_property_now_within_a_minute', () {
    final Random random = seededRandom(9401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final Duration age = Duration(seconds: random.nextInt(400000));
      final String lastSeen = describeLastSeen(now.subtract(age), now);

      if (age < const Duration(minutes: 1)) {
        expect(lastSeen, 'Now');
      } else {
        expect(lastSeen, describeTimeSince(now.subtract(age), now));
      }
    }
  });

  test('test_describe_device_last_seen_property_this_device_is_now', () {
    final Random random = seededRandom(9402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final Device device =
          galleryDevices[random.nextInt(galleryDevices.length)];
      final Device thisDevice =
          galleryDevices[random.nextInt(galleryDevices.length)];

      final String lastSeen = describeDeviceLastSeen(
        device: device,
        thisDeviceId: thisDevice.id,
        now: now,
      );

      if (device.id == thisDevice.id) {
        expect(lastSeen, 'Now');
      } else {
        expect(lastSeen, describeLastSeen(device.lastSeen, now));
      }
    }
  });

  test('test_describe_role_with_article_property_lowercase_label', () {
    for (final DeviceRole role in DeviceRole.values) {
      final String phrase = describeRoleWithArticle(role);

      expect(phrase, 'a ${role.label.toLowerCase()}');
    }
    expect(describeRoleWithArticle(DeviceRole.runner), 'a runner');
  });

  test('test_describe_this_device_kind_property_one_word_per_platform', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final String kind = describeThisDeviceKind(platform);

      expect(kind.contains(' '), isFalse);
      expect(kind, isNotEmpty);
    }
    expect(describeThisDeviceKind(TargetPlatform.macOS), 'Mac');
  });

  test('test_describe_tray_name_property_menu_bar_only_on_macos', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final String trayName = describeTrayName(platform);

      expect(trayName == 'menu bar', platform == TargetPlatform.macOS);
      expect(trayName, isNotEmpty);
    }
    expect(describeTrayName(TargetPlatform.linux), 'tray');
    expect(describeTrayName(TargetPlatform.windows), 'tray');
  });

  test('test_describe_device_key_property_marks_only_this_device', () {
    final Random random = seededRandom(9402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final DeviceId currentDeviceId = pickOne(random, galleryDevices).id;
      final String key = describeDeviceKey(
        device: device,
        currentDeviceId: currentDeviceId,
      );

      expect(key.endsWith(device.keyKind.label), isTrue);
      expect(key.startsWith('This device · '), device.id == currentDeviceId);
    }
  });

  test('test_describe_device_pairing_property_date_then_approver', () {
    final Random random = seededRandom(9403);
    final DeviceNames names = DeviceNames(galleryDevices);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final String pairing = describeDevicePairing(device, names);
      final DeviceId? approver = device.approvedBy;

      expect(pairing.startsWith(formatCalendarDate(device.pairedAt)), isTrue);
      expect(
        pairing.endsWith(
          approver == null ? '' : ', approved by ${names.nameOf(approver)}',
        ),
        isTrue,
      );
    }
    final Device oldMacbook = galleryDevices.firstWhere(
      (Device device) => device.id == GalleryDeviceIds.oldMacbook,
    );
    expect(
      describeDevicePairing(oldMacbook, names),
      '12 March 2026, approved by air-laptop',
    );
  });

  test('test_describe_workspace_names_property_joins_names_in_order', () {
    final Random random = seededRandom(9404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final String names = describeWorkspaceNames(
        device.workspaces,
        galleryCatalog,
      );

      expect(
        names,
        device.workspaces.map(galleryCatalog.nameOfWorkspace).join(', '),
      );
    }
    expect(describeWorkspaceNames(const <WorkspaceId>[], galleryCatalog), '');
  });

  test('test_format_calendar_date_property_day_month_year', () {
    final Random random = seededRandom(9405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomLocalMoment(random);
      final List<String> parts = formatCalendarDate(moment).split(' ');

      expect(parts.length, 3);
      expect(int.parse(parts[0]), moment.day);
      expect(int.parse(parts[2]), moment.year);
    }
    expect(formatCalendarDate(DateTime(2026, 3, 12)), '12 March 2026');
  });

  test('test_describe_time_left_property_minutes_and_padded_seconds', () {
    final Random random = seededRandom(9406);
    final RegExp countdown = RegExp(r'^Expires in (\d+):(\d\d)$');

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final Duration left = Duration(seconds: random.nextInt(900) - 300);
      final String text = describeTimeLeft(expiresAt: now.add(left), now: now);

      if (left <= Duration.zero) {
        expect(text, 'Expired');
        continue;
      }
      final RegExpMatch? match = countdown.firstMatch(text);
      expect(match, isNotNull, reason: text);
      final int minutes = int.parse(match!.group(1)!);
      final int seconds = int.parse(match.group(2)!);
      expect(minutes * 60 + seconds, left.inSeconds);
    }
    expect(
      describeTimeLeft(
        expiresAt: galleryNow.add(const Duration(minutes: 4, seconds: 52)),
        now: galleryNow,
      ),
      'Expires in 4:52',
    );
  });
}
