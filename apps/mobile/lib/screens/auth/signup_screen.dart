import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/premium_loader.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

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

  String _selectedRole = 'user';
  String _selectedTitle = 'Mr';
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

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1950),
      lastDate: now,
    );

    if (picked != null) {
      _dob.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final isPromoter = _selectedRole == 'promoter';
      String validIdUrl = '';
      if (_validIdFile != null) {
        final idBytes = _validIdBytes ?? await _validIdFile!.readAsBytes();
        final ext = _validIdFile!.name.split('.').last.toLowerCase();
        validIdUrl = await StorageService.instance.uploadValidId(
          bytes: idBytes,
          userId: _email.text.trim(),
          fileName: _validIdFile!.name,
          contentType: 'image/$ext',
        );
      }
      await AuthService.instance.signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        requestedRole: _selectedRole,
        title: isPromoter ? '' : _selectedTitle,
        gender: isPromoter ? '' : _gender.text.trim(),
        dob: isPromoter ? '' : _dob.text.trim(),
        instagramId: isPromoter ? '' : _instagramId.text.trim(),
        snapchatId: isPromoter ? '' : _snapchatId.text.trim(),
        validIdUrl: validIdUrl,
        businessName: _businessName.text.trim(),
        gstNumber: _gstNumber.text.trim(),
        businessPhone: _businessPhone.text.trim(),
        businessAddress: _businessAddress.text.trim(),
        businessCity: _businessCity,
        businessInstagram: _businessInstagram.text.trim(),
        documentUploadStatus: 'pending_upload',
      );
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

  Widget _gap() => const SizedBox(height: 10);

  Widget _roleSelector() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: Row(
        children: _roles.map((role) {
          final isSelected = _selectedRole == role['value'];
          return Expanded(
            child: GestureDetector(
              onTap: _loading
                  ? null
                  : () => setState(() => _selectedRole = role['value']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.goldSubtle : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  role['label']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w500 : FontWeight.w400,
                    color: isSelected ? AppTheme.gold : AppTheme.textLow,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool get _isBusinessRole => _selectedRole == 'clubAdmin';

  bool get _isPromoterRole => _selectedRole == 'promoter';

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 1.2,
          color: AppTheme.textLow,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _groupContainer({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < 500;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isPhone ? 20 : 28,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── Header ────────────────────────────────────────────
                    Align(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.goldSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.goldBorder,
                            width: 0.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.nightlife,
                          size: 22,
                          color: AppTheme.gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: AppTheme.textHigh,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Complete your profile to start your nightlife journey.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textLow,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Role selector ──────────────────────────────────────
                    _roleSelector(),
                    const SizedBox(height: 16),

                    // ── Personal Info group ───────────────────────────────
                    _groupContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionLabel('PERSONAL INFO'),
                          if (!_isPromoterRole) ...[
                            DropdownButtonFormField<String>(
                              initialValue: _selectedTitle,
                              decoration: const InputDecoration(
                                labelText: 'Title',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Mr',
                                  child: Text('Mr'),
                                ),
                                DropdownMenuItem(
                                  value: 'Mrs',
                                  child: Text('Mrs'),
                                ),
                                DropdownMenuItem(
                                  value: 'Miss',
                                  child: Text('Miss'),
                                ),
                                DropdownMenuItem(
                                  value: 'Ms',
                                  child: Text('Ms'),
                                ),
                                DropdownMenuItem(
                                  value: 'Dr',
                                  child: Text('Dr'),
                                ),
                                DropdownMenuItem(
                                  value: 'Prof',
                                  child: Text('Prof'),
                                ),
                              ],
                              onChanged: _loading
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(
                                          () => _selectedTitle = value,
                                        );
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
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().length < 2) {
                                return 'Enter your full name';
                              }
                              return null;
                            },
                          ),
                          if (!_isPromoterRole) ...[
                            _gap(),
                            TextFormField(
                              controller: _gender,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                                prefixIcon: Icon(Icons.wc_outlined),
                                hintText: 'Male / Female / Other',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter your gender';
                                }
                                return null;
                              },
                            ),
                            _gap(),
                            TextFormField(
                              controller: _dob,
                              readOnly: true,
                              onTap: _loading ? null : _pickDob,
                              decoration: const InputDecoration(
                                labelText: 'Date of birth',
                                prefixIcon: Icon(
                                  Icons.calendar_month_outlined,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Select your date of birth';
                                }
                                return null;
                              },
                            ),
                            _gap(),
                            TextFormField(
                              controller: _instagramId,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Instagram ID (optional)',
                                prefixIcon: Icon(Icons.alternate_email),
                              ),
                            ),
                            _gap(),
                            TextFormField(
                              controller: _snapchatId,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Snapchat ID (optional)',
                                prefixIcon: Icon(Icons.camera_alt_outlined),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Business Details group ─────────────────────────────
                    if (_isBusinessRole)
                      _groupContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionLabel('BUSINESS DETAILS'),
                            TextFormField(
                              controller: _businessName,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Business / Venue name',
                                prefixIcon: Icon(Icons.storefront_outlined),
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
                                prefixIcon: Icon(Icons.receipt_long_outlined),
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
                                prefixIcon: Icon(Icons.call_outlined),
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
                                prefixIcon: Icon(Icons.location_on_outlined),
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
                                prefixIcon: Icon(
                                  Icons.location_city_outlined,
                                ),
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
                                        setState(
                                          () => _businessCity = value,
                                        );
                                      }
                                    },
                            ),
                            _gap(),
                            TextFormField(
                              controller: _businessInstagram,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Instagram link (optional)',
                                prefixIcon: Icon(Icons.alternate_email),
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
                            const Text(
                              'Document upload is optional right now. If skipped, your document status will be pending upload.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textLow,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Account group ──────────────────────────────────────
                    _groupContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionLabel('ACCOUNT'),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
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
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              prefixIcon: Icon(Icons.call_outlined),
                            ),
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
                              prefixIcon: const Icon(Icons.lock_outline),
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
                    ),

                    // ── Submit ─────────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          disabledBackgroundColor: AppTheme.goldSubtle,
                          foregroundColor: AppTheme.background,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF080809),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'CREATE ACCOUNT',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ── Bottom login link ──────────────────────────────────
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Already have an account?  ',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textLow,
                            ),
                          ),
                          GestureDetector(
                            onTap: _loading
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w500,
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
      _ValidIdStatus.uploadedPendingReview => AppTheme.success,
      _ValidIdStatus.uploadFailed => AppTheme.error,
      _ValidIdStatus.selected || _ValidIdStatus.uploading => AppTheme.gold,
      _ValidIdStatus.notSelected => AppTheme.textLow,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textLow,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            previewBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(selected ? 'Replace ID image' : 'Choose from gallery'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.borderMid, width: 0.5),
              foregroundColor: AppTheme.textMid,
              textStyle: const TextStyle(
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
