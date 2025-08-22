# Changelog

All notable changes to the OpenVine Backend will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Cloudflare Stream upload and CDN integration (phase-in)
  - New POST `/v1/media/request-upload` to create Stream direct upload URLs (NIP-98 auth, rate limited per pubkey)
  - New POST `/v1/webhooks/stream-complete` to receive processing callbacks (HMAC signature validation)
  - New GET `/v1/media/status/{videoId}` to poll processing state (`pending_upload`, `processing`, `published`, `failed`, `quarantined`)
  - Thumbnail delivery via Cloudflare Images transformation of Stream thumbnails
  - Server-side mappings in KV: `stream:file:{fileId} -> { uid, state, migratedAt }` and `stream:uid:{uid} -> { fileId }`
  - Compatibility serving maintained: `/media/{fileId}` and `/thumbnail/{fileId}` redirect to Stream/Images when migrated; otherwise serve from R2
  - Pre-upload dedup flows retained: `/api/check/{sha256}`, batch `/api/check` and `/api/media/lookup`
- New `/api/import-url` endpoint for importing videos from external URLs
  - Supports fetching videos from any HTTP/HTTPS URL including Google Cloud Storage
  - Optional Cloudinary integration for content moderation and thumbnail generation
  - Automatic deduplication based on SHA256 hash
  - NIP-98 authentication required
  - Returns NIP-94 event data compatible with existing upload flow

### Changed
- Preferred delivery moves to Cloudflare Stream HLS/DASH; `/media/{fileId}` now capable of redirecting to Stream when a `stream:file:{fileId}` mapping exists (R2 remains as fallback)
- `/thumbnail/{fileId}` prefers Cloudflare Images URL when a Stream UID is known; otherwise serves R2-stored image
- Standardize webhook secret name usage to `STREAM_WEBHOOK_SECRET` (ensure Wrangler secrets are updated accordingly)
- Rate limiting applied to Stream uploads (30/hour per pubkey via KV)

### Fixed
- **GCS MIME Type Issue**: URL import now handles Google Cloud Storage files with incorrect MIME types
  - Accepts `application/octet-stream` and `application/binary` for GCS domains when file extension indicates video
  - Enhanced content type validation with extension-based fallback for trusted sources
  - Automatic content type correction during processing (e.g., octet-stream → video/mp4)
  - Addresses issue where Vine archive videos were rejected due to missing Content-Type metadata

### Notes
- NIP-96 `/api/upload` remains for images and legacy flows. For videos, clients should migrate to Stream upload flow. Transitional behavior may return a processing handoff to Stream from NIP-96.
- GIF output is not provided by Stream; prefer HLS/short MP4. If animated GIFs are required, a separate processing path will be needed.

### Migration
- A one-time migration will import existing R2 videos into Cloudflare Stream:
  - Enumerate R2 objects under `uploads/`; for each video, generate a temporary signed URL
  - Create Stream video via API with `{ input: signedUrl, meta: { fileId, sha256, originalFilename } }`
  - Store KV mappings `stream:file:{fileId}` and reverse `stream:uid:{uid}`
  - On webhook completion, update `v1:video:{videoId}` to `published` with playback URLs, and enable `/media` and `/thumbnail` redirects
- Deduplication and original Vine mappings are preserved:
  - KV keys retained: `sha256:{hash}`, `vine_id:{vineId}`, `filename:{name}`

### Deprecations
- Direct R2-based video delivery is considered legacy and will remain as a fallback path during and after the migration window. Future versions may require Stream for all new video uploads.

### Technical Details
- Added `url-import.ts` handler with support for:
  - Direct R2 storage mode (default)
  - Cloudinary processing mode with content moderation
  - Lazy thumbnail generation for R2 uploads
  - Eager thumbnail transformations for Cloudinary uploads
