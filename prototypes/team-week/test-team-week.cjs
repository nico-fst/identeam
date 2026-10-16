const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const html=fs.readFileSync(__dirname+'/team-week-views.html','utf8');
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
function surface(row,kind){
 const clip=row.match(new RegExp('class="'+kind+'"[^>]*style="clip-path:([^"]+)"'))[1];
 return [...clip.matchAll(/([\d.-]+)% ([\d.-]+)%/g)].slice(0,26).map(m=>Number(m[2]));
}
function assertWaterLevel(row,done,target){
 const ys=surface(row,'it-progress-fill');
 assert.equal(ys.length,26);
 const level=100*(1-Math.min(done/target,1));
 assert.ok(ys.every(y=>Math.abs(y-level)<=3.001));
 if(done>0&&done<target)assert.ok(Math.max(...ys)-Math.min(...ys)>5);
 else assert.ok(ys.every(y=>y===level));
}
function mount({reducedMotion=false,streak=4,initialWeek=0,scenario='near',ownScenario='near',streakFirst=false}={}){
 const classes=new Set();
 const scene={innerHTML:'',getBoundingClientRect(){return{left:0,top:0};},appendChild(){},classList:{add(c){classes.add(c);},remove(c){classes.delete(c);},contains(c){return classes.has(c);}}};
 const animations=[];
 const events={};
 let focusedMode=null;
 const info={hidden:true};
 const hint={hidden:true,textContent:''};
 const goalFeedback={hidden:true,textContent:''};
 const pageStyle={setProperty(key,value){this[key]=value;}};
 const heroStyle={setProperty(key,value){this[key]=value;}};
 const infoButton={attributes:{'aria-expanded':'false'},setAttribute(k,v){this.attributes[k]=v;},focus(){}};
 const start={checked:streakFirst,addEventListener(event,fn){assert.equal(event,'change');this.change=fn;}};
 const design={value:'classic',addEventListener(event,fn){assert.equal(event,'change');this.change=fn;}};
 const select={value:scenario,addEventListener(event,fn){assert.equal(event,'change');this.change=fn;}};
 const node=(kind,rect,style={},dataset={})=>({dataset,style,setAttribute(){},remove(){},cloneNode(){return node('exit-'+kind,rect,{...style},{...dataset});},getBoundingClientRect(){return rect;},animate(frames,options){animations.push({kind,dataset,frames,options});return{finished:Promise.resolve()};}});
 const heroTrack={style:{},clientWidth:400,scrollLeft:0,scrollTo(options){this.scrollLeft=options.left;if(this.onscroll)this.onscroll();}};
 const root={
  dataset:{screenId:'demo',streak:String(streak),weekOffset:String(initialWeek),scenario:ownScenario},
  addEventListener(event,handler){events[event]=handler;},
  querySelector(selector){
   if(selector.startsWith('[data-week-step=')||selector==='.it-date-picker summary')return{focus(){focusedMode=selector;}};
   if(selector==='.it-teamtop .it-streak')return node('header-flame',{left:380,top:24,width:72,height:84});
   if(selector==='.it-phone')return node('phone',{left:0,top:0,width:480,height:900},pageStyle);
   if(selector==='.it-hero')return node('hero',{top:120,height:200},heroStyle);
   if(selector==='.it-goal-feedback')return goalFeedback;
   if(selector==='.it-screen-situation')return{textContent:''};
   if(selector==='#it-streak-first')return start;
   if(selector==='#it-streak-design')return design;
   if(selector==='#it-scenario')return select;
   if(selector==='.it-hero-track')return heroTrack;
   if(selector==='.it-scene')return scene;
   if(selector==='.it-info-panel')return info;
   if(selector==='[data-info]')return infoButton;
   if(selector==='.it-week-content')return node('content',{left:20,top:180,width:400,height:300});
   if(selector==='.it-today-highlight'){
    const detailed=scene.innerHTML.includes('data-view="detailed"');
    return node('today',{left:detailed?220:210,top:200,width:detailed?35:45,height:detailed?284:175});
   }
   if(selector==='.it-week')return node('week',{height:scene.innerHTML.includes('data-view="detailed"')?320:240});
   if(selector==='.it-detail-hint')return hint;
   const mode=selector.match(/\[data-mode="(.*?)"\]/);
   if(mode)return{focus(){focusedMode=mode[1];}};
   throw new Error('Unexpected selector: '+selector);
  },
  querySelectorAll(selector){
   if(selector==='[data-screen]')return[root];
   if(selector==='.it-hero-slide')return [...scene.innerHTML.matchAll(/class="it-hero-slide"/g)].map((_,i)=>node('hero-slide',{height:i===0?240:360}));
   if(selector==='.it-today'){
    const detailed=scene.innerHTML.includes('data-view="detailed"');
    return detailed?[0,1,2,3].map(i=>node('day',{left:220,right:255,top:200+i*71,bottom:200+(i+1)*71})): [node('day',{left:210,right:255,top:200,bottom:375})];
   }
   if(selector==='[data-side]')return [...scene.innerHTML.matchAll(/data-side="(left|right)" data-row="(\d)"/g)].map(m=>node('side',{left:m[1]==='left'?20:350,top:220+Number(m[2])*84,width:48,height:70},{},{side:m[1],row:m[2]}));
   if(selector==='[data-weekday]'){
    const detailed=scene.innerHTML.includes('data-view="detailed"');
    return [...scene.innerHTML.matchAll(/data-weekday="(\d)"/g)].map(m=>node('weekday',{left:(detailed?80:30)+Number(m[1])*(detailed?35:45),top:detailed?185:195,width:18,height:16},{},{weekday:m[1]}));
   }
   if(selector==='[data-ident]'){
    const detailed=scene.innerHTML.includes('data-view="detailed"');
    return [...scene.innerHTML.matchAll(/<span class="it-mark [^"]+" style="([^"]*)"[^>]*data-ident="(\d)-(\d)"/g)].map(m=>{
     const dx=Number(m[1].match(/--dx:([-\d]+)/)?.[1]||0);
     const dy=Number(m[1].match(/--dy:([-\d]+)/)?.[1]||0);
     return node('ident',{left:(detailed?80:30)+Number(m[3])*(detailed?35:45)+dx,top:200+(detailed?Number(m[2])*84:dy),width:48,height:64},{},{ident:m[2]+'-'+m[3]});
    });
   }
   if(selector==='.it-team-track span')return [...scene.innerHTML.matchAll(/class="it-team-track"><span style="width:([^"]*)"/g)].map(m=>node('team-bar',{}, {width:m[1]}));
   if(selector==='.it-number-inverse'||selector==='.it-number-base'){
    const kind=selector.slice(1);
    return [...scene.innerHTML.matchAll(new RegExp('class="'+kind+'" style="clip-path:([^"]*)"','g'))].map(m=>node(kind,{}, {clipPath:m[1]}));
   }
   if(selector==='.it-progress-wave-back')return [...scene.innerHTML.matchAll(/class="it-progress-wave-back"[^>]*style="clip-path:([^"]*)"/g)].map(m=>node('back-wave',{}, {clipPath:m[1]}));
   if(selector==='.it-progress-fill')return [...scene.innerHTML.matchAll(/class="it-progress-fill"[^>]*style="clip-path:([^"]*)"/g)].map(m=>node('fill',{}, {clipPath:m[1]}));
   return[];
  }
 };
 vm.runInNewContext(script,{
  document:{getElementById(id){assert.equal(id,'ignite-team-demo');return root;}},
  matchMedia(){return{matches:reducedMotion};},
  getComputedStyle(){return{transform:'none'};}
 });
 return{scene,select,design,start,animations,info,infoButton,hint,goalFeedback,pageStyle,heroStyle,heroTrack,
  setGoal(){events.click({target:{closest(selector){return selector==='[data-set-goal]'?{}:null;}}});},
  heroSlide(index){events.click({target:{closest(selector){return selector==='[data-hero-slide]'?{dataset:{heroSlide:String(index)}}:null;}}});},
  stepWeek(step){events.click({target:{closest(selector){return selector==='[data-week-step]'?{dataset:{weekStep:String(step)}}:null;}}});},
  today(){events.click({target:{closest(selector){return selector==='[data-current-week]'?{}:null;}}});},
  date(value){events.change({target:{value,matches(selector){return selector==='[data-week-date]';}}});},
  swipe(dx,dy=0){
   events.pointerdown({pointerId:1,isPrimary:true,button:0,clientX:200,clientY:200,target:{closest(selector){return selector==='.it-week-content'?{}:null;}}});
   events.pointerup({pointerId:1,clientX:200+dx,clientY:200+dy});
  },
  clickWeek(){events.click({target:{closest(selector){return selector==='[data-expand-week]'?{}:null;}}});},
  clickIdent(){events.click({target:{closest(selector){return selector==='[data-open-ident]'?{dataset:{openIdent:'0-0'}}:null;}}});},
  switchMode(mode){if(scene.innerHTML.includes('data-view="'+mode+'"'))return;events.click({target:{closest(selector){return selector==='[data-mode]'?{dataset:{mode}}:null;}}});},
  toggleInfo(){events.click({target:{closest(selector){return selector==='[data-info]'?infoButton:null;}}});},
  key(key){events.keydown({key,preventDefault(){},target:{closest(){return{dataset:{mode:'combined'}};}}});},
  get focusedMode(){return focusedMode;}
 };
}
test('every requested situation defaults to Combined with correct totals and a hidden legend',()=>{
 const {scene,select}=mount();
 for(const [key,value] of Object.entries({near:8,behind:3,catchup:6,start:0,you:2,team:6})){
  select.value=key;select.change();
  const out=scene.innerHTML;
  if(key==='catchup')assert.equal((out.match(/class="it-hero-member(?: it-hero-member-self)?"/g)||[]).length,3);
  else if(key==='start'||key==='you')assert.equal((out.match(/data-hero-summary=/g)||[]).length,3);
  else assert.ok(out.includes(key==='near'?`<strong>Noch ${9-value}</strong>`:key==='behind'?`<strong>${value}<span class="it-hero-target">/10</span></strong>`:`<strong>${value} / ${key==='you'?3:key==='behind'?10:9}</strong>`),key);
  assert.equal((out.match(/class="it-day /g)||[]).length,7,key);
  assert.ok(out.includes('data-view="combined"'));
  assert.ok(out.includes('id="it-ident-info-demo" class="it-info-panel" hidden'));
  assert.ok(!out.includes('<details>'));
  assert.equal((out.match(/class="it-personrow"/g)||[]).length,0);
  assert.ok(!out.includes('undefined'));
  assert.ok(out.includes('class="it-streak" role="img" aria-label="4 Wochen Streak"'));
  assert.ok(out.includes('<span class="it-streak-art" aria-hidden="true"></span>'));
  assert.ok(out.includes('<strong aria-hidden="true">4</strong>'));
  assert.ok(!out.includes('>4 Wochen Streak<'));
 }
});
test('planned, completed and missed flashes stay in each person color; shared days stack diagonally',()=>{
 const {scene,select}=mount();select.value='behind';select.change();
 const out=scene.innerHTML;
 for(const kind of ['it-done','it-planned','it-missed'])assert.ok(out.includes(kind));
 for(const name of ['Du','Lena','Max'])assert.ok(out.includes(`aria-label="${name}: verpasst"`));
 assert.ok(!out.includes('it-todaynote'));
 assert.ok(out.includes('--dy:12px')); 
 assert.ok(out.includes('--dx:8px'));
 assert.ok(!out.includes('it-x'));
 assert.ok(out.includes('aria-valuenow="3" aria-valuemin="0" aria-valuemax="10"'));
});
test('Detailed shows one row per person and a correctly filled goal flash without progress bars',()=>{
 const app=mount();
 for(const key of ['near','behind','catchup','start','you','team']){
  app.select.value=key;app.select.change();app.switchMode('detailed');
  const out=app.scene.innerHTML;
  const rows=[...out.matchAll(/<tr class="it-personrow">([\s\S]*?)<\/tr>/g)];
  assert.equal(rows.length,3);
  for(const [index,row] of rows.entries()){
   const target=key==='behind'&&index===1?4:3;
   const done=(row[1].match(/it-mark it-done/g)||[]).length;
   assert.ok(row[1].includes(`aria-valuenow="${done}" aria-valuemin="0" aria-valuemax="${target}"`));
   assert.ok(row[1].includes(`<strong class="it-progress-number">${done}<span>/${target}</span></strong>`));
   assertWaterLevel(row[1],done,target);
   assert.ok(!row[1].includes('it-track'));
  }
  assert.equal((out.match(/data-progress-user=/g)||[]).length,3);
  assert.ok(!out.includes('it-progresscell'));
  assert.ok(!out.includes('it-stack'));
  assert.ok(out.includes('<th scope="col" aria-label="Person"></th>'));
  assert.ok(out.includes('class="it-progress-column" aria-label="Ziel"></th>'));
  assert.equal((out.slice(out.indexOf('<table class="it-grid"')).match(/class="it-progress-flash">[\s\S]*?<strong class="it-progress-number">[^<]+<span>\/[34]<\/span><\/strong><\/div>/g)||[]).length,3);
  assert.ok(!out.includes('>Person</th>')&&!out.includes('>Ziel</th>'));
 }
 assert.ok(html.includes('grid-template-columns:repeat(7,minmax(0,1fr))'));
 assert.ok(html.includes('table-layout:fixed'));
 assert.ok(html.includes('data:font/ttf;base64,'));
 assert.ok(Buffer.byteLength(html)<1000000);
});

test('missed idents are normally filled with reduced opacity and an opaque halo',()=>{
 const {scene,select}=mount();select.value='behind';select.change();
 assert.ok(scene.innerHTML.includes('it-mark it-missed'));
 assert.ok(html.includes('.it-missed use{fill:currentColor;stroke:none}'));
 assert.ok(html.includes('.it-missed use:not(.it-halo){opacity:.2}'));
 assert.ok(!/\.it-missed\{[^}]*opacity/.test(html));
 assert.ok(!scene.innerHTML.includes('it-x'));
 assert.ok(!html.includes('stroke-dasharray'));
});

test('planned stacked flashes use an opaque fill matching their day background',()=>{
 const {scene,select}=mount();select.value='start';select.change();
 assert.ok(scene.innerHTML.includes('it-mark it-planned'));
 const style=html.match(/\.it-planned use\{([^}]+)\}/)[1];
 assert.ok(style.includes('fill:var(--it-mark-bg,var(--it-surface))'));
 assert.ok(!style.includes('opacity'));
 assert.ok(!style.includes('fill:none'));
 assert.match(html,/\.it-today-highlight\{[^}]*background:color-mix\(in srgb,var\(--it-orange\) 11%,var\(--it-surface\)\)/);
 assert.ok(html.includes('--it-mark-bg:color-mix(in srgb,var(--it-orange) 11%,var(--it-surface))'));
});

test('preview survives a non-UTF-8 transport without corrupting labels',()=>{
 assert.ok([...html].every(c=>c.charCodeAt(0)<128), 'Source must be encoding independent');
 const {scene,select}=mount();
 for(const key of ['near','behind','catchup','start','you','team']){
  select.value=key;select.change();
  const out=scene.innerHTML;
  assert.ok(out.includes('–'), 'Empty days use the intended dash');
  assert.ok(out.includes('>Smart</button>'));
  assert.ok(!out.includes('verpasste Termine zählen nicht zum Fortschritt'));
  assert.ok(!out.includes('it-todaynote'));
  assert.ok(!/[ÃÂâ�]/.test(out), 'No mojibake in generated labels');
 }
});

test('compact week keeps larger flashes and stacks them diagonally',()=>{
 const {scene,select}=mount();
 for(const key of ['near','behind','catchup','start','you','team']){
  select.value=key;select.change();
  assert.ok(scene.innerHTML.includes('--dy:0px'));
  const offsets=[...scene.innerHTML.matchAll(/--dx:([^;]+)px;--dy:(\d+)px/g)];
  assert.ok(offsets.every(offset=>[-8,-4,0,4,8].includes(Number(offset[1]))));
  assert.ok(offsets.every(offset=>[0,6,12].includes(Number(offset[2]))));
 }
 const style=html.match(/\.it-stack \.it-mark\{([^}]+)\}/)[1];
 assert.ok(style.includes('top:calc(2px + var(--dy))'));
 assert.ok(style.includes('width:clamp(40px,10vw,48px)'));
 assert.ok(style.includes('height:64px'));
 assert.ok(html.includes('.it-grid .it-mark{width:clamp(40px,10vw,48px);height:64px;'));
});

test('missed idents always come last in each compact day stack',()=>{
 const {scene,select}=mount();let mixed=0;
 for(const key of ['near','behind','catchup','start','you','team']){
  select.value=key;select.change();
  const stacks=[...scene.innerHTML.matchAll(/<span class="it-stack">([\s\S]*?)<\/span><\/div>/g)];
  assert.equal(stacks.length,7);
  for(const stack of stacks){
   const states=[...stack[1].matchAll(/class="it-mark it-(done|planned|missed)"/g)].map(m=>m[1]);
   const firstMissed=states.indexOf('missed');
   if(firstMissed!==-1){
    assert.ok(states.slice(firstMissed).every(s=>s==='missed'));
    if(firstMissed>0)mixed++;
   }

  }
 }
 assert.ok(mixed>0,'Exercise days with both missed and other idents');
});

test('planned outlines have an opaque wider halo behind their colored contour',()=>{
 const {scene,select}=mount();select.value='start';select.change();
 assert.ok(scene.innerHTML.includes('<use class="it-halo" href="#it-brand-flash"/><use href="#it-brand-flash"/>'));
 const halo=html.match(/\.it-planned \.it-halo,[^{]+\{([^}]+)\}/)[1];
 const outline=html.match(/\.it-planned use\{([^}]+)\}/)[1];
 assert.ok(Number(halo.match(/stroke-width:(\d+)/)[1])>Number(outline.match(/stroke-width:(\d+)/)[1]));
 assert.ok(halo.includes('stroke:var(--it-mark-bg,var(--it-surface))'));
 assert.ok(!halo.includes('opacity'));
});

test('all stacked idents receive a narrow opaque separation halo',()=>{
 const {scene,select}=mount();
 for(const key of ['near','behind','catchup','start','you','team']){
  select.value=key;select.change();
  const stacks=[...scene.innerHTML.matchAll(/<span class="it-stack">([\s\S]*?)<\/span><\/div>/g)];
  for(const stack of stacks){
   assert.equal((stack[1].match(/class="it-halo"/g)||[]).length,(stack[1].match(/class="it-mark /g)||[]).length);
  }
 }
 const halo=html.match(/\.it-stack \.it-halo\{([^}]+)\}/)[1];
 assert.ok(halo.includes('stroke:var(--it-mark-bg,var(--it-surface))'));
 const width=Number(halo.match(/stroke-width:(\d+)/)[1]);
 assert.ok(width>25 && width<60, 'A modest gap beyond the colored outline');
});

test('missed flashes sit visually behind completed and planned flashes',()=>{
 const {scene,select}=mount();let mixed=0;
 for(const key of ['near','behind','catchup','start','you','team']){
  select.value=key;select.change();
  const stacks=[...scene.innerHTML.matchAll(/<span class="it-stack">([\s\S]*?)<\/span><\/div>/g)];
  for(const stack of stacks){
   const marks=[...stack[1].matchAll(/class="it-mark it-(done|planned|missed)" style="[^"]*z-index:(\d+)"/g)];
   const missed=marks.filter(m=>m[1]==='missed');
   const others=marks.filter(m=>m[1]!=='missed');
   if(missed.length&&others.length)mixed++;
   for(const back of missed){
    assert.equal(Number(back[2]),0);
    for(const front of others)assert.ok(Number(front[2])>Number(back[2]));
   }
  }
 }
 assert.ok(mixed>0);
});

test('outline and filled flashes have the same visible halo width in the stack',()=>{
 const filledHalo=Number(html.match(/\.it-stack \.it-halo\{[^}]*stroke-width:(\d+)/)[1]);
 const outline=Number(html.match(/\.it-planned use\{[^}]*stroke-width:(\d+)/)[1]);
 const outlineHalo=Number(html.match(/\.it-stack \.it-planned \.it-halo\{stroke-width:(\d+)/)[1]);
 assert.ok(html.includes('.it-done use{fill:currentColor;stroke:none}'));
 assert.equal((outlineHalo-outline)/2,filledHalo/2);
});

test('top-left flashes sit in front and missed idents sit at the bottom-right back',()=>{
 const {scene,select}=mount();let mixed=0;
 for(const key of ['near','behind','catchup','start','you','team']){
  select.value=key;select.change();
  const stacks=[...scene.innerHTML.matchAll(/<span class="it-stack">([\s\S]*?)<\/span><\/div>/g)];
  for(const stack of stacks){
   const marks=[...stack[1].matchAll(/class="it-mark it-(done|planned|missed)" style="[^"]*--dx:([-\d]+)px;--dy:(\d+)px;z-index:(\d+)/g)];
   for(let i=1;i<marks.length;i++){
    assert.ok(Number(marks[i][2])>Number(marks[i-1][2]));
    assert.ok(Number(marks[i][3])>Number(marks[i-1][3]));
    assert.ok(Number(marks[i][4])<=Number(marks[i-1][4]));
   }
   const missed=marks.filter(m=>m[1]==='missed');
   const others=marks.filter(m=>m[1]!=='missed');
   if(missed.length&&others.length){
    mixed++;
    for(const back of missed)for(const front of others){
     assert.ok(Number(back[2])>Number(front[2]));
     assert.ok(Number(back[3])>Number(front[3]));
     assert.ok(Number(back[4])<Number(front[4]));
    }
   }
  }
 }
 assert.ok(mixed>0);
});

test('each flash retains its identity, status and color between Combined and Detailed',()=>{
 const app=mount();
 function marks(){return new Map([...app.scene.innerHTML.matchAll(/class="it-mark (it-[^"]+)" style="--user:([^;]+);[^"]*"[^>]*data-ident="([^"]+)"/g)].map(m=>[m[3],m[1]+'|'+m[2]]));}
 for(const key of ['near','behind','catchup','start','you','team']){
  app.switchMode('combined');app.select.value=key;app.select.change();
  const combined=marks();assert.ok(combined.size>0);
  app.switchMode('detailed');
  assert.deepEqual(marks(),combined);
  assert.ok(app.scene.innerHTML.includes('data-mode="detailed" aria-pressed="true"'));
  app.switchMode('combined');
  assert.deepEqual(marks(),combined);
 }
});

test('switching in both directions animates every flash from its previous position and size',()=>{
 const app=mount();
 const count=(app.scene.innerHTML.match(/data-ident=/g)||[]).length;
 app.switchMode('detailed');
 let moving=app.animations.filter(a=>a.kind==='ident');
 assert.equal(moving.length,count);
 assert.equal(new Set(moving.map(a=>a.dataset.ident)).size,count);
 assert.ok(moving.every(a=>a.frames[0].transform.includes('translate(')&&a.frames[0].transform.includes('scale(1,1)')));
 assert.ok(moving.some(a=>!a.frames[0].transform.startsWith('translate(0px,0px)')));
 assert.ok(moving.every(a=>a.frames[1].transform==='none'));
 const fills=app.animations.filter(a=>a.kind==='fill');
 assert.equal(fills.length,3);
 assert.ok(fills.every(a=>a.frames[0].clipPath.startsWith('polygon(0% 100.000%')&&a.frames[1].clipPath!==a.frames[0].clipPath));
 assert.ok(app.animations.some(a=>a.kind==='week'));
 app.animations.length=0;app.switchMode('combined');
 moving=app.animations.filter(a=>a.kind==='ident');
 assert.equal(moving.length,count);
 assert.ok(moving.every(a=>a.frames[0].transform.includes('scale(1,1)')));
 assert.equal(app.focusedMode,'combined');
});

test('legend stays behind the adjacent info button and supports opening, closing and Escape',()=>{
 const app=mount();
 assert.ok(app.scene.innerHTML.includes('<h3>Diese Woche</h3><button type="button" class="it-info-button"'));
 assert.ok(app.scene.innerHTML.includes('id="it-ident-info-demo" class="it-info-panel" hidden'));
 app.toggleInfo();assert.equal(app.info.hidden,false);assert.equal(app.infoButton.attributes['aria-expanded'],'true');
 app.switchMode('detailed');assert.ok(app.scene.innerHTML.includes('id="it-ident-info-demo" class="it-info-panel"><div class="it-legend">'));
 app.key('Escape');assert.equal(app.info.hidden,true);assert.equal(app.infoButton.attributes['aria-expanded'],'false');
 app.toggleInfo();app.toggleInfo();assert.equal(app.info.hidden,true);
});

test('reduced motion skips movement while keyboard navigation still changes the view',()=>{
 const app=mount({reducedMotion:true});
 app.switchMode('detailed');assert.ok(app.scene.innerHTML.includes('data-view="detailed"'));
 assert.equal(app.animations.length,0);
 app.switchMode('combined');assert.ok(app.scene.innerHTML.includes('data-view="combined"'));
 app.switchMode('detailed');assert.ok(app.scene.innerHTML.includes('data-view="detailed"'));
 assert.equal(app.animations.length,0);
});

test('changing scenarios during a transition clears temporary animation styles',async()=>{
 const app=mount();app.switchMode('detailed');
 assert.ok(app.scene.classList.contains('it-is-morphing'));
 app.select.value='behind';app.select.change();
 assert.ok(!app.scene.classList.contains('it-is-morphing'));
 app.switchMode('combined');app.switchMode('detailed');
 await new Promise(resolve=>setImmediate(resolve));
 assert.ok(!app.scene.classList.contains('it-is-morphing'));
});

test('Smart and Detailed picker sits under the heading with week expansion only in Smart',()=>{
 const app=mount();
 for(const mode of ['combined','detailed']){
  app.switchMode(mode);
  const out=app.scene.innerHTML;
  assert.ok(!out.includes('data-week-toggle'));
  assert.equal(out.includes('data-expand-week'),mode==='combined');
  assert.ok(out.includes('>Smart</button>')&&out.includes('>Detailed</button>'));
  assert.ok(out.includes(`data-mode="${mode}" aria-pressed="true"`));
  assert.ok(out.indexOf('<h3>Diese Woche</h3>')<out.indexOf('class="it-view-picker"'));
  assert.ok(out.indexOf('class="it-view-picker"')<out.indexOf('class="it-week-content"'));
 }
});test('darkened yellow streak flame is embedded and works without an icon loader',()=>{
 const style=html.match(/#ignite-team-demo \.it-streak-art\{([^}]+)\}/)[1];
 assert.ok(style.includes('background:hsl(from var(--it-yellow) h s calc(l * .46))'));
 assert.ok(style.includes('opacity:1'));
 assert.ok(style.includes('-webkit-mask:'));
 assert.ok(!html.includes('data-lucide="flame"'));
 const encoded=style.match(/data:image\/svg\+xml;base64,([^"]+)/)[1];
 const svg=Buffer.from(encoded,'base64').toString('utf8');
 assert.ok(svg.includes('lucide-flame'));
 assert.ok(svg.includes('<path d="'));
 assert.ok(svg.includes('fill="#000000"'));
 assert.match(html,/--it-yellow:#ffd166/);
 const app=mount();
 for(const mode of ['combined','detailed','combined']){
  app.switchMode(mode);
  assert.ok(app.scene.innerHTML.includes('<span class="it-streak-art" aria-hidden="true"></span>'));
  assert.ok(app.scene.innerHTML.includes('<strong aria-hidden="true">4</strong>'));
 }
 app.select.value='behind';app.select.change();
 assert.ok(app.scene.innerHTML.includes('class="it-streak-art"'));
});
test('current-day column morphs with the flashes in both directions and remains rounded',()=>{
 const app=mount();
 for(const mode of ['detailed','combined']){
  app.animations.length=0;app.switchMode(mode);
  const highlights=app.animations.filter(a=>a.kind==='today');
  assert.equal(highlights.length,1);
  assert.ok(highlights[0].frames[0].transform.includes('translate('));
  assert.ok(highlights[0].frames[0].transform.includes('scale('));
  assert.equal(highlights[0].frames[1].borderRadius,'14px');
  assert.equal(highlights[0].options.duration,app.animations.find(a=>a.kind==='ident').options.duration);
 }
 const reduced=mount({reducedMotion:true});reduced.switchMode('detailed');
 assert.equal(reduced.animations.filter(a=>a.kind==='today').length,0);
 assert.match(html,/\.it-today-highlight\{[^}]*border-radius:14px/);
});

test('Combined shows flashes without daily count captions',()=>{
 const app=mount();
 for(const scenario of ['near','behind','catchup','start','you','team']){
  app.select.value=scenario;app.select.change();
  assert.equal((app.scene.innerHTML.match(/class="it-stack"/g)||[]).length,7);
  assert.ok(!app.scene.innerHTML.includes('it-daycount'));
  assert.ok(!/\d+ Idents?</.test(app.scene.innerHTML));
 }
});

test('all seven weekday labels animate between their actual positions in both views',()=>{
 const app=mount();
 for(const mode of ['detailed','combined']){
  app.animations.length=0;app.switchMode(mode);
  const days=app.animations.filter(a=>a.kind==='weekday');
  assert.equal(days.length,7);
  assert.equal(new Set(days.map(a=>a.dataset.weekday)).size,7);
  assert.ok(days.every(a=>a.frames[0].transform.startsWith('translate(')&&a.frames[1].transform==='none'));
  assert.ok(days.some(a=>a.frames[0].transform!=='translate(0px,0px)'));
  assert.ok(days.every(a=>a.options.duration===app.animations.find(a=>a.kind==='ident').options.duration));
 }
 const reduced=mount({reducedMotion:true});reduced.switchMode('detailed');
 assert.equal(reduced.animations.filter(a=>a.kind==='weekday').length,0);
});

test('avatars and summary flashes enter and exit from opposite sides with row staggering',()=>{
 const app=mount();app.switchMode('detailed');
 const entering=app.animations.filter(a=>a.kind==='side');
 assert.equal(entering.length,6);
 for(const a of entering){
  assert.equal(a.options.delay,Number(a.dataset.row)*75);
  assert.equal(a.frames[0].transform,a.dataset.side==='left'?'translateX(-96px)':'translateX(112px)');
  assert.equal(a.frames[1].opacity,1);
 }
 app.animations.length=0;app.switchMode('combined');
 const exiting=app.animations.filter(a=>a.kind==='exit-side');
 assert.equal(exiting.length,6);
 for(const a of exiting){
  assert.equal(a.options.delay,(2-Number(a.dataset.row))*75);
  assert.equal(a.frames[1].transform,a.dataset.side==='left'?'translateX(-96px)':'translateX(112px)');
  assert.equal(a.frames[1].opacity,0);
 }
 const reduced=mount({reducedMotion:true});reduced.switchMode('detailed');reduced.switchMode('combined');
 assert.equal(reduced.animations.length,0);
});

test('empty-day dash is centered inside the full stack height',()=>{
 const style=html.match(/\.it-empty\{([^}]+)\}/)[1];
 for(const rule of ['position:absolute','inset:0','display:flex','align-items:center','justify-content:center'])assert.ok(style.includes(rule));
 const app=mount();app.select.value='near';app.select.change();
 assert.ok(app.scene.innerHTML.includes('<span class="it-stack"><span class="it-empty">–</span></span>'));
});

test('total flash retains native symbol dimensions and is centered in an unpadded column',()=>{
 const app=mount();app.switchMode('detailed');
 const progress=[...app.scene.innerHTML.matchAll(/<div class="it-progress-flash">([\s\S]*?)<strong/g)];
 assert.equal(progress.length,3);
 for(const [,content] of progress){
  assert.equal((content.match(/viewBox="92 28 328 456"/g)||[]).length,4);
  assert.equal((content.match(/<use href="#it-brand-flash" width="512" height="512"\/>/g)||[]).length,4);
 }
 assert.ok(html.includes('.it-progress-column{width:84px;padding:0;text-align:center}'));
 assert.ok(html.includes('.it-progress-column{width:70px;padding:0}'));
});

test('individual flashes use identical responsive dimensions in Combined and Detailed',()=>{
 const combined=html.match(/\.it-stack \.it-mark\{([^}]+)\}/)[1];
 const detailed=html.match(/\.it-grid \.it-mark\{([^}]+)\}/)[1];
 for(const dimension of ['width','height']){
  const rule=new RegExp('(?:^|;)'+dimension+':([^;]+)');
  assert.equal(detailed.match(rule)[1],combined.match(rule)[1]);
 }
});

test('Combined has a team progress bar beside the names instead of a total flash',()=>{
 const app=mount();
 for(const [scenario,done] of Object.entries({near:8,behind:3,catchup:6,start:0,you:4,team:6})){
  app.select.value=scenario;app.select.change();
  const out=app.scene.innerHTML;
  const target=scenario==='behind'?10:9;
  assert.equal((out.match(/data-team-total/g)||[]).length,1);
  assert.ok(out.includes(`aria-label="Team: Wochenziel" aria-valuenow="${done}" aria-valuemin="0" aria-valuemax="${target}" data-team-total`));
  assert.ok(out.includes(`<strong>${done}/${target}</strong>`));
  assert.ok(out.includes(`<div class="it-team-track"><span style="width:${Math.min(done/target,1)*100}%">`));
  assert.ok(!out.slice(out.indexOf('<section class="it-week-section"')).includes('it-progress-flash'));
  assert.ok(out.indexOf('class="it-week-footer"')<out.indexOf('class="it-personkey"'));
  assert.ok(out.indexOf('class="it-personkey"')<out.indexOf('class="it-team-progress"'));
 }
 assert.match(html,/\.it-week-footer\{[^}]*display:flex;align-items:center/);
 assert.match(html,/\.it-personkey\{[^}]*flex-wrap:nowrap/);
 app.switchMode('detailed');
 assert.ok(!app.scene.innerHTML.includes('data-team-total'));
 assert.equal((app.scene.innerHTML.match(/data-progress-user=/g)||[]).length,3);
});

test('team progress bar uses translucent black and larger horizontal margins',()=>{
 assert.match(html,/\.it-team-progress\{[^}]*margin-inline:clamp\(12px,4vw,24px\)/);
 assert.ok(!html.match(/\.it-team-track\{[^}]*margin-inline/));
 assert.match(html,/\.it-team-track span\{[^}]*background:rgb\(0 0 0 \/ 45%\)/);
});

test('returning to Combined fills the team bar from zero to the actual progress',()=>{
 const app=mount();
 assert.equal(app.animations.filter(a=>a.kind==='team-bar').length,0);
 for(const [scenario,done] of Object.entries({near:8,behind:3,catchup:6,start:0,you:4,team:6})){
  app.select.value=scenario;app.select.change();
  app.animations.length=0;app.switchMode('detailed');
  assert.equal(app.animations.filter(a=>a.kind==='team-bar').length,0);
  app.switchMode('combined');
  const bars=app.animations.filter(a=>a.kind==='team-bar');
  assert.equal(bars.length,1);
  assert.equal(bars[0].frames[0].width,'0%');
  assert.equal(bars[0].frames[1].width,`${done/(scenario==='behind'?10:9)*100}%`);
  assert.equal(bars[0].options.fill,'backwards');
  assert.equal(bars[0].options.delay,120);
 }
 const reduced=mount({reducedMotion:true});reduced.switchMode('detailed');reduced.switchMode('combined');
 assert.equal(reduced.animations.length,0);
});

test('bold motivational boxes show a large subdued brand flash behind their text',()=>{
 const app=mount();
 for(const scenario of ['near','behind']){
  app.select.value=scenario;app.select.change();
  assert.equal((app.scene.innerHTML.match(/class="it-hero-brand"/g)||[]).length,1);
  assert.ok(app.scene.innerHTML.includes('class="it-hero-brand" viewBox="0 0 512 512" aria-hidden="true" focusable="false"'));
 }
 for(const scenario of ['you','team']){
  app.select.value=scenario;app.select.change();
  assert.ok(!app.scene.innerHTML.includes('it-hero-brand'));
 }
 const style=html.match(/\.it-hero-brand\{([^}]+)\}/)[1];
 for(const rule of ['position:absolute','z-index:-1','width:380px','opacity:.09','pointer-events:none','mask-image:linear-gradient'])assert.ok(style.includes(rule));
});

test('progress digits invert exactly at the flash fill boundary, including during animation',()=>{
 const app=mount();app.switchMode('detailed');
 const rows=[...app.scene.innerHTML.matchAll(/<tr class="it-personrow">([\s\S]*?)<\/tr>/g)];
 for(const [,row] of rows){
  const front=surface(row,'it-progress-fill');
  const back=surface(row,'it-progress-wave-back');
  const base=surface(row,'it-number-base');
  const inverse=surface(row,'it-number-inverse');
  assert.deepEqual(base,inverse);
  inverse.forEach((y,i)=>assert.ok(Math.abs(y-Math.min(front[i],back[i]))<.002));
 }
 const fills=app.animations.filter(a=>a.kind==='fill');
 const inverse=app.animations.filter(a=>a.kind==='it-number-inverse');
 assert.equal(inverse.length,3);
 inverse.forEach((a,i)=>{assert.deepEqual(a.frames[0],fills[i].frames[0]);assert.deepEqual(a.options,fills[i].options);});
 assert.equal(app.animations.filter(a=>a.kind==='it-number-base').length,3);
 assert.match(html,/\.it-progress-number\{[^}]*color:var\(--user\)/);
 assert.match(html,/\.it-number-inverse \.it-progress-number\{color:color-mix\(in srgb,var\(--user\) 16%,var\(--it-surface\)\)/);
});

test('Detailed ident clicks announce the detail view without changing the week mode',()=>{
 const app=mount();app.clickIdent();assert.equal(app.hint.hidden,true);
 app.switchMode('detailed');
 const out=app.scene.innerHTML;
 assert.equal((out.match(/data-open-ident=/g)||[]).length,(out.match(/data-ident=/g)||[]).length);
 assert.ok(out.includes('id="it-detail-hint-demo" role="status" hidden'));
 app.clickIdent();
 assert.equal(app.hint.hidden,false);
 assert.equal(app.hint.textContent,'Hier würde sich IdentDetailView öffnen.');
 assert.ok(app.scene.innerHTML.includes('data-view="detailed"'));
 app.switchMode('combined');assert.ok(!app.scene.innerHTML.includes('data-open-ident='));
});

test('behind scenario gives Nico zero of three and Lena two of four',()=>{
 const app=mount();app.select.value='behind';app.select.change();
 assert.ok(app.scene.innerHTML.includes('<strong>3/10</strong>'));
 assert.ok(app.scene.innerHTML.includes('it-hero it-behind'));
 app.switchMode('detailed');
 const rows=[...app.scene.innerHTML.matchAll(/<tr class="it-personrow">([\s\S]*?)<\/tr>/g)].map(m=>m[1]);
 assert.equal((rows[0].match(/it-mark it-done/g)||[]).length,0);
 assert.ok(rows[0].includes('<strong class="it-progress-number">0<span>/3</span></strong>'));
 assert.equal((rows[1].match(/it-mark it-done/g)||[]).length,2);
 assert.ok(rows[1].includes('<strong class="it-progress-number">2<span>/4</span></strong>'));
 assertWaterLevel(rows[1],2,4);
});

test('Smart week click animates into Detailed while Detailed background click leaves it open',()=>{
 const app=mount();
 assert.ok(app.scene.innerHTML.includes('class="it-week-expand" data-expand-week'));
 app.clickWeek();
 assert.ok(app.scene.innerHTML.includes('data-view="detailed"'));
 assert.ok(app.animations.some(a=>a.kind==='ident'));
 assert.equal(app.hint.hidden,true);
 assert.ok(!app.scene.innerHTML.includes('data-expand-week'));
 app.clickWeek();
 assert.ok(app.scene.innerHTML.includes('data-view="detailed"'));
 assert.equal(app.hint.hidden,true);
 app.clickIdent();assert.equal(app.hint.hidden,false);
 assert.equal(app.hint.textContent,'Hier würde sich IdentDetailView öffnen.');
 app.switchMode('combined');
 assert.ok(app.scene.innerHTML.includes('data-expand-week'));
});

test('two distinct sine waves fill the flash and animate together without spilling at empty or full',()=>{
 const app=mount();app.select.value='behind';app.select.change();app.switchMode('detailed');
 const rows=[...app.scene.innerHTML.matchAll(/<tr class="it-personrow">([\s\S]*?)<\/tr>/g)];
 const front=surface(rows[1][1],'it-progress-fill');
 const back=surface(rows[1][1],'it-progress-wave-back');
 assert.notDeepEqual(front,back);
 assert.ok(Math.max(...back)-Math.min(...back)>8);
 assert.ok(surface(rows[0][1],'it-progress-wave-back').every(y=>y===100));
 assert.equal(app.animations.filter(a=>a.kind==='back-wave').length,3);
 app.switchMode('combined');app.select.value='near';app.select.change();app.switchMode('detailed');
 const fullRows=[...app.scene.innerHTML.matchAll(/<tr class="it-personrow">([\s\S]*?)<\/tr>/g)];
 assert.ok(surface(fullRows[1][1],'it-progress-wave-back').every(y=>y===0));
 assert.match(html,/\.it-progress-wave-back\{opacity:\.25/);
});

test('week title, info and date form an external iOS-style section header above the rounded content',()=>{
 const app=mount();
 for(const mode of ['combined','detailed']){
  app.switchMode(mode);
  const out=app.scene.innerHTML;
  const section=out.indexOf('<section class="it-week-section"');
  const header=out.indexOf('<header class="it-weekhead">',section);
  const headerEnd=out.indexOf('</header>',header);
  const card=out.indexOf('<div class="it-week">',headerEnd);
  assert.ok(section>=0&&header>section&&card>headerEnd);
  const content=out.slice(header,headerEnd);
  assert.ok(content.includes('<h3>Diese Woche</h3>'));
  assert.ok(content.includes('data-info'));
  assert.ok(content.includes('class="it-dates"'));
  assert.ok(out.indexOf('class="it-view-picker"',card)>card);
 }
 assert.match(html,/\.it-weekhead h3\{font-size:16px/);
});

test('week arrows change dates, summaries and rows while retaining the selected view',()=>{
 const app=mount({scenario:''});app.switchMode('detailed');app.animations.length=0;
 app.stepWeek(-1);
 assert.ok(app.scene.innerHTML.includes('<h3>Letzte Woche</h3>'));
 assert.ok(app.scene.innerHTML.includes('value="2026-10-05"'));
 assert.ok(app.scene.innerHTML.includes('Euer Wochenabschluss'));
 assert.ok(app.scene.innerHTML.includes('data-current-week'));
 assert.ok(app.scene.innerHTML.includes('data-view="detailed"'));
 assert.ok(!app.scene.innerHTML.includes('it-daycell it-today'));
 assert.ok(app.animations.some(a=>a.kind==='content'));
 assert.ok(app.animations.some(a=>a.kind==='exit-content'));
 app.today();
 assert.ok(app.scene.innerHTML.includes('<h3>Diese Woche</h3>'));
 assert.ok(app.scene.innerHTML.includes('value="2026-10-12"'));
 assert.ok(app.scene.innerHTML.includes('it-daycell it-today'));
 assert.ok(!app.scene.innerHTML.includes('data-current-week'));
 app.stepWeek(1);
 assert.ok(app.scene.innerHTML.includes('<h3>Nächste Woche</h3>'));
 assert.ok(app.scene.innerHTML.includes('value="2026-10-19"'));
 assert.ok(!app.scene.innerHTML.match(/<tbody>([\s\S]*?)<\/tbody>/)[1].includes('it-mark it-done'));
 assert.ok(app.scene.innerHTML.includes('it-mark it-planned'));
});

test('date picker normalizes arbitrary dates to Monday across month, year and daylight-saving boundaries',()=>{
 const app=mount();
 for(const [date,monday] of [['2026-11-01','2026-10-26'],['2027-01-01','2026-12-28'],['2027-03-28','2027-03-22'],['2026-10-18','2026-10-12']]){
  app.date(date);
  assert.ok(app.scene.innerHTML.includes(`value="${monday}"`));
 }
 app.date('invalid');assert.ok(app.scene.innerHTML.includes('value="2026-10-12"'));
});

test('horizontal swipes navigate weeks and suppress the following tap; vertical gestures keep Smart unchanged',()=>{
 const app=mount();app.swipe(-90);
 assert.ok(app.scene.innerHTML.includes('value="2026-10-19"'));
 app.clickWeek();assert.ok(app.scene.innerHTML.includes('data-view="combined"'));
 app.clickWeek();assert.ok(app.scene.innerHTML.includes('data-view="detailed"'));
 app.swipe(90);assert.ok(app.scene.innerHTML.includes('value="2026-10-12"'));
 app.clickIdent();assert.equal(app.hint.hidden,true);
 app.swipe(10,90);app.switchMode('combined');
 assert.ok(app.scene.innerHTML.includes('value="2026-10-12"'));
});

test('week navigation respects reduced motion and leaves current scenario data intact on return',()=>{
 const app=mount({reducedMotion:true});app.select.value='behind';app.select.change();
 app.stepWeek(-1);app.today();
 assert.equal(app.animations.length,0);
 assert.ok(app.scene.innerHTML.includes('<strong>3/10</strong>'));
 app.switchMode('detailed');
 assert.ok(app.scene.innerHTML.includes('<strong class="it-progress-number">2<span>/4</span></strong>'));
});

test('week navigation uses a compact height',()=>{
 assert.match(html,/\.it-week-nav button\{[^}]*min-height:32px/);
 assert.match(html,/\.it-date-picker summary\{[^}]*padding:8px 4px/);
});

test('dark background cut runs from top left to bottom right with a downward offset',()=>{
 const style=html.match(/\.it-phone::before\{([^}]+)\}/)[1];
 assert.ok(style.includes('inset:0 0 auto'));
 assert.ok(style.includes('height:100px;padding-bottom:100%'));
 assert.ok(style.includes('background:#24201d'));
 assert.ok(style.includes('clip-path:polygon(0 0,100% 0,100% 100%,0 100px)'));
 assert.ok(style.includes('z-index:-1'));
 assert.match(html,/\.it-streak-art\{[^}]*background:hsl\(from var\(--it-yellow\) h s calc\(l \* \.46\)\)/);
 assert.ok(!script.includes('--it-diagonal-top'));
 const app=mount();app.switchMode('detailed');app.stepWeek(-1);
 assert.ok(app.scene.innerHTML.includes('class="it-phone"'));
});
test('streak uses two differently shaded yellow flames layered behind the number',()=>{
 const app=mount();
 const streak=app.scene.innerHTML.match(/<div class="it-streak"[\s\S]*?<\/div>/)[0];
 assert.ok(streak.includes('class="it-streak-art"'));
 assert.ok(streak.includes('class="it-streak-art it-streak-art-front"'));
 assert.ok(streak.indexOf('it-streak-art-front')<streak.indexOf('<strong'));
 assert.match(html,/\.it-streak-art-front\{background:hsl\(from var\(--it-yellow\) h s calc\(l \* \.64\)\);transform:translate\(3px,9px\) scale\(\.72\)/);
});

test('streak number is centered in the shifted inner flame bowl',()=>{
 assert.match(html,/\.it-streak strong\{[^}]*left:54\.2%;top:79%;transform:translate\(-50%,-50%\)/);
});

test('four reward screens are selectable beside the situation and preserve all week interactions',()=>{
 const app=mount();
 assert.ok(html.includes('class="it-design-controls"'));
 assert.ok(html.includes('label for="it-streak-design"'));
 for(const design of ['trophy','level','chain','medal','classic']){
  app.design.value=design;app.design.change();
  assert.ok(app.scene.innerHTML.includes(`data-reward-design="${design}"`));
  assert.equal((app.scene.innerHTML.match(/aria-label="4 Wochen Streak"/g)||[]).length,design==='classic'?1:2);
  assert.equal(app.scene.innerHTML.includes('aria-label="Streak-Belohnung"'),design!=='classic');
  for(const scenario of ['near','behind','catchup','start','you','team']){
   app.select.value=scenario;app.select.change();
   assert.ok(app.scene.innerHTML.includes('class="it-week-section"'));
   app.switchMode('detailed');app.clickIdent();assert.equal(app.hint.hidden,false);
   app.stepWeek(-1);app.today();
   assert.ok(app.scene.innerHTML.includes('data-view="detailed"'));
   app.switchMode('combined');
  }
 }
 assert.match(html,/\.it-phone::before\{display:none/);
 assert.match(html,/\.it-phone\[data-streak-design="classic"\]::before\{display:block/);
});

test('Dark Cut keeps the streak at top right with a blurred yellow glow and trophy colors',()=>{
 const app=mount();
 assert.ok(app.scene.innerHTML.includes('data-streak-design="classic"'));
 const header=app.scene.innerHTML.match(/<header class="it-teamtop">([\s\S]*?)<\/header>/)[1];
 assert.ok(header.includes('aria-label="4 Wochen Streak"'));
 assert.ok(!app.scene.innerHTML.includes('aria-label="Streak-Belohnung"'));
 assert.match(html,/\.it-phone\[data-streak-design="classic"\]::after\{[^}]*right:-50px[^}]*var\(--it-yellow\)[^}]*filter:blur\(28px\)/);
 assert.match(html,/\.it-phone\[data-streak-design="classic"\] \.it-teamtop\{color:#fff3e5/);
 assert.ok(!html.includes('<option value="classic">'));
});

test('all comparison weeks include a streak info page with an appropriate zero state',()=>{
 const screens=[...html.matchAll(/data-screen data-screen-id="week(\d)" data-streak="(\d)" data-week-offset="(-?\d)"/g)];
 assert.equal(screens.length,7);
 screens.slice(0,6).forEach((m,i)=>{assert.equal(Number(m[2]),i);assert.equal(Number(m[3]),i-3);});
 for(let count=0;count<4;count++){
  const app=mount({streak:count,initialWeek:count-3});
  for(const design of ['trophy','level','chain','medal']){
   app.design.value=design;app.design.change();
   const out=app.scene.innerHTML;
   assert.ok(out.includes('data-streak-design="classic"'));
   assert.ok(out.includes(`data-reward-design="${design}" data-streak-count="${count}"`));
   assert.equal((out.match(/class="it-hero-slide"/g)||[]).length,2);
   assert.equal(out.includes('aria-label="Streak-Belohnung"'),true);
   assert.equal(out.includes('data-hero-slide="1"'),true);
   if(count){
    assert.ok(out.includes(`aria-label="${count} ${count===1?'Woche':'Wochen'} Streak"`));
    const header=out.match(/<header class="it-teamtop">([\s\S]*?)<\/header>/)[1];
    assert.ok(header.includes('class="it-streak"'));
   }else assert.ok(!out.includes('class="it-streak"'));
  }
 }
 assert.ok(!html.includes('<option value="classic">'));
});

test('reward carousel supports paging and native swipe position without altering weekly view',()=>{
 const app=mount({streak:2});app.design.value='trophy';app.design.change();
 app.heroSlide(1);assert.equal(app.heroTrack.scrollLeft,400);
 app.switchMode('detailed');assert.equal(app.heroTrack.scrollLeft,400);
 assert.ok(app.scene.innerHTML.includes('data-view="detailed"'));
 app.heroTrack.scrollLeft=0;app.heroTrack.onscroll();
 app.switchMode('combined');assert.equal(app.heroTrack.scrollLeft,0);
 assert.match(html,/\.it-hero-track\{[^}]*scroll-snap-type:x mandatory/);
 assert.match(html,/\.it-hero-slide\{[^}]*scroll-snap-align:start/);
});

test('streak tiers graduate from blue snowflake to a single flame, small cut and full glowing cut',()=>{
 for(let count=0;count<=3;count++){
  const app=mount({streak:count});
  const header=app.scene.innerHTML.match(/<header class="it-teamtop">([\s\S]*?)<\/header>/)[1];
  if(count===0){
   assert.ok(header.includes('class="it-frozen"'));
   assert.ok(header.includes('aria-label="Keine Streak"'));
   assert.ok(!header.includes('class="it-streak"'));
  }else{
   assert.ok(header.includes('class="it-streak-art"'));
   assert.equal(header.includes('it-streak-art-front'),count>=2);
  }
 }
 assert.match(html,/\.it-frozen\{[^}]*background:light-dark\(#338bd1,#74c7ff\)/);
 assert.match(html,/data-streak-count="0"\]::before,[^{]*data-streak-count="1"\]::before\{display:none/);
 assert.match(html,/data-streak-count="2"\]::before\{height:0;padding-bottom:65%;clip-path:polygon\(35% 0,100% 0,100% 100%\)/);
 assert.match(html,/data-streak-count="0"\]::after,[^{]*data-streak-count="1"\]::after,[^{]*data-streak-count="2"\]::after\{display:none/);
});

test('comparison screens stretch to equal row height while info cards keep their natural height',()=>{
 assert.match(html,/\.it-screen-comparison\{[^}]*align-items:stretch/);
 assert.match(html,/\[data-screen\]\{[^}]*display:flex;flex-direction:column/);
 assert.match(html,/\[data-screen\]>\.it-preview\{[^}]*flex:1/);
 assert.match(html,/\[data-screen\]>\.it-preview>\.it-scene\{[^}]*flex:1/);
 assert.match(html,/\[data-screen\] \.it-phone\{flex:1/);
});

test('zero streak has a strongly blurred blue glow behind its snowflake',()=>{
 const style=[...html.matchAll(/\.it-phone\[data-streak-count="0"\]::after\{([^}]+)\}/g)].at(-1)[1];
 assert.ok(style.includes('display:block'));
 assert.ok(style.includes('light-dark(#338bd180,#74c7ff70)'));
 assert.ok(style.includes('filter:blur(56px)'));
 assert.ok(style.includes('z-index:-1'));
 const app=mount({streak:0});
 assert.ok(app.scene.innerHTML.includes('class="it-frozen"'));
});

test('single flame has yellow glow and both dark cuts round their screen-edge intersections',()=>{
 assert.match(html,/data-streak-count="1"\]::after\{display:block/);
 for(const count of [2,3]){
  const app=mount({streak:count});
  const path=app.pageStyle['--it-cut-path'];
  assert.ok(path.startsWith('path("M'));
  assert.equal((path.match(/C/g)||[]).length,2);
  assert.ok(!/NaN|Infinity/.test(path));
  if(count===2){
   assert.ok(path.includes('M116 0'));
   assert.ok(path.includes('V364'));
  }else{
   assert.ok(path.includes('L52 152'));
   assert.ok(path.includes('V632'));
  }
 }
 assert.ok(html.includes('clip-path:var(--it-cut-path,'));
});

test('dark cuts use a pronounced 52px corner rounding',()=>{
 const app=mount({streak:3});
 assert.ok(app.pageStyle['--it-cut-path'].includes('L52 152 C26 126 0 178 0 152'));
 assert.ok(app.pageStyle['--it-cut-path'].includes('V632 C480 606 454 554 428 528'));
});

test('weeks five and six extend the row with deeper cut, wider glow and full dark canvas',()=>{
 assert.ok(html.includes('data-screen-id="week4" data-streak="4" data-week-offset="1"'));
 assert.ok(html.includes('data-screen-id="week5" data-streak="5" data-week-offset="2"'));
 const fifth=mount({streak:4,initialWeek:1});
 assert.ok(fifth.pageStyle['--it-cut-path'].includes('L52 592'));
 assert.ok(fifth.pageStyle['--it-cut-path'].includes('V1072'));
 const sixth=mount({streak:5,initialWeek:2});
 assert.ok(sixth.scene.innerHTML.includes('data-streak-count="5"'));
 assert.match(html,/data-streak-count="4"\]::after\{[^}]*width:400px;height:400px;filter:blur\(48px\)/);
 assert.match(html,/data-streak-count="5"\]\{background:#24201d/);
 assert.match(html,/data-streak-count="5"\]::before\{display:none/);
 assert.match(html,/\.it-screen-comparison\{[^}]*grid-template-columns:repeat\(auto-fit,minmax\(min\(100%,320px\),1fr\)\)/);
 assert.ok(!html.match(/\.it-screen-comparison\{[^}]*overflow-x:auto/));
});

test('week section has translucent glass, backdrop blur and a legible dark-screen palette',()=>{
 const style=html.match(/\.it-week\{([^}]+)\}/)[1];
 assert.ok(style.includes('background:linear-gradient'));
 assert.ok(style.includes('backdrop-filter:blur(24px) saturate(150%)'));
 assert.ok(style.includes('-webkit-backdrop-filter:blur(24px) saturate(150%)'));
 assert.ok(style.includes('border:1px solid'));
 assert.match(html,/data-streak-count="5"\] \.it-week\{[^}]*--it-ink:#fff3e5/);
 assert.match(html,/\.it-week \.it-view-picker\{background:light-dark\(#24201d0a,#ffffff0a\)/);
 const app=mount({streak:5});app.switchMode('detailed');
 assert.equal((app.scene.innerHTML.match(/class="it-personrow"/g)||[]).length,3);
});

test('upper information boxes use tinted translucent glass with backdrop blur',()=>{
 const styles=[...html.matchAll(/\.it-hero\{([^}]+)\}/g)];
 const glass=styles.find(m=>m[1].includes('backdrop-filter'));
 assert.ok(glass);
 assert.ok(glass[1].includes('background:linear-gradient(135deg,#ff682680,#ff682638)'));
 assert.ok(glass[1].includes('-webkit-backdrop-filter:blur(24px) saturate(150%)'));
 assert.match(html,/\.it-hero\.it-behind\{background:linear-gradient\(135deg,#dfff6880,#dfff6838\)/);
 assert.match(html,/\.it-hero\.it-catchup\{background:linear-gradient\(135deg,#c4a5ff80,#c4a5ff38\)/);
});

test('swiped streak reward cards also use glass surfaces',()=>{
 assert.match(html,/\.it-reward\{[^}]*backdrop-filter:blur\(24px\) saturate\(150%\)/);
 assert.match(html,/\.it-reward-trophy\{background:#24201d99/);
});

test('empty situation picker distributes all six scenarios and an override applies to every screen',()=>{
 assert.ok(html.includes('<select id="it-scenario"><option value="">'));
 const keys=['near','behind','catchup','start','you','team'];
 keys.forEach((key,i)=>{
  assert.ok(html.includes(`data-week-offset="${i-3}" data-scenario="${key}"`));
  const app=mount({streak:i,initialWeek:i-3,scenario:'',ownScenario:key});
  if(key==='behind')assert.ok(app.scene.innerHTML.includes('<strong>3/10</strong>'));
  if(key==='start')assert.ok(app.scene.innerHTML.includes('class="it-hero-summaries"'));
  app.select.value='behind';app.select.change();
  assert.ok(app.scene.innerHTML.includes('it-hero it-behind'));
  assert.ok(app.scene.innerHTML.includes('<strong>3/10</strong>'));
  app.select.value='';app.select.change();
  assert.ok(app.scene.innerHTML.includes(`data-streak-count="${i}"`));
 });
});

test('start toggle selects the preferred carousel page without removing swipe navigation',()=>{
 const app=mount({streak:2});app.design.value='trophy';app.design.change();
 assert.equal(app.heroTrack.scrollLeft,0);
 app.start.checked=true;app.start.change();
 assert.equal(app.heroTrack.scrollLeft,400);
 app.heroSlide(0);assert.equal(app.heroTrack.scrollLeft,0);
 app.design.value='chain';app.design.change();assert.equal(app.heroTrack.scrollLeft,400);
 app.start.checked=false;app.start.change();assert.equal(app.heroTrack.scrollLeft,0);
 const zero=mount({streak:0,streakFirst:true});zero.design.value='trophy';zero.design.change();
 assert.equal(zero.heroTrack.scrollLeft,400);
 assert.ok(zero.scene.innerHTML.includes('data-hero-slide="1"'));
 assert.ok(zero.scene.innerHTML.includes('it-reward-zero'));
 assert.match(html,/data-streak-count="1"\]::after\{[^}]*filter:blur\(40px\)/);
});

test('streak four cut extends farther down while retaining a light bottom-left area',()=>{
 const app=mount({streak:4});
 const depth=parseFloat(app.pageStyle['--it-cut-depth']);
 assert.equal(depth,540);
 assert.ok(depth<900);
 assert.ok(depth+480>900);
 assert.ok(app.pageStyle['--it-cut-path'].includes('V1072'));
 assert.ok(html.includes('[data-streak-count="4"]::before{height:var(--it-cut-depth,220px)}'));
});
test('streak one has a stronger yellow glow while retaining its soft blur',()=>{
 assert.match(html,/data-streak-count="1"\]::after\{[^}]*filter:blur\(40px\);background:radial-gradient\(circle,color-mix\(in srgb,var\(--it-yellow\) 65%,transparent\),transparent 70%\)/);
});

test('streak five uses the original compact golden glow',()=>{
 assert.match(html,/data-streak-count="5"\]::after\{[^}]*width:420px;height:420px;filter:blur\(48px\)/);
});

test('streak three through five glows track the exact header flame center',()=>{
 for(const streak of [3,4,5]){
  const app=mount({streak});
  assert.equal(app.pageStyle['--it-glow-x'],'416px');
  assert.equal(app.pageStyle['--it-glow-y'],'66px');
  app.switchMode('detailed');
  assert.equal(app.pageStyle['--it-glow-x'],'416px');
 }
 assert.match(html,/data-streak-count="5"\]::after\{left:var\(--it-glow-x\);top:var\(--it-glow-y\);right:auto;transform:translate\(-50%,-50%\)/);
});

test('dark cut has a hard diagonal edge without rounding or blur',()=>{
 const rules=[...html.matchAll(/\.it-phone\[data-streak-design="classic"\]::before\{([^}]+)\}/g)];
 const final=rules.at(-1)[1];
 assert.ok(final.includes('clip-path:none'));
 assert.ok(final.includes('background:linear-gradient(45deg,transparent var(--it-cut-stop),#24201d var(--it-cut-stop))'));
 for(const streak of [2,3,4]){
  const app=mount({streak});
  assert.ok(Math.abs(parseFloat(app.pageStyle['--it-cut-stop'])-480/Math.SQRT2)<.001);
 }
});

test('light week surfaces suppress the dark cut with readable dark text',()=>{
 const rules=[...html.matchAll(/\.it-phone\[data-streak-count="5"\] \.it-week\{([^}]+)\}/g)];
 const final=rules.at(-1)[1];
 for(const rule of ['--it-ink:#24201d','--it-muted:#665446','background:linear-gradient(135deg,#fff8efa6,#fff3e594)'])assert.ok(final.includes(rule));
 assert.match(html,/\.it-phone \.it-week\{[^}]*backdrop-filter:blur\(28px\) saturate\(115%\)/);
 assert.match(html,/\.it-phone \.it-week \.it-team-track span\{background:#24201d80/);
});

test('information cards switch to dark at streak three and weekly cards at streak four',()=>{
 for(let streak=0;streak<=6;streak++){
  const app=mount({streak});
  assert.ok(app.scene.innerHTML.includes(`data-info-theme="${streak>=4?'dark':'light'}"`));
  assert.ok(app.scene.innerHTML.includes(`data-week-theme="${streak>=4?'dark':'light'}"`));
  app.switchMode('detailed');
  assert.ok(app.scene.innerHTML.includes(`data-week-theme="${streak>=4?'dark':'light'}"`));
 }
 assert.match(html,/data-reward-theme="dark"\] \.it-reward\{color-scheme:dark;--it-ink:#fff3e5/);
 assert.match(html,/data-week-theme="dark"\] \.it-week\{color-scheme:dark;--it-ink:#fff3e5/);
 assert.match(html,/data-week-theme="dark"\] \.it-week\{[^}]*--it-user-0:#ffab79/);
});

test('bold dark-mode info boxes share light-mode glass backgrounds with light text',()=>{
 const latest=pattern=>[...html.matchAll(pattern)].at(-1)[1];
 assert.ok(latest(/data-info-theme="dark"\] \.it-hero:not\(\.it-quiet\)\{([^}]+)\}/g).includes('background:linear-gradient(135deg,#ff682680,#ff682638);color:#fff3e5'));
 assert.equal(latest(/data-info-theme="dark"\] \.it-hero\.it-behind\{([^}]+)\}/g),'background:linear-gradient(135deg,#dfff6880,#dfff6838)');
 assert.equal(latest(/data-info-theme="dark"\] \.it-hero\.it-catchup\{([^}]+)\}/g),'background:linear-gradient(135deg,#c4a5ff80,#c4a5ff38)');
 assert.equal(latest(/data-info-theme="dark"\] \.it-hero:not\(\.it-quiet\) p\{([^}]+)\}/g),'color:#fff3e5');
});
test('hero background flash sits slightly farther left',()=>{
 assert.match(html,/\.it-hero-brand\{[^}]*right:-100px/);
});

test('nearly completed team card emphasizes its progress number',()=>{
 const app=mount();
 assert.ok(app.scene.innerHTML.includes('it-near'));
 assert.match(html,/\.it-hero\.it-near \.it-hero-progress strong\{font-size:34px;line-height:1;font-weight:1000/);
 app.select.value='behind';app.select.change();
 assert.ok(!app.scene.innerHTML.includes('it-near'));
});

test('nearly finished hero shows the remaining team idents',()=>{
 const app=mount();
 assert.ok(app.scene.innerHTML.includes('<strong>Noch 1</strong>'));
 assert.match(html,/\.it-hero\.it-near \.it-hero-progress \.it-hero-target\{font-size:20px/);
});

test('bold information cards at streak three stay light while quiet cards remain dark',()=>{
 const app=mount({streak:3});
 for(const scenario of ['near','behind','catchup']){
  app.select.value=scenario;app.select.change();
  assert.ok(app.scene.innerHTML.includes('data-info-theme="light"'));
  assert.ok(app.scene.innerHTML.includes('data-reward-theme="dark"'));
 }
 for(const scenario of ['start','you','team']){
  app.select.value=scenario;app.select.change();
  assert.ok(app.scene.innerHTML.includes('data-info-theme="dark"'));
 }
});

test('comeback card emphasizes completed count over target',()=>{
 const app=mount();app.select.value='behind';app.select.change();
 assert.ok(app.scene.innerHTML.includes('<strong>3<span class="it-hero-target">/10</span></strong>'));
 assert.match(html,/\.it-hero\.it-behind \.it-hero-progress strong\{font-size:34px/);
 assert.match(html,/\.it-hero\.it-behind \.it-hero-progress \.it-hero-target\{font-size:20px/);
});

test('team-leads card shows each member progress instead of the aggregate weekly goal',()=>{
 const app=mount();app.select.value='catchup';app.select.change();
 const hero=app.scene.innerHTML.match(/<section class="it-hero [^"]*"[\s\S]*?<\/section>/)[0];
 assert.ok(!hero.includes('it-hero-progress'));
 assert.ok(!hero.includes('Euer Wochenziel'));
 const members=[...hero.matchAll(/class="it-hero-member(?: it-hero-member-self)?"([\s\S]*?)<\/strong>/g)].map(m=>m[1]);
 assert.equal(members.length,3);
 for(const [i,done] of [3,2,1].entries()){
  assert.ok(members[i].includes(`aria-valuenow="${done}" aria-valuemin="0" aria-valuemax="3"`));
  assert.ok(members[i].includes(`width:${done/3*100}%`));
  assert.ok(members[i].includes(`<strong>${done}<small>/3</small>`));
 }
});

test('team-leads member ranking sorts progress descending and places Du last',()=>{
 const app=mount();app.select.value='catchup';app.select.change();
 const members=[...app.scene.innerHTML.matchAll(/class="it-hero-member(?: it-hero-member-self)?"([\s\S]*?)<\/strong>/g)].map(m=>m[1]);
 for(const [i,name] of ['Lena','Max','Du'].entries()){
  assert.ok(members[i].includes(`<span class="it-member-place">${i+1}.</span><span>${name}</span>`));
 }
});

test('own ranked row is larger while preserving its position',()=>{
 const app=mount();app.select.value='catchup';app.select.change();
 const self=app.scene.innerHTML.match(/class="it-hero-member it-hero-member-self"([\s\S]*?)<\/strong>/)[1];
 assert.ok(self.includes('<span class="it-member-place">3.</span><span>Du</span>'));
 assert.match(html,/\.it-hero-member-self\{font-size:23px;[^}]*min-height:34px/);
 assert.match(html,/\.it-hero-member-self strong\{font-size:36px/);
 assert.match(html,/\.it-hero-member-self \.it-member-track\{height:11px/);
});

test('other ranking rows are subdued while own row has substantially larger type',()=>{
 assert.match(html,/\.it-hero-member:not\(\.it-hero-member-self\)\{opacity:\.65/);
 assert.match(html,/\.it-hero-member-self small\{font-size:21px/);
});

test('swipe indicators use compact glass and switch to dark at streak four',()=>{
 for(const streak of [1,2,3,4,5]){
  const app=mount({streak});app.design.value='trophy';app.design.change();
  assert.ok(app.scene.innerHTML.includes(`class="it-hero-pagination" data-pagination-theme="${streak>=4?'dark':'light'}"`));
 }
 assert.match(html,/\.it-hero-pagination\{[^}]*backdrop-filter:blur\(14px\) saturate\(150%\)/);
 assert.match(html,/\.it-hero-pagination button\{[^}]*min-width:22px/);
 assert.match(html,/data-pagination-theme="dark"\] button span\{background:#fff3e5/);
});

test('hero brand flash extends into the lower card edge regardless of card height',()=>{
 const style=html.match(/\.it-hero-brand\{([^}]+)\}/)[1];
 assert.ok(style.includes('bottom:-96px'));
 assert.ok(!style.includes('top:'));
 assert.match(html,/\.it-hero\{[^}]*overflow:hidden/);
});

test('comparison dynamically fits screens with no inter-screen gaps or margins',()=>{
 assert.match(html,/\.it-screen-comparison\{[^}]*repeat\(auto-fit,minmax\(min\(100%,320px\),1fr\)\);gap:0/);
 assert.match(html,/\[data-screen\]>\.it-preview\{[^}]*max-width:none;margin:0/);
 assert.ok(!html.includes('.it-screen-comparison{grid-template-columns:repeat(2,'));
});

test('new week card centers one labeled summary flash per member instead of a weekly goal',()=>{
 const app=mount();app.select.value='start';app.select.change();
 const hero=app.scene.innerHTML.match(/<section class="it-hero [^"]*"[\s\S]*?<\/section>/)[0];
 assert.ok(!hero.includes('it-hero-progress'));
 assert.ok(!hero.includes('Euer Wochenziel'));
 const summaries=[...hero.matchAll(/class="it-hero-member-summary">([\s\S]*?)class="it-hero-sum-name">([^<]+)/g)];
 assert.equal(summaries.length,3);
 for(const [i,name] of ['Du','Lena','Max'].entries()){
  assert.equal(summaries[i][2],name);
  assert.ok(summaries[i][1].includes('aria-valuenow="0" aria-valuemin="0" aria-valuemax="3"'));
  assert.ok(summaries[i][1].includes('it-progress-wave-back'));
 }
 assert.match(html,/\.it-hero-summaries\{display:flex;[^}]*justify-content:center/);
 app.switchMode('detailed');
 assert.equal((app.scene.innerHTML.match(/data-progress-user=/g)||[]).length,3);
});

test('summary flashes have a user-colored outline around both empty and filled regions',()=>{
 const app=mount();app.select.value='start';app.select.change();
 assert.equal((app.scene.innerHTML.match(/class="it-progress-outline"/g)||[]).length,3);
 app.switchMode('detailed');
 assert.equal((app.scene.innerHTML.match(/class="it-progress-outline"/g)||[]).length,6);
 assert.match(html,/\.it-progress-flash \.it-progress-outline\{fill:none;stroke:currentColor;stroke-width:8;stroke-linejoin:round/);
});

test('summary flash layers share a padded viewBox so the left contour and outline are not clipped',()=>{
 const app=mount();app.select.value='start';app.select.change();
 const flashes=[...app.scene.innerHTML.matchAll(/<div class="it-progress-flash">([\s\S]*?)<div class="it-number-base"/g)];
 assert.equal(flashes.length,3);
 for(const [,flash] of flashes){
  assert.equal((flash.match(/viewBox="92 28 328 456"/g)||[]).length,4);
  assert.ok(!flash.includes('viewBox="114 36 320 440"'));
 }
});

test('summary ratio is slightly right of the flash center in both inverse text layers',()=>{
 assert.match(html,/\.it-progress-number\{position:absolute;left:55%;top:53%/);
});

test('personal on-course card uses summary flashes and subdues only the other members',()=>{
 const app=mount();app.select.value='you';app.select.change();
 const hero=app.scene.innerHTML.match(/<section class="it-hero [^"]*"[\s\S]*?<\/section>/)[0];
 assert.ok(!hero.includes('it-hero-progress'));
 assert.equal((hero.match(/data-hero-summary=/g)||[]).length,3);
 assert.equal((hero.match(/it-hero-summary-muted/g)||[]).length,2);
 const self=hero.match(/class="it-hero-member-summary">([\s\S]*?)class="it-hero-sum-name">([^<]+)/);
 assert.equal(self[2],'Du');
 assert.ok(self[1].includes('aria-valuenow="2" aria-valuemin="0" aria-valuemax="3"'));
 assert.match(html,/\.it-hero-summary-muted\{opacity:\.55/);
});

test('information carousel follows the active card natural height instead of stretching to its taller neighbor',()=>{
 const app=mount();app.design.value='trophy';app.design.change();
 assert.equal(app.heroTrack.style.height,'240px');
 app.heroSlide(1);assert.equal(app.heroTrack.style.height,'360px');
 app.heroSlide(0);assert.equal(app.heroTrack.style.height,'240px');
 assert.match(html,/\.it-hero-track\{display:flex;align-items:flex-start/);
});

test('others-nearly-finished card replaces the background flash with an oversized bold L',()=>{
 const app=mount();app.select.value='catchup';app.select.change();
 const hero=app.scene.innerHTML.match(/<section class="it-hero [^"]*"[\s\S]*?<\/section>/)[0];
 assert.ok(hero.includes('<span class="it-hero-letter it-hero-loss" aria-hidden="true">L</span>'));
 assert.ok(!hero.includes('it-hero-brand'));
 assert.match(html,/\.it-hero-letter\{[^}]*font-weight:1000/);
 app.select.value='behind';app.select.change();
 assert.ok(app.scene.innerHTML.includes('class="it-hero-brand"'));
 assert.ok(!app.scene.innerHTML.includes('it-hero-loss'));
});

test('large background letters are centered and on-course cards use W',()=>{
 const app=mount();
 for(const [scenario,letter] of [['catchup','L'],['you','W'],['team','W']]){
  app.select.value=scenario;app.select.change();
  assert.ok(app.scene.innerHTML.includes(`aria-hidden="true">${letter}</span>`));
 }
 assert.match(html,/\.it-hero-letter\{[^}]*left:50%;top:50%;transform:translate\(-50%,-50%\) rotate\(-8deg\)/);
});

test('subdued information cards use a flash unless they have L or W, with optically centered faded letters',()=>{
 const app=mount();app.select.value='start';app.select.change();
 assert.ok(app.scene.innerHTML.includes('class="it-hero-brand"'));
 assert.match(html,/\.it-hero-letter\{[^}]*font-size:var\(--it-letter-size,320px\)[^}]*letter-spacing:0;opacity:\.06/);
 assert.match(html,/\.it-hero-win\{[^}]*letter-spacing:0/);
 for(const scenario of ['catchup','you','team']){
  app.select.value=scenario;app.select.change();
  assert.ok(!app.scene.innerHTML.includes('class="it-hero-brand"'));
 }
});

test('quiet information boxes keep background flashes and letters especially subtle',()=>{
 assert.match(html,/\.it-hero\.it-quiet \.it-hero-brand,#ignite-team-demo \.it-hero\.it-quiet \.it-hero-letter\{opacity:\.04/);
});

test('background L and W scale with card height to extend slightly beyond top and bottom',()=>{
 const app=mount();
 for(const scenario of ['catchup','you','team']){
  app.select.value=scenario;app.select.change();
  assert.equal(app.heroStyle['--it-letter-size'],'320px');
  assert.equal(app.heroStyle['--it-win-letter-size'],'290px');
 }
 assert.match(html,/\.it-hero-letter\{[^}]*font-size:var\(--it-letter-size,320px\);line-height:\.72/);
 assert.match(html,/\.it-hero-win\{font-size:var\(--it-win-letter-size,290px\)/);
});

test('seventh screen prompts setting a weekly goal and avoids an invalid zero-target progress ratio',()=>{
 assert.ok(html.includes('data-screen-id="week6" data-streak="0" data-week-offset="0" data-scenario="goal"'));
 const app=mount({streak:0,scenario:'',ownScenario:'goal'});
 assert.ok(app.scene.innerHTML.includes('class="it-goal-action"'));
 assert.ok(app.scene.innerHTML.includes('data-set-goal>Wochenziel setzen</button>'));
 assert.ok(!app.scene.innerHTML.includes('NaN'));
 app.setGoal();assert.equal(app.goalFeedback.hidden,false);
 assert.equal(app.goalFeedback.textContent,'Hier würde sich die Zielauswahl öffnen.');
 app.switchMode('detailed');
 assert.ok(app.scene.innerHTML.includes('aria-label="Du: Noch kein Wochenziel"'));
 assert.ok(!app.scene.innerHTML.includes('NaN'));
 assert.ok(!app.scene.innerHTML.includes('Infinity'));
});

test('team header caption follows the information scenario',()=>{
 const app=mount();
 for(const [scenario,label] of Object.entries({near:'Am Edgen',behind:'Lowperformer',catchup:'Besser als du',start:'Am Durchstarten',you:'Von dir outperformed',team:'Am Performen'})){
  app.select.value=scenario;app.select.change();
  const header=app.scene.innerHTML.match(/<header class="it-teamtop">([\s\S]*?)<\/header>/)[1];
  assert.ok(header.includes(`<p class="it-eyebrow">${label}</p>`));
 }
});

test('dark Detailed table explicitly keeps weekday and person names light',()=>{
 assert.match(html,/data-week-theme="dark"\] \.it-grid th,[^{]*data-week-theme="dark"\] \.it-grid \.it-dayname,[^{]*data-week-theme="dark"\] \.it-grid \.it-userlabel\{color:var\(--it-ink\)/);
 for(const streak of [4,5]){
  const app=mount({streak});app.switchMode('detailed');
  assert.ok(app.scene.innerHTML.includes('data-week-theme="dark"'));
  assert.equal((app.scene.innerHTML.match(/class="it-userlabel"/g)||[]).length,3);
  assert.equal((app.scene.innerHTML.match(/data-weekday=/g)||[]).length,7);
 }
});

test('Smart ident row removes excess vertical whitespace without shrinking flashes',()=>{
 assert.match(html,/\.it-stack\{height:80px/);
 assert.match(html,/\.it-date\{[^}]*margin:3px 0 4px/);
 assert.match(html,/\.it-day\{[^}]*padding:8px 0 2px/);
 assert.match(html,/\.it-week-footer\{[^}]*padding:10px 6px 10px/);
 assert.match(html,/\.it-stack \.it-mark\{[^}]*height:64px/);
});

test('Streak Info first also works for nearly finished and set-goal screens at zero streak',()=>{
 for(const ownScenario of ['near','goal']){
  const app=mount({streak:0,scenario:'',ownScenario});
  app.design.value='trophy';app.design.change();
  app.start.checked=true;app.start.change();
  assert.equal(app.heroTrack.scrollLeft,400);
  assert.ok(app.scene.innerHTML.includes('it-reward-zero'));
  assert.ok(app.scene.innerHTML.includes('Entfacht euer<br>erstes Feuer.'));
  app.heroSlide(0);assert.equal(app.heroTrack.scrollLeft,0);
  app.heroSlide(1);assert.equal(app.heroTrack.scrollLeft,400);
 }
});


test('week date navigation adopts dark mode from streak four including its date popover',()=>{
 const app=mount({streak:4});
 assert.ok(app.scene.innerHTML.includes('data-week-theme="dark"'));
 assert.match(html,/data-week-theme="dark"\] \.it-week-nav\{color-scheme:dark;--it-bg:#211b18/);
 assert.match(html,/data-week-theme="dark"\] \.it-week-nav button,#ignite-team-demo \.it-phone\[data-week-theme="dark"\] \.it-dates\{color:#fff3e5/);
 assert.ok(!html.includes('[data-streak-count="5"] .it-week-nav'));
});
