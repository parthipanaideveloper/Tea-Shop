import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../core/utils/ui_utils.dart';
import '../../services/firebase_sync_service.dart';

class SupportChatScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final String? clientShopCode;
  final String? clientShopName;
  final bool hideAppBar;

  const SupportChatScreen({
    super.key,
    this.onOpenDrawer,
    this.clientShopCode,
    this.clientShopName,
    this.hideAppBar = false,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  String? _selectedShopCode;
  String? _selectedShopName;
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.clientShopCode != null) {
      _selectedShopCode = widget.clientShopCode;
      _selectedShopName = widget.clientShopName ?? 'Support Chat';
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _isBase64Image(String data) {
    return data.startsWith('data:image/');
  }

  Uint8List _getBase64Bytes(String data) {
    try {
      final base64String = data.substring(data.indexOf(',') + 1);
      return base64.decode(base64String);
    } catch (_) {
      return Uint8List(0);
    }
  }

  void _viewFileAttachment(String name, String data) {
    showDialog(
      context: context,
      builder: (context) {
        final isTxt = name.endsWith('.txt');
        final isPdf = name.toLowerCase().endsWith('.pdf');
        String textContent = '';
        if (isTxt) {
          try {
            final bytes = _getBase64Bytes(data);
            textContent = utf8.decode(bytes);
          } catch (_) {
            textContent = 'Could not decode text content.';
          }
        }
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SizedBox(
            width: isPdf ? 500 : 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isPdf) ...[
                  SizedBox(
                    height: 400,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PdfPreview(
                        build: (format) async => _getBase64Bytes(data),
                        allowPrinting: true,
                        allowSharing: true,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                      ),
                    ),
                  ),
                ] else if (isTxt) ...[
                  const Icon(
                    Icons.text_snippet,
                    size: 64,
                    color: Color(0xFF4F46E5),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Content Preview:',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        textContent,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.insert_drive_file,
                    size: 64,
                    color: Color(0xFF4F46E5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Attachment Format Verified',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This attachment can be shared/saved or opened directly on your device.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () async {
                        try {
                          final bytes = _getBase64Bytes(data);
                          final tempDir = await getTemporaryDirectory();
                          final file = File('${tempDir.path}/$name');
                          await file.writeAsBytes(bytes);
                          await Share.shareXFiles([XFile(file.path)], text: name);
                        } catch (e) {
                          if (context.mounted) {
                            UiUtils.showSquarePopup(context, 'Failed to share: $e', isError: true);
                          }
                        }
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () async {
                        try {
                          String? outputFile = await FilePicker.saveFile(
                            dialogTitle: 'Save Attachment',
                            fileName: name,
                          );
                          if (outputFile != null) {
                            final bytes = _getBase64Bytes(data);
                            final file = File(outputFile);
                            await file.writeAsBytes(bytes);
                            if (context.mounted) {
                              UiUtils.showSquarePopup(context, 'Saved successfully to $outputFile');
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            UiUtils.showSquarePopup(context, 'Failed to download: $e', isError: true);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Color(0xFF4F46E5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showImagePreview(BuildContext context, String data, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) {
        final isBase64 = _isBase64Image(data);
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: isBase64
                      ? Image.memory(_getBase64Bytes(data), fit: BoxFit.contain)
                      : Image.network(data, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.download,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () async {
                            if (!isBase64) return;
                            try {
                              String? outputFile = await FilePicker.saveFile(
                                dialogTitle: 'Save Image',
                                fileName: title,
                              );
                              if (outputFile != null) {
                                final bytes = _getBase64Bytes(data);
                                final file = File(outputFile);
                                await file.writeAsBytes(bytes);
                                if (context.mounted) {
                                  UiUtils.showSquarePopup(context, 'Saved successfully to $outputFile');
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                UiUtils.showSquarePopup(context, 'Failed to download: $e', isError: true);
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
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

  Future<void> _pickAttachment() async {
    if (_selectedShopCode == null) return;
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'pdf',
          'txt',
          'doc',
          'docx',
        ],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploading = true);

      final file = result.files.first;
      final bytes =
          file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);

      if (bytes == null) {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to read file contents.')),
          );
        }
        return;
      }

      // Check size limit: 800 KB
      if (bytes.length > 800 * 1024) {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFFEF4444),
              content: Text(
                'File size exceeds 800KB safety limit. Please upload a smaller file.',
              ),
            ),
          );
        }
        return;
      }

      final ext = file.extension?.toLowerCase() ?? 'bin';
      final isImg = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
      final mime = isImg ? 'image/$ext' : 'application/$ext';
      final base64Data = 'data:$mime;base64,${base64.encode(bytes)}';

      await FirebaseSyncService.instance.sendSupportMessage(
        _selectedShopCode!,
        '',
        attachmentUrl: base64Data,
        attachmentName: file.name,
        attachmentType: ext,
        isMaster: widget.clientShopCode == null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting attachment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty || _selectedShopCode == null) return;
    FirebaseSyncService.instance.sendSupportMessage(
      _selectedShopCode!,
      text,
      isMaster: widget.clientShopCode == null,
    );
    _msgController.clear();
  }

  Widget _buildThreadList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseSyncService.instance.getSupportChatRoomsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
          );
        }
        final rooms = snapshot.data ?? [];
        final filteredRooms = rooms.where((room) {
          final code = room['shopCode'].toString().toLowerCase();
          final name = room['shopName'].toString().toLowerCase();
          return code.contains(_searchQuery) || name.contains(_searchQuery);
        }).toList();

        if (filteredRooms.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No shops found.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: filteredRooms.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
          itemBuilder: (context, index) {
            final room = filteredRooms[index];
            final shopCode = room['shopCode'] ?? 'Unknown';
            final shopName = room['shopName'] ?? 'Unknown Shop';
            final lastMsg = room['lastMessage'] ?? '';
            final unread = room['unreadCount'] ?? 0;
            final isSelected = _selectedShopCode == shopCode;

            final lastSeenAt = room['lastSeenAt'];
            DateTime? lastSeenDate;
            if (lastSeenAt is Timestamp) lastSeenDate = lastSeenAt.toDate();
            final bool isOnline =
                lastSeenDate != null &&
                DateTime.now().difference(lastSeenDate).inHours < 1;

            final int codeLen = shopCode.length;
            final int limit = codeLen < 2 ? codeLen : 2;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedShopCode = shopCode;
                  _selectedShopName = shopName;
                });
                FirebaseFirestore.instance
                    .collection('support_chats')
                    .doc(shopCode)
                    .set({'unreadCount': 0}, SetOptions(merge: true));
              },
              child: Container(
                color: isSelected
                    ? const Color(0xFFEEF2FF)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: isSelected
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFFE0E7FF),
                          child: Text(
                            shopCode.substring(0, limit).toUpperCase(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF4F46E5),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withOpacity(0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                shopCode,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isSelected
                                      ? const Color(0xFF1e293b)
                                      : const Color(0xFF334155),
                                ),
                              ),
                              if (unread > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            shopName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (lastMsg.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              lastMsg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusDropdown(String shopCode) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('support_chats').doc(shopCode).snapshots(),
      builder: (context, snapshot) {
        String currentStatus = 'OPEN';
        if (snapshot.hasData && snapshot.data!.exists) {
          currentStatus = (snapshot.data!.data() as Map<String, dynamic>)['status'] ?? 'OPEN';
        }
        
        Color getStatusColor(String status) {
          if (status == 'RESOLVED') return Colors.green;
          if (status == 'IN PROGRESS') return Colors.blue;
          return Colors.orange;
        }

        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: getStatusColor(currentStatus).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: getStatusColor(currentStatus).withOpacity(0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentStatus,
              icon: Icon(Icons.arrow_drop_down, color: getStatusColor(currentStatus)),
              items: ['OPEN', 'IN PROGRESS', 'RESOLVED'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: getStatusColor(value),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (newValue) async {
                if (newValue != null && newValue != currentStatus) {
                  await FirebaseFirestore.instance
                      .collection('support_chats')
                      .doc(shopCode)
                      .set({'status': newValue}, SetOptions(merge: true));
                  
                  await FirebaseFirestore.instance
                      .collection('support_chats')
                      .doc(shopCode)
                      .collection('messages')
                      .add({
                    'text': '[SYSTEM] Ticket status changed to ',
                    'sender': 'SYSTEM',
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickReplies() {
    final templates = [
      '🙋‍♂️ Hello! How can we assist you today?',
      '⚙️ We are investigating this issue. Please stand by.',
      '📄 Please share a screenshot or copy of the receipt if possible.',
      '🚀 The fix is live. Please restart the app to sync.',
      '✅ This issue has been resolved. Let us know if you need anything else!',
    ];
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9).withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: templates.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () => _msgController.text = templates[index],
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  templates[index],
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShopInfoPanel() {
    return Container(
      width: 260,
      color: Colors.white,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('support_chats').doc(_selectedShopCode).snapshots(),
        builder: (context, snapshot) {
          String status = 'OPEN';
          Timestamp? lastSeen;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            status = data['status'] ?? 'OPEN';
            if (data['lastSeenAt'] is Timestamp) {
              lastSeen = data['lastSeenAt'];
            }
          }
          final isOnline = lastSeen != null && DateTime.now().difference(lastSeen.toDate()).inMinutes < 5;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                color: const Color(0xFFF8FAFC),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFFEEF2FF),
                      child: const Icon(Icons.store, size: 32, color: Color(0xFF4F46E5)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedShopName ?? 'Unknown Shop',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedShopCode ?? '',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline ? Colors.green : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isOnline ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TICKET DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.label_important_outline, 'Status', status),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.access_time, 'Last Active', lastSeen != null ? ':' : 'Unknown'),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
      ],
    );
  }

  Widget _buildChatArea() {
    if (_selectedShopCode == null) {
      return Container(
        color: const Color(0xFFF8FAFC),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: const Color(0xFF94A3B8).withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select a shop from the support panel to start messaging.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Premium Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              if (widget.clientShopCode == null &&
                  MediaQuery.of(context).size.width < 1024) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF4F46E5)),
                  onPressed: () => setState(() {
                    _selectedShopCode = null;
                    _selectedShopName = null;
                  }),
                ),
                const SizedBox(width: 8),
              ],
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFEEF2FF),
                child: const Icon(
                  Icons.store_rounded,
                  color: Color(0xFF4F46E5),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedShopCode!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _selectedShopName ?? 'Store Location Active',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.clientShopCode == null) _buildStatusDropdown(_selectedShopCode!),
            ],
          ),
        ),
        // Messages Panel
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseSyncService.instance.getSupportMessages(
                _selectedShopCode!,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  );
                }
                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.forum_outlined,
                          color: Color(0xFF94A3B8),
                          size: 48,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No conversation history. Send a message to begin.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMaster = data['sender'] == 'MASTER_ADMIN';
                    final bool isMe = (widget.clientShopCode == null)
                        ? isMaster
                        : !isMaster;
                    final text = data['text'] ?? '';
                    final attachment = data['attachmentUrl'] as String?;
                    final attachmentName = data['attachmentName'] as String?;
                    final attachmentType = data['attachmentType'] as String?;
                    final ts = data['timestamp'];

                    DateTime? msgTime;
                    if (ts is Timestamp) msgTime = ts.toDate();
                    final timeStr = msgTime != null
                        ? '${msgTime.hour.toString().padLeft(2, '0')}:${msgTime.minute.toString().padLeft(2, '0')}'
                        : 'Just now';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (isMe)
                            Positioned(
                              right: -6,
                              bottom: 8,
                              child: CustomPaint(
                                size: const Size(12, 16),
                                painter: BubbleTailPainter(color: const Color(0xFF7C3AED), isMe: true),
                              ),
                            ),
                          if (!isMe)
                            Positioned(
                              left: -6,
                              bottom: 8,
                              child: CustomPaint(
                                size: const Size(12, 16),
                                painter: BubbleTailPainter(color: Colors.white, isMe: false),
                              ),
                            ),
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width < 800
                                  ? MediaQuery.of(context).size.width * 0.75
                                  : 500,
                            ),
                            decoration: BoxDecoration(
                              color: isMe ? null : Colors.white,
                              gradient: isMe
                                  ? const LinearGradient(
                                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                                bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isMe ? const Color(0xFF4F46E5).withOpacity(0.2) : Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Render Attachment
                            if (attachment != null) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: _isBase64Image(attachment)
                                    ? MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: GestureDetector(
                                          onTap: () => _showImagePreview(
                                            context,
                                            attachment,
                                            attachmentName ??
                                                'Image Attachment',
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Image.memory(
                                              _getBase64Bytes(attachment),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: 180,
                                              errorBuilder: (_, __, ___) => Container(
                                                height: 120,
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: isMe
                                                      ? Colors.white
                                                            .withOpacity(0.08)
                                                      : const Color(0xFFF1F5F9),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      color: isMe
                                                          ? Colors.white70
                                                          : const Color(
                                                              0xFF94A3B8,
                                                            ),
                                                      size: 32,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'Image Attachment',
                                                      style: TextStyle(
                                                        color: isMe
                                                            ? Colors.white70
                                                            : const Color(
                                                                0xFF64748B,
                                                              ),
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      attachmentName ??
                                                          'image.$attachmentType',
                                                      style: TextStyle(
                                                        color: isMe
                                                            ? Colors.white38
                                                            : const Color(
                                                                0xFF94A3B8,
                                                              ),
                                                        fontSize: 9,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : attachment.startsWith('http')
                                    ? MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: GestureDetector(
                                          onTap: () => _showImagePreview(
                                            context,
                                            attachment,
                                            attachmentName ??
                                                'Image Attachment',
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Image.network(
                                              attachment,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: 180,
                                              errorBuilder: (_, __, ___) => Container(
                                                height: 120,
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: isMe
                                                      ? Colors.white
                                                            .withOpacity(0.08)
                                                      : const Color(0xFFF1F5F9),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      color: isMe
                                                          ? Colors.white70
                                                          : const Color(
                                                              0xFF94A3B8,
                                                            ),
                                                      size: 32,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'Image Attachment',
                                                      style: TextStyle(
                                                        color: isMe
                                                            ? Colors.white70
                                                            : const Color(
                                                                0xFF64748B,
                                                              ),
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      attachmentName ??
                                                          'image.$attachmentType',
                                                      style: TextStyle(
                                                        color: isMe
                                                            ? Colors.white38
                                                            : const Color(
                                                                0xFF94A3B8,
                                                              ),
                                                        fontSize: 9,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? Colors.white.withOpacity(0.12)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: isMe
                                                ? Colors.white12
                                                : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.insert_drive_file,
                                              color: isMe
                                                  ? Colors.white
                                                  : const Color(0xFF4F46E5),
                                              size: 28,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    attachmentName ??
                                                        'Attached Document',
                                                    style: TextStyle(
                                                      color: isMe
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF1E293B,
                                                            ),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    attachmentType
                                                            ?.toUpperCase() ??
                                                        'DOCUMENT',
                                                    style: TextStyle(
                                                      color: isMe
                                                          ? Colors.white70
                                                          : const Color(
                                                              0xFF64748B,
                                                            ),
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.visibility,
                                                color: isMe
                                                    ? Colors.white
                                                    : const Color(0xFF4F46E5),
                                                size: 20,
                                              ),
                                              onPressed: () => _viewFileAttachment(
                                                attachmentName ??
                                                    'document.$attachmentType',
                                                attachment,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ],
                            // Render Message Text
                            if (text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    fontSize: 13.5,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            // Render Timestamp and Checkmark
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.grey,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.done_all,
                                      color: Colors.cyanAccent,
                                      size: 12,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
                );
              },
            ),
          ),
        ),
        if (widget.clientShopCode == null && _selectedShopCode != null)
          _buildQuickReplies(),
        // Send Input Area (Premium Glassmorphism Style)
        ClipRRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white.withOpacity(0.85),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_isUploading)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(
                            Icons.attach_file,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: _pickAttachment,
                          tooltip: 'Attach Image or File',
                        ),
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _isUploading
                  ? const SizedBox()
                  : Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ),
            ],
          ),
        ),
        ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    Widget buildThreadListPane() {
      return Container(
        width: isMobile ? double.infinity : 340,
        color: Colors.white,
        child: Column(
          children: [
            if (!isMobile)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: const [
                    Icon(Icons.forum, color: Color(0xFF4F46E5), size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Support Tickets',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search shop code or name...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Expanded(child: _buildThreadList()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: (widget.hideAppBar || !isMobile)
          ? null
          : AppBar(
              title: const Text(
                'Support Tickets',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              backgroundColor: const Color(0xFFF0F4F8),
              elevation: 0,
              foregroundColor: const Color(0xFF1E293B),
              leading: widget.onOpenDrawer != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: widget.onOpenDrawer,
                    )
                  : null,
            ),
      body: Container(
        margin: EdgeInsets.all(isMobile ? 8 : 24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.clientShopCode != null
            ? _buildChatArea()
            : (isMobile
                  ? (_selectedShopCode == null
                        ? buildThreadListPane()
                        : _buildChatArea())
                  : Row(
                      children: [
                        buildThreadListPane(),
                        const VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Color(0xFFE2E8F0),
                        ),
                        Expanded(child: _buildChatArea()),
                        if (_selectedShopCode != null) ...[
                          const VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: Color(0xFFE2E8F0),
                          ),
                          _buildShopInfoPanel(),
                        ],
                      ],
                    )),
      ),
    );
  }
}

class BubbleTailPainter extends CustomPainter {
  final Color color;
  final bool isMe;

  BubbleTailPainter({required this.color, required this.isMe});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (isMe) {
      path.moveTo(0, 0);
      path.lineTo(size.width, size.height / 2);
      path.lineTo(0, size.height);
      path.close();
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(0, size.height / 2);
      path.lineTo(size.width, size.height);
      path.close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
