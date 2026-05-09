import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_spacing.dart';

class MomentCommentInput extends StatefulWidget {
  const MomentCommentInput({
    required this.onSubmit,
    this.isReply = false,
    this.isSubmitting = false,
    super.key,
  });

  final Future<void> Function(String body) onSubmit;
  final bool isReply;
  final bool isSubmitting;

  @override
  State<MomentCommentInput> createState() => _MomentCommentInputState();
}

class _MomentCommentInputState extends State<MomentCommentInput> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: !_isBusy,
            minLines: 1,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: widget.isReply
                  ? context.l10n.replyInputHint
                  : context.l10n.commentInputHint,
              border: const OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filled(
          tooltip: context.l10n.sendComment,
          onPressed: _isBusy ? null : _submit,
          icon: const Icon(Icons.send_outlined),
        ),
      ],
    );
  }

  bool get _isBusy => widget.isSubmitting || _isSubmitting;

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit(text);

      if (!mounted) {
        return;
      }

      _controller.clear();
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
