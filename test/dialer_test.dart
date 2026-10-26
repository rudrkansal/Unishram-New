// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_marketplace/widgets/common.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Records what the app hands the phone instead of opening a real dialer.
class _FakeLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final List<String> opened = [];
  Object? failWith;
  bool result = true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    if (failWith != null) throw failWith!;
    opened.add(url);
    return result;
  }
}

void main() {
  late _FakeLauncher launcher;
  setUp(() => UrlLauncherPlatform.instance = launcher = _FakeLauncher());

  test('Call 112 opens the dialer with exactly 112 — no +91, nothing else', () async {
    expect(await openDialer('112'), isTrue);
    expect(launcher.opened, ['tel:112']);
  });

  test('contact calls go through the same dialer, with +91', () async {
    await dialPhone('98765 43210');
    expect(launcher.opened, ['tel:+919876543210']);
  });

  test('no phone app: openDialer reports failure instead of throwing', () async {
    launcher.failWith = Exception('no activity for tel:');
    expect(await openDialer('112'), isFalse);
    launcher
      ..failWith = null
      ..result = false;
    expect(await openDialer('112'), isFalse);
  });
}
