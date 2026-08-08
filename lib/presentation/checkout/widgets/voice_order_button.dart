import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../core/services/ai_service.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/inventory_provider.dart';

class VoiceOrderButton extends ConsumerStatefulWidget {
  const VoiceOrderButton({super.key});

  @override
  ConsumerState<VoiceOrderButton> createState() => _VoiceOrderButtonState();
}

class _VoiceOrderButtonState extends ConsumerState<VoiceOrderButton> {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _isProcessing = false;
  String _wordsSpoken = "";

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      await _speechToText.initialize();
    } catch (e) {
      debugPrint("Speech initialization failed: \$e");
    }
  }

  void _startListening() async {
    setState(() {
      _isListening = true;
      _wordsSpoken = "";
    });
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _wordsSpoken = result.recognizedWords;
        });
      },
      localeId: 'ta_IN', // Prefer Tamil for tanglish
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
      _isProcessing = true;
    });

    if (_wordsSpoken.isNotEmpty) {
      await _processVoiceInput(_wordsSpoken);
    } else {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processVoiceInput(String text) async {
    final inventory = ref.read(inventoryProvider);
    final mappedOrder = await AiService().processVoiceOrder(text, inventory);

    if (mappedOrder.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not recognize any items from voice.')),
        );
      }
    } else {
      final cartNotifier = ref.read(cartProvider.notifier);
      for (final entry in mappedOrder.entries) {
        final productId = entry.key;
        final qty = entry.value;
        
        try {
          final product = inventory.firstWhere((p) => p.id == productId);
          cartNotifier.addProduct(product);
          // Assuming addProduct adds 1. We update the quantity if > 1.
          if (qty > 1) {
            cartNotifier.updateQuantity(product.id, qty);
          }
        } catch (e) {
          debugPrint('Product not found: ');
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added \${mappedOrder.length} items from voice!')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          shape: BoxShape.circle,
        ),
        child: const Padding(
          padding: EdgeInsets.all(12.0),
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    return InkWell(
      onTap: _toggleListening,
      customBorder: const CircleBorder(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _isListening ? Colors.red : Colors.blue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (_isListening ? Colors.red : Colors.blue).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          _isListening ? Icons.mic : Icons.mic_none,
          color: Colors.white,
        ),
      ),
    );
  }
}
