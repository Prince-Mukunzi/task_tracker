import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/animations/animation_helpers.dart';
import '../../core/components/pressable_scale.dart';
import '../../core/components/settings_row.dart';
import '../../core/components/toggle_row.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/task.dart';
import '../../models/team_member.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_member_provider.dart';
import '../auth/auth_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
late AnimationController _entranceCtrl;

bool _pushNotifications = true;
bool _deadlineAlerts = true;
bool _mentionAlerts = true;
String _defaultView = 'Dashboard';

// SLA thresholds (hours)
double _atRiskThreshold = 24;
String _slaUnit = 'Hours';

@override
void initState() {
super.initState();
_entranceCtrl = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 900),
);
WidgetsBinding.instance.addPostFrameCallback((_) {
_entranceCtrl.forward();
});
}

@override
void dispose() {
_entranceCtrl.dispose();
super.dispose();
}
