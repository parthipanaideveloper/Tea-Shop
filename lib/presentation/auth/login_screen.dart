import 'package:pos/core/utils/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/master_password_service.dart';
import '../../services/security_service.dart';
import '../../services/firebase_sync_service.dart';
import '../master_admin/master_admin_screen.dart';

const Color _kGreen = Color(0xFF1E5631);
const Color _kGreenMid = Color(0xFF2E7D32);
const Color _kGreenLight = Color(0xFF4CAF50);
const Color _kWhite = Colors.white;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _biometricsAvailable = false;
  bool _biometricsLoading = false;
  final LocalAuthentication _auth = LocalAuthentication();

  // Secret tap state
  int _tapCount = 0;
  DateTime? _firstTapTime;

  // Cloud / host login mode
  bool _showCloudLogin = false;
  final _shopCodeCtrl = TextEditingController();
  final _cloudPasswordCtrl = TextEditingController();
  bool _obscureCloudPassword = true;
  bool _cloudLoading = false;
  String? _cloudError;

  // Franchise login mode
  bool _showFranchiseLogin = false;
  final _franchisePhoneCtrl = TextEditingController();
  final _franchisePasswordCtrl = TextEditingController();
  bool _obscureFranchisePassword = true;
  bool _franchiseLoading = false;
  String? _franchiseError;

  // Host device state
  bool _isHostDevice = false;
  bool _showHostLogin = false;
  final _hostShopCodeCtrl = TextEditingController();
  final _masterPasswordCtrl = TextEditingController();
  bool _obscureMasterPassword = true;
  bool _hostLoading = false;
  String? _hostError;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _isHostDevice = MasterPasswordService().isHostDevice();
    
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
          title: const Text('Access Revoked', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text(msg),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
          ]));
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _shopCodeCtrl.dispose();
    _cloudPasswordCtrl.dispose();
    _franchisePhoneCtrl.dispose();
    _franchisePasswordCtrl.dispose();
    _hostShopCodeCtrl.dispose();
    _masterPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    try {
      final notifier = ref.read(authProvider.notifier);
      if (notifier.lastKnownUsername == null) return;
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (mounted) {
        setState(() {
          _biometricsAvailable = canCheck && isDeviceSupported;
        });
      }
      if (_biometricsAvailable) _authenticateWithBiometrics();
    } catch (_) {}
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() {
      _biometricsLoading = true;
      _errorMessage = null;
    });
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Verify your identity to log in',
        biometricOnly: false,
        persistAcrossBackgrounding: true);
      if (authenticated && mounted) {
        final success = ref.read(authProvider.notifier).loginWithBiometrics();
        if (!success) {
          setState(() {
            _errorMessage = 'Biometric login failed. Please use your password.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Biometric not available. Use your password.';
        });
      }
    } finally {
      if (mounted) setState(() => _biometricsLoading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (_formKey.currentState!.validate()) {
      final username = _usernameCtrl.text.trim();
      final password = _passwordCtrl.text;
      
      // Check for Magic Username (Franchise Owner)
      // A typical phone number is 10 digits
      final isNumeric = RegExp(r'^[0-9]{10}$').hasMatch(username);
      
      if (isNumeric) {
        setState(() => _cloudLoading = true); // use cloud loading indicator
        final error = await ref.read(authProvider.notifier).franchiseLogin(username, password);
        if (mounted) setState(() => _cloudLoading = false);
        
        if (error == null) {
          // Success! authProvider handled the role change
          return;
        }
        // If it failed to find a franchise owner or incorrect password,
        // it falls through to check the local staff login just in case
      }

      // Standard Local Login
      var success = ref.read(authProvider.notifier).login(username, password);
      if (!success) {
        // Try to pull latest staff accounts from cloud in case of newly created accounts
        final settingsBox = Hive.box<String>('settings');
        final shopCode = settingsBox.get('shopCode') ?? '';
        if (shopCode.isNotEmpty) {
          setState(() => _cloudLoading = true);
          try {
            await FirebaseSyncService().pullSync(shopCode);
            // Try login again with updated staff list
            success = ref.read(authProvider.notifier).login(username, password);
          } catch (e) {
            debugPrint("Failed to pull staff list during login: $e");
          }
          if (mounted) setState(() => _cloudLoading = false);
        }
      }

      if (!success) {
        setState(() => _errorMessage = 'Invalid username or password');
      }
    }
  }

  // --- SECRET TAP LOGIC ---
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
      _showHostActivationSheet();
    }
  }

  void _showHostActivationSheet() {
    final masterService = MasterPasswordService();
    if (masterService.isHostDevice()) {
      setState(() {
        _isHostDevice = true;
        _showHostLogin = true; // Auto-expand it!
      });
      NotificationHelper.showCenter(context, '✅ Customer Support Access Revealed! Scroll down to log in.', isError: false);
      return;
    }

    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Host Admin Activation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Enter Master Security Key',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final input = passCtrl.text.trim();
              if (masterService.verifyMasterPassword(input)) {
                final deviceId = await SecurityService().getDeviceId();
                final error = await FirebaseSyncService().claimMasterAdminDevice(deviceId);
                if (error != null && ctx.mounted) {
                  NotificationHelper.showCenter(ctx, error, isError: true);
                  return;
                }
                await masterService.activateHostDevice();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  setState(() {
                    _isHostDevice = true;
                    _showHostLogin = true;
                  });
                  NotificationHelper.showCenter(context, '🌟 Device Registered as Host Admin!', isError: false);
                }
              } else {
                if (ctx.mounted) {
                  NotificationHelper.showCenter(ctx, 'Invalid Master Security Key!', isError: true);
                }
              }
            },
            child: const Text('Activate'),
          ),
        ],
      ),
    );
  }

  // --- CLOUD ADMIN LOGIN ---
  Future<void> _submitCloudLogin() async {
    setState(() {
      _cloudLoading = true;
      _cloudError = null;
    });
    final error = await ref
        .read(authProvider.notifier)
        .cloudAdminLogin(_shopCodeCtrl.text.trim(), _cloudPasswordCtrl.text);
    if (mounted) {
      setState(() {
        _cloudLoading = false;
        if (error == 'max_devices_reached') {
          _cloudError =
              'Maximum of 3 Admin devices reached for this shop. The primary device has been alerted. Please contact support.';
        } else {
          _cloudError = error;
        }
      });
    }
  }

  // --- HOST LOGIN ---
  Future<void> _submitHostLogin() async {
    final shopCode = _hostShopCodeCtrl.text.trim();
    final masterPassword = _masterPasswordCtrl.text;

    setState(() {
      _hostLoading = true;
      _hostError = null;
    });

    final error = await ref
        .read(authProvider.notifier)
        .hostLogin(shopCode, masterPassword);
        
    if (mounted) {
      setState(() {
        _hostLoading = false;
        _hostError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final lastUser = ref.read(authProvider.notifier).lastKnownUsername;

    return Scaffold(
      backgroundColor: _kWhite,
      body: Column(
        children: [
          // ── Green Hero Header ──────────────────────────────────────────
          _GreenHeader(onLogoTap: _onLogoTap),

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
                      const SizedBox(height: 16),
                      Text(
                        settings.shopName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: _kGreen)),
                      const SizedBox(height: 4),
                      Text(
                        'Terminal Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13)),
                      const SizedBox(height: 32),

                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Biometric banner
                            if (_biometricsAvailable && lastUser != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12),
                                decoration: BoxDecoration(
                                  color: _kGreenLight.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _kGreenLight.withValues(alpha: 0.3))),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.fingerprint,
                                      color: _kGreen,
                                      size: 32),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Welcome back, $lastUser',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _kGreen,
                                              fontSize: 14)),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Tap to login with fingerprint',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 12)),
                                        ])),
                                    _biometricsLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: _kGreen))
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.arrow_forward_ios,
                                              color: _kGreen,
                                              size: 18),
                                            onPressed:
                                                _authenticateWithBiometrics),
                                  ])),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: Colors.grey.shade300)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                    child: Text(
                                      'or use password',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12))),
                                  Expanded(
                                    child: Divider(color: Colors.grey.shade300)),
                                ]),
                              const SizedBox(height: 20),
                            ],

                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200)),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade700,
                                      size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade800,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                                  ])),
                              const SizedBox(height: 16),
                            ],

                            _buildField(
                              controller: _usernameCtrl,
                              label: 'Username',
                              icon: Icons.person_outline_rounded,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Please enter username'
                                  : null),
                            const SizedBox(height: 16),
                            _buildField(
                              controller: _passwordCtrl,
                              label: 'Password',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscurePassword,
                              onToggleObscure: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Please enter password'
                                  : null,
                              onFieldSubmitted: (_) => _submit()),
                            const SizedBox(height: 32),

                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                                backgroundColor: _kGreen,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shadowColor: _kGreen.withOpacity(0.5)),
                              onPressed: _submit,
                              child: const Text(
                                'LOG IN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 1.2))),

                            if (_biometricsAvailable && lastUser == null) ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _biometricsLoading
                                    ? null
                                    : _authenticateWithBiometrics,
                                icon: const Icon(
                                  Icons.fingerprint,
                                  color: _kGreen),
                                label: const Text(
                                  'Use Fingerprint',
                                  style: TextStyle(color: _kGreen)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                  side: const BorderSide(color: _kGreenLight),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)))),
                            ],
                          ])),


                      // --- HOST DEVICE LOGIN CARD ---
                      if (_isHostDevice) ...[
                        const SizedBox(height: 32),
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Colors.deepPurple.shade300,
                              width: 1.5)),
                          color: const Color(0xFFF5F0FF),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.admin_panel_settings,
                                      color: Colors.deepPurple),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'HOST ADMIN ACCESS',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple,
                                        letterSpacing: 1)),
                                    const Spacer(),
                                    IconButton(
                                      icon: Icon(
                                        _showHostLogin
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: Colors.deepPurple),
                                      onPressed: () => setState(
                                        () => _showHostLogin = !_showHostLogin)),
                                  ]),
                                if (_showHostLogin) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Enter your Master Password to open the Global Dashboard, or add a Shop Code to impersonate a client directly.',
                                    style: TextStyle(
                                      color: Colors.deepPurple.shade700,
                                      fontSize: 12)),
                                  const SizedBox(height: 16),
                                  if (_hostError != null)
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.shade200)),
                                      child: Text(
                                        _hostError!,
                                        style: TextStyle(
                                          color: Colors.red.shade800,
                                          fontSize: 12))),
                                  TextField(
                                    controller: _hostShopCodeCtrl,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    decoration: const InputDecoration(
                                      labelText: 'Client Shop Code (Optional)',
                                      prefixIcon: Icon(
                                        Icons.store,
                                        color: Colors.deepPurple),
                                      border: OutlineInputBorder(),
                                      isDense: true)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _masterPasswordCtrl,
                                    obscureText: _obscureMasterPassword,
                                    decoration: InputDecoration(
                                      labelText: 'Master Password',
                                      prefixIcon: const Icon(
                                        Icons.vpn_key,
                                        color: Colors.deepPurple),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureMasterPassword
                                              ? Icons.visibility_off
                                              : Icons.visibility),
                                        onPressed: () => setState(
                                          () => _obscureMasterPassword =
                                              !_obscureMasterPassword)),
                                      border: const OutlineInputBorder(),
                                      isDense: true)),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.login),
                                    label: _hostLoading
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                        : const Text(
                                            'Enter Shop',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10))),
                                    onPressed: _hostLoading
                                        ? null
                                        : _submitHostLogin),
                                ],
                              ]))),
                      ],

                      const SizedBox(height: 40),
                    ])))))),
        ]));
  }
}

// ── Shared input field ───────────────────────────────────────────────────
Widget _buildField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  bool obscure = false,
  VoidCallback? onToggleObscure,
  void Function(String)? onFieldSubmitted,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    obscureText: obscure,
    style: const TextStyle(fontSize: 14, color: Colors.black87),
    validator: validator,
    onFieldSubmitted: onFieldSubmitted,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      prefixIcon: Icon(icon, color: _kGreenMid, size: 20),
      suffixIcon: onToggleObscure != null
          ? IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: Colors.grey.shade400,
                size: 20),
              onPressed: onToggleObscure)
          : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kGreenLight, width: 1.8)),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      isDense: true));
}

// ── Green Hero Header with wave clip ────────────────────────────────────────
class _GreenHeader extends StatelessWidget {
  const _GreenHeader({required this.onLogoTap});
  final VoidCallback onLogoTap;

  @override
  Widget build(BuildContext context) {
    // Hide header only if the screen is extremely short (e.g., mobile landscape keyboard open)
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
            end: Alignment.bottomRight)),
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
                              vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8)),
                            child: const Text(
                              'DTS',
                              style: TextStyle(
                                color: _kGreen,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                letterSpacing: 2))),
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              'POS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                letterSpacing: 1))),
                        ]),
                      const SizedBox(height: 8),
                      const Text(
                        'Point of Sale',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your sales easily\nand efficiently',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          height: 1.4)),
                    ])),

                // POS machine illustration (text-art icon cluster)
                GestureDetector(
                  onTap: onLogoTap, // SECRET TAP TARGET
                  child: _PosMachineIllustration()),
              ])))));
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
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.point_of_sale_rounded,
            color: Colors.white,
            size: 36),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6)),
            child: const Text(
              'DTS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5))),
        ]));
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
      size.height - 20);
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 40,
      size.width,
      size.height - 10);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper oldClipper) => false;
}
