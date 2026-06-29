import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/promoter.dart';
import '../../models/rsvp.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/compact_ui.dart';
import '../../widgets/delete_account_dialogs.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/premium_loader.dart';
import '../../widgets/state_views.dart';

class PromoterProfileScreen extends StatelessWidget {
  const PromoterProfileScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: AppBar(title: const Text('Promoter profile')),
      child: StreamBuilder<AppUser?>(
        stream: AuthService.instance.profileStream(currentUser.uid),
        builder: (context, userSnapshot) {
          final profile = userSnapshot.data ?? currentUser;

          return StreamBuilder<Promoter?>(
            stream: FirestoreService.instance.promoterForUserStream(
              profile.uid,
            ),
            builder: (context, promoterSnapshot) {
              if (promoterSnapshot.hasError) {
                return ErrorStateView(
                  message: ErrorStateView.sanitizeError(
                    promoterSnapshot.error,
                  ),
                );
              }
              if (promoterSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView(message: 'Loading promoter profile');
              }

              final promoter = promoterSnapshot.data;
              if (promoter == null) {
                return const EmptyView(
                  title: 'Promoter profile unavailable',
                  message:
                      'Sign out and back in to refresh your referral profile.',
                  icon: Icons.campaign_outlined,
                );
              }

              return StreamBuilder<List<Rsvp>>(
                stream: FirestoreService.instance.promoterRsvpsStream(
                  promoter.referralCode,
                ),
                builder: (context, rsvpSnapshot) {
                  final rsvps = rsvpSnapshot.data ?? const <Rsvp>[];
                  final metrics = _PromoterProfileMetrics.fromRsvps(rsvps);

                  return _PromoterProfileContent(
                    currentUser: profile,
                    promoter: promoter,
                    metrics: metrics,
                    loadingMetrics:
                        rsvpSnapshot.connectionState == ConnectionState.waiting,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _PromoterProfileContent extends StatefulWidget {
  const _PromoterProfileContent({
    required this.currentUser,
    required this.promoter,
    required this.metrics,
    required this.loadingMetrics,
  });

  final AppUser currentUser;
  final Promoter promoter;
  final _PromoterProfileMetrics metrics;
  final bool loadingMetrics;

  @override
  State<_PromoterProfileContent> createState() =>
      _PromoterProfileContentState();
}

class _PromoterProfileContentState extends State<_PromoterProfileContent> {
  Uint8List? _pendingAvatarBytes;
  double? _uploadProgress;
  bool _uploadingAvatar = false;
  bool _deletingAccount = false;

  String get _displayName {
    final promoterName = widget.promoter.name.trim();
    if (promoterName.isNotEmpty) return promoterName;
    final userName = widget.currentUser.name.trim();
    return userName.isEmpty ? 'Promoter' : userName;
  }

  String get _email {
    final promoterEmail = widget.promoter.email.trim();
    return promoterEmail.isNotEmpty ? promoterEmail : widget.currentUser.email;
  }

  String get _referralCode => widget.promoter.referralCode.trim();

  String get _referralLink => 'https://nightlife.app/?ref=$_referralCode';

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar || _deletingAccount) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        imageQuality: 82,
      );
      if (picked == null) return;

      setState(() {
        _uploadingAvatar = true;
        _uploadProgress = null;
      });

      final bytes = await picked.readAsBytes().timeout(
        const Duration(seconds: 15),
      );
      final contentType = _profileImageContentType(
        picked.mimeType,
        picked.name,
        bytes,
      );
      if (contentType == null) {
        _showSnack('Choose a JPG, PNG, or WebP image.');
        return;
      }
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        _showSnack('Photo must be under 5MB. Please choose a smaller image.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _pendingAvatarBytes = bytes;
        _uploadProgress = 0;
      });

      final url = await StorageService.instance.uploadProfilePhoto(
        bytes: bytes,
        userId: widget.currentUser.uid,
        fileName: picked.name,
        contentType: contentType,
        filePath: picked.path,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _uploadProgress = progress);
        },
      );
      await FirestoreService.instance.updatePromoterProfilePhoto(
        userId: widget.currentUser.uid,
        promoterId: widget.promoter.id,
        profilePhotoUrl: url,
      );
      await AuthService.instance.refreshCurrentUserProfileState(
        displayName: _displayName,
        photoUrl: url,
      );
      if (!mounted) return;
      setState(() {
        _pendingAvatarBytes = null;
        _uploadProgress = null;
      });
      _showSnack('Profile photo updated');
    } on TimeoutException {
      _showSnack('Image upload timed out. Please try again.');
    } on FirebaseException catch (error) {
      _showSnack(_profileImageErrorMessage(error));
    } catch (error) {
      _showSnack(_profileImageErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _copyReferralCode() async {
    if (_referralCode.isEmpty) {
      _showSnack('No referral code yet.');
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: _referralCode));
      _showSnack('Referral code copied');
    } catch (_) {
      _showSnack('Unable to copy code right now.');
    }
  }

  Future<void> _shareReferralLink() async {
    if (_referralCode.isEmpty) {
      _showSnack('No referral code yet.');
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _referralLink,
          subject: 'Nightlife referral code $_referralCode',
        ),
      );
    } catch (_) {
      _showSnack('Unable to open sharing right now.');
    }
  }

  Future<void> _deleteAccount() async {
    if (_deletingAccount) return;
    final password = await confirmAndRequestDeletePassword(context);
    if (password == null || !mounted) return;

    // Capture the navigator before the async gap so we can leave the pushed
    // profile route after deletion, the same way Logout does.
    final navigator = Navigator.of(context);

    setState(() => _deletingAccount = true);
    try {
      await AuthService.instance.deleteCurrentAccount(password: password);
      // Leave the pushed profile route FIRST, then sign out so RoleRouterScreen
      // rebuilds to WelcomeScreen with no stale screen on top. deleteCurrentAccount
      // already deletes the Auth user (which signs out); call signOut to be sure
      // any cached state is cleared even if the Auth user was already gone.
      navigator.pop();
      try {
        await AuthService.instance.signOut();
      } catch (_) {
        // Auth user is already deleted; RoleRouterScreen rebuilds on its own.
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      _showSnack(error.toString());
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Opens a hosted legal policy URL (Terms / Privacy) in the browser, matching
  /// the welcome screen. Fails gracefully with a snackbar instead of crashing.
  Future<void> _openLegalUrl(String url) async {
    final uri = Uri.tryParse(url);
    var launched = false;
    if (uri != null) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
    }
    if (!launched) _showSnack("Couldn't open the link");
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: compactScreenPadding(context, bottom: 28),
      children: [
        _ProfileHeader(
          name: _displayName,
          email: _email,
          photoUrl: widget.currentUser.profilePhotoUrl,
          previewBytes: _pendingAvatarBytes,
          uploading: _uploadingAvatar,
          uploadProgress: _uploadProgress,
          active: widget.promoter.isActive,
          onChangePhoto: _pickAvatar,
        ),
        const SizedBox(height: 12),
        _ReferralCard(
          referralCode: _referralCode,
          referralLink: _referralLink,
          onCopy: _copyReferralCode,
          onShare: _shareReferralLink,
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Activity metrics',
          child: widget.loadingMetrics
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: PremiumLoader.compact(size: 22),
                )
              : _MetricsGrid(metrics: widget.metrics),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Settings & legal',
          child: Column(
            children: [
              _ActionTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () => _openLegalUrl(AppConstants.termsOfServiceUrl),
              ),
              _ActionTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => _openLegalUrl(AppConstants.privacyPolicyUrl),
              ),
              _ActionTile(
                icon: Icons.logout_rounded,
                title: 'Logout',
                destructive: true,
                onTap: () async {
                  // Capture the navigator before the async gap, leave the
                  // pushed profile route FIRST, then sign out so
                  // RoleRouterScreen's authStateChanges listener rebuilds to
                  // WelcomeScreen with no stale screen on top.
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  try {
                    await AuthService.instance.signOut();
                  } catch (_) {
                    // RoleRouterScreen already rebuilds to WelcomeScreen on the
                    // auth change; nothing more to do here.
                  }
                },
              ),
              _ActionTile(
                icon: Icons.delete_forever_outlined,
                title: _deletingAccount
                    ? 'Deleting account...'
                    : 'Delete Account',
                destructive: true,
                onTap: _deletingAccount ? null : _deleteAccount,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PromoterProfileMetrics {
  const _PromoterProfileMetrics({
    required this.totalRsvps,
    required this.referralImpact,
    required this.eventsJoined,
  });

  final int totalRsvps;
  final int referralImpact;
  final int eventsJoined;

  factory _PromoterProfileMetrics.fromRsvps(List<Rsvp> rsvps) {
    final confirmed = rsvps.where((rsvp) {
      final status = rsvp.status.toLowerCase();
      return status == 'confirmed' ||
          status == 'approved' ||
          status == 'attended';
    }).length;
    return _PromoterProfileMetrics(
      totalRsvps: rsvps.length,
      referralImpact: rsvps.isEmpty
          ? 0
          : (confirmed / rsvps.length * 100).round(),
      eventsJoined: rsvps
          .map((rsvp) => rsvp.eventId)
          .where((id) => id.trim().isNotEmpty)
          .toSet()
          .length,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.previewBytes,
    required this.uploading,
    required this.uploadProgress,
    required this.active,
    required this.onChangePhoto,
  });

  final String name;
  final String email;
  final String photoUrl;
  final Uint8List? previewBytes;
  final bool uploading;
  final double? uploadProgress;
  final bool active;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _EditableAvatar(
                name: name,
                photoUrl: photoUrl,
                previewBytes: previewBytes,
                uploading: uploading,
                uploadProgress: uploadProgress,
                onTap: onChangePhoto,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textHigh,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _StatusBadge(active: active),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: uploading ? null : onChangePhoto,
              icon: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.7),
                    )
                  : const Icon(Icons.camera_alt_outlined, size: 17),
              label: Text(
                uploading
                    ? _uploadProgressLabel(uploadProgress)
                    : 'Change photo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({
    required this.referralCode,
    required this.referralLink,
    required this.onCopy,
    required this.onShare,
  });

  final String referralCode;
  final String referralLink;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REFERRAL CODE',
            style: TextStyle(
              color: AppTheme.textLow,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.goldSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.goldBorder, width: 0.8),
            ),
            child: Text(
              referralCode.isEmpty ? '—' : referralCode,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            referralLink,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text('Copy Code'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded, size: 17),
                  label: const Text('Share Link'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final _PromoterProfileMetrics metrics;

  @override
  Widget build(BuildContext context) {
    // Mobile-first: three equal-width stat cards in a single row that sizes to
    // the phone width (no odd vertical stacking on narrow screens). Expanded
    // keeps the cards balanced on wider/web viewports too.
    const tiles = [
      _MetricTileData(
        icon: Icons.confirmation_number_outlined,
        label: 'Total RSVPs',
      ),
      _MetricTileData(
        icon: Icons.trending_up_rounded,
        label: 'Referral Impact',
      ),
      _MetricTileData(
        icon: Icons.event_available_outlined,
        label: 'Events Joined',
      ),
    ];
    final values = [
      metrics.totalRsvps.toString(),
      '${metrics.referralImpact}%',
      metrics.eventsJoined.toString(),
    ];

    // IntrinsicHeight gives the Row a bounded cross-axis (height) so the cards
    // can match each other's height. Without it, a Row inside the surrounding
    // unbounded-height ListView/Column would collapse (the previous
    // CrossAxisAlignment.stretch tried to stretch to infinite height, which is
    // why the cards rendered blank).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                icon: tiles[i].icon,
                value: values[i],
                label: tiles[i].label,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTileData {
  const _MetricTileData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.gold, size: 20),
          const SizedBox(height: 10),
          // FittedBox prevents the number overflowing in the narrow column.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: AppTheme.textHigh,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.name,
    required this.photoUrl,
    required this.previewBytes,
    required this.uploading,
    required this.uploadProgress,
    required this.onTap,
  });

  final String name;
  final String photoUrl;
  final Uint8List? previewBytes;
  final bool uploading;
  final double? uploadProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _InitialsAvatar(
            name: name,
            photoUrl: photoUrl,
            previewBytes: previewBytes,
            radius: 42,
            uploading: uploading,
            uploadProgress: uploadProgress,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.gold,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.background, width: 2),
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: AppTheme.background,
                size: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.name,
    required this.photoUrl,
    required this.radius,
    this.previewBytes,
    this.uploading = false,
    this.uploadProgress,
  });

  final String name;
  final String photoUrl;
  final double radius;
  final Uint8List? previewBytes;
  final bool uploading;
  final double? uploadProgress;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final cleanUrl = photoUrl.trim();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.goldSubtle,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.goldBorder, width: 1),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (previewBytes != null)
            Image.memory(previewBytes!, fit: BoxFit.cover)
          else if (cleanUrl.isNotEmpty)
            Image.network(
              cleanUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _AvatarFallback(name: name, radius: radius),
            )
          else
            _AvatarFallback(name: name, radius: radius),
          if (uploading)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.44),
              child: Center(
                child: CircularProgressIndicator(
                  value: uploadProgress,
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name, required this.radius});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _initials(name),
        style: TextStyle(
          color: AppTheme.gold,
          fontSize: radius * 0.66,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.success : AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        active ? 'Active Promoter' : 'Inactive Promoter',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textLow,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        _Panel(child: child),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(12)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: child,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppTheme.error : AppTheme.textHigh;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: destructive ? AppTheme.error : AppTheme.gold),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      trailing: destructive
          ? null
          : const Icon(Icons.chevron_right, color: AppTheme.textLow, size: 18),
      onTap: onTap,
    );
  }
}

String? _profileImageContentType(
  String? mimeType,
  String fileName,
  Uint8List bytes,
) {
  final normalizedMime = mimeType?.trim().toLowerCase();
  if (normalizedMime == 'image/jpeg' ||
      normalizedMime == 'image/jpg' ||
      normalizedMime == 'image/png' ||
      normalizedMime == 'image/webp') {
    return normalizedMime == 'image/jpg' ? 'image/jpeg' : normalizedMime;
  }

  final extension = fileName.split('.').last.toLowerCase();
  if (extension == 'jpg' || extension == 'jpeg') return 'image/jpeg';
  if (extension == 'png') return 'image/png';
  if (extension == 'webp') return 'image/webp';

  if (_hasJpegSignature(bytes)) return 'image/jpeg';
  if (_hasPngSignature(bytes)) return 'image/png';
  if (_hasWebpSignature(bytes)) return 'image/webp';
  return null;
}

bool _hasJpegSignature(Uint8List bytes) {
  return bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
}

bool _hasPngSignature(Uint8List bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A;
}

bool _hasWebpSignature(Uint8List bytes) {
  return bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
}

String _profileImageErrorMessage(Object error) {
  if (error is FirestoreAppException) return error.message;
  if (error is FirebaseException) {
    return switch (error.code) {
      'unauthorized' || 'permission-denied' =>
        'Image upload is not allowed yet. Check Storage rules.',
      'canceled' => 'Image upload was cancelled. Please try again.',
      'retry-limit-exceeded' =>
        'Image upload timed out. Please check your connection and try again.',
      'invalid-user' => 'Please sign in again before changing your photo.',
      _ =>
        error.message == null || error.message!.trim().isEmpty
            ? 'Failed to upload image. Your old avatar is unchanged.'
            : error.message!,
    };
  }
  final message = error.toString().toLowerCase();
  if (message.contains('timeout')) {
    return 'Image upload timed out. Please try again.';
  }
  if (message.contains('permission')) return 'Image upload is not allowed yet.';
  return 'Failed to upload image. Your old avatar is unchanged.';
}

String _uploadProgressLabel(double? progress) {
  if (progress == null || progress <= 0) return 'Uploading photo...';
  final percent = (progress * 100).clamp(1, 100).round();
  return 'Uploading $percent%';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return initials.isEmpty ? 'P' : initials;
}
