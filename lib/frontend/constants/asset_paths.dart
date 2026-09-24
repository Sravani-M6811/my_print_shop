class AssetPaths {
  AssetPaths._();

  static const String appLogo = 'assets/images/icon/app_logo.png';
  static const String banner = 'assets/images/banner.jpg';

  static const String saree1 = 'assets/images/saree1.jpg';
  static const String saree2 = 'assets/images/saree2.jpg';
  static const String saree3 = 'assets/images/saree3.jpg';
  static const String dress1 = 'assets/images/products/dress_materials/plain_cotton_dress_material.jpg';
  static const String dress2 = 'assets/images/dress2.jpg';
  static const String dress3 = 'assets/images/dress3.jpg';
  static const String border1 = 'assets/images/border1.jpg';
  static const String border2 = 'assets/images/border2.jpg';
  static const String border3 = 'assets/images/border3.jpg';
  static const String tshirt1 = 'assets/images/tshirt1.jpg';
  static const String tshirt2 = 'assets/images/tshirt2.jpg';
  static const String tshirt3 = 'assets/images/tshirt3.jpg';
  static const String mug1 = 'assets/images/mug1.jpg';
  static const String mug2 = 'assets/images/mug2.jpg';
  static const String mug3 = 'assets/images/mug3.jpg';
  static const String poster1 = 'assets/images/poster1.jpg';
  static const String poster2 = 'assets/images/poster2.jpg';
  static const String embroidery1 = 'assets/images/embroidery1.jpg';
  static const String embroidery2 = 'assets/images/embroidery2.jpg';

  // Cardboard standups / cutouts shown as category product photos.
  static const String cardboard1 =
      '${cardboardFolder}cardboard_0002.jpg';
  static const String cardboard2 =
      '${cardboardFolder}cardboard_0003.jpg';
  static const String cardboard3 =
      '${cardboardFolder}cardboard_0004.jpg';

  // Glass Art (hand-art / decorative / printed / custom glass artwork)
  // category product photos.
  static const String glassArt1 = '${glassFolder}glass_design_0001.jpg';
  static const String glassArt2 = '${glassFolder}glass_design_0002.jpg';
  static const String glassArt3 = '${glassFolder}glass_design_0003.jpg';

  // ── Structured product image folders (one per category) ──
  // A clean, scalable layout: assets/images/products/<category>/. Every path
  // below points at a real bundled file (copied from the existing collection),
  // so no asset is ever silently broken. Adding many more product photos later
  // is just dropping files into the matching folder and adding a constant.
  static const String sareeFolder =
      'assets/images/products/sarees/';
  static const String borderFolder =
      'assets/images/products/borders/';
  static const String tshirtFolder =
      'assets/images/products/tshirts/';
  static const String mugFolder = 'assets/images/products/mugs/';
  static const String posterFolder =
      'assets/images/products/posters/';
  static const String embroideryFolder =
      'assets/images/products/embroidery/';
  static const String cardboardFolder =
      'assets/images/products/cardboard/';
  static const String glassFolder =
      'assets/images/products/glass_art/';
  static const String designsFolder = 'assets/images/designs/';

  // ── Plain / base product folders ──
  // The CUSTOM PRINT SHOP concept lives on plain, blank base products that are
  // ready for a design to be applied. These folders hold the "blank product"
  // photography, kept visually distinct from the reusable design artwork in
  // [designsFolder] / the *_Prod category images above.
  static const String plainSareeFolder =
      'assets/images/products/plain/sarees/';
  static const String plainBorderFolder =
      'assets/images/products/plain/borders/';
  static const String plainTshirtFolder =
      'assets/images/products/plain/tshirts/';
  static const String plainMugFolder =
      'assets/images/products/plain/mugs/';
  static const String plainPosterFolder =
      'assets/images/products/plain/posters/';
  static const String plainEmbroideryFolder =
      'assets/images/products/plain/embroidery/';
  static const String plainCardboardFolder =
      'assets/images/products/plain/cardboard/';
  static const String plainGlassFolder =
      'assets/images/products/plain/glass_art/';

  // Concrete plain/base product images (real, bundled assets).
  static const String plainSilkSaree = '${plainSareeFolder}plain_silk.jpg';
  static const String plainGeorgetteSaree = '${plainSareeFolder}plain_georgette.jpg';
  static const String plainCottonSaree = '${plainSareeFolder}plain_cotton.jpg';

  static const String plainZariBorder = '${plainBorderFolder}plain_zari.jpg';
  static const String plainContrastBorder = '${plainBorderFolder}plain_contrast.jpg';
  static const String plainMirrorBorder = '${plainBorderFolder}plain_mirror.jpg';

  static const String plainCottonTshirt = '${plainTshirtFolder}plain_cotton.jpg';
  static const String plainOversizedTshirt = '${plainTshirtFolder}plain_oversized.jpg';
  static const String plainPoloTshirt = '${plainTshirtFolder}plain_polo.jpg';

  static const String plainCeramicMug = '${plainMugFolder}plain_ceramic.jpg';
  static const String plainMagicMug = '${plainMugFolder}plain_magic.jpg';
  static const String plainTravelMug = '${plainMugFolder}plain_travel.jpg';

  static const String blankPoster = '${plainPosterFolder}blank_poster.jpg';
  static const String blankCanvasPoster = '${plainPosterFolder}blank_canvas.jpg';

  static const String plainFabricBase = '${plainEmbroideryFolder}plain_fabric1.jpg';
  static const String plainFabricBase2 = '${plainEmbroideryFolder}plain_fabric2.jpg';

  static const String blankCardboardBoard = '${cardboardFolder}blank_standee.jpg';
  static const String blankCardboardStandee = '${plainCardboardFolder}blank_standee.jpg';

  static const String plainGlassPanel = '${glassFolder}plain_glass.jpg';
  static const String plainGlassFrame = '${plainGlassFolder}plain_frame.jpg';

  // Representative product image for each category's professional card.
  static const String sareeProd = '${sareeFolder}plain_maroon_silk_saree.jpg';
  static const String borderProd = '${borderFolder}border1.jpg';
  static const String tshirtProd = '${tshirtFolder}plain_t_shirt.jpg';
  static const String mugProd = '${mugFolder}plain_mug.jpg';
  static const String posterProd = '${posterFolder}plain_poster.jpg';
  static const String embroideryProd = '${embroideryFolder}plain_embroidery_base.jpg';
  static const String cardboardProd = '${cardboardFolder}cardboard_0002.jpg';
  static const String glassProd = '${glassFolder}glass_design_0001.jpg';
  static const String dressProd = dress1;

  static String productImageForCategory(String category, {int index = 0}) {
    switch (category) {
      case 'Sarees':
      case 'Saree':
        return [saree1, saree2, saree3][index % 3];
      case 'Dress Materials':
        return [dress1, dress2, dress3][index % 3];
      case 'Saree Borders':
        return [border1, border2, border3][index % 3];
      case 'T-Shirts':
      case 'T-Shirt':
        return [tshirt1, tshirt2, tshirt3][index % 3];
      case 'Mugs':
      case 'Mug':
        return [mug1, mug2, mug3][index % 3];
      case 'Posters':
        return [poster1, poster2][index % 2];
      case 'Embroidery':
        return [embroidery1, embroidery2][index % 2];
      case 'Cardboard':
        return [cardboard1, cardboard2, cardboard3][index % 3];
      case 'Glass Art':
        return [glassArt1, glassArt2, glassArt3][index % 3];
      default:
        return tshirt1;
    }
  }
}