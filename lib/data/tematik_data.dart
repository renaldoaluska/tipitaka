// lib/data/tematik_data.dart

class TematikData {
  // ===== TAMBAHAN BARU: URL mapping untuk webview =====
  static const Map<String, String> webviewUrls = {
    "apaitutematik":
        "https://tipitakaindonesia.blogspot.com/p/tematik-new.html",
    "prakata": "https://tipitakaindonesia.blogspot.com/p/tematik-prakata.html",
    "pendahuluanUmum":
        "https://tipitakaindonesia.blogspot.com/p/tematik-pendahuluan-umum.html",
    "pendahuluan1":
        "https://tipitakaindonesia.blogspot.com/p/tematik-pendahuluan1.html",
    "pendahuluan2":
        "https://tipitakaindonesia.blogspot.com/p/tematik-pendahuluan2.html",
    "pendahuluan3":
        "https://tipitakaindonesia.blogspot.com/p/tematik-pendahuluan3.html",
    "pendahuluan4":
        "https://tipitakaindonesia.blogspot.com/p/tematik-pendahuluan4.html",
    "pendahuluan5":
        "https://tipitakaindonesia.blogspot.com/p/tematik-pendahuluan5.html",
    "pendahuluan6":
        "https://tipitakaindonesia.blogspot.com/p/tematik-pendahuluan6.html",
    "pendahuluan7":
        "https://tipitakaindonesia.blogspot.com/p/tematik-pendahuluan7.html",
    "pendahuluan8":
        "https://tipitakaindonesia.blogspot.com/p/tematik-pendahuluan8.html",
    "pendahuluan9":
        "https://tipitakaindonesia.blogspot.com/p/tematik-pendahuluan9.html",
    "pendahuluan10":
        "https://tipitakaindonesia.blogspot.com/p/tematik-pendahuluan10.html",
  };
  // ===== AKHIR TAMBAHAN =====

  static const List<Map<String, String>> mainMenu = [
    {"title": "Pengenalan Fitur", "desc": "Panduan menggunakan fitur tematik"},
    {"title": "Prakata & Pendahuluan", "desc": "Bhikkhu Bodhi"},
    {"title": "Keadaan Manusia", "desc": "Realitas kehidupan dan saṃsāra"},
    {"title": "Pembawa Cahaya", "desc": "Kelahiran dan pencerahan Buddha"},
    {"title": "Pendekatan Dhamma", "desc": "Cara memahami ajaran Buddha"},
    {"title": "Kebahagiaan Sekarang", "desc": "Dhamma untuk kehidupan sosial"},
    {
      "title": "Punarbawa Bahagia",
      "desc": "Kamma dan kelahiran kembali yang baik",
    },
    {"title": "Pandangan Dunia", "desc": "Memahami dunia dengan benar"},
    {"title": "Jalan Pembebasan", "desc": "Memasuki jalan menuju nibbāna"},
    {"title": "Penguasaan Pikiran", "desc": "Meditasi dan latihan pikiran"},
    {"title": "Cahaya Kebijaksanaan", "desc": "Mengembangkan paññā"},
    {"title": "Tingkat Pencerahan", "desc": "Empat tingkat orang mulia"},
  ];

  static Map<String, dynamic> getChapterDetail(int chapterIndex) {
    // ... SISA KODE TETAP SAMA seperti yang asli ...
    switch (chapterIndex) {
      case 0:
        return {
          "title": "Pengenalan Fitur",
          "items": [
            {
              "section": "",
              "name": "Penjelasan singkat",
              "desc": "Apa itu tematik?",
              "code": "",
            },
            {
              "section": "",
              "name": "ReadingFaithfully.org",
              "desc": "Postingan sumber (Inggris)",
              "code": "",
            },
            //  {
            //   "section": "",
            //  "name": "Unduh daftar ceklis",
            // "desc": "Berukuran A4 (Inggris)",
            //"code": "",
            // },
          ],
        };

      case 1:
        return {
          "title": "Prakata dan Pendahuluan Umum",
          "items": [
            {
              "section": "",
              "name": "Prakata",
              "desc": "oleh Bhikkhu Bodhi",
              "code": "",
            },
            {
              "section": "",
              "name": "Pendahuluan Umum",
              "desc": "oleh Bhikkhu Bodhi",
              "code": "",
            },
          ],
        };

      // ... SEMUA CASE LAINNYA TETAP SAMA ...

      case 2:
        return {
          "title": "I. Keadaan Manusia",
          "items": [
            {
              "section": "",
              "name": "Pendahuluan I",
              "desc": "oleh Bhikkhu Bodhi",
              "code": "",
            },

            {
              "section": "Usia Tua, Sakit, dan Mati",
              "name": "Penuaan dan Kematian",
              "desc": "",
              "code": "SN 3.3",
            },
            {
              "section": "Usia Tua, Sakit, dan Mati",
              "name": "Perumpamaan Gunung",
              "desc": "",
              "code": "SN 3.25",
            },
            {
              "section": "Usia Tua, Sakit, dan Mati",
              "name": "Utusan Surgawi",
              "desc": "",
              "code": "AN 3.35",
            },

            {
              "section": "Sengsara Akibat Tak Mawas",
              "name": "Anak Panah Perasaan Menyakitkan",
              "desc": "",
              "code": "SN 36.6",
            },
            {
              "section": "Sengsara Akibat Tak Mawas",
              "name": "Perubahan dalam Kehidupan",
              "desc": "",
              "code": "AN 8.6",
            },
            {
              "section": "Sengsara Akibat Tak Mawas",
              "name": "Kekhawatiran Karena Perubahan",
              "desc": "",
              "code": "SN 22.7",
            },

            {
              "section": "Dunia dalam Kekisruhan",
              "name": "Asal-mula Konflik",
              "desc": "",
              "code": "AN 2.37",
            },
            {
              "section": "Dunia dalam Kekisruhan",
              "name": "Mengapakah Makhluk-makhluk Hidup dalam Kebencian?",
              "desc": "",
              "code": "DN 21",
            },
            {
              "section": "Dunia dalam Kekisruhan",
              "name": "Mata Rantai Gelap dari Sebab-Akibat",
              "desc": "",
              "code": "DN 15",
            },
            {
              "section": "Dunia dalam Kekisruhan",
              "name": "Akar Kekerasan dan Penindasan",
              "desc": "",
              "code": "AN 3.69",
            },

            {
              "section": "Saṃsāra Tanpa Awal",
              "name": "Rumput dan Ranting",
              "desc": "",
              "code": "SN 15.1",
            },
            {
              "section": "Saṃsāra Tanpa Awal",
              "name": "Bola-bola Tanah",
              "desc": "",
              "code": "SN 15.2",
            },
            {
              "section": "Saṃsāra Tanpa Awal",
              "name": "Gunung",
              "desc": "",
              "code": "SN 15.5",
            },
            {
              "section": "Saṃsāra Tanpa Awal",
              "name": "Sungai Gangga",
              "desc": "",
              "code": "SN 15.8",
            },
            {
              "section": "Saṃsāra Tanpa Awal",
              "name": "Anjing yang Terikat",
              "desc": "",
              "code": "SN 22.99",
            },
          ],
        };

      case 3:
        return {
          "title": "II. Pembawa Cahaya",
          "items": [
            {
              "section": "",
              "name": "Pendahuluan II",
              "desc": "oleh Bhikkhu Bodhi",
              "code": "",
            },
            {
              "section": "Satu Orang",
              "name": "Satu Orang",
              "desc": "",
              "code": "AN 1.170-187",
            },
            {
              "section": "Kelahiran Sang Buddha",
              "name": "Kelahiran Sang Buddha",
              "desc": "",
              "code": "MN 123",
            },

            {
              "section": "Usaha Mencapai Kecerahan",
              "name": "Mencari Kondisi Kedamaian Luhur Tertinggi",
              "desc": "",
              "code": "MN 26",
            },
            {
              "section": "Usaha Mencapai Kecerahan",
              "name": "Pencapaian Tiga Pengetahuan Sejati",
              "desc": "",
              "code": "MN 36",
            },
            {
              "section": "Usaha Mencapai Kecerahan",
              "name": "Kota Tua",
              "desc": "",
              "code": "SN 12.65",
            },

            {
              "section": "Keputusan Mengajar",
              "name": "Keputusan Mengajar",
              "desc": "",
              "code": "MN 26",
            },
            {
              "section": "Khotbah Pertama",
              "name": "Khotbah Pertama",
              "desc": "",
              "code": "SN 56.11",
            },
          ],
        };

      case 4:
        return {
          "title": "III. Pendekatan Dhamma",
          "items": [
            {
              "section": "",
              "name": "Pendahuluan III",
              "desc": "oleh Bhikkhu Bodhi",
              "code": "",
            },
            {
              "section": "Bukan Doktrin Rahasia",
              "name": "Bukan Doktrin Rahasia",
              "desc": "",
              "code": "AN 3.131",
            },
            {
              "section": "Tanpa Dogma",
              "name": "Tanpa Dogma ataupun Kepercayaan Membuta",
              "desc": "",
              "code": "AN 3.65",
            },
            {
              "section": "Asal dan Henti Derita",
              "name": "Asal dan Hentinya Penderitaan",
              "desc": "",
              "code": "SN 42.11",
            },
            {
              "section": "Telitilah Sang Guru",
              "name": "Telitilah Sang Guru",
              "desc": "",
              "code": "MN 47",
            },
            {
              "section": "Jalan Menuju Realisasi Kebenaran",
              "name": "Jalan Menuju Realisasi Kebenaran",
              "desc": "",
              "code": "MN 95",
            },
          ],
        };

      case 5:
        return {
          "title": "IV. Kebahagiaan Sekarang",
          "items": [
            {
              "section": "",
              "name": "Pendahuluan IV",
              "desc": "oleh Bhikkhu Bodhi",
              "code": "",
            },

            {
              "section": "Junjung Tinggi Dhamma",
              "name": "Raja Dhamma",
              "desc": "",
              "code": "AN 3.14",
            },
            {
              "section": "Junjung Tinggi Dhamma",
              "name": "Memuja Enam Arah",
              "desc": "",
              "code": "DN 31",
            },

            {
              "section": "Keluarga:\nOrang Tua dan Anak",
              "name": "Hormat kepada Orang Tua",
              "desc": "",
              "code": "AN 4.63",
            },
            {
              "section": "Keluarga:\nOrang Tua dan Anak",
              "name": "Membalas Budi Orang Tua",
              "desc": "",
              "code": "AN 2.33",
            },

            {
              "section": "Keluarga:\nSuami dan Istri",
              "name": "Aneka Jenis Pernikahan",
              "desc": "",
              "code": "AN 4.53",
            },
            {
              "section": "Keluarga:\nSuami dan Istri",
              "name": "Bagaimana agar Bersatu dalam Kehidupan Mendatang",
              "desc": "",
              "code": "AN 4.55",
            },
            {
              "section": "Keluarga:\nSuami dan Istri",
              "name": "Tujuh Jenis Istri",
              "desc": "",
              "code": "AN 7.63",
            },

            {
              "section": "Sejahtera Kini dan Nanti",
              "name": "Sejahtera Kini dan Nanti",
              "desc": "",
              "code": "AN 8.54",
            },

            {
              "section": "Penghidupan Benar",
              "name": "Menghindari Berpenghidupan Salah",
              "desc": "",
              "code": "AN 5.177",
            },
            {
              "section": "Penghidupan Benar",
              "name": "Pemanfaatan Kekayaan Secara Tepat",
              "desc": "",
              "code": "AN 4.61",
            },
            {
              "section": "Penghidupan Benar",
              "name": "Kebahagiaan Perumah Tangga",
              "desc": "",
              "code": "AN 4.62",
            },

            {
              "section": "Ibu Rumah Tangga",
              "name": "Ibu Rumah Tangga",
              "desc": "",
              "code": "AN 8.49",
            },

            {
              "section": "Masyarakat",
              "name": "Enam Akar Perselisihan",
              "desc": "",
              "code": "MN 104",
            },
            {
              "section": "Masyarakat",
              "name": "Enam Asas Kehangatan",
              "desc": "",
              "code": "MN 104",
            },
            {
              "section": "Masyarakat",
              "name": "Kemuliaan Berlaku Bagi Semua Kasta",
              "desc": "",
              "code": "MN 93",
            },
            {
              "section": "Masyarakat",
              "name": "Tujuh Asas Stabilitas Sosial",
              "desc": "",
              "code": "DN 16",
            },
            {
              "section": "Masyarakat",
              "name": "Raja Pemutar-Roda",
              "desc": "",
              "code": "DN 26",
            },
            {
              "section": "Masyarakat",
              "name": "Membawa Ketenangan Bagi Negeri",
              "desc": "",
              "code": "DN 5",
            },
          ],
        };

      case 6:
        return {
          "title": "V. Punarbawa Bahagia",
          "items": [
            {
              "section": "",
              "name": "Pendahuluan V",
              "desc": "oleh Bhikkhu Bodhi",
              "code": "",
            },

            {
              "section": "Hukum Kamma",
              "name": "Pertanyaan Singkat-Jawaban Panjang",
              "desc": "",
              "code": "MN 135",
            },
            {
              "section": "Hukum Kamma",
              "name": "Jalur Perbedaan Kamma",
              "desc": "",
              "code": "AN 4.237",
            },
            {
              "section": "Hukum Kamma",
              "name": "Empat Jenis Orang",
              "desc": "",
              "code": "AN 4.85",
            },

            {
              "section": "Kebajikan (Puñña)",
              "name": "Tiga Hal Membawa Kebahagiaan",
              "desc": "",
              "code": "AN 8.35",
            },
            {
              "section": "Kebajikan (Puñña)",
              "name": "Limpahan Kebajikan",
              "desc": "",
              "code": "AN 8.36",
            },

            {
              "section": "Bederma (Dāna)",
              "name": "Pemberian",
              "desc": "",
              "code": "AN 7.49",
            },
            {
              "section": "Bederma (Dāna)",
              "name": "Kekayaan Sejati",
              "desc": "",
              "code": "SN 1.33",
            },
            {
              "section": "Bederma (Dāna)",
              "name": "Ladang Kebajikan Tertinggi",
              "desc": "",
              "code": "AN 4.39",
            },

            {
              "section": "Moralitas (Sīla)",
              "name": "Moral Sempurna",
              "desc": "",
              "code": "DN 2",
            },
            {
              "section": "Moralitas (Sīla)",
              "name": "Moralitas dan Kebahagiaan",
              "desc": "",
              "code": "SN 55.7",
            },
            {
              "section": "Moralitas (Sīla)",
              "name": "Lima Latihan",
              "desc": "",
              "code": "AN 8.39",
            },
            {
              "section": "Moralitas (Sīla)",
              "name": "Uposatha Delapan Unsur",
              "desc": "",
              "code": "AN 8.41",
            },

            {
              "section": "Meditasi (Bhāvanā)",
              "name": "Dua Jenis Bahagia",
              "desc": "",
              "code": "AN 2.65",
            },
            {
              "section": "Meditasi (Bhāvanā)",
              "name": "Jhāna Pertama",
              "desc": "",
              "code": "MN 27",
            },
            {
              "section": "Meditasi (Bhāvanā)",
              "name": "Empat Jhāna",
              "desc": "",
              "code": "MN 39",
            },
          ],
        };

      case 7:
        return {
          "title": "VI. Pandangan Dunia",
          "items": [
            {
              "section": "",
              "name": "Pendahuluan VI",
              "desc": "oleh Bhikkhu Bodhi",
              "code": "",
            },
            {
              "section": "Empat Hal Menakjubkan",
              "name": "Empat Hal Menakjubkan",
              "desc": "",
              "code": "AN 4.36",
            },

            {
              "section": "Pemuasan dan Jalan Keluar",
              "name": "Sumber Kesenangan",
              "desc": "",
              "code": "SN 12.66",
            },
            {
              "section": "Pemuasan dan Jalan Keluar",
              "name": "Tiga Karakteristik",
              "desc": "",
              "code": "AN 3.136",
            },

            {
              "section": "Objek Pelekatan",
              "name": "Objek Pelekatan",
              "desc": "",
              "code": "MN 109",
            },

            {
              "section": "Perangkap Indrawi",
              "name": "Perangkap Ketergantungan",
              "desc": "",
              "code": "MN 13",
            },
            {
              "section": "Perangkap Indrawi",
              "name": "Benang-benang Indrawi",
              "desc": "",
              "code": "SN 35.247",
            },

            {
              "section": "Hidup Singkat dan Fana",
              "name": "Kehidupan Singkat",
              "desc": "",
              "code": "AN 7.70",
            },
            {
              "section": "Hidup Singkat dan Fana",
              "name": "Busa dan Bayang-bayang",
              "desc": "",
              "code": "SN 22.95",
            },

            {
              "section": "Empat Ringkasan Dhamma",
              "name": "Empat Ringkasan Dhamma",
              "desc": "",
              "code": "AN 4.50",
            },

            {
              "section": "Pandangan Berbahaya (Diṭṭhi)",
              "name": "Jaring Pandangan",
              "desc": "",
              "code": "DN 1",
            },
            {
              "section": "Pandangan Berbahaya (Diṭṭhi)",
              "name": "Dalil Eternalis dan Annihilasionalis",
              "desc": "",
              "code": "MN 22",
            },

            {
              "section": "Alam Dewa dan Alam Rendah",
              "name": "Tiga Puluh Tiga Dewa",
              "desc": "",
              "code": "DN 21",
            },
            {
              "section": "Alam Dewa dan Alam Rendah",
              "name": "Alam Duka",
              "desc": "",
              "code": "MN 129",
            },

            {
              "section": "Bahaya Saṃsāra",
              "name": "Bahaya Saṃsāra",
              "desc": "",
              "code": "SN 56.35-47",
            },
          ],
        };

      case 8:
        return {
          "title": "VII. Jalan Pembebasan",
          "items": [
            {
              "section": "",
              "name": "Pendahuluan VII",
              "desc": "oleh Bhikkhu Bodhi",
              "code": "",
            },

            {
              "section": "Mengapa Memasuki Jalan?",
              "name": "Pencarian Terhina dan Pencarian Termulia",
              "desc": "",
              "code": "MN 26",
            },
            {
              "section": "Mengapa Memasuki Jalan?",
              "name": "Kecemerlangan",
              "desc": "",
              "code": "SN 56.11",
            },

            {
              "section": "Jalan Mulia Berunsur Delapan",
              "name": "Jalan Menuju Nibbāna",
              "desc": "",
              "code": "SN 45.8",
            },
            {
              "section": "Jalan Mulia Berunsur Delapan",
              "name": "Jalan Tengah",
              "desc": "",
              "code": "SN 56.11",
            },

            {
              "section": "Persahabatan Baik",
              "name": "Persahabatan Baik",
              "desc": "",
              "code": "SN 45.2",
            },

            {
              "section": "Latihan Bertahap",
              "name": "Dengan Keyakinan Puncak",
              "desc": "",
              "code": "MN 38",
            },
            {
              "section": "Latihan Bertahap",
              "name": "Dua Gagasan",
              "desc": "",
              "code": "AN 2.31",
            },

            {
              "section": "Latihan Lanjutan",
              "name": "Pikiran Pembebas",
              "desc": "",
              "code": "MN 19",
            },
            {
              "section": "Latihan Lanjutan",
              "name": "Perhatian dan Pemahaman Jernih",
              "desc": "",
              "code": "SN 47.35",
            },
          ],
        };

      case 9:
        return {
          "title": "VIII. Penguasaan Pikiran",
          "items": [
            {
              "section": "",
              "name": "Pendahuluan VIII",
              "desc": "oleh Bhikkhu Bodhi",
              "code": "",
            },
            {
              "section": "Pikiran Kuncinya",
              "name": "Pikiran Kuncinya",
              "desc": "",
              "code": "Dhp 1-2",
            },

            {
              "section": "Pengembangan Kecakapan",
              "name": "Lima Hambatan",
              "desc": "",
              "code": "SN 46.51",
            },
            {
              "section": "Pengembangan Kecakapan",
              "name": "Tujuh Faktor Pencerahan",
              "desc": "",
              "code": "SN 46.3",
            },

            {
              "section": "Rintangan Batin",
              "name": "Rintangan Batin",
              "desc": "",
              "code": "MN 20",
            },
            {
              "section": "Pemurnian Pikiran",
              "name": "Pemurnian Pikiran",
              "desc": "",
              "code": "AN 10.51",
            },
            {
              "section": "Pikiran Pengganggu",
              "name": "Pikiran Pengganggu",
              "desc": "",
              "code": "SN 35.246",
            },
            {
              "section": "Pikiran Cinta Kasih",
              "name": "Pikiran Cinta Kasih",
              "desc": "",
              "code": "MN 21",
            },
            {
              "section": "Enam Perenungan",
              "name": "Enam Perenungan",
              "desc": "",
              "code": "AN 6.29",
            },
            {
              "section": "Empat Landasan Perhatian",
              "name": "Empat Landasan Perhatian",
              "desc": "",
              "code": "MN 10",
            },
            {
              "section": "Perhatian Pada Napas",
              "name": "Perhatian Pada Napas",
              "desc": "",
              "code": "MN 118",
            },
            {
              "section": "Tercapainya Penguasaan",
              "name": "Tercapainya Penguasaan",
              "desc": "",
              "code": "MN 119",
            },
          ],
        };

      case 10:
        return {
          "title": "IX. Cahaya Kebijaksanaan",
          "items": [
            {
              "section": "",
              "name": "Pendahuluan IX",
              "desc": "oleh Bhikkhu Bodhi",
              "code": "",
            },
            {
              "section": "Citra Kebijaksanaan",
              "name": "Citra Kebijaksanaan",
              "desc": "",
              "code": "MN 2",
            },
            {
              "section": "Syarat Kebijaksanaan",
              "name": "Syarat Kebijaksanaan",
              "desc": "",
              "code": "AN 5.24",
            },
            {
              "section": "Pandangan Benar",
              "name": "Pandangan Benar",
              "desc": "",
              "code": "MN 9",
            },

            {
              "section": "Lingkup Kebijaksanaan",
              "name": "Lima Kelompok",
              "desc": "",
              "code": "SN 22.59",
            },
            {
              "section": "Lingkup Kebijaksanaan",
              "name": "Enam Landasan Indriawi",
              "desc": "",
              "code": "SN 35.23",
            },
            {
              "section": "Lingkup Kebijaksanaan",
              "name": "Elemen dan Landasan Indriawi",
              "desc": "",
              "code": "MN 140",
            },
            {
              "section": "Lingkup Kebijaksanaan",
              "name": "Kemunculan Bergantungan",
              "desc": "",
              "code": "SN 12.2",
            },

            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tujuan Kebijaksanaan",
              "desc": "",
              "code": "MN 1",
            },
          ],
        };

      case 11:
        return {
          "title": "X. Tingkat Pencerahan",
          "items": [
            {
              "section": "",
              "name": "Pendahuluan X",
              "desc": "oleh Bhikkhu Bodhi",
              "code": "",
            },
            {
              "section": "Ladang Kebajikan Dunia",
              "name": "Ladang Kebajikan Dunia",
              "desc": "",
              "code": "AN 8.59",
            },

            {
              "section": "Pemasuk-Arus (Sotāpanna)",
              "name": "Empat Faktor Pemasuk-Arus",
              "desc": "",
              "code": "SN 55.5",
            },
            {
              "section": "Pemasuk-Arus (Sotāpanna)",
              "name": "Sariputta dan Pemasuk-Arus",
              "desc": "",
              "code": "SN 55.53",
            },

            {
              "section": "Yang-Tak-Kembali (Anāgāmi)",
              "name": "Yang-Tak-Kembali (Anāgāmi)",
              "desc": "",
              "code": "AN 5.179",
            },

            {
              "section": "Arahā (Arahat)",
              "name": "Delapan Ciri Arahat",
              "desc": "",
              "code": "AN 8.19",
            },
            {
              "section": "Arahā (Arahat)",
              "name": "Empat Puluh Empat Faktor Arahat",
              "desc": "",
              "code": "MN 77",
            },
            {
              "section": "Arahā (Arahat)",
              "name": "Tidak Ada Lagi Masa Depan",
              "desc": "",
              "code": "MN 140",
            },

            {
              "section": "Tathāgata",
              "name": "Melampaui Spekulasi",
              "desc": "",
              "code": "MN 72",
            },
            {
              "section": "Tathāgata",
              "name": "Laut Dalam",
              "desc": "",
              "code": "AN 4.198",
            },
          ],
        };

      default:
        return {"title": "", "items": []};
    }
  }

  static String parseSuttaCode(String code) {
    if (code.isEmpty) return "";
    return code.toLowerCase().replaceAll(" ", "");
  }
}
