# Wharf site components

Markup to copy for each component. The styles already exist in `site/site.css`. Add `data-reveal` (and `style="--i:n"` for the stagger) to the parts of a new section so it enters like the rest.

## Contents
- Primary button
- Action cells
- Interface fragments (`[data-ui]`)
- Run-in stage
- Feature name columns
- Photograph band
- Statement with a lit name
- One-size table
- Questions
- Inverted close
- Recolouring footage

## Primary button

```html
<a class="btn btn--accent" href="https://github.com/bimurto/wharf-player/releases/latest">Download for Mac</a>
```
Add `btn--big` for the close. One per screen.

## Action cells

A pair of full-width rectangles at the foot of a split section: one ink, one a tone off the field.
```html
<div class="cells">
  <a class="cell cell--ink" href="…">Download for Mac</a>
  <a class="cell cell--tone" href="…">Read the source</a>
</div>
```

## Interface fragments (`[data-ui]`)

A real Mac window, drawn in HTML. Take every label from `Sources/SFTPPlayer/*.swift` (for example the trust alert text is in `ServersPanel.swift`, `HostKeyDialogText`). Use the `--ui-*` tokens. Borders inside are allowed, with a `/* taste-skill-ignore: data-ui … */` comment on the CSS line.

Window shell with a list (Library):
```html
<div class="win win--list" data-ui>
  <div class="lib__bar"><span class="lib__search">Search this folder</span></div>
  <p class="lib__crumbs"><span>/</span><span>media</span><i>/</i><span>films</span></p>
  <ul class="lib__rows">
    <li class="is-hover"><span class="ico" aria-hidden="true"><!-- svg --></span><span><b>File name.mkv</b><small>8.41 GB · 3 Nov 2026</small></span></li>
  </ul>
</div>
```
Other fragments on the page to copy: `.player` (the live player), `.form` inside `.win` (server form), `.win--alert` (trust dialog), `.rec__rows` (Recents with `.bar` progress, set `style="--p:42%"`). Middle dots are fine inside fragments, because they are the app's own format.

## Run-in stage

```html
<div class="stage">
  <p data-reveal><strong>To begin, add a server.</strong> The rest of the paragraph in soft ink…</p>
  <div class="ev" data-reveal style="--i:1"><!-- one piece of evidence, column width --></div>
</div>
```
The opening phrase names the moment ("To begin,", "The first time you connect,", "Come back whenever you like,"). There are no subheads or bullets.

## Feature name columns

```html
<div class="index__group" data-reveal>
  <h3>Playback</h3>
  <ul>
    <li tabindex="0" data-desc="One-line note shown in the empty columns on hover.">Streams over SFTP</li>
  </ul>
  <p class="index__sum">One sentence shown instead of the notes on phones.</p>
</div>
```

## Photograph band

```html
<figure class="band" aria-labelledby="x-cap">
  <div class="band__img"><img src="assets/t-name.jpg" width="1400" height="1170" alt="What it shows, toned gold." loading="lazy"></div>
  <figcaption id="x-cap" class="band__cap" data-reveal>
    <p>Place, year. One or two sentences tying the picture to Wharf.</p>
    <p class="credit">Photograph by Creator, Source, licence, recoloured.</p>
  </figcaption>
</figure>
```

## Statement with a lit name

`site.js` lights one `.nm` at a time inside `.proof`.
```html
<section class="proof" aria-label="Built on">
  <p class="proof__line" data-reveal><span class="proof__lead">Below deck, Wharf runs on</span> <span class="nm is-lit">mpv</span>, <span class="nm">FFmpeg</span> and <span class="nm">libssh</span>.</p>
</section>
```

## One-size table

A real `<table>` with a visually hidden header and caption. Part rows use `<th colspan="4" scope="rowgroup">` and render in gold.

## Questions

```html
<details data-reveal>
  <summary>A real question a visitor asks?</summary>
  <div class="faq__a"><p>A plain answer from the README or the code.</p></div>
</details>
```

## Inverted close

The `.cta` and `.foot` share the light field (`--color-ink` as ground). The close line is in capitals, 3–5 words, and echoes the intro ("Nothing comes ashore." → "Keep it offshore."). It must fit two lines at 390px at 10.5vw: about 9 capitals per line.

## Recolouring footage

Trim to the part worth looping (about 20–30 s), map to the two colours, H.264 MP4 with no audio:
```bash
ffmpeg -ss <start> -t <seconds> -i in.webm -an \
  -vf "format=gray,format=rgb24,lutrgb=r='20+(215)*pow(val/255\,1.2)':g='18+(169)*pow(val/255\,1.2)':b='13+(89)*pow(val/255\,1.2)',scale=1280:-2" \
  -c:v libx264 -crf 27 -preset slow -pix_fmt yuv420p -movflags +faststart site/assets/t-name.mp4
ffmpeg -ss 8 -i site/assets/t-name.mp4 -frames:v 1 -q:v 4 site/assets/t-name-poster.jpg
```
Use it as `<video autoplay muted loop playsinline preload="metadata" poster="…" aria-hidden="true">`. `site.js` pauses it under reduced motion.
