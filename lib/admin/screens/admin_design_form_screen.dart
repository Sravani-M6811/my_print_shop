import 'package:flutter/material.dart';

import '../../frontend/data/product_catalog.dart';
import '../../frontend/models/design.dart';
import '../services/catalogue_service.dart';
import '../widgets/catalogue_image_field.dart';

/// Add / edit a reusable print design.
///
/// Reuses the existing [Design] model and writes through a
/// [CatalogueRepository] so changes persist to Firestore (admin-only).
class AdminDesignFormScreen extends StatefulWidget {
  final CatalogueRepository repository;

  /// When null the form creates a new design; otherwise it preloads and edits
  /// the given design.
  final Design? design;

  const AdminDesignFormScreen({
    super.key,
    required this.repository,
    this.design,
  });

  @override
  State<AdminDesignFormScreen> createState() => _AdminDesignFormScreenState();
}

class _AdminDesignFormScreenState extends State<AdminDesignFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _image;
  late final TextEditingController _tags;
  late final TextEditingController _templateType;
  late final TextEditingController _price;
  late final TextEditingController _keywords;
  late final TextEditingController _compatibleProductIds;

  late String _category;
  late String _designType;
  late bool _availability;
  late bool _isTrending;
  late bool _supportsCustomization;
  late bool _supportsUpload;

  /// Which plain-product categories this design can be applied to. Defaults to
  /// the design's own category so a newly added design stays compatible with
  /// its category's base products until an admin narrows it.
  late Set<String> _compatibleCategories;
  bool _saving = false;

  bool get _isEditing => widget.design != null;

  @override
  void initState() {
    super.initState();
    final d = widget.design;
    _name = TextEditingController(text: d?.name ?? '');
    _description = TextEditingController(text: d?.description ?? '');
    _image = TextEditingController(text: d?.imagePath ?? '');
    _tags = TextEditingController(text: (d?.tags ?? const []).join(', '));
    _templateType = TextEditingController(text: d?.templateType ?? '');
    _price = TextEditingController(
        text: d != null && d.basePrice > 0 ? _formatPrice(d.basePrice) : '');
    _keywords =
        TextEditingController(text: (d?.keywords ?? const []).join(', '));
    _compatibleProductIds = TextEditingController(
        text: (d?.compatibleProductIds ?? const []).join(', '));

    _category = d?.category ?? ProductCatalog.categories.first;
    _designType = d?.designType ?? '';
    _availability = d?.availability ?? true;
    _isTrending = d?.isTrending ?? false;
    _supportsCustomization = d?.supportsCustomization ?? true;
    _supportsUpload = d?.supportsUpload ?? true;
    _compatibleCategories = Set<String>.from(
      d != null && d.compatibleCategories.isNotEmpty
          ? d.compatibleCategories
          : d != null && d.category.isNotEmpty
              ? [d.category]
              : <String>[],
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _image.dispose();
    _tags.dispose();
    _templateType.dispose();
    _price.dispose();
    _keywords.dispose();
    _compatibleProductIds.dispose();
    super.dispose();
  }

  String _formatPrice(double price) =>
      price == price.roundToDouble() ? price.toInt().toString() : price.toString();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final design = Design(
        designId: _isEditing
            ? widget.design!.designId
            : 'd_${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        imagePath: _image.text.trim(),
        category: _category,
        tags: _splitList(_tags.text),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        availability: _availability,
        designType: _designType.trim(),
        isTrending: _isTrending,
        templateType: _templateType.text.trim(),
        compatibleCategories: _compatibleCategories.toList(),
        compatibleProductIds: _splitList(_compatibleProductIds.text),
        supportsCustomization: _supportsCustomization,
        supportsUpload: _supportsUpload,
        basePrice: _price.text.trim().isEmpty
            ? 0
            : double.parse(_price.text.trim()),
        keywords: _splitList(_keywords.text),
      );
      if (_isEditing) {
        await widget.repository.updateDesign(design);
      } else {
        await widget.repository.createDesign(design);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Design updated.' : 'Design added.')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save design. Check your connection and try again.')),
      );
    }
  }

  List<String> _splitList(String text) => text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .map((s) => s.length <= 40 ? s : s.substring(0, 40))
      .toList();

  String? _fieldValidator(String? v, String label, int max) {
    final requiredError = CatalogueService.required(v, label);
    if (requiredError != null) return requiredError;
    return CatalogueService.maxLength(v, label, max);
  }

  String? _priceValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final parsed = double.tryParse(v.trim());
    if (parsed == null || parsed < 0) return 'Enter a valid price';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Design' : 'Add Design'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    validator: (v) => _fieldValidator(v, 'Design name', 120),
                    decoration: const InputDecoration(
                      labelText: 'Design name *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    items: [
                      for (final c in ProductCatalog.categories)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? _category),
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CatalogueImageField(
                    controller: _image,
                    category: _category,
                    validator: (v) =>
                        CatalogueService.validateImage(v) ??
                        CatalogueService.maxLength(v, 'Image', 2048),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: _priceValidator,
                    decoration: const InputDecoration(
                      labelText: 'Price (₹) *',
                      prefixText: '₹ ',
                      helperText: '0 = use the base product price',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    validator: (v) =>
                        CatalogueService.maxLength(v, 'Description', 2000),
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('designType'),
                    initialValue: _designType.isEmpty ? null : _designType,
                    hint: const Text('Design type (optional)'),
                    items: [
                      for (final t in ProductCatalog.allDesignTypes)
                        DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged: (v) => setState(() => _designType = v ?? ''),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Compatible Categories',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The plain/base product categories this design can be '
                    'printed on. Used to enforce product -> design '
                    'compatibility.',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in ProductCatalog.categories)
                        FilterChip(
                          label: Text(c, style: const TextStyle(fontSize: 12)),
                          selected: _compatibleCategories.contains(c),
                          onSelected: (sel) => setState(() {
                            if (sel) {
                              _compatibleCategories.add(c);
                            } else {
                              _compatibleCategories.remove(c);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('compatibleProductIds'),
                    controller: _compatibleProductIds,
                    validator: (v) => CatalogueService.maxLength(
                        v, 'Compatible product IDs', 2000),
                    decoration: const InputDecoration(
                      labelText: 'Compatible product IDs (optional)',
                      hintText: 'e.g. base_saree, base_tshirt (comma separated)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _templateType,
                    validator: (v) =>
                        CatalogueService.maxLength(v, 'Template type', 80),
                    decoration: const InputDecoration(
                      labelText: 'Template type (optional)',
                      hintText: 'e.g. Invitation, Event, Blank',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tags,
                    validator: (v) =>
                        CatalogueService.maxLength(v, 'Tags', 300),
                    decoration: const InputDecoration(
                      labelText: 'Tags (comma separated)',
                      hintText: 'e.g. floral, wedding, festive',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _keywords,
                    validator: (v) =>
                        CatalogueService.maxLength(v, 'Keywords', 300),
                    decoration: const InputDecoration(
                      labelText: 'Keywords (comma separated)',
                      hintText: 'e.g. new year, gift, trending',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available in store'),
                    value: _availability,
                    onChanged: (v) => setState(() => _availability = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Trending collection'),
                    value: _isTrending,
                    onChanged: (v) => setState(() => _isTrending = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Customizable (text/photo/colour)'),
                    value: _supportsCustomization,
                    onChanged: (v) => setState(() => _supportsCustomization = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow artwork upload'),
                    value: _supportsUpload,
                    onChanged: (v) => setState(() => _supportsUpload = v),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving
                        ? 'Saving…'
                        : (_isEditing ? 'Save Changes' : 'Add Design')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Saved to the admin-managed design catalogue.',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
