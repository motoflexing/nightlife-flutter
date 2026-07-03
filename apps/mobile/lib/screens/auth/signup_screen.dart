import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/premium_loader.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.initialRole});

  /// Optional role to pre-select in the in-screen role picker (e.g. when
  /// arriving from the welcome screen's role cards). Validated against
  /// [AppConstants.roles]; an unknown value falls back to 'user'. The user can
  /// still change the role with the existing picker.
  final String? initialRole;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const _maxValidIdBytes = 5 * 1024 * 1024;
  static const _allowedValidIdExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _dob = TextEditingController();
  final _gender = TextEditingController();
  final _instagramId = TextEditingController();
  final _snapchatId = TextEditingController();
  final _businessName = TextEditingController();
  final _gstNumber = TextEditingController();
  final _businessPhone = TextEditingController();
  final _businessAddress = TextEditingController();
  final _businessInstagram = TextEditingController();

  late String _selectedRole;
  String _selectedTitle = 'Mr';
  // Gender dropdown selection. 'Male'/'Female' are saved as-is; 'Other' reveals
  // the _gender text field and the typed value is saved instead (falling back to
  // 'Other' if left blank). Shared by both User and Promoter signup.
  String _selectedGender = 'Male';
  String _businessCity = AppConstants.defaultCity;

  bool _loading = false;
  bool _uploadingId = false;
  bool _hidePassword = true;
  XFile? _validIdFile;
  Uint8List? _validIdBytes;
  _ValidIdStatus _validIdStatus = _ValidIdStatus.notSelected;

  final List<Map<String, String>> _roles = const [
    {'label': 'User', 'value': 'user'},
    {'label': 'Promoter', 'value': 'promoter'},
    {'label': 'Venue', 'value': 'clubAdmin'},
  ];

  @override
  void initState() {
    super.initState();
    // Pre-select the role passed in (e.g. from the welcome role cards), but only
    // if it is a real, requestable role; otherwise default to 'user'. The
    // in-screen role picker can still override this.
    final requested = widget.initialRole;
    _selectedRole = AppConstants.roles.contains(requested) ? requested! : 'user';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _dob.dispose();
    _gender.dispose();
    _instagramId.dispose();
    _snapchatId.dispose();
    _businessName.dispose();
    _gstNumber.dispose();
    _businessPhone.dispose();
    _businessAddress.dispose();
    _businessInstagram.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();

    // The latest selectable date is exactly 18 years ago, so the picker itself
    // cannot produce an under-18 date of birth. The validator below repeats the
    // age check as defense in depth (e.g. for any programmatic path).
    final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: eighteenYearsAgo,
      firstDate: DateTime(now.year - 100),
      lastDate: eighteenYearsAgo,
    );

    if (picked != null) {
      _dob.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      // Refresh so the "age confirmed" chip reflects the new value. This is a
      // cosmetic rebuild only — the real gate stays in the DOB validator.
      setState(() {});
    }
  }

  /// Parses a `dd/MM/yyyy` date of birth string (the format written by
  /// [_pickDob]). Returns null when the text is malformed or not a real
  /// calendar date.
  DateTime? _parseDob(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final date = DateTime(year, month, day);
    // Reject impossible dates that DateTime would otherwise roll over
    // (e.g. 31/02/2000 -> 02/03/2000).
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  /// Whole-years age on [asOf], accounting for month and day so someone born
  /// 17 years and 11 months ago is correctly counted as 17.
  int _ageOnDate(DateTime dob, DateTime asOf) {
    var age = asOf.year - dob.year;
    if (asOf.month < dob.month ||
        (asOf.month == dob.month && asOf.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// True only when the entered DOB is a real date AND the person is 18+.
  /// Drives the cosmetic "Age confirmed" chip. The authoritative gate remains
  /// the DOB field validator (which blocks submit); this never bypasses it.
  bool get _ageConfirmed {
    final dob = _parseDob(_dob.text.trim());
    if (dob == null) return false;
    return _ageOnDate(dob, DateTime.now()) >= 18;
  }

  /// The gender value to persist: the dropdown choice for Male/Female, or the
  /// user's typed value when "Other" is selected (falling back to 'Other' if the
  /// custom field was left blank).
  String _resolvedGender() {
    if (_selectedGender != 'Other') return _selectedGender;
    final custom = _gender.text.trim();
    return custom.isEmpty ? 'Other' : custom;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final isPromoter = _selectedRole == 'promoter';
      await AuthService.instance.signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        requestedRole: _selectedRole,
        title: isPromoter ? '' : _selectedTitle,
        // Gender + DOB now apply to all roles (promoters included).
        gender: _resolvedGender(),
        dob: _dob.text.trim(),
        instagramId: isPromoter ? '' : _instagramId.text.trim(),
        snapchatId: isPromoter ? '' : _snapchatId.text.trim(),
        // The valid-ID URL is uploaded and saved AFTER signup (see below), once
        // the user is authenticated — Storage rules require request.auth.uid ==
        // the upload's userId, which only exists post sign-up. Signup itself
        // stays a pure account+profile write with no Storage dependency.
        validIdUrl: '',
        businessName: _businessName.text.trim(),
        gstNumber: _gstNumber.text.trim(),
        businessPhone: _businessPhone.text.trim(),
        businessAddress: _businessAddress.text.trim(),
        businessCity: _businessCity,
        businessInstagram: _businessInstagram.text.trim(),
        documentUploadStatus: 'pending_upload',
      );

      // Upload the valid-ID document AFTER the account exists and is signed in,
      // keyed by the authenticated UID so it lands at valid_ids/{uid}/... (the
      // path Storage rules authorize for the owner). Best-effort: a Storage
      // failure here (e.g. Storage not yet enabled) must NOT fail an otherwise
      // successful signup — the document is optional and the profile already
      // carries documentUploadStatus 'pending_upload'.
      if (_validIdFile != null) {
        final uid = AuthService.instance.currentFirebaseUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          try {
            final idBytes = _validIdBytes ?? await _validIdFile!.readAsBytes();
            final ext = _validIdFile!.name.split('.').last.toLowerCase();
            final validIdUrl = await StorageService.instance.uploadValidId(
              bytes: idBytes,
              userId: uid,
              fileName: _validIdFile!.name,
              contentType: 'image/$ext',
            );
            await AuthService.instance.updateCurrentUserValidIdUrl(validIdUrl);
          } catch (error, stackTrace) {
            // Non-fatal: signup already succeeded. The user can re-upload their
            // ID later; their document status stays 'pending_upload'.
            debugPrintStack(stackTrace: stackTrace);
          }
        }
      }

      AnalyticsService.instance.logSignUp('email');
      if (mounted) {
        final isBusinessRole = _selectedRole == 'clubAdmin';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBusinessRole
                  ? 'Your profile has been submitted for admin review.'
                  : 'Account created successfully.',
            ),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showSnack(
          'Signup failed. Please check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _uploadingId = false;
        });
      }
    }
  }

  Future<void> _pickValidId() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (picked == null) {
        if (mounted) _showSnack('No image selected.');
        return;
      }

      final bytes = await picked.readAsBytes();
      final validationError = _validateValidIdFile(picked, bytes);
      if (validationError != null) {
        if (mounted) {
          setState(() {
            _validIdFile = null;
            _validIdBytes = null;
            _validIdStatus = _ValidIdStatus.notSelected;
          });
          _showSnack(validationError);
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _validIdFile = picked;
        _validIdBytes = bytes;
        _validIdStatus = _ValidIdStatus.selected;
      });
      _showSnack('ID image selected - pending upload.');
    } catch (error) {
      if (mounted) _showSnack('Unable to choose ID: $error');
    } finally {
      if (mounted) setState(() => _uploadingId = false);
    }
  }

  String? _validateValidIdFile(XFile file, Uint8List bytes) {
    final extension = _normalizedExtension(file.name);
    if (!_allowedValidIdExtensions.contains(extension)) {
      return 'Please upload a JPG, JPEG, PNG, or WEBP image under 5MB.';
    }

    if (bytes.isEmpty || bytes.lengthInBytes > _maxValidIdBytes) {
      return 'Please upload a JPG, JPEG, PNG, or WEBP image under 5MB.';
    }

    return null;
  }

  String _normalizedExtension(String? fileName) {
    final name = (fileName ?? '').trim().toLowerCase();
    if (!name.contains('.')) return '';
    return name.split('.').last.replaceFirst('.', '').trim();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _gap() => const SizedBox(height: 20);

  /// Gender dropdown (Male / Female / Other) shared by User and Promoter. When
  /// "Other" is selected, a text field is revealed for a custom value. Required:
  /// a choice must be made, and an "Other" selection must have a typed value.
  Widget _genderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedGender,
          decoration: const InputDecoration(labelText: 'Gender'),
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: _loading
              ? null
              : (value) {
                  if (value != null) {
                    setState(() => _selectedGender = value);
                  }
                },
        ),
        if (_selectedGender == 'Other') ...[
          _gap(),
          TextFormField(
            controller: _gender,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Your gender',
              hintText: 'Type your gender',
            ),
            validator: (value) {
              if (_selectedGender == 'Other' &&
                  (value == null || value.trim().isEmpty)) {
                return 'Enter your gender';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  /// Date-of-birth picker field with the shared 18+ age gate. Used by both User
  /// and Promoter. Reuses _pickDob (lastDate = 18 years ago) and the existing
  /// _parseDob / _ageOnDate helpers — no duplicated age logic.
  Widget _dobField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _dob,
          readOnly: true,
          onTap: _loading ? null : _pickDob,
          decoration: const InputDecoration(
            labelText: 'Date of birth',
            suffixIcon: Icon(
              Icons.calendar_month_outlined,
              color: AppColors.champagne,
              size: 18,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Select your date of birth';
            }
            final dob = _parseDob(value.trim());
            if (dob == null) {
              return 'Select a valid date of birth';
            }
            if (_ageOnDate(dob, DateTime.now()) < 18) {
              return 'You must be at least 18 years old to use this app.';
            }
            return null;
          },
        ),
        // Design's "Age confirmed — you must be 18 or over." chip. Shown only
        // when the real 18+ check passes; the DOB validator still gates submit.
        if (_ageConfirmed) ...[
          const SizedBox(height: 12),
          const _AgeConfirmedChip(),
        ],
      ],
    );
  }

  /// Segmented role picker — pill tabs, champagne-selected (design chips).
  Widget _roleSelector() {
    return Row(
      children: _roles.map((role) {
        final isSelected = _selectedRole == role['value'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _loading
                  ? null
                  : () => setState(() => _selectedRole = role['value']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.champagne
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.champagne
                        : AppColors.textDisabled,
                    width: 1,
                  ),
                ),
                child: Text(
                  role['label']!.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.14 * 11,
                    color: isSelected
                        ? AppColors.obsidian
                        : AppColors.textBody,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  bool get _isBusinessRole => _selectedRole == 'clubAdmin';

  bool get _isPromoterRole => _selectedRole == 'promoter';

  /// Tracked uppercase section eyebrow + trailing gold hairline (design).
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.champagne,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(child: _GoldHairline()),
        ],
      ),
    );
  }

  /// A titled section — eyebrow + fields, spaced generously (no boxed card;
  /// the design uses open sections separated by hairlines, not panels).
  Widget _section({required String label, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_sectionLabel(label), ...children],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < 500;
    final stepLabel = switch (_selectedRole) {
      'promoter' => 'Promoter',
      'clubAdmin' => 'Venue',
      _ => 'Guest · 1 of 1',
    };
    final heroTitle = switch (_selectedRole) {
      'promoter' => 'Build your\nfollowing.',
      'clubAdmin' => 'Register your\nhouse.',
      _ => 'Create your\nmembership.',
    };

    return Scaffold(
      backgroundColor: AppColors.obsidianDeep,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isPhone ? 24 : 32,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header: back · hairline · step indicator ─────────────
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _loading
                              ? null
                              : () => Navigator.of(context).maybePop(),
                          behavior: HitTestBehavior.opaque,
                          child: const Icon(
                            Icons.arrow_back,
                            size: 22,
                            color: AppColors.champagne,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(child: _GoldHairline()),
                        const SizedBox(width: 14),
                        Text(
                          stepLabel.toUpperCase(),
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 9,
                            letterSpacing: 0.24 * 9,
                            color: AppColors.textCaption,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Playfair hero title ──────────────────────────────────
                    Text(
                      heroTitle,
                      style: AppTypography.displayMedium.copyWith(
                        fontSize: 32,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Role selector ────────────────────────────────────────
                    _roleSelector(),
                    const SizedBox(height: 32),

                    // ── Personal Info ────────────────────────────────────────
                    _section(
                      label: 'Personal Info',
                      children: [
                        if (!_isPromoterRole) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _selectedTitle,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Mr', child: Text('Mr')),
                              DropdownMenuItem(value: 'Mrs', child: Text('Mrs')),
                              DropdownMenuItem(
                                value: 'Miss',
                                child: Text('Miss'),
                              ),
                              DropdownMenuItem(value: 'Ms', child: Text('Ms')),
                              DropdownMenuItem(value: 'Dr', child: Text('Dr')),
                              DropdownMenuItem(
                                value: 'Prof',
                                child: Text('Prof'),
                              ),
                            ],
                            onChanged: _loading
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _selectedTitle = value);
                                    }
                                  },
                          ),
                          _gap(),
                        ],
                        TextFormField(
                          controller: _name,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 2) {
                              return 'Enter your full name';
                            }
                            return null;
                          },
                        ),
                        // Gender + DOB (with 18+ age gate) apply to BOTH User
                        // and Promoter.
                        _gap(),
                        _genderField(),
                        _gap(),
                        _dobField(),
                        if (!_isPromoterRole) ...[
                          _gap(),
                          TextFormField(
                            controller: _instagramId,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Instagram ID (optional)',
                            ),
                          ),
                          _gap(),
                          TextFormField(
                            controller: _snapchatId,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Snapchat ID (optional)',
                            ),
                          ),
                        ],
                      ],
                    ),

                    // ── Business Details (clubAdmin only) ────────────────────
                    if (_isBusinessRole)
                      _section(
                        label: 'Business Details',
                        children: [
                          TextFormField(
                            controller: _businessName,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Business / Venue name',
                            ),
                            validator: (value) {
                              if (!_isBusinessRole) return null;
                              if (value == null || value.trim().isEmpty) {
                                return 'Business / Venue name is required';
                              }
                              return null;
                            },
                          ),
                          _gap(),
                          TextFormField(
                            controller: _gstNumber,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'GST number',
                            ),
                            validator: (value) {
                              if (!_isBusinessRole) return null;
                              if (value == null || value.trim().isEmpty) {
                                return 'GST number is required';
                              }
                              final gstRegex = RegExp(
                                r'^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}Z[A-Z\d]{1}$',
                              );
                              if (!gstRegex.hasMatch(
                                value.trim().toUpperCase(),
                              )) {
                                return 'Enter a valid GST number (e.g. 22AAAAA0000A1Z5)';
                              }
                              return null;
                            },
                          ),
                          _gap(),
                          TextFormField(
                            controller: _businessPhone,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Business phone',
                            ),
                            validator: (value) {
                              if (!_isBusinessRole) return null;
                              if (value == null || value.trim().isEmpty) {
                                return 'Phone number is required';
                              }
                              final digits = value
                                  .trim()
                                  .replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
                              if (!RegExp(r'^\d+$').hasMatch(digits)) {
                                return 'Enter digits only';
                              }
                              if (digits.length < 8 || digits.length > 15) {
                                return 'Enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                          _gap(),
                          TextFormField(
                            controller: _businessAddress,
                            textInputAction: TextInputAction.next,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Business address',
                            ),
                            validator: (value) {
                              if (!_isBusinessRole) return null;
                              if (value == null || value.trim().isEmpty) {
                                return 'Business address is required';
                              }
                              return null;
                            },
                          ),
                          _gap(),
                          DropdownButtonFormField<String>(
                            initialValue: _businessCity,
                            decoration: const InputDecoration(
                              labelText: 'City',
                            ),
                            items: AppConstants.cities
                                .where((city) => city != 'All')
                                .map(
                                  (city) => DropdownMenuItem(
                                    value: city,
                                    child: Text(city),
                                  ),
                                )
                                .toList(),
                            onChanged: _loading
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _businessCity = value);
                                    }
                                  },
                          ),
                          _gap(),
                          TextFormField(
                            controller: _businessInstagram,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Instagram link (optional)',
                            ),
                          ),
                          _gap(),
                          _ValidIdUploader(
                            file: _validIdFile,
                            previewBytes: _validIdBytes,
                            status: _validIdStatus,
                            uploading: _uploadingId,
                            onPick: _loading || _uploadingId
                                ? null
                                : _pickValidId,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Document upload is optional right now. If skipped, '
                            'your document status will be pending upload.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textCaption,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),

                    // ── Account ──────────────────────────────────────────────
                    _section(
                      label: 'Account',
                      children: [
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return 'Email is required';
                            final emailRegex = RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            );
                            if (!emailRegex.hasMatch(email)) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        _gap(),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Phone'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Phone number is required';
                            }
                            final digits = value
                                .trim()
                                .replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
                            if (!RegExp(r'^\d+$').hasMatch(digits)) {
                              return 'Enter digits only';
                            }
                            if (digits.length < 8 || digits.length > 15) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        _gap(),
                        TextFormField(
                          controller: _password,
                          obscureText: _hidePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(
                                  () => _hidePassword = !_hidePassword,
                                );
                              },
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            if (!RegExp(r'[A-Z]').hasMatch(value)) {
                              return 'Include at least one uppercase letter';
                            }
                            if (!RegExp(r'[0-9]').hasMatch(value)) {
                              return 'Include at least one number';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),

                    // ── Submit — ivory primary, tracked uppercase ────────────
                    _PrimarySubmitButton(
                      loading: _loading,
                      onPressed: _loading ? null : _submit,
                    ),

                    const SizedBox(height: 24),

                    // ── Bottom login link ────────────────────────────────────
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Already have an account?  ',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: _loading
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: Text(
                              'Sign In',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.champagne,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The signature champagne hairline that fades to transparent.
class _GoldHairline extends StatelessWidget {
  const _GoldHairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.champagne.withValues(alpha: 0.5),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// Design's "Age confirmed — you must be 18 or over." verified chip. Purely
/// presentational; the real 18+ gate lives in the DOB field validator.
class _AgeConfirmedChip extends StatelessWidget {
  const _AgeConfirmedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.goldWash,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, size: 16, color: AppColors.champagne),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Age confirmed — you must be 18 or over.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textBody,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ivory primary CTA (design §7): obsidian tracked-uppercase label, crisp
/// corners, no gradient. Label stays "Create account".
class _PrimarySubmitButton extends StatelessWidget {
  const _PrimarySubmitButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: loading
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
                      'Create account'.toUpperCase(),
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.obsidian,
                        letterSpacing: 0.18 * 12,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ValidIdStatus {
  notSelected,
  selected,
  uploading,
  uploadedPendingReview,
  uploadFailed,
}

class _ValidIdUploader extends StatelessWidget {
  const _ValidIdUploader({
    required this.file,
    required this.status,
    required this.uploading,
    required this.onPick,
    this.previewBytes,
  });

  final XFile? file;
  final _ValidIdStatus status;
  final bool uploading;
  final VoidCallback? onPick;
  final Uint8List? previewBytes;

  @override
  Widget build(BuildContext context) {
    final selected = status != _ValidIdStatus.notSelected;
    final statusText = switch (status) {
      _ValidIdStatus.notSelected => 'Upload valid ID',
      _ValidIdStatus.selected => 'ID image selected - pending upload',
      _ValidIdStatus.uploading => 'Uploading ID image...',
      _ValidIdStatus.uploadedPendingReview => 'Uploaded - pending review',
      _ValidIdStatus.uploadFailed => 'Upload failed - try again',
    };
    final statusColor = switch (status) {
      _ValidIdStatus.uploadedPendingReview => AppColors.champagne,
      _ValidIdStatus.uploadFailed => AppColors.destructive,
      _ValidIdStatus.selected || _ValidIdStatus.uploading =>
        AppColors.champagne,
      _ValidIdStatus.notSelected => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                selected
                    ? Icons.pending_actions_outlined
                    : Icons.badge_outlined,
                color: statusColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statusText,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textBody,
                    fontSize: 13,
                  ),
                ),
              ),
              if (uploading) const PremiumLoader.compact(size: 18),
            ],
          ),
          if (file != null) ...[
            const SizedBox(height: 10),
            Text(
              status == _ValidIdStatus.uploadedPendingReview
                  ? 'Uploaded for review. This image is not marked valid until reviewed.'
                  : status == _ValidIdStatus.uploadFailed
                  ? 'Upload failed. You can retry signup or replace the image.'
                  : 'Selected for upload. This image is not marked valid until reviewed.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textCaption,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            previewBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(
                      previewBytes!,
                      height: 126,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                : const SizedBox(
                    height: 96,
                    child: Center(child: Icon(Icons.image_outlined)),
                  ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: Text(
              (selected ? 'Replace ID image' : 'Choose from gallery')
                  .toUpperCase(),
            ),
          ),
        ],
      ),
    );
  }
}
