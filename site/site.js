// Wharf site: section entrances, the live player, feature notes and the lit name.
(() => {
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Entrances: each part rises once as its section enters.
  const parts = document.querySelectorAll('[data-reveal]');
  if ('IntersectionObserver' in window && !reduce) {
    const io = new IntersectionObserver((entries) => {
      for (const e of entries) if (e.isIntersecting) { e.target.classList.add('is-in'); io.unobserve(e.target); }
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.12 });
    parts.forEach((el) => io.observe(el));
  } else {
    parts.forEach((el) => el.classList.add('is-in'));
  }

  // The live player: the playhead decides the byte range Wharf would request.
  const files = [
    { name: 'Evening on Hong Kong harbour.mkv', size: 8_410_000_000, duration: 6072 },
    { name: 'Tug and sailing ship at the pier.mp4', size: 2_060_000_000, duration: 2910 },
    { name: 'The Entrepot dock, Amsterdam.mkv', size: 24_600_000_000, duration: 8045 },
  ];
  const player = document.querySelector('.player');
  const scrub = document.getElementById('scrub');
  const out = (k) => document.querySelector(`[data-out="${k}"]`);
  let file = 0;
  let frac = scrub ? Number(scrub.value) / Number(scrub.max) : 0;
  let timer = null;

  const timecode = (s) => {
    s = Math.floor(s);
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
    return `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
  };
  const gb = (b) => `${(b / 1e9).toFixed(b >= 1e10 ? 1 : 2)} GB`;

  function render() {
    const f = files[file];
    const offset = Math.floor(frac * f.size);
    out('name').textContent = f.name;
    out('pos').textContent = timecode(frac * f.duration);
    out('dur').textContent = timecode(f.duration);
    out('from').textContent = gb(offset);
    out('size').textContent = gb(f.size);
    out('range').textContent = `Range: bytes=${offset}-`;
    scrub.setAttribute('aria-valuetext', `${timecode(frac * f.duration)} of ${timecode(f.duration)}`);
  }

  function setPlaying(on) {
    player.dataset.state = on ? 'playing' : 'paused';
    const btn = player.querySelector('[data-act="play"]');
    btn.setAttribute('aria-label', on ? 'Pause' : 'Play');
    clearInterval(timer);
    if (on) {
      timer = setInterval(() => {
        frac = Math.min(1, frac + 1 / files[file].duration);
        scrub.value = Math.round(frac * Number(scrub.max));
        render();
        if (frac >= 1) setPlaying(false);
      }, 1000);
    }
  }

  if (player && scrub) {
    scrub.addEventListener('input', () => { frac = Number(scrub.value) / Number(scrub.max); render(); });
    player.querySelector('[data-act="play"]').addEventListener('click', () => setPlaying(player.dataset.state !== 'playing'));

    const tabs = [...document.querySelectorAll('.tab')];
    const select = (i, focus) => {
      file = i;
      tabs.forEach((t, j) => { t.setAttribute('aria-selected', String(j === i)); t.tabIndex = j === i ? 0 : -1; });
      player.querySelectorAll('.player__img').forEach((img) => img.classList.toggle('is-on', Number(img.dataset.file) === i));
      if (focus) tabs[i].focus();
      render();
    };
    tabs.forEach((t, i) => {
      t.addEventListener('click', () => select(i));
      t.addEventListener('keydown', (e) => {
        if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
          e.preventDefault();
          select((i + (e.key === 'ArrowRight' ? 1 : tabs.length - 1)) % tabs.length, true);
        }
      });
    });
    select(0);

    // Starts playing once the player is on screen, so the timecode moves on its own.
    if (!reduce && 'IntersectionObserver' in window) {
      const once = new IntersectionObserver((entries) => {
        if (entries.some((e) => e.isIntersecting)) { setPlaying(true); once.disconnect(); }
      }, { threshold: 0.5 });
      once.observe(player);
    }
  }

  // Features: pointing at a name shows its note in the empty columns.
  const desc = out('desc');
  if (desc) {
    const initial = desc.textContent;
    document.querySelectorAll('.index__group li').forEach((li) => {
      const show = () => { document.querySelectorAll('.index__group li.is-on').forEach((x) => x.classList.remove('is-on')); li.classList.add('is-on'); desc.textContent = li.dataset.desc; };
      li.addEventListener('mouseenter', show);
      li.addEventListener('focus', show);
    });
    document.querySelector('.index__grid').addEventListener('mouseleave', () => {
      document.querySelectorAll('.index__group li.is-on').forEach((x) => x.classList.remove('is-on'));
      desc.textContent = initial;
    });
  }

  // Proof: one name at a time is lit.
  const names = [...document.querySelectorAll('.proof .nm')];
  if (names.length && !reduce) {
    let lit = 0;
    setInterval(() => {
      names[lit].classList.remove('is-lit');
      lit = (lit + 1) % names.length;
      names[lit].classList.add('is-lit');
    }, 2000);
  }

})();
