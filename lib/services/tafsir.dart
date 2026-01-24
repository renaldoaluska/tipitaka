import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

enum TafsirType { mul, att, tik }

// di tempat lu manggil TafsirService
Future<String?> loadTafsir(String uid, TafsirType type) async {
  // compute bakal jalanin fungsi di thread terpisah biar UI lu tetep 60fps
  return await compute(_processTafsirTask, {'uid': uid, 'type': type});
}

// fungsi top-level (di luar class) buat compute
Future<String?> _processTafsirTask(Map<String, dynamic> params) async {
  final service = TafsirService();
  return await service.getContent2(params['uid'], type: params['type']);
}

class TafsirService {
  // 3. PETA STRUKTUR VAGGA
  static const Map<int, List<int>> _snStructure = {
    1: [10, 10, 10, 10, 10, 10, 10, 11],
    2: [10, 10, 10],
    3: [10, 10, 5],
    4: [10, 10, 5],
    5: [10],
    6: [10, 5],
    7: [10, 12],
    8: [12],
    9: [14],
    10: [12],
    11: [10, 10, 5],
    12: [10, 10, 10, 10, 10, 10, 10, 11, 11, 121],
    13: [11],
    14: [10, 12, 7, 10],
    15: [10, 10],
    16: [13],
    17: [10, 10, 10, 13],
    18: [10, 12],
    19: [10, 11],
    20: [12],
    21: [12],
    22: [11, 10, 11, 10, 10, 10, 10, 10, 10, 10, 10, 13, 10, 14, 10],
    23: [10, 12, 12, 12],
    24: [18, 26, 26, 26],
    25: [10],
    26: [10],
    27: [10],
    28: [10],
    // 29: [10, 40],
    29: [50],
    30: [46],
    31: [112],
    32: [57],
    33: [55],
    34: [55],
    35: [
      12,
      10,
      10,
      10,
      10,
      10,
      11,
      10,
      10,
      10,
      10,
      10,
      10,
      12,
      10,
      12,
      60,
      10,
      11,
    ],
    36: [10, 10, 11],
    37: [14, 10, 10],
    38: [16],
    39: [16],
    40: [11],
    41: [10],
    42: [13],
    43: [11, 33],
    44: [11],
    45: [10, 10, 10, 10, 8, 14, 14, 14, 12, 36, 10, 12, 10, 10],
    46: [10, 10, 10, 10, 10, 6, 10, 10, 12, 10, 12, 10, 10, 12, 10, 12, 10, 10],
    47: [10, 10, 10, 10, 10, 12, 10, 12, 10, 10],
    48: [10, 10, 10, 10, 10, 10, 10, 12, 10, 12, 10, 10, 12, 10, 12, 10, 10],
    49: [12, 10, 12, 10, 10],
    50: [12, 10, 12, 10, 10, 12, 10, 12, 10, 10],
    51: [10, 10, 12, 12, 10, 12, 10, 10],
    52: [10, 14],
    53: [12, 10, 12, 10, 10],
    54: [10, 10],
    55: [10, 10, 10, 10, 10, 11, 13],
    56: [10, 10, 10, 10, 10, 10, 10, 10, 10, 11, 30],
  };

  /* static const Map<int, List<List<(int, String)>>> _anStructure = {
    1: [
      [
        (10, "Cittapariyādāna"), (10, "Nīvaraṇa"), (10, "Akammaniya"),
        (10, "Adanta"), (10, "Paṇihita"), (10, "Accharā"),
        (10, "Vīriyārambha"), (10, "Kalyāṇamitta"), (16, "Pamāda"),
        (42, "Dutiyapamāda"), (10, "Adhamma"), (20, "Anāpatti"),
        (19, "Ekapuggala"), // ðŸ”¥ Naikin jadi 19 biar totalnya 187
        (80, "Etadagga"),
        (28, "Aṭṭhāna"),
        (52, "Ekadhamma"),
        (16, "Pasādakara"),
        (181, "Aparaaccharā"),
        (41, "Kāyagatāsati"),
        (12, "Amata"),
        (30, "Muṇḍarāja"),
      ],
    ],
    2: [
      // Paṭhamapaṇṇāsakaṃ - Total 52 Sutta
      [
        (10, "Kammakaraṇa"),
        (11, "Adhikaraṇa"),
        (11, "Bāla"),
        (10, "Samacitta"),
        (10, "Parisa"),
      ],

      // Dutiyapaṇṇāsakaṃ - Total 66 Sutta (V6 - V10)
      [
        (12, "Puggala"),
        (13, "Sukha"),
        (10, "Sanimitta"),
        (11, "Dhamma"),
        (20, "Bāla"),
      ],

      // Tatiyapaṇṇāsakaṃ - Total 62 Sutta (V11 - V15)
      // Perhatikan Vagga 15 (Samāpatti) gue set 17 biar pas sampe nomor 180
      [
        (12, "Āsāduppajaha"),
        (11, "Āyācana"),
        (10, "Dāna"),
        (12, "Santhāra"),
        (17, "Samāpatti"),
      ],

      [(50, "Kodhapeyyāla")], // 181-230
      [(50, "Akusalapeyyāla")], // 231-280
      [(30, "Vinayapeyyāla")], // 281-310
      [(318, "Ragapeyyāla")], // 311-627 (buffer sisa)
      // Bagian Peyyāla - Kodha dimulai dari VRI 181
      // [(10, "Kodhapeyyāla")], // ID: an2_4 (Sesuai mapping lu 181-190)
      // [(10, "Akusalapeyyāla")], // ID: an2_5 (191-200)
      ///  [(30, "Vinayapeyyāla")], // ID: an2_6 (201-230)
      //   [(16, "Rāgapeyyāla")], // ID: an2_7 (231-246)
      //   [(92, "Sabbatthaka")], // ID: an2_8
      //   [(10, "Naya")],
      //   [(184, "Peyyāla")],
    ],
    3: [
      [
        (10, "Bāla"),
        (10, "Rathakāra"),
        (10, "Puggala"),
        (10, "Devadūta"),
        (10, "Cūḷa"),
      ],
      [
        (10, "Brāhmaṇa"),
        (10, "Mahā"),
        (10, "Ānanda"),
        (11, "Samaṇa"),
        (11, "Loṇakapalla"),
      ],
      [
        (10, "Sambodha"),
        (10, "Āpāyika"),
        (10, "Kusināra"),
        (13, "Yodhājīva"),
        (10, "Maṅgala"),
        (7, "Acelaka"), (20, "Kammapatha"), // ðŸ‘ˆ TAMBAHIN INI (163-182 VRI)
        (2, "Rāga"),
      ],
    ],
    4: [
      [
        (10, "Bhaṇḍagāma"),
        (10, "Cara"),
        (10, "Uruvela"),
        (10, "Cakka"),
        (10, "Rohitassa"),
      ],
      [
        (10, "Puññābhisanda"),
        (10, "Pattakamma"),
        (10, "Apaṇṇaka"),
        (10, "Macala"),
        (10, "Asura"),
      ],
      [
        (10, "Valāhaka"),
        (10, "Kesi"),
        (10, "Bhaya"),
        (10, "Puggala"),
        (10, "Ābhā"),
      ],
      [
        (10, "Indriya"),
        (10, "Paṭipadā"),
        (10, "Sañcetaniya"),
        (10, "Brāhmaṇa"),
        (10, "Mahā"),
      ],
      [
        (10, "Sappurisa"),
        (10, "Parisā"),
        (11, "Duccarita"),
        (11, "Kamma"),
        (11, "Āpattibhaya"),
        (10, "Abhiññā"),
        (10, "Kammapatha"),
      ],
    ],
    5: [
      [
        (10, "Sekhabala"),
        (10, "Bala"),
        (10, "Pañcaṅgika"),
        (10, "Sumana"),
        (10, "Muṇḍarāja"),
      ],
      [
        (10, "Nīvaraṇa"),
        (10, "Saññā"),
        (10, "Yodhājīva"),
        (10, "Thera"),
        (10, "Kakudha"),
      ],
      [
        (10, "Phāsuvihāra"),
        (10, "Andhakavinda"),
        (10, "Gilāna"),
        (10, "Rāja"),
        (10, "Tikaṇḍakī"),
      ],
      [
        (10, "Saddhamma"),
        (10, "Āghāta"),
        (10, "Upāsaka"),
        (10, "Arañña"),
        (10, "Brāhmaṇa"),
      ],
      [
        (10, "Kimila"),
        (10, "Akkosaka"),
        (10, "Dīghacārika"),
        (10, "Āvāsa"),
        (10, "Duccarita"),
      ],
      [(11, "Upasampadā")],
    ],
    6: [
      [
        (10, "Āhuneyya"),
        (10, "Sāraṇīya"),
        (10, "Anuttariya"),
        (10, "Devatā"),
        (10, "Dhammika"),
      ],
      [
        (10, "Mahā"),
        (10, "Devatā"),
        (10, "Arahatta"),
        (10, "Sīti"),
        (10, "Ānisaṃsa"),
      ],
      [(10, "Tika"), (12, "Sāmañña")],
    ],
    7: [
      [
        (10, "Dhana"),
        (10, "Anusaya"),
        (10, "Vajjisattaka"),
        (10, "Devatā"),
        (10, "Mahāyañña"),
      ],
      [
        (10, "Abyākata"),
        (10, "Mahā"),
        (10, "Vinaya"),
        (10, "Samaṇa"),
        (10, "Āhuneyya"),
      ],
    ],
    8: [
      [
        (10, "Mettā"),
        (10, "Mahā"),
        (10, "Gahapati"),
        (10, "Dāna"),
        (10, "Uposatha"),
      ],
      [
        (10, "Gotamī"),
        (10, "Bhūmicāla"),
        (10, "Yamaka"),
        (10, "Sati"),
        (10, "Sāmañña"),
      ],
    ],
    9: [
      [
        (10, "Sambodhi"),
        (10, "Sīhanāda"),
        (10, "Sattāvāsa"),
        (10, "Mahā"),
        (10, "Sāmañña"),
      ],
      [
        (10, "Khemā"),
        (10, "Satipaṭṭhāna"),
        (10, "Sammappadhāna"),
        (10, "Iddhipāda"),
      ],
    ],
    10: [
      [
        (10, "Ānisaṃsa"),
        (10, "Nātha"),
        (10, "Mahā"),
        (10, "Upāli"),
        (10, "Akkosa"),
      ],
      [
        (10, "Sacitta"),
        (10, "Yamaka"),
        (10, "Ākaṅkha"),
        (10, "Thera"),
        (10, "Upāsaka"),
      ],
      [
        (10, "Samaṇasaññā"),
        (10, "Paccorohaṇī"),
        (10, "Parisuddha"),
        (10, "Sādhu"),
        (10, "Ariya"),
      ],
      [
        (10, "Puggala"),
        (10, "Jāṇussoṇi"),
        (10, "Sādhu"),
        (10, "Ariya"),
        (10, "Puggala"),
      ],
      [(10, "Karajakāya"), (10, "Sāmañña")],
    ],
    11: [
      [(10, "Nissaya"), (11, "Anussati"), (49, "Sāmañña")],
    ],
  };
*/

  static const Map<int, List<List<(int, String)>>> _anStructure = {
    1: [
      [
        (10, "Cittapariyādāna"),
        (10, "Nīvaraṇa"),
        (10, "Akammaniya"),
        (10, "Adanta"),
        (10, "Paṇihita"),
        (10, "Accharā"),
        (10, "Vīriyārambha"),
        (11, "Kalyāṇamitta"),
        (16, "Pamāda"),
        (42, "Dutiyapamāda"),
        (10, "Adhamma"),
        (20, "Anāpatti"),
        (18, "Ekapuggala"),
        (80, "Etadagga"),
        (28, "Aṭṭhāna"),
        (82, "Ekadhamma"),
        (16, "Pasādakara"),
        (181, "Aparaaccharā"),
        (41, "Kāyagatāsati"),
        (12, "Amata"),
      ],
    ],
    2: [
      [
        (10, "Kammakaraṇa"),
        (10, "Adhikaraṇa"),
        (11, "Bāla"),
        (10, "Samacitta"),
        (10, "Parisa"),
      ], // P1
      [
        (12, "Puggala"),
        (13, "Sukha"),
        (10, "Sanimitta"),
        (11, "Dhamma"),
        (20, "Bāla"),
      ], // P2
      [
        (12, "Āsāduppajaha"),
        (11, "Āyācana"),
        (10, "Dāna"),
        (12, "Santhāra"),
        (17, "Samāpatti"),
      ], // P3
      [
        (50, "Kodhapeyyāla"),
        (50, "Akusalapeyyāla"),
        (30, "Vinayapeyyāla"),
        (170, "Rāgapeyyāla"),
      ], // Peyyala
    ],
    3: [
      [
        (10, "Bāla"),
        (10, "Rathakāra"),
        (10, "Puggala"),
        (10, "Devadūta"),
        (10, "Cūḷa"), //ini 11 karena tampungan 2 dijadiin 1
      ], // P1
      [
        (10, "Brāhmaṇa"),
        (10, "Mahā"),
        (10, "Ānanda"),
        (11, "Samaṇa"),
        (11, "Loṇakapalla"),
      ], // P2
      [
        (10, "Sambodha"),
        (10, "Āpāyika"),
        (10, "Kusināra"),
        (13, "Yodhājīva"),
        (10, "Maṅgala"),
        (7, "Patipadā"),
        (20, "Kammapatha"),
        (170, "Rāgadipeyyāla"),
      ], // P3
    ],
    4: [
      [
        (10, "Bhaṇḍagāma"),
        (10, "Cara"),
        (10, "Uruvela"),
        (10, "Cakka"),
        (10, "Rohitassa"),
      ], // P1
      [
        (10, "Puññābhisanda"),
        (10, "Pattakamma"),
        (10, "Apaṇṇaka"),
        (10, "Macala"),
        (10, "Asura"),
      ], // P2
      [
        (10, "Valāhaka"),
        (10, "Kesi"),
        (10, "Bhaya"),
        (10, "Puggala"),
        (10, "Ābhā"),
      ], // P3
      [
        (10, "Indriya"),
        (10, "Paṭipadā"),
        (10, "Sañcetaniya"),
        (10, "Brāhmaṇa"),
        (10, "Mahā"),
      ], // P4
      [
        (10, "Sappurisa"),
        (10, "Parisā"),
        (11, "Duccarita"),
        (11, "Kamma"),
        (11, "Āpattibhaya"),
        (10, "Abhiññā"),
        (10, "Kammapatha"),
        (510, "Rāgapeyyāla"),
      ], // P5
    ],
    5: [
      [
        (10, "Sekhabala"),
        (10, "Bala"),
        (10, "Pañcaṅgika"),
        (10, "Sumana"),
        (10, "Muṇḍarāja"),
      ], // P1
      [
        (10, "Nīvaraṇa"),
        (10, "Saññā"),
        (10, "Yodhājīva"),
        (10, "Thera"),
        (10, "Kakudha"),
      ], // P2
      [
        (10, "Phāsuvihāra"),
        (10, "Andhakavinda"),
        (10, "Gilāna"),
        (10, "Rāja"),
        (10, "Tikaṇḍakī"),
      ], // P3
      [
        (10, "Saddhamma"),
        (10, "Āghāta"),
        (10, "Upāsaka"),
        (10, "Arañña"),
        (10, "Brāhmaṇa"),
      ], // P4
      [
        (10, "Kimila"),
        (10, "Akkosaka"),
        (10, "Dīghacārika"),
        (10, "Āvāsa"),
        (10, "Duccarita"),
      ], // P5
      [
        (21, "Upasampadā"),
        (14, "Sammutipeyyāla"),
        (17, "Sikkhāpadapeyyāla"),
        (850, "Rāgapeyyāla"),
      ], // P6
    ],
    6: [
      [
        (10, "Āhuneyya"),
        (10, "Sāraṇīya"),
        (10, "Anuttariya"),
        (12, "Devatā"),
        (12, "Dhammika"),
      ], // P1
      [
        (10, "Mahā"),
        (10, "Devatā"),
        (10, "Arahatta"),
        (11, "Sīti"),
        (11, "Ānisaṃsa"),
      ], // P2
      [
        (10, "Tika"),
        (23, "Sāmañña"),
        (510, "Rāgapeyyāla"),
      ], // P3 (Samañña 117-139)
    ],
    7: [
      [
        (10, "Dhana"),
        (10, "Anusaya"),
        (11, "Vajjisattaka"),
        (12, "Devatā"),
        (10, "Mahāyañña"),
      ], // P1
      [
        (11, "Abyākata"),
        (10, "Mahā"),
        (10, "Vinaya"),
        (10, "Samaṇa"),
        (520, "Āhuneyya"),
        (510, "Rāgapeyyāla"),
      ], // P2
    ],
    8: [
      [
        (10, "Mettā"),
        (10, "Mahā"),
        (10, "Gahapati"),
        (10, "Dāna"),
        (10, "Uposatha"),
      ], // P1
      [
        (10, "Gotamī"),
        (10, "Bhūmicāla"),
        (10, "Yamaka"),
        (10, "Sati"),
        (27, "Sāmañña"),
        (510, "Rāgapeyyāla"),
      ], // P2
    ],
    9: [
      [
        (10, "Sambodhi"),
        (10, "Sīhanāda"),
        (11, "Sattāvāsa"),
        (10, "Mahā"),
        (10, "Sāmañña"),
      ], // P1
      [
        (11, "Khemā"),
        (10, "Satipaṭṭhāna"),
        (10, "Sammappadhāna"),
        (10, "Iddhipāda"),
        (340, "Rāgapeyyāla"),
      ], // P2
    ],
    10: [
      [
        (10, "Ānisaṃsa"),
        (10, "Nātha"),
        (10, "Mahā"),
        (10, "Upāli"),
        (10, "Akkosa"),
      ], // P1
      [
        (10, "Sacitta"),
        (10, "Yamaka"),
        (10, "Ākaṅkha"),
        (10, "Thera"),
        (10, "Upāli"),
      ], // P2
      [
        (12, "Samaṇasaññā"),
        (10, "Paccorohaṇī"),
        (11, "Parisuddha"),
        (11, "Sādhu"),
        (10, "Ariya"),
      ], // P3
      [
        (12, "Puggala"),
        (11, "Jāṇussoṇi"),
        (11, "Sādhu"),
        (10, "Ariyamagga"),
        (12, "Ariyapuggala"),
      ], // P4
      [(10, "Karajakāya"), (16, "Sāmañña"), (510, "Rāgapeyyāla")], // P5
    ],
    11: [
      [
        (10, "Nissaya"),
        (11, "Anussati"),
        (960, "Sāmañña"),
        (170, "Rāgapeyyāla"),
      ], // P1
    ],
  };

  final Dio _dio = Dio();

  static const String _baseUrl =
      "https://raw.githubusercontent.com/renaldoaluska/tipitaka-xml/main/romn";

  // 🔥 1. VARIABEL BARU: Simpan data XML di RAM
  static final Map<String, String> _ramCache = {};

  // Dipanggil sekali seumur hidup via main.dart
  static Future<void> deleteOldOfflineFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Cek: Apakah misi penghancuran sudah pernah dilakukan?
      // Kita pakai key 'legacy_files_deleted' biar jelas.
      final bool alreadyDeleted =
          prefs.getBool('legacy_files_deleted') ?? false;

      if (alreadyDeleted) {
        return; // Misi selesai, gak perlu cek-cek file lagi. Hemat CPU.
      }

      // 2. Target Lokasi: Folder Dokumen (Tempat file offline lama bersarang)
      final dir = await getApplicationDocumentsDirectory();

      // List semua file di situ
      if (dir.existsSync()) {
        final List<FileSystemEntity> files = dir.listSync();

        int deletedCount = 0;
        for (var file in files) {
          // Hapus cuma file .xml (Kitab yang terlanjur didownload user)
          if (file is File && file.path.endsWith('.xml')) {
            try {
              await file.delete();
              deletedCount++;
            } catch (e) {
              debugPrint("Gagal hapus file ${file.path}: $e");
            }
          }
        }

        if (deletedCount > 0) {
          debugPrint(
            "🗑️ CLEANUP: Berhasil menghapus $deletedCount file kitab offline lama dari Storage.",
          );
        }
      }

      // 3. TANDAIN MISI SELESAI
      // Besok-besok pas user buka app, fungsi ini langsung stop di langkah no. 1
      await prefs.setBool('legacy_files_deleted', true);
    } catch (e) {
      debugPrint("Gagal menjalankan cleanup: $e");
    }
  }

  Future<String?> getContent2(String uid, {required TafsirType type}) async {
    // 1. Logic Nama File (Sama persis kayak kode lu)
    final mapping = _calculateMapping(uid);
    final String bookCode = mapping['code'] ?? "";
    final String suttaNum = mapping['num'] ?? "";
    final String mulPart = mapping['mulPart'] ?? "";
    final String part = mapping['part'] ?? "";

    if (bookCode.isEmpty) return null;

    String fileName;
    switch (type) {
      case TafsirType.mul:
        if (bookCode.startsWith("s040") && mulPart.isNotEmpty) {
          fileName = "${bookCode}m$mulPart.mul.xml";
        } else if (bookCode == "s0518") {
          fileName = "${bookCode}m.nrf.xml";
        } else if (bookCode == "s0510") {
          fileName = "${bookCode}m$part.mul.xml";
        } else {
          fileName = "${bookCode}m.mul.xml";
        }
        break;

      case TafsirType.att:
        if (bookCode.startsWith("s040")) {
          fileName = "${bookCode}a.att.xml";
        } else {
          final splitAttBooks = ["s0508", "s0513", "s0514"];
          String attPart = splitAttBooks.contains(bookCode) ? part : "";
          fileName = "${bookCode}a$attPart.att.xml";
        }
        break;

      case TafsirType.tik:
        if (bookCode.startsWith("s040")) {
          fileName = "${bookCode}t.tik.xml";
        } else if (bookCode == "s0501") {
          fileName = "${bookCode}t.nrf.xml";
        } else {
          fileName = "${bookCode}t$part.tik.xml";
        }
        break;
    }

    try {
      String fullXmlString;

      // 🔥 2. LOGIC CACHE RAM (Anti Boros Kuota)
      if (_ramCache.containsKey(fileName)) {
        debugPrint("⚡ RAM HIT: $fileName (Pake memori)");
        fullXmlString = _ramCache[fileName]!;
      } else {
        // 🔥 3. FETCH ONLINE (Kalau belum ada di RAM)
        debugPrint("🌐 DOWNLOAD: $fileName ...");
        final url = "$_baseUrl/$fileName";

        final response = await _dio.get(
          url,
          options: Options(responseType: ResponseType.bytes),
        );

        List<int> bytes = response.data as List<int>;

        // Decode bytes (Pake helper _decodeSmart lu yang udah ada)
        fullXmlString = _decodeSmart(bytes);

        // 🔥 4. SIMPAN KE RAM
        _ramCache[fileName] = fullXmlString;
      }

      // 5. PARSE & EXTRACT (Logic Lama)
      final document = XmlDocument.parse(fullXmlString);
      String nikaya = _getNikaya(uid);
      String extractedXml = _extractSutta(document, suttaNum, nikaya, type);

      return _beautifyXml2(extractedXml);
    } catch (e) {
      debugPrint("Error loading $fileName: $e");
      return """
      <h3>Gagal Memuat</h3>
      <p><b>File:</b> $fileName</p>
      <p><b>Status:</b> Gagal ambil data online.</p>
      <p><b>Error:</b> $e</p>
      
      <pJika masalah ini terus berlanjut, mohon <i>screenshot</i> dan laporkan ke <b>aluskaindonesia@gmail.com</b></p>
      """;
    }
  }

  String _extractSutta(
    XmlNode root,
    String suttaNum,
    String nikaya,
    TafsirType type,
  ) {
    // --- 1. HANDLING DN (Cukup pakai root) ---
    if (nikaya == 'dn') {
      return _extractByDivId(root, suttaNum, 'sutta');
    }
    // --- 2. HANDLING AN (Cukup pakai root, jauh lebih hemat RAM) ---
    else if (nikaya == 'an') {
      final parts = suttaNum.split('.');
      if (parts.length < 2) return root.outerXml;

      int nipata =
          int.tryParse(parts[0].toLowerCase().replaceAll('an', '')) ?? 0;
      String numPart = parts[1];
      int globalSuttaNum = numPart.contains('-')
          ? int.tryParse(numPart.split('-')[0]) ?? 0
          : int.tryParse(numPart) ?? 0;

      // 1. Dapatkan posisi Bab berdasarkan index asli SuttaCentral (Agar bab TIDAK terdorong)
      final (pIdx, vInP, vName, relNum, originalIsRange) =
          _calculateAnVaggaPosition(nipata, globalSuttaNum, numPart);

      // 2. Lakukan remap untuk mendapatkan angka VRI (Teks yang mau ditarik)
      final (remappedNumPart, remappedGlobal) = _applyAnRemap(
        nipata,
        numPart,
        globalSuttaNum,
      );

      // 3. Tentukan apakah hasil remap menjadi range (misal 47 jadi 47-48)
      bool effectiveIsRange = originalIsRange || remappedNumPart.contains('-');

      // 4. Hitung relativeNum baru berdasarkan selisih pergeseran VRI
      int finalRelativeNum = relNum + (remappedGlobal - globalSuttaNum);

      if (type == TafsirType.mul) {
        return _extractMulaAn(
          root,
          globalSuttaNum,
          nipata,
          pIdx,
          vInP,
          finalRelativeNum,
          suttaNum,
          effectiveIsRange,
          type,
          remappedNumPart,
        );
      } else {
        return _extractCommentaryAn(
          root,
          globalSuttaNum,
          nipata,
          pIdx,
          vInP,
          finalRelativeNum,
          vName,
          remappedNumPart,
          effectiveIsRange,
          type,
        );
      }
    }

    // ðŸ”¥ BARU DI SINI KITA BIKIN xmlString (Buat MN, KN, SN yang masih pakai regex)
    final String xmlString = root.outerXml;

    if (nikaya == 'mn') {
      String bookPrefix = 'mn1';
      if (xmlString.contains('id="mn2"')) {
        bookPrefix = 'mn2';
      } else if (xmlString.contains('id="mn3"')) {
        bookPrefix = 'mn3';
      }

      int bookRelativeNum = int.tryParse(suttaNum.split('_')[1]) ?? 1;
      int vaggaNum = 1;
      int vaggaRelativeSuttaNum = 1;

      if (bookPrefix == 'mn3') {
        if (bookRelativeNum <= 30) {
          vaggaNum = ((bookRelativeNum - 1) ~/ 10) + 1;
          vaggaRelativeSuttaNum = ((bookRelativeNum - 1) % 10) + 1;
        } else if (bookRelativeNum <= 42) {
          vaggaNum = 4;
          vaggaRelativeSuttaNum = bookRelativeNum - 30;
        } else {
          vaggaNum = 5;
          vaggaRelativeSuttaNum = bookRelativeNum - 42;
        }
      } else {
        vaggaNum = ((bookRelativeNum - 1) ~/ 10) + 1;
        vaggaRelativeSuttaNum = ((bookRelativeNum - 1) % 10) + 1;
      }

      String vaggaId = '${bookPrefix}_$vaggaNum';
      String vaggaXml = _extractByDivFlexible(root, vaggaId, 'vagga');

      if (vaggaXml.length == xmlString.length && vaggaNum > 1) {
        String prevVaggaId = '${bookPrefix}_${vaggaNum - 1}';
        String prevContent = _extractByDivFlexible(root, prevVaggaId, 'vagga');
        if (prevContent.length < xmlString.length) {
          int splitIdx = xmlString.indexOf(prevContent);
          if (splitIdx != -1) {
            vaggaXml = xmlString.substring(splitIdx + prevContent.length);
          }
        }
      }

      if (type == TafsirType.tik &&
          vaggaNum == 1 &&
          bookPrefix == 'mn1' &&
          vaggaRelativeSuttaNum == 1) {
        final startPattern = RegExp(
          r'<p rend="subhead"[^>]*>\s*1\.\s*Mūlapariyāya.*?</p>',
          caseSensitive: false,
        );
        final startMatch = startPattern.firstMatch(xmlString);
        final endPattern = RegExp(
          r'<p rend="subhead"[^>]*>\s*2\.\s*Sabbāsava.*?</p>',
          caseSensitive: false,
        );
        final endMatch = endPattern.firstMatch(xmlString);

        if (startMatch != null && endMatch != null) {
          return xmlString.substring(startMatch.start, endMatch.start);
        }
      }

      if (type == TafsirType.tik &&
          vaggaNum == 1 &&
          bookPrefix == 'mn1' &&
          vaggaRelativeSuttaNum >= 2 &&
          vaggaRelativeSuttaNum <= 10) {
        final Map<int, String> mnVagga1Titles = {
          2: "Sabbāsava",
          3: "Dhammadāyāda",
          4: "Bhayabherava",
          5: "Anaṅgaṇa",
          6: "Ākaṅkheyya",
          7: "Vattha",
          8: "Sallekha",
          9: "Sammādiṭṭhi",
          10: "Satipaṭṭhāna",
        };

        if (mnVagga1Titles.containsKey(vaggaRelativeSuttaNum)) {
          String keyword = mnVagga1Titles[vaggaRelativeSuttaNum]!;
          String res = _extractBySpecificTitle(xmlString, keyword, type);

          if (res.contains("tidak ditemukan")) {
            return _generateErrorHtml(type, keyword);
          }
          return res;
        }
      }

      String result = _extractBySubhead2(
        vaggaXml,
        'mn_$vaggaRelativeSuttaNum',
        type,
      );

      if (result.contains("tidak ditemukan")) {
        return _generateErrorHtml(type, "MN $suttaNum");
      }
      return result;
    } else if (nikaya == 'kn') {
      String res = _extractBySubhead2(xmlString, suttaNum, type);
      if (res.contains("tidak ditemukan")) {
        return _generateErrorHtml(type, suttaNum);
      }
      return res;
    } else if (nikaya == 'sn') {
      if (suttaNum.contains(':')) {
        final parts = suttaNum.split(':');
        final String samyuttaId = parts[0];
        final String suttaPart = parts[1];

        String samyuttaXml = _extractByDivFlexible(
          root,
          samyuttaId,
          'samyutta',
        );
        if (!samyuttaXml.contains('<p')) return samyuttaXml;

        int samyuttaNum = _getSamyuttaNumFromId(samyuttaId);
        int globalIdx = int.tryParse(suttaPart.split('-')[0]) ?? 1;

        // --- 1. KILL SWITCH (Sesuai Report Lu) ---
        if (samyuttaNum == 18 && globalIdx >= 11 && type == TafsirType.tik) {
          return _generateErrorHtml(type, suttaPart);
        }
        if (samyuttaNum == 24) {
          if (globalIdx >= 20 && globalIdx <= 35) {
            return _generateErrorHtml(type, suttaPart);
          }
          if (type != TafsirType.mul &&
              ((globalIdx >= 46 && globalIdx <= 69) ||
                  (globalIdx >= 72 && globalIdx <= 95))) {
            return _generateErrorHtml(type, suttaPart);
          }
        }

        // --- 2. KEYWORD OVERRIDES ---
        String? specialKeyword;
        if (samyuttaNum == 23 && globalIdx >= 23) {
          // ðŸ”¥ Fix: nangkep 'Mārasuttādi' atau 'Mārādisutta'
          specialKeyword = r'mār.*?sutt.*?ādi';
        } else if (samyuttaNum == 29) {
          // ðŸ”¥ Fix: Mapping lengkap SN 29 biar gak nyasar
          if (globalIdx >= 11 && globalIdx <= 20) {
            specialKeyword = r'aṇḍaja.*?sutt.*?ādi';
          } else if (globalIdx >= 21 && globalIdx <= 30) {
            specialKeyword = r'jalābuja.*?sutt.*?ādi';
          } else if (globalIdx >= 31 && globalIdx <= 40) {
            specialKeyword = r'saṃsedaja.*?sutt.*?ādi';
          } else if (globalIdx >= 41 && globalIdx <= 50) {
            specialKeyword = r'opapātika.*?sutt.*?ādi';
          }

          // 1. Tambahkan pengecekan range untuk Samyutta 24
        } else if (samyuttaNum == 24 && globalIdx >= 19 && globalIdx <= 44) {
          specialKeyword = "Dutiyagamanādivaggavaṇṇanā";
        } else if (samyuttaNum == 47 && globalIdx >= 31 && globalIdx <= 40) {
          specialKeyword = "Ananussutavaggavaṇṇanā";
        } else if (samyuttaNum == 48 && globalIdx >= 61 && globalIdx <= 70) {
          specialKeyword = "Bodhipakkhiyavagg";
        } else if (samyuttaNum == 52 && globalIdx >= 11 && globalIdx <= 24) {
          specialKeyword = "Dutiyavaggavaṇṇanā";
        } else if (samyuttaNum == 56 && globalIdx >= 51 && globalIdx <= 60) {
          specialKeyword = "Abhisamayavaggavaṇṇanā";
          // 2. Sisanya tetap menggunakan Map yang sudah ada
        } else if ((samyuttaNum >= 30 && samyuttaNum <= 33) ||
            samyuttaNum == 26 ||
            samyuttaNum == 27 ||
            samyuttaNum == 39 ||
            samyuttaNum == 49 ||
            samyuttaNum == 50 ||
            samyuttaNum == 53) {
          // ðŸ”¥ Fix SN 30-34: Semuanya ulasan kolektif (sepaket satu bab)
          final Map<int, String> shortSamyuttaKeywords = {
            26: "uppādasaṃyutta",
            27: "kilesasaṃyutta",
            30: "supaṇṇasaṃyutta",
            31: "gandhabbakāyasaṃyutta",
            32: "valāhakasaṃyutta", // Ini kunci buat SN 32 lu!
            33: "vacchagottasaṃyutta",
            39: "sāmaṇḍakasaṃyutta",
            49: "sammappadhānasaṃyutta",
            50: "balasaṃyutta",
            53: "jhānasaṃyutta",
            // 34: "jhānasaṃyutta",
          };
          specialKeyword = shortSamyuttaKeywords[samyuttaNum];
        }

        int vaggaIdx = 1;
        int relativeNum = globalIdx;
        List<int>? counts = _snStructure[samyuttaNum];
        if (counts != null) {
          for (int count in counts) {
            if (relativeNum <= count) break;
            relativeNum -= count;
            vaggaIdx++;
          }
        }

        String vaggaXml = _isolateVaggaSn(samyuttaXml, vaggaIdx, samyuttaNum);
        String label = (type == TafsirType.att)
            ? "Aṭṭhakathā"
            : (type == TafsirType.tik ? "Ṭīkā" : "Sutta");
        String result = "tidak ditemukan";

        if (specialKeyword != null && type != TafsirType.mul) {
          // ðŸ”¥ Fix: Tambahin 'centre|bodytext' di rend list
          final m = RegExp(
            r'<(p|head)[^>]*rend="(chapter|title|subhead|centre|bodytext)"[^>]*>.*?'
            '$specialKeyword'
            r'.*?</\1>',
            caseSensitive: false,
          ).firstMatch(samyuttaXml);

          if (m != null) {
            result =
                "<h4>$label (Kolektif)</h4>${_cutFromMatch(samyuttaXml, m)}";
          }
        }

        if (result.contains("tidak ditemukan")) {
          // ðŸ”¥ Fix: Kalau isolation gagal, JANGAN cari Relative (biar gak dapet Suddhika)
          bool isolationFailed = (vaggaXml.length >= samyuttaXml.length * 0.9);

          // 1. Cari Global Subhead (Paling Akurat)
          result = _extractBySubhead2(vaggaXml, "sn_$globalIdx", type);

          // 2. Cari Relative Subhead (Cuma kalo isolation berhasil)
          if (result.contains("tidak ditemukan") && !isolationFailed) {
            result = _extractBySubhead2(vaggaXml, "sn_$relativeNum", type);
          }

          // 3. Cari Paranum (Pake Global SuttaPart)
          if (result.contains("tidak ditemukan")) {
            result = _extractByParanum(vaggaXml, suttaPart, type);
          }
        }

        return (result.contains("tidak ditemukan"))
            ? _generateErrorHtml(type, suttaPart)
            : result;
      }
    }

    return xmlString; // Fallback terakhir
  }

  String _cutFromMatch(String xml, Match m) {
    int start = m.start;
    int end = xml.length;
    // Berhenti kalau ketemu subhead berikutnya atau judul vagga baru
    final next = RegExp(
      r'<p[^>]*rend="(subhead|title|chapter)"',
      caseSensitive: false,
    ).firstMatch(xml.substring(m.end));
    if (next != null) end = m.end + next.start;
    return xml.substring(start, end);
  }

  String _getNikaya(String uid) {
    final cleanUid = uid.toLowerCase();
    if (cleanUid.startsWith('dn')) return 'dn';
    if (cleanUid.startsWith('mn')) return 'mn';
    if (cleanUid.startsWith('sn')) return 'sn';
    if (cleanUid.startsWith('an')) return 'an';

    const knPrefixes = [
      'kp',
      'khp',
      'dhp',
      'ud',
      'iti',
      'snp',
      'vv',
      'pv',
      'thag',
      'thig',
      'ap',
      'bu',
      'cp',
      'ja',
    ];
    if (knPrefixes.any((p) => cleanUid.startsWith(p))) return 'kn';

    return '';
  }

  String _extractByDivId(XmlNode node, String divId, String divType) {
    // terima XmlNode
    try {
      // langsung cari tanpa parse ulang
      final element = node.descendants.whereType<XmlElement>().firstWhere(
        (e) =>
            e.getAttribute('id') == divId && e.getAttribute('type') == divType,
        orElse: () => throw Exception('not found'),
      );
      return element.outerXml; // balikin string buat diproses regex beautify lu
    } catch (e) {
      return node.outerXml; // fallback
    }
  }

  // ðŸ”¥ FUNGSI SAKTI V2: The "Patient" Accumulator
  // Dia gak akan ambil match pertama, tapi ngitung dulu slot kursinya.

  // ðŸ”¥ FUNGSI SAKTI: Cari Sutta berdasarkan JUDUL (Keyword)
  // Dipake buat MN 2-10 Tika yang strukturnya "rata tanah" tanpa div.
  String _extractBySpecificTitle(
    String xml,
    String titleKeyword,
    TafsirType type,
  ) {
    // 1. Cari Header Target: <p rend="subhead">...Angka...Judul...</p>
    // Kita cari angka + judul (misal: "2. Sabbāsava")
    final startPattern = RegExp(
      r'<p rend="subhead"[^>]*>\s*\d+\.\s*' +
          RegExp.escape(titleKeyword) +
          r'.*?</p>',
      caseSensitive: false,
    );

    final startMatch = startPattern.firstMatch(xml);

    // Fallback: Coba cari tanpa angka (kadang cuma "Sabbāsavasuttavaṇṇanā")
    if (startMatch == null) {
      final startPatternNoNum = RegExp(
        r'<p rend="subhead"[^>]*>.*?' +
            RegExp.escape(titleKeyword) +
            r'.*?</p>',
        caseSensitive: false,
      );
      final startMatchNoNum = startPatternNoNum.firstMatch(xml);

      if (startMatchNoNum == null) {
        return "tidak ditemukan"; // Ganti dari _generateErrorHtml
      }
      return _extractFromPosToEnd(xml, startMatchNoNum);
    }

    return _extractFromPosToEnd(xml, startMatch);
  }

  String _extractFromPosToEnd(String xml, RegExpMatch startMatch) {
    // 2. Cari Header Berikutnya (Sebagai Batas Akhir)
    // Cari <p rend="subhead"> yang punya ANGKA depannya (misal "3.")
    // Ini asumsinya sutta berikutnya pasti dimulai dengan nomor urut.
    final nextSubheadPattern = RegExp(
      r'<p rend="subhead"[^>]*>\s*\d+\.',
      caseSensitive: false,
    );

    final nextMatch = nextSubheadPattern.firstMatch(
      xml.substring(startMatch.end),
    );

    int endPos;
    if (nextMatch != null) {
      endPos = startMatch.end + nextMatch.start;
    } else {
      // Kalau gak ada subhead angka lagi, cari penutup div / trailer
      int divEnd = xml.indexOf('</div>', startMatch.end);
      if (divEnd != -1) {
        endPos = divEnd;
      } else {
        endPos = xml.length;
      }
    }

    return xml.substring(startMatch.start, endPos);
  }

  String _extractBySubhead2(String xml, String suttaNum, TafsirType type) {
    final parts = suttaNum.split('_');
    final String targetNum = parts.length > 1 ? parts[1] : parts[0];
    final int targetInt = int.tryParse(targetNum) ?? -1;

    // ðŸ”¥ FIX 1: Deteksi range di targetNum user (support semua jenis strip)
    bool isSubheadRange = targetNum.contains(RegExp(r'[\-\â€“\â€”]'));

    // --- STEP 1: CARI TITIK AWAL (START) ---
    RegExpMatch? startMatch;

    if (isSubheadRange) {
      // Kalau user request range (misal 5-6), cari string persis
      startMatch = RegExp(
        r'<p rend="subhead"[^>]*>\s*' + RegExp.escape(targetNum) + r'[\.\)]',
        caseSensitive: false,
      ).firstMatch(xml);
    } else {
      // A. Coba match angka persis ("6." atau "6 " atau "6-")
      // ðŸ”¥ FIX 2: Regex ini sekarang kenal strip panjang (â€“) dan em-dash (â€”)
      startMatch = RegExp(
        r'<(p|head)[^>]*rend="(subhead|title|chapter|bodytext|centre)"[^>]*>'
        r'(?:\s*<[^>]+>)*\s*(?:\(\s*)?'
        '${RegExp.escape(targetNum)}' // ðŸ”¥ Pakai interpolasi di sini
        r'[\.\s\-\â€“\â€”\)](?![^<]*?(?:vagg|saṃyutt))',
        caseSensitive: false,
      ).firstMatch(xml);

      // B. LOGIKA MATEMATIKA: Cari Range yang MENGANDUNG angka target
      if (startMatch == null && targetInt != -1) {
        final rangeRegex = RegExp(
          r'<(p|head)[^>]*rend="(subhead|title|chapter)"[^>]*>\s*(\d+)\s*[\-\â€“\â€”]\s*(\d+)[\.\)]',
          caseSensitive: false,
        );
        // ... rest of logic for (targetInt >= s && targetInt <= e) ...
        final allRanges = rangeRegex.allMatches(xml);

        for (var m in allRanges) {
          int s = int.tryParse(m.group(1) ?? '0') ?? 0;
          int e = int.tryParse(m.group(2) ?? '0') ?? 0;

          if (targetInt >= s && targetInt <= e) {
            startMatch = m;
            break;
          }
        }
      }

      // C. Fallback (Adivanna/Peyyala) - DENGAN BLOCKER CHECK
      if (startMatch == null && targetInt != -1) {
        // ðŸ”¥ FIX 4: Fallback scanner juga support strip panjang
        final fallbackMatches = RegExp(
          r'<p rend="subhead"[^>]*>[^<]*?(\d+)[\.\-\â€“\â€”][^<]*?(ādi|peyyāla)',
          caseSensitive: false,
        ).allMatches(xml);

        RegExpMatch? bestMatch;
        int bestNum = 0;

        for (var m in fallbackMatches) {
          int headNum = int.tryParse(m.group(1)!) ?? 0;
          if (headNum <= targetInt && headNum > bestNum) {
            bestMatch = m;
            bestNum = headNum;
          }
        }

        if (bestMatch != null) {
          bool isBlocked = false;
          final allSubheads = RegExp(
            r'<p rend="subhead"[^>]*>\s*(\d+)',
          ).allMatches(xml);
          for (var sub in allSubheads) {
            int subNum = int.tryParse(sub.group(1)!) ?? 0;
            if (subNum > bestNum && subNum < targetInt) {
              isBlocked = true;
              break;
            }
          }
          if (!isBlocked) startMatch = bestMatch;
        }
      }
    }

    if (startMatch == null) {
      return "tidak ditemukan"; // Ganti dari _generateErrorHtml
    }

    // --- STEP 2: CARI TITIK AKHIR (END) ---
    final int startPos = startMatch.start;

    final nextBoundaryPattern = RegExp(
      // ðŸ”¥ Fix: Boundary harus sensitif sama 'vagg' dan 'saṃyutt' juga
      r'<p[^>]*rend="subhead"[^>]*>\s*\d+|<head|<trailer|<p[^>]*rend="(title|centre|chapter)"[^>]*>.*?(vaṇṇanā|vannana|vagg|saṃyutt|niṭṭhita|samatta)|<div[^>]*id=',
      caseSensitive: false,
    );

    final nextMatches = nextBoundaryPattern.allMatches(xml, startMatch.end);

    int endPos = xml.length;

    if (nextMatches.isNotEmpty) {
      endPos = nextMatches.first.start;
    }

    // --- STEP 3: FINAL CLEANUP ---
    String extracted = xml.substring(startPos, endPos);

    if (extracted.trim().endsWith('</div>')) {
      extracted = extracted.substring(0, extracted.lastIndexOf('</div>'));
    }

    return extracted;
  }

  // TERIMA XmlNode, JANGAN String
  String _extractByDivFlexible(XmlNode node, String targetId, String type) {
    try {
      // LANGSUNG CARI, JANGAN XmlDocument.parse LAGI
      final element = node.descendants.whereType<XmlElement>().firstWhere(
        (e) => e.getAttribute('id')?.contains(targetId) ?? false,
        orElse: () => throw Exception('not found'),
      );
      return element.outerXml;
    } catch (e) {
      return node.outerXml; // fallback ke node asal
    }
  }

  /*Future<String> _getOrDownloadBook(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final File file = File(filePath);

    List<int> bytes;
    bool shouldDownload = true; // Defaultnya kita anggap harus download

    // 1. Cek dulu kalau file ada di HP
    if (await file.exists()) {
      bytes = await file.readAsBytes();

      // --- TAMBAHAN: VALIDASI ISI FILE (SATPAM) ---
      // Kita cek 50 huruf pertama. Kalau isinya HTML error, berarti file sampah.
      String header = String.fromCharCodes(bytes.take(50));

      if (bytes.length < 50 ||
          header.contains("<!DOCTYPE") ||
          header.contains("404")) {
        // Kalau file rusak/sampah, hapus biar nanti didownload ulang
        await file.delete();
        shouldDownload = true;
      } else {
        // Kalau file aman, gak usah download
        shouldDownload = false;
      }
      // -------------------------------------------
    } else {
      // Kalau file emang gak ada, ya download
      shouldDownload = true;
      bytes = []; // Init aja biar gak error
    }

    // 2. Proses Download (Cuma jalan kalau file gak ada atau file rusak)
    if (shouldDownload) {
      final String url = "$_baseUrl/$fileName";

      try {
        final response = await _dio.get(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        bytes = response.data as List<int>;

        // Simpan file yang baru didownload
        await file.writeAsBytes(bytes);
      } catch (e) {
        throw Exception("File $fileName not found at $url");
      }
    }

    return _decodeSmart(bytes);
  }
*/
  String _decodeSmart(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16LE(bytes.sublist(2));
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16BE(bytes.sublist(2));
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3));
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x3C &&
        bytes[1] == 0x00 &&
        bytes[2] == 0x3F &&
        bytes[3] == 0x00) {
      return _decodeUtf16LE(bytes);
    }
    try {
      return utf8.decode(bytes);
    } catch (e) {
      return _decodeUtf16LE(bytes);
    }
  }

  String _decodeUtf16LE(List<int> bytes) {
    List<int> codeUnits = [];
    for (int i = 0; i < bytes.length - 1; i += 2) {
      int charCode = bytes[i] | (bytes[i + 1] << 8);
      codeUnits.add(charCode);
    }
    return String.fromCharCodes(codeUnits);
  }

  String _decodeUtf16BE(List<int> bytes) {
    List<int> codeUnits = [];
    for (int i = 0; i < bytes.length - 1; i += 2) {
      int charCode = (bytes[i] << 8) | bytes[i + 1];
      codeUnits.add(charCode);
    }
    return String.fromCharCodes(codeUnits);
  }

  String _beautifyXml2(String xml) {
    // 1. Filter Metadata & Penutup (Update: Tambah "Vaggo")
    xml = xml.replaceAllMapped(
      RegExp(
        r'<p[^>]*rend="title"[^>]*>(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ),
      (m) {
        final text = m.group(1) ?? "";
        final lowerText = text.toLowerCase();

        // style khusus buat trailer (samatto, nitthito, atau nama vaggo penutup)
        if (lowerText.contains("samatto") ||
            lowerText.contains("niṭṭhit") ||
            lowerText.contains("vaggo")) {
          return "<p style='text-align:center; font-style:italic; opacity:0.7; margin-top:30px; border-top:1px dashed #ccc; padding-top:10px;'>$text</p>";
        }

        // Cek metadata kitab besar, tapi kecualikan judul bagian penting (pāḷi / vaṇṇanā)
        if ((lowerText.contains("nikāya") ||
                lowerText.contains("nipāta") ||
                lowerText.contains("paḷi")) &&
            !lowerText.contains("vaggo") &&
            !lowerText.contains("pāḷi") &&
            !lowerText.contains("vaṇṇanā")) {
          return "tidak ditemukan";
        }
        return "<h1 class='title'>$text</h1>";
      },
    );

    // 2. Hapus Judul Bab (Vaggo/Nipato) - FIX "VAMPIRE REGEX"
    // xml = xml.replaceAll(
    //  RegExp(
    //    r'<p[^>]*rend="centre"[^>]*>\s*(.*?vaggo.*?|.*?nipāto.*?|.*?saṃyuttaṃ.*?)\s*</p>',
    //     caseSensitive: false,
    //    multiLine: true,
    //   ),
    //   '',
    // );

    // Hapus Note dan Tag XML lain
    xml = xml.replaceAll(RegExp(r'<note>.*?</note>', dotAll: true), '');
    xml = xml.replaceAll(
      RegExp(
        r'</?(xml|div|pgroup|book|nikaya|readunit)[^>]*>',
        caseSensitive: false,
      ),
      '',
    );

    // 3. Format Headers (H1, H2, H3)

    // <head> -> H1 Title Utama
    //  xml = xml.replaceAllMapped(
    //   RegExp(r'<head[^>]*>(.*?)</head>', caseSensitive: false, dotAll: true),
    //    (m) => "<h1 class='title'>${m.group(1)}</h1>",
    //  );

    // Subhead dengan Angka (misal: "2. Mahasihanada...") -> H1 Sutta Title
    // Menggunakan regex fleksibel untuk menangkap angka di awal
    xml = xml.replaceAllMapped(
      RegExp(
        r'<p[^>]*rend="subhead"[^>]*>\s*(\d+[\.\-][^<]*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ),
      (m) => "<h1 class='sutta-title'>${m.group(1)}</h1>",
    );

    // Subhead TANPA Angka (misal: "Vesālinagaravaṇṇanā") -> H2 Topic Title
    // Ini penting agar sub-bahasan vannana muncul tebal
    xml = xml.replaceAllMapped(
      RegExp(
        r'<p[^>]*rend="subhead"[^>]*>(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ),
      (m) => "<h2 class='topic-title'>${m.group(1)}</h2>",
    );

    // Subsubhead -> H3
    xml = xml.replaceAllMapped(
      RegExp(
        r'<p[^>]*rend="subsubhead"[^>]*>(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ),
      (m) => "<h3 class='subsubhead'>${m.group(1)}</h3>",
    );

    // --- 3. FORMAT NOMOR (Subhead Range & n-Attribute) DULUAN ---
    // tangkap paragraf yang punya <hi rend="paranum"> di dalemnya (sering di ulasan pertama AN)
    xml = xml.replaceAllMapped(
      RegExp(
        r'<p[^>]*>(?:\s*<hi rend="paranum">([\d\-]+)</hi>)(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ),
      (m) {
        String num = m.group(1) ?? '';
        String content = m.group(2) ?? '';
        return '<p class="para"><span class="para-num" data-num="$num">$num</span> ${content.trim()}</p>';
      },
    );

    // Tangkap paragraf yang punya atribut n="..." (Standar SN & AN)
    xml = xml.replaceAllMapped(
      RegExp(
        r'<p[^>]*\bn="([\d\-]+)"[^>]*>(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ),
      (m) {
        String numAttr = m.group(1) ?? '';
        String content = m.group(2) ?? '';

        // Cari nomor asli di dalam tag <hi rend="paranum"> kalau ada (biar dapet format 21-22)
        final hiMatch = RegExp(
          r'<hi rend="paranum">(.*?)</hi>',
          caseSensitive: false,
        ).firstMatch(content);
        String displayNum = hiMatch != null ? hiMatch.group(1)! : numAttr;

        // Bersihkan sisa tag biar nomor gak muncul dobel di layar
        content = content.replaceFirst(
          RegExp(r'<hi rend="paranum">.*?</hi>', caseSensitive: false),
          '',
        );
        content = content.replaceFirst(
          RegExp(r'<hi rend="dot">.*?</hi>', caseSensitive: false),
          '',
        );

        return '<p class="para"><span class="para-num" data-num="$displayNum">$displayNum</span> ${content.trim()}</p>';
      },
    );

    // Tangkap tag 'subhead' yang isinya angka tapi gak punya atribut 'n' (Penting buat awal AN)
    xml = xml.replaceAllMapped(
      RegExp(
        r'<p[^>]*rend="subhead"[^>]*>\s*([\d\-]+)[\.\)](.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ),
      (m) {
        String num = m.group(1) ?? '';
        String content = m.group(2) ?? '';
        return '<p class="para"><span class="para-num" data-num="$num">$num</span> ${content.trim()}</p>';
      },
    );

    // --- 4. FORMAT HEADERS (JUDUL ASLI YANG TERSISA) ---
    // <head> -> H1 Title Utama
    xml = xml.replaceAllMapped(
      RegExp(r'<head[^>]*>(.*?)</head>', caseSensitive: false, dotAll: true),
      (m) => "<h1 class='title'>${m.group(1)}</h1>",
    );

    // Subhead yang BUKAN angka (misal: "Nidānavaṇṇanā") -> H2 Topic Title
    xml = xml.replaceAllMapped(
      RegExp(
        r'<p[^>]*rend="subhead"[^>]*>(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ),
      (m) => "<h2 class='topic-title'>${m.group(1)}</h2>",
    );

    // 5. Format Gatha (Syair)
    xml = xml.replaceAllMapped(
      RegExp(
        r'<p[^>]*rend="gatha\d*"[^>]*>(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ),
      (m) => "<div class='gatha'>${m.group(1)}</div>",
    );

    // 6. Cleanup & Styling Tambahan

    // Bodytext biasa jadi p class='para'
    xml = xml.replaceAll(
      RegExp(r'<p[^>]*rend="bodytext"[^>]*>', caseSensitive: false),
      '<p class="para">',
    );

    // Cari yang ini (Baris 911):
    xml = xml.replaceAll(
      RegExp(r'<(p|trailer)[^>]*rend="centre"[^>]*>', caseSensitive: false),
      '<p style="text-align:center; font-weight:bold; color:#666; margin-top:20px; margin-bottom:20px;">',
    );

    // Dan tambahkan baris ini di bawahnya:
    xml = xml.replaceAll('</trailer>', '</p>');

    // Page break markers
    xml = xml.replaceAllMapped(
      RegExp(r'<pb ed="([^"]*)" n="([^"]*)"\s*/>', caseSensitive: false),
      (m) =>
          '<span class="pb-marker" data-edition="${m.group(1)}" data-page="${m.group(2)}">${m.group(1)}</span>',
    );

    // Bold formatting
    xml = xml.replaceAllMapped(
      RegExp(r'<hi rend="bold">(.*?)</hi>', caseSensitive: false),
      (m) => "<b>${m.group(1)}</b>",
    );

    // Final cleanup
    xml = xml.replaceAll(RegExp(r'>\s+<'), '><');
    xml = xml.replaceAll('||', '.');
    xml = xml.replaceAll('|', '.');

    return xml;
  }

  Future<bool> hasTafsir(String uid) async {
    final cleanUid = uid.toLowerCase();
    final validPrefixes = [
      'dn',
      'mn',
      'sn',
      'an',
      //'kp',
      // 'dhp',
      //'ud',//BERPOTENSI LANCAR
      //'iti', //BERPOTENSI LANCAR
      //  'snp'
      //'vv', //BERPOTENSI LANCAR
      //'pv', ////BERPOTENSI LANCAR MULAI PV17 KOSONG
      //'thag',
      //'thig',
      //'ap',
      //'bu',
      // 'cp',
      // 'ja',
      // 'nm',
      // 'nc',
      // 'ps',
      //  'ne',
      // 'mil',
      // 'pe',
    ];

    return validPrefixes.any((prefix) => cleanUid.startsWith(prefix));
  }

  Map<String, String> _calculateMapping(String uid) {
    final cleanUid = uid.toLowerCase(); //  Pastikan semua lowercase di sini
    final int n =
        int.tryParse(RegExp(r'\d+').firstMatch(cleanUid)?.group(0) ?? '1') ?? 1;

    // DN
    if (cleanUid.startsWith('dn')) {
      if (n <= 13) return {'code': 's0101', 'num': 'dn1_$n'};
      if (n <= 23) return {'code': 's0102', 'num': 'dn2_${n - 13}'};
      return {'code': 's0103', 'num': 'dn3_${n - 23}'};
    }

    // MN
    if (cleanUid.startsWith('mn')) {
      if (n <= 50) return {'code': 's0201', 'num': 'mn_$n'};
      if (n <= 100) return {'code': 's0202', 'num': 'mn_${n - 50}'};
      return {'code': 's0203', 'num': 'mn_${n - 100}'};
    }

    // SN
    if (cleanUid.startsWith('sn')) {
      final parts = cleanUid.replaceAll('sn', '').split('.');
      final int samyutta = int.tryParse(parts[0]) ?? 1;

      final String suttaPart = parts.length > 1 ? parts[1] : "1";

      //  KODE LAMA (BIANG KEROK): Ini yang motong "93-213" jadi "93"
      // final suttaMatch = RegExp(r'\d+').firstMatch(suttaPart);
      // final int sutta = int.tryParse(suttaMatch?.group(0) ?? '1') ?? 1;

      String code;
      int bookNum;
      int localSamyutta;

      if (samyutta <= 11) {
        code = "s0301";
        bookNum = 1;
        localSamyutta = samyutta;
      } else if (samyutta <= 21) {
        code = "s0302";
        bookNum = 2;
        localSamyutta = samyutta - 11;
      } else if (samyutta <= 34) {
        code = "s0303";
        bookNum = 3;
        localSamyutta = samyutta - 21;
      } else if (samyutta <= 44) {
        code = "s0304";
        bookNum = 4;
        localSamyutta = samyutta - 34;
      } else {
        code = "s0305";
        bookNum = 5;
        localSamyutta = samyutta - 44;
      }

      // âœ… FIX: Pake 'suttaPart' langsung (isinya "93-213") biar range-nya kebawa!
      return {'code': code, 'num': 'sn${bookNum}_$localSamyutta:$suttaPart'};
    }

    // AN (Ganti 'uid' dengan 'cleanUid')
    if (cleanUid.startsWith('an')) {
      final parts = cleanUid.split('.');
      if (parts.length < 2) return {'code': '', 'num': ''};

      String bookStr = parts[0].replaceAll('an', '');
      int bookNum = int.tryParse(bookStr) ?? 0;

      String bookCode = "";
      String mulPart = ""; // Kita hitung lagi part-nya!

      // Mapping File
      switch (bookNum) {
        case 1:
          bookCode = "s0401";
          // AN 1 gak punya part pecahan, biarkan kosong
          break;
        case 2:
        case 3:
        case 4:
          bookCode = "s0402";
          // Rumus: AN 2 -> m1, AN 3 -> m2, AN 4 -> m3
          mulPart = (bookNum - 1).toString();
          break;
        case 5:
        case 6:
        case 7:
          bookCode = "s0403";
          // Rumus: AN 5 -> m1, AN 6 -> m2, AN 7 -> m3
          mulPart = (bookNum - 4).toString();
          break;
        case 8:
        case 9:
        case 10:
        case 11:
          bookCode = "s0404";
          // Rumus: AN 8 -> m1, ... AN 11 -> m4
          mulPart = (bookNum - 7).toString();
          break;
        default:
          return {'code': '', 'num': ''};
      }

      return {
        'code': bookCode,
        'num': cleanUid,
        'mulPart': mulPart, // ✅ SEKARANG SUDAH TERISI (Misal: "2" untuk AN 3)
      };
    }

    // KN
    const knMap = {
      'kp': '01',
      'khp': '01',
      'dhp': '02',
      'ud': '03',
      'iti': '04',
      'snp': '05',
      'vv': '06',
      'pv': '07',
      'thag': '08',
      'thig': '09',
      'ap': '10',
      'bu': '11',
      'cp': '12',
      'ja': '13',
      'nm': '14',
      'nc': '15',
      'ps': '16',
      'ne': '17',
      'mil': '18',
      'pe': '19',
    };

    for (var entry in knMap.entries) {
      if (cleanUid.startsWith(entry.key)) {
        final String bookCode = "s05${entry.value}";
        final parts = cleanUid.replaceAll(entry.key, '').split('.');

        int suttaIdx;
        if (parts.length > 1) {
          int p1 = int.tryParse(parts[0]) ?? 1;
          int p2 = int.tryParse(parts[1]) ?? 1;

          if (entry.key == 'ud') {
            suttaIdx = ((p1 - 1) * 10) + p2;
          } else if (entry.key == 'iti') {
            suttaIdx = n;
          } else {
            suttaIdx = p2;
          }
        } else {
          suttaIdx = n;
        }

        String part = "";
        if (bookCode == "s0508") {
          part = (suttaIdx <= 263) ? "1" : "2";
        } else if (bookCode == "s0510") {
          part = (suttaIdx <= 400) ? "1" : "2";
        } else if (bookCode == "s0513") {
          if (suttaIdx <= 150) {
            part = "1";
          } else if (suttaIdx <= 300) {
            part = "2";
          } else if (suttaIdx <= 450) {
            part = "3";
          } else {
            part = "4";
          }
        } else if (bookCode == "s0514") {
          part = cleanUid.startsWith('bu') ? "1" : "2";
        }

        return {
          'code': bookCode,
          'num': '${entry.key}_$suttaIdx',
          'part': part, // âœ… KN tetap pakai 'part'
        };
      }
    }

    return {'code': '', 'num': ''};
  }

  String _extractCommentaryAn(
    XmlNode root,
    int globalSuttaNum,
    int nipata,
    int pannasakaIdx,
    int vaggaInPannasaka,
    int relativeNum,
    String vaggaNameTarget,
    String numPart,
    bool isRange,
    TafsirType type,
  ) {
    // =======================================================================
    // ðŸ› ï¸ STEP 0: PATCH MAPPING (STANDARD)
    // =======================================================================
    // ... (Mapping standar lainnya tetap ada buat safety) ...
    /*if (isRange) {
      final (newNumPart, newGlobalSutta) = _applyAnRemap(
        nipata,
        numPart,
        globalSuttaNum,
      );
      numPart = newNumPart;
      globalSuttaNum = newGlobalSutta;
      final (newP, newV, _, newRel, _) = _calculateAnVaggaPosition(
        nipata,
        globalSuttaNum,
        numPart,
      );
      if (!vaggaNameTarget.contains("peyyāla")) {
        pannasakaIdx = newP;
        vaggaInPannasaka = newV;
        relativeNum = newRel;
      }
    }*/

    // =======================================================================
    // 1. ISOLASI NIPATA
    // =======================================================================
    String fullXml = root.outerXml;
    String nipataBlock = fullXml;
    String nipataId = "an$nipata";

    int nStart = fullXml.indexOf('id="$nipataId"');
    if (nStart != -1) {
      int nEnd = fullXml.indexOf('<div id="an${nipata + 1}"', nStart);
      if (nEnd == -1) nEnd = fullXml.lastIndexOf('</body>');
      if (nEnd != -1) nipataBlock = fullXml.substring(nStart, nEnd);
    }

    // =======================================================================
    // ðŸ”¥ STEP 2: THE "HARDCODE" BYPASS (AN 1 & AN 2 - ATT & TIK) ðŸ”¥
    // =======================================================================
    // Kita izinkan Nipata 1 & 2, dan Tipe selain MUL (bisa Att/Tik)
    if ((nipata == 1 || nipata == 2 || nipata == 3 || nipata == 24) &&
        type != TafsirType.mul) {
      String? hardcodedTarget;

      // -----------------------------------------------------------
      // BAGIAN A: Mapping Khusus AN 1 (Ekakanipāta) - ISI DI SINI BANG
      // -----------------------------------------------------------
      if (nipata == 1) {
        // CONTOH (Abang sesuaikan angka & keywordnya dgn XML AN 1):

        // 1. Bālavaggavaṇṇanā (AN 1.1-10)
        if (globalSuttaNum >= 1 && globalSuttaNum <= 10) {
          hardcodedTarget = "Rūpādivaggavaṇṇanā"; // Cukup kata uniknya
        } else if (globalSuttaNum >= 98 && globalSuttaNum <= 139) {
          hardcodedTarget = "Dutiyapamādādivaggavaṇṇanā"; // Cukup kata uniknya
        } else if (globalSuttaNum >= 198 && globalSuttaNum <= 208) {
          hardcodedTarget = "Dutiyaetadaggavagg"; // Cukup kata uniknya
        } else if (globalSuttaNum >= 209 && globalSuttaNum <= 218) {
          hardcodedTarget = "Tatiyaetadaggavagg"; // Cukup kata uniknya
        } else if (globalSuttaNum >= 219 && globalSuttaNum <= 234) {
          hardcodedTarget = "Catutthaetadaggavagg"; // Cukup kata uniknya
        } else if (globalSuttaNum >= 235 && globalSuttaNum <= 247) {
          hardcodedTarget = "Pañcamaetadaggavagg"; // Cukup kata uniknya
        } else if (globalSuttaNum >= 248 && globalSuttaNum <= 257) {
          hardcodedTarget = "Chaṭṭhaetadaggavagg"; // Cukup kata uniknya
        } else if (globalSuttaNum >= 258 && globalSuttaNum <= 267) {
          hardcodedTarget = "Sattamaetadaggavagg"; // Cukup kata uniknya
          //LANJUT
        } else if (globalSuttaNum >= 278 && globalSuttaNum <= 295) {
          if (type == TafsirType.att) {
            //PUSING GATAU, DUTIYA TATIYA
            hardcodedTarget = "(15) 2. Aṭṭhānapāḷi-dutiyavaggavaṇṇanā";
          } else {
            hardcodedTarget = "Aṭṭhānapāḷi (dutiyavagga)"; // Cukup kata uniknya
          }
          //LANJUT
          //PUSING GATAU, DUTIYA TATIYA
        }
        // CONTOH CARA PAKE GESER INDEX:
        else if (globalSuttaNum >= 298 && globalSuttaNum <= 307) {
          hardcodedTarget = "Ekadhammapāḷi-dutiyavaggavaṇṇanā";
        } else if (globalSuttaNum >= 308 && globalSuttaNum <= 321) {
          hardcodedTarget = "Ekadhammapāḷi-tatiyavaggavaṇṇanā";
        } else if (globalSuttaNum >= 322 && globalSuttaNum <= 365) {
          hardcodedTarget = "Ekadhammapāḷi-catutthavaggavaṇṇanā";
        } else if (globalSuttaNum >= 366 && globalSuttaNum <= 381) {
          hardcodedTarget = "Pasādakaradhammavagg"; // Cukup kata uniknya
        } else if (globalSuttaNum >= 382 && globalSuttaNum <= 562) {
          hardcodedTarget =
              "Aparaaccharāsaṅghātavaggavaṇṇanā"; // Cukup kata uniknya
        } else if (globalSuttaNum >= 563 && globalSuttaNum <= 599) {
          hardcodedTarget = "Kāyagatāsativaggavaṇṇanā"; // Cukup kata uniknya
        }
      } // -----------------------------------------------------------
      // BAGIAN B: Mapping Khusus AN 2 (Dukanipāta)
      // -----------------------------------------------------------
      else if (nipata == 2) {
        // 1. Bālavaggavaṇṇanā (AN 2.98-117)
        if (globalSuttaNum >= 99 && globalSuttaNum <= 118) {
          hardcodedTarget = "5. Bālavaggavaṇṇanā"; // Cukup kata uniknya
        }
        // 2. Āsāduppajahavaggavaṇṇanā (AN 2.118-129)
        else if (globalSuttaNum >= 119 && globalSuttaNum <= 130) {
          hardcodedTarget = "Āsāduppajaha";
        }
        // 3. Āyācanavaggavaṇṇanā (AN 2.130-140)
        else if (globalSuttaNum >= 131 && globalSuttaNum <= 141) {
          hardcodedTarget = "Āyācana";
        }
        // 4. Kodhapeyyāla (AN 2.180-229)
        else if (globalSuttaNum >= 181 && globalSuttaNum <= 190) {
          hardcodedTarget = "Kodhapeyyāla";
        }
        // 5. Akusalapeyyala (AN 2.230-279)
        else if (globalSuttaNum >= 191 && globalSuttaNum <= 200) {
          hardcodedTarget = "Akusalapeyyāla";
        }
        //   // 6. Vinayapeyyāla (AN 2.280-309)
        //    else if (globalSuttaNum >= 201 && globalSuttaNum <= 230) {
        ///     hardcodedTarget = "Vinayapeyyāla";
        //   }
        // 7. Rāgapeyyāla (AN 2.310+)
        else if (globalSuttaNum >= 231) {
          hardcodedTarget = "Rāgapeyyāla";
        }
        // BAGIAN C: Mapping Khusus AN 3 (Tikanipāta)
        // -----------------------------------------------------------
      } else if (nipata == 3) {
        if (globalSuttaNum >= 146 && globalSuttaNum <= 156) {
          if (type == TafsirType.tik) {
            hardcodedTarget =
                "Qwertyuiop"; //INI HARUSNYA DIILANGIN HUHU GIMANA SI BINGUNG
          }
          //} else if (globalSuttaNum >= 157 && globalSuttaNum <= 163) {
          //    hardcodedTarget = "Acelakavaggo";
        }
      }

      // ===========================================================
      // EKSEKUSI (SAMA UNTUK SEMUA)
      // Kalau salah satu kondisi di atas ngisi 'hardcodedTarget', jalanin ini:
      // ===========================================================
      if (hardcodedTarget != null) {
        // ðŸ”¥ FITUR 1: MAKSA KOSONGIN TIKA (Kalo target Qwertyuiop)
        if (hardcodedTarget.contains("Qwertyuiop")) {
          return _generateErrorHtml(
            type,
            isRange ? numPart : relativeNum.toString(),
          );
        }

        vaggaNameTarget = hardcodedTarget;

        // Cari match PERTAMA saja (Gak pake fitur geser urutan lagi)
        RegExp explicitRegex = RegExp(
          r'<(p|head)[^>]*rend="(chapter|title|subhead)"[^>]*>.*?' +
              RegExp.escape(hardcodedTarget) +
              r'.*?</\1>',
          caseSensitive: false,
        );

        // Pakai firstMatch biar enteng, gak perlu looping index
        Match? m = explicitRegex.firstMatch(nipataBlock);

        if (m != null) {
          int startIdx = m.start;
          int contentStart = m.end;
          int endIdx = nipataBlock.length;

          // Logic Cutting Pintar (Skip Empty Title) - TETEP PAKE PUNYA LU
          RegExp nextChapter = RegExp(
            r'<(p|head)[^>]*rend="(chapter|title|subhead)"',
            caseSensitive: false,
          );
          Match? nextM = nextChapter.firstMatch(
            nipataBlock.substring(contentStart),
          );

          while (nextM != null) {
            int tentativeEnd = contentStart + nextM.start;
            String gapContent = nipataBlock
                .substring(contentStart, tentativeEnd)
                .trim();

            if (gapContent.length < 100 && !gapContent.contains("bodytext")) {
              contentStart = tentativeEnd + (nextM.end - nextM.start);
              nextM = nextChapter.firstMatch(
                nipataBlock.substring(contentStart),
              );
            } else {
              endIdx = tentativeEnd;
              break;
            }
          }

          if (nextM == null) {
            int trailer = nipataBlock.lastIndexOf('</trailer>');
            if (trailer > contentStart) endIdx = trailer + 10;
          }

          String hardcodedVaggaXml = nipataBlock.substring(startIdx, endIdx);

          // Bersihin header - TETEP PAKE PUNYA LU
          String cleanVagga = hardcodedVaggaXml;
          int closeTag = cleanVagga.indexOf("</p>");
          if (closeTag != -1 && closeTag < 300) {
            cleanVagga = cleanVagga.substring(closeTag + 4).trim();
          } else {
            cleanVagga = cleanVagga.replaceFirst(
              RegExp(
                r'^\s*<(head|p)[^>]*rend="(chapter|title|subhead)"[^>]*>.*?</\1>',
                dotAll: true,
              ),
              '',
            );
          }

          // Label dinamis (Tik/Att)
          String label = (type == TafsirType.att) ? "Aṭṭhakathā" : "Ṭīkā";

          if (cleanVagga.isNotEmpty) {
            return "<h4>$label (Bab $vaggaNameTarget)</h4>$cleanVagga";
          }
        }
      }
    }

    // =======================================================================
    // 3. LOGIKA REGULAR (UNTUK YG LAIN & ATTHAKATHA)
    // =======================================================================

    String vaggaXml = "";
    String idFull = "an${nipata}_${pannasakaIdx}_$vaggaInPannasaka";

    if (fullXml.contains('id="$idFull"')) {
      vaggaXml = _cutXmlByNextId(
        root,
        idFull,
        "an${nipata}_${pannasakaIdx}_${vaggaInPannasaka + 1}",
      );
      if (vaggaXml.isEmpty) {
        try {
          vaggaXml = _extractByDivFlexible(root, idFull, 'vagga');
        } catch (e) {
          vaggaXml = "";
        }
      }
    }

    if (vaggaXml.isEmpty || vaggaXml.length < 50) {
      String fuzzyName = vaggaNameTarget.length > 4
          ? vaggaNameTarget.substring(0, 4)
          : vaggaNameTarget;
      // Regex PATOKAN WARAS buat Atthakatha & Tika Normal
      RegExp sniperRegex = RegExp(
        r'<(p|head)[^>]*rend="(chapter|title)"[^>]*>\s*(\(\d+\)\s*)?' +
            vaggaInPannasaka.toString() +
            r'[\.\s].*?' +
            RegExp.escape(fuzzyName) +
            r'.*?</\1>',
        caseSensitive: false,
      );

      Match? m = sniperRegex.firstMatch(nipataBlock);
      if (m != null) {
        int startIdx = m.start;
        int contentStart = m.end;
        int endIdx = nipataBlock.length;
        RegExp nextChapter = RegExp(
          r'<(p|head)[^>]*rend="(chapter|title)"',
          caseSensitive: false,
        );
        Match? nextM = nextChapter.firstMatch(
          nipataBlock.substring(contentStart),
        );

        while (nextM != null) {
          int tentativeEnd = contentStart + nextM.start;
          String gapContent = nipataBlock
              .substring(contentStart, tentativeEnd)
              .trim();
          if (gapContent.length < 100 && !gapContent.contains("bodytext")) {
            contentStart = tentativeEnd + nextM.end - nextM.start;
            nextM = nextChapter.firstMatch(nipataBlock.substring(contentStart));
          } else {
            endIdx = tentativeEnd;
            break;
          }
        }
        if (nextM == null) {
          int trailer = nipataBlock.lastIndexOf('</trailer>');
          if (trailer > contentStart) endIdx = trailer + 10;
        }
        vaggaXml = nipataBlock.substring(startIdx, endIdx);
      }
    }

    // Fix Raga Normal Case
    if (vaggaXml.isEmpty) {
      bool isRaga =
          (vaggaNameTarget.toLowerCase().contains("raga") ||
          vaggaNameTarget.toLowerCase().contains("rāga"));
      if (nipata == 2 && type == TafsirType.tik && isRaga) {
        vaggaXml = "";
      } else {
        vaggaXml = nipataBlock;
      }
    }

    // Ekstraksi Normal
    String result = "tidak ditemukan";
    String label = (type == TafsirType.att) ? "Aṭṭhakathā" : "Ṭīkā";

    if (vaggaXml.isNotEmpty) {
      if (isRange) {
        String pRes = _extractByParanum(vaggaXml, numPart, type);
        if (!pRes.contains("tidak ditemukan")) {
          return "<h4>$label #$numPart</h4>$pRes";
        }
        String sRes = _extractBySubhead2(vaggaXml, "an_$numPart", type);
        if (!sRes.contains("tidak ditemukan")) {
          return "<h4>$label #$numPart</h4>$sRes";
        }
      } else {
        String specificRes = _extractBySubhead2(
          vaggaXml,
          "an_$relativeNum",
          type,
        );
        if (!specificRes.contains("tidak ditemukan")) {
          result = specificRes;
        } else {
          String rangeRes = _extractBySmartRange(vaggaXml, relativeNum);
          if (rangeRes.isNotEmpty) {
            result = rangeRes;
          } else {
            String globalRes = _extractBySubhead2(
              vaggaXml,
              "an_$globalSuttaNum",
              type,
            );
            if (!globalRes.contains("tidak ditemukan")) {
              result = globalRes;
            } else {
              String paraRes = _extractByParanum(
                vaggaXml,
                relativeNum.toString(),
                type,
              );
              if (!paraRes.contains("tidak ditemukan")) {
                result = "<h4>$label #$relativeNum (Paragraf)</h4>$paraRes";
              } else {
                String paraGlobal = _extractByParanum(
                  vaggaXml,
                  globalSuttaNum.toString(),
                  type,
                );
                if (!paraGlobal.contains("tidak ditemukan")) {
                  result =
                      "<h4>$label #$globalSuttaNum (Paragraf)</h4>$paraGlobal";
                }
              }
            }
          }
        }
      }
    }

    if (vaggaXml.isNotEmpty &&
        (result.trim().isEmpty || result.contains("tidak ditemukan")) &&
        (nipata == 1 || nipata == 2) &&
        type == TafsirType.tik) {
      String cleanVagga = vaggaXml.trim();
      int closeTag = cleanVagga.indexOf("</p>");
      if (closeTag != -1 && closeTag < 300) {
        cleanVagga = cleanVagga.substring(closeTag + 4).trim();
      } else {
        cleanVagga = cleanVagga.replaceFirst(
          RegExp(
            r'^\s*<(head|p)[^>]*rend="(chapter|title)"[^>]*>.*?</\1>',
            dotAll: true,
          ),
          '',
        );
      }
      if (cleanVagga.trim().isEmpty) {
        return _generateErrorHtml(
          type,
          isRange ? numPart : relativeNum.toString(),
        );
      }
      return "<h4>$label (Ringkasan Bab $vaggaNameTarget)</h4>$cleanVagga";
    }

    if (result.trim().isEmpty || result.contains("tidak ditemukan")) {
      return _generateErrorHtml(
        type,
        isRange ? numPart : relativeNum.toString(),
      );
    }

    return result;
  }

  // ðŸ”¥ SMART RANGE V2 (AGGRESSIVE SCANNER)
  // Pastikan pakai versi ini biar "3-4" dan "5-10" ketangkep
  String _extractBySmartRange(String vaggaXml, int targetNum) {
    // Regex: <p rend="subhead">3-4. Cintisutta...</p>
    final rangePattern = RegExp(
      r'<p[^>]*rend="subhead"[^>]*>\s*(\d+)\s*[\-\â€“\â€”]\s*(\d+)',
      caseSensitive: false,
    );

    final matches = rangePattern.allMatches(vaggaXml);

    for (var m in matches) {
      int startRange = int.tryParse(m.group(1) ?? '0') ?? 0;
      int endRange = int.tryParse(m.group(2) ?? '0') ?? 0;

      if (endRange < startRange) continue;

      // Kalau target kita (misal 4) ada di range (3-4), ambil!
      if (targetNum >= startRange && targetNum <= endRange) {
        int startPos = m.start;
        int endPos = vaggaXml.length;

        // Cari batas akhir sutta ini
        final nextBoundary = RegExp(
          r'<p[^>]*rend="subhead"|<head|<trailer|<div|<p[^>]*rend="title"|<p[^>]*rend="chapter"',
          caseSensitive: false,
        ).firstMatch(vaggaXml.substring(m.end));

        if (nextBoundary != null) {
          endPos = m.end + nextBoundary.start;
        }

        String content = vaggaXml.substring(startPos, endPos);
        return "<h4>(Bagian dari rentang $startRange-$endRange)</h4>$content";
      }
    }

    return "tidak ditemukan";
  }

  (int, int, String, int, bool) _calculateAnVaggaPosition(
    int nipata,
    int globalSuttaNum,
    String suttaNumStr,
  ) {
    final List<List<(int, String)>> pannasakas =
        _anStructure[nipata] ?? [List.generate(100, (i) => (10, "Vagga"))];

    int currentLimit = 0;
    for (int pIdx = 0; pIdx < pannasakas.length; pIdx++) {
      List<(int, String)> vaggas = pannasakas[pIdx];
      for (int vIdx = 0; vIdx < vaggas.length; vIdx++) {
        int count = vaggas[vIdx].$1;
        String name = vaggas[vIdx].$2;

        if (globalSuttaNum <= currentLimit + count) {
          bool isRange = suttaNumStr.contains('-');
          return (
            pIdx + 1,
            vIdx + 1,
            name,
            globalSuttaNum - currentLimit,
            isRange,
          );
        }
        currentLimit += count;
      }
    }
    return (1, 1, "Unknown", globalSuttaNum, false);
  }

  // Panggil ini di _extractSutta bagian SN kalau result "tidak ditemukan"

  // ðŸ”ª HELPER: Iris Sutta dari dalam Vagga XML (By Subhead Number)
  String _extractSuttaFromVaggaXml(String vaggaXml, int relativeNum) {
    // Cari <p rend="subhead">X.</p>  atau  <p rend="subhead">X-Y.</p>
    // Regex: Angka di awal subhead harus match relativeNum
    final startPattern = RegExp(
      r'<p rend="subhead"[^>]*>\s*' + relativeNum.toString() + r'[.-]',
      caseSensitive: false,
    );

    final startMatch = startPattern.firstMatch(vaggaXml);
    if (startMatch == null) return "tidak ditemukan";
    // Gak ketemu

    int startPos = startMatch.start;

    // Cari Subhead berikutnya (apapun angkanya) buat jadi batas akhir
    final nextPattern = RegExp(
      r'<p rend="subhead"[^>]*>\s*\d+[.-]',
      caseSensitive: false,
    );
    final nextMatch = nextPattern.firstMatch(
      vaggaXml.substring(startMatch.end),
    );

    int endPos = vaggaXml.length;
    if (nextMatch != null) {
      endPos = startMatch.end + nextMatch.start;
    } else {
      // Kalau gak ada sutta lagi, cari penutup div/trailer
      final trailer = vaggaXml.indexOf('<trailer', startMatch.end);
      final divClose = vaggaXml.lastIndexOf('</div>');
      if (trailer != -1) {
        endPos = trailer;
      } else if (divClose != -1 && divClose > startPos) {
        endPos = divClose;
      }
    }

    return vaggaXml.substring(startPos, endPos);
  }

  String _extractMulaAn(
    XmlNode root,
    int globalSuttaNum,
    int nipata,
    int pannasakaIdx,
    int vaggaInPannasaka,
    int relativeNum,
    String suttaId,
    bool isRange,
    TafsirType type,
    String numPart,
  ) {
    int globalVaggaIdx = 0;
    final List<List<(int, String)>> structure = _anStructure[nipata] ?? [];
    for (int i = 0; i < pannasakaIdx - 1; i++) {
      globalVaggaIdx += (structure.length > i) ? structure[i].length : 0;
    }
    globalVaggaIdx += vaggaInPannasaka;

    String vaggaIdXml = "a$nipata-$globalVaggaIdx"; // ID format berkas kamu

    String vaggaXml = ""; // Deklarasi agar tidak "Undefined name"

    XmlElement? targetElement;
    try {
      final idsToTry = {
        "an${nipata}_${pannasakaIdx}_$vaggaInPannasaka",
        "an${nipata}_$globalVaggaIdx",
        vaggaIdXml,
        "a$nipata-$globalVaggaIdx",
      };

      targetElement = root.descendants.whereType<XmlElement>().firstWhere(
        (e) => idsToTry.contains(e.getAttribute('id')),
        orElse: () {
          // Fallback
          return root.descendants.whereType<XmlElement>().firstWhere(
            (e) => e.getAttribute('id') == "an$nipata",
            orElse: () => root.descendants.whereType<XmlElement>().first,
          );
        },
      );

      vaggaXml = targetElement.outerXml;
    } catch (e) {
      if (kDebugMode) {
        print("   💥 Exception: $e");
      }
      targetElement = null;
      vaggaXml = root.outerXml;
    }

    String targetId = targetElement?.getAttribute('id') ?? "";
    // Jika ID bab tidak ketemu, gunakan seluruh isi file sebagai scope
    String scope = (targetId.isEmpty)
        ? root.outerXml
        : _cutXmlByNextId(root, targetId, "");

    String content = "";
    if (isRange) {
      content = _extractByParanum(scope, numPart, type);
    } else {
      content = _extractSuttaFromVaggaXml(scope, relativeNum);
    }

    if (content.isEmpty || content.contains("tidak ditemukan")) {
      return vaggaXml.isNotEmpty ? vaggaXml : root.outerXml;
    }

    // --- Header Logic ---
    String headerHtml = "";
    if (targetElement != null) {
      final pHead = targetElement.parent?.children
          .whereType<XmlElement>()
          .firstWhere(
            (e) => e.name.local == 'head' && e.getAttribute('rend') == 'title',
            orElse: () => XmlElement(XmlName('empty')),
          );
      final vHead = targetElement.children.whereType<XmlElement>().firstWhere(
        (e) =>
            (e.name.local == 'head' && e.getAttribute('rend') == 'chapter') ||
            (nipata == 1 &&
                e.name.local == 'p' &&
                (e.getAttribute('rend') == 'title' ||
                    e.getAttribute('rend') == 'centre')),
        orElse: () => XmlElement(XmlName('empty')),
      );

      String pHtml = (pHead != null && pHead.name.local != 'empty')
          ? pHead.outerXml
          : "";
      String vHtml = (vHead.name.local != 'empty') ? vHead.outerXml : "";
      headerHtml = (isRange && relativeNum == 1 && vaggaInPannasaka == 1)
          ? ""
          : "$pHtml\n$vHtml";
    }

    return "$headerHtml\n$content";
  }

  String _cutXmlByNextId(XmlNode node, String currentId, String nextId) {
    try {
      final allElements = [
        if (node is XmlElement) node,
        ...node.descendants.whereType<XmlElement>(),
      ];

      final startElement = allElements.firstWhere(
        (e) => e.getAttribute('id') == currentId,
        orElse: () => throw Exception('not found'),
      );

      final endMatches = allElements.where(
        (e) => e.getAttribute('id') == nextId,
      );
      final endElement = (nextId.isEmpty || endMatches.isEmpty)
          ? null
          : endMatches.first;

      // Jika start dan end berada di parent yang berbeza, ambil start sampai habis
      if (endElement == null || startElement.parent != endElement.parent) {
        return startElement.outerXml;
      }

      final parent = startElement.parent!;
      final children = parent.children;
      final sIdx = children.indexOf(startElement);
      final eIdx = children.indexOf(endElement);

      if (sIdx != -1 && eIdx != -1 && eIdx > sIdx) {
        return children.sublist(sIdx, eIdx).map((e) => e.outerXml).join('\n');
      }

      return startElement.outerXml;
    } catch (e) {
      return "tidak ditemukan"; // Ganti dari "" jadi ini
    }
  }

  String _extractByParanum(String xml, String suttaNum, TafsirType type) {
    // ðŸ”¥ FIX UTAMA: Cara bersihin ID yang lebih pinter.
    // Dulu cuma: replaceAll('an\d+.', '') -> Akibatnya 'sn_123' gak kebersih, jadi error.
    // Sekarang: Ambil angka paling belakang setelah underscore (_) atau titik (.).
    String cleanSuttaNum = suttaNum;
    if (suttaNum.contains('_')) {
      cleanSuttaNum = suttaNum.split('_').last;
    } else if (suttaNum.contains('.')) {
      cleanSuttaNum = suttaNum.split('.').last;
    }

    // Bersihin sisa-sisa karakter non-angka (misal range 18-20)
    final parts = cleanSuttaNum.split('-');
    final startStr = parts[0];
    final endStr = parts.length > 1 ? parts[1] : startStr;

    int startNum = int.tryParse(startStr) ?? 0;
    int endNum = int.tryParse(endStr) ?? startNum;

    // Kalo parsing gagal (0), langsung nyerah aja daripada nyari angka 0
    if (startNum == 0) return _generateErrorHtml(type, suttaNum);

    int startPos = -1;
    int endOfLastPara = -1;
    RegExpMatch? endMatch;

    // =========================================================================
    // ðŸ•µï¸ CARA 1: Cari via atribut n="..." (Support Range "18-20")
    // =========================================================================
    final paraPattern = RegExp(
      r'<p[^>]*\bn="([\d\-\â€“\â€”]+)"[^>]*>(.*?)</p>', // Fix: Support dash aneh di atribut n
      caseSensitive: false,
      dotAll: true,
    );
    final allParas = paraPattern.allMatches(xml);

    for (var m in allParas) {
      String nAttr = m.group(1) ?? '';
      // Bersihkan string: ganti en-dash/em-dash jadi strip biasa, hapus spasi
      String cleanAttr = nAttr
          .replaceAll(RegExp(r'[â€“â€”]'), '-')
          .replaceAll(' ', '');

      int rangeStart = 0, rangeEnd = 0;
      if (cleanAttr.contains('-')) {
        var rp = cleanAttr.split('-');
        if (rp.length >= 2) {
          rangeStart = int.tryParse(rp[0]) ?? 0;
          rangeEnd = int.tryParse(rp[1]) ?? rangeStart;
        }
      } else {
        rangeStart = int.tryParse(cleanAttr) ?? 0;
        rangeEnd = rangeStart;
      }

      // LOGIKA SAKTI: Cek apakah target (19) ada di dalam range n="18-20"
      if (startNum >= rangeStart && startNum <= rangeEnd) {
        startPos = m.start;
      }
      if (endNum >= rangeStart && endNum <= rangeEnd) {
        endMatch = m;
        endOfLastPara = m.end;
      }
    }

    // =========================================================================
    // ðŸ•µï¸ CARA 2: Cari via Teks Awal Paragraf (RANGE AWARE SCANNER)
    // =========================================================================
    if (startPos == -1) {
      final textNumScanner = RegExp(
        // ðŸ”¥ Fix: Larang nangkep rend="title/chapter/centre" biar gak nangkep nomor di judul Vagga
        r'<p(?![^>]*rend="(?:title|chapter|centre|subhead)")'
        r'[^>]*>(?:\s*<[^>]+>)*\s*(\d+)(?:\s*[\-â€“â€”]\s*(\d+))?\s*[\.]',
        caseSensitive: false,
      );

      final matches = textNumScanner.allMatches(xml);

      for (var m in matches) {
        int pStart = int.tryParse(m.group(1) ?? '0') ?? 0;
        int pEnd = pStart;

        // Kalau ada angka kedua (range), ambil. Kalau gak, pEnd = pStart.
        if (m.group(2) != null) {
          pEnd = int.tryParse(m.group(2)!) ?? pStart;
        }

        // LOGIKA MATEMATIKA: Cek apakah target ada di dalam range
        if (startNum >= pStart && startNum <= pEnd) {
          startPos = m.start;
          break; // KETEMU! Stop scanning.
        }
      }
    }

    // =========================================================================
    // ðŸ•µï¸ CARA 3: Fallback <hi rend="paranum">
    // =========================================================================
    if (startPos == -1) {
      final hiPattern = RegExp(
        r'<hi rend="paranum">([^<]+)</hi>',
        caseSensitive: false,
      );
      final hiMatches = hiPattern.allMatches(xml);
      for (var m in hiMatches) {
        String hiNum = m.group(1) ?? '';
        String cleanHi = hiNum
            .replaceAll(RegExp(r'[â€“â€”]'), '-')
            .replaceAll(' ', '');

        int nStart = 0, nEnd = 0;
        if (cleanHi.contains('-')) {
          var parts = cleanHi.split('-');
          nStart = int.tryParse(parts[0]) ?? 0;
          nEnd = int.tryParse(parts[1]) ?? nStart;
        } else {
          nStart = int.tryParse(cleanHi) ?? 0;
          nEnd = nStart;
        }

        if (startNum >= nStart && startNum <= nEnd) {
          int pStart = xml.lastIndexOf('<p', m.start);
          if (pStart != -1) {
            startPos = pStart;
            break;
          }
        }
      }
    }

    // --- SAFETY CHECK (ANTI BOCOR HEADER) ---
    if (startPos != -1) {
      int lookBackLimit = (startPos - 4000 > 0) ? startPos - 4000 : 0;
      String lookBackArea = xml.substring(lookBackLimit, startPos);

      final headerRegex = RegExp(
        r'<(p|head|trailer)[^>]*rend="(title|chapter|subhead|centre)"[^>]*>(.*?)</(p|head|trailer)>',
        caseSensitive: false,
        dotAll: true,
      );

      final matches = headerRegex.allMatches(lookBackArea).toList();
      if (matches.isNotEmpty) {
        int actualStart = startPos;
        for (var i = matches.length - 1; i >= 0; i--) {
          String fullTag = matches[i].group(0) ?? "";
          String titleContent = (matches[i].group(3) ?? "")
              .trim()
              .toLowerCase();

          bool isTrailer =
              fullTag.contains('<trailer') ||
              titleContent.contains("samatto") ||
              titleContent.contains("niṭṭhit") ||
              titleContent.contains("paṇṇāsaka") ||
              (fullTag.contains('rend="centre"') &&
                  (titleContent.contains('vaggo') ||
                      titleContent.contains('vaṇṇanā')));

          if (isTrailer) break;
          String between = lookBackArea.substring(
            matches[i].end,
            (i == matches.length - 1)
                ? (startPos - lookBackLimit)
                : matches[i + 1].start,
          );
          if (between.contains('<p n=') ||
              between.contains('rend="bodytext"')) {
            break;
          }
          actualStart = lookBackLimit + matches[i].start;
        }
        startPos = actualStart;
      }
    }

    if (startPos == -1) {
      return "tidak ditemukan"; // Ganti dari _generateErrorHtml
    }

    // --- TENTUKAN END POS ---
    if (endOfLastPara == -1) {
      if (endMatch != null) {
        endOfLastPara = endMatch.end;
      } else {
        int divEnd = xml.indexOf('</div>', startPos);
        endOfLastPara = (divEnd != -1) ? divEnd : xml.length;
        int pEnd = xml.indexOf('</p>', startPos);
        if (pEnd != -1 && pEnd < endOfLastPara) endOfLastPara = pEnd + 4;
      }
    }
    final nextBoundary = RegExp(
      r'(<hi rend="paranum">\s*(?!'
      '${RegExp.escape(endStr)}' // ðŸ”¥ Ganti operator '+' jadi interpolasi
      r')\d+'
      r'|<p rend="subhead"[^>]*>\s*(?!'
      '${RegExp.escape(endStr)}' // ðŸ”¥ Sini juga
      r')\d+'
      r'|<p[^>]*\bn="(?!'
      '${RegExp.escape(endStr)}' // ðŸ”¥ Dan sini
      r')\d+"'
      r'|<p[^>]*>\s*(?:<[^>]+>)*\s*(?!'
      '${RegExp.escape(endStr)}' // ðŸ”¥ Terakhir sini
      r')\d+[\.\-]'
      r'|<p[^>]*rend="(title|centre|chapter)"[^>]*>.*?(vaṇṇanā|vannana|vagg|saṃyutt|niṭṭhita|samatta)'
      r'|<div[^>]*?id="|<head)',
      caseSensitive: false,
    ).firstMatch(xml.substring(endOfLastPara));

    int endPos = (nextBoundary != null)
        ? endOfLastPara + nextBoundary.start
        : xml.length;

    // Trailer cleanup
    String suffix = xml.substring(endPos);
    final trailerMatch = RegExp(
      r'^\s*(?:</div>\s*)*<(p|trailer)[^>]*rend="centre"[^>]*>(.*?)</(p|trailer)>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(suffix);
    if (trailerMatch != null) {
      String tContent = trailerMatch.group(2)?.toLowerCase() ?? "";
      if (tContent.contains("vaggo") ||
          tContent.contains("samatto") ||
          tContent.contains("niṭṭhit")) {
        endPos += trailerMatch.end;
      }
    }

    return xml.substring(startPos, endPos);
  }

  String _isolateVaggaSn(String samyuttaXml, int vaggaIdx, int samyuttaNum) {
    // ðŸ”¥ Fix: Kalau nyari Vagga > 1, JANGAN cari kata 'samyutta' biar gak match judul Samyutta.
    final String typePattern = (vaggaIdx > 1) ? 'vagg' : r'(?:vagg|saṃyutt)';

    final vPattern = RegExp(
      r'<(p|head)[^>]*rend="(title|chapter|centre)"[^>]*>'
      r'(?:\s*<[^>]+>)*\s*'
      '$vaggaIdx' // Interpolasi buat ilangin warning
      r'[\.\s\)].*?'
      '$typePattern'
      r'.*?</\1>',
      caseSensitive: false,
    );

    Match? vMatch = vPattern.firstMatch(samyuttaXml);
    if (vMatch == null && vaggaIdx == 1) {
      vMatch = RegExp(
        r'<(p|head)[^>]*rend="(title|chapter|centre)"[^>]*>.*?saṃyuttaṃ.*?</\1>',
        caseSensitive: false,
      ).firstMatch(samyuttaXml);
    }

    if (vMatch == null) return samyuttaXml;

    int startPos = vMatch.start;
    int endPos = samyuttaXml.length;

    // Batas akhir: Vagga berikutnya
    final nextV = RegExp(
      r'<(p|head)[^>]*rend="(title|chapter|centre)"[^>]*>\s*'
      '${vaggaIdx + 1}'
      r'[\.\s\)].*?'
      '$typePattern'
      r'.*?</\1>|<div[^>]*id="',
      caseSensitive: false,
    ).firstMatch(samyuttaXml.substring(vMatch.end));

    if (nextV != null) endPos = vMatch.end + nextV.start;

    return samyuttaXml.substring(startPos, endPos);
  }

  // Helper konversi ID samyutta (sn1_1, dll) ke nomor global (1-56)
  int _getSamyuttaNumFromId(String id) {
    final parts = id.split('_');
    if (parts.length < 2) return 1;
    int book = int.tryParse(parts[0].replaceAll('sn', '')) ?? 1;
    int localIdx = int.tryParse(parts[1]) ?? 1;

    if (book == 1) return localIdx;
    if (book == 2) return 11 + localIdx;
    if (book == 3) return 21 + localIdx;
    if (book == 4) return 34 + localIdx;
    return 44 + localIdx;
  }

  // ðŸ”¥ HELPER BARU: Pesan Error Keren & Informatif (Versi Rapi & Rapet)
  String _generateErrorHtml(TafsirType type, String id) {
    String label = "Mūla";
    if (type == TafsirType.att) label = "Aṭṭhakathā";
    if (type == TafsirType.tik) label = "Ṭīkā";

    return '''
      <h3 style="margin-top: 0; margin-bottom: 8px;">$label tidak ditemukan</h3>
      
      <p style="margin-bottom: 4px;">Bagian <b>#$id</b> tidak ditemukan.</p>
      
      <hr style="margin-top: 12px; margin-bottom: 12px; border: 0; border-top: 1px solid #ccc;">
      
      <p style="margin-bottom: 8px;"><b>Ada beberapa kemungkinan:</b></p>
      
      <ol style="margin-left: -20px; margin-top: 0px;">
        <li style="margin-bottom: 8px;">Memang tidak ada dari sumber asli (CSCD VRI).<br/>• Tidak semua teks memiliki penjelas karena dianggap sudah jelas.<br/>• Ada perbedaan penomoran antara edisi Mahasaṅgīti Tipiṭaka Buddhavasse 2500 dan Chaṭṭha Saṅgāyana CD VRI.</li>
        
        
        <li style="margin-bottom: 8px;">Menyatu dengan bagian lain sekaligus (lihat teks sebelum/sesudah teks ini).</li>

        <li>Kesalahan potong oleh Tim myDhamma. Jika Anda yakin teks ini seharusnya ada, silakan laporkan dengan kirim <i>screenshot</i> halaman ini ke: <b>aluskaindonesia@gmail.com</b></li>
      </ol>

      <p style="margin-bottom: 8px;"><b>Terima kasih!<br/><i>Buddhasāsanaṁ ciraṁ tiṭṭhatu!</i></b></p>
      

    ''';
  }

  // ============================================
  // ðŸ” DEBUGGING TOOLS - TAMBAH DI SINI
  // ============================================

  void testAnMapping(String uid) {
    final mapping = _calculateMapping(uid);

    // Cek filename yang bakal dipake
    String bookCode = mapping['code'] ?? "";

    String _ = "${bookCode}a.att.xml";
  }

  Future<void> testAnExtraction(String uid) async {
    try {
      // Test MUL
      String? mul = await getContent2(uid, type: TafsirType.mul);
      bool mulOk = mul != null && !mul.contains("tidak ditemukan");

      if (mulOk) {
        // ðŸ” PREVIEW: Ambil 300 karakter pertama
        String preview = mul.substring(0, mul.length > 300 ? 300 : mul.length);
        preview = preview.replaceAll(RegExp(r'\s+'), ' '); // Kompres whitespace
      } else if (mul != null) {
        if (kDebugMode) {
          print(
            '   Error: ${mul.substring(0, mul.length > 200 ? 200 : mul.length)}...',
          );
        }
      }

      // Test ATT
      String? att = await getContent2(uid, type: TafsirType.att);
      bool attOk = att != null && !att.contains("tidak ditemukan");

      if (attOk) {
        String preview = att.substring(0, att.length > 300 ? 300 : att.length);
        preview = preview.replaceAll(RegExp(r'\s+'), ' ');
      } else if (att != null) {
        if (kDebugMode) {
          print(
            '   Error: ${att.substring(0, att.length > 200 ? 200 : att.length)}...',
          );
        }
      }

      // Test TIK
      String? tik = await getContent2(uid, type: TafsirType.tik);
      bool tikOk = tik != null && !tik.contains("tidak ditemukan");

      if (tikOk) {
        String preview = tik.substring(0, tik.length > 300 ? 300 : tik.length);
        preview = preview.replaceAll(RegExp(r'\s+'), ' ');
      } else if (tik != null) {
        if (kDebugMode) {
          print(
            '   Error: ${tik.substring(0, tik.length > 200 ? 200 : tik.length)}...',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('âŒ EXCEPTION: $e');
      }
    }
  }

  (String, int) _applyAnRemap(int nipata, String numPart, int globalSuttaNum) {
    final parts = numPart.split('-');
    int scStart = int.tryParse(parts[0]) ?? 0;

    //  PERBAIKAN: Cek dulu panjangnya, jangan main asal ambil parts[1]
    int scEnd = (parts.length > 1)
        ? (int.tryParse(parts[1]) ?? scStart)
        : scStart;

    // Pindahkan semua logika IF-ELSE AN 1 dan AN 2 kamu ke sini
    if (nipata == 1) {
      // Remap SC range ke VRI equivalent (sesuai spot lu)
      if (scStart == 71 && scEnd == 81) {
        numPart = "71-80";
        globalSuttaNum = 71; // Update start global
      } else if (scStart == 82 && scEnd == 97) {
        numPart = "81-97";
        globalSuttaNum = 81; // Update start global
      } else if (scStart == 296 && scEnd == 305) {
        numPart = "296-297";
        globalSuttaNum = 296; // Update start global
      } else if (scStart == 306 && scEnd == 315) {
        numPart = "298-307";
        globalSuttaNum = 298;
      } else if (scStart == 316 && scEnd == 332) {
        numPart = "308-321";
        globalSuttaNum = 308;
      } else if (scStart == 333 && scEnd == 377) {
        numPart = "322-365";
        globalSuttaNum = 322;
      } else if (scStart == 378 && scEnd == 393) {
        numPart = "366-381";
        globalSuttaNum = 366;
      } else if (scStart == 394 && scEnd == 574) {
        numPart = "382-562";
        globalSuttaNum = 382;
      } else if (scStart == 575 && scEnd == 615) {
        numPart = "563-599";
        globalSuttaNum = 563;
      } else if (scStart == 616 && scEnd == 627) {
        numPart = "600-611";
        globalSuttaNum = 600;
      }
    } else if (nipata == 2) {
      // Plotting Pengecualian AN 2
      if (scStart == 11 && scEnd == 20) {
        numPart = "11-21";
        globalSuttaNum = 11;
      } else if (scStart == 21 && scEnd == 31) {
        numPart = "22-32";
        globalSuttaNum = 22;
      } else if (scStart == 32 && scEnd == 41) {
        numPart = "33-42"; // Mapping ke VRI 33 sampai 42
        globalSuttaNum = 33; // Start perhitungan dari 33
      } else if (scStart == 42 && scEnd == 51) {
        numPart = "43-52";
        globalSuttaNum = 43;
      } else if (scStart == 52 && scEnd == 63) {
        numPart = "53-64";
        globalSuttaNum = 53;
      } else if (scStart == 64 && scEnd == 76) {
        numPart = "65-77";
        globalSuttaNum = 65;
      } else if (scStart == 77 && scEnd == 86) {
        numPart = "78-87";
        globalSuttaNum = 78;
      } else if (scStart == 87 && scEnd == 97) {
        numPart = "88-98";
        globalSuttaNum = 88;
      } else if (scStart == 98 && scEnd == 117) {
        numPart = "99-118";
        globalSuttaNum = 99;
      } else if (scStart == 118 && scEnd == 129) {
        numPart = "119-130";
        globalSuttaNum = 119;
      } else if (scStart == 130 && scEnd == 140) {
        numPart = "131-141";
        globalSuttaNum = 131;
      } else if (scStart == 141 && scEnd == 150) {
        numPart = "142-151";
        globalSuttaNum = 142;
      } else if (scStart == 151 && scEnd == 162) {
        // INI HARUSNYA LANJUTANNYA, BUKAN 142-151 LAGI
        numPart = "152-163";
        globalSuttaNum = 152;
      } else if (scStart == 163 && scEnd == 179) {
        // DAN INI LANJUTAN DARI 163
        numPart = "164-180";
        globalSuttaNum = 164;
      } else if (scStart == 180 && scEnd == 229) {
        numPart = "181-190";
        globalSuttaNum = 181;
      } else if (scStart == 230 && scEnd == 279) {
        numPart = "191-200";
        globalSuttaNum = 191;
      } else if (scStart == 280 && scEnd == 309) {
        numPart = "201-230";
        globalSuttaNum = 201;
      }
      //else if (scStart == 310 && scEnd == 479) {
      //  numPart =
      //     "231-246"; // Kamu memetakan 170 Sutta SC ke cuma 15 Sutta VRI!
      // globalSuttaNum = 231;
      // }
    } else if (nipata == 3) {
      // 1. Kasus Stacking (Saṅkhata & Asaṅkhata)
      if (globalSuttaNum == 47) {
        numPart = "47-48"; // Ambil dua sutta VRI sekaligus
        globalSuttaNum = 47; // Tetap di index 47 agar tetap di Cūḷavagga
      }
      // 2. Kasus Offset Global (+1 untuk SEMUA sutta DALAM VAGGA setelah stacking)
      else if (globalSuttaNum >= 48 && globalSuttaNum <= 50) {
        globalSuttaNum += 1; // SC 48 jadi VRI 49, SC 51 jadi VRI 52, dst.
        numPart = globalSuttaNum.toString();
      }
      // Plotting Pengecualian AN 3
      else if (scStart == 156 && scEnd == 162) {
        numPart = "157-163";
        globalSuttaNum = 157;
      } else if (scStart == 163 && scEnd == 182) {
        numPart = "164-183";
        globalSuttaNum = 164;
      } else if (scStart == 183 && scEnd == 352) {
        numPart = "184";
        globalSuttaNum = 184;
      }
    }

    return (numPart, globalSuttaNum);
  }

  /* String _getAnNipataName(int nipata) {
    const names = {
      1: "Ekakanipāta",
      2: "Dukanipāta",
      3: "Tikanipāta",
      4: "Catukkanipāta",
      5: "Pañcakanipāta",
      6: "Chakkanipāta",
      7: "Sattakanipāta",
      8: "Aṭṭhakanipāta",
      9: "Navakanipāta",
      10: "Dasakanipāta",
      11: "Ekādasakanipāta",
    };
    return names[nipata] ?? "";
  }
*/
  // Cek apakah UID ini punya Tika atau enggak
  bool hasTika(String uid) {
    final cleanUid = uid.toLowerCase();

    // 1. Nikaya Besar (DN, MN, SN, AN) -> PASTI ADA TIKA
    if (['dn', 'mn', 'sn', 'an'].any((p) => cleanUid.startsWith(p))) {
      return true;
    }

    // 2. Kitab Khuddaka yang DIKONFIRMASI GAK ADA TIKA (Blocklist)
    // Sesuai list Abang tadi:
    const noTikaPrefixes = [
      'kp', 'khp', // Khuddakapatha
      'dhp', // Dhammapada
      'ud', // Udana
      'iti', // Itivuttaka
      'snp', // Suttanipata
      'vv', // Vimanavatthu
      'pv', // Petavatthu
      'thag', // Theragatha
      'thig', // Therigatha
      'ap', // Apadana
      'bu', // Buddhavamsa
      'cp', // Cariyapitaka
      'ja', // Jataka
      'nm', // Mahaniddesa
      'nc', // Culaniddesa
      'ps', // Patisambhidamagga
      // 'ne',     // Netti (Sebenarnya ada Tika, tapi kalau mau dimatiin, uncomment ini)
      // 'mil',    // Milinda (Kadang ada Tika)
    ];

    if (noTikaPrefixes.any((p) => cleanUid.startsWith(p))) {
      return false; // Tombol Tika bakal ILANG
    }

    // Default: Anggap ada (buat Netti, Milinda, Peṭakopadesa, dll)
    return true;
  }
}
