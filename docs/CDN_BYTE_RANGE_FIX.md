# CDN Byte Range Support Fix Required

## Problem
The CDN at `cdn.divine.video` is not properly handling HTTP Range requests, which causes video playback failures in media_kit/libmpv. When a Range header is sent, the server returns HTTP 200 (full content) instead of HTTP 206 (partial content).

## Current Behavior (BROKEN)
```bash
curl -I -H "Range: bytes=0-1023" "https://cdn.divine.video/[video].mp4"
# Returns: HTTP/2 200  ❌ WRONG
# Should return: HTTP/2 206 Partial Content ✅
```

## Error in App
```
CoreMediaErrorDomain error -12939 - byte range length mismatch
```

This happens because media_kit/libmpv expects:
1. HTTP 206 status code for range requests
2. `Content-Range` header showing which bytes were returned
3. `Accept-Ranges: bytes` header to indicate range support
4. Only the requested bytes in the response body

## Required CDN Configuration

### For Cloudflare (if using Cloudflare CDN)

1. **Enable Byte Range Support in Cloudflare Dashboard:**
   - Go to Speed → Optimization
   - Enable "Byte-Range Support"
   - Or use Page Rule: `*cdn.divine.video/*` → Cache Level: Bypass

2. **Cloudflare Worker Fix (if using Workers):**
```javascript
export default {
  async fetch(request, env, ctx) {
    // Forward range requests properly
    const response = await fetch(request, {
      cf: {
        cacheEverything: false,  // Disable caching for range requests
        bypassCache: request.headers.has('range')  // Bypass cache if range header present
      }
    });

    return response;
  }
}
```

### For Nginx Origin Server

Add to your nginx configuration:
```nginx
location ~ \.(mp4|webm|m4v)$ {
    # Enable byte-range support
    add_header Accept-Ranges bytes;

    # Ensure range requests work
    proxy_force_ranges on;

    # Don't buffer entire video
    proxy_buffering off;

    # Pass range headers
    proxy_set_header Range $http_range;
    proxy_set_header If-Range $http_if_range;
}
```

### For AWS S3/CloudFront

S3 supports byte ranges by default, but CloudFront needs configuration:

1. **CloudFront Behavior Settings:**
   - Cache Based on Selected Request Headers: Include `Range`
   - Forward Headers: Whitelist `Range` and `If-Range`

2. **Origin Request Policy:**
   - Include headers: `Range`, `If-Range`

### For Express.js/Node.js Server

```javascript
app.get('/videos/:id', (req, res) => {
  const videoPath = getVideoPath(req.params.id);
  const stat = fs.statSync(videoPath);
  const fileSize = stat.size;
  const range = req.headers.range;

  if (range) {
    // Parse Range header
    const parts = range.replace(/bytes=/, "").split("-");
    const start = parseInt(parts[0], 10);
    const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
    const chunksize = (end - start) + 1;

    // Send 206 Partial Content
    const head = {
      'Content-Range': `bytes ${start}-${end}/${fileSize}`,
      'Accept-Ranges': 'bytes',
      'Content-Length': chunksize,
      'Content-Type': 'video/mp4',
    };

    res.writeHead(206, head);
    const stream = fs.createReadStream(videoPath, { start, end });
    stream.pipe(res);
  } else {
    // No range requested, send full file
    const head = {
      'Content-Length': fileSize,
      'Content-Type': 'video/mp4',
      'Accept-Ranges': 'bytes',  // Important: advertise range support
    };
    res.writeHead(200, head);
    fs.createReadStream(videoPath).pipe(res);
  }
});
```

## Testing the Fix

After implementing, test with:
```bash
# Test 1: Check range request returns 206
curl -I -H "Range: bytes=0-1023" "https://cdn.divine.video/[video].mp4"
# Should see: HTTP/2 206 Partial Content
# Should see: Content-Range: bytes 0-1023/[total-size]
# Should see: Accept-Ranges: bytes

# Test 2: Check content length matches requested range
curl -H "Range: bytes=0-99" "https://cdn.divine.video/[video].mp4" | wc -c
# Should return exactly 100 bytes

# Test 3: Check middle range
curl -I -H "Range: bytes=1000-1999" "https://cdn.divine.video/[video].mp4"
# Should see: Content-Range: bytes 1000-1999/[total-size]
```

## Why This Matters

Media players like libmpv (used by media_kit) and native video players on iOS/macOS rely on byte-range requests to:
1. Stream video efficiently without downloading the entire file
2. Seek to different positions in the video
3. Adapt quality based on bandwidth
4. Resume interrupted downloads

Without proper byte-range support, the player tries to download the entire video for every seek operation, causing the "byte range length mismatch" error.

## Quick Workaround (Not Recommended)

If you can't fix the CDN immediately, you could proxy videos through a service that adds range support, but this adds latency and bandwidth costs.

## Contact
If the CDN is managed by a third party, send them this document and ask them to enable HTTP Range request support for video files.