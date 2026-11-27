/* The deck owns presentation only; Swift-aligned card selection stays in the page. */
(function () {
  const AUTO_MS = 10000;
  function coreOrbitLayout(targets, mode = 'flashes') {
    const total = targets.reduce((sum, slots) => sum + slots, 0);
    if (!total) return [];
    const minimum = mode === 'avatars' ? 36 : 40;
    // The TeamFlash occupies 43% of the 360-unit canvas; keep Idents just below it.
    const maximum = mode === 'avatars' ? 76 : 360 * .43 * .95;
    const gap = 10;
    const innerEdge = mode === 'avatars' ? 80 : 70;
    const outerEdge = 176;
    // Compare feasible ring counts by marker size; a second ring can beat a cramped first one.
    const maxRings = Math.floor((outerEdge - innerEdge + gap) / (minimum + gap));
    const ringsFor = (size, count, staggered) => Array.from({length:count}, (_, row) => {
      const radius = outerEdge - size / 2 - row * (staggered
        ? (outerEdge - innerEdge - size) / (count - 1) : size + gap);
      const capacity = radius - size / 2 < innerEdge - 1e-8 ? 0
        : Math.floor(Math.PI / Math.asin(Math.min(1, (size + gap) / (2 * radius))));
      return {radius, capacity};
    });
    const positionsFor = (size, rings, counts, staggered) => rings.flatMap(({radius}, row) => {
      const lanes = staggered ? Math.ceil(total / rings.length) : counts[row];
      return Array.from({length:counts[row]}, (_, i) => {
        const angle = -Math.PI / 2 + (i + (staggered ? row / rings.length : 0)) * Math.PI * 2 / lanes;
        return {x:180 + Math.cos(angle) * radius, y:180 + Math.sin(angle) * radius, angle, radius, size};
      });
    });
    // Staggered rings use the angular gaps between markers to fit larger symbols.
    let best = null;
    for (let count = 1; count <= Math.min(total, maxRings); count++) {
      for (const staggered of count === 1 ? [false] : [false, true]) {
        const counts = Array.from({length:count}, (_, row) => Math.ceil((total - row) / count));
        const fits = size => {
          const rings = ringsFor(size, count, staggered);
          if (staggered) {
            if (rings.some(r => r.radius - size / 2 < innerEdge - 1e-8)) return false;
            const points = positionsFor(size, rings, counts, true);
            return points.every((a, i) => points.slice(i + 1).every(b => Math.hypot(a.x - b.x, a.y - b.y) >= size + gap));
          }
          return rings.every(r => r.capacity > 0) && rings.reduce((sum, r) => sum + r.capacity, 0) >= total;
        };
        if (!fits(minimum)) continue;
        let low = minimum, high = maximum;
        for (let step = 0; step < 32; step++) {
          const middle = (low + high) / 2;
          if (fits(middle)) low = middle; else high = middle;
        }
        if (!best || low > best.size + .01) best = {size:low, rings:ringsFor(low, count, staggered), staggered};
      }
    }
    const {size, rings, staggered} = best;
    const counts = rings.map((_, row) => staggered ? Math.ceil((total - row) / rings.length) : 1);
    for (let remaining = total - counts.reduce((sum, n) => sum + n, 0); remaining > 0; remaining--) {
      // Fill rings to comparable occupancy without exceeding their chord-based capacities.
      let next = -1;
      rings.forEach((ring, i) => {
        if (counts[i] < ring.capacity && (next < 0 || counts[i] / ring.capacity < counts[next] / rings[next].capacity)) next = i;
      });
      counts[next]++;
    }
    const points = positionsFor(size, rings, counts, staggered);
    // Angular ordering keeps each person's Idents grouped even with unequal weekly targets.
    points.sort((a, b) => a.angle - b.angle || b.radius - a.radius);
    let offset = 0;
    return targets.flatMap((slots, user) => points.slice(offset, offset += slots).map((p, ident) => ({...p, user, ident})));
  }
  function orbitLayout(count, slots, mode = 'flashes') {
    return coreOrbitLayout(Array(count).fill(slots), mode).filter(p => p.user === 0);
  }
  function shouldDismiss(dx, dy) {
    return Math.hypot(dx, dy) > 36;
  }
  function swipeFlight(samples, viewport = {width: 1200, height: 900}) {
    const first = samples[0], last = samples.at(-1);
    const dx = last.x - first.x, dy = last.y - first.y;
    const length = Math.hypot(dx, dy);
    const travel = Math.hypot(viewport.width, viewport.height) * 1.5;
    return {x:(length ? dx / length : 1) * travel, y:(length ? dy / length : 0) * travel,
      spin:(dx < 0 || (dx === 0 && dy < 0) ? -1 : 1) * 360, duration:320};
  }
  function swipeFrames(from, flight) {
    return [{transform:from,opacity:1},
      {transform:`translate(${flight.x}px,${flight.y}px) rotate(${flight.spin}deg)`,opacity:1}];
  }
  function orbitStep(angle, boost, seconds) {
    const decay = Math.exp(-seconds / .8);
    return {angle: (angle + 2 * seconds + boost * .8 * (1 - decay)) % 360, boost: boost * decay};
  }
  function orbitPosition(point, degrees) {
    const radians = degrees * Math.PI / 180;
    const x = point.x - 180, y = point.y - 180;
    return {x: 180 + x * Math.cos(radians) - y * Math.sin(radians),
      y: 180 + x * Math.sin(radians) + y * Math.cos(radians)};
  }
  function memberArc(index, count, done, target) {
    const start = -90 + index * 360 / count + 10;
    const sweep = 360 / count - 20;
    const progress = target > 0 ? Math.max(0, Math.min(1, done / target)) : 0;
    const path = extent => {
      if (extent <= 0) return '';
      const a = start * Math.PI / 180, b = (start + extent) * Math.PI / 180;
      return `M ${180+146*Math.cos(a)} ${180+146*Math.sin(a)} A 146 146 0 ${extent>180?1:0} 1 ${180+146*Math.cos(b)} ${180+146*Math.sin(b)}`;
    };
    return {start, sweep, progress, track:path(sweep), fill:path(sweep*progress)};
  }
  function autoRotationFrames(from, width = 360) {
    const aside = `translate(${-width * 1.08}px,-24px) rotate(-14deg) scale(.96)`;
    return [{transform:from,opacity:1,zIndex:11},
      {transform:aside,opacity:1,zIndex:11,offset:.48},
      {transform:aside,opacity:1,zIndex:0,offset:.50},
      {transform:'translate(0,14px) rotate(-12deg) scale(.93)',opacity:1,zIndex:0}];
  }
  class DeckSequence {
    constructor(count, changed, schedule = (fn, delay) => setTimeout(fn, delay), cancel = id => clearTimeout(id)) {
      this.count = count;
      this.changed = changed; this.schedule = schedule; this.cancel = cancel;
      this.queue = Array.from({length: count}, (_, i) => i);
      this.phase = count ? 'cards' : 'core';
      this.onAuto = () => this.rotate();
    }
    get index() { return this.queue[0]; }
    arm() {
      this.stop();
      if (this.phase === 'cards' && this.queue.length > 1)
        this.timer = this.schedule(() => this.onAuto(), AUTO_MS);
    }
    stop() { this.cancel(this.timer); }
    rotate() {
      if (this.phase !== 'cards') return;
      if (this.queue.length > 1) this.queue.push(this.queue.shift());
      this.changed(this); this.arm();
    }
    dismiss() {
      if (this.phase !== 'cards') return;
      this.queue.shift();
      if (!this.queue.length) this.phase = 'core';
      this.changed(this); this.arm();
    }
    core() { this.stop(); this.phase = 'core'; this.changed(this); }
    reset() {
      this.stop(); this.queue = Array.from({length: this.count}, (_, i) => i);
      this.phase = this.count ? 'cards' : 'core'; this.changed(this); this.arm();
    }
  }
  if (typeof module !== 'undefined') module.exports = {coreOrbitLayout, orbitLayout, shouldDismiss, DeckSequence, AUTO_MS, swipeFlight, swipeFrames, orbitStep, orbitPosition, memberArc, autoRotationFrames};
  if (typeof document === 'undefined') return;
  const host = document.getElementById('ignite-team-demo');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const colors = ['#a6421c', '#6b4dc4', '#218073', '#b4781c'];
  const names = ['Du', 'Greta', 'Veit', 'Mila'];
  const instances = new Set();
  let previewMembers = 3, previewSlots = 7, override = false, coreMode = 'flashes';
  const tools = document.createElement('fieldset');
  tools.className = 'it-control-group it-deck-tools';
  tools.dataset.controls = 'core';
  tools.innerHTML = `<legend>Core</legend><label>Mitglieder <select data-core-members>${[1,2,3,4].map(n=>`<option ${n===3?'selected':''}>${n}</option>`).join('')}</select></label><label>Idents pro Person <span class="it-control-range"><input data-core-slots type="range" min="1" max="7" value="7"><output>7</output></span></label><label>Umlauf <select data-core-mode><option value="flashes">Flashes</option><option value="arcs">Fortschrittsbögen</option></select></label><div class="it-control-actions"><button type="button" data-preview-core>Core ansehen</button></div>`;
  host.querySelector('.it-design-controls').appendChild(tools);

  // Snapshot computed styles so the floating card retains its exact appearance outside the phone.
  function floatingCard(source, track, local = false) {
    const clone = source.cloneNode(true);
    const originals = [source, ...source.querySelectorAll('*')];
    const copies = [clone, ...clone.querySelectorAll('*')];
    originals.forEach((node, i) => {
      const style = getComputedStyle(node);
      copies[i].style.cssText = Array.from(style).map(key => `${key}:${style.getPropertyValue(key)};`).join('');
      copies[i].removeAttribute('id');
    });
    const rect = track.getBoundingClientRect();
    const layer = document.createElement('div');
    layer.className = 'it-flight-layer';
    layer.inert = true;
    layer.setAttribute('aria-hidden', 'true');
    Object.assign(layer.style, {position:'fixed', inset:'0', pointerEvents:'none', zIndex:'2147483647', perspective:'1200px'});
    Object.assign(clone.style, {position:'absolute', left:rect.left+'px', top:rect.top+'px',
      width:rect.width+'px', height:rect.height+'px', margin:'0', inset:'auto',
      visibility:'visible', opacity:'1', display:'flex', transition:'none', animation:'none',
      transformOrigin:'50% 50%', pointerEvents:'none'});
    // inset must precede left/top: do not let the snapshot's layout positioning win.
    clone.style.left=rect.left+'px'; clone.style.top=rect.top+'px';
    if (local) {
      Object.assign(clone.style, {left:'0', top:'0', zIndex:'11'});
      track.appendChild(clone);
    } else {
      layer.appendChild(clone); document.body.appendChild(layer);
    }
    source.style.visibility = 'hidden';
    return {clone, layer:local?clone:layer, source, base:clone.style.transform};
  }

  function mount(root) {
    const shell = root.querySelector('.it-hero-carousel');
    if (!shell || shell.dataset.deckMounted) return;
    const previous = [...instances].find(i => i.root === root);
    const saved = previous ? {queue:[...previous.sequence.queue], phase:previous.sequence.phase, key:previous.key} : null;
    if (previous) { previous.dispose(); instances.delete(previous); }
    shell.dataset.deckMounted = 'true';
    const data = JSON.parse(shell.dataset.core || '{}');
    const slides = [...shell.querySelectorAll('.it-hero-slide')];
    const track = shell.querySelector('.it-hero-track');
    const key = JSON.stringify(data);
    shell.querySelector('.it-hero-pagination')?.remove();
    track.onscroll = null; track.scrollLeft = 0;
    track.tabIndex = 0; track.setAttribute('aria-label','Kartenstapel: klicken zum Wechseln, ziehen zum Entfernen');
    shell.insertAdjacentHTML('beforeend','<div class="it-core" aria-label="Teamfortschritt"></div>');
    let gesture=null, thrownPointer=null, flying=false, floating=null, swallowUntil=0, disposed=false;
    let coreKey='', angle=0, boost=0, lastFrame=0, frame=0, orbitGroup=null, orbitMarkers=[];
    const sequence = new DeckSequence(slides.length, paint);
    const instance = {root, key, sequence, paintCore, dispose};
    instances.add(instance);
    if (saved && saved.key === key) {sequence.queue=saved.queue; sequence.phase=saved.phase;}

    function paintCore() {
      const memberCount = override ? previewMembers : (data.done?.length || 3);
      const targets = override ? Array(memberCount).fill(previewSlots) : (data.targets || [3,3,3]);
      const done = override ? Array.from({length:memberCount},(_,i)=>Math.max(0,previewSlots-i)) : (data.done || [2,1,2]);
      const nextKey = JSON.stringify({done,targets,coreMode});
      if (coreKey === nextKey) return;
      coreKey = nextKey;
      const total=done.reduce((a,b)=>a+b,0), target=targets.reduce((a,b)=>a+b,0);
      const summary = root.teamWeekProgressFlash;
      const dark = root.querySelector('.it-phone').dataset.infoTheme === 'dark';
      const palette = dark ? ['#e9a681','#b9a4ed','#75bdaf','#e7be70'] : colors;
      const minis = coreMode === 'arcs' ? targets.map((slots,user)=>{
        const arc=memberArc(user,memberCount,done[user],slots);
        return `<g style="color:${palette[user]}"><title>${names[user]}: ${done[user]}/${slots}</title><path d="${arc.track}" fill="none" stroke="currentColor" stroke-width="20" stroke-linecap="round" opacity=".10"/>${arc.fill?`<path d="${arc.fill}" fill="none" stroke="currentColor" stroke-width="20" stroke-linecap="round"/>`:''}</g>`;
      }).join('') : coreOrbitLayout(targets.map(slots=>Math.min(7,slots)),coreMode).map(p=>{
        const {user,ident:i,size}=p;
        const base=p;
        const position=orbitPosition(base,angle);
        const opacity=i<done[user]?1:.12;
        const id=`avatar-${root.dataset.screenId}-${user}-${i}`;
        const glyph=coreMode==='avatars'
          ? `<defs><clipPath id="${id}"><circle r="${size/2}"/></clipPath></defs><circle r="${size/2}" fill="${palette[user]}"/><image href="assets/member-${user+1}.jpg" x="${-size/2}" y="${-size/2}" width="${size}" height="${size}" preserveAspectRatio="xMidYMid slice" clip-path="url(#${id})"/>`
          : `<svg x="${-size/2}" y="${-size/2}" width="${size}" height="${size}" viewBox="0 0 512 512" style="color:${palette[user]}"><use href="#it-brand-flash" fill="currentColor"/></svg>`;
        return `<g data-orbit-marker data-x="${base.x}" data-y="${base.y}" transform="translate(${position.x} ${position.y})" opacity="${opacity}">${glyph}</g>`;
      }).join('');
      shell.querySelector('.it-core').innerHTML=`<div class="it-core-universe"><svg class="it-core-orbit" viewBox="0 0 360 360" role="img" aria-label="${targets.map((slots,i)=>`${names[i]}: ${done[i]} von ${slots}`).join(', ')}"><g data-core-orbit${coreMode==='arcs'?` transform="rotate(${angle} 180 180)"`:''}>${minis}</g></svg><button type="button" class="it-core-center" data-core-boost aria-label="Teamfortschritt: ${total} von ${target} Idents. Umlauf anschubsen">${summary({name:'Team',color:dark?'#fff3e5':'#24201d'},total,target,'core-team')}</button></div>`;
      orbitGroup=shell.querySelector('[data-core-orbit]');
      orbitMarkers=[...shell.querySelectorAll('[data-orbit-marker]')].map(node=>({node,point:{x:Number(node.dataset.x),y:Number(node.dataset.y)}}));
      root.animateTeamWeekWater?.();
    }
    function animateOrbit(now) {
      if (disposed) return;
      const dt=lastFrame?Math.min(.05,(now-lastFrame)/1000):0; lastFrame=now;
      if (!document.hidden && !reduced && shell.dataset.coreReady === 'true') {
        ({angle,boost}=orbitStep(angle,boost,dt));
        if (coreMode==='arcs') orbitGroup?.setAttribute('transform',`rotate(${angle} 180 180)`);
        else for (const {node,point} of orbitMarkers) {
          const p=orbitPosition(point,angle);
          node.setAttribute('transform',`translate(${p.x} ${p.y})`);
        }
      }
      frame=requestAnimationFrame(animateOrbit);
    }
    function paint() {
      if (disposed) return;
      shell.dataset.deckPhase=sequence.phase;
      shell.dataset.coreReady=String(sequence.phase==='core'||sequence.queue.length===1);
      shell.querySelector('.it-core').setAttribute('aria-hidden',String(sequence.phase!=='core'));
      slides.forEach((slide,i)=>{
        const depth=sequence.queue.indexOf(i);
        slide.hidden=depth<0||depth>2||sequence.phase!=='cards';
        slide.inert=depth!==0||sequence.phase!=='cards';
        slide.setAttribute('aria-hidden',String(slide.inert));
        slide.dataset.autoHint=String(depth===0&&sequence.queue.length>1);
        slide.style.setProperty('--depth',depth);
        slide.style.setProperty('--angle',(depth===0?-1.5:depth===1?9:-12)+'deg');
        slide.style.zIndex=String(10-depth);
        slide.style.transform=''; slide.style.visibility=''; slide.style.opacity='';
        slide.style.animation='none'; void slide.offsetWidth; slide.style.animation='';
      });
      paintCore();
    }
    function clearFloating() {
      if (!floating) return;
      floating.source.style.visibility=''; floating.layer.remove(); floating=null;
    }
    function fly(automatic=false, samples=null) {
      if (flying||sequence.phase!=='cards') return;
      if (automatic&&sequence.queue.length<=1) {
        clearFloating(); paint(); sequence.arm(); return;
      }
      flying=true; sequence.stop();
      if (automatic && floating) clearFloating();
      if (!floating) floating=floatingCard(slides[sequence.index],track,automatic);
      const current=floating;
      const from=getComputedStyle(current.clone).transform;
      const flight=samples?swipeFlight(samples,{width:innerWidth,height:innerHeight}):null;
      const frames=automatic
        ? autoRotationFrames(from,track.getBoundingClientRect().width)
        : swipeFrames(from,flight);
      // Promote the next card immediately, underneath the free-floating outgoing surface.
      if (automatic) sequence.rotate(); else sequence.dismiss();
      current.source.style.visibility='hidden';
      const animation=current.clone.animate(frames,{duration:reduced?1:automatic?850:flight.duration,easing:automatic?'cubic-bezier(.4,0,.2,1)':'linear',fill:'forwards'});
      animation.finished.then(()=>{
        animation.cancel();
        if (floating===current) clearFloating();
        flying=false;
      }).catch(()=>{clearFloating();flying=false;});
    }
    sequence.onAuto=()=>fly(true);
    track.addEventListener('dragstart',e=>e.preventDefault());
    track.addEventListener('pointerdown',e=>{
      if (sequence.phase!=='cards'||flying||e.isPrimary===false||e.button>0||e.target.closest('button,a,input,select'))return;
      e.preventDefault(); sequence.stop();
      track.focus({preventScroll:true});
      floating=floatingCard(slides[sequence.index],track);
      gesture={id:e.pointerId,samples:[{x:e.clientX,y:e.clientY,t:performance.now()}]};
      track.setPointerCapture(e.pointerId);
    });
    function move(e) {
      if (!gesture||gesture.id!==e.pointerId)return;
      const start=gesture.samples[0];
      gesture.samples.push({x:e.clientX,y:e.clientY,t:performance.now()});
      const dx=e.clientX-start.x,dy=e.clientY-start.y;
      floating.clone.style.transform=`translate(${dx}px,${dy}px) rotate(${dx*.045-1.5}deg)`;
      if (shouldDismiss(dx,dy)) {
        const samples=gesture.samples;
        thrownPointer=gesture.id; gesture=null; swallowUntil=Infinity;
        fly(false,samples);
      }
    }
    track.addEventListener('pointermove',move);
    function release(e,cancelled=false) {
      if (thrownPointer===e.pointerId) {
        thrownPointer=null; swallowUntil=performance.now()+400; return;
      }
      if (!gesture||gesture.id!==e.pointerId)return;
      if (!cancelled&&Number.isFinite(e.clientX))move(e);
      if (!gesture) {thrownPointer=null;swallowUntil=performance.now()+400;return;}
      const samples=gesture.samples, first=samples[0],last=samples.at(-1);
      const dx=last.x-first.x,dy=last.y-first.y;
      gesture=null; swallowUntil=performance.now()+400;
      if (!cancelled&&Math.hypot(dx,dy)<8) {fly(true);return;}
      const current=floating;
      const animation=current.clone.animate([{transform:getComputedStyle(current.clone).transform},{transform:current.base}],{duration:reduced?1:420,easing:'cubic-bezier(.2,1.4,.4,1)',fill:'forwards'});
      flying=true;
      animation.finished.finally(()=>{clearFloating();flying=false;if(!disposed){paint();sequence.arm();}});
    }
    track.addEventListener('pointerup',e=>release(e));
    track.addEventListener('pointercancel',e=>release(e,true));
    track.addEventListener('lostpointercapture',e=>release(e,true));
    const onUp=e=>release(e), onBlur=()=>{if(gesture||thrownPointer!==null)release({pointerId:gesture?.id??thrownPointer},true);};
    window.addEventListener('pointerup',onUp); window.addEventListener('blur',onBlur);
    shell.addEventListener('click',e=>{
      if (performance.now()<swallowUntil){e.preventDefault();e.stopPropagation();return;}
      if (e.target.closest('[data-core-boost]')) {
        boost=Math.min(90,boost+42);
        if(!reduced)e.target.closest('button').animate([{transform:'translate(-50%,-50%) scale(1)'},{transform:'translate(-50%,-50%) scale(.94)'},{transform:'translate(-50%,-50%) scale(1)'}],{duration:380,easing:'ease-out'});
      }
    },true);
    track.addEventListener('keydown',e=>{
      if (e.target===track&&['Enter',' ','ArrowRight'].includes(e.key)){e.preventDefault();fly(true);}
    });
    instance.visibility=()=>{
      if(document.hidden){sequence.stop();slides[sequence.index]?.style.setProperty('animation-play-state','paused');}
      else{paint();sequence.arm();}
    };
    function dispose() {
      disposed=true; sequence.stop(); cancelAnimationFrame(frame); clearFloating();
      window.removeEventListener('pointerup',onUp); window.removeEventListener('blur',onBlur);
    }
    paint(); sequence.arm(); frame=requestAnimationFrame(animateOrbit);
  }
  tools.addEventListener('change',e=>{
    if(e.target.matches('[data-core-members]')){previewMembers=Number(e.target.value);override=true;}
    if(e.target.matches('[data-core-slots]')){previewSlots=Number(e.target.value);tools.querySelector('output').value=previewSlots;override=true;}
    if(e.target.matches('[data-core-mode]'))coreMode=e.target.value;
    instances.forEach(i=>{i.paintCore();i.sequence.core();});
  });
  host.querySelector('.it-design-controls').addEventListener('click',e=>{
    if(e.target.closest('[data-preview-core]'))instances.forEach(i=>i.sequence.core());
    if(e.target.closest('[data-replay-deck]'))instances.forEach(i=>i.sequence.reset());
  });
  document.addEventListener('visibilitychange',()=>instances.forEach(i=>i.visibility()));
  host.querySelectorAll('[data-screen]').forEach(root=>{
    mount(root);
    new MutationObserver(records=>{if(records.some(r=>r.target===root.querySelector('.it-scene')))mount(root);}).observe(root.querySelector('.it-scene'),{childList:true});
  });
})();
