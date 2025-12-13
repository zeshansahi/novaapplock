import 'package:flutter/material.dart';

class PinInputWidget extends StatefulWidget {
  final int pinLength;
  final Function(String) onPinComplete;

  const PinInputWidget({
    super.key,
    required this.pinLength,
    required this.onPinComplete,
  });

  @override
  State<PinInputWidget> createState() => _PinInputWidgetState();
}

class _PinInputWidgetState extends State<PinInputWidget> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  String _pin = '';

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.pinLength; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
    _focusNodes[0].requestFocus();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      _controllers[index].text = value.substring(value.length - 1);
    }

    if (value.isNotEmpty && index < widget.pinLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    _updatePin();
  }


  void _updatePin() {
    setState(() {
      _pin = _controllers.map((c) => c.text).join();
      if (_pin.length == widget.pinLength) {
        widget.onPinComplete(_pin);
        // Clear after a short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          for (var controller in _controllers) {
            controller.clear();
          }
          _focusNodes[0].requestFocus();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.pinLength,
        (index) => Container(
          width: 60,
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            obscureText: true,
            style: Theme.of(context).textTheme.headlineSmall,
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            onChanged: (value) => _onChanged(index, value),
            onTap: () {
              _controllers[index].selection = TextSelection.fromPosition(
                TextPosition(offset: _controllers[index].text.length),
              );
            },
            onSubmitted: (_) {
              if (index < widget.pinLength - 1) {
                _focusNodes[index + 1].requestFocus();
              }
            },
          ),
        ),
      ),
    );
  }
}

