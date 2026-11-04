---
name: wharf-site-design
description: The design system of the Wharf website (wharf.bimurto.io, the static site in `site/`). Use it for any change to that site: a new section or page (changelog, privacy, docs, download, a release note), new copy, a new picture, a restyle, a bug in the layout, or a review of how it looks. Also use it when the user asks to make anything "match the Wharf site", "in the Wharf style", or to build marketing material for Wharf (an OG image, a banner, a release page), even if they don't name the site or this skill.
---

# Wharf site design

The Wharf site is a static page in `site/` (plain HTML, CSS and a little JS, no build step). It sells a native macOS video player that streams films straight off an SFTP server. This skill keeps every change in the same voice and design, so a new page looks like it was made with the first one.

Read `site/index.html`, `site/site.css` and `site/tokens.css` before changing anything. They are the source of truth. This file explains why they are the way they are. When the code and this file disagree, the code wins: update this file.

## The idea, which every change should carry

Old wharves painted their names metres high across their warehouse walls, big enough to read from a ship. The site does the same: **WHARF** is set wall-sized in the gold of the app icon on warm black, cropped by the screen edges. The second idea is the product's own promise, **nothing comes ashore**: films stay on the server and only the bytes being watched cross the water.

A new section is right when it says something true about Wharf with one of these two images (the painted name, the harbour and its cargo) or with the real app's interface. It is wrong when it could sit on any other product's site. Before building, write one line: "this section shows [a real Wharf fact] as [a picture, a piece of the interface, or a large statement]."

The harbour vocabulary is a light touch in headlines ("Nothing comes ashore.", "Keep it offshore.", "Below deck, Wharf runs on…"). Body copy stays plain and literal. One nautical line per section at most, or it turns into a costume.

## Tokens

All colour and type go through the custom properties in `site/tokens.css` and the `:root` blocks at the top of `site/site.css`. Never write a literal colour or `font-family` in a rule. If you need a new value, add a token first. This is what keeps the page consistent, and the Hallmark check fails the build otherwise.

| Role | Token | Value | Use |
| --- | --- | --- | --- |
| Ground | `--color-paper` | `#14120D` | the page, warm black from the app icon |
| Raised field | `--color-paper-2` | `#1E1B15` | a section that changes field (the player, the shortcuts) |
| Field inside a field | `--color-paper-3` | `#2A261E` | secondary cells, code |
| Ink | `--color-ink` | `#E6E4DF` | running text, headings; also the ground of the closing field |
| Soft ink | `--color-ink-2` | `#D2CCC0` | the run-on part of paragraphs, secondary text |
| Muted | `--color-muted` | `#ACA18B` | notes, credits, inactive tabs, dimmed names |
| Accent | `--color-accent` | `#EBBB66` | the gold from the icon: the monument word, the primary button, one lit detail per section |
| On light field | `--color-cream-muted` | `#5E5647` | small text on the closing light field |
| Interface | `--ui-*` | see `site.css` | only inside `[data-ui]` fragments of the app |

Gold is the brand, not a highlight colour. Give it to the name, to the one primary action, and to at most one small detail per section (a lit name, the "0 bytes", a breadcrumb). A second gold thing on the same screen dilutes the first.

## Type

Two families, loaded from Fontshare with **two separate links**. The combined URL `f[]=panchang@700&f[]=switzer@400,500` silently serves the wrong font (Bevellier instead of Switzer), so keep them apart:

```html
<link href="https://api.fontshare.com/v2/css?f[]=panchang@700&display=swap" rel="stylesheet">
<link href="https://api.fontshare.com/v2/css?f[]=switzer@400,500&display=swap" rel="stylesheet">
```

- **Panchang 700** (`--font-display`): headings only. It is an extremely wide face, about one em per capital, which shapes everything below.
- **Switzer 400/500** (`--font-body`): everything else. 500 is the only emphasis weight.

Sizes come from these steps only. A sixth size is the start of a messy page.

| Step | Token | Used for |
| --- | --- | --- |
| Monument | inline in `.monument` / `.foot__word` | the name only, 17–23vw |
| Big | `--step-big` | section headings that carry the idea (intro, FAQ) |
| Head | `--step-head` | ordinary section headings, the proof statement, footer places |
| Lead | `--step-lead` | the hero sentence, FAQ questions, the shortcut table, captions set large |
| Body | `--step-body` | running text, 17–19px |
| Small | `--step-small` | notes, credits, labels, 14–15px |

Rules that come from Panchang's width:
- **Capitals are for the name and the closing line only** (`.monument`, `.foot__word`, `.cta__head`). Section headings are sentence case. Capitals at heading size wrapped to three lines on phones.
- **Every heading fits in two lines at 390px.** At `--step-big` that is about 13 characters per line on a phone. Count the characters before committing to a headline: cut words first, change size last.
- A statement set large is a `<p>`, at `--step-head` or below (36px max on desktop, 24px on a phone), about 25 words.
- Tracking −0.02 to −0.035em on display sizes, leading 0.74–1.05. Body leading 1.55.

## Layout

- Margins are tight: `--gutter` is 28px (20px on phones), so big type reaches the edges.
- Sections are separated by space (`--section-gap*`, 120–176px) or by a change of field colour (`--color-paper-2`, or the light closing field). Never by a line, a border or a shadow.
- Neighbouring sections never share a composition. The page today runs: monument hero → the idea heading with two short captions over the real app window → a 50/50 plate with the live player → a narrow run-in column starting at 30vw → three one-size name columns → a photograph with a caption beside it → one statement sentence → a full-width one-size table → a wide heading with indented questions → the inverted close → the name-first footer. A new section takes a composition none of its neighbours use.
- Grids use `minmax(0, 1fr)` tracks so pictures never force overflow. `html` and `body` keep `overflow-x: clip`.
- Phones get their own composition, not a squashed desktop. The hero word turns vertical and runs down the right edge.

## Components

Copy these instead of inventing new ones. Markup and notes for each are in `references/components.md`:

- `.btn.btn--accent`: the one primary button. Square corners, gold fill, ink on hover. One per screen.
- `.cells`: a pair of full-width rectangular actions (ink and tone), used inside a section.
- `[data-ui]` fragments: the Wharf interface drawn in HTML (player, server form, trust alert, Library, Recents). Built from the real strings in `Sources/SFTPPlayer/*.swift`. These are the only places allowed borders, rounded corners and the system font, because they show a real Mac window.
- `.stage`: a run-in paragraph (bold opening phrase in ink, the rest in soft ink) followed by one piece of evidence the width of the column.
- `.index__group`: a stack of feature names at one size, with a note on hover.
- `.band`: a recoloured photograph with a caption and credit beside it.
- `.keys__table`: a real `<table>` at one type size, with part headings in gold.
- `.faq__list details`: questions indented to column 5. An open answer sits on a tone tile.
- `.credit`: small muted credit line under any found picture.

## Pictures

What the site shows, in order of preference:
1. **Real screenshots of the app** (`.shot`, `site/assets/wharf-window-*.jpg`). They prove the app exists and looks this way, which drawn pieces can't. Never recolour them, because the product must look as it does. Flatten the window's transparent corners onto `--color-paper`, export 1800 and 1200 px JPEGs (quality about 86) with `srcset`, and credit any film shown in them. Take them with a demo server, never your own: keep real host names and personal folders out of the frame (the current shot uses `/Users/Shared/Media/Films`), and use an openly licensed film such as Blender's Sintel (CC BY 3.0).
2. **The app drawn in HTML**, as a `[data-ui]` fragment with its real labels, numbers that add up, and one item hovered or selected. Use it where the page needs something a screenshot can't do: the interactive player, or a small panel at any size. Never a fake dashboard, never a device frame.
3. **Real pictures of the harbour world**: archival or openly licensed photographs and footage of wharves, docks, warehouses, ferries, cranes. Use only CC0, public domain or CC BY. CC BY-SA forces share-alike on a recoloured version, so leave it out.
4. Type and colour alone.

Every picture except the app screenshots is recoloured to the icon's two colours (`#14120D` to `#EBBB66`) so archival scans and modern footage read as one set. Run `scripts/duotone.py` for stills. Run the ffmpeg command in `references/components.md` for footage, which also trims it. Save into `site/assets/` with a `t-` prefix, then:
- add a credit naming the title, creator, licence and "recoloured" in the footer `.foot__credits` paragraph. That satisfies CC BY. A caption under the picture is optional; add one only when it says something about the picture (like the Brooklyn band), not just to repeat the credit;
- add its entry to `site/assets/credits.json`;
- give it real `width`, `height` and an `alt` that says what the picture shows and that it is toned gold;
- never present a found picture as Wharf's product, users or team.

The `design-taste-frontend` skill's `scripts/assets.mjs "<query>"` searches the open collections and `--get <ref> --to site/assets` downloads with the credit. Look at each picture before using it: scans often carry colour charts and mount borders that need cropping (`duotone.py --crop`).

## Words

- Short, literal, specific. Use real numbers from the code: 32 reads of 64 KiB, 10 s and 60 s seeks, 130% volume, controls hide after 2.8 s, three logins at most, the last 20 recents.
- Facts come from the repo (`README.md`, `Sources/`), never from memory. If a number isn't in the code, leave it out.
- No invented proof: no testimonials, download counts, logos, press or ratings. Sample content (file names, a server, a user) is allowed in the interface fragments and is labelled as an illustration in the footer.
- Sentence case. Typographic apostrophes (’) in prose. The interface fragments use the app's exact strings.
- One primary action, named for what it does: "Download for Mac", "Download Wharf".

## House rules

These keep the page from looking generated. Each has a reason, and the checks below measure most of them.
- **No eyebrow labels** above headings, no pill badges, no "New" chips. Put the fact in the heading or drop it.
- **No tiny uppercase letter-spaced labels.** Labels are sentence case, one step smaller.
- **No gradients, glows or shadows at rest.** Separate surfaces by a tone step.
- **No thin divider lines** or outlined boxes, except inside `[data-ui]`. Mark those lines with `/* taste-skill-ignore: data-ui … */`.
- **No monospace** outside real code (`<code>`, `<pre>`): the Range header and the Terminal command are real code.
- **No 01/02/03 numbering.** Order is shown by position, or a real `<ol>`.
- **No icon-topped feature cards or rows of identical cards.**
- **No styled accent word** inside a headline: one face, one colour per heading.
- **No literal colours or spacing** outside the token blocks. Use `--space-*` for padding, margin and gap.

## Motion

- The signature move: the monument word sinks from scale 1 to 0.93 as the hero scrolls away (`animation-timeline: scroll(root)`, inside `@supports`). It is the only scroll-linked effect. Don't add a second one.
- Section parts rise 24px and fade in once, staggered 80ms with `style="--i:n"`, through `[data-reveal]` and the observer in `site.js`. Content stays visible without JS: the hidden state only applies under `html.js`.
- Every control has hover, press (`scale(0.97)`) and `:focus-visible` feedback. Animate only `transform`, `opacity`, `scale`, `translate` and colours. Never `transition: all`.
- Everything has a `prefers-reduced-motion` fallback: no travel, the lit-name cycle stopped.
- There is no video on the page. The intro footage was replaced by the real app window, because the product proves "nothing comes ashore" better than a harbour metaphor. The taste checker may warn `no-footage`; that is accepted. Add a video only if it shows Wharf itself.

## Checks before handing back

Run what is installed and fix every FAIL before calling the change done:

```bash
node ~/.claude/skills/design-taste-frontend/scripts/lint.mjs site
node ~/.claude/skills/design-taste-frontend/scripts/inspect.mjs site/index.html   # screenshots at 1440, 768, 390
node ~/.claude/skills/hallmark/scripts/sloplint.mjs site/index.html site/site.css --genre atmospheric
```

Then open the screenshots in `.taste-skill/inspect/` and look at every width. The inspector measures rules but not quality: a headline that technically fits but crowds the screen is still wrong. Known, accepted warnings are the third typeface (the system font inside `[data-ui]`), the size count, and no footage. Waivers and dismissals live as comments at the top of `site.css`. Add one only with a reason specific to this page.

For a new page, copy the `<head>` of `index.html` (fonts, icon, Open Graph tags, the `html.js` line), reuse `site.css`, and add page-specific rules at the end of it rather than in a new stylesheet.

If the skills above are not installed, check by eye against the house rules and say in the report that the checks could not run.

`.taste-skill/` and `.hallmark/` are working folders for those checks. Leave them out of commits.
