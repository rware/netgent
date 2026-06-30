# Generated with Claude Opus 4.8

# YouTube / Twitch Stats — Field Reference Guide

This guide explains every field produced by the JavaScript logging script
(`js-logging.txt`) and stored in `youtube_stats.jsonl`. Each line of the
`.jsonl` file is one **snapshot**: a single in-page poll of the player state at
a moment in time.

## Top-level record structure

Each line is a JSON object with three keys:

| Field | Type | Meaning |
|---|---|---|
| `timestamp` | float (Unix epoch seconds) | Wall-clock time the snapshot was taken by the Selenium/Python harness. Use this for spacing between samples and for detecting session gaps. |
| `url` | string | The page URL at capture time. The video id is the `v=` query parameter. |
| `stats` | object | The payload returned by the injected JS. All fields below live inside `stats`. |

The injected script branches by hostname: `youtubeStats()` for YouTube,
`twitchStats()` for Twitch, and a generic `<video>` fallback otherwise. So the
available fields depend on `stats.platform`.

## Where each field comes from

The script merges three sources into one flat `stats` object:

1. **`player.getStatsForNerds()`** — YouTube's internal "Stats for Nerds" panel. These are the rich, YouTube-specific fields (bandwidth, codecs, buffer health, the `*_samples` arrays, `debug_info`, etc.). They are largely strings formatted for display.
2. **`player.getVideoData()` / player getters** — clean typed values: `video_id`, `title`, `author`, `is_live`, `current_time_secs`, `duration_secs`, `loaded_fraction`, `player_state`.
3. **`addVideoElementStats()`** — read directly off the HTML `<video>` element: dimensions, `playback_rate`, `paused`, `muted`, `volume`, buffered range, and frame-quality counters.

A practical consequence: some information appears **twice** in slightly
different forms — e.g. `buffer_ahead_secs` (computed from the `<video>`
buffered range, a true float) vs `buffer_health_seconds` (`"27.25 s"`, YouTube's
display string). Prefer the typed `<video>`-element values for analysis.

## Identity & metadata fields

| Field | Example | Meaning |
|---|---|---|
| `platform` | `"youtube"` | Which branch produced the stats: `youtube`, `twitch`, or `unknown`. |
| `video_id` | `"dQw4w9WgXcQ"` | YouTube's 11-char video id. |
| `video_id_and_cpn` | `"dQw4w9WgXcQ / QDCQ 01CW ..."` | Video id plus the **CPN** (Client Playback Nonce) — a per-playback random id. A **new CPN means a new playback** (reload/replay), even for the same video. Useful for splitting sessions. |
| `title` | `"Rick Astley - ..."` | Video title. |
| `author` | `"Rick Astley"` | Channel name. |
| `is_live` | `false` | Whether this is a live stream. On Twitch, derived from the URL (`/videos/` ⇒ VOD ⇒ false). |
| `date` | `"Wed Jun 17 2026 18:53:43 GMT+0000 ..."` | The browser's local `Date` at capture. Redundant with `timestamp` but in the browser's timezone. |
| `channel` *(Twitch only)* | `"somechannel"` | First path segment of the Twitch URL. |

## Playback position & progress

| Field | Units | Meaning |
|---|---|---|
| `current_time_secs` | seconds | Current playhead position. A **decrease** between consecutive snapshots = a **seek backward or a replay/reload**. |
| `duration_secs` | seconds | Total video length (`213.061` ≈ 3:33 here). For live, this can be `Infinity`/large. |
| `loaded_fraction` | 0–1 | Fraction of the video **buffered/loaded**, per `getVideoLoadedFraction()`. Not the same as watched fraction. |
| `player_state` | enum int | YouTube player state: **-1** unstarted, **0** ended, **1** playing, **2** paused, **3** buffering, **5** cued. All snapshots here are `1` (playing). |
| `paused` | bool | From the `<video>` element. Cross-check against `player_state`. |
| `playback_rate` | multiplier | `1` = normal speed, `2` = 2×, etc. |

## Streaming quality (the QoE core)

| Field | Units | Meaning |
|---|---|---|
| `resolution` | `WxH` string | Currently rendered video resolution (`"854x480"` = 480p). Built from `video.videoWidth` × `videoHeight`. Changes over time = **adaptive bitrate (ABR) quality switches**. |
| `video_width` / `video_height` | px | Numeric components of `resolution`. |
| `bandwidth_kbps` | `"NNNN Kbps"` string | YouTube's current **estimated network throughput** (not the bitrate of the chosen stream). Parse off the `" Kbps"` suffix. |
| `bandwidth_samples` | array (bits/sec) | Recent history of throughput estimates, oldest→newest. The panel charts these. |
| `buffer_ahead_secs` | seconds | **How many seconds are buffered past the playhead** (from the `<video>` buffered range). The single best buffer-health number. Falling toward 0 ⇒ risk of rebuffering/stall. |
| `buffer_health_seconds` | `"27.25 s"` string | YouTube's display version of buffer health. |
| `buffer_health_samples` | array (seconds) | History of buffer health, oldest→newest. Sawtooth pattern = buffer drains during playback then refills when a new segment downloads. |
| `network_activity_bytes` | `"0 KB"` string | Instantaneous network activity at snapshot time. |
| `network_activity_samples` | array (bytes) | History of bytes downloaded per tick; spikes mark segment fetches. |
| `codecs` | string | Video/audio codec + itag, e.g. `"av01.0.04M.08 (397) / opus (251)"` ⇒ AV1 video (itag 397) / Opus audio (itag 251). |
| `color` | string | Color space, e.g. `"bt709 / bt709"`. |

## Frame statistics (smoothness)

These come from `video.getVideoPlaybackQuality()` and are **cumulative for the
current playback** (they reset on reload).

| Field | Meaning |
|---|---|
| `total_video_frames` | Total frames rendered so far this playback. Differencing consecutive snapshots gives an effective render FPS. |
| `dropped_video_frames` | Frames dropped (decode/render couldn't keep up). `dropped/total` is the **drop ratio**; a rising ratio signals CPU/GPU or bandwidth strain. |
| `corrupted_video_frames` | Frames that arrived corrupted (often 0). |
| `dims_and_frames` | `"922x519 / 0 dropped of 380"` — YouTube's display string combining the *element* display size with the dropped/total counts. |

## Debug / diagnostic strings

| Field | Meaning |
|---|---|
| `debug_info` | Free-form YouTube debug line, e.g. `"SABR, s:8 t:15.03 b:0.000-42.280 L pbs:1779"`. **SABR** = Server-ABR streaming; **t:** playhead; **b:** buffered byte/time range; **pbs:** player buffer size. Useful as ground-truth but format is undocumented and version-dependent. |
| `extra_debug_info` | Usually empty; extended diagnostics when present. |
| `shader_info` | GPU shader/renderer string, often `null`. |
| `drm` | DRM info; empty for non-DRM content. |
| `live_latency_samples` | Live-edge latency history; `null` entries for VOD (non-live). |
| `playback_categories` | Internal categorization; usually empty for VOD. |

## `*_style` fields — ignore these

Fields ending in `_style` (`bandwidth_style`, `drm_style`,
`live_latency_style`, `cotn_and_local_media_style`, etc.) are **CSS display
strings** scraped from the Stats-for-Nerds DOM (e.g. `"display:none"`). They
indicate whether YouTube was *showing* that row in the panel, not data values.
They carry no analytical signal and can be dropped.

## Interpreting the sample arrays

`bandwidth_samples`, `buffer_health_samples`, `network_activity_samples`, and
`live_latency_samples` are **rolling histories** the panel uses to draw its
mini-charts. They are ordered oldest→newest and **overlap between consecutive
snapshots** (a sliding window). For analysis, either (a) use only the scalar
`*_secs` / `*_kbps` value per snapshot, or (b) deduplicate the arrays across
snapshots if you want a finer-grained continuous series. Treat the per-snapshot
scalar as the reliable value; treat the arrays as bonus high-resolution context.

## Detecting sessions, seeks, and quality switches

- **New session / replay:** a large jump in `timestamp` (wall-clock gap), a reset of `current_time_secs` to a smaller value, a reset of `total_video_frames`, **and/or** a changed CPN in `video_id_and_cpn`. In this dataset, snapshot 16 is a new session: a 120 s wall gap, `current_time` resets 54 s → 15 s, frame counter resets, and the CPN changes.
- **Seek:** `current_time_secs` jumps non-linearly relative to elapsed wall time without a session-level gap.
- **Quality switch:** `resolution` (or `video_height`) changes between snapshots — here 360p→480p as ABR ramps up after startup.
- **Rebuffer risk / stall:** `buffer_ahead_secs` trending toward 0, and/or `player_state` == 3.

## Error fields

If the page had no player/video or a getter threw, the script emits an `error`
or `*_error` key (`no_player`, `no_video`, `stats_for_nerds_error`,
`player_data_error`, `video_element_error`). None are present in this dataset.
The analysis script flags any snapshot carrying one.