# Panduan ATW Source v112

Diperiksa 18 November 2026. Panduan ini sesuai dengan paket v112, bukan file versi lama.

## 1. Pahami statusnya dahulu

Frontend v112 dapat dibuka untuk mencoba alur dan meninjau skenario yang terisi. Baseline v111 lulus 712 pemeriksaan otomatis. Pada v112, perbaikan toolbar ATLAS diuji ulang dengan observer perubahan DOM, pergantian bahasa, pembukaan berulang, serta pemeriksaan duplikasi 83 modul. Pemeriksaan tersebut belum mencakup penerimaan langsung pada browser/ponsel dan server perusahaan.

**Operasional bersama belum siap hanya dengan mengunggah paket.** Paket server menyediakan login OTP, pembacaan record sesuai akses, ruang kerja pribadi, endpoint draft, dan penyimpanan dokumen privat. Seluruh pengiriman, persetujuan, dan pembayaran pada modul lama belum menjadi transaksi bersama di server. Pekerjaan integrasi tersebut memerlukan pengembangan dan pengujian lebih lanjut; pengaturan akun/domain saja tidak menyelesaikannya.

| Berkas | Kegunaan |
|---|---|
| `ATW_Source_v112.html` | Membuka aplikasi dengan skenario terisi untuk meninjau antarmuka dan alur. Bukan database bersama. |
| `ATW_Source_GitHub_Supabase_Vercel_v112.zip` | Sumber aplikasi, API, migrasi database, dan petunjuk pemasangan server. |
| `ATW_Source_v112_Release.zip` | Salinan frontend terisi/kosong, sumber, dan laporan pengujian. |

## 2. Coba frontend yang tersedia

1. Buka `ATW_Source_v112.html` di Edge atau Chrome. Tutup tab versi lama agar hasil pemeriksaan tidak tertukar.
2. Pilih bahasa yang ingin digunakan. Masuk memakai akun yang sudah terdaftar pada edisi tersebut. Akun dan penyimpanan frontend ini terpisah dari Supabase Auth.
3. Buka pencarian modul. Pilih modul dari kelompoknya; pastikan satu halaman aktif yang muncul.
4. Periksa **Price Book** dan **Item Code**: cari item, buka rincian, dan cocokkan referensi harga.
5. Buka **Procurement KPI & IPP**. Pilih periode. Periksa bahwa laporan Supervisor langsung terbuka dan PICA berada pada tab tersendiri, tanpa tabel berulang di bawahnya.
6. Gunakan pelacakan dengan nomor PR atau PO yang sudah tercatat. Buka dokumen setiap tahap. PDF dari record adalah tampilan dokumen modul; file unggahan asli akan diprioritaskan jika tersedia.
7. Buka **ASK ATLAS**. Coba ringkasan halaman dan pertanyaan bertipe. Untuk pemeriksaan dokumen, pilih file dan periksa isi ringkasan terhadap file aslinya.
8. Ulangi pemeriksaan bahasa EN, ID, dan ZH. Nama orang/perusahaan, kode record, serta teks dokumen sumber tidak selalu diterjemahkan karena merupakan data.

File frontend tidak otomatis membuat database Supabase, mengirim OTP perusahaan, atau mengaktifkan Outlook/ETOSS/NetSuite.

## 3. Siapkan GitHub

1. Ekstrak `ATW_Source_GitHub_Supabase_Vercel_v112.zip`.
2. Buka GitHub Desktop dan clone repository tujuan. Buat branch baru, misalnya `setup-v112`, agar versi lama tetap tersedia.
3. Salin **isi folder paket** ke root folder clone. Pastikan `package.json`, `vercel.json`, `api`, `server`, `src`, `scripts`, dan `supabase` berada di root, bukan di dalam folder tambahan.
4. Tinjau perubahan. Jangan sertakan `.env`, API key, password, dokumen vendor, atau data perusahaan pada repository publik.
5. Commit, lalu Push. Import branch ini ke Vercel untuk pemeriksaan awal. GitHub menyimpan kode; edisi ini dihosting oleh Vercel, sehingga tombol **Settings → Pages → Save** tidak diperlukan.

## 4. Siapkan Supabase

1. Masuk ke akun Supabase yang berwenang dan buat/pilih project ATW Source. Catat project yang digunakan; jangan menjalankan migrasi pada database perusahaan lain.
2. Buka **SQL Editor → New query**. Salin seluruh isi `supabase/migrations/202611180001_atw_source.sql`, lalu Run. Jika ada error, selesaikan sebelum melanjutkan. Migrasi ini belum pernah dijalankan pada project live oleh Codex.
3. Periksa tabel `atw_members`, `atw_records`, `atw_documents`, `atw_user_state`, dan `atw_audit`. Periksa bucket `atw-documents` bersifat privat dan kebijakan RLS tersedia.
4. Buka **Authentication → Users** dan buat akun Auth `noor.sari@atwsolar.com`. Pastikan email dikonfirmasi melalui pengelolaan admin. Baris Administrator sudah disiapkan di `atw_members`, tetapi baris tersebut tidak membuat akun Auth otomatis.
5. Tambahkan pengguna lain pada **Authentication → Users** dan `atw_members`. Email harus sama, lowercase, dan `active = true`. Tetapkan role/divisi/entity sesuai akses sebenarnya. Vendor harus memiliki `vendor_id` yang sama dengan master/record miliknya.
6. Nonaktifkan pendaftaran Auth publik. Paket hanya mengirim OTP untuk anggota yang sudah diizinkan.
7. Atur **Custom SMTP** dengan pengirim yang disetujui perusahaan. Pada **Email Templates → Magic Link**, sertakan kode `{{ .Token }}`. Paket memakai kode email, bukan tautan masuk. Lihat [OTP Supabase](https://supabase.com/docs/guides/auth/auth-email-passwordless) dan [SMTP Supabase](https://supabase.com/docs/guides/auth/auth-smtp).
8. Ambil **Project URL**, **Publishable key**, dan **Secret key** dari dashboard project. Masukkan nilainya langsung ke Vercel pada langkah berikut. Secret key hanya untuk server; jangan masukkan ke HTML, repository, atau chat. Lihat [API keys Supabase](https://supabase.com/docs/guides/getting-started/api-keys).

## 5. Hubungkan Vercel

1. Masuk ke Vercel, pilih **Add New → Project**, lalu import repository/branch yang tadi disiapkan. Jika repository berada di akun lain, berikan akses GitHub kepada Vercel untuk repository itu.
2. Tetapkan pengaturan berikut. Paket juga memuat pengaturannya dalam `vercel.json`.

| Pengaturan | Nilai |
|---|---|
| Framework Preset | Other |
| Root Directory | Root repository |
| Build Command | `npm run build` |
| Output Directory | `public` |
| Node.js | 24.x jika tersedia; paket mensyaratkan minimal 22 |

3. Tambahkan environment variables berikut untuk deployment yang akan dipakai. Gunakan nilai project sebenarnya, tanpa tanda kutip tambahan.

| Variable | Nilai |
|---|---|
| `SUPABASE_URL` | Project URL Supabase |
| `SUPABASE_PUBLISHABLE_KEY` | Publishable key project |
| `SUPABASE_SECRET_KEY` | Secret key project; simpan sebagai sensitive/server secret |
| `AUTH_RATE_SALT` | Nilai acak dari password manager, minimal 32 karakter |
| `APP_ORIGIN` | Origin HTTPS website yang benar, tanpa path atau slash penutup |

4. Jika URL produksi belum tersedia saat import, deploy dahulu untuk memperoleh domain project, kemudian isi `APP_ORIGIN` dengan URL tersebut dan **Redeploy**. Sebelum itu API akan menolak konfigurasi yang belum lengkap. Jangan menebak nama domain.
5. Pastikan Build berstatus Ready. Jika gagal, buka Build Logs. Jangan mengubah Output Directory menjadi folder sumber.
6. Di Supabase **Authentication → URL Configuration**, isi **Site URL** dengan origin yang sama.
7. Buka URL production yang tepat. Preview Vercel memiliki origin lain; `APP_ORIGIN` harus disetel sesuai environment/domain yang sedang diuji.
8. Setelah mengubah environment variables, lakukan **Redeploy**; perubahan tidak berlaku pada deployment yang sudah ada. Lihat [Environment variables Vercel](https://vercel.com/docs/environment-variables/managing-environment-variables).

## 6. Uji login dan data pada server

1. Buka website Vercel melalui HTTPS. Masukkan `noor.sari@atwsolar.com`, lalu Continue.
2. Ambil kode dari mailbox tersebut, masukkan kode, lalu Verify. Email lain harus dibuat terlebih dahulu pada Supabase Auth dan `atw_members`.
3. Periksa peran Administrator yang tampil. Coba logout lalu login kembali.
4. Periksa data yang benar-benar tersimpan di Supabase. Edisi server memulai record kanonis kosong; skenario terisi dari HTML frontend tidak otomatis diimport.
5. Untuk memuat data yang disetujui, siapkan file JSON privat sesuai format dalam README. Dengan Node.js dan environment server yang sesuai, jalankan `node scripts/import-records.mjs "PATH-ABSOLUT-KE-RECORDS.json"`. Script mengabaikan referensi yang sudah ada; tidak mengisi dokumen yang tidak disertakan. Jangan commit file import perusahaan ke repository publik.
6. Cocokkan satu PR/PO dan dokumennya dengan sumber. Uji akun vendor: hanya data miliknya/record yang dibagikan yang boleh terbuka.
7. Ubah pekerjaan pribadi, tunggu indikator **Tersimpan**, lalu login pada browser lain dengan akun yang sama. Periksa hasilnya. Penyimpanan pribadi ini berbeda dari persetujuan/transaksi bersama.
8. Jika muncul konflik perangkat lain, muat ulang sebelum mengubah lagi. Jangan menganggap indikator Tersimpan sebagai bukti PO sudah disetujui atau email sudah dikirim.

## 7. Selesaikan integrasi operasional

Bagian ini memerlukan implementasi kode dan uji lintas akun, bukan sekadar pengisian dashboard hosting.

1. Petakan setiap controller/form lama ke API transaksi kanonis yang sesuai; jangan bergantung pada snapshot pribadi untuk transaksi bersama.
2. Terapkan otorisasi persetujuan di server, audit, versi record, serta pengujian dua pengguna. Uji route CQS dan Direct PO secara terpisah.
3. Selesaikan onboarding vendor dan alur upload file untuk setiap modul yang memerlukannya.
4. Hubungkan Outlook, ETOSS dan NetSuite melalui adapter resmi perusahaan. PO approval tetap di ATW Source; migrasi ke NetSuite harus memakai hasil yang telah disetujui.
5. Cocokkan grafik/KPI dengan sumber kanonis yang sama. Pastikan PR/PO, dokumen, outstanding, dan status tidak berbeda antar akun.
6. Jalankan migrasi/RLS/storage/email pada project tujuan dan lakukan uji akses dengan akun Administrator, Procurement, internal divisi, dan vendor.

ATLAS pada paket ini memakai analisis berbasis data ATW Source. **API OpenAI tidak diperlukan untuk fungsi tersebut.** Paket belum mengaktifkan model generatif. Kemampuan suara tetap perlu diperiksa pada browser/ponsel tujuan; belum ada jaminan suara tersedia untuk seluruh perangkat dan bahasa.

## 8. Pasang domain sendiri

1. Di Vercel buka **Project → Settings → Domains**. Tambahkan domain/subdomain yang memang dimiliki ATW.
2. Di pengelola DNS, misalnya Cloudflare jika digunakan, tambahkan record sesuai nilai yang ditampilkan Vercel untuk project tersebut. Tidak ada alamat DNS tetap yang perlu ditebak.
3. Tunggu Vercel mengonfirmasi domain/HTTPS.
4. Ubah `APP_ORIGIN` dan Supabase Auth Site URL ke origin final yang sama, lalu Redeploy.
5. Uji login dan dokumen kembali melalui domain baru. Langkah domain mengikuti [panduan resmi Vercel](https://vercel.com/docs/domains/working-with-domains/add-a-domain).

## 9. Pemeriksaan sebelum dipakai bersama

- [ ] OTP benar-benar diterima pengguna yang terdaftar; email tidak terdaftar tidak memperoleh akses.
- [ ] Vendor tidak dapat membaca file atau harga vendor lain.
- [ ] Data penting dibaca konsisten dari dua akun/browser.
- [ ] Approval CQS/Direct PO/PO tersimpan sebagai transaksi kanonis dan dapat diverifikasi akun berwenang lain.
- [ ] Upload, batal upload, buka, dan download dokumen benar-benar bekerja pada server.
- [ ] Outstanding, grafik, dan KPI cocok dengan transaksi sumber.
- [ ] EN/ID/ZH, tabel, dialog PDF, dan ATLAS diperiksa di desktop serta ponsel.
- [ ] Pengiriman Outlook dan sinkronisasi ETOSS/NetSuite hanya ditandai berhasil setelah layanan tujuan mengonfirmasi.
- [ ] Backup dan pemulihan diuji sesuai fasilitas project yang dipilih.

**Status saat panduan dibuat:** paket dan uji otomatis tersedia. Project Supabase/Vercel, domain, SMTP, migrasi live dan integrasi operasional di atas belum diaktifkan/dinyatakan lulus. Website yang berhasil tampil belum membuktikan seluruh proses perusahaan sudah terintegrasi.

## Jika ada kendala

| Gejala | Yang diperiksa |
|---|---|
| OTP tidak masuk | Akun ada di Auth dan `atw_members`, active, SMTP, template Token, spam, dan batas pengiriman. |
| Server configuration incomplete / 503 | Kelima environment variables, project URL, dan redeploy terbaru. |
| Aksi ditolak dari domain | `APP_ORIGIN` harus sama persis dengan origin website yang dipakai. |
| Record kosong setelah login server | Import/data Supabase dan batas akses pengguna; isi HTML terpisah tidak otomatis berpindah. |
| Simpan pribadi berhasil tetapi akun lain tidak berubah | Periksa adapter transaksi; snapshot pribadi bukan record bersama. |
| Nama domain belum valid | DNS project dan status verifikasi di Vercel. |
| Tampilan masih versi lama | Pastikan URL/file v112 yang dipakai, deployment terbaru, lalu muat ulang. |
