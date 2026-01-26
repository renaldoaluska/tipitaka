class SegmentedSutta {
  final String uid;
  final String lang;
  final Map<String, String> segments;

  SegmentedSutta({
    required this.uid,
    required this.lang,
    required this.segments,
  });

  factory SegmentedSutta.fromJson(Map<String, dynamic> json) {
    Map<String, String> segs = {};

    //  Service sudah flatten ke "segments"
    if (json.containsKey("segments") && json["segments"] is Map) {
      segs = Map<String, String>.from(
        json["segments"] as Map<String, dynamic>,
      ).map((k, v) => MapEntry(k, v.toString())); // ← safer casting
    }

    return SegmentedSutta(
      uid: json["uid"]?.toString() ?? "", // ← safer
      lang: json["lang"]?.toString() ?? "", // ← safer
      segments: segs,
    );
  }

  /// Gabung semua segmen jadi teks rapi
  String get fullText => segments.values.join("\n\n");

  ///  Helper: cek apakah data valid
  bool get isValid => uid.isNotEmpty && segments.isNotEmpty;
}

class NonSegmentedSutta {
  final String uid;
  final String lang;
  final String text;

  NonSegmentedSutta({
    required this.uid,
    required this.lang,
    required this.text,
  });

  factory NonSegmentedSutta.fromJson(Map<String, dynamic> json) {
    return NonSegmentedSutta(
      uid: json["uid"]?.toString() ?? "", // ← safer
      lang: json["lang"]?.toString() ?? "", // ← safer
      text: json["text"]?.toString() ?? "", // ← safer (HTML bisa object)
    );
  }

  ///  Helper: cek apakah data valid
  bool get isValid => uid.isNotEmpty && text.isNotEmpty;
}
