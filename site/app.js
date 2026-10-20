const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
const $ = id => document.getElementById(id);

// ---------- topbar color follows the block under it ----------
const topbar = $('topbar'), themeMeta = $('themeColor');
const heroSection = $('hero');
let heroColor = '#FF6B1A';
const barColors = { health:'#D92D20', try:'#2F5BFF', deal:'#FF2D6F', story:'#FFF6EC', private:'#0D0F14', final:'#FF6B1A' };
function syncBar() {
  // sample just below the fixed bar so the color always matches what's underneath
  const probe = document.elementFromPoint(Math.max(0, innerWidth/2), topbar.offsetHeight + 4);
  const theme = probe && probe.closest ? (probe.closest('.block') || {}).dataset?.theme : null;
  const color = theme === 'hero' ? heroColor : (barColors[theme] || heroColor);
  document.body.dataset.block = theme || 'hero';
  topbar.style.setProperty('--bar', color);
  if (themeMeta) themeMeta.content = color;
}
let barQueued = false;
addEventListener('scroll', () => {
  if (barQueued) return; barQueued = true;
  requestAnimationFrame(() => { barQueued = false; syncBar(); });
}, { passive: true });
addEventListener('resize', syncBar);
syncBar();

// ---------- reveal ----------
const revObs = new IntersectionObserver(es => es.forEach(e => {
  if (e.isIntersecting) { e.target.classList.add('in'); revObs.unobserve(e.target); }
}), { threshold: .2 });
document.querySelectorAll('.reveal').forEach(el => revObs.observe(el));

// ---------- helpers ----------
function countUp(el, to, dur=1200, fmt=v=>Math.round(v).toLocaleString('en-IN')) {
  if (reduce) { el.textContent = fmt(to); return; }
  const t0 = performance.now();
  (function f(t){ const p = Math.min(1,(t-t0)/dur);
    el.textContent = fmt(to * (0.2 + 0.8*easeOut(p)) * (p===1?1:1));
    if (p<1) requestAnimationFrame(f); else el.textContent = fmt(to);
  })(t0);
  function easeOut(x){return 1-Math.pow(1-x,3)}
}
function burst(container, n=16, o={}) {
  if (reduce) return;
  const colors = ['#fff','#FFE45E','#111216','#FFD9E6'];
  const l0 = o.l0 ?? 8, l1 = o.l1 ?? 92, b0 = o.b0 ?? 25, b1 = o.b1 ?? 65;
  for (let i=0;i<n;i++){ const s=document.createElement('i');
    s.className = 'cf';
    s.style.left = (l0+Math.random()*(l1-l0))+'%'; s.style.bottom = (b0+Math.random()*(b1-b0))+'%';
    s.style.background = colors[i%colors.length];
    const sz = 6+Math.round(Math.random()*6);
    s.style.width = sz+'px'; s.style.height = Math.round(sz*0.6+4)+'px';
    if (i%3===0) s.style.borderRadius = '50%';
    if (o.dx) s.style.setProperty('--dx', Math.round(o.dx[0]+Math.random()*(o.dx[1]-o.dx[0]))+'px');
    if (o.dy) s.style.setProperty('--dy', Math.round(o.dy[0]+Math.random()*(o.dy[1]-o.dy[0]))+'px');
    container.appendChild(s); setTimeout(()=>s.remove(),1500);
  }
}
function buildBars(el, n, misses=[]) {
  el.innerHTML='';
  for (let i=0;i<n;i++){ const b=document.createElement('i'); el.appendChild(b); }
  return [...el.children];
}

// ---------- 1 HERO cycle ----------
const heroData = [
  { pill:'◉ 12,468 steps', name:'October 10K', rule:'Flexible · 20 of 30 days', wins:12, rem:'8 wins to go in 14 days', max:'₹2,00,000', color:'#FF6B1A', misses:[4,11] },
  { pill:'◎ rings closed', name:'Ring month', rule:'Streak · 30 days in a row', wins:19, rem:'11 wins to go · keep it up', max:'Trip to Taiwan', color:'#FF2D6F', misses:[] },
  { pill:'☾ 7h 42m sleep', name:'Sleep deep', rule:'Flexible · 15 of 21 days', wins:9, rem:'6 wins to go in 9 days', max:'Spa day', color:'#7A5CFF', misses:[2] },
  { pill:'➤ 5.0 km run', name:'Morning run', rule:'Savings jar · ₹500 per win', wins:16, rem:'₹80,000 of ₹2,00,000', max:'Running shoes', color:'#13A866', misses:[7] },
];
function riseFill(el, dur=1300) {
  if (reduce || !el) return;
  el.style.height = ''; el.style.minHeight = ''; el.style.transition = '';
  const full = el.scrollHeight; // measured with natural height
  el.classList.add('rising');
  el.style.minHeight = '0'; // CSS min-height would pin the start height otherwise
  el.style.height = '24px';
  el.getBoundingClientRect();
  el.style.transition = `height ${dur}ms cubic-bezier(.25,.7,.25,1), background-color .5s`;
  el.style.height = full + 'px';
  setTimeout(() => { el.style.height = ''; el.style.minHeight = ''; el.style.transition = ''; el.classList.remove('rising'); }, dur + 60);
}
let hi = 0;
const heroBars = buildBars($('heroBars'), 20);
const heroBtn = $('heroBtn');
function playHero() {
  const d = heroData[hi % heroData.length];
  heroColor = d.color;
  heroSection.style.setProperty('--hero', d.color); // scoped: final stays orange
  document.body.style.background = d.color;
  if (document.body.dataset.block === 'hero') syncBar();
  $('heroFill').style.background = d.color;
  $('heroFill').querySelector('.wave path').style.fill = d.color;
  $('heroPill').textContent = d.pill; $('heroPill').style.background = d.color;
  $('heroName').textContent = d.name; $('heroRule').textContent = d.rule;
  $('heroMax').textContent = d.max; $('heroRem').textContent = d.rem;
  $('heroStamp').style.color = d.color;
  $('heroStamp').classList.remove('show');
  if (heroBtn) heroBtn.style.color = d.color; // download text follows page color
  riseFill($('heroFill'));
  heroBars.forEach(b => b.classList.remove('on','miss'));
  countUp($('heroWins'), d.wins, 1400);
  heroBars.forEach((b,i) => {
    setTimeout(() => {
      if (d.misses.includes(i)) b.classList.add('miss'); else if (i < d.wins+2) b.classList.add('on');
      if (i === heroBars.length-1) {
        const fromStamp = { l0: 60, l1: 95, b0: 68, b1: 92, dx: [-230, 30], dy: [-40, 330] };
        $('heroStamp').classList.add('show');
        burst($('heroConfetti'), 48, fromStamp); // from the stamp, across the whole screen
        setTimeout(() => burst($('heroConfetti'), 30, fromStamp), 320);
      }
    }, reduce ? 0 : 120 + i*90);
  });
  hi++;
}
playHero();
if (!reduce) setInterval(playHero, 4500);

// ---------- HEALTH: counts itself, replay while visible ----------
(() => {
  const sec = $('health');
  if (!sec) return;
  const nums = { steps: $('hStepsNum'), rings: $('hRingsNum'), ex: $('hExNum'), sleep: $('hSleepNum') };
  const bars = { steps: $('hStepsBar'), rings: $('hRingsBar'), ex: $('hExBar'), sleep: $('hSleepBar') };
  const won = $('hWon'), note = $('hNote'), sync = $('hSync');
  const targets = { steps: 10000, rings: 2, ex: 22, sleep: 7.5 };
  const fills = { steps: 100, rings: 66, ex: 73, sleep: 94 };
  const DUR = 3600;
  let raf = 0, replayT = 0, gen = 0;
  const inr = v => Math.round(v).toLocaleString('en-IN');
  function draw(p) {
    const e = 1 - Math.pow(1 - p, 3);
    nums.steps.textContent = inr(targets.steps * e);
    nums.rings.textContent = Math.round(targets.rings * e);
    nums.ex.textContent = Math.round(targets.ex * e);
    nums.sleep.textContent = (targets.sleep * e).toFixed(1);
    bars.steps.style.width = fills.steps * e + '%';
    bars.rings.style.width = fills.rings * e + '%';
    bars.ex.style.width = fills.ex * e + '%';
    bars.sleep.style.width = fills.sleep * e + '%';
  }
  function reset() {
    draw(0);
    won.classList.remove('show'); note.classList.remove('drop');
    sync.textContent = 'Syncing from Apple Health…';
  }
  function visible() {
    const r = sec.getBoundingClientRect();
    return r.top < innerHeight * 0.7 && r.bottom > innerHeight * 0.3;
  }
  function play() {
    const g = ++gen;
    cancelAnimationFrame(raf); clearTimeout(replayT);
    reset();
    if (reduce) { draw(1); won.classList.add('show'); note.classList.add('drop'); sync.textContent = 'Updated just now'; return; }
    const t0 = performance.now();
    (function f(t) {
      if (g !== gen) return;
      const p = Math.min(1, (t - t0) / DUR);
      draw(p);
      if (p < 1) raf = requestAnimationFrame(f);
      else {
        won.classList.add('show'); note.classList.add('drop');
        sync.textContent = 'Updated just now';
        replayT = setTimeout(() => { if (g === gen && visible()) play(); }, 6000);
      }
    })(t0);
  }
  new IntersectionObserver(es => es.forEach(e => {
    if (e.isIntersecting) play(); else { gen++; cancelAnimationFrame(raf); clearTimeout(replayT); }
  }), { threshold: 0.35 }).observe(sec);
})();

// ---------- 2 HOLD TO WALK ----------
(() => {
  const btn = $('holdBtn'), num = $('walkNum'), fill = $('walkFill'), scr = $('walkScreen');
  const card = $('unlockCard'), again = $('walkAgain');
  const zones = [$('walkTop'), $('walkCount'), $('walkBottom')];
  let steps = 0, holding = false, raf = 0, done = false;
  // each text zone turns white only once the fill rising from the bottom reaches it
  function paintWalk() {
    const fillTop = scr.clientHeight - fill.offsetHeight;
    zones.forEach(el => {
      if (!el) return;
      el.classList.toggle('lit', fillTop <= el.offsetTop + el.offsetHeight * 0.35);
    });
  }
  function tick() {
    if (!holding || done) return;
    steps = Math.min(10000, steps + 90);
    num.textContent = steps.toLocaleString('en-IN');
    fill.style.height = (steps/100) + '%';
    paintWalk();
    if (steps >= 10000) finish();
    else raf = requestAnimationFrame(tick);
  }
  function finish() {
    done = true; holding = false;
    card.classList.add('show','shake');
    countUp($('unlockNum'), 10000, 900);
    burst(scr, 26);
    setTimeout(() => burst(scr, 18), 280);
    again.hidden = false;
  }
  const start = e => { e.preventDefault(); if (done) return; holding = true; cancelAnimationFrame(raf); raf = requestAnimationFrame(tick); };
  const stop = () => { holding = false; cancelAnimationFrame(raf); };
  btn.addEventListener('pointerdown', start);
  addEventListener('pointerup', stop); btn.addEventListener('pointerleave', stop);
  again.addEventListener('click', () => {
    steps = 0; done = false; num.textContent = '0'; fill.style.height = '0%';
    zones.forEach(el => el && el.classList.remove('lit'));
    card.classList.remove('show','shake'); again.hidden = true;
  });
})();

// ---------- 3 DEAL loop ----------
(() => {
  const deals = [
    ['walk 10,000 steps','on 20 of 30 days','₹10,000 for each win'],
    ['close my rings','30 days in a row','a trip to Taiwan'],
    ['run 5 km','on 12 of 20 days','running shoes'],
    ['sleep 8 hours','on 15 of 21 days','a spa day'],
    ['burn 500 kcal','on 20 of 30 days','pizza night'],
  ];
  const sent = $('dealSentence'), btn = $('dealBtn');
  let di = 0;
  const words = ['I'];
  async function play() {
    const d = deals[di % deals.length]; di++;
    btn.classList.remove('lit');
    sent.innerHTML = 'I ';
    const parts = [[d[0]],[d[1]],['to win'],[d[2]]];
    // render dashed blanks first
    parts.forEach((p,i) => {
      if (p[0]==='to win') { sent.append(document.createTextNode(' to win ')); return; }
      const s = document.createElement('span'); s.className='blank'; s.textContent = '···';
      s.dataset.full = p[0]; sent.append(s); sent.append(document.createTextNode(' '));
    });
    const blanks = [...sent.querySelectorAll('.blank')];
    for (const b of blanks) {
      await new Promise(r => setTimeout(r, reduce ? 0 : 550));
      const w = document.createElement('span'); w.className='pillw'; w.textContent = b.dataset.full;
      b.replaceWith(w);
    }
    btn.classList.add('lit');
    await new Promise(r => setTimeout(r, reduce ? 1500 : 2600));
    play();
  }
  play();
})();

// ---------- 4 PRIVACY loop ----------
(() => {
  const items = [...document.querySelectorAll('#privList li')];
  const lock = $('privLock');
  async function play() {
    items.forEach(li => li.classList.remove('in'));
    lock.classList.remove('shut');
    await new Promise(r => setTimeout(r, 500));
    lock.classList.add('shut');
    for (const li of items) { await new Promise(r => setTimeout(r, reduce?0:450)); li.classList.add('in'); }
    await new Promise(r => setTimeout(r, 2600));
    play();
  }
  // reveal when visible
  new IntersectionObserver((es, o) => es.forEach(e => { if (e.isIntersecting) { play(); o.disconnect(); } }), {threshold:.4}).observe($('privList'));
})();

// ---------- 5 STORY: Monday becomes wonday ----------
(() => {
  const morphs = [...document.querySelectorAll('.daymorph')], sec = $('story');
  if (!morphs.length || !sec) return;
  if (reduce) { morphs.forEach(m => m.classList.add('won')); return; }
  let timer = 0, gen = 0;
  function play() {
    const g = ++gen;
    morphs.forEach(m => m.classList.remove('won'));
    timer = setTimeout(() => {
      if (g !== gen) return;
      morphs.forEach(m => m.classList.add('won'));
      timer = setTimeout(() => { if (g === gen) play(); }, 3400);
    }, 1600);
  }
  new IntersectionObserver((es, o) => es.forEach(e => {
    if (e.isIntersecting) play(); else { gen++; clearTimeout(timer); }
  }), { threshold: 0.4 }).observe(sec);
})();

// store button placeholder (App Store link when live)
$('storeBtn').addEventListener('click', e => { e.preventDefault(); location.hash = '#top'; });
