import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/premium_gradient_button.dart';

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
  String _businessCity = 'Guwahati';

  bool _loading = false;
  bool _uploadingId = false;
  bool _hidePassword = true;
  XFile? _validIdFile;
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
      debugPrint('Signup flow started.');
      final user = await AuthService.instance.createAuthUser(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );

      await AuthService.instance.saveCurrentUserProfile(
        user: user,
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        requestedRole: _selectedRole,
        title: isPromoter ? '' : _selectedTitle,
        gender: isPromoter ? '' : _gender.text.trim(),
        dob: isPromoter ? '' : _dob.text.trim(),
        instagramId: isPromoter ? '' : _instagramId.text.trim(),
        snapchatId: isPromoter ? '' : _snapchatId.text.trim(),
        validIdUrl: '',
        businessName: _businessName.text.trim(),
        gstNumber: _gstNumber.text.trim(),
        businessPhone: _businessPhone.text.trim(),
        businessAddress: _businessAddress.text.trim(),
        businessCity: _businessCity,
        businessInstagram: _businessInstagram.text.trim(),
        documentUploadStatus: _validIdFile == null
            ? 'pending_upload'
            : 'pending_upload',
      );
      debugPrint('Signup flow completed.');
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
      debugPrint('Signup AuthException: ${error.message}');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error, stackTrace) {
      debugPrint('Signup failed: $error');
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

      debugPrint('ID image picked: ${picked.name}');
      final bytes = await picked.readAsBytes();
      debugPrint('ID image size: ${bytes.lengthInBytes}');
      final validationError = _validateValidIdFile(picked, bytes);
      if (validationError != null) {
        if (mounted) {
          setState(() {
            _validIdFile = null;
            _validIdStatus = _ValidIdStatus.notSelected;
          });
          _showSnack(validationError);
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _validIdFile = picked;
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
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.glassBorder),
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
                  gradient: isSelected ? AppTheme.premiumGradient : null,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text(
                  role['label']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppTheme.textMuted,
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < 500;

    return NeonScaffold(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isPhone ? 16 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: GlassCard(
                padding: EdgeInsets.all(isPhone ? 14 : 18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        child: Container(
                          width: isPhone ? 50 : 58,
                          height: isPhone ? 50 : 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.premiumGradient,
                          ),
                          child: Icon(
                            Icons.nightlife,
                            size: isPhone ? 28 : 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Create Account',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Complete your profile to start your nightlife journey.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _roleSelector(),
                      const SizedBox(height: 12),

                      if (!_isPromoterRole) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedTitle,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            prefixIcon: Icon(Icons.badge_outlined),
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
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return 'Enter your full name';
                          }
                          return null;
                        },
                      ),

                      _gap(),

                      if (!_isPromoterRole) ...[
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
                      ],

                      if (_isBusinessRole) ...[
                        TextFormField(
                          controller: _businessName,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Business / Venue name',
                            prefixIcon: const Icon(Icons.storefront_outlined),
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
                            if (value == null || value.trim().length < 8) {
                              return 'Enter a valid business phone';
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
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                          items:
                              const [
                                    'Guwahati',
                                    'Delhi',
                                    'Mumbai',
                                    'Bengaluru',
                                    'Kolkata',
                                    'Shillong',
                                  ]
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
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                        ),
                        _gap(),
                        _ValidIdUploader(
                          file: _validIdFile,
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
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        _gap(),
                      ],

                      if (!_isPromoterRole) ...[
                        TextFormField(
                          controller: _dob,
                          readOnly: true,
                          onTap: _loading ? null : _pickDob,
                          decoration: const InputDecoration(
                            labelText: 'Date of birth',
                            prefixIcon: Icon(Icons.calendar_month_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Select your date of birth';
                            }
                            return null;
                          },
                        ),
                        _gap(),
                      ],

                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email';
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
                          if (value == null || value.trim().length < 8) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),

                      _gap(),

                      if (!_isPromoterRole) ...[
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
                        _gap(),
                      ],

                      TextFormField(
                        controller: _password,
                        obscureText: _hidePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Use at least 6 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      PremiumGradientButton(
                        onPressed: _loading ? null : _submit,
                        loading: _loading,
                        icon: Icons.person_add_alt,
                        label: 'Sign up',
                      ),

                      const SizedBox(height: 22),

                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Already have an account? Login'),
                      ),
                    ],
                  ),
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
  });

  final XFile? file;
  final _ValidIdStatus status;
  final bool uploading;
  final VoidCallback? onPick;

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
      _ValidIdStatus.uploadedPendingReview => AppTheme.neonLime,
      _ValidIdStatus.uploadFailed => AppTheme.neonPink,
      _ValidIdStatus.notSelected => AppTheme.accentPink,
      _ => AppTheme.neonCyan,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.elevated.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
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
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (uploading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
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
              style: TextStyle(color: statusColor, fontSize: 12),
            ),
            const SizedBox(height: 8),
            FutureBuilder<Uint8List>(
              future: file!.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 96,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    snapshot.data!,
                    height: 126,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(selected ? 'Replace ID image' : 'Choose from gallery'),
          ),
        ],
      ),
    );
  }
}
