// Superadmin web panel for the Nightlife website.
//
// Self-contained: drop this file at apps/website/lib/admin_panel.dart and add
// one route in main.dart (see instructions). Reached at /admin.
//
// Uses only methods that already exist in nightlife_shared:
//   AuthService.signIn / verifyCurrentUserIsSuperAdmin / signOut
//   FirestoreService.pendingApprovalsStream / usersStream / clubsStream /
//   adminEventsStream / approveUser / rejectUser

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nightlife_shared/nightlife_shared.dart';

/// Entry widget for the /admin route. Decides between the login gate and the
/// dashboard based on whether the current user is a verified superadmin.
class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  bool _checking = true;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final ok = await AuthService.instance.verifyCurrentUserIsSuperAdmin();
    if (!mounted) return;
    setState(() {
      _isSuperAdmin = ok;
      _checking = false;
    });
  }

  Future<void> _signOut() async {
    // There is no root authStateChanges listener on the website, so returning
    // to the login gate is driven entirely by this flag. Reset it in a finally
    // so that even if signOut() throws (e.g. a network blip) the user always
    // lands back on the login screen instead of being stuck on the dashboard.
    try {
      await AuthService.instance.signOut();
    } finally {
      if (mounted) setState(() => _isSuperAdmin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: PremiumLoader()),
      );
    }
    if (!_isSuperAdmin) {
      return _AdminLoginPage(onSignedIn: _check);
    }
    return _AdminDashboard(onSignOut: _signOut);
  }
}

/// Login gate. Signs in via Firebase, then verifies the superAdmin role.
/// A non-superadmin account is signed back out and shown an error.
class _AdminLoginPage extends StatefulWidget {
  const _AdminLoginPage({required this.onSignedIn});

  final Future<void> Function() onSignedIn;

  @override
  State<_AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<_AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signIn(
        email: _email.text.trim(),
        password: _password.text,
        requestedRole: 'user',
      );
      final ok = await AuthService.instance.verifyCurrentUserIsSuperAdmin();
      if (!ok) {
        await AuthService.instance.signOut();
        if (mounted) {
          setState(() => _error = 'This account is not a superadmin.');
        }
        return;
      }
      await widget.onSignedIn();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            color: AppTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Superadmin',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Restricted access. Authorized accounts only.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Email is required';
                        if (!email.contains('@')) return 'Enter valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.accentPink),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(_loading ? 'Signing in...' : 'Sign in'),
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

/// The dashboard shown to a verified superadmin: four tabs backed by the
/// existing shared streams.
class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard({required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          titleSpacing: 16,
          // Shorten the title on narrow (phone) widths so it never crowds the
          // sign-out action; full label on laptop widths.
          title: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = MediaQuery.sizeOf(context).width < 520;
              return Text(
                narrow ? 'Superadmin' : 'Superadmin Dashboard',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout),
            ),
          ],
          // Scrollable + start-aligned so the four tabs stay usable and never
          // overflow on narrow screens; they simply scroll horizontally.
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Pending Approvals'),
              Tab(text: 'Users'),
              Tab(text: 'Clubs'),
              Tab(text: 'Events'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PendingApprovalsTab(),
            _UsersTab(),
            _ClubsTab(),
            _EventsTab(),
          ],
        ),
      ),
    );
  }
}

/// Pending venue-admin approvals — the core unblock. Approve/Reject call the
/// existing FirestoreService methods.
class _PendingApprovalsTab extends StatelessWidget {
  const _PendingApprovalsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: FirestoreService.instance.pendingApprovalsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: PremiumLoader());
        }
        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString());
        }
        final users = snapshot.data ?? const <AppUser>[];
        if (users.isEmpty) {
          return const _EmptyState(
            title: 'No pending approvals',
            message: 'Venue admins awaiting review will appear here.',
          );
        }
        return _PaddedList(
          children: [
            for (final user in users) _PendingApprovalCard(user: user),
          ],
        );
      },
    );
  }
}

/// A single pending-approval row. Collapsed it shows the name/email/role/status
/// summary plus Approve/Reject. Tapping it expands an additive detail panel with
/// every available field from the user's `users/{uid}` doc and the linked club —
/// none of the approval logic changes.
class _PendingApprovalCard extends StatefulWidget {
  const _PendingApprovalCard({required this.user});

  final AppUser user;

  @override
  State<_PendingApprovalCard> createState() => _PendingApprovalCardState();
}

class _PendingApprovalCardState extends State<_PendingApprovalCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Card(
      color: AppTheme.surface,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Strip ExpansionTile's default divider lines so it blends with the card.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          onExpansionChanged: (value) => setState(() => _expanded = value),
          title: Text(
            user.name.isEmpty ? user.email : user.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${user.email}  •  venue admin  •  ${user.status}',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ApproveButton(user: user),
              const SizedBox(width: 8),
              _RejectButton(user: user),
              const SizedBox(width: 8),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: AppTheme.textMuted,
              ),
            ],
          ),
          children: [
            // Build the detail content only once the row is expanded so we don't
            // fire the raw-doc read or the club stream for collapsed rows.
            if (_expanded) _PendingApprovalDetails(user: user),
          ],
        ),
      ),
    );
  }
}

/// The expanded detail content: the full user doc plus the linked club. Uses a
/// one-time read of the raw `users/{uid}` doc to surface business fields that
/// are stored but not on the typed [AppUser] model, and the existing
/// [FirestoreService.clubForOwnerStream] for the venue. Read-only and additive.
class _PendingApprovalDetails extends StatefulWidget {
  const _PendingApprovalDetails({required this.user});

  final AppUser user;

  @override
  State<_PendingApprovalDetails> createState() =>
      _PendingApprovalDetailsState();
}

class _PendingApprovalDetailsState extends State<_PendingApprovalDetails> {
  late final Future<Map<String, dynamic>> _rawUserFuture;

  @override
  void initState() {
    super.initState();
    _rawUserFuture = _loadRawUser();
  }

  Future<Map<String, dynamic>> _loadRawUser() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();
      return doc.data() ?? const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: AppTheme.textMuted),
        const SizedBox(height: 12),
        const _DetailSectionTitle('Venue admin details'),
        const SizedBox(height: 8),
        FutureBuilder<Map<String, dynamic>>(
          future: _rawUserFuture,
          builder: (context, snapshot) {
            final raw = snapshot.data ?? const <String, dynamic>{};
            // Prefer typed model values; fall back to raw doc for fields that
            // are not part of the AppUser model (business / venue fields).
            String rawStr(String key) {
              final value = raw[key];
              return value == null ? '' : value.toString().trim();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow('UID', user.uid),
                _DetailRow('Name', user.name),
                _DetailRow('Email', user.email),
                _DetailRow('Phone', user.phone),
                _DetailRow('Role', user.role),
                _DetailRow('Status', user.status),
                _DetailRow('Verification', user.verificationStatus),
                _DetailRow('Document upload', user.documentUploadStatus),
                _DetailRow(
                  'Onboarding completed',
                  user.onboardingCompleted ? 'Yes' : 'No',
                ),
                _DetailRow('Active', user.isActive ? 'Yes' : 'No'),
                _DetailRow('Rejection reason', user.rejectionReason),
                _DetailRow('Promoter code', user.promoterCode ?? ''),
                _DetailRow('Club ID', user.clubId ?? ''),
                // Business / venue fields live only in the raw doc.
                _DetailRow('Business name', rawStr('businessName')),
                _DetailRow('Venue name', rawStr('venueName')),
                _DetailRow('Owner name', rawStr('ownerName')),
                _DetailRow('Business phone', rawStr('businessPhone')),
                _DetailRow('Business address', rawStr('businessAddress')),
                _DetailRow('City', rawStr('city')),
                _DetailRow('GST number', rawStr('gstNumber')),
                _DetailRow('Instagram', rawStr('instagramLink')),
                _DetailRow('Valid ID URL', rawStr('validIdUrl')),
                _DetailRow('Created', _formatDate(user.createdAt)),
                _DetailRow('Updated', _formatDate(user.updatedAt)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const _DetailSectionTitle('Linked venue / club'),
        const SizedBox(height: 8),
        StreamBuilder<Club?>(
          stream: FirestoreService.instance.clubForOwnerStream(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Loading venue…',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              );
            }
            final club = snapshot.data;
            if (club == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No linked venue found.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow('Club ID', club.id),
                _DetailRow('Club name', club.clubName),
                _DetailRow('Owner name', club.ownerName),
                _DetailRow('Business email', club.businessEmail),
                _DetailRow('Phone', club.phone),
                _DetailRow('City', club.city),
                _DetailRow('Address', club.address),
                _DetailRow('Instagram', club.instagram),
                _DetailRow('Google Maps', club.googleMapsLink),
                _DetailRow('Document URL', club.documentUrl),
                _DetailRow('Verification', club.verificationStatus),
                _DetailRow('Created', _formatDate(club.createdAt)),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One label/value line in the detail panel. Empty values render as "—".
class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty ? '—' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              display,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSectionTitle extends StatelessWidget {
  const _DetailSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontWeight: FontWeight.w900,
        fontSize: 12,
        letterSpacing: 1.2,
      ),
    );
  }
}

String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return '';
  return DateFormat('MMM d, y • h:mm a').format(date);
}

class _ApproveButton extends StatefulWidget {
  const _ApproveButton({required this.user});

  final AppUser user;

  @override
  State<_ApproveButton> createState() => _ApproveButtonState();
}

class _ApproveButtonState extends State<_ApproveButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await FirestoreService.instance.approveUser(widget.user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approved ${widget.user.email}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: _busy ? null : _run,
      child: Text(_busy ? '...' : 'Approve'),
    );
  }
}

class _RejectButton extends StatefulWidget {
  const _RejectButton({required this.user});

  final AppUser user;

  @override
  State<_RejectButton> createState() => _RejectButtonState();
}

class _RejectButtonState extends State<_RejectButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await FirestoreService.instance.rejectUser(widget.user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejected ${widget.user.email}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: _busy ? null : _run,
      child: Text(_busy ? '...' : 'Reject'),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: FirestoreService.instance.usersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: PremiumLoader());
        }
        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString());
        }
        final users = snapshot.data ?? const <AppUser>[];
        if (users.isEmpty) {
          return const _EmptyState(
            title: 'No users yet',
            message: 'Signed-up users will appear here.',
          );
        }
        return _PaddedList(
          children: [
            for (final user in users)
              Card(
                color: AppTheme.surface,
                child: ListTile(
                  title: Text(
                    user.name.isEmpty ? user.email : user.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${user.email}  •  ${user.role}  •  ${user.status}'
                    '${user.isActive ? '' : '  •  inactive'}',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ClubsTab extends StatelessWidget {
  const _ClubsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Club>>(
      stream: FirestoreService.instance.clubsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: PremiumLoader());
        }
        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString());
        }
        final clubs = snapshot.data ?? const <Club>[];
        if (clubs.isEmpty) {
          return const _EmptyState(
            title: 'No clubs yet',
            message: 'Venues created during onboarding will appear here.',
          );
        }
        return _PaddedList(
          children: [
            for (final club in clubs)
              Card(
                color: AppTheme.surface,
                child: ListTile(
                  title: Text(
                    club.clubName.isEmpty ? '(unnamed venue)' : club.clubName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${club.city}  •  ${club.verificationStatus}',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EventsTab extends StatelessWidget {
  const _EventsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NightlifeEvent>>(
      stream: FirestoreService.instance.adminEventsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: PremiumLoader());
        }
        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString());
        }
        final events = snapshot.data ?? const <NightlifeEvent>[];
        if (events.isEmpty) {
          return const _EmptyState(
            title: 'No events yet',
            message: 'Events created by approved venue admins will appear here.',
          );
        }
        return _PaddedList(
          children: [
            for (final event in events)
              Card(
                color: AppTheme.surface,
                child: ListTile(
                  title: Text(
                    event.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${event.venueName}  •  ${event.city}  •  '
                    '${DateFormat('MMM d, h:mm a').format(event.dateTime)}'
                    '${event.isActive ? '' : '  •  inactive'}',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PaddedList extends StatelessWidget {
  const _PaddedList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: children,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Something went wrong',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
