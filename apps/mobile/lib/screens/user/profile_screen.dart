import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/rsvp.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/compact_ui.dart';
import '../../widgets/delete_account_dialogs.dart';
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
            final city = profile.lastKnownCity.trim().isEmpty
                ? 'City not set'
                : profile.lastKnownCity.trim();

            return ListView(
              padding: compactScreenPadding(context, bottom: 28),
              children: [
                _ProfileHero(
                  currentUser: profile,
                  city: city,
                  upcoming: upcoming,
                  attended: attended,
                  onEdit: () => _showEditProfileSheet(context, profile),
                  onSettings: () => _showSettingsSheet(context, profile),
                ),
                const SizedBox(height: 12),
                _Section(
                  title: 'Upcoming RSVPs',
                  child: rsvps.isEmpty
                      ? const _EmptyPanel(
                          icon: Icons.confirmation_number_outlined,
                          text:
                              'Your RSVPs will appear here once you join a guestlist.',
                        )
                      : Column(
                          children: rsvps
                              .take(3)
                              .map((rsvp) => _RsvpTile(rsvp: rsvp))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 12),
                const _Section(
                  title: 'Saved Events',
                  child: _EmptyPanel(
                    icon: Icons.favorite_border,
                    text: 'Favorite clubs and events will live here.',
                  ),
                ),
                const SizedBox(height: 12),
                _Section(
                  title: 'Account',
                  child: Column(
                    children: [
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
                        onTap: () async {
                          await AuthService.instance.signOut();
                        },
                      ),
                      const _DeleteAccountTile(),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.currentUser,
    required this.city,
    required this.upcoming,
    required this.attended,
    required this.onEdit,
    required this.onSettings,
  });

  final AppUser currentUser;
  final String city;
  final int upcoming;
  final int attended;
  final VoidCallback onEdit;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProfileAvatar(user: currentUser, radius: 30),
              const SizedBox(width: 10),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textHigh,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Badge(label: _roleLabel(currentUser.role)),
                        _Badge(
                          label: currentUser.isApproved
                              ? 'Verified'
                              : currentUser.status,
                          highlighted: currentUser.isApproved,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoTile(icon: Icons.location_on_outlined, label: city),
          _InfoTile(icon: Icons.mail_outline, label: currentUser.email),
          if (currentUser.phone.trim().isNotEmpty)
            _InfoTile(icon: Icons.call_outlined, label: currentUser.phone),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(label: 'Upcoming', value: upcoming.toString()),
              Container(width: 0.5, height: 30, color: AppTheme.borderSubtle),
              const _Stat(label: 'Saved', value: '0'),
              Container(width: 0.5, height: 30, color: AppTheme.borderSubtle),
              _Stat(label: 'Attended', value: attended.toString()),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: AppTheme.borderMid,
                      width: 0.5,
                    ),
                    foregroundColor: AppTheme.textHigh,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit profile'),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.elevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.borderSubtle,
                    width: 0.5,
                  ),
                ),
                child: IconButton(
                  tooltip: 'Settings',
                  onPressed: onSettings,
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: AppTheme.textMid,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 18),
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit profile',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textHigh,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _uploadingPhoto || _saving ? null : _pickPhoto,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppTheme.borderMid,
                        width: 0.5,
                      ),
                      foregroundColor: AppTheme.textMid,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
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
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name cannot be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: widget.user.email,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
                helperText: 'Email is managed by your sign-in account.',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.call_outlined),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _city,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              items: AppConstants.cities
                  .map(
                    (city) => DropdownMenuItem(value: city, child: Text(city)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _city = value ?? _city),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving || _uploadingPhoto ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: AppTheme.background,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'SAVE PROFILE',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                        ),
                      ),
              ),
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
        color: AppTheme.goldSubtle,
        border: Border.all(color: AppTheme.goldBorder, width: 1),
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
                  _InitialsFallback(name: name, fontSize: radius * 0.72),
            )
          else if (cleanUrl.isNotEmpty)
            Image.network(
              cleanUrl,
              key: ValueKey(cleanUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _InitialsFallback(name: name, fontSize: radius * 0.72),
            )
          else
            _InitialsFallback(name: name, fontSize: radius * 0.72),
          if (uploading)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.42),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    value: uploadProgress,
                    strokeWidth: 2.6,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
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
          _initials(name),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: AppTheme.gold,
          ),
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
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.textLow,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.goldSubtle
            : const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlighted ? AppTheme.goldBorder : AppTheme.borderSubtle,
          width: 0.5,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: highlighted ? AppTheme.gold : AppTheme.textMid,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textLow, size: 16),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textMid, fontSize: 13),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppTheme.goldSubtle,
        child: const Icon(
          Icons.local_activity_outlined,
          color: AppTheme.gold,
          size: 18,
        ),
      ),
      title: Text(
        rsvp.eventTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.textHigh,
        ),
      ),
      subtitle: Text(
        rsvp.status.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          color: AppTheme.textLow,
          letterSpacing: 0.5,
        ),
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
    return Row(
      children: [
        Icon(icon, color: AppTheme.textLow, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.textLow, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _DeleteAccountTile extends StatefulWidget {
  const _DeleteAccountTile();

  @override
  State<_DeleteAccountTile> createState() => _DeleteAccountTileState();
}

class _DeleteAccountTileState extends State<_DeleteAccountTile> {
  bool _deleting = false;

  Future<void> _deleteAccount() async {
    if (_deleting) return;
    final password = await confirmAndRequestDeletePassword(context);
    if (password == null || !mounted) return;

    // Capture the navigator before the async gap so we can leave any pushed
    // route after deletion, the same way Logout-related flows do.
    final navigator = Navigator.of(context);

    setState(() => _deleting = true);
    try {
      await AuthService.instance.deleteCurrentAccount(password: password);
      // Pop any pushed route first, then sign out so RoleRouterScreen rebuilds
      // to WelcomeScreen with no stale screen on top.
      if (navigator.canPop()) navigator.pop();
      try {
        await AuthService.instance.signOut();
      } catch (_) {
        // Auth user is already deleted; RoleRouterScreen rebuilds on its own.
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorStateView.friendlyError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      icon: Icons.delete_forever_outlined,
      title: _deleting ? 'Deleting account...' : 'Delete Account',
      destructive: true,
      onTap: _deleting ? () {} : _deleteAccount,
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
    final iconColor = destructive ? AppTheme.error : AppTheme.textMid;
    final titleColor = destructive ? AppTheme.error : AppTheme.textHigh;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: destructive
          ? null
          : const Icon(Icons.chevron_right, color: AppTheme.textLow, size: 16),
      onTap: onTap,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w300,
              color: AppTheme.textHigh,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textLow,
              letterSpacing: 0.5,
            ),
          ),
        ],
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
    backgroundColor: AppTheme.surface,
    builder: (_) => _EditProfileSheet(user: user),
  );
}

void _showSettingsSheet(BuildContext context, AppUser user) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppTheme.surface,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile settings',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _SettingsRow(label: 'Email', value: user.email),
            _SettingsRow(label: 'Role', value: _roleLabel(user.role)),
            _SettingsRow(
              label: 'Status',
              value: user.isApproved ? 'Verified' : user.status,
            ),
            const SizedBox(height: 12),
            const Text(
              'Email changes are managed by your sign-in provider. Profile name, phone, city, and avatar can be changed from Edit profile.',
              style: TextStyle(color: AppTheme.textMuted, height: 1.35),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check),
                label: const Text('Done'),
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
    backgroundColor: AppTheme.surface,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & Support',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              'For RSVP, event, or account issues, email us at '
              '${AppConstants.supportEmail} from your registered email address '
              'and the team will help you out.',
              style: const TextStyle(color: AppTheme.textMuted, height: 1.35),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check),
                label: const Text('Got it'),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
