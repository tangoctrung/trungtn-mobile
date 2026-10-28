import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/lock_session_scope.dart';
import '../auth/lock_settings_sheet.dart';
import '../discover/discover_controller.dart';
import '../discover/discover_screen.dart';
import '../storage/storage_screen.dart';
import '../storage/vault_models.dart';
import '../storage/vault_repository.dart';
import 'home_dashboard.dart';
import '../../shared/compact_bottom_bar.dart';
import '../../shared/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onLock,
    this.repository,
    this.discover,
  });
  final VoidCallback onLock;
  final VaultRepository? repository;
  final DiscoverController? discover;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final VaultRepository _repository;
  late final DiscoverController _discover;
  final _storageKey = GlobalKey<StorageScreenState>();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? VaultRepository();
    _discover = widget.discover ?? DiscoverController();
    if (widget.repository == null) unawaited(_repository.load(seedDemo: true));
    if (widget.discover == null) unawaited(_discover.refresh());
  }

  @override
  void dispose() {
    if (widget.repository == null) _repository.dispose();
    if (widget.discover == null) _discover.dispose();
    super.dispose();
  }

  void _showFolder(VaultFolder folder) {
    setState(() => _index = 1);
    _storageKey.currentState?.openFolder(folder);
  }

  Future<void> _showLockOptions() async {
    final session = LockSessionScope.maybeOf(context);
    if (session == null) {
      widget.onLock();
    } else {
      await showLockSettings(context, session);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library, size: 28, color: AppTheme.accent),
          SizedBox(width: 7),
          Text(
            'TrungTN',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -.6,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            tooltip: 'Khóa ứng dụng',
            onPressed: _showLockOptions,
            icon: const Icon(Icons.lock_outline_rounded),
          ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: IndexedStack(
            index: _index,
            children: [
              HomeDashboard(
                repository: _repository,
                discover: _discover,
                onStorage: () => setState(() => _index = 1),
                onDiscover: () => setState(() => _index = 2),
                onFolder: _showFolder,
              ),
              StorageScreen(
                key: _storageKey,
                repository: _repository,
                isActive: _index == 1,
              ),
              DiscoverScreen(controller: _discover),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: CompactBottomBar(
      selectedIndex: _index,
      onSelected: (index) => setState(() => _index = index),
    ),
  );
}
