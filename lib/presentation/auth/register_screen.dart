import 'package:pos/core/utils/notification_helper.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/license_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/security_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../services/master_password_service.dart';

// ─── Brand Colors ────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF1B5E20);
const _kGreenMid = Color(0xFF2E7D32);
const _kGreenLight = Color(0xFF43A047);
const _kWhite = Colors.white;

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animController;
  final _securityService = SecurityService();
  String _deviceId = 'Loading...';

  // Key Generation State
  bool _keyGenerated = false;
  String _generatedKey = '';
  int _keyGenCount = 0;
  String _keyGenDate = '';
  static const int _maxKeysPerDay = 3;

  // Registration Form
  final _adminFormKey = GlobalKey<FormState>();
  final _shopNameCtrl = TextEditingController();
  final _adminUsernameCtrl = TextEditingController(text: 'admin');
  final _adminPasswordCtrl = TextEditingController();
  final _activationKeyCtrl = TextEditingController();
  final _adminMobileCtrl = TextEditingController();
  bool _obscureAdminPassword = true;

  // Staff Login Form
  final _staffFormKey = GlobalKey<FormState>();
  final _shopCodeCtrl = TextEditingController();
  final _staffUsernameCtrl = TextEditingController();
  final _staffPasswordCtrl = TextEditingController();
  bool _obscureStaffPassword = true;

  // Customer Support Tap Setup
  int _tapCount = 0;
  DateTime? _firstTapTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _animController.forward();
    _loadDeviceId();
    _loadKeyGenState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLogoutMessage();
    });
  }

  void _checkLogoutMessage() {
    final box = Hive.box<String>('settings');
    final msg = box.get('logoutMessage');
    if (msg != null && msg.isNotEmpty) {
      box.delete('logoutMessage'); // Only show once
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'Access Revoked',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: Text(msg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _loadKeyGenState() {
    try {
      final box = Hive.box<String>('settings');
      final storedDate = box.get('keyGenDate', defaultValue: '')!;
      final storedCount =
          int.tryParse(box.get('keyGenCount', defaultValue: '0')!) ?? 0;
      final today = _todayString();
      if (mounted)
        setState(() {
          _keyGenDate = storedDate;
          _keyGenCount = (storedDate == today) ? storedCount : 0;
        });
    } catch (_) {}
  }

  Future<void> _saveKeyGenState() async {
    try {
      final box = Hive.box<String>('settings');
      await box.put('keyGenDate', _keyGenDate);
      await box.put('keyGenCount', _keyGenCount.toString());
    } catch (_) {}
  }

  String _todayString() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadDeviceId() async {
    final id = await _securityService.getDeviceId();
    if (mounted) setState(() => _deviceId = id.toUpperCase());
  }

  @override
  void dispose() {
    _animController.dispose();
    _tabController.dispose();
    _shopNameCtrl.dispose();
    _adminUsernameCtrl.dispose();
    _adminPasswordCtrl.dispose();
    _activationKeyCtrl.dispose();
    _adminMobileCtrl.dispose();
    _shopCodeCtrl.dispose();
    _staffUsernameCtrl.dispose();
    _staffPasswordCtrl.dispose();
    super.dispose();
  }

  void _copyDeviceId() {
    Clipboard.setData(ClipboardData(text: _deviceId));
    NotificationHelper.showCenter(
      context,
      'Device ID copied! 📋',
      isError: false,
    );
  }

  void _onLogoTap() {
    final now = DateTime.now();

    if (_firstTapTime == null ||
        now.difference(_firstTapTime!).inSeconds > 30) {
      _firstTapTime = now;
      _tapCount = 1;
    } else {
      _tapCount++;
    }

    if (_tapCount >= 24) {
      _tapCount = 0;
      _firstTapTime = null;
      _activateHostDevice();
    }
  }

  void _activateHostDevice() {
    final masterService = MasterPasswordService();
    if (masterService.isHostDevice()) {
      NotificationHelper.showCenter(
        context,
        '✅ Customer Support Access Revealed! Redirecting...',
        isError: false,
      );
      // Redirection is handled by main.dart automatically when box changes
      return;
    }

    // Automatic master password flow with default
    Future(() async {
      // First verify globally with Firebase
      final deviceId = await SecurityService().getDeviceId();
      final error = await FirebaseSyncService().claimMasterAdminDevice(
        deviceId,
      );

      if (error != null) {
        if (mounted) {
          NotificationHelper.showCenter(context, error, isError: true);
        }
        return; // Reject activation
      }

      await masterService.setMasterPassword('DTS@SILAM&_20!!26##P*O*S');
      await masterService.activateHostDevice();
      Hive.box<String>(
        'settings',
      ).put('hostAdminRegistrationDate', DateTime.now().toIso8601String());
      if (mounted) {
        NotificationHelper.showCenter(
          context,
          '✅ Host Device Activated globally! Redirecting...',
          isError: false,
        );
      }
    });
  }

  void _onGenerateKeyTapped() async {
    final mobile = _adminMobileCtrl.text.trim();
    if (mobile.isEmpty) {
      NotificationHelper.showCenter(
        context,
        'Please enter your Mobile Number first!',
        isError: true,
      );
      return;
    }

    final today = _todayString();
    final currentCount = (_keyGenDate == today) ? _keyGenCount : 0;
    if (currentCount >= _maxKeysPerDay) {
      _showDialog(
        icon: Icons.block,
        iconColor: Colors.red,
        title: 'Daily Limit Reached',
        message:
            'You have already generated 3 activation keys today.\n\nTry again tomorrow or contact admin on WhatsApp: ${FirebaseSyncService().getSupportPhoneNumber()}.',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: _kGreenLight)),
    );

    // 1. Generate unique shop code
    final shopCode = await FirebaseSyncService().generateUniqueShopCode();

    // 2. Lock the mobile number in the global registry
    final mobileError = await FirebaseSyncService().registerMobileForActivation(
      mobile,
      _deviceId,
      shopCode,
    );

    if (mobileError != null) {
      if (mounted) Navigator.pop(context);
      NotificationHelper.showCenter(context, mobileError, isError: true);
      return;
    }

    // 3. Save shop code locally so it is used during actual registration
    Hive.box<String>('settings').put('shopCode', shopCode);

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    Navigator.pop(context);

    final nonce = (Random().nextInt(8999) + 1000).toString();
    final generatedKey = _securityService.generateActivationKey(
      _deviceId,
      nonce,
    );

    setState(() {
      _keyGenDate = today;
      _keyGenCount = currentCount + 1;
      _generatedKey = generatedKey;
      _keyGenerated = true;
    });
    await _saveKeyGenState();

    try {
      final senderEmail = FirebaseSyncService().getSenderEmail();
      final senderPwd = FirebaseSyncService().getSenderAppPassword();
      final smtpServer = gmail(senderEmail, senderPwd);
      final emailMessage = Message()
        ..from = Address(senderEmail, 'DTS POS Alerts')
        ..recipients.add(senderEmail)
        ..subject = '🔔 New Activation Request — $mobile'
        ..text =
            'NEW STORE ACTIVATION REQUEST\n\n'
            'Shop Code:  $shopCode\n'
            'Mobile:     $mobile\n'
            'Device ID:  $_deviceId\n'
            'Secret Key: $generatedKey\n'
            'Attempt:    ${currentCount + 1}/3\n\n'
            'Share the Secret Key with the customer to activate their store.';
      await send(emailMessage, smtpServer);
    } catch (e) {
      debugPrint('Email error: $e');
    }

    if (mounted) {
      final remaining = _maxKeysPerDay - _keyGenCount;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF25D366)),
              SizedBox(width: 8),
              Text(
                'Request Sent!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Your activation request has been submitted!\n\nContact admin on WhatsApp (${FirebaseSyncService().getSupportPhoneNumber()}) to get your key.\nAttempts remaining today: $remaining / $_maxKeysPerDay',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final msg =
                    'Hi, I would like to activate my DTS POS store.\nMy registered mobile: $mobile';
                final cleanPhone = FirebaseSyncService()
                    .getSupportPhoneNumber()
                    .replaceAll(RegExp(r'\D'), '');
                final url = Uri.parse(
                  'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}',
                );
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
              child: const Text(
                'Send via WhatsApp',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _onRegenerateTapped() {
    final today = _todayString();
    final currentCount = (_keyGenDate == today) ? _keyGenCount : 0;
    if (currentCount >= _maxKeysPerDay) {
      NotificationHelper.showCenter(
        context,
        'Daily limit of 3 reached. Try again tomorrow.',
        isError: true,
      );
      return;
    }
    setState(() {
      _keyGenerated = false;
      _generatedKey = '';
    });
  }

  void _submitAdminRegister() async {
    if (_adminFormKey.currentState!.validate()) {
      final shopName = _shopNameCtrl.text.trim();
      final username = _adminUsernameCtrl.text.trim();
      final password = _adminPasswordCtrl.text;
      final enteredKey = _activationKeyCtrl.text.trim();

      if (enteredKey.isNotEmpty) {
        final isValid = _securityService.verifyActivationKey(
          _deviceId,
          enteredKey,
        );
        if (!isValid) {
          NotificationHelper.showCenter(
            context,
            'Invalid Activation Key!',
            isError: true,
          );
          return;
        }
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: CircularProgressIndicator(color: _kGreenLight)),
      );

      try {
        ref
            .read(authProvider.notifier)
            .setupAdminCredentials(username, password);
        ref.read(settingsProvider.notifier).updateSettings(shopName: shopName);

        await ref
            .read(licenseProvider.notifier)
            .registerStore(shopName, enteredKey)
            .timeout(const Duration(seconds: 3), onTimeout: () {});
        
        // Push initial data to cloud asynchronously so it doesn't block the UI
        FirebaseSyncService().pushSync();

        if (mounted) {
          Navigator.pop(context);
          NotificationHelper.showCenter(
            context,
            'Shop registered and activated successfully! 🎉',
            isError: false,
          );
        }

        ref.read(authProvider.notifier).login(username, password);
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          NotificationHelper.showCenter(context, 'Error: $e', isError: true);
        }
      }
    }
  }

  void _submitStaffLogin() async {
    if (_staffFormKey.currentState!.validate()) {
      final shopCode = _shopCodeCtrl.text.trim();
      final username = _staffUsernameCtrl.text.trim();
      final password = _staffPasswordCtrl.text;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: CircularProgressIndicator(color: _kGreenLight)),
      );

      try {
        bool success = false;
        String? adminError;

        if (username.toLowerCase() == 'admin') {
          adminError = await FirebaseSyncService().verifyAdminCloudLogin(
            shopCode,
            password,
            _deviceId,
          );
          success = adminError == null;
        } else {
          success = await FirebaseSyncService().verifyStaffLogin(
            shopCode,
            username,
            password,
            _deviceId,
          );
        }

        if (mounted) Navigator.pop(context);

        if (success) {
          final settingsBox = Hive.box<String>('settings');
          final shopName = settingsBox.get('shopName') ?? 'DTS POS';
          await ref
              .read(licenseProvider.notifier)
              .connectStaffStore(
                shopCode,
                shopName,
                isAdmin: username.toLowerCase() == 'admin',
              );

          if (username.toLowerCase() == 'admin') {
            ref
                .read(authProvider.notifier)
                .setupAdminCredentials(username, password);
          }

          final loginOk = ref
              .read(authProvider.notifier)
              .login(username, password);
          if (mounted) {
            NotificationHelper.showCenter(
              context,
              loginOk
                  ? 'Welcome! Connected successfully.'
                  : 'Auth check failed.',
              isError: true,
            );
          }
        } else {
          if (mounted) {
            String errorMsg = adminError ?? 'Invalid credentials or Shop Code!';
            if (adminError == 'max_devices_reached') {
              errorMsg =
                  'Admin device limit reached (Max 3). Alert sent to owner.';
            }
            NotificationHelper.showCenter(context, errorMsg, isError: true);
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          NotificationHelper.showCenter(context, 'Error: $e', isError: true);
        }
      }
    }
  }

  void _showDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedWidget(Widget child, int index) {
    final start = (index * 0.1).clamp(0.0, 1.0);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _animController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kWhite,
      body: Column(
        children: [
          // ── Green Hero Header ──────────────────────────────────────────
          _buildAnimatedWidget(_GreenHeader(onLogoTap: _onLogoTap), 0),

          // ── White scrollable body ──────────────────────────────────────
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        // Tab bar
                        _buildAnimatedWidget(_buildTabBar(), 1),
                        const SizedBox(height: 4),
                        // Tab content via IndexedStack so both forms keep state
                        _buildAnimatedWidget(
                          _tabController.index == 0
                              ? _buildStaffPortalTab()
                              : _buildAdminSetupTab(),
                          2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (_, __) => Row(
        children: [
          _TabPill(
            label: 'Connect Shop',
            icon: Icons.link_rounded,
            selected: _tabController.index == 0,
            onTap: () => setState(() => _tabController.index = 0),
          ),
          const SizedBox(width: 10),
          _TabPill(
            label: 'Register Shop',
            icon: Icons.add_business_rounded,
            selected: _tabController.index == 1,
            onTap: () => setState(() => _tabController.index = 1),
          ),
        ],
      ),
    );
  }

  // ── CONNECT / STAFF TAB ──────────────────────────────────────────────────
  Widget _buildStaffPortalTab() {
    return Form(
      key: _staffFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Connect to Existing Shop',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: _kGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your Shop Code and credentials to sync with your store.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
          ),
          const SizedBox(height: 22),

          _buildField(
            controller: _shopCodeCtrl,
            label: 'Shop Code (e.g. DTS-10492)',
            icon: Icons.qr_code_rounded,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter shop code' : null,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _staffUsernameCtrl,
            label: 'Username',
            icon: Icons.person_outline_rounded,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter username' : null,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _staffPasswordCtrl,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscureStaffPassword,
            onToggleObscure: () =>
                setState(() => _obscureStaffPassword = !_obscureStaffPassword),
            validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
          ),
          const SizedBox(height: 28),

          _buildGreenButton(
            label: 'CONNECT & SYNC DATABASE',
            onPressed: _submitStaffLogin,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── REGISTER / ADMIN TAB ─────────────────────────────────────────────────
  Widget _buildAdminSetupTab() {
    return Form(
      key: _adminFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Register New Shop',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: _kGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Set up your store for the first time and activate your licence.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
          ),
          const SizedBox(height: 20),

          // ── Activation Key Generator Panel ──────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kGreenLight.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _kGreenLight.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.vpn_key_rounded,
                        color: _kGreenMid,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'GENERATE ACTIVATION KEY',
                      style: TextStyle(
                        color: _kGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _buildField(
                  controller: _adminMobileCtrl,
                  label: 'Mobile Number',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  readOnly: _keyGenerated,
                  validator: (_) => null,
                ),
                const SizedBox(height: 12),

                if (_keyGenerated) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.green.shade700,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Request submitted!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Contact admin on WhatsApp (${FirebaseSyncService().getSupportPhoneNumber()}) to receive your key.\n${_maxKeysPerDay - _keyGenCount} attempt(s) remaining today',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kGreenMid,
                      side: BorderSide(color: _kGreenLight.withOpacity(0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      _keyGenCount >= _maxKeysPerDay
                          ? 'Daily limit reached (3/3)'
                          : 'Regenerate Key ($_keyGenCount/$_maxKeysPerDay used today)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _keyGenCount >= _maxKeysPerDay
                        ? null
                        : _onRegenerateTapped,
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.vpn_key_rounded, size: 16),
                      label: Text(
                        _keyGenCount > 0
                            ? 'Generate Key ($_keyGenCount/$_maxKeysPerDay)'
                            : 'Generate Activation Key',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _onGenerateKeyTapped,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          _buildField(
            controller: _activationKeyCtrl,
            label: 'Activation Key (Optional)',
            icon: Icons.admin_panel_settings_rounded,
            hint: 'Paste your activation key here',
            readOnly: !_keyGenerated,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _shopNameCtrl,
            label: 'Shop / Restaurant Name',
            icon: Icons.store_rounded,
            readOnly: !_keyGenerated,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Shop name is required' : null,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _adminUsernameCtrl,
            label: 'Admin Username',
            icon: Icons.manage_accounts_rounded,
            readOnly: !_keyGenerated,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Username required' : null,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _adminPasswordCtrl,
            label: 'Admin Password',
            icon: Icons.lock_rounded,
            obscure: _obscureAdminPassword,
            readOnly: !_keyGenerated,
            onToggleObscure: () =>
                setState(() => _obscureAdminPassword = !_obscureAdminPassword),
            validator: (v) =>
                v == null || v.length < 4 ? 'Minimum 4 characters' : null,
          ),
          const SizedBox(height: 10),

          // Device ID chip
          GestureDetector(
            onTap: _copyDeviceId,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.device_hub_rounded,
                    color: Colors.grey.shade500,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Device ID: $_deviceId',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.copy_rounded,
                    color: Colors.grey.shade400,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          _buildGreenButton(
            label: 'REGISTER & ACTIVATE STORE',
            onPressed: _keyGenerated ? _submitAdminRegister : () {},
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Shared input field ───────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = false,
    bool readOnly = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        prefixIcon: Icon(icon, color: _kGreenMid, size: 20),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : readOnly
            ? Icon(Icons.lock_rounded, color: Colors.grey.shade300, size: 18)
            : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kGreenLight, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        isDense: true,
      ),
    );
  }

  // ── Green CTA button ─────────────────────────────────────────────────────
  Widget _buildGreenButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
        shadowColor: _kGreen.withOpacity(0.4),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Tab Pill Widget ──────────────────────────────────────────────────────────
class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _kGreen : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _kGreen.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Green Hero Header with wave clip ────────────────────────────────────────
class _GreenHeader extends StatelessWidget {
  final VoidCallback? onLogoTap;

  const _GreenHeader({this.onLogoTap});

  @override
  Widget build(BuildContext context) {
    final isShortScreen = MediaQuery.of(context).size.height < 450;
    if (isShortScreen) return const SizedBox.shrink();

    return ClipPath(
      clipper: _WaveClipper(),
      child: Container(
        height: 210,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kGreen, _kGreenMid, _kGreenLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // DTS Logo block
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // DTS Logo
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'DTS',
                              style: TextStyle(
                                color: _kGreen,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              'POS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Point of Sale',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your sales easily\nand efficiently',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // POS machine illustration (text-art icon cluster)
                GestureDetector(
                  onTap: onLogoTap, // SECRET TAP TARGET
                  child: _PosMachineIllustration(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Cute POS illustration made from icons ────────────────────────────────────
class _PosMachineIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.point_of_sale_rounded,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'DTS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wave Clip ────────────────────────────────────────────────────────────────
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height - 20,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 40,
      size.width,
      size.height - 10,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper oldClipper) => false;
}
