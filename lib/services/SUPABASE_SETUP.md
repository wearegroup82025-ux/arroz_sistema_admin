# Supabase Storage setup for the Firebase app

This keeps **Firebase Firestore + Firebase Auth** as the main app backend. Supabase is used only for product image files.

## 1. Flutter package

Run:

```bash
flutter pub add supabase_flutter
```

Supabase's current Flutter docs use `supabase_flutter` and initialize it with the Project URL and publishable key. citeturn0search0turn0search1

## 2. Supabase Storage

Create a bucket named:

```text
product-images
```

Make it **Public** so shoppers can display product photos with normal image URLs. Supabase documents `getPublicUrl()` for assets in public buckets. citeturn0search3

Set the bucket's maximum file size to something reasonable such as 5 MB. The Flutter code already limits the number of photos to 9 and the picker requests image quality/compression.

## 3. Enable Anonymous Sign-Ins

In Supabase:

**Authentication → Providers/Configuration → Anonymous Sign-Ins → Enable**

The app creates a Supabase anonymous session so Storage RLS can use the `authenticated` role without adding another user-facing login flow. Supabase documents that anonymous users use the `authenticated` role. citeturn2search0

This is a convenience security layer, not an admin authorization system. For a production app where only Firebase admins should upload, the stronger next step is to connect Firebase Auth to Supabase authorization or route uploads through a trusted server/Edge Function. Firebase supports server-side ID-token verification, and Supabase supports third-party Firebase Auth integration. citeturn1search2turn1search7

## 4. Storage upload policy

Open **SQL Editor** and run this. It allows only authenticated Supabase sessions to INSERT into the `product-images` bucket and limits paths to `products/...`. It does NOT grant delete/update access.

```sql
create policy "authenticated users can upload product images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = 'products'
);
```

Supabase Storage uses RLS policies on `storage.objects`; INSERT is the permission required for uploads. citeturn0search8

Because the bucket is public, you do not need a SELECT policy just to display public product images. citeturn0search3

## 5. Add the config file

Copy `supabase_config.dart` into your Flutter project's `lib/` folder. Put only the **Project URL** and **publishable key** in it. NEVER put a Supabase secret/service-role key in Flutter. Supabase documents secret keys as server-side credentials that bypass RLS. citeturn1search4

## 6. Initialize in main.dart

Before `runApp()`:

```dart
WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp();
await SupabaseConfig.initialize();
runApp(const MyApp());
```

Also import:

```dart
import 'supabase_config.dart';
```

## 7. Code changes

Use the supplied `inventory_page_supabase.dart` and `product_page_supabase_gallery.dart`.

The inventory page now uploads to:

```text
product-images/products/<productCode>/<timestamp>_<index>.<extension>
```

and saves the returned public URLs into the existing Firestore fields:

```text
imageUrl
imageUrls
```

The product page shows the first image in the grid and a swipeable multi-image gallery on the detail page, with tap-to-fullscreen and zoom.
