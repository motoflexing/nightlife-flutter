import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_user.dart';
import '../../models/club.dart';
import '../../models/event.dart';
import '../../models/promoter.dart';
import '../../models/rsvp.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

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

    return Scaffold(
      backgroundColor: _FireAdminColors.black,
      appBar: AppBar(
        title: Text(sections[_index].label),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: AuthService.instance.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
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
            Positioned.fill(child: CustomPaint(painter: _FireGridPainter())),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 860;
                  return Column(
                    children: [
                      _CommandHeader(currentUser: widget.currentUser),
                      Expanded(
                        child: wide
                            ? Row(
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
                              )
                            : Column(
                                children: [
                                  _SectionTabs(
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
  const _CommandHeader({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _FireAdminColors.panel,
          borderRadius: BorderRadius.circular(20),
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
              width: 54,
              height: 54,
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
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Super Admin',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentUser.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const _LiveBadge(),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_SuperAdminSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onSelected(index),
            avatar: Icon(
              sections[index].icon,
              size: 18,
              color: selected ? Colors.black : _FireAdminColors.gold,
            ),
            label: Text(sections[index].label),
            selectedColor: _FireAdminColors.lava,
            backgroundColor: _FireAdminColors.panel,
            labelStyle: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontWeight: FontWeight.w800,
            ),
            side: BorderSide(
              color: selected
                  ? _FireAdminColors.gold
                  : _FireAdminColors.lava.withValues(alpha: 0.36),
            ),
          );
        },
      ),
    );
  }
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
      width: 236,
      margin: const EdgeInsets.fromLTRB(16, 0, 12, 16),
      padding: const EdgeInsets.all(10),
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
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                  _SignalChip(label: 'Hidden route armed'),
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
        final columns = width >= 1000
            ? 4
            : width >= 680
            ? 3
            : width >= 420
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: columns,
          childAspectRatio: 1.55,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
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
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: _FireAdminColors.gold),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w800,
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: events.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final user = users[index];
            return _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RecordHeader(
                    icon: Icons.person_outline,
                    title: user.name.isEmpty ? user.email : user.name,
                    subtitle: '${user.email} - ${user.role}',
                    status: user.status,
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: promoters.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final promoter = promoters[index];
            return _Panel(
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: clubs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final club = clubs[index];
            return _Panel(
              child: _RecordHeader(
                icon: Icons.storefront_outlined,
                title: club.clubName,
                subtitle:
                    '${club.city} - ${club.businessEmail} - ${club.address}',
                status: club.verificationStatus,
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _FireAdminColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _FireAdminColors.lava.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: _FireAdminColors.red.withValues(alpha: 0.18),
            blurRadius: 28,
            spreadRadius: -16,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
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
    return Row(
      children: [
        Icon(icon, color: _FireAdminColors.gold),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _FireAdminColors.lava.withValues(alpha: 0.12),
            border: Border.all(
              color: _FireAdminColors.lava.withValues(alpha: 0.42),
            ),
          ),
          child: Icon(icon, color: _FireAdminColors.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusPill(label: status),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: _FireAdminColors.red.withValues(alpha: 0.16),
        border: Border.all(color: _FireAdminColors.lava.withValues(alpha: 0.5)),
      ),
      child: Text(
        Formatters.titleCase(label),
        style: const TextStyle(
          color: _FireAdminColors.gold,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
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
