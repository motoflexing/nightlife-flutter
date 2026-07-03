import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../models/rsvp.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/state_views.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.profileStream(currentUser.uid),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data ?? currentUser;

        return StreamBuilder<List<Rsvp>>(
          stream: FirestoreService.instance.userRsvpsStream(profile.uid),
          builder: (context, snapshot) {
            final rsvps = snapshot.data ?? [];
            final upcoming = rsvps
                .where((rsvp) => rsvp.status.toLowerCase() != 'cancelled')
                .length;
            final attended = rsvps
                .where((rsvp) => rsvp.status.toLowerCase() == 'attended')
                .length;
            final city = profile.lastKnownCity.trim();

            // Saved count comes from the REAL saved-events stream (no hardcode).
            return StreamBuilder<List<NightlifeEvent>>(
              stream: FirestoreService.instance.savedEventsStream(),
              builder: (context, savedSnapshot) {
                final saved = savedSnapshot.data?.length ?? 0;
                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                  children: [
                    _ProfileHeader(
                      currentUser: profile,
                      city: city,
                      onEdit: () => _showEditProfileSheet(context, profile),
                      onSettings: () => _showSettingsSheet(context, profile),
                    ),
                    const SizedBox(height: 24),
                    // Real-data stat cards (Attended / Upcoming / Saved).
                    _StatRow(
                      attended: attended,
                      upcoming: upcoming,
                      saved: saved,
                    ),
                    const SizedBox(height: 30),
                    _SectionEyebrow('Your Next Nights'),
                    if (rsvps.isEmpty)
                      const _EmptyPanel(
                        icon: Icons.confirmation_number_outlined,
                        text:
                            'Your RSVPs will appear here once you join a '
                            'guestlist.',
                      )
                    else
                      ...rsvps.take(3).map((rsvp) => _RsvpTile(rsvp: rsvp)),
                    const SizedBox(height: 26),
                    _SectionEyebrow('Account'),
                    _ActionTile(
                      icon: Icons.security_outlined,
                      title: 'Privacy and settings',
                      onTap: () => _showSettingsSheet(context, profile),
                    ),
                    _ActionTile(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      onTap: () => _showHelpSheet(context),
                    ),
                    _ActionTile(
                      icon: Icons.logout,
                      title: 'Logout',
                      destructive: true,
                      onTap: () => _confirmAndLogout(context),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── Profile header: avatar, name, "member since", edit ────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.currentUser,
    required this.city,
    required this.onEdit,
    required this.onSettings,
  });

  final AppUser currentUser;
  final String city;
  final VoidCallback onEdit;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileAvatar(user: currentUser, radius: 44),
            const Spacer(),
            IconButton(
              tooltip: 'Settings',
              onPressed: onSettings,
              icon: const Icon(
                Icons.settings_outlined,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentUser.name.isEmpty
                        ? 'Nightlife Member'
                        : currentUser.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.displayMedium.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _memberLine(currentUser, city),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textBodyDim,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Ghost-gold "Edit".
            OutlinedButton(
              onPressed: onEdit,
              child: const Text('Edit'),
            ),
          ],
        ),
      ],
    );
  }

  /// "Member since {year} · {city}" — only includes the year when a real
  /// createdAt exists (epoch-0 means unknown → omitted), and the city only when
  /// set. Never fabricates a join date.
  String _memberLine(AppUser user, String city) {
    final year = user.createdAt.millisecondsSinceEpoch > 0
        ? user.createdAt.year
        : null;
    final parts = <String>[
      if (year != null) 'Member since $year',
      if (city.isNotEmpty) city,
    ];
    return parts.isEmpty ? _roleLabel(user.role) : parts.join(' · ');
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user, required this.radius});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _SafeInitialsAvatar(
      name: user.name,
      photoUrl: user.profilePhotoUrl,
      radius: radius,
    );
  }
}

// ─── Real-data stat row (Attended / Upcoming / Saved) ──────────────────────────

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.attended,
    required this.upcoming,
    required this.saved,
  });

  final int attended;
  final int upcoming;
  final int saved;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.goldBorder, width: 1),
          bottom: BorderSide(color: AppColors.goldBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          _Stat(label: 'Attended', value: attended.toString()),
          const _StatDivider(),
          _Stat(label: 'Upcoming', value: upcoming.toString()),
          const _StatDivider(),
          _Stat(label: 'Saved', value: saved.toString()),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: AppColors.goldBorder);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            // Playfair figure.
            Text(
              value,
              style: AppTypography.headlineMedium.copyWith(
                fontSize: 24,
                color: AppColors.champagne,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(
                fontSize: 8,
                letterSpacing: 0.18 * 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit profile sheet (logic preserved verbatim) ─────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.user});

  final AppUser user;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late String _city;
  late String _photoUrl;
  Uint8List? _pendingPhotoBytes;
  double? _photoUploadProgress;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _phone = TextEditingController(text: widget.user.phone);
    final userCity = widget.user.lastKnownCity.trim();
    _city = AppConstants.cities.contains(userCity) ? userCity : 'All';
    _photoUrl = widget.user.profilePhotoUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_uploadingPhoto || _saving) return;
    final previousPhotoUrl = _photoUrl;
    try {
      final authUser = AuthService.instance.currentFirebaseUser;
      if (authUser == null) {
        throw const FirestoreAppException('Please sign in again.');
      }
      if (authUser.uid != widget.user.uid) {
        throw FirestoreAppException(
          'Your session profile does not match. Please sign in again.',
          debugMessage:
              'auth.uid=${authUser.uid} profile.uid=${widget.user.uid}',
        );
      }
      await authUser.getIdToken(true).timeout(const Duration(seconds: 10));

      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        imageQuality: 82,
      );
      if (picked == null) {
        return;
      }


      setState(() {
        _uploadingPhoto = true;
        _photoUploadProgress = null;
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
      const maxBytes = 5 * 1024 * 1024; // 5MB
      if (bytes.lengthInBytes > maxBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Photo must be under 5MB. Please choose a smaller image.',
              ),
            ),
          );
          setState(() => _uploadingPhoto = false);
        }
        return;
      }

      if (mounted) {
        setState(() {
          _pendingPhotoBytes = bytes;
          _photoUploadProgress = 0;
        });
      }
      final url = await StorageService.instance.uploadProfilePhoto(
        bytes: bytes,
        userId: widget.user.uid,
        fileName: picked.name,
        contentType: contentType,
        filePath: picked.path,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _photoUploadProgress = progress);
        },
      );
      if (!mounted) return;
      await NetworkImage(url).evict();
      await FirestoreService.instance.updateUserProfilePhoto(
        userId: widget.user.uid,
        profilePhotoUrl: url,
      );
      await AuthService.instance.refreshCurrentUserProfileState(
        displayName: _name.text,
        photoUrl: url,
      );
      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _pendingPhotoBytes = null;
        _photoUploadProgress = null;
      });
      _showSnack('Profile photo updated');
    } on TimeoutException catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _photoUrl = previousPhotoUrl;
        _pendingPhotoBytes = null;
        _photoUploadProgress = null;
      });
      _showSnack('Image upload timed out. Please try again.');
    } on FirebaseException catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _photoUrl = previousPhotoUrl;
        _pendingPhotoBytes = null;
        _photoUploadProgress = null;
      });
      _showSnack(_profileImageErrorMessage(error));
    } catch (error, stackTrace) {
      if (error is FirestoreAppException && error.debugMessage != null) {
      }
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _photoUrl = previousPhotoUrl;
        _pendingPhotoBytes = null;
        _photoUploadProgress = null;
      });
      _showSnack(_profileImageErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
          _photoUploadProgress = null;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await FirestoreService.instance.updateUserProfile(
        userId: widget.user.uid,
        name: _name.text,
        phone: _phone.text,
        city: _city == 'All' ? '' : _city,
        profilePhotoUrl: _photoUrl,
      );
      await AuthService.instance.refreshCurrentUserProfileState(
        displayName: _name.text,
        photoUrl: _photoUrl,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (error) {
      if (!mounted) return;
      _showSnack(ErrorStateView.friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(22, 14, 22, bottomInset + 22),
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit profile',
                    style: AppTypography.headlineMedium.copyWith(fontSize: 20),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetAvatar(
                    name: _name.text,
                    photoUrl: _photoUrl,
                    previewBytes: _pendingPhotoBytes,
                    uploadProgress: _photoUploadProgress,
                    uploading: _uploadingPhoto,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _uploadingPhoto || _saving ? null : _pickPhoto,
                    icon: _uploadingPhoto
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : const Icon(Icons.camera_alt_outlined, size: 16),
                    label: Text(
                      _uploadingPhoto
                          ? _uploadProgressLabel(_photoUploadProgress)
                          : 'Change photo',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Full name'),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name cannot be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              initialValue: widget.user.email,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                helperText: 'Email is managed by your sign-in account.',
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _city,
              decoration: const InputDecoration(labelText: 'City'),
              items: AppConstants.cities
                  .map(
                    (city) => DropdownMenuItem(value: city, child: Text(city)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _city = value ?? _city),
            ),
            const SizedBox(height: 24),
            _PrimaryButton(
              label: 'Save profile',
              loading: _saving,
              onPressed: _saving || _uploadingPhoto ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetAvatar extends StatelessWidget {
  const _SheetAvatar({
    required this.name,
    required this.photoUrl,
    required this.previewBytes,
    required this.uploadProgress,
    required this.uploading,
  });

  final String name;
  final String photoUrl;
  final Uint8List? previewBytes;
  final double? uploadProgress;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return _SafeInitialsAvatar(
      name: name,
      photoUrl: photoUrl,
      previewBytes: previewBytes,
      radius: 42,
      uploading: uploading,
      uploadProgress: uploadProgress,
    );
  }
}

class _SafeInitialsAvatar extends StatelessWidget {
  const _SafeInitialsAvatar({
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
    final cleanUrl = photoUrl.trim();
    final size = radius * 2;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceEspresso,
        border: Border.all(color: AppColors.champagne, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (previewBytes != null)
            Image.memory(
              previewBytes!,
              key: ValueKey(previewBytes!.lengthInBytes),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _InitialsFallback(name: name, fontSize: radius * 0.82),
            )
          else if (cleanUrl.isNotEmpty)
            Image.network(
              cleanUrl,
              key: ValueKey(cleanUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _InitialsFallback(name: name, fontSize: radius * 0.82),
            )
          else
            _InitialsFallback(name: name, fontSize: radius * 0.82),
          if (uploading)
            ColoredBox(
              color: AppColors.obsidian.withValues(alpha: 0.5),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    value: uploadProgress,
                    strokeWidth: 2.6,
                    color: AppColors.champagne,
                    backgroundColor: AppColors.goldWash,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({required this.name, required this.fontSize});

  final String name;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          // Playfair monogram (design avatar).
          _initials(name),
          style: AppTypography.headlineMedium.copyWith(
            fontSize: fontSize,
            color: AppColors.champagne,
          ),
        ),
      ),
    );
  }
}

// ─── Section eyebrow ───────────────────────────────────────────────────────────

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.champagne,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.champagne.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RsvpTile extends StatelessWidget {
  const _RsvpTile({required this.rsvp});

  final Rsvp rsvp;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_activity_outlined,
            color: AppColors.champagne,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rsvp.eventTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 3),
                Text(
                  rsvp.status.toUpperCase(),
                  style: AppTypography.labelSmall.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textCaption,
              ),
            ),
          ),
        ],
      ),
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
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.destructive : AppColors.textBody;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(color: color),
      ),
      trailing: destructive
          ? null
          : const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 18,
            ),
      onTap: onTap,
    );
  }
}

/// Ivory primary button (design §7).
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: onPressed == null
              ? AppColors.ivory.withValues(alpha: 0.5)
              : AppColors.ivory,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            splashColor: Colors.transparent,
            highlightColor: AppColors.obsidian.withValues(alpha: 0.08),
            onTap: onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.obsidian,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      label.toUpperCase(),
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.obsidian,
                        letterSpacing: 0.16 * 12,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return initials.isEmpty ? '?' : initials;
}

String _roleLabel(String role) {
  return switch (role) {
    'promoter' => 'Promoter',
    'clubAdmin' => 'Venue',
    _ => 'Member',
  };
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
      'object-not-found' => 'Image upload did not finish. Please try again.',
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
  if (message.contains('bucket') ||
      message.contains('storage is not configured') ||
      message.contains('no default storage') ||
      message.contains('firebase storage')) {
    return 'Image upload is not configured yet.';
  }
  if (message.contains('timeout')) {
    return 'Image upload timed out. Check Firebase Storage setup/rules/network.';
  }
  if (message.contains('unauthorized') || message.contains('permission')) {
    return 'Image upload is not allowed yet. Check Storage rules.';
  }
  return 'Failed to upload image. Your old avatar is unchanged.';
}

String _uploadProgressLabel(double? progress) {
  if (progress == null || progress <= 0) return 'Uploading photo...';
  final percent = (progress * 100).clamp(1, 100).round();
  return 'Uploading $percent%';
}

void _showEditProfileSheet(BuildContext context, AppUser user) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surfaceEspresso,
    barrierColor: AppColors.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _EditProfileSheet(user: user),
  );
}

/// Confirms intent before signing out. Mirrors the account-deletion dialog:
/// a plain "Cancel" and a destructive-styled confirm. Sign-out runs only after
/// the user confirms, so logging out now takes two taps (tile -> confirm).
Future<void> _confirmAndLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Log out?'),
      content: Text(
        "You'll need to sign in again to access your account.",
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textBodyDim,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Log out',
            style: TextStyle(color: AppColors.destructive),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  await AuthService.instance.signOut();
}

void _showSettingsSheet(BuildContext context, AppUser user) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.surfaceEspresso,
    barrierColor: AppColors.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile settings',
              style: AppTypography.headlineMedium.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 16),
            _SettingsRow(label: 'Email', value: user.email),
            _SettingsRow(label: 'Role', value: _roleLabel(user.role)),
            _SettingsRow(
              label: 'Status',
              value: user.isApproved ? 'Verified' : user.status,
            ),
            const SizedBox(height: 16),
            Text(
              'Email changes are managed by your sign-in provider. Profile '
              'name, phone, city, and avatar can be changed from Edit profile.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textCaption,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showHelpSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.surfaceEspresso,
    barrierColor: AppColors.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & Support',
              style: AppTypography.headlineMedium.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              'For RSVP, event, or account issues, email us at '
              '${AppConstants.supportEmail} from your registered email address '
              'and the team will help you out.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textBodyDim,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textHigh,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
