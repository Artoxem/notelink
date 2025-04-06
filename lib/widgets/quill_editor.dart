import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class QuillEditorWidget extends StatefulWidget {
  final QuillController controller;
  final bool readOnly;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;

  const QuillEditorWidget({
    Key? key,
    required this.controller,
    this.readOnly = false,
    this.focusNode,
    this.onChanged,
  }) : super(key: key);

  @override
  State<QuillEditorWidget> createState() => _QuillEditorWidgetState();
}

class _QuillEditorWidgetState extends State<QuillEditorWidget> {
  late ScrollController _scrollController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _focusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _scrollController.dispose();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Панель инструментов
        Container(
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.format_bold),
                  onPressed:
                      () => widget.controller.formatSelection(Attribute.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.format_italic),
                  onPressed:
                      () => widget.controller.formatSelection(Attribute.italic),
                ),
                IconButton(
                  icon: const Icon(Icons.format_underline),
                  onPressed:
                      () => widget.controller.formatSelection(
                        Attribute.underline,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.format_clear),
                  onPressed: () => widget.controller.clearFormat(),
                ),
                const VerticalDivider(),
                IconButton(
                  icon: const Icon(Icons.format_list_bulleted),
                  onPressed:
                      () => widget.controller.formatSelection(Attribute.ul),
                ),
                IconButton(
                  icon: const Icon(Icons.format_list_numbered),
                  onPressed:
                      () => widget.controller.formatSelection(Attribute.ol),
                ),
              ],
            ),
          ),
        ),
        // Область редактирования
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: QuillEditor.basic(
              controller: widget.controller,
              readOnly: widget.readOnly,
              scrollController: _scrollController,
              focusNode: _focusNode,
            ),
          ),
        ),
      ],
    );
  }

  void _onChanged() {
    if (widget.onChanged != null) {
      widget.onChanged!(widget.controller.document.toPlainText());
    }
  }
}
