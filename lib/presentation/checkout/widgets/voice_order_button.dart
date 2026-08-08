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

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return FloatingActionButton(
        onPressed: null,
        backgroundColor: Colors.grey,
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onLongPressStart: (_) => _startListening(),
      onLongPressEnd: (_) => _stopListening(),
      child: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hold button to speak')),
          );
        },
        backgroundColor: _isListening ? Colors.red : Colors.blue,
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
    );
  }
}
