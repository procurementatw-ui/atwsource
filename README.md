# ATW Source · GitHub + Supabase + Vercel

Kode berada di GitHub. Website dan API berjalan di Vercel. Supabase menyediakan PostgreSQL, Auth dan bucket dokumen privat. Paket ini mempertahankan antarmuka v112, grafik procurement/OTOBOS, ATLAS, dan alur modul yang sudah ada.

## 1. Upload ke GitHub

Ekstrak ZIP. Upload **isi folder paket** ke root repository `nrulailasari-ui/atwsource`, termasuk `package.json`, `vercel.json`, `api`, `server`, `src`, `scripts` dan `supabase`. Simpan salinan/branch versi lama sebelum menggantinya. Jangan hanya mengunggah HTML ke GitHub Pages untuk edisi server ini.

Untuk folder yang berisi banyak berkas, gunakan GitHub Desktop: Clone repository → salin isi paket ke folder clone → Commit → Push. Sumber aplikasi yang bisa diedit ada di `src/application.html`; `npm run build` menyusunnya menjadi `public/application.html`. Mesin OCR, audio dan gambar disajikan terpisah sehingga tidak semuanya diunduh saat membuka halaman.

Jangan upload `.env`, token, password, `service_role` / secret key, atau file data perusahaan ke repository publik. `.gitignore` mengecualikan `.env` dan `data/*.json`. Batas GitHub untuk satu file berlaku; semua file sumber pada paket telah diperiksa ukurannya. Paket tidak berisi kredensial asli.

## 2. Supabase

1. Pilih/buat project Supabase milik ATW. Jalankan `supabase/migrations/202611180001_atw_source.sql` di SQL Editor project tersebut. Ini membuat tabel, RLS, audit dan bucket privat `atw-documents`.
2. Di Authentication, matikan pendaftaran akun publik dan buat akun Auth untuk email yang disetujui. Buat akun `noor.sari@atwsolar.com` terlebih dahulu. Tabel `atw_members` sudah menunjuk email itu sebagai satu-satunya Administrator; membuat baris anggota tidak otomatis membuat akun Auth.
3. Tambahkan anggota lain di `atw_members` menggunakan email lowercase, peran, divisi, batas entitas dan vendor ID yang benar. Vendor wajib memiliki `vendor_id`; jangan beri peran internal kepada vendor. Tidak ada pilihan nama bebas saat login.
4. Konfigurasikan SMTP perusahaan. Pada template **Magic Link**, tampilkan `{{ .Token }}` sebagai kode OTP. Paket memakai kode email, bukan login dengan nama saja. Pengiriman email Auth hanya berjalan setelah SMTP/Supabase Auth disiapkan.
5. Payload record kanonis pada edisi server dimulai kosong dan dibaca dari Supabase. Controller dan laporan warisan tetap perlu ditinjau sumber serta pemetaan datanya sebelum operasi perusahaan; tampilannya bukan bukti bahwa sumber tersebut sudah terhubung ke Supabase. Untuk memakai data yang disediakan sebelumnya, simpan file import di luar repository publik lalu jalankan `node scripts/import-records.mjs /path/records.json` dengan environment server yang sesuai. Import mengabaikan referensi yang sudah ada; tidak menimpa persetujuan atau transaksi aktif. Hak vendor atas RFQ bersama dicatat secara eksplisit pada `atw_record_access`.

Struktur satu record import:

```json
{"domain":"po","reference":"PO-COMPANY-001","entity":"ATWS","vendor_id":"vendor-id-from-master","requester_email":"registered-requester@company.com","division":"ENG","payload":{"ref":"PO-COMPANY-001","entity":"ATWS","status":"Draft","currency":"IDR"},"created_by":"registered-actor@company.com","source":"atwsource"}
```

## 3. Vercel

Import repository GitHub tersebut pada Vercel. Framework: **Other**, Build Command: `npm run build`, Output Directory: `public`. Node.js: 24 (atau versi yang memenuhi `package.json`). Folder `api` adalah Vercel Function, bukan file statis.

Isi environment variables Vercel dari `.env.example`:

| Variable | Isi |
|---|---|
| `SUPABASE_URL` | URL project ATW di Supabase |
| `SUPABASE_PUBLISHABLE_KEY` | Publishable key project |
| `SUPABASE_SECRET_KEY` | Secret key server; legacy service_role juga didukung |
| `APP_ORIGIN` | Origin website yang benar, misalnya URL deployment Vercel setelah tersedia |
| `AUTH_RATE_SALT` | Nilai acak minimal 32 karakter, hanya di server |

Environment harus disetel juga untuk Preview jika ingin menguji preview; `APP_ORIGIN` harus cocok tepat dengan domain yang dipakai. Redeploy setelah environment atau domain berubah. Server gagal tertutup jika konfigurasi belum lengkap. Tidak ada key yang perlu dimasukkan ke HTML.

## 4. Domain website

Setelah deploy, Vercel memberikan URL project `.vercel.app`. Nama final bergantung ketersediaan dan project yang dibuat. Untuk domain sendiri, buka Project → Settings → Domains, tambahkan domain/subdomain yang Anda miliki, lalu ikuti **nilai DNS yang ditampilkan Vercel** pada akun pengelola domain. Paket ini tidak membeli atau mengklaim domain. Setelah DNS terverifikasi, ubah `APP_ORIGIN` dan Supabase Auth Site URL ke origin final, lalu redeploy.

## Yang sudah terhubung oleh kode

- OTP Supabase untuk akun terdaftar, verifikasi akun pada server, cookie HttpOnly/Secure dan pemeriksaan Origin untuk setiap perubahan.
- Record kanonis dibaca dari Supabase menggunakan JWT pengguna dan RLS, bukan peran yang dikirim browser. Vendor dibatasi pada data atau undangan yang memang diberikan kepadanya.
- Ruang kerja pribadi disimpan per akun di server, dikompresi dan menggunakan versi untuk mendeteksi perubahan dari perangkat lain. Snapshot pribadi ini **bukan** persetujuan bersama atau pengganti transaksi kanonis. Konflik tidak ditimpa diam-diam.
- Endpoint draft kanonis hanya menyimpan Draft; tidak membuat PR, menerbitkan PO, mengesahkan CQS atau membayar invoice. Kolom persetujuan tidak diterima melalui endpoint draft.
- Dokumen asli memakai bucket privat, hak record, signed upload dan signed download singkat. Batas 12 MB. File harus diselesaikan/terverifikasi ukurannya sebelum berstatus Available.
- ATLAS membaca record ATW Source melalui endpoint context yang sama. Analisis berbasis data tidak memerlukan API OpenAI. Model generatif eksternal tidak diaktifkan.

## Batas penerapan yang masih perlu diselesaikan di akun perusahaan

Koneksi project, domain/DNS, migrasi SQL, SMTP, akun Auth, import dan pengujian langsung memerlukan akses Supabase/Vercel yang belum tersambung saat paket dibuat. Menjalankan build bukan bukti deployment berhasil. Tidak ada domain, database live atau email yang dibuat/dikirim otomatis saat menyusun paket ini.

Snapshot pribadi mempertahankan formulir dan pekerjaan akun; **seluruh tindakan persetujuan, pengiriman dan pembayaran pada controller lama belum diubah menjadi transaksi multi-user pada server**. Jangan menganggap perubahan tampilan status lama sebagai persetujuan kanonis lintas akun. Adaptor bisnis final per modul, onboarding vendor, approval server dan koneksi NetSuite/ETOSS/Outlook masih harus disambungkan serta diuji sebelum operasi perusahaan. PO approval tetap milik ATW Source; paket tidak memindahkannya ke NetSuite.

Edisi populated v112 untuk memeriksa seluruh skenario disediakan terpisah dari paket public/server agar data bisnis tidak disebar lewat sumber halaman publik. Antarmuka server mulai dari data yang benar-benar diimport/tersimpan. Tidak ada signature, bukti pembayaran, atau keputusan persetujuan yang dibuat oleh ATLAS.

## Pemeriksaan

`npm test` memeriksa gateway memakai respons Supabase yang dikendalikan dalam tes. `npm run build` menghasilkan halaman dan menyisipkan bridge. `npm run check` memeriksa isolasi aplikasi publik. SQL/RLS, SMTP, DNS, storage live dan deployment tetap perlu diverifikasi pada project tujuan; hasil mock tidak disebut pengujian server live.

Referensi: [Vercel Node Functions](https://vercel.com/docs/functions/runtimes/node-js), [Domain Vercel](https://vercel.com/docs/domains/working-with-domains/add-a-domain), [Supabase API keys](https://supabase.com/docs/guides/getting-started/api-keys), [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [Storage access](https://supabase.com/docs/guides/storage/security/access-control).
