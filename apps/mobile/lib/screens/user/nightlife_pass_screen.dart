import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/user_app_chrome.dart';

class NightlifePassScreen extends StatelessWidget {
  const NightlifePassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: const UserBackAppBar(
        title: 'Nightlife Pass',
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 2),
            child: Icon(Icons.workspace_premium, color: AppTheme.accentPink),
          ),
        ],
      ),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          28 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const _PassHero(),
          const SizedBox(height: 16),
          const _BenefitsCard(),
          const SizedBox(height: 18),
          const _PricingHeader(),
          const SizedBox(height: 10),
          for (final plan in _plans) ...[
            _PremiumPlanCard(plan: plan),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          PremiumCTAButton(
            label: 'Unlock Nightlife Pass',
            icon: Icons.lock_open,
            onPressed: () => _showDemoMessage(
              context,
              title: 'Payment gateway coming soon',
              message: 'This is a demo premium screen.',
            ),
          ),
          const SizedBox(height: 10),
          PremiumCTAButton.secondary(
            label: 'Invite a Friend - Get 3 Days Free',
            icon: Icons.person_add_alt_1,
            onPressed: () => _showDemoMessage(
              context,
              title: 'Referral rewards coming soon',
              message: 'Invite rewards will be connected later.',
            ),
          ),
        ],
      ),
    );
  }

  static void _showDemoMessage(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.elevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppTheme.premiumGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PassHero extends StatelessWidget {
  const _PassHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentPink.withValues(alpha: 0.22),
            AppTheme.neonViolet.withValues(alpha: 0.12),
            AppTheme.surface.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(
              Icons.local_activity,
              color: AppTheme.accentPink,
              size: 27,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Unlock Premium Parties & Exclusive Deals',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.04,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Get faster entry, hidden parties, VIP access and exclusive guestlists.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Column(
        children: [
          BenefitRow(
            icon: Icons.payments_outlined,
            label: 'One-time demo payment only',
          ),
          BenefitRow(
            icon: Icons.visibility_off_outlined,
            label: 'Unlock hidden parties',
          ),
          BenefitRow(
            icon: Icons.auto_awesome,
            label: 'Discover premium events',
          ),
          BenefitRow(
            icon: Icons.savings_outlined,
            label: 'Save on selected event entries',
          ),
          BenefitRow(
            icon: Icons.verified_outlined,
            label: 'Priority guestlist access',
          ),
          BenefitRow(
            icon: Icons.flash_on_outlined,
            label: 'Faster venue check-ins',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class BenefitRow extends StatelessWidget {
  const BenefitRow({
    super.key,
    required this.icon,
    required this.label,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: AppTheme.accentPink.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: AppTheme.accentPink),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
        ],
      ),
    );
  }
}

class _PricingHeader extends StatelessWidget {
  const _PricingHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Text(
            'Available Plans',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          'Terms Apply',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PremiumPlanCard extends StatelessWidget {
  const _PremiumPlanCard({required this.plan});

  final _PassPlan plan;

  @override
  Widget build(BuildContext context) {
    final highlighted = plan.highlighted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.elevated.withValues(alpha: 0.98)
            : AppTheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted
              ? AppTheme.accentPink.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: highlighted ? 0.32 : 0.2),
            blurRadius: highlighted ? 22 : 14,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: highlighted ? AppTheme.premiumGradient : null,
              color: highlighted ? null : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              highlighted ? Icons.workspace_premium : Icons.confirmation_number,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (plan.badge != null) _PlanBadge(label: plan.badge!),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan.price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        plan.originalPrice,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  plan.discount,
                  style: TextStyle(
                    color: highlighted ? AppTheme.paidAccent : AppTheme.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
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

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        gradient: AppTheme.premiumGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class PremiumCTAButton extends StatefulWidget {
  const PremiumCTAButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  }) : secondary = false;

  const PremiumCTAButton.secondary({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  }) : secondary = true;

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool secondary;

  @override
  State<PremiumCTAButton> createState() => _PremiumCTAButtonState();
}

class _PremiumCTAButtonState extends State<PremiumCTAButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: widget.secondary ? null : AppTheme.premiumGradient,
            color: widget.secondary ? Colors.transparent : null,
            borderRadius: BorderRadius.circular(8),
            border: widget.secondary
                ? Border.all(color: AppTheme.accentPink.withValues(alpha: 0.55))
                : null,
            boxShadow: widget.secondary
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.accentPink.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.onPressed,
              child: SizedBox(
                height: 50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 19),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
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

class _PassPlan {
  const _PassPlan({
    required this.duration,
    required this.price,
    required this.originalPrice,
    required this.discount,
    this.badge,
    this.highlighted = false,
  });

  final String duration;
  final String price;
  final String originalPrice;
  final String discount;
  final String? badge;
  final bool highlighted;
}

const _plans = [
  _PassPlan(
    duration: '1 Year',
    price: '₹1999',
    originalPrice: '₹5999',
    discount: '66% OFF',
  ),
  _PassPlan(
    duration: '1 Month',
    price: '₹699',
    originalPrice: '₹999',
    discount: '30% OFF',
    badge: 'Recommended',
    highlighted: true,
  ),
  _PassPlan(
    duration: '3 Days',
    price: '₹249',
    originalPrice: '₹299',
    discount: '16% OFF',
  ),
];
