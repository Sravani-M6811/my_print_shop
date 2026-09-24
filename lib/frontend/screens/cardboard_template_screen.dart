import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_catalog.dart';
import '../models/product.dart';
import '../providers/app_state.dart';
import '../../ui/widgets/catalogue_image.dart';
import 'design_customize_screen.dart';

/// Dedicated Cardboard order flow step: "Select Size -> Select Template ->
/// Enter/Edit Matter -> Preview".
///
/// Cardboards are template-driven, so instead of the generic gallery the
/// customer picks a template grouped by kind (Invitation / Event / School /
/// Business / Promotional / Celebration / Decorative / Blank) and then enters
/// the text "matter" that will be printed on the board. Both the chosen
/// template and the matter are carried into [DesignCustomizeScreen], so nothing
/// is lost when the user steps forward or back.
class CardboardTemplateScreen extends StatefulWidget {
  /// The Cardboard board (specific size) selected by the customer.
  final Product baseProduct;

  /// Colour/option chosen for the board (e.g. 'White' / 'Brown').
  final String? selectedVariant;

  /// The size label shown on the product banner.
  final String? selectedSize;

  /// Quantity selected on the product detail screen.
  final int quantity;

  const CardboardTemplateScreen({
    super.key,
    required this.baseProduct,
    this.selectedVariant,
    this.selectedSize,
    this.quantity = 1,
  });

  @override
  State<CardboardTemplateScreen> createState() => _CardboardTemplateScreenState();
}

class _CardboardTemplateScreenState extends State<CardboardTemplateScreen> {
  final TextEditingController _matterController = TextEditingController();
  Product? _selectedTemplate;

  @override
  void dispose() {
    _matterController.dispose();
    super.dispose();
  }

  /// Cardboard design/template records, grouped by [Product.templateType].
  Map<String, List<Product>> get _templatesByType {
    final designs = ProductCatalog.productsForCategory('Cardboard');
    final map = <String, List<Product>>{};
    for (final d in designs) {
      final type = d.templateType.isEmpty ? 'Template' : d.templateType;
      map.putIfAbsent(type, () => []).add(d);
    }
    return map;
  }

  /// The selected template validated against the base product's compatibles.
  bool get _canSelect => _selectedTemplate != null;

  void _continue() {
    final template = _selectedTemplate;
    if (template == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: Provider.of<AppState>(context, listen: false),
          child: DesignCustomizeScreen(
            product: template,
            baseProduct: widget.baseProduct,
            selectedVariant: widget.selectedVariant,
            selectedSize: widget.selectedSize,
            quantity: widget.quantity,
            initialText:
                _matterController.text.trim().isNotEmpty ? _matterController.text : '',
            title: 'Enter Matter & Preview',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseProduct;
    final templates = _templatesByType;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Cardboard Template',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Selected board banner ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF4B3FBF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CatalogueImage(
                        imagePath: base.imagePath,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            base.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          if (widget.selectedSize != null &&
                              widget.selectedSize!.isNotEmpty)
                            Text(
                              'Size: ${widget.selectedSize}',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12),
                            ),
                          if (widget.selectedVariant != null &&
                              widget.selectedVariant!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Colour: ${widget.selectedVariant}',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            'Step 1 — pick a template below',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Template sections ──
            for (final entry in templates.entries)
              if (entry.value.isNotEmpty)
                _TemplateSection(
                  title: entry.key,
                  templates: entry.value,
                  selectedId: _selectedTemplate?.id,
                  onSelect: (p) => setState(() => _selectedTemplate = p),
                ),

            const SizedBox(height: 8),

            // ── Matter / Text Content ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Step 2 — Enter/Edit Matter',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'The text (matter) printed on your board. You can adjust it later on the customize screen if needed.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _matterController,
                    maxLines: 3,
                    minLines: 2,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Matter / Text Content',
                      hintText: 'e.g. Happy Birthday Ramesh!',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.notes),
                    ),
                  ),
                ],
              ),
            ),

            if (_selectedTemplate != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            const Color(0xFF6C5CE7).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Selection',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6C5CE7))),
                      const SizedBox(height: 6),
                      _SelectionRow(label: 'Board', value: base.name),
                      _SelectionRow(
                          label: 'Template', value: _selectedTemplate!.name),
                      _SelectionRow(
                          label: 'Matter',
                          value: _matterController.text.trim().isEmpty
                              ? '—'
                              : _matterController.text.trim()),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── Continue ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    _selectedTemplate == null
                        ? 'Select a Template to Continue'
                        : 'Continue to Customize',
                    style:
                        const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _canSelect ? _continue : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateSection extends StatelessWidget {
  final String title;
  final List<Product> templates;
  final String? selectedId;
  final void Function(Product) onSelect;

  const _TemplateSection({
    required this.title,
    required this.templates,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            '$title Templates',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final t = templates[index];
              final selected = t.id == selectedId;
              return _TemplateCard(
                template: t,
                selected: selected,
                onTap: () => onSelect(t),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Product template;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected ? const Color(0xFF6C5CE7) : Colors.grey.shade300,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x336C5CE7), blurRadius: 8)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(13)),
                child: CatalogueImage(
                  imagePath: template.imagePath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '₹${template.basePrice.toInt()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6C5CE7)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF6C5CE7)
                                : Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            selected ? 'Selected' : 'Select',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: selected
                                    ? Colors.white
                                    : Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionRow extends StatelessWidget {
  final String label;
  final String value;

  const _SelectionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
