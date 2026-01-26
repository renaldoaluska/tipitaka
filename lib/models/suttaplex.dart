class Translation {
  final String lang;
  final String authorUid;
  final String author;
  final String? publicationDate; //  TAMBAHIN: buat UI (tahun publikasi)
  final bool segmented; //  TAMBAHIN: buat tracking format
  final bool isRoot; //  TAMBAHIN: buat identify Pali root

  Translation({
    required this.lang,
    required this.authorUid,
    required this.author,
    this.publicationDate,
    this.segmented = false,
    this.isRoot = false,
  });

  factory Translation.fromJson(Map<String, dynamic> json) {
    return Translation(
      lang: json["lang"]?.toString() ?? "",
      authorUid: json["author_uid"]?.toString() ?? "", //  safer casting
      author: json["author"]?.toString() ?? "",
      publicationDate: json["publication_date"]?.toString(), //  nullable
      segmented: json["segmented"] == true, //  default false
      isRoot: json["is_root"] == true, //  default false
    );
  }

  ///  Helper: check data valid
  bool get isValid => lang.isNotEmpty && author.isNotEmpty;
}

class SuttaplexModel {
  final String uid;
  final String translatedTitle;
  final String originalTitle;
  final String blurb;
  final List<Translation> translations;
  final String? acronym; //  TAMBAHIN: untuk display (DN, MN, dll)

  SuttaplexModel({
    required this.uid,
    required this.translatedTitle,
    required this.originalTitle,
    required this.blurb,
    required this.translations,
    this.acronym,
  });

  factory SuttaplexModel.fromJson(Map<String, dynamic> json) {
    final trans = (json["translations"] as List? ?? [])
        .whereType<Map<String, dynamic>>() //  filter invalid items
        .map((t) => Translation.fromJson(t))
        .where((t) => t.isValid) //  filter invalid translations
        .toList();

    return SuttaplexModel(
      uid: json["uid"]?.toString() ?? "", //  safer casting
      translatedTitle: json["translated_title"]?.toString() ?? "",
      originalTitle: json["original_title"]?.toString() ?? "",
      blurb: json["blurb"]?.toString() ?? "",
      translations: trans,
      acronym: json["acronym"]?.toString(), //  nullable
    );
  }

  ///  Helper: check data valid
  bool get isValid => uid.isNotEmpty && translations.isNotEmpty;

  ///  Helper: get primary translation (fallback chain)
  Translation? getPrimaryTranslation({String preferredLang = "id"}) {
    try {
      return translations.firstWhere((t) => t.lang == preferredLang);
    } catch (e) {
      // Fallback ke yang pertama
      return translations.isNotEmpty ? translations.first : null;
    }
  }

  ///  Helper: check if pali root exists
  bool get hasPaliRoot => translations.any((t) => t.isRoot);
}
