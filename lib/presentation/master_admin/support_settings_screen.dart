import 'package:pos/core/utils/notification_helper.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_sync_service.dart';
import '../../services/master_password_service.dart';
import 'master_admin_shell.dart'; // for kMasterWorkspaceColor

class SupportSettingsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final bool hideAppBar;
  const SupportSettingsScreen({
    super.key,
    this.onOpenDrawer,
    this.hideAppBar = false,
  });

  @override
  State<SupportSettingsScreen> createState() => _SupportSettingsScreenState();
}

class _SupportSettingsScreenState extends State<SupportSettingsScreen> {
  void _showChangeMasterPasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? err;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kMasterWorkspaceColor,
          title: const Row(
            children: [
              Icon(Icons.vpn_key, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text(
                'Change Master Password',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (err != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    err!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Master Password',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Master Password',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Master Password',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!MasterPasswordService().verifyMasterPassword(
                  currentCtrl.text,
                )) {
                  setDialogState(
                    () => err = 'Current master password is incorrect',
                  );
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  setDialogState(() => err = 'Passwords do not match');
                  return;
                }
                if (newCtrl.text.length < 8) {
                  setDialogState(
                    () => err = 'Master password must be at least 8 characters',
                  );
                  return;
                }
                await MasterPasswordService().setMasterPassword(newCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  NotificationHelper.showCenter(
                    context,
                    'Master password changed successfully! 🔐',
                    isError: false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('CHANGE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileSettingsDialog(BuildContext context) {
    final phoneCtrl = TextEditingController();
    final otpCtrl = TextEditingController();

    final prevPhone = FirebaseSyncService().getSupportPhoneNumber();
    String maskedPhone = prevPhone;
    if (prevPhone.length > 4) {
      maskedPhone = '******${prevPhone.substring(prevPhone.length - 4)}';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool otpSent = false;
        bool isSendingOtp = false;
        bool isVerifyingOtp = false;
        bool isOtpVerified = false;
        String? currentVerificationId;
        String? statusMsg;
        Color statusColor = Colors.grey;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: kMasterWorkspaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.phone_android, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Support Mobile No',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Authorize via Current Number:\n$maskedPhone',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    const Divider(height: 20),
                    if (statusMsg != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: statusColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusMsg!,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!isOtpVerified) ...[
                      if (!otpSent)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: isSendingOtp
                              ? null
                              : () async {
                                  setState(() {
                                    isSendingOtp = true;
                                    statusMsg = 'Sending OTP...';
                                    statusColor = Colors.orange;
                                  });

                                  try {
                                    await FirebaseAuth.instance.verifyPhoneNumber(
                                      phoneNumber: prevPhone,
                                      verificationCompleted:
                                          (
                                            PhoneAuthCredential credential,
                                          ) async {
                                            // Auto-retrieval completed
                                            try {
                                              await FirebaseAuth.instance
                                                  .signInWithCredential(
                                                    credential,
                                                  );
                                              setState(() {
                                                isOtpVerified = true;
                                                statusMsg =
                                                    'OTP Auto-Verified!';
                                                statusColor = Colors.green;
                                              });
                                            } catch (e) {
                                              // Ignore error, let them enter manually
                                            }
                                          },
                                      verificationFailed:
                                          (FirebaseAuthException e) {
                                            setState(() {
                                              isSendingOtp = false;
                                              statusMsg =
                                                  'Verification failed: ${e.message}';
                                              statusColor = Colors.red;
                                            });
                                          },
                                      codeSent:
                                          (
                                            String verificationId,
                                            int? resendToken,
                                          ) {
                                            setState(() {
                                              currentVerificationId =
                                                  verificationId;
                                              isSendingOtp = false;
                                              otpSent = true;
                                              statusMsg =
                                                  'OTP sent via SMS to your current number.';
                                              statusColor = Colors.green;
                                            });
                                          },
                                      codeAutoRetrievalTimeout:
                                          (String verificationId) {
                                            currentVerificationId =
                                                verificationId;
                                          },
                                    );
                                  } catch (e) {
                                    setState(() {
                                      isSendingOtp = false;
                                      statusMsg =
                                          'Failed to initiate phone verification: $e';
                                      statusColor = Colors.red;
                                    });
                                  }
                                },
                          icon: isSendingOtp
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            isSendingOtp
                                ? 'Sending...'
                                : 'Send OTP to Current Number',
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: otpCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: const InputDecoration(
                                labelText: 'Enter 6-digit SMS OTP',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock_clock),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: isVerifyingOtp
                                  ? null
                                  : () async {
                                      setState(() {
                                        isVerifyingOtp = true;
                                        statusMsg = 'Verifying...';
                                        statusColor = Colors.orange;
                                      });
                                      try {
                                        PhoneAuthCredential credential =
                                            PhoneAuthProvider.credential(
                                              verificationId:
                                                  currentVerificationId!,
                                              smsCode: otpCtrl.text.trim(),
                                            );
                                        await FirebaseAuth.instance
                                            .signInWithCredential(credential);

                                        setState(() {
                                          isVerifyingOtp = false;
                                          isOtpVerified = true;
                                          statusMsg =
                                              'OTP Verified Successfully! You can now change the number.';
                                          statusColor = Colors.green;
                                        });
                                      } catch (e) {
                                        setState(() {
                                          isVerifyingOtp = false;
                                          statusMsg =
                                              'Incorrect OTP. Please check and try again.';
                                          statusColor = Colors.red;
                                        });
                                      }
                                    },
                              icon: isVerifyingOtp
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.verified),
                              label: Text(
                                isVerifyingOtp ? 'Verifying...' : 'Verify OTP',
                              ),
                            ),
                          ],
                        ),
                    ],
                    if (isOtpVerified) ...[
                      const Divider(height: 24),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'New WhatsApp / Mobile No',
                          hintText: '+919876543210',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOtpVerified
                        ? Colors.green
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isOtpVerified
                      ? () async {
                          if (phoneCtrl.text.trim().isEmpty) {
                            setState(() {
                              statusMsg = 'Please enter a valid new number.';
                              statusColor = Colors.red;
                            });
                            return;
                          }
                          await FirebaseSyncService().updateGlobalConfig(
                            supportPhoneNumber: phoneCtrl.text.trim(),
                          );
                          Navigator.pop(context);
                          NotificationHelper.showCenter(
                            context,
                            'Customer support phone number updated successfully!',
                            isError: false,
                          );
                        }
                      : null,
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEmailSettingsDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    final otpCtrl = TextEditingController();

    final prevEmail = FirebaseSyncService().getSenderEmail();
    final prevPwd = FirebaseSyncService().getSenderAppPassword();

    // Mask current email for display
    String maskedEmail = prevEmail;
    if (prevEmail.contains('@')) {
      final parts = prevEmail.split('@');
      final name = parts[0];
      final domain = parts[1];
      if (name.length > 3) {
        maskedEmail =
            '${name.substring(0, 2)}***${name.substring(name.length - 2)}@$domain';
      } else {
        maskedEmail = '***@$domain';
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool otpSent = false;
        bool isSendingOtp = false;
        bool isOtpVerified = false;
        bool obscurePwd = true;
        String? generatedOtp;
        String? statusMsg;
        Color statusColor = Colors.grey;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: kMasterWorkspaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.email_outlined, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text(
                    'Email Setup (Gmail)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Authorize via Current Email:\n$maskedEmail',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    const Divider(height: 20),
                    if (statusMsg != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: statusColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusMsg!,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!isOtpVerified) ...[
                      if (!otpSent)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: isSendingOtp
                              ? null
                              : () async {
                                  setState(() {
                                    isSendingOtp = true;
                                    statusMsg =
                                        'Sending verification code to current email...';
                                    statusColor = Colors.blue;
                                  });
                                  try {
                                    final otp =
                                        (Random().nextInt(900000) + 100000)
                                            .toString();
                                    final smtpServer = gmail(
                                      prevEmail,
                                      prevPwd,
                                    );
                                    final message = Message()
                                      ..from = Address(
                                        prevEmail,
                                        'DTS POS Alerts Security',
                                      )
                                      ..recipients.add(prevEmail)
                                      ..subject =
                                          'OTP: Update Customer Support Email'
                                      ..text =
                                          'Your security verification OTP to update the customer support email is: $otp\n\nIf you did not request this change, please check your account security.';
                                    await send(message, smtpServer);
                                    setState(() {
                                      generatedOtp = otp;
                                      otpSent = true;
                                      isSendingOtp = false;
                                      statusMsg =
                                          'Code sent to previous email ID successfully!';
                                      statusColor = Colors.green;
                                    });
                                  } catch (e) {
                                    setState(() {
                                      isSendingOtp = false;
                                      statusMsg =
                                          'Verification failed: Could not send OTP using previous credentials. Error: $e';
                                      statusColor = Colors.red;
                                    });
                                  }
                                },
                          icon: isSendingOtp
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            isSendingOtp
                                ? 'Sending...'
                                : 'Send Code to Current Email',
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: otpCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: const InputDecoration(
                                labelText: 'Enter 6-digit OTP',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock_clock),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                if (otpCtrl.text.trim() == generatedOtp) {
                                  setState(() {
                                    isOtpVerified = true;
                                    statusMsg =
                                        'OTP Verified! You can now change the email.';
                                    statusColor = Colors.green;
                                  });
                                } else {
                                  setState(() {
                                    statusMsg =
                                        'Incorrect OTP. Please check and try again.';
                                    statusColor = Colors.red;
                                  });
                                }
                              },
                              icon: const Icon(Icons.verified),
                              label: const Text('Verify OTP'),
                            ),
                          ],
                        ),
                    ],
                    if (isOtpVerified) ...[
                      const Divider(height: 24),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'New Gmail ID',
                          hintText: 'example@gmail.com',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.mail),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pwdCtrl,
                        obscureText: obscurePwd,
                        decoration: InputDecoration(
                          labelText: 'New App Password',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.vpn_key),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePwd
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => obscurePwd = !obscurePwd),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOtpVerified
                        ? Colors.green
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isOtpVerified
                      ? () async {
                          if (emailCtrl.text.trim().isEmpty ||
                              pwdCtrl.text.trim().isEmpty) {
                            setState(() {
                              statusMsg =
                                  'Please enter both new email and app password.';
                              statusColor = Colors.red;
                            });
                            return;
                          }
                          await FirebaseSyncService().updateGlobalConfig(
                            senderEmail: emailCtrl.text.trim(),
                            senderAppPassword: pwdCtrl.text.trim(),
                          );
                          Navigator.pop(context);
                          NotificationHelper.showCenter(
                            context,
                            'Global email credentials updated successfully!',
                            isError: false,
                          );
                        }
                      : null,
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNeumorphicTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
          BoxShadow(
            color: Color(0xFFD1D9E6),
            blurRadius: 6,
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMasterWorkspaceColor,
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              title: const Text(
                'Customer Support Settings',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              backgroundColor: kMasterWorkspaceColor,
              elevation: 0,
              foregroundColor: const Color(0xFF1E293B),
              iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
              leading: widget.onOpenDrawer != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: widget.onOpenDrawer,
                    )
                  : null,
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 768;
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1100),
              padding: const EdgeInsets.all(32.0),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildNeumorphicTile(
                            icon: Icons.phone,
                            iconColor: Colors.orange,
                            title: 'Support Mobile Number',
                            onTap: () => _showMobileSettingsDialog(context),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildNeumorphicTile(
                            icon: Icons.email,
                            iconColor: Colors.blue,
                            title: 'Email Setup',
                            onTap: () => _showEmailSettingsDialog(context),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildNeumorphicTile(
                            icon: Icons.vpn_key,
                            iconColor: Colors.deepPurple,
                            title: 'Change Master Password',
                            onTap: _showChangeMasterPasswordDialog,
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildNeumorphicTile(
                            icon: Icons.phone,
                            iconColor: Colors.orange,
                            title: 'Support Mobile Number',
                            onTap: () => _showMobileSettingsDialog(context),
                          ),
                          _buildNeumorphicTile(
                            icon: Icons.email,
                            iconColor: Colors.blue,
                            title: 'Email Setup',
                            onTap: () => _showEmailSettingsDialog(context),
                          ),
                          _buildNeumorphicTile(
                            icon: Icons.vpn_key,
                            iconColor: Colors.deepPurple,
                            title: 'Change Master Password',
                            onTap: _showChangeMasterPasswordDialog,
                          ),
                        ],
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
