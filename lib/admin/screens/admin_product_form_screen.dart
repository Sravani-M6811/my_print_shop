import 'package:flutter/material.dart';

import '../../frontend/data/product_catalog.dart';
import '../../frontend/models/product.dart';
import '../../frontend/models/product_variant.dart';
import '../services/catalogue_service.dart';
import '../widgets/catalogue_image_field.dart';

/// Add / edit a catalogue product.
///
/// Reuses the existing [Product] model and writes through a
/// [CatalogueRepository] so changes persist to Firestore (admin-only).
class AdminProductFormScreen extends StatefulWidget {
  final CatalogueRepository repository;

  /// When null the form creates a new product; otherwise it preloads and edits
  /// the given product.
  final Product? product;

  const AdminProductFormScreen({
    super.key,
    required this.repository,
    this.product,
  });

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _image;
  late final TextEditingController _subcategory;
  late final TextEditingController _material;
  late final TextEditingController _sizes;
  late final TextEditingController _tags;
  late final TextEditingController _measurements;
  late final TextEditingController _compatibleCategories;
  late final TextEditingController _compatibleProductIds;
  late final TextEditingController _keywords;

  late String _category;
  late String _productType;
  late String _designType;
  late bool _availability;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(text: p == null ? '' : _formatPrice(p.basePrice));
    _image = TextEditingController(text: p?.imagePath ?? '');
    _subcategory = TextEditingController(text: p?.subcategory ?? '');
    _material = TextEditingController(text: p?.material ?? '');
    _sizes = TextEditingController(text: (p?.availableSizes ?? const []).join(', '));
    _tags = TextEditingController(text: (p?.tags ?? const []).join(', '));
    _measurements = TextEditingController(
        text: (p?.measurements ?? const [])
            .map((e) => '${e.key}: ${e.value}')
            .join('\n'));
    _compatibleCategories =
        TextEditingController(text: (p?.compatibleCategories ?? const []).join(', '));
    _compatibleProductIds =
        TextEditingController(text: (p?.compatibleProductIds ?? const []).join(', '));
    _keywords = TextEditingController(text: (p?.keywords ?? const []).join(', '));

    _category = p?.category ?? ProductCatalog.categories.first;
    _productType = p?.productType ?? 'base';
    _designType = p?.designType ?? '';
    _availability = p?.availability ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _image.dispose();
    _subcategory.dispose();
    _material.dispose();
    _sizes.dispose();
    _tags.dispose();
    _measurements.dispose();
    _compatibleCategories.dispose();
    _compatibleProductIds.dispose();
    _keywords.dispose();
    super.dispose();
  }

  String _formatPrice(double price) =>
      price == price.roundToDouble() ? price.toInt().toString() : price.toString();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final product = _buildProduct();
      if (_isEditing) {
        await widget.repository.updateProduct(product);
      } else {
        await widget.repository.createProduct(product);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Product updated.' : 'Product added.')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save product. Check your connection and try again.')),
      );
    }
  }

  Product _buildProduct() {
    final sizes = _splitList(_sizes.text);
    final tags = _splitList(_tags.text);
    final variant = ProductVariant(
      label: _category,
      isColor: false,
    );
    final base = Product(
      id: _isEditing
          ? widget.product!.id
          : 'p_${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      category: _category,
      description: _description.text.trim(),
      basePrice: double.parse(_price.text.trim()),
      imagePath: _image.text.trim(),
      productType: _productType,
      subcategory: _subcategory.text.trim(),
      material: _material.text.trim().isEmpty ? null : _material.text.trim(),
      availableSizes: sizes,
      tags: tags,
      designType: _productType == 'design' ? _designType.trim() : '',
      availability: _availability,
      measurements: _parseMeasurements(_measurements.text),
      compatibleCategories: _splitList(_compatibleCategories.text),
      compatibleProductIds: _splitList(_compatibleProductIds.text),
      keywords: _splitList(_keywords.text),
    );
    // Preserve the original variant list on edits so colours are not lost.
    if (_isEditing && widget.product!.variants.isNotEmpty) {
      return base.copyWith(variants: widget.product!.variants);
    }
    return base.copyWith(
      variants: widget.product?.variants ?? [variant],
    );
  }

  /// Parses "Label: Value" lines (one per line) into the product's
  /// measurement/ dimension key-value list.
  static List<MapEntry<String, String>> _parseMeasurements(String text) {
    final entries = <MapEntry<String, String>>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      entries.add(MapEntry(
          key.length <= 40 ? key : key.substring(0, 40),
          value.length <= 80 ? value : value.substring(0, 80)));
    }
    return entries;
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

  @override
  Widget build(BuildContext context) {
    final designTypeVisible = _productType == 'design';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
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
                    validator: (v) => _fieldValidator(v, 'Product name', 120),
                    decoration: const InputDecoration(
                      labelText: 'Product name *',
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
                    onChanged: (v) =>
                        setState(() => _category = v ?? _category),
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _productType,
                    items: const [
                      DropdownMenuItem(value: 'base', child: Text('Base / Plain')),
                      DropdownMenuItem(value: 'design', child: Text('Design')),
                      DropdownMenuItem(
                          value: 'readyMade', child: Text('Ready-made')),
                    ],
                    onChanged: (v) =>
                        setState(() => _productType = v ?? _productType),
                    decoration: const InputDecoration(
                      labelText: 'Product type *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: CatalogueService.validatePrice,
                    decoration: const InputDecoration(
                      labelText: 'Price (₹) *',
                      prefixText: '₹ ',
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
                  if (designTypeVisible) ...[
                    DropdownButtonFormField<String>(
                      key: const ValueKey('designType'),
                      initialValue:
                          _designType.isEmpty ? null : _designType,
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
                  ],
                  TextFormField(
                    controller: _subcategory,
                    validator: (v) =>
                        CatalogueService.maxLength(v, 'Subcategory', 80),
                    decoration: const InputDecoration(
                      labelText: 'Subcategory (section/row)',
                      hintText: 'e.g. Silk Plain Sarees',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _material,
                    validator: (v) =>
                        CatalogueService.maxLength(v, 'Material', 80),
                    decoration: const InputDecoration(
                      labelText: 'Material (optional)',
                      hintText: 'e.g. 100% Cotton',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sizes,
                    validator: (v) =>
                        CatalogueService.maxLength(v, 'Sizes', 200),
                    decoration: const InputDecoration(
                      labelText: 'Sizes (comma separated)',
                      hintText: 'e.g. S, M, L, XL',
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
                    controller: _measurements,
                    maxLines: 3,
                    validator: (v) =>
                        CatalogueService.maxLength(v, 'Measurements', 500),
                    decoration: const InputDecoration(
                      labelText: 'Dimensions / Measurements',
                      hintText: 'One "Label: Value" per line\n'
                          'e.g. Length: 6 m\nWidth: 1.2 m',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _compatibleCategories,
                    validator: (v) => CatalogueService.maxLength(
                        v, 'Compatible categories', 400),
                    decoration: const InputDecoration(
                      labelText: 'Compatible categories (optional)',
                      hintText: 'e.g. Sarees, T-Shirts (comma separated)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
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
                    controller: _keywords,
                    validator: (v) =>
                        CatalogueService.maxLength(v, 'Keywords', 300),
                    decoration: const InputDecoration(
                      labelText: 'Keywords (comma separated)',
                      hintText: 'e.g. wedding, festive, new year',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available in store'),
                    subtitle: Text(
                      _availability
                          ? 'Customers can order this product.'
                          : 'Hidden from the storefront.',
                    ),
                    value: _availability,
                    onChanged: (v) => setState(() => _availability = v),
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
                        : (_isEditing ? 'Save Changes' : 'Add Product')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Saved to the admin-managed catalogue. Changes are '
                    'admin-only and appear in this panel.',
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
