import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_user.dart';
import '../../models/club.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/compact_ui.dart';
import '../../widgets/delete_account_dialogs.dart';
import '../../widgets/premium_loader.dart';
import '../../widgets/state_views.dart';

class ClubProfileScreen extends StatelessWidget {
  const ClubProfileScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.profileStream(currentUser.uid),
      builder: (context, userSnapshot) {
        final profile = userSnapshot.data ?? currentUser;
        return StreamBuilder<Club?>(
          stream: FirestoreService.instance.clubForOwnerStream(profile.uid),
          builder: (context, clubSnapshot) {
            if (clubSnapshot.hasError) {
              return ErrorStateView(
                message: ErrorStateView.sanitizeError(clubSnapshot.error),
              );
            }
            if (clubSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Loading venue profile');
            }

            return _ClubProfileContent(
              currentUser: profile,
              club: clubSnapshot.data,
            );
          },
        );
      },
    );
  }
}

class _ClubProfileContent extends StatefulWidget {
  const _ClubProfileContent({required this.currentUser, required this.club});

  final AppUser currentUser;
  final Club? club;

  @override
  State<_ClubProfileContent> createState() => _ClubProfileContentState();
}

class _ClubProfileContentState extends State<_ClubProfileContent> {
  final _formKey = GlobalKey<FormState>();
  final _venueName = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _contactEmail = TextEditingController();
  final _gstDetails = TextEditingController();

  String _city = AppConstants.defaultCity;
  String _profilePhotoUrl = '';
  String _coverBannerUrl = '';
  String? _syncKey;
  String? _uploadingKind;
  double? _uploadProgress;
  bool _saving = false;
  bool _deletingAccount = false;

  @override
  void dispose() {
    _venueName.dispose();
    _address.dispose();
    _phone.dispose();
    _contactEmail.dispose();
    _gstDetails.dispose();
    super.dispose();
  }

  String get _clubId {
    final fromClub = widget.club?.id.trim() ?? '';
    if (fromClub.isNotEmpty) return fromClub;
    return widget.currentUser.clubId?.trim() ?? '';
  }

  void _syncControllers() {
    final club = widget.club;
    final user = widget.currentUser;
    final key = [
      user.updatedAt.millisecondsSinceEpoch,
      club?.id ?? '',
      club?.clubName ?? '',
      club?.profilePhotoUrl ?? '',
      club?.coverBannerUrl ?? '',
    ].join('|');
    if (_syncKey == key || _saving || _uploadingKind != null) return;
    _syncKey = key;

    _venueName.text = _firstNonEmpty([
      club?.clubName,
      user.venueName,
      user.businessName,
    ]);
    _address.text = _firstNonEmpty([club?.address, user.businessAddress]);
    _phone.text = _firstNonEmpty([club?.phone, user.businessPhone, user.phone]);
    _contactEmail.text = _firstNonEmpty([
      club?.businessEmail,
      user.contactEmail,
      user.email,
    ]);
    _gstDetails.text = _firstNonEmpty([
      club?.gstNumber,
      club?.businessRegistrationDetails,
      user.gstNumber,
      user.businessRegistrationDetails,
    ]);

    final nextCity = _firstNonEmpty([
      club?.city,
      user.city,
      user.lastKnownCity,
    ]);
    _city = AppConstants.cities.contains(nextCity) && nextCity != 'All'
        ? nextCity
        : AppConstants.defaultCity;
    _profilePhotoUrl = _firstNonEmpty([
      club?.profilePhotoUrl,
      user.profilePhotoUrl,
    ]);
    _coverBannerUrl = _firstNonEmpty([
      club?.coverBannerUrl,
      user.coverBannerUrl,
    ]);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    if (_clubId.isEmpty) {
      _showSnack('Venue profile is not ready yet. Please sign in again.');
      return;
    }

    setState(() => _saving = true);
    try {
      await FirestoreService.instance.updateVenueProfile(
        userId: widget.currentUser.uid,
        clubId: _clubId,
        venueName: _venueName.text,
        city: _city,
        address: _address.text,
        phone: _phone.text,
        contactEmail: _contactEmail.text,
        gstDetails: _gstDetails.text,
      );
      if (!mounted) return;
      _showSnack('Venue profile updated');
    } catch (error) {
      if (!mounted) return;
      _showSnack(ErrorStateView.friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickMedia(String kind) async {
    if (_uploadingKind != null || _saving) return;
    if (_clubId.isEmpty) {
      _showSnack('Venue profile is not ready yet. Please sign in again.');
      return;
    }

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: kind == 'cover' ? 1600 : 900,
        imageQuality: 84,
      );
      if (picked == null) return;

      setState(() {
        _uploadingKind = kind;
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
        _showSnack('Image must be under 5MB. Please choose a smaller file.');
        return;
      }

      final url = await StorageService.instance.uploadVenueMedia(
        bytes: bytes,
        userId: widget.currentUser.uid,
        fileName: picked.name,
        contentType: contentType,
        kind: kind,
        filePath: picked.path,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _uploadProgress = progress);
        },
      );
      await FirestoreService.instance.updateClubMedia(
        userId: widget.currentUser.uid,
        clubId: _clubId,
        profilePhotoUrl: kind == 'profile' ? url : null,
        coverBannerUrl: kind == 'cover' ? url : null,
      );
      if (kind == 'profile') {
        await AuthService.instance.refreshCurrentUserProfileState(
          photoUrl: url,
        );
      }
      if (!mounted) return;
      setState(() {
        if (kind == 'profile') {
          _profilePhotoUrl = url;
        } else {
          _coverBannerUrl = url;
        }
      });
      _showSnack(
        kind == 'profile'
            ? 'Venue profile image updated'
            : 'Cover banner updated',
      );
    } on TimeoutException {
      _showSnack('Image upload timed out. Please try again.');
    } on FirebaseException catch (error) {
      _showSnack(_profileImageErrorMessage(error));
    } catch (error) {
      _showSnack(_profileImageErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingKind = null;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (_deletingAccount) return;
    final password = await confirmAndRequestDeletePassword(
      context,
      message:
          'Your venue admin account will be deactivated and scheduled for '
          'deletion. You will be signed out and lose access immediately. '
          'This cannot be undone.',
    );
    if (password == null || !mounted) return;

    // Capture the navigator before the async gap so we can leave the pushed
    // profile route after deletion, the same way Logout does.
    final navigator = Navigator.of(context);

    setState(() => _deletingAccount = true);
    try {
      await AuthService.instance.deleteCurrentAccount(password: password);
      // Leave the pushed profile route FIRST, then sign out so RoleRouterScreen
      // rebuilds to WelcomeScreen with no stale screen on top.
      navigator.pop();
      try {
        await AuthService.instance.signOut();
      } catch (_) {
        // Auth user is already deleted; RoleRouterScreen rebuilds on its own.
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      _showSnack(ErrorStateView.friendlyError(error));
    }
  }

  /// Opens a hosted legal policy URL (Terms / Privacy) in the browser. Fails
  /// gracefully with a snackbar instead of crashing.
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.espresso,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncControllers();

    return Form(
      key: _formKey,
      child: ListView(
        padding: compactScreenPadding(context, bottom: 30),
        children: [
          _HeaderCard(
            venueName: _venueName.text,
            city: _city,
            profilePhotoUrl: _profilePhotoUrl,
            coverBannerUrl: _coverBannerUrl,
            status:
                widget.club?.verificationStatus ??
                widget.currentUser.verificationStatus,
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Venue information',
            child: Column(
              children: [
                _Field(
                  controller: _venueName,
                  label: 'Public Venue Name',
                  icon: Icons.storefront_outlined,
                  onChanged: (_) => setState(() {}),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _city,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  items: AppConstants.cities
                      .where((city) => city != 'All')
                      .map(
                        (city) =>
                            DropdownMenuItem(value: city, child: Text(city)),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _city = value ?? AppConstants.defaultCity,
                        ),
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _address,
                  label: 'City / Address',
                  icon: Icons.pin_drop_outlined,
                  maxLines: 2,
                ),
                _Field(
                  controller: _phone,
                  label: 'Phone number',
                  icon: Icons.call_outlined,
                  keyboardType: TextInputType.phone,
                ),
                _Field(
                  controller: _contactEmail,
                  label: 'Contact Email',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                ),
                _Field(
                  controller: _gstDetails,
                  label: 'Business Registration / GST Details',
                  icon: Icons.badge_outlined,
                  maxLines: 2,
                  isRequired: false,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saving || _uploadingKind != null
                        ? null
                        : _saveProfile,
                    icon: _saving
                        ? const PremiumLoader.compact(size: 18)
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? 'Saving...' : 'Save Venue Profile'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Media management',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth > 620;
                final tiles = [
                  _MediaTile(
                    title: 'Profile Picture',
                    subtitle: 'Square venue image',
                    imageUrl: _profilePhotoUrl,
                    icon: Icons.account_circle_outlined,
                    uploading: _uploadingKind == 'profile',
                    uploadProgress: _uploadProgress,
                    onTap: () => _pickMedia('profile'),
                  ),
                  _MediaTile(
                    title: 'Cover Banner',
                    subtitle: 'Wide venue header',
                    imageUrl: _coverBannerUrl,
                    icon: Icons.panorama_outlined,
                    wide: true,
                    uploading: _uploadingKind == 'cover',
                    uploadProgress: _uploadProgress,
                    onTap: () => _pickMedia('cover'),
                  ),
                ];
                if (!twoColumns) {
                  return Column(
                    children: [
                      tiles.first,
                      const SizedBox(height: 12),
                      tiles.last,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: tiles.first),
                    const SizedBox(width: 12),
                    Expanded(child: tiles.last),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Legal',
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () => _openLegalUrl(AppConstants.privacyPolicyUrl),
                ),
                _ActionTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () => _openLegalUrl(AppConstants.termsOfServiceUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Account actions',
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  destructive: true,
                  onTap: () async {
                    try {
                      await AuthService.instance.signOut();
                    } catch (_) {
                      _showSnack('Unable to log out right now.');
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
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.venueName,
    required this.city,
    required this.profilePhotoUrl,
    required this.coverBannerUrl,
    required this.status,
  });

  final String venueName;
  final String city;
  final String profilePhotoUrl;
  final String coverBannerUrl;
  final String status;

  @override
  Widget build(BuildContext context) {
    final cleanCover = coverBannerUrl.trim();
    final cleanName = venueName.trim().isEmpty ? 'Venue profile' : venueName;
    return Container(
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cleanCover.isNotEmpty)
            Image.network(cleanCover, fit: BoxFit.cover)
          else
            // Oxblood-tint → obsidian cover gradient (design venue header).
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.oxblood, AppColors.obsidian],
                ),
              ),
            ),
          // Bottom-up obsidian legibility scrim (design §9).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.obsidianDeep.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              children: [
                _VenueAvatar(name: cleanName, imageUrl: profilePhotoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cleanName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // Playfair venue name (design venue header).
                        style: AppTypography.headlineMedium.copyWith(
                          fontSize: 22,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 12),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        city,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textBodyDim,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _StatusBadge(status: status),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.icon,
    required this.uploading,
    required this.uploadProgress,
    required this.onTap,
    this.wide = false,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final IconData icon;
  final bool uploading;
  final double? uploadProgress;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: uploading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceEspresso,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.goldBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: wide ? 16 / 7 : 1,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.goldWash,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.goldBorder, width: 1),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cleanUrl.isNotEmpty)
                      Image.network(
                        cleanUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Icon(icon, color: AppColors.champagne, size: 42),
                      )
                    else
                      Icon(icon, color: AppColors.champagne, size: 42),
                    if (uploading)
                      ColoredBox(
                        color: AppColors.obsidian.withValues(alpha: 0.5),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: uploadProgress,
                            strokeWidth: 2.5,
                            color: AppColors.champagne,
                            backgroundColor: AppColors.goldWash,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 3),
            Text(
              uploading ? _uploadProgressLabel(uploadProgress) : subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textCaption,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: uploading ? null : onTap,
                icon: const Icon(Icons.upload_file_outlined, size: 17),
                label: Text((cleanUrl.isEmpty ? 'Upload' : 'Replace')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.isRequired = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool isRequired;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        validator: (value) {
          if (!isRequired) return null;
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }
}

class _VenueAvatar extends StatelessWidget {
  const _VenueAvatar({required this.name, required this.imageUrl});

  final String name;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    return Container(
      width: 70,
      height: 70,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.champagne, width: 1),
      ),
      child: cleanUrl.isNotEmpty
          ? Image.network(
              cleanUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _AvatarFallback(name: name),
            )
          : _AvatarFallback(name: name),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        // Playfair monogram (design avatar).
        _initials(name),
        style: AppTypography.headlineMedium.copyWith(
          fontSize: 24,
          color: AppColors.champagne,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    // Reads the venue's REAL verificationStatus — champagne when approved,
    // low-emphasis ivory otherwise. Single-accent Nocturne palette.
    final approved = status.toLowerCase() == 'approved';
    final color = approved ? AppColors.champagne : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: approved ? AppColors.goldWash : Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        (approved
                ? 'Approved Venue'
                : status.replaceAll('_', ' '))
            .toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          fontSize: 10,
          color: color,
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
          // Tracked uppercase gold eyebrow + fading gold hairline (design §11).
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
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
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceEspresso,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.goldBorder, width: 1),
          ),
          child: child,
        ),
      ],
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
    final color = destructive ? AppColors.destructive : AppColors.textBody;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: destructive ? AppColors.destructive : AppColors.champagne,
      ),
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

String _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final clean = value?.trim();
    if (clean != null && clean.isNotEmpty) return clean;
  }
  return '';
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
      'invalid-user' => 'Please sign in again before changing venue media.',
      _ =>
        error.message == null || error.message!.trim().isEmpty
            ? 'Failed to upload image. Your venue media is unchanged.'
            : error.message!,
    };
  }
  final message = error.toString().toLowerCase();
  if (message.contains('timeout')) {
    return 'Image upload timed out. Please try again.';
  }
  if (message.contains('permission')) return 'Image upload is not allowed yet.';
  return 'Failed to upload image. Your venue media is unchanged.';
}

String _uploadProgressLabel(double? progress) {
  if (progress == null || progress <= 0) return 'Uploading image...';
  final percent = (progress * 100).clamp(1, 100).round();
  return 'Uploading $percent%';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return initials.isEmpty ? 'V' : initials;
}
