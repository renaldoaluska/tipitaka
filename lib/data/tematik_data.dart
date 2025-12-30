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
    {"title": "Mendatangi Dhamma", "desc": "Cara memahami ajaran Buddha"},
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
          "title": "I. Kondisi Dunia",
          "items": [
            {
              "section": "",
              "name": "Pendahuluan I",
              "desc": "oleh Bhikkhu Bodhi",
              "code": "",
            },

            {
              "section": "Usia Tua, Penyakit, dan Kematian",
              "name": "Penuaan dan Kematian",
              "desc": "",
              "code": "SN 3.3",
            },
            {
              "section": "Usia Tua, Penyakit, dan Kematian",
              "name": "Perumpamaan Gunung",
              "desc": "",
              "code": "SN 3.25",
            },
            {
              "section": "Usia Tua, Penyakit, dan Kematian",
              "name": "Utusan Surgawi",
              "desc": "",
              "code": "AN 3.35",
            },

            {
              "section": "Kesengsaraan Kehidupan Tanpa Perenungan",
              "name": "Anak Panah Perasaan Menyakitkan",
              "desc": "",
              "code": "SN 36.6",
            },
            {
              "section": "Kesengsaraan Kehidupan Tanpa Perenungan",
              "name": "Perubahan dalam Kehidupan",
              "desc": "",
              "code": "AN 8.6",
            },
            {
              "section": "Kesengsaraan Kehidupan Tanpa Perenungan",
              "name": "Kekhawatiran Karena Perubahan",
              "desc": "",
              "code": "SN 22.7",
            },

            {
              "section": "Dunia dalam Kekacauan",
              "name": "Asal-mula Konflik",
              "desc": "",
              "code": "AN 2.37",
            },
            {
              "section": "Dunia dalam Kekacauan",
              "name": "Mengapakah Makhluk-makhluk Hidup dalam Kebencian?",
              "desc": "",
              "code": "DN 21",
            },
            {
              "section": "Dunia dalam Kekacauan",
              "name": "Mata Rantai Gelap dari Sebab-Akibat",
              "desc": "",
              "code": "DN 15",
            },
            {
              "section": "Dunia dalam Kekacauan",
              "name": "Akar Kekerasan dan Penindasan",
              "desc": "",
              "code": "AN 3.69",
            },

            {
              "section": "Tanpa Awal Yang Dapat Ditemukan",
              "name": "Rumput dan Ranting",
              "desc": "",
              "code": "SN 15.1",
            },
            {
              "section": "Tanpa Awal Yang Dapat Ditemukan",
              "name": "Bola-bola Tanah",
              "desc": "",
              "code": "SN 15.2",
            },
            {
              "section": "Tanpa Awal Yang Dapat Ditemukan",
              "name": "Gunung",
              "desc": "",
              "code": "SN 15.5",
            },
            {
              "section": "Tanpa Awal Yang Dapat Ditemukan",
              "name": "Sungai Gangga",
              "desc": "",
              "code": "SN 15.8",
            },
            {
              "section": "Tanpa Awal Yang Dapat Ditemukan",
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
              "section": "Konsepsi dan Kelahiran Sang Buddha",
              "name": "Konsepsi dan Kelahiran Sang Buddha",
              "desc": "",
              "code": "MN 123",
            },

            {
              "section": "Pencarian Pencerahan",
              "name": "Mencari Kondisi Kedamaian Luhur Tertinggi",
              "desc": "",
              "code": "MN 26",
            },
            {
              "section": "Pencarian Pencerahan",
              "name": "Pencapaian Tiga Pengetahuan Sejati",
              "desc": "",
              "code": "MN 36",
            },
            {
              "section": "Pencarian Pencerahan",
              "name": "Kota Tua",
              "desc": "",
              "code": "SN 12.65",
            },

            {
              "section": "Keputusan Untuk Mengajar",
              "name": "Keputusan Untuk Mengajar",
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
          "title": "III. Mendatangi Dhamma",
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
              "section": "Tanpa Dogma atau Kepercayaan Membuta",
              "name": "Tanpa Dogma atau Kepercayaan Membuta",
              "desc": "",
              "code": "AN 3.65",
            },
            {
              "section": "Asal-Mula Yang Terlihat dan Lenyapnya Penderitaan",
              "name": "Asal-Mula Yang Terlihat dan Lenyapnya Penderitaan",
              "desc": "",
              "code": "SN 42.11",
            },
            {
              "section": "Menyelidiki Sang Guru Sendiri",
              "name": "Menyelidiki Sang Guru Sendiri",
              "desc": "",
              "code": "MN 47",
            },
            {
              "section": "Langkah Menuju Penembusan Kebenaran",
              "name": "Langkah Menuju Penembusan Kebenaran",
              "desc": "",
              "code": "MN 95",
            },
          ],
        };

      case 5:
        return {
          "title": "IV. Kebahagiaan Hidup Ini",
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
              "name": "Empat Jenis Kamma",
              "desc": "",
              "code": "AN 4.232",
            },
            {
              "section": "Hukum Kamma",
              "name": "Mengapa Makhluk-makhluk Mengembara Setelah Kematian",
              "desc": "",
              "code": "MN 41",
            },
            {
              "section": "Hukum Kamma",
              "name": "Kamma dan Buahnya",
              "desc": "",
              "code": "MN 135",
            },

            {
              "section": "Jasa Kebajikan (Puñña)",
              "name": "Perbuatan Baik",
              "desc": "",
              "code": "Iti 22",
            },
            {
              "section": "Jasa Kebajikan (Puñña)",
              "name": "Tiga Landasan Jasa",
              "desc": "",
              "code": "AN 8.36",
            },
            {
              "section": "Jasa Kebajikan (Puñña)",
              "name": "Jenis Keyakinan Terbaik",
              "desc": "",
              "code": "AN 4.34",
            },

            {
              "section": "Memberi (Dāna)",
              "name": "Jika Orang-orang Mengetahui Akibat dari Memberi",
              "desc": "",
              "code": "Iti 26",
            },
            {
              "section": "Memberi (Dāna)",
              "name": "Alasan-alasan Memberi",
              "desc": "",
              "code": "AN 8.33",
            },
            {
              "section": "Memberi (Dāna)",
              "name": "Pemberian Makanan",
              "desc": "",
              "code": "AN 4.57",
            },
            {
              "section": "Memberi (Dāna)",
              "name": "Persembahan Seorang Besar",
              "desc": "",
              "code": "AN 5.148",
            },
            {
              "section": "Memberi (Dāna)",
              "name": "Saling Menyokong",
              "desc": "",
              "code": "Iti 107",
            },
            {
              "section": "Memberi (Dāna)",
              "name": "Kelahiran Kembali Karena Memberi",
              "desc": "",
              "code": "AN 8.35",
            },

            {
              "section": "Disiplin Moral (Sīla)",
              "name": "Lima Sila",
              "desc": "",
              "code": "AN 8.39",
            },
            {
              "section": "Disiplin Moral (Sīla)",
              "name": "Pelaksanaan Uposatha",
              "desc": "",
              "code": "AN 8.41",
            },

            {
              "section": "Meditasi (Bhāvanā)",
              "name": "Pengembangan Cinta Kasih",
              "desc": "",
              "code": "Iti 27",
            },
            {
              "section": "Meditasi (Bhāvanā)",
              "name": "Empat Kediaman Luhur",
              "desc": "",
              "code": "MN 99",
            },
            {
              "section": "Meditasi (Bhāvanā)",
              "name": "Pandangan Terang Melampaui Segalanya",
              "desc": "",
              "code": "AN 9.20",
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
              "section": "Empat Hal Mengagumkan",
              "name": "Empat Hal Mengagumkan",
              "desc": "",
              "code": "AN 4.128",
            },

            {
              "section": "Kepuasan, Bahaya, dan Jalan Bebas",
              "name": "Sebelum Pencerahan-Ku",
              "desc": "",
              "code": "AN 3.103",
            },
            {
              "section": "Kepuasan, Bahaya, dan Jalan Bebas",
              "name": "Aku Melakukan Pencarian",
              "desc": "",
              "code": "AN 3.104",
            },
            {
              "section": "Kepuasan, Bahaya, dan Jalan Bebas",
              "name": "Jika Tidak Ada Kepuasan",
              "desc": "",
              "code": "AN 3.105",
            },

            {
              "section": "Dengan Benar Menilai Objek Kemelekatan",
              "name": "Dengan Benar Menilai Objek Kemelekatan",
              "desc": "",
              "code": "MN 13",
            },

            {
              "section": "Jebakan Kenikmatan Indrawi",
              "name": "Memotong Segala Urusan",
              "desc": "",
              "code": "MN 54",
            },
            {
              "section": "Jebakan Kenikmatan Indrawi",
              "name": "Demam Kenikmatan Indrawi",
              "desc": "",
              "code": "MN 75",
            },

            {
              "section": "Hidup Singkat dan Berlalu Cepat",
              "name": "Hidup Singkat dan Berlalu Cepat",
              "desc": "",
              "code": "AN 7.70",
            },

            {
              "section": "Empat Ringkasan Dhamma",
              "name": "Empat Ringkasan Dhamma",
              "desc": "",
              "code": "MN 82",
            },

            {
              "section": "Bahaya Dalam Pandangan (Diṭṭhi)",
              "name": "Bunga-rampai Pandangan Salah",
              "desc": "",
              "code": "AN 1.306-315",
            },
            {
              "section": "Bahaya Dalam Pandangan (Diṭṭhi)",
              "name": "Orang Buta dan Gajah",
              "desc": "",
              "code": "Ud 6.4",
            },
            {
              "section": "Bahaya Dalam Pandangan (Diṭṭhi)",
              "name": "Terkekang Dua Jenis Pandangan",
              "desc": "",
              "code": "Iti 49",
            },

            {
              "section": "Alam Dewa dan Alam Rendah",
              "name": "Alam Dewa dan Alam Rendah",
              "desc": "",
              "code": "AN 4.125",
            },

            {
              "section": "Bahaya Saṃsāra",
              "name": "Cucuran Air Mata",
              "desc": "",
              "code": "SN 15.3",
            },
            {
              "section": "Bahaya Saṃsāra",
              "name": "Cucuran Darah",
              "desc": "",
              "code": "SN 15.13",
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
              "name": "Panah Kelahiran, Penuaan, dan Kematian",
              "desc": "",
              "code": "MN 63",
            },
            {
              "section": "Mengapa Memasuki Jalan?",
              "name": "Inti Kehidupan Mulia",
              "desc": "",
              "code": "MN 29",
            },
            {
              "section": "Mengapa Memasuki Jalan?",
              "name": "Lenyapnya Nafsu (1)",
              "desc": "",
              "code": "SN 45.41",
            },
            {
              "section": "Mengapa Memasuki Jalan?",
              "name": "Lenyapnya Nafsu (2)",
              "desc": "",
              "code": "SN 45.42-47",
            },
            {
              "section": "Mengapa Memasuki Jalan?",
              "name": "Lenyapnya Nafsu (3)",
              "desc": "",
              "code": "SN 45.48",
            },

            {
              "section": "Jalan Mulia Berunsur Delapan",
              "name": "Jalan Mulia Berunsur Delapan",
              "desc": "",
              "code": "SN 45.8",
            },

            {
              "section": "Persahabatan Baik",
              "name": "Persahabatan Baik",
              "desc": "",
              "code": "SN 45.2",
            },

            {
              "section": "Latihan Bertahap",
              "name": "Latihan Bertahap",
              "desc": "",
              "code": "MN 27",
            },

            {
              "section": "Latihan Lanjutan",
              "name": "Latihan Lanjutan",
              "desc": "",
              "code": "MN 39",
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
              "code": "AN 1.21-30",
            },

            {
              "section": "Pengembangan Kecakapan",
              "name": "Keheningan dan Pandangan Terang",
              "desc": "",
              "code": "AN 2.31",
            },
            {
              "section": "Pengembangan Kecakapan",
              "name": "Empat Cara Mencapai Kemuliaan Arahat",
              "desc": "",
              "code": "AN 4.170",
            },
            {
              "section": "Pengembangan Kecakapan",
              "name": "Empat Jenis Orang",
              "desc": "",
              "code": "AN 4.94",
            },

            {
              "section": "Rintangan Batin",
              "name": "Rintangan Batin",
              "desc": "",
              "code": "SN 46.55",
            },
            {
              "section": "Pemurnian Pikiran",
              "name": "Pemurnian Pikiran",
              "desc": "",
              "code": "AN 3.101",
            },
            {
              "section": "Pikiran Pengganggu",
              "name": "Pikiran Pengganggu",
              "desc": "",
              "code": "MN 20",
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
              "code": "AN 6.10",
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
              "code": "SN 54.13",
            },
            {
              "section": "Tercapainya Penguasaan",
              "name": "Tercapainya Penguasaan (1)",
              "desc": "",
              "code": "SN 28.1",
            },
            {
              "section": "Tercapainya Penguasaan",
              "name": "Tercapainya Penguasaan (2)",
              "desc": "",
              "code": "SN 28.2",
            },
            {
              "section": "Tercapainya Penguasaan",
              "name": "Tercapainya Penguasaan (3)",
              "desc": "",
              "code": "SN 28.3",
            },
            {
              "section": "Tercapainya Penguasaan",
              "name": "Tercapainya Penguasaan (4)",
              "desc": "",
              "code": "SN 28.4",
            },
            {
              "section": "Tercapainya Penguasaan",
              "name": "Tercapainya Penguasaan (5)",
              "desc": "",
              "code": "SN 28.5",
            },
            {
              "section": "Tercapainya Penguasaan",
              "name": "Tercapainya Penguasaan (6)",
              "desc": "",
              "code": "SN 28.6",
            },
            {
              "section": "Tercapainya Penguasaan",
              "name": "Tercapainya Penguasaan (7)",
              "desc": "",
              "code": "SN 28.7",
            },
            {
              "section": "Tercapainya Penguasaan",
              "name": "Tercapainya Penguasaan (8)",
              "desc": "",
              "code": "SN 28.8",
            },
            {
              "section": "Tercapainya Penguasaan",
              "name": "Tercapainya Penguasaan (9)",
              "desc": "",
              "code": "SN 28.9",
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
              "name": "Kebijaksanaan sebagai Cahaya",
              "desc": "",
              "code": "AN 4.143",
            },
            {
              "section": "Citra Kebijaksanaan",
              "name": "Kebijaksanaan sebagai Pisau",
              "desc": "",
              "code": "MN 146",
            },

            {
              "section": "Syarat Kebijaksanaan",
              "name": "Syarat Kebijaksanaan",
              "desc": "",
              "code": "AN 8.2",
            },
            {
              "section": "Pandangan Benar",
              "name": "Pandangan Benar",
              "desc": "",
              "code": "MN 9",
            },

            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Lima Gugusan",
              "name": "Tahap-tahap Gugusan",
              "desc": "",
              "code": "SN 22.56",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Lima Gugusan",
              "name": "Tanya-Jawab Mengenai Gugusan (1)",
              "desc": "",
              "code": "SN 22.82",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Lima Gugusan",
              "name": "Tanya-Jawab Mengenai Gugusan (2)",
              "desc": "",
              "code": "MN 109",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Lima Gugusan",
              "name": "Ciri Tanpa-Aku",
              "desc": "",
              "code": "SN 22.59",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Lima Gugusan",
              "name": "Ketidakkekalan, Penderitaan, Tanpa-Aku",
              "desc": "",
              "code": "SN 22.45",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Lima Gugusan",
              "name": "Segumpal Buih",
              "desc": "",
              "code": "SN 22.95",
            },

            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Enam Landasan Indra",
              "name": "Pemahaman Penuh",
              "desc": "",
              "code": "SN 35.26",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Enam Landasan Indra",
              "name": "Terbakar",
              "desc": "",
              "code": "SN 35.28",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Enam Landasan Indra",
              "name": "Sesuai untuk Mencapai Nibbāna (1)",
              "desc": "",
              "code": "SN 35.147",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Enam Landasan Indra",
              "name": "Sesuai untuk Mencapai Nibbāna (2)",
              "desc": "",
              "code": "SN 35.148",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Enam Landasan Indra",
              "name": "Sesuai untuk Mencapai Nibbāna (3)",
              "desc": "",
              "code": "SN 35.149",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Enam Landasan Indra",
              "name": "Dunia Ini Kosong",
              "desc": "",
              "code": "SN 35.85",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Enam Landasan Indra",
              "name": "Kesadaran Juga Tanpa-Aku",
              "desc": "",
              "code": "SN 35.234",
            },

            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Unsur",
              "name": "Delapan Belas Unsur",
              "desc": "",
              "code": "SN 14.1",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Unsur",
              "name": "Empat Unsur (1)",
              "desc": "",
              "code": "SN 14.37",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Unsur",
              "name": "Empat Unsur (2)",
              "desc": "",
              "code": "SN 14.38",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Unsur",
              "name": "Empat Unsur (3)",
              "desc": "",
              "code": "SN 14.39",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Unsur",
              "name": "Enam Unsur",
              "desc": "",
              "code": "MN 140",
            },

            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Kemunculan Bersebab",
              "name": "Apakah Kemunculan Bersebab Itu?",
              "desc": "",
              "code": "SN 12.1",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Kemunculan Bersebab",
              "name": "Kestabilan Dhamma",
              "desc": "",
              "code": "SN 12.20",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Kemunculan Bersebab",
              "name": "Empat Puluh Empat Perihal Pengetahuan",
              "desc": "",
              "code": "SN 12.33",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Kemunculan Bersebab",
              "name": "Ajaran yang Berada di Tengah",
              "desc": "",
              "code": "SN 12.15",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Kemunculan Bersebab",
              "name": "Kesinambungan Kesadaran",
              "desc": "",
              "code": "SN 12.38",
            },
            {
              "section": "Lingkup Kebijaksanaan:\nMelalui Kemunculan Bersebab",
              "name": "Asal-Mula dan Lenyapnya Dunia",
              "desc": "",
              "code": "SN 12.44",
            },

            {
              "section":
                  "Lingkup Kebijaksanaan:\nMelalui Empat Kebenaran Mulia",
              "name": "Kebenaran dari Semua Buddha",
              "desc": "",
              "code": "SN 56.24",
            },
            {
              "section":
                  "Lingkup Kebijaksanaan:\nMelalui Empat Kebenaran Mulia",
              "name": "Empat Kebenaran yang Nyata",
              "desc": "",
              "code": "SN 56.20",
            },
            {
              "section":
                  "Lingkup Kebijaksanaan:\nMelalui Empat Kebenaran Mulia",
              "name": "Segenggam Daun",
              "desc": "",
              "code": "SN 56.31",
            },
            {
              "section":
                  "Lingkup Kebijaksanaan:\nMelalui Empat Kebenaran Mulia",
              "name": "Karena Tak Memahami",
              "desc": "",
              "code": "SN 56.21",
            },
            {
              "section":
                  "Lingkup Kebijaksanaan:\nMelalui Empat Kebenaran Mulia",
              "name": "Tebing",
              "desc": "",
              "code": "SN 56.42",
            },
            {
              "section":
                  "Lingkup Kebijaksanaan:\nMelalui Empat Kebenaran Mulia",
              "name": "Membuat Terobosan",
              "desc": "",
              "code": "SN 56.32",
            },
            {
              "section":
                  "Lingkup Kebijaksanaan:\nMelalui Empat Kebenaran Mulia",
              "name": "Hancurnya Kotoran Batin",
              "desc": "",
              "code": "SN 56.25",
            },

            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Apakah Nibbāna Itu?",
              "desc": "",
              "code": "SN 38.1",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (1)",
              "desc": "",
              "code": "SN 43.1",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (2)",
              "desc": "",
              "code": "SN 43.2",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (3)",
              "desc": "",
              "code": "SN 43.3",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (4)",
              "desc": "",
              "code": "SN 43.4",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (5)",
              "desc": "",
              "code": "SN 43.5",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (6)",
              "desc": "",
              "code": "SN 43.6",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (7)",
              "desc": "",
              "code": "SN 43.7",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (8)",
              "desc": "",
              "code": "SN 43.8",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (9)",
              "desc": "",
              "code": "SN 43.9",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (10)",
              "desc": "",
              "code": "SN 43.10",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (11)",
              "desc": "",
              "code": "SN 43.11",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (12)",
              "desc": "",
              "code": "SN 43.12",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (13)",
              "desc": "",
              "code": "SN 43.13",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (14)",
              "desc": "",
              "code": "SN 43.14-43",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Tiga Puluh Tiga Sinonim Nibbāna (15)",
              "desc": "",
              "code": "SN 43.44",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Itulah Dasarnya",
              "desc": "",
              "code": "Ud 8.1",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Yang Tak Terlahir",
              "desc": "",
              "code": "Ud 8.3",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Dua Unsur Nibbāna",
              "desc": "",
              "code": "Iti 44",
            },
            {
              "section": "Tujuan Kebijaksanaan",
              "name": "Api dan Samudra",
              "desc": "",
              "code": "MN 72",
            },
          ],
        };

      case 11:
        return {
          "title": "X. Tingkat Kemuliaan",
          "items": [
            {
              "section": "",
              "name": "Pendahuluan X",
              "desc": "oleh Bhikkhu Bodhi",
              "code": "",
            },

            {
              "section": "Ladang Jasa Kebajikan Bagi Dunia",
              "name": "Delapan Individu yang Layak Menerima Persembahan",
              "desc": "",
              "code": "AN 8.59",
            },
            {
              "section": "Ladang Jasa Kebajikan Bagi Dunia",
              "name": "Pembedaan Melalui Indra (1)",
              "desc": "",
              "code": "SN 48.18",
            },
            {
              "section": "Ladang Jasa Kebajikan Bagi Dunia",
              "name": "Pembedaan Melalui Indra (2)",
              "desc": "",
              "code": "SN 48.10",
            },
            {
              "section": "Ladang Jasa Kebajikan Bagi Dunia",
              "name": "Dalam Dhamma yang Telah Dibabarkan Sempurna",
              "desc": "",
              "code": "MN 22",
            },
            {
              "section": "Ladang Jasa Kebajikan Bagi Dunia",
              "name": "Ajaran Yang Lengkap",
              "desc": "",
              "code": "MN 73",
            },
            {
              "section": "Ladang Kebajikan Dunia",
              "name": "Tujuh Jenis Individu Mulia",
              "desc": "",
              "code": "MN 70",
            },

            {
              "section": "Pemasuk-Arus (Sotāpanna)",
              "name": "Empat Faktor yang Mengarahkan ke Pemasuk-Arus",
              "desc": "",
              "code": "SN 55.5",
            },
            {
              "section": "Pemasuk-Arus (Sotāpanna)",
              "name": "Memasuki Jalan Kebenaran yang Pasti",
              "desc": "",
              "code": "SN 25.1",
            },
            {
              "section": "Pemasuk-Arus (Sotāpanna)",
              "name": "Terobosan Mencapai Dhamma",
              "desc": "",
              "code": "SN 13.1",
            },
            {
              "section": "Pemasuk-Arus (Sotāpanna)",
              "name": "Empat Faktor Pemasuk-Arus",
              "desc": "",
              "code": "SN 55.2",
            },
            {
              "section": "Pemasuk-Arus (Sotāpanna)",
              "name": "Lebih Baik Daripada Kekuasaan Atas Bumi",
              "desc": "",
              "code": "SN 55.1",
            },

            {
              "section": "Yang-Tak-Kembali (Anāgāmi)",
              "name": "Meninggalkan Lima Belenggu Rendah",
              "desc": "",
              "code": "MN 64",
            },
            {
              "section": "Yang-Tak-Kembali (Anāgāmi)",
              "name": "Empat Jenis Orang",
              "desc": "",
              "code": "AN 4.169",
            },
            {
              "section": "Yang-Tak-Kembali (Anāgāmi)",
              "name": "Enam Hal yang Mengandung Pengetahuan Sejati",
              "desc": "",
              "code": "SN 55.3",
            },
            {
              "section": "Yang-Tak-Kembali (Anāgāmi)",
              "name": "Lima Jenis Yang-Tak-Kembali",
              "desc": "",
              "code": "SN 46.3",
            },

            {
              "section": "Arahat",
              "name": "Melenyapkan Keangkuhan 'Aku' Yang Tersisa",
              "desc": "",
              "code": "SN 22.89",
            },
            {
              "section": "Arahat",
              "name": "Siswa Yang Masih Berlatih dan Arahat",
              "desc": "",
              "code": "SN 48.53",
            },
            {
              "section": "Arahat",
              "name": "Bhikkhu yang Penghalangnya Telah Diangkat",
              "desc": "",
              "code": "MN 22",
            },
            {
              "section": "Arahat",
              "name": "Sembilan Hal yang Tak Mungkin Dilakukan Arahat",
              "desc": "",
              "code": "AN 9.7",
            },
            {
              "section": "Arahat",
              "name": "Pikiran yang Tak Tergoyahkan",
              "desc": "",
              "code": "AN 9.26",
            },
            {
              "section": "Arahat",
              "name": "Sepuluh Kekuatan Seorang Bhikkhu Arahat",
              "desc": "",
              "code": "AN 10.90",
            },
            {
              "section": "Arahat",
              "name": "Sang Bijaksana Yang Damai",
              "desc": "",
              "code": "MN 140",
            },
            {
              "section": "Arahat",
              "name": "Sungguh Bahagia Para Arahat",
              "desc": "",
              "code": "SN 22.76",
            },

            {
              "section": "Tathāgata",
              "name": "Sang Buddha dan Para Arahat",
              "desc": "",
              "code": "SN 22.58",
            },
            {
              "section": "Tathāgata",
              "name": "Demi Kesejahteraan Banyak Makhluk",
              "desc": "",
              "code": "Iti 84",
            },
            {
              "section": "Tathāgata",
              "name": "Ucapan Agung Sāriputta",
              "desc": "",
              "code": "SN 47.12",
            },
            {
              "section": "Tathāgata",
              "name": "Kekuatan dan Landasan Bagi Keberanian",
              "desc": "",
              "code": "MN 12",
            },
            {
              "section": "Tathāgata",
              "name": "Manifestasi Cahaya Agung",
              "desc": "",
              "code": "SN 56.38",
            },
            {
              "section": "Tathāgata",
              "name": "Orang yang Menghendaki Kebaikan Kita",
              "desc": "",
              "code": "MN 19",
            },
            {
              "section": "Tathāgata",
              "name": "Sang Singa",
              "desc": "",
              "code": "SN 22.78",
            },
            {
              "section": "Tathāgata",
              "name": "Mengapa Beliau Disebut Tathāgata? (1)",
              "desc": "",
              "code": "AN 4.23",
            },
            {
              "section": "Tathāgata",
              "name": "Mengapa Beliau Disebut Tathāgata? (2)",
              "desc": "",
              "code": "Iti 112",
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
