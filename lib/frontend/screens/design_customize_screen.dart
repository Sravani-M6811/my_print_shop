import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/product_catalog.dart';
import '../models/product.dart';
import '../services/upload_service.dart';
import '../../ui/widgets/step_indicator.dart';
import 'order_preview_screen.dart';

/// The customization studio: pick a base design, upload a photo/logo, style
/// custom text, then add the finished item to the cart.
///
/// This is deliberately a *separate* screen from the Design gallery so the two
/// choices remain clearly distinct:
///   * Choose from our designs  -> pick a card in the gallery
///   * Upload your design       -> "Upload Your Design" -> this screen
///
/// It is opened either with a pre-selected [Product] (from the gallery) or
/// empty (from the upload flow). The upload picker is only shown when the user
/// explicitly taps the upload button — it is never auto-opened on entry.
class DesignCustomizeScreen extends StatefulWidget {
  final Product? product;

  /// The plain/base product (e.g. "Plain Saree") this design is printed on,
  /// when the flow started from Home's "Start With a Product". When set, the
  /// category is locked to the base product's category and the chosen base is
  /// remembered on the cart item alongside the design.
  final Product? baseProduct;

  /// The colour/variant label chosen for [baseProduct] (e.g. "Red", "Matte").
  /// Preserved on the cart item so the configuration survives to the order.
  final String? selectedVariant;

  /// The size chosen for [baseProduct] (e.g. 'L'), preserved through to the
  /// preview/cart/order.
  final String? selectedSize;

  final String title;

  /// The quantity chosen on the product detail screen, forwarded through to the
  /// preview so the configured quantity is never reset to 1.
  final int quantity;

  /// Optional starting value for the custom-text field (e.g. the "matter" a
  /// customer may already have entered on a dedicated template/matter screen).
  final String initialText;

  const DesignCustomizeScreen({
    super.key,
    this.product,
    this.baseProduct,
    this.selectedVariant,
    this.selectedSize,
    this.title = 'Customize Design',
    this.quantity = 1,
    this.initialText = '',
  });

  @override
  State<DesignCustomizeScreen> createState() => _DesignCustomizeScreenState();
}

class _DesignCustomizeScreenState extends State<DesignCustomizeScreen> {
  late TextEditingController _textController;
  Offset textPosition = const Offset(80, 80);
  String selectedFontFamily = 'Sans-Serif';
  late String selectedCategory;
  Color textColor = Colors.white;
  double fontSize = 20.0;
  bool isBold = true;
  Product? _selectedDesign;
  XFile? _uploadedImage;
  Uint8List? _uploadedImageBytes;
  final ImagePicker _picker = ImagePicker();
  late String _printPosition;
  String _stitching = 'With Stitching';

  final List<String> fontOptions = ['Sans-Serif', 'Serif', 'Monospace', 'Cursive'];
  final List<Color> colorOptions = [
    Colors.white, Colors.black, Colors.yellow, Colors.red, Colors.cyan, Colors.lightGreenAccent,
  ];

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.baseProduct?.category ??
        widget.product?.category ??
        ProductCatalog.categories.first;
    _textController =
        TextEditingController(text: widget.initialText.isNotEmpty ? widget.initialText : 'MY CUSTOM BRAND');
    _selectedDesign = widget.product;
    _printPosition = _defaultPrintPosition;
    _selectDefaultDesign();
  }

  /// The print positions offered for the selected plain product (fallback to
  /// the classic Front/Back for design-only flows). Produces category-aware
  /// choices without hard-coded UI conditions.
  List<String> get _printPositions {
    final source = widget.baseProduct ?? widget.product;
    final positions = source?.supportedPrintPositions ?? const [];
    if (positions.isNotEmpty) return positions;
    return const ['Front', 'Back', 'Both'];
  }

  String get _defaultPrintPosition {
    final positions = _printPositions;
    return positions.isNotEmpty ? positions.first : 'Front';
  }

  /// Whether the stitching option applies — Dress Materials are the printed
  /// product category that lets the customer keep the fabric unstitched and
  /// have it tailored separately. Data-driven on the base product's category.
  bool get _supportsStitching =>
      (widget.baseProduct?.category ?? selectedCategory) == 'Dress Materials';

  /// Whether the selected design is a template-driven record (e.g. a Cardboard
  /// template) whose custom-text field represents the "matter" printed on the
  /// product. Drives a clearer label so the enter-matter step of the Cardboard
  /// flow is not mistaken for generic custom text.
  bool get _isTemplateDriven =>
      (_selectedDesign?.templateType.isNotEmpty ?? false) ||
      ((widget.baseProduct?.category ?? selectedCategory) == 'Cardboard');

  /// The design gallery for the customize screen. When the flow is product-
  /// scoped (a base product was chosen), only designs compatible with that
  /// exact product are shown, so the customer can never select an incompatible
  /// artwork. Otherwise falls back to the category's designs.
  List<Product> get _compatibleDesigns {
    final base = widget.baseProduct;
    if (base != null) {
      return ProductCatalog.designsForBase(base);
    }
    return ProductCatalog.productsForCategory(selectedCategory);
  }

  void _selectDefaultDesign() {
    if (_selectedDesign != null) return;
    if (widget.baseProduct != null) {
      final designs = ProductCatalog.designsForBase(widget.baseProduct!);
      if (designs.isNotEmpty) _selectedDesign = designs.first;
      return;
    }
    final designs = ProductCatalog.productsForCategory(selectedCategory);
    if (designs.isNotEmpty) _selectedDesign = designs.first;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    // Read the bytes up-front so the preview can use Image.memory, which is
    // Web-safe (XFile.path on Web is a blob: URL that Image.network cannot
    // reliably load). The same bytes are later uploaded via UploadService.
    try {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _uploadedImage = image;
        _uploadedImageBytes = bytes;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected image.')),
      );
    }
  }

  /// Whether a design path is a remote URL (e.g. a live Pexels image) rather
  /// than a bundled asset; drives which Image widget renders it.
  bool _remote(String path) => path.startsWith('http');

  double _getCategoryPrice(String cat) {
    // The CTA must quote the price actually charged: when a plain/base product
    // drives the flow that is its base price; in the design-first flow it is
    // the base product resolved by _defaultBaseForCategory (the same product
    // passed into the order preview), not the selected design's price.
    if (widget.baseProduct != null) return widget.baseProduct!.basePrice;
    return _defaultBaseForCategory(cat)?.basePrice ?? 499.0;
  }

  /// "Color" for a real colour option, "Option" for finish/type choices.
  String get _variantLabel {
    final base = widget.baseProduct;
    if (base == null) return 'Variant';
    return ProductCatalog.variantFor(base, widget.selectedVariant)?.isColor ==
            true
        ? 'Color'
        : 'Option';
  }

  @override
  Widget build(BuildContext context) {
    final designs = _compatibleDesigns;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
        ),
      ),
      body: Column(
        children: [
          const StepIndicator(
            steps: ['Product', 'Design', 'Customize', 'Preview', 'Cart'],
            currentIndex: 2,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // ── Your Selection summary (product + design, base product flow) ──
            if (widget.baseProduct != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Selection',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6C5CE7)),
                    ),
                    const SizedBox(height: 8),
                    _ConfigRow(label: 'Product', value: widget.baseProduct!.name),
                    if (widget.selectedVariant != null &&
                        widget.selectedVariant!.isNotEmpty)
                      _ConfigRow(
                        label: _variantLabel,
                        value: widget.selectedVariant!,
                      ),
                    if (widget.selectedSize != null &&
                        widget.selectedSize!.isNotEmpty)
                      _ConfigRow(
                        label: 'Size',
                        value: widget.selectedSize!,
                      ),
                    if (widget.baseProduct!.material != null &&
                        widget.baseProduct!.material!.isNotEmpty)
                      _ConfigRow(
                        label: 'Material',
                        value: widget.baseProduct!.material!,
                      ),
                    _ConfigRow(
                        label: 'Design',
                        value: _selectedDesign?.name ?? '—'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Canvas
            Center(
              child: Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_selectedDesign != null)
                      _remote(_selectedDesign!.imagePath)
                          ? Image.network(
                              _selectedDesign!.imagePath,
                              width: 180,
                              height: 180,
                              fit: BoxFit.contain,
                              opacity: const AlwaysStoppedAnimation(0.3),
                              errorBuilder: (_, _, _) => Container(
                                width: 120,
                                height: 120,
                                color: Colors.grey.shade800,
                                child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.white38),
                              ),
                            )
                          : Image.asset(
                              _selectedDesign!.imagePath,
                              width: 180,
                              height: 180,
                              fit: BoxFit.contain,
                              opacity: const AlwaysStoppedAnimation(0.3),
                            ),
                    if (_uploadedImageBytes != null)
                      Positioned(
                        top: 30,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _uploadedImageBytes!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey.shade700,
                              child: const Icon(Icons.broken_image, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: textPosition.dx,
                      top: textPosition.dy,
                      child: GestureDetector(
                        onPanUpdate: (d) => setState(() => textPosition += d.delta),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blueAccent, width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _textController.text.isEmpty ? 'Your Text' : _textController.text,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                              fontFamily: selectedFontFamily,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Upload Button
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), foregroundColor: Colors.white),
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_a_photo, size: 18),
                    label: const Text('Upload Photo / Logo'),
                  ),
                ),
                if (_uploadedImage != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() {
                      _uploadedImage = null;
                      _uploadedImageBytes = null;
                    }),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Design Selection
            const Text('Select Design:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: designs.length,
                itemBuilder: (context, index) {
                  final design = designs[index];
                  final isSelected = _selectedDesign?.id == design.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDesign = design),
                      child: Container(
                        width: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF6C5CE7) : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: _remote(design.imagePath)
                              ? Image.network(
                                  design.imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: Theme.of(context).colorScheme.outlineVariant,
                                    child: const Icon(
                                        Icons.image_not_supported,
                                        size: 20),
                                  ),
                                )
                              : Image.asset(design.imagePath,
                                  fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Category (locked to the base product when one is selected)
            const Text('Category:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (widget.baseProduct != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  widget.baseProduct!.name,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6C5CE7), fontWeight: FontWeight.w600),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ProductCatalog.categories.map((cat) {
                    final isSelected = selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(cat, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onSelected: (v) {
                          if (v) {
                            setState(() {
                              selectedCategory = cat;
                              _selectDefaultDesign();
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 12),

            // Font Selection
            const Text('Font Style:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: fontOptions.length,
                itemBuilder: (context, index) {
                  final font = fontOptions[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(font, style: const TextStyle(fontSize: 12)),
                      selected: font == selectedFontFamily,
                      onSelected: (s) {
                        if (s) setState(() => selectedFontFamily = font);
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Custom Text
            TextField(
              controller: _textController,
              onChanged: (v) => setState(() {}),
              decoration: InputDecoration(
                labelText: _isTemplateDriven ? 'Matter / Text Content' : 'Custom Text',
                hintText: _isTemplateDriven
                    ? 'Enter the matter to print on your board'
                    : null,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.edit_note),
              ),
            ),

            const SizedBox(height: 12),

            // Text Color
            const Text('Text Color:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: colorOptions.map((color) {
                return GestureDetector(
                  onTap: () => setState(() => textColor = color),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: textColor == color ? const Color(0xFF6C5CE7) : Colors.grey,
                        width: textColor == color ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Font Size + Bold
            Row(
              children: [
                const Text('Size: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Slider(
                    value: fontSize,
                    min: 12.0,
                    max: 36.0,
                    activeColor: const Color(0xFF6C5CE7),
                    onChanged: (v) => setState(() => fontSize = v),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.format_bold, color: isBold ? const Color(0xFF6C5CE7) : Colors.grey),
                  onPressed: () => setState(() => isBold = !isBold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Print position (product/category aware)
            const Text('Print Position:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _printPositions.map((pos) {
                final isSelected = _printPosition == pos;
                return ChoiceChip(
                  label: Text(pos, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (v) {
                    if (v) setState(() => _printPosition = pos);
                  },
                );
              }).toList(),
            ),
            if (widget.baseProduct != null) ...[
              const SizedBox(height: 4),
              Text(
                'Position will vary with your selected product.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],

            if (_supportsStitching) ...[
              const SizedBox(height: 16),
              const Text('Stitching:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const ['With Stitching', 'Without Stitching']
                    .map((option) {
                  final isSelected = _stitching == option;
                  return ChoiceChip(
                    label: Text(option, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (v) {
                      if (v) setState(() => _stitching = option);
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            // Continue to Preview
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.preview),
                label: Text(
                  _selectedDesign != null || _uploadedImage != null
                      ? 'Continue to Preview (₹${widget.baseProduct?.basePrice.toInt() ?? _getCategoryPrice(selectedCategory).toInt()})'
                      : 'Choose a Design or Upload to Continue',
                  style: const TextStyle(fontSize: 15),
                ),
                onPressed: (_selectedDesign != null || _uploadedImage != null)
                    ? () async {
                        final imagePath =
                            await UploadService().prepareDesignPath(_uploadedImage);
                        if (!context.mounted) return;
                        final base =
                            widget.baseProduct ?? _defaultBaseForCategory(selectedCategory);
                        if (base == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No base product is available for this category.'),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrderPreviewScreen(
                              baseProduct: base,
                              selectedVariant: widget.selectedVariant,
                              selectedSize: widget.selectedSize,
                              design: _selectedDesign,
                              uploadedImagePath: imagePath.isNotEmpty
                                  ? imagePath
                                  : null,
                              customText: _textController.text,
                              fontFamily: selectedFontFamily,
                              printPosition: _printPosition,
                              stitching:
                                  _supportsStitching ? _stitching : null,
                              quantity: widget.quantity,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  /// When the flow is opened without an explicit base product (e.g. direct
  /// design customization), derive a compatible base product for the design's
  /// category so the preview still renders a concrete product.
  Product? _defaultBaseForCategory(String category) {
    return ProductCatalog.baseProductForCategory(category) ??
        ProductCatalog.baseProducts.firstOrNull;
  }
}

class _ConfigRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConfigRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(width: 12),
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
