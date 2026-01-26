import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DaftarIsi {
  // 🔧 AUDIO BASE URL
  static const String _baseUrl =
      "https://samaggi-phala.or.id/multimedias/paritta/";

  //  FIREBASE DATABASE REFERENCE
  static final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  //  CACHE KEYS
  static const String _audioUrlsCacheKey = 'cached_audio_urls';
  static const String _audioUrlsTimestampKey = 'cached_audio_urls_timestamp';

  // 🗺️ In-memory storage (loaded from Firebase/cache)
  static Map<String, String> _audioUrlsMap = {};
  static bool _isAudioLoaded = false;

  // ========================================================================
  // 🎵 AUDIO URLs - FIREBASE INTEGRATION
  // ========================================================================

  /// Load audio URLs from Firebase or cache
  static Future<Map<String, String>> loadAudioUrls({
    bool forceRefresh = false,
  }) async {
    if (_isAudioLoaded && !forceRefresh && _audioUrlsMap.isNotEmpty) {
      return _audioUrlsMap;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1️⃣ Try cache first
      if (!forceRefresh) {
        final cachedData = prefs.getString(_audioUrlsCacheKey);
        if (cachedData != null && cachedData.isNotEmpty) {
          final Map<String, dynamic> rawData = json.decode(cachedData);
          _audioUrlsMap = _convertRawToAudioUrls(rawData);
          _isAudioLoaded = true;
          return _audioUrlsMap;
        }
      }

      // 2️⃣ Fetch from Firebase
      final snapshot = await _databaseRef
          .child('audio')
          .get()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw TimeoutException('Firebase timeout'),
          );

      if (!snapshot.exists) {
        throw Exception('Audio data not found in Firebase');
      }

      final data = snapshot.value;
      if (data == null || data is! Map) {
        throw Exception('Invalid audio data format');
      }

      final rawAudioData = Map<String, dynamic>.from(data);

      // 3️⃣ Convert & save
      _audioUrlsMap = _convertRawToAudioUrls(rawAudioData);
      await prefs.setString(_audioUrlsCacheKey, json.encode(rawAudioData));
      await prefs.setInt(
        _audioUrlsTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      _isAudioLoaded = true;
      return _audioUrlsMap;
    } catch (e) {
      // ⚠️ Fallback to cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString(_audioUrlsCacheKey);

        if (cachedData != null && cachedData.isNotEmpty) {
          final rawData = json.decode(cachedData);
          _audioUrlsMap = _convertRawToAudioUrls(rawData);
          _isAudioLoaded = true;
          return _audioUrlsMap;
        }
      } catch (_) {}

      return {};
    }
  }

  /// Convert: {"NamakkaraPatha": "namakara"} → {"pNamakkaraPatha.html": "url/namakara.mp3"}
  static Map<String, String> _convertRawToAudioUrls(
    Map<String, dynamic> rawMap,
  ) {
    return rawMap.map(
      (htmlName, mp3Name) =>
          MapEntry("p$htmlName.html", "$_baseUrl$mp3Name.mp3"),
    );
  }

  static Map<String, String> get audioUrls {
    if (!_isAudioLoaded || _audioUrlsMap.isEmpty) return {};
    return _audioUrlsMap;
  }

  //  Realtime listener
  static StreamSubscription? _audioListener;

  static void setupRealtimeListener({Function(Map<String, String>)? onUpdate}) {
    _audioListener?.cancel();

    _audioListener = _databaseRef.child('audio').onValue.listen((event) async {
      if (event.snapshot.exists) {
        final data = event.snapshot.value;
        if (data != null && data is Map) {
          final rawData = Map<String, dynamic>.from(data);
          _audioUrlsMap = _convertRawToAudioUrls(rawData);
          _isAudioLoaded = true;

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_audioUrlsCacheKey, json.encode(rawData));
            await prefs.setInt(
              _audioUrlsTimestampKey,
              DateTime.now().millisecondsSinceEpoch,
            );
          } catch (_) {}

          onUpdate?.call(_audioUrlsMap);
        }
      }
    }, onError: (_) {});
  }

  static void disposeRealtimeListener() {
    _audioListener?.cancel();
    _audioListener = null;
  }

  static Future<void> clearAudioCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_audioUrlsCacheKey);
    await prefs.remove(_audioUrlsTimestampKey);
    _audioUrlsMap.clear();
    _isAudioLoaded = false;
  }

  static Future<Map<String, dynamic>> getAudioCacheInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_audioUrlsTimestampKey);
    final cachedData = prefs.getString(_audioUrlsCacheKey);

    return {
      'hasCachedData': cachedData != null && cachedData.isNotEmpty,
      'cachedCount': cachedData != null
          ? (json.decode(cachedData) as Map).length
          : 0,
      'lastUpdate': timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null,
      'isLoaded': _isAudioLoaded,
      'loadedCount': _audioUrlsMap.length,
    };
  }

  // ========================================================================
  // 📚 HTML FILE PATHS (unchanged - existing lists below)
  // ========================================================================

  static const List<String> upo = ['assets/web/upo.html'];
  // Ini daftar file untuk kategori TEMATIK
  static const List<String> tem = ['assets/web/tem/pen.html'];
  static const List<String> tem0_1 = ['assets/web/tem/pen0-1.html'];

  static const List<String> tem0_2 = ['assets/web/tem/pen0-2.html'];

  // ganti struktur yang lama jadi gini
  static Map<int, List<String>> tem1_10 = {
    // 1: ['assets/web/tem/pen1.html', 'dst'], // ini isi tem1 kamu
    1: ['assets/web/tem/pen1.html'], // ini isi tem1 kamu
    2: ['assets/web/tem/pen2.html'], // ini isi tem2 kamu
    3: ['assets/web/tem/pen3.html'],
    4: ['assets/web/tem/pen4.html'],
    5: ['assets/web/tem/pen5.html'],
    6: ['assets/web/tem/pen6.html'],
    7: ['assets/web/tem/pen7.html'],
    8: ['assets/web/tem/pen8.html'],
    9: ['assets/web/tem/pen9.html'],
    10: ['assets/web/tem/pen10.html'],
  };

  // Ini daftar file untuk kategori ABH
  static const List<String> abh = [
    'assets/web/abh/index_abh.html',
    'assets/web/abh/abh1.html',
    'assets/web/abh/abh2.html',
    'assets/web/abh/abh3.html',
  ];

  // Ini daftar file untuk kategori PAR (Paritta)
  static const List<String> parSti0 = ['assets/web/par/sti/p0.html'];
  static const List<String> parSti1_1 = [
    'assets/web/par/sti/p1/pUp1.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pSaranagamanaPatha.html',
    'assets/web/par/sti/text/pSaccakiriyaGatha.html',
    'assets/web/par/sti/text/pMangalaSutta.html',
    'assets/web/par/sti/text/pKaraniyamettaSutta.html',
    'assets/web/par/sti/text/pAngulimala.html',
    'assets/web/par/sti/text/pBuddhanussati.html',
    'assets/web/par/sti/text/pDhammanussati.html',
    'assets/web/par/sti/text/pSanghanussati.html',
    'assets/web/par/sti/text/pAbhaya.html',
    'assets/web/par/sti/text/pDevatauyyojana.html',
    'assets/web/par/sti/text/pSumangala2.html',
  ];

  static const List<String> parSti1_2 = [
    'assets/web/par/sti/p1/pUp2.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pSaranagamanaPatha.html',
    'assets/web/par/sti/text/pSaccakiriyaGatha.html',
    'assets/web/par/sti/text/pAngulimala.html',
    'assets/web/par/sti/text/pBuddhanussati.html',
    'assets/web/par/sti/text/pDhammanussati.html',
    'assets/web/par/sti/text/pSanghanussati.html',
    'assets/web/par/sti/text/pSakkatvatiadi.html',
    'assets/web/par/sti/text/pSumangala2.html',
  ];

  static const List<String> parSti1_3 = [
    'assets/web/par/sti/p1/pUp3.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pSaranagamanaPatha.html',
    'assets/web/par/sti/text/pBuddhanussati.html',
    'assets/web/par/sti/text/pDhammanussati.html',
    'assets/web/par/sti/text/pSanghanussati.html',
    'assets/web/par/sti/text/pCulamangalacakkavala.html',
    'assets/web/par/sti/text/pSo.html',
    'assets/web/par/sti/text/pSumangala2.html',
  ];

  static const List<String> parSti1_4 = [
    'assets/web/par/sti/p1/pUp4.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pSaranagamanaPatha.html',
    'assets/web/par/sti/text/pMangalaSutta.html',
    'assets/web/par/sti/text/pSo.html',
    'assets/web/par/sti/text/pMahajayamangala.html',
    'assets/web/par/sti/text/pSumangala1.html',
  ];

  static const List<String> parSti1_5 = [
    'assets/web/par/sti/p1/pUp5.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pBuddhanussati.html',
    'assets/web/par/sti/text/pDhammanussati.html',
    'assets/web/par/sti/text/pSanghanussati.html',
    'assets/web/par/sti/text/pAbhaya.html',
    'assets/web/par/sti/text/pSo.html',
  ];

  static const List<String> parSti1_6 = [
    'assets/web/par/sti/p1/pUp6.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pSaranagamanaPatha.html',
    'assets/web/par/sti/text/pVattaka.html',
    'assets/web/par/sti/text/pJaya.html',
    'assets/web/par/sti/text/pRatana.html',
    'assets/web/par/sti/text/pSumangala1.html',
  ];

  static const List<String> parSti1_7 = [
    'assets/web/par/sti/p1/pUp7.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pSaranagamanaPatha.html',
    'assets/web/par/sti/text/pBuddhanussati.html',
    'assets/web/par/sti/text/pDhammanussati.html',
    'assets/web/par/sti/text/pSanghanussati.html',
    'assets/web/par/sti/text/pMangalaSutta.html',
    'assets/web/par/sti/text/pKaraniyamettaSutta.html',
    'assets/web/par/sti/text/pMora.html',
    'assets/web/par/sti/text/pCulamangalacakkavala.html',
    'assets/web/par/sti/text/pJaya.html',
    'assets/web/par/sti/text/pSumangala1.html',
  ];

  static const List<String> parSti1_8 = [
    'assets/web/par/sti/p1/pUp8.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pSaranagamanaPatha.html',
    'assets/web/par/sti/text/pBuddhanussati.html',
    'assets/web/par/sti/text/pDhammanussati.html',
    'assets/web/par/sti/text/pSanghanussati.html',
    'assets/web/par/sti/text/pSaccakiriyaGatha.html',
    'assets/web/par/sti/text/pKaraniyamettaSutta.html',
    'assets/web/par/sti/text/pKhandha.html',
    'assets/web/par/sti/text/pAtanatiya.html',
    'assets/web/par/sti/text/pAbhaya.html',
    'assets/web/par/sti/text/pDhajagga.html',
    'assets/web/par/sti/text/pSumangala2.html',
  ];

  static const List<String> parSti1_9 = [
    'assets/web/par/sti/p1/pUp9.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pSaranagamanaPatha.html',
    'assets/web/par/sti/text/pBuddhanussati.html',
    'assets/web/par/sti/text/pDhammanussati.html',
    'assets/web/par/sti/text/pSanghanussati.html',
    'assets/web/par/sti/text/pSaccakiriyaGatha.html',
    'assets/web/par/sti/text/pRatanaSutta.html',
    'assets/web/par/sti/text/pKaraniyamettaSutta.html',
    'assets/web/par/sti/text/pBojjhanga.html',
    'assets/web/par/sti/text/pSakkatvatiadi.html',
    'assets/web/par/sti/text/pSumangala2.html',
  ];

  static const List<String> parSti1_10 = [
    'assets/web/par/sti/p1/pUp10.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pSaranagamanaPatha.html',
    'assets/web/par/sti/text/pKhandha.html',
    'assets/web/par/sti/text/pMahajayamangala.html',
    'assets/web/par/sti/text/pSumangala2.html',
  ];

  static const List<String> parSti1_11 = ['assets/web/par/sti/p1/pUp11.html'];

  static const List<String> parSti1_12 = ['assets/web/par/sti/p1/pUp12.html'];

  static const List<String> parSti1_13 = ['assets/web/par/sti/p1/pUp13.html'];

  static const List<String> parSti1_14 = ['assets/web/par/sti/p1/pUp14.html'];

  static const List<String> parSti1_15 = ['assets/web/par/sti/p1/pUp15.html'];

  static const List<String> parSti1_16a = [
    'assets/web/par/sti/p1/pUp16a.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pSaranagamanaPatha.html',
    'assets/web/par/sti/text/pPabbatopama.html',
    'assets/web/par/sti/text/pAriyadhana.html',
    'assets/web/par/sti/text/pBuddhanussati.html',
    'assets/web/par/sti/text/pDhammanussati.html',
    'assets/web/par/sti/text/pSanghanussati.html',
    'assets/web/par/sti/text/pSumangala1.html',
  ];

  static const List<String> parSti1_16b = [
    'assets/web/par/sti/p1/pUp16b.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pSaranagamanaPatha.html',
    'assets/web/par/sti/text/pEttavatatiadipattidana.html',
  ];
  static const List<String> parSti1_17 = ['assets/web/par/sti/p1/pUp17.html'];

  static const List<String> parSti2 = [
    'assets/web/par/sti/p2.html',
    'assets/web/par/sti/text/pPujaPembukaan.html',
    'assets/web/par/sti/text/pNamakkaraPatha.html',
    'assets/web/par/sti/text/pPujaKatha.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pSaranagamanaPatha.html',
    'assets/web/par/sti/text/pPancasila.html',
    'assets/web/par/sti/text/pBuddhanussati.html',
    'assets/web/par/sti/text/pDhammanussati.html',
    'assets/web/par/sti/text/pSanghanussati.html',
    'assets/web/par/sti/text/pSaccakiriyaGatha.html',
    'assets/web/par/sti/text/pMangalaSutta.html',
    'assets/web/par/sti/text/pKaraniyamettaSutta.html',
    'assets/web/par/sti/text/pBrahmaviharapharana.html',
    'assets/web/par/sti/text/pAbhinhapaccavekkhanaPatha.html',
    'assets/web/par/sti/text/pBhavana.html',
    'assets/web/par/sti/text/pPancasilaAradhana.html',
    'assets/web/par/sti/text/pParittaAradhana.html',
    'assets/web/par/sti/text/pDhammadesanaAradhana.html',
    'assets/web/par/sti/text/pDhammadesana.html',
    'assets/web/par/sti/text/pEttavatatiadipattidana.html',
    'assets/web/par/sti/text/pPujaPenutup.html',
  ];
  static const List<String> parSti3 = [
    'assets/web/par/sti/p3.html',
    'assets/web/par/sti/text/pPancasilaAradhana.html',
    'assets/web/par/sti/text/pUposathaAradhana.html',
    'assets/web/par/sti/text/pAtthasilaAradhana.html',
    'assets/web/par/sti/text/pParittaAradhana.html',
    'assets/web/par/sti/text/pDhammadesanaAradhana.html',
    'assets/web/par/sti/text/pDevataAradhana.html',
    'assets/web/par/sti/text/pPancasila.html',
    'assets/web/par/sti/text/pAtthangasila.html',
    'assets/web/par/sti/text/pDasasila.html',
    'assets/web/par/sti/text/pASCatatan.html',
  ];

  static const List<String> parSti4 = [
    'assets/web/par/sti/p4.html',
    'assets/web/par/sti/text/pDevataAradhana.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pSaranagamanaPatha.html',
    'assets/web/par/sti/text/pNamakkarasiddhi.html',
    'assets/web/par/sti/text/pSaccakiriyaGatha.html',
    'assets/web/par/sti/text/pMahakaru.html',
    'assets/web/par/sti/text/pNamokara.html',
    'assets/web/par/sti/text/pMangalaSutta.html',
    'assets/web/par/sti/text/pRatanaSutta.html',
    'assets/web/par/sti/text/pKaraniyamettaSutta.html',
    'assets/web/par/sti/text/pKhandha.html',
    'assets/web/par/sti/text/pVattaka.html',
    'assets/web/par/sti/text/pBuddhanussati.html',
    'assets/web/par/sti/text/pDhammanussati.html',
    'assets/web/par/sti/text/pSanghanussati.html',
    'assets/web/par/sti/text/pAngulimala.html',
    'assets/web/par/sti/text/pBojjhanga.html',
    'assets/web/par/sti/text/pAtanatiya.html',
    'assets/web/par/sti/text/pAbhaya.html',
    'assets/web/par/sti/text/pDhajagga.html',
    'assets/web/par/sti/text/pMora.html',
    'assets/web/par/sti/text/pDevatauyyojana.html',
    'assets/web/par/sti/text/pSakkatvatiadi.html',
    'assets/web/par/sti/text/pMahajayamangala.html',
    'assets/web/par/sti/text/pBuddhajaya.html',
    'assets/web/par/sti/text/pJaya.html',
    'assets/web/par/sti/text/pSabba.html',
    'assets/web/par/sti/text/pSama.html',
    'assets/web/par/sti/text/pAgga.html',
    'assets/web/par/sti/text/pBhoja.html',
    'assets/web/par/sti/text/pSo.html',
    'assets/web/par/sti/text/pCulamangalacakkavala.html',
    'assets/web/par/sti/text/pRatana.html',
    'assets/web/par/sti/text/pSumangala1.html',
    'assets/web/par/sti/text/pSumangala2.html',
    'assets/web/par/sti/text/pPattidana.html',
  ];

  static const List<String> parSti5 = [
    'assets/web/par/sti/p5.html',
    'assets/web/par/sti/text/pPubbabhaganamakkara.html',
    'assets/web/par/sti/text/pSaranagamanaPatha.html',
    'assets/web/par/sti/text/pPabbatopama.html',
    'assets/web/par/sti/text/pAriyadhana.html',
    'assets/web/par/sti/text/pDhammaniyama.html',
    'assets/web/par/sti/text/pBhadde.html',
    'assets/web/par/sti/text/pTilakkhanadi.html',
    'assets/web/par/sti/text/pBodhi.html',
    'assets/web/par/sti/text/pPamsukula.html',
    'assets/web/par/sti/text/pAdiya.html',
    'assets/web/par/sti/text/pCatuti.html',
    'assets/web/par/sti/text/pEttavatatiadipattidana.html',
  ];

  static const List<String> parSti6 = [
    'assets/web/par/sti/p6.html',
    'assets/web/par/sti/text/pDhammacakka.html',
    'assets/web/par/sti/text/pAnatta.html',
    'assets/web/par/sti/text/pAditta.html',
    'assets/web/par/sti/text/pOvada.html',
    'assets/web/par/sti/text/pBala.html',
    'assets/web/par/sti/text/pSaraniya.html',
    'assets/web/par/sti/text/pDhammaniyama.html',
    'assets/web/par/sti/text/pTiro.html',
    'assets/web/par/sti/text/pNindhi.html',
    'assets/web/par/sti/text/pPaccaya.html',
    'assets/web/par/sti/text/pVijaya.html',
  ];

  static const List<String> parSti7 = [
    'assets/web/par/sti/p7.html',
    'assets/web/par/sti/text/raya/pRVisakha.html',
    'assets/web/par/sti/text/raya/pRAsalha.html',
    'assets/web/par/sti/text/raya/pRKathina.html',
    'assets/web/par/sti/text/raya/pRMagha.html',
  ];

  static const List<String> parSti8 = [
    'assets/web/par/sti/p8.html',
    'assets/web/par/sti/text/paki/pPKathina.html',
    'assets/web/par/sti/text/paki/pPCivaradussa.html',
    'assets/web/par/sti/text/paki/pPCivara.html',
    'assets/web/par/sti/text/paki/pPSangha.html',
    'assets/web/par/sti/text/paki/pPMataka.html',
    'assets/web/par/sti/text/paki/pPSenasana.html',
    'assets/web/par/sti/text/paki/pPPavara.html',
  ];

  static const List<String> parLCetiya = ['assets/web/par/lain/pCetiya.html'];
  static const List<String> parLImaya = ['assets/web/par/lain/pImaya.html'];
  static const List<String> parLPaticca = ['assets/web/par/lain/pPaticca.html'];
  static const List<String> parLAneka = ['assets/web/par/lain/pAneka.html'];
  static const List<String> parLPacca = ['assets/web/par/lain/pPacca.html'];
  static const List<String> parLMaha = ['assets/web/par/lain/pMaha.html'];
  static const List<String> parLYuddeso = ['assets/web/par/lain/pYuddeso.html'];
  static const List<String> parLYaniddeso = [
    'assets/web/par/lain/pYaniddeso.html',
  ];

  static const List<String> parLDBS1 = ['assets/web/par/lain/dbs/pOpen.html'];
  static const List<String> parLDBS2 = ['assets/web/par/lain/dbs/pClose.html'];

  static const List<String> parLDKS1 = ['assets/web/par/lain/dbs/pOpen.html'];
  static const List<String> parLDKS2 = ['assets/web/par/lain/dbs/pClose.html'];

  static const List<String> parLYasati1 = [
    'assets/web/par/lain/yasati/pOpen.html',
  ];
  static const List<String> parLYasati2 = [
    'assets/web/par/lain/yasati/pClose.html',
  ];

  static const List<String> parLPA1 = ['assets/web/par/lain/patvdh/pOpen.html'];
  static const List<String> parLPA2 = [
    'assets/web/par/lain/patvdh/pClose.html',
  ];
  // Nanti tambah kategori lain di sini
}
