import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionService {
  VersionService._();

  static final instance = VersionService._();

  Future<VersionCheckResult> checkVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final doc = await FirebaseFirestore.instance
          .collection('platform')
          .doc('settings')
          .get();

      if (!doc.exists) return VersionCheckResult.ok();

      final data = doc.data()!;
      final maintenanceMode = data['maintenanceMode'] as bool? ?? false;
      if (maintenanceMode) return VersionCheckResult.maintenance();

      final minimumBuild = (data['minimumBuildNumber'] as num?)?.toInt() ?? 0;
      final latestBuild = (data['latestBuildNumber'] as num?)?.toInt() ?? 0;
      final updateUrl = data['updateUrl'] as String? ?? '';

      if (currentBuild < minimumBuild) {
        return VersionCheckResult.forceUpdate(updateUrl);
      }
      if (currentBuild < latestBuild) {
        return VersionCheckResult.softUpdate(updateUrl);
      }
      return VersionCheckResult.ok();
    } catch (_) {
      // Never block the app if version check fails
      return VersionCheckResult.ok();
    }
  }
}

enum VersionStatus { ok, softUpdate, forceUpdate, maintenance }

class VersionCheckResult {
  const VersionCheckResult._({
    required this.status,
    this.updateUrl = '',
  });

  factory VersionCheckResult.ok() =>
      const VersionCheckResult._(status: VersionStatus.ok);

  factory VersionCheckResult.softUpdate(String url) =>
      VersionCheckResult._(status: VersionStatus.softUpdate, updateUrl: url);

  factory VersionCheckResult.forceUpdate(String url) =>
      VersionCheckResult._(status: VersionStatus.forceUpdate, updateUrl: url);

  factory VersionCheckResult.maintenance() =>
      const VersionCheckResult._(status: VersionStatus.maintenance);

  final VersionStatus status;
  final String updateUrl;
}
