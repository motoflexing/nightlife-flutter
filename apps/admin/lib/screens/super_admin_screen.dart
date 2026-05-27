import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nightlife_shared/core/theme/app_theme.dart';
import 'package:nightlife_shared/core/utils/formatters.dart';
import 'package:nightlife_shared/models/app_user.dart';
import 'package:nightlife_shared/models/club.dart';
import 'package:nightlife_shared/models/event.dart';
import 'package:nightlife_shared/models/promoter.dart';
import 'package:nightlife_shared/models/rsvp.dart';
import 'package:nightlife_shared/services/auth_service.dart';
import 'package:nightlife_shared/services/firestore_service.dart';
import 'package:nightlife_shared/widgets/premium_loader.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  int _index = 0;
  bool _maintenanceMode = false;

  @override
  Widget build(BuildContext context) {
    final sections = [
      _SuperAdminSection(
        label: 'Analytics Overview',
        icon: Icons.query_stats,
        child: _AnalyticsOverview(currentUser: widget.currentUser),
      ),
      const _SuperAdminSection(
        label: 'All Events',
        icon: Icons.local_fire_department_outlined,
        child: _AllEventsSection(),
      ),
      const _SuperAdminSection(
        label: 'All Users',
        icon: Icons.people_outline,
        child: _AllUsersSection(),
      ),
      const _SuperAdminSection(
        label: 'Promoters',
        icon: Icons.campaign_outlined,
        child: _PromotersSection(),
      ),
      const _SuperAdminSection(
        label: 'RSVPs',
        icon: Icons.confirmation_number_outlined,
        child: _RsvpsSection(),
      ),
      const _SuperAdminSection(
        label: 'Payments',
        icon: Icons.payments_outlined,
        child: _PaymentsSection(),
      ),
      const _SuperAdminSection(
        label: 'Clubs/Venues',
        icon: Icons.storefront_outlined,
        child: _ClubsSection(),
      ),
      _SuperAdminSection(
        label: 'Emergency Controls',
        icon: Icons.emergency_outlined,
        child: _EmergencyControlsSection(
          currentUser: widget.currentUser,
          maintenanceMode: _maintenanceMode,
          onMaintenanceChanged: _setMaintenanceMode,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 860;

        return Scaffold(
          backgroundColor: _FireAdminColors.black,
          appBar: mobile
              ? null
              : AppBar(
                  title: Text(
                    sections[_index].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
          bottomNavigationBar: mobile
              ? _SectionBottomNav(
                  sections: sections,
                  selectedIndex: _index,
                  onSelected: (value) => setState(() => _index = value),
                )
              : null,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _FireAdminColors.black,
                  _FireAdminColors.charcoal,
                  Color(0xFF1A0504),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _FireGridPainter()),
                ),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _CommandHeader(
                        currentUser: widget.currentUser,
                        onLogout: AuthService.instance.signOut,
                      ),
                      Expanded(
                        child: mobile
                            ? sections[_index].child
                            : Row(
                                children: [
                                  _SectionRail(
                                    sections: sections,
                                    selectedIndex: _index,
                                    onSelected: (value) {
                                      setState(() => _index = value);
                                    },
                                  ),
                                  Expanded(child: sections[_index].child),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _setMaintenanceMode(bool value) async {
    setState(() => _maintenanceMode = value);
    try {
      await FirestoreService.instance.setMaintenanceModePlaceholder(value);
    } catch (error) {
      if (!mounted) return;
      setState(() => _maintenanceMode = !value);
      _showActionError(context, error);
    }
  }
}

class _SuperAdminSection {
  const _SuperAdminSection({
    required this.label,
    required this.icon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Widget child;
}

class _FireAdminColors {
  static const black = Color(0xFF030304);
  static const charcoal = Color(0xFF10111A);
  static const panel = Color(0xE6111220);
  static const lava = Color(0xFFFF2D55);
  static const ember = Color(0xFFFF3D8B);
  static const gold = Color(0xFFB8FF5C);
  static const red = Color(0xFFA855F7);
}

class _CommandHeader extends StatelessWidget {
  const _CommandHeader({required this.currentUser, required this.onLogout});

  final AppUser currentUser;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    final avatarSize = mobile ? 38.0 : 50.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        mobile ? 12 : 16,
        mobile ? 6 : 8,
        mobile ? 12 : 16,
        mobile ? 8 : 12,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(mobile ? 10 : 14),
        decoration: BoxDecoration(
          color: _FireAdminColors.panel,
          borderRadius: BorderRadius.circular(mobile ? 14 : 18),
          border: Border.all(
            color: _FireAdminColors.lava.withValues(alpha: 0.34),
          ),
          boxShadow: [
            BoxShadow(
              color: _FireAdminColors.ember.withValues(alpha: 0.2),
              blurRadius: 34,
              spreadRadius: -12,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    _FireAdminColors.gold,
                    _FireAdminColors.lava,
                    _FireAdminColors.red,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _FireAdminColors.lava.withValues(alpha: 0.45),
                    blurRadius: 26,
                  ),
                ],
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: Colors.black,
                size: 24,
              ),
            ),
            SizedBox(width: mobile ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Super Admin',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: mobile ? 16 : null,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentUser.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: mobile ? 11 : 13,
                    ),
                  ),
                ],
              ),
            ),
            _LiveBadge(compact: mobile),
            SizedBox(width: mobile ? 6 : 8),
            _HeaderLogoutButton(compact: mobile, onTap: onLogout),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _FireAdminColors.lava),
        color: _FireAdminColors.lava.withValues(alpha: 0.12),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: _FireAdminColors.gold,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _HeaderLogoutButton extends StatelessWidget {
  const _HeaderLogoutButton({required this.compact, required this.onTap});

  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Logout',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: compact ? 32 : 36,
          height: compact ? 32 : 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: _FireAdminColors.lava.withValues(alpha: 0.32),
            ),
          ),
          child: Icon(
            Icons.logout,
            size: compact ? 16 : 18,
            color: _FireAdminColors.gold,
          ),
        ),
      ),
    );
  }
}

class _SectionBottomNav extends StatelessWidget {
  const _SectionBottomNav({
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_SuperAdminSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      height: 66,
      selectedIndex: selectedIndex,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      onDestinationSelected: onSelected,
      backgroundColor: const Color(0xF2030304),
      indicatorColor: _FireAdminColors.lava.withValues(alpha: 0.2),
      destinations: [
        for (final section in sections)
          NavigationDestination(
            icon: Icon(section.icon, size: 20),
            selectedIcon: Icon(section.icon, size: 20),
            label: _shortSectionLabel(section.label),
          ),
      ],
    );
  }
}

String _shortSectionLabel(String label) {
  return switch (label) {
    'Analytics Overview' => 'Analytics',
    'All Events' => 'Events',
    'All Users' => 'Users',
    'Clubs/Venues' => 'Venues',
    'Emergency Controls' => 'Emergency',
    _ => label,
  };
}

class _SectionRail extends StatelessWidget {
  const _SectionRail({
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_SuperAdminSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 212,
      margin: const EdgeInsets.fromLTRB(16, 0, 12, 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _FireAdminColors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _FireAdminColors.lava.withValues(alpha: 0.24),
        ),
      ),
      child: ListView.separated(
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: selected
                    ? const LinearGradient(
                        colors: [_FireAdminColors.lava, _FireAdminColors.ember],
                      )
                    : null,
                color: selected ? null : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(
                    sections[index].icon,
                    size: 19,
                    color: selected ? Colors.black : _FireAdminColors.gold,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sections[index].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnalyticsOverview extends StatelessWidget {
  const _AnalyticsOverview({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _adminListPadding(context),
      children: [
        _ResponsiveMetricGrid(
          children: [
            _StreamMetric<NightlifeEvent>(
              label: 'All Events',
              icon: Icons.local_activity_outlined,
              stream: FirestoreService.instance.adminEventsStream(),
            ),
            _StreamMetric<AppUser>(
              label: 'All Users',
              icon: Icons.people_outline,
              stream: FirestoreService.instance.usersStream(),
            ),
            _StreamMetric<Promoter>(
              label: 'Promoters',
              icon: Icons.campaign_outlined,
              stream: FirestoreService.instance.promotersStream(),
            ),
            _StreamMetric<Club>(
              label: 'Clubs/Venues',
              icon: Icons.storefront_outlined,
              stream: FirestoreService.instance.clubsStream(),
            ),
            _StreamMetric<Rsvp>(
              label: 'RSVPs',
              icon: Icons.fact_check_outlined,
              stream: FirestoreService.instance.allRsvpsStream(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                icon: Icons.radar_outlined,
                title: 'Restricted Operations Pulse',
                action: ElevatedButton.icon(
                  onPressed: () =>
                      FirestoreService.instance.seedDemoEvents(currentUser.uid),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Seed demo events'),
                ),
              ),
              const SizedBox(height: 16),
              const Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SignalChip(label: 'Firestore gated'),
                  _SignalChip(label: 'Role locked'),
                  _SignalChip(label: 'Isolated web dashboard'),
                  _SignalChip(label: 'Venue approvals live'),
                  _SignalChip(label: 'RSVP command ready'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResponsiveMetricGrid extends StatelessWidget {
  const _ResponsiveMetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1280
            ? 4
            : width >= 1000
            ? 3
            : 2;
        final mobile = width < 640;
        return GridView.count(
          crossAxisCount: columns,
          childAspectRatio: mobile ? 1.72 : 1.65,
          crossAxisSpacing: mobile ? 8 : 10,
          mainAxisSpacing: mobile ? 8 : 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

class _StreamMetric<T> extends StatelessWidget {
  const _StreamMetric({
    required this.label,
    required this.icon,
    required this.stream,
  });

  final String label;
  final IconData icon;
  final Stream<List<T>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) {
        return _MetricCard(
          label: label,
          icon: icon,
          value: snapshot.hasData ? snapshot.data!.length.toString() : '...',
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.icon,
    required this.value,
  });

  final String label;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;

    return _Panel(
      compact: true,
      child: Row(
        children: [
          Container(
            width: mobile ? 30 : 34,
            height: mobile ? 30 : 34,
            decoration: BoxDecoration(
              color: _FireAdminColors.lava.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _FireAdminColors.lava.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              icon,
              color: _FireAdminColors.gold,
              size: mobile ? 17 : 19,
            ),
          ),
          SizedBox(width: mobile ? 8 : 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: mobile ? 21 : 24,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: mobile ? 11 : 12,
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

class _AllEventsSection extends StatelessWidget {
  const _AllEventsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NightlifeEvent>>(
      stream: FirestoreService.instance.adminEventsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _CenterState(message: 'Loading events');
        }
        if (snapshot.hasError) {
          return _CenterState(message: snapshot.error.toString());
        }
        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return const _CenterState(message: 'No events found');
        }
        return ListView.separated(
          padding: _adminListPadding(context),
          itemCount: events.length,
          separatorBuilder: (_, _) =>
              SizedBox(height: MediaQuery.sizeOf(context).width < 640 ? 8 : 12),
          itemBuilder: (context, index) {
            final event = events[index];
            return _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RecordHeader(
                    icon: Icons.local_fire_department_outlined,
                    title: event.title.isEmpty ? 'Untitled event' : event.title,
                    subtitle:
                        '${event.venueName} - ${event.city} - ${Formatters.eventDate(event.dateTime)}',
                    status: event.isActive ? 'Active' : 'Inactive',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _runAdminAction(
                          context,
                          () => FirestoreService.instance.setEventFeatured(
                            event.id,
                            true,
                          ),
                        ),
                        icon: const Icon(Icons.stars_outlined),
                        label: const Text('Feature'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _runAdminAction(
                          context,
                          () => FirestoreService.instance.deactivateEvent(
                            event.id,
                          ),
                        ),
                        icon: const Icon(Icons.visibility_off_outlined),
                        label: const Text('Deactivate'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _confirmDeleteEvent(context, event),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AllUsersSection extends StatelessWidget {
  const _AllUsersSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: FirestoreService.instance.usersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _CenterState(message: 'Loading users');
        }
        if (snapshot.hasError) {
          return _CenterState(message: snapshot.error.toString());
        }
        final users = snapshot.data ?? [];
        return ListView.separated(
          padding: _adminListPadding(context),
          itemCount: users.length,
          separatorBuilder: (_, _) =>
              SizedBox(height: MediaQuery.sizeOf(context).width < 640 ? 8 : 12),
          itemBuilder: (context, index) {
            final user = users[index];
            return _Panel(
              onTap: () => _showUserDetailDialog(context, user),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RecordHeader(
                    icon: Icons.person_outline,
                    title: user.name.isEmpty ? user.email : user.name,
                    subtitle: '${user.email} - ${user.role}',
                    status: user.status,
                    onStatusTap: _isReviewStatus(user.status)
                        ? () => _showUserReviewDialog(context, user)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (user.isPending)
                        ElevatedButton.icon(
                          onPressed: () => _runAdminAction(
                            context,
                            () => FirestoreService.instance.approveUser(user),
                          ),
                          icon: const Icon(Icons.check),
                          label: const Text('Approve admin'),
                        ),
                      if (user.isPending)
                        OutlinedButton.icon(
                          onPressed: () => _runAdminAction(
                            context,
                            () => FirestoreService.instance.rejectUser(user),
                          ),
                          icon: const Icon(Icons.close),
                          label: const Text('Reject admin'),
                        ),
                      OutlinedButton.icon(
                        onPressed: user.isSuperAdmin
                            ? null
                            : () => _runAdminAction(
                                context,
                                () => FirestoreService.instance.setUserActive(
                                  user.uid,
                                  !user.isActive,
                                ),
                              ),
                        icon: Icon(
                          user.isActive
                              ? Icons.block_outlined
                              : Icons.restore_outlined,
                        ),
                        label: Text(user.isActive ? 'Ban user' : 'Reinstate'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PromotersSection extends StatelessWidget {
  const _PromotersSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Promoter>>(
      stream: FirestoreService.instance.promotersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _CenterState(message: 'Loading promoters');
        }
        if (snapshot.hasError) {
          return _CenterState(message: snapshot.error.toString());
        }
        final promoters = snapshot.data ?? [];
        if (promoters.isEmpty) {
          return const _CenterState(message: 'No promoters found');
        }
        return ListView.separated(
          padding: _adminListPadding(context),
          itemCount: promoters.length,
          separatorBuilder: (_, _) =>
              SizedBox(height: MediaQuery.sizeOf(context).width < 640 ? 8 : 12),
          itemBuilder: (context, index) {
            final promoter = promoters[index];
            return _Panel(
              onTap: () => _showPromoterDetailDialog(context, promoter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RecordHeader(
                    icon: Icons.campaign_outlined,
                    title: promoter.name,
                    subtitle:
                        '${promoter.email} - ${promoter.referralCode} - ${promoter.totalRsvps} RSVPs',
                    status: promoter.isActive ? 'Active' : 'Banned',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _runAdminAction(
                      context,
                      () => FirestoreService.instance.setPromoterActive(
                        promoter,
                        !promoter.isActive,
                      ),
                    ),
                    icon: Icon(
                      promoter.isActive
                          ? Icons.block_outlined
                          : Icons.restore_outlined,
                    ),
                    label: Text(
                      promoter.isActive ? 'Ban promoter' : 'Reinstate',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RsvpsSection extends StatelessWidget {
  const _RsvpsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Rsvp>>(
      stream: FirestoreService.instance.allRsvpsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _CenterState(message: 'Loading RSVPs');
        }
        if (snapshot.hasError) {
          return _CenterState(message: snapshot.error.toString());
        }
        final rsvps = snapshot.data ?? [];
        if (rsvps.isEmpty) {
          return const _CenterState(message: 'No RSVPs found');
        }
        return ListView.separated(
          padding: _adminListPadding(context),
          itemCount: rsvps.length,
          separatorBuilder: (_, _) =>
              SizedBox(height: MediaQuery.sizeOf(context).width < 640 ? 8 : 12),
          itemBuilder: (context, index) {
            final rsvp = rsvps[index];
            return _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RecordHeader(
                    icon: Icons.confirmation_number_outlined,
                    title: rsvp.userName.isEmpty ? rsvp.userId : rsvp.userName,
                    subtitle:
                        '${rsvp.eventTitle} - ${rsvp.userPhone} - ${Formatters.eventDate(rsvp.createdAt)}',
                    status: rsvp.rsvpStatus,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _runAdminAction(
                          context,
                          () => FirestoreService.instance.updateRsvpStatus(
                            rsvp.id,
                            'confirmed',
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Confirm'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _runAdminAction(
                          context,
                          () => FirestoreService.instance.updateRsvpStatus(
                            rsvp.id,
                            'approved',
                          ),
                        ),
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Approve'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _runAdminAction(
                          context,
                          () => FirestoreService.instance.updateRsvpStatus(
                            rsvp.id,
                            'rejected',
                          ),
                        ),
                        icon: const Icon(Icons.block_outlined),
                        label: const Text('Reject'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PaymentsSection extends StatelessWidget {
  const _PaymentsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Rsvp>>(
      stream: FirestoreService.instance.allRsvpsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _CenterState(message: 'Loading payments');
        }
        if (snapshot.hasError) {
          return _CenterState(message: snapshot.error.toString());
        }
        final rsvps = snapshot.data ?? [];
        if (rsvps.isEmpty) {
          return const _CenterState(message: 'No payment records found');
        }
        return ListView.separated(
          padding: _adminListPadding(context),
          itemCount: rsvps.length,
          separatorBuilder: (_, _) =>
              SizedBox(height: MediaQuery.sizeOf(context).width < 640 ? 8 : 12),
          itemBuilder: (context, index) {
            final rsvp = rsvps[index];
            return _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RecordHeader(
                    icon: Icons.payments_outlined,
                    title: rsvp.eventTitle.isEmpty
                        ? 'Payment record'
                        : rsvp.eventTitle,
                    subtitle:
                        '${rsvp.userName} - ${rsvp.paymentMethod.isEmpty ? 'payment method pending' : rsvp.paymentMethod}',
                    status: rsvp.paymentStatus.isEmpty
                        ? 'pending'
                        : rsvp.paymentStatus,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _runAdminAction(
                          context,
                          () => FirestoreService.instance
                              .updateRsvpPaymentStatus(rsvp.id, 'paid'),
                        ),
                        icon: const Icon(Icons.price_check_outlined),
                        label: const Text('Mark paid'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _runAdminAction(
                          context,
                          () =>
                              FirestoreService.instance.updateRsvpPaymentStatus(
                                rsvp.id,
                                'pending_at_venue',
                              ),
                        ),
                        icon: const Icon(Icons.hourglass_bottom_outlined),
                        label: const Text('Pending at venue'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _runAdminAction(
                          context,
                          () => FirestoreService.instance
                              .updateRsvpPaymentStatus(rsvp.id, 'failed'),
                        ),
                        icon: const Icon(Icons.report_gmailerrorred_outlined),
                        label: const Text('Mark failed'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ClubsSection extends StatelessWidget {
  const _ClubsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Club>>(
      stream: FirestoreService.instance.clubsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _CenterState(message: 'Loading venues');
        }
        if (snapshot.hasError) {
          return _CenterState(message: snapshot.error.toString());
        }
        final clubs = snapshot.data ?? [];
        if (clubs.isEmpty) {
          return const _CenterState(message: 'No venues found');
        }
        return ListView.separated(
          padding: _adminListPadding(context),
          itemCount: clubs.length,
          separatorBuilder: (_, _) =>
              SizedBox(height: MediaQuery.sizeOf(context).width < 640 ? 8 : 12),
          itemBuilder: (context, index) {
            final club = clubs[index];
            return _Panel(
              onTap: () => _showClubDetailDialog(context, club),
              child: _RecordHeader(
                icon: Icons.storefront_outlined,
                title: club.clubName,
                subtitle:
                    '${club.city} - ${club.businessEmail} - ${club.address}',
                status: club.verificationStatus,
                onStatusTap: _isReviewStatus(club.verificationStatus)
                    ? () => _showClubReviewDialog(context, club)
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}

class _EmergencyControlsSection extends StatelessWidget {
  const _EmergencyControlsSection({
    required this.currentUser,
    required this.maintenanceMode,
    required this.onMaintenanceChanged,
  });

  final AppUser currentUser;
  final bool maintenanceMode;
  final ValueChanged<bool> onMaintenanceChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _adminListPadding(context),
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.emergency_outlined,
                title: 'Emergency Controls',
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: maintenanceMode,
                onChanged: onMaintenanceChanged,
                activeThumbColor: _FireAdminColors.gold,
                activeTrackColor: _FireAdminColors.lava.withValues(alpha: 0.45),
                title: const Text(
                  'Maintenance mode',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text(
                  'Placeholder',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => FirestoreService.instance.seedDemoEvents(
                      currentUser.uid,
                    ),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Seed demo events'),
                  ),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.warning_amber_outlined),
                    label: const Text('Panic freeze'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.onTap, this.compact = false});

  final Widget child;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    final panel = Container(
      padding: EdgeInsets.all(compact ? (mobile ? 9 : 11) : (mobile ? 12 : 16)),
      decoration: BoxDecoration(
        color: _FireAdminColors.panel,
        borderRadius: BorderRadius.circular(mobile ? 12 : 16),
        border: Border.all(
          color: _FireAdminColors.lava.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: _FireAdminColors.red.withValues(alpha: 0.18),
            blurRadius: mobile ? 18 : 26,
            spreadRadius: -16,
            offset: Offset(0, mobile ? 10 : 16),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return panel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: panel,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.action});

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    return Row(
      children: [
        Icon(icon, color: _FireAdminColors.gold, size: mobile ? 18 : 22),
        SizedBox(width: mobile ? 8 : 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: mobile ? 15 : null,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        ?action,
      ],
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      avatar: const Icon(Icons.local_fire_department_outlined, size: 18),
      backgroundColor: _FireAdminColors.lava.withValues(alpha: 0.12),
      side: BorderSide(color: _FireAdminColors.lava.withValues(alpha: 0.32)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w800),
    );
  }
}

class _RecordHeader extends StatelessWidget {
  const _RecordHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    this.onStatusTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback? onStatusTap;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    final iconSize = mobile ? 34.0 : 42.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _FireAdminColors.lava.withValues(alpha: 0.12),
            border: Border.all(
              color: _FireAdminColors.lava.withValues(alpha: 0.42),
            ),
          ),
          child: Icon(
            icon,
            color: _FireAdminColors.gold,
            size: mobile ? 18 : 22,
          ),
        ),
        SizedBox(width: mobile ? 9 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: mobile ? 14 : 16,
                ),
              ),
              SizedBox(height: mobile ? 2 : 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: mobile ? 12 : 14,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: mobile ? 6 : 8),
        _StatusPill(label: status, onTap: onStatusTap),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 7 : 9,
        vertical: mobile ? 5 : 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: _FireAdminColors.red.withValues(alpha: 0.16),
        border: Border.all(color: _FireAdminColors.lava.withValues(alpha: 0.5)),
      ),
      child: Text(
        Formatters.titleCase(label),
        style: TextStyle(
          color: _FireAdminColors.gold,
          fontWeight: FontWeight.w900,
          fontSize: mobile ? 10 : 11,
        ),
      ),
    );

    if (onTap == null) return pill;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: pill,
      ),
    );
  }
}

class _CenterState extends StatelessWidget {
  const _CenterState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FireGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = _FireAdminColors.ember.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 54)
      ..strokeWidth = size.width * 0.24
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.95, size.height * 0.08),
      Offset(size.width * 0.1, size.height * 0.9),
      glow,
    );

    final gridPaint = Paint()
      ..color = _FireAdminColors.lava.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<void> _runAdminAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) _showActionError(context, error);
  }
}

void _showActionError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.toString())));
}

bool _isReviewStatus(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'pending' || normalized == 'pending_review';
}

EdgeInsets _adminListPadding(BuildContext context) {
  final mobile = MediaQuery.sizeOf(context).width < 640;
  return EdgeInsets.fromLTRB(
    mobile ? 12 : 16,
    0,
    mobile ? 12 : 16,
    mobile ? 88 : 24,
  );
}

Future<void> _showUserDetailDialog(BuildContext context, AppUser user) async {
  await _showRecordDetailDialog(
    context: context,
    title: user.name.isEmpty ? user.email : user.name,
    icon: Icons.person_outline,
    status: user.status,
    loadData: () => FirestoreService.instance.userRecordData(user.uid),
    primaryFields: [
      'name',
      'email',
      'phone',
      'role',
      'status',
      'verificationStatus',
      'city',
      'businessName',
      'venueName',
      'gstNumber',
      'ownerName',
      'businessPhone',
      'businessAddress',
      'address',
      'createdAt',
      'updatedAt',
      'onboardingCompleted',
      'isActive',
      'isApproved',
      'rejectionReason',
      'documentUrl',
      'validIdUrl',
    ],
    onApprove: _isReviewStatus(user.status)
        ? () => FirestoreService.instance.approveUser(user)
        : null,
    onReject: _isReviewStatus(user.status)
        ? (reason) => FirestoreService.instance.rejectUserReview(
            user,
            rejectionReason: reason,
          )
        : null,
    onToggleActive: user.isSuperAdmin
        ? null
        : () =>
              FirestoreService.instance.setUserActive(user.uid, !user.isActive),
    toggleActiveLabel: user.isActive ? 'Ban user' : 'Reinstate',
  );
}

Future<void> _showPromoterDetailDialog(
  BuildContext context,
  Promoter promoter,
) async {
  await _showRecordDetailDialog(
    context: context,
    title: promoter.name.isEmpty ? promoter.email : promoter.name,
    icon: Icons.campaign_outlined,
    status: promoter.isActive ? 'Active' : 'Banned',
    loadData: () => FirestoreService.instance.promoterRecordData(promoter.id),
    primaryFields: [
      'name',
      'email',
      'phone',
      'role',
      'status',
      'verificationStatus',
      'referralCode',
      'totalRsvps',
      'city',
      'createdAt',
      'updatedAt',
      'onboardingCompleted',
      'isActive',
      'isApproved',
      'rejectionReason',
      'documentUrl',
      'validIdUrl',
    ],
    onToggleActive: () => FirestoreService.instance.setPromoterActive(
      promoter,
      !promoter.isActive,
    ),
    toggleActiveLabel: promoter.isActive ? 'Ban promoter' : 'Reinstate',
  );
}

Future<void> _showClubDetailDialog(BuildContext context, Club club) async {
  await _showRecordDetailDialog(
    context: context,
    title: club.clubName.isEmpty ? club.ownerName : club.clubName,
    icon: Icons.storefront_outlined,
    status: club.verificationStatus,
    loadData: () => FirestoreService.instance.clubRecordData(club.id),
    primaryFields: [
      'clubName',
      'businessName',
      'venueName',
      'businessEmail',
      'phone',
      'role',
      'status',
      'verificationStatus',
      'city',
      'address',
      'businessAddress',
      'gstNumber',
      'ownerName',
      'ownerId',
      'instagram',
      'instagramLink',
      'googleMapsLink',
      'createdAt',
      'updatedAt',
      'onboardingCompleted',
      'isActive',
      'isApproved',
      'rejectionReason',
      'documentUrl',
      'documentUploadStatus',
    ],
    onApprove: _isReviewStatus(club.verificationStatus)
        ? () => FirestoreService.instance.approveClubReview(club)
        : null,
    onReject: _isReviewStatus(club.verificationStatus)
        ? (reason) => FirestoreService.instance.rejectClubReview(
            club,
            rejectionReason: reason,
          )
        : null,
  );
}

Future<void> _showUserReviewDialog(BuildContext context, AppUser user) async {
  await _showReviewDialog(
    context: context,
    title: user.name.isEmpty ? user.email : user.name,
    email: user.email,
    role: user.role,
    status: user.status,
    onApprove: () => FirestoreService.instance.approveUser(user),
    onReject: (reason) => FirestoreService.instance.rejectUserReview(
      user,
      rejectionReason: reason,
    ),
  );
}

Future<void> _showClubReviewDialog(BuildContext context, Club club) async {
  await _showReviewDialog(
    context: context,
    title: club.clubName.isEmpty ? club.ownerName : club.clubName,
    email: club.businessEmail,
    role: 'clubAdmin',
    status: club.verificationStatus,
    onApprove: () => FirestoreService.instance.approveClubReview(club),
    onReject: (reason) => FirestoreService.instance.rejectClubReview(
      club,
      rejectionReason: reason,
    ),
  );
}

Future<void> _showRecordDetailDialog({
  required BuildContext context,
  required String title,
  required IconData icon,
  required String status,
  required Future<Map<String, dynamic>> Function() loadData,
  required List<String> primaryFields,
  Future<void> Function()? onApprove,
  Future<void> Function(String? rejectionReason)? onReject,
  Future<void> Function()? onToggleActive,
  String? toggleActiveLabel,
}) async {
  final rootContext = context;
  final messenger = ScaffoldMessenger.of(rootContext);
  final rejectionReasonController = TextEditingController();
  final detailsFuture = loadData();
  var saving = false;

  await showDialog<void>(
    context: rootContext,
    barrierDismissible: !saving,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (builderContext, setDialogState) {
          Future<void> runDetailAction(
            Future<void> Function() action,
            String successMessage,
          ) async {
            if (saving) return;
            setDialogState(() => saving = true);
            try {
              await action();
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              messenger.showSnackBar(SnackBar(content: Text(successMessage)));
            } catch (error) {
              if (builderContext.mounted) {
                _showActionError(builderContext, error);
              }
              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
              }
            }
          }

          return AlertDialog(
            backgroundColor: _FireAdminColors.charcoal,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                Icon(icon, color: _FireAdminColors.gold),
                const SizedBox(width: 10),
                Expanded(child: Text(title.isEmpty ? 'Details' : title)),
              ],
            ),
            content: FutureBuilder<Map<String, dynamic>>(
              future: detailsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 420,
                    height: 120,
                    child: Center(
                      child: PremiumLoader(message: 'Loading details...'),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return SizedBox(
                    width: 420,
                    child: Text(snapshot.error.toString()),
                  );
                }

                final data = snapshot.data ?? const <String, dynamic>{};
                final rows = _detailRows(data, primaryFields);
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusPill(label: status),
                        const SizedBox(height: 14),
                        for (final row in rows)
                          _DetailInfoRow(label: row.$1, value: row.$2),
                        if (onReject != null) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: rejectionReasonController,
                            enabled: !saving,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Rejection reason (optional)',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
              if (onToggleActive != null && toggleActiveLabel != null)
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () => runDetailAction(
                          onToggleActive,
                          '$toggleActiveLabel updated successfully.',
                        ),
                  icon: const Icon(Icons.block_outlined),
                  label: Text(toggleActiveLabel),
                ),
              if (onReject != null)
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () => runDetailAction(
                          () => onReject(rejectionReasonController.text),
                          'Review rejected successfully.',
                        ),
                  icon: saving
                      ? const SizedBox.shrink()
                      : const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              if (onApprove != null)
                ElevatedButton.icon(
                  onPressed: saving
                      ? null
                      : () => runDetailAction(
                          onApprove,
                          'Review approved successfully.',
                        ),
                  icon: saving
                      ? const PremiumLoader.compact(size: 16)
                      : const Icon(Icons.check),
                  label: Text(saving ? 'Saving' : 'Approve'),
                ),
            ],
          );
        },
      );
    },
  );

  rejectionReasonController.dispose();
}

Future<void> _showReviewDialog({
  required BuildContext context,
  required String title,
  required String email,
  required String role,
  required String status,
  required Future<void> Function() onApprove,
  required Future<void> Function(String? rejectionReason) onReject,
}) async {
  final rootContext = context;
  final messenger = ScaffoldMessenger.of(rootContext);
  final rejectionReasonController = TextEditingController();
  var saving = false;

  await showDialog<void>(
    context: rootContext,
    barrierDismissible: !saving,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (builderContext, setDialogState) {
          Future<void> submitReview({required bool approved}) async {
            if (saving) return;
            setDialogState(() => saving = true);
            try {
              if (approved) {
                await onApprove();
              } else {
                await onReject(rejectionReasonController.text);
              }
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    approved
                        ? 'Review approved successfully.'
                        : 'Review rejected successfully.',
                  ),
                ),
              );
            } catch (error) {
              if (builderContext.mounted) {
                _showActionError(builderContext, error);
              }
              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
              }
            }
          }

          return AlertDialog(
            backgroundColor: _FireAdminColors.charcoal,
            surfaceTintColor: Colors.transparent,
            title: const Text('Review approval'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ReviewInfoRow(label: 'Name', value: title),
                  _ReviewInfoRow(label: 'Email', value: email),
                  _ReviewInfoRow(label: 'Role', value: role),
                  _ReviewInfoRow(label: 'Status', value: status),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rejectionReasonController,
                    enabled: !saving,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Rejection reason (optional)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              OutlinedButton.icon(
                onPressed: saving ? null : () => submitReview(approved: false),
                icon: saving
                    ? const SizedBox.shrink()
                    : const Icon(Icons.close),
                label: const Text('Reject'),
              ),
              ElevatedButton.icon(
                onPressed: saving ? null : () => submitReview(approved: true),
                icon: saving
                    ? const PremiumLoader.compact(size: 16)
                    : const Icon(Icons.check),
                label: Text(saving ? 'Saving' : 'Approve'),
              ),
            ],
          );
        },
      );
    },
  );

  rejectionReasonController.dispose();
}

class _ReviewInfoRow extends StatelessWidget {
  const _ReviewInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

List<(String, String)> _detailRows(
  Map<String, dynamic> data,
  List<String> primaryFields,
) {
  final fields = <String>[];
  for (final field in primaryFields) {
    if (!fields.contains(field)) fields.add(field);
  }

  final remainingFields =
      data.keys.where((field) => !fields.contains(field)).toList()..sort();
  fields.addAll(remainingFields);

  return fields
      .map((field) => (_detailLabel(field), _detailValue(data[field])))
      .toList();
}

String _detailLabel(String field) {
  final spaced = field
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll('_', ' ')
      .trim();
  if (spaced.isEmpty) return 'Field';
  return spaced[0].toUpperCase() + spaced.substring(1);
}

String _detailValue(Object? value) {
  if (value == null) return 'Not provided';
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'Not provided' : trimmed;
  }
  if (value is Timestamp) return Formatters.eventDate(value.toDate());
  if (value is DateTime) return Formatters.eventDate(value);
  if (value is bool) return value ? 'Yes' : 'No';
  if (value is Iterable) {
    final values = value.map(_detailValue).where((item) => item.isNotEmpty);
    return values.isEmpty ? 'Not provided' : values.join(', ');
  }
  if (value is Map) {
    if (value.isEmpty) return 'Not provided';
    return value.entries
        .map((entry) => '${entry.key}: ${_detailValue(entry.value)}')
        .join('\n');
  }
  return value.toString();
}

class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _FireAdminColors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _FireAdminColors.lava.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value.isEmpty ? 'Not provided' : value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteEvent(
  BuildContext context,
  NightlifeEvent event,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: _FireAdminColors.charcoal,
        surfaceTintColor: Colors.transparent,
        title: const Text('Delete event'),
        content: Text(event.title.isEmpty ? 'Delete this event?' : event.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return;
  await _runAdminAction(
    context,
    () => FirestoreService.instance.deleteEvent(event.id),
  );
}
