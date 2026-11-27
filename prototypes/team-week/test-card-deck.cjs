const {test} = require('node:test');
const assert = require('node:assert/strict');
const {coreOrbitLayout,orbitLayout,shouldDismiss,DeckSequence,AUTO_MS}=require('./card-deck.js');
function clock() {
  let now=0, id=0; const jobs=new Map();
  return {schedule(fn,delay){jobs.set(++id,{fn,time:now+delay});return id;},cancel(id){jobs.delete(id);},
    tick(ms){const end=now+ms;while(true){const next=[...jobs].sort((a,b)=>a[1].time-b[1].time)[0];if(!next||next[1].time>end)break;jobs.delete(next[0]);now=next[1].time;next[1].fn();}now=end;},get pending(){return jobs.size;}};
}
test('automatic changes cycle indefinitely through exactly the available cards',()=>{
 const c=clock();const d=new DeckSequence(3,()=>{},c.schedule,c.cancel);d.arm();
 c.tick(AUTO_MS-1);assert.equal(d.index,0);c.tick(1);assert.deepEqual(d.queue,[1,2,0]);
 c.tick(AUTO_MS*99);assert.equal(d.phase,'cards');assert.equal(d.queue.length,3);
 assert.equal(c.pending,1);
});
test('manual swipes remove cards permanently even after automatic rotations',()=>{
 const c=clock();const d=new DeckSequence(3,()=>{},c.schedule,c.cancel);d.arm();c.tick(AUTO_MS);
 assert.equal(d.index,1);d.dismiss();assert.deepEqual(d.queue,[2,0]);
 c.tick(AUTO_MS*8);assert.ok(!d.queue.includes(1));
 d.dismiss();assert.deepEqual(d.queue,[0]);assert.equal(c.pending,0);
 d.dismiss();assert.equal(d.phase,'core');assert.equal(c.pending,0);
});
test('the last card stays until swiped and then reveals the Core directly',()=>{
 const c=clock();const d=new DeckSequence(1,()=>{},c.schedule,c.cancel);d.arm();c.tick(AUTO_MS*10);
 assert.deepEqual(d.queue,[0]);assert.equal(c.pending,0);d.dismiss();assert.deepEqual(d.queue,[]);assert.equal(d.phase,'core');
 c.tick(AUTO_MS*10);assert.equal(d.phase,'core');assert.equal(c.pending,0);
});
test('pause and replay preserve a single timer and restore dismissed cards',()=>{
 const c=clock();const d=new DeckSequence(3,()=>{},c.schedule,c.cancel);d.arm();d.dismiss();
 d.stop();c.tick(60000);assert.equal(d.index,1);d.arm();d.arm();assert.equal(c.pending,1);
 d.core();assert.equal(c.pending,0);d.reset();assert.deepEqual(d.queue,[0,1,2]);assert.equal(c.pending,1);
});
test('an empty deck opens and resets directly to the Core without a placeholder',()=>{
 const c=clock();const d=new DeckSequence(0,()=>{},c.schedule,c.cancel);d.arm();assert.deepEqual(d.queue,[]);
 assert.equal(c.pending,0);assert.equal(d.phase,'core');d.reset();assert.equal(d.phase,'core');assert.equal(c.pending,0);
});
test('gesture threshold accepts any direction and rejects taps and short pulls',()=>{
 for(const [x,y] of [[37,0],[-37,0],[0,37],[0,-37],[26,26]])assert.equal(shouldDismiss(x,y),true);
 for(const [x,y] of [[18,0],[8,0],[24,10],[36,0],[0,-18]])assert.equal(shouldDismiss(x,y),false);
});
test('pointer handlers throw once at threshold crossing before release and swallow the trailing click',()=>{
 const vm=require('node:vm'),fs=require('node:fs');
 const source=fs.readFileSync(__dirname+'/card-deck.js','utf8');
 for(const trigger of ['move','release']){
  const flights=[];
  const context={gesture:{id:1,samples:[{x:0,y:0,t:0}]},thrownPointer:null,swallowUntil:0,
   floating:{clone:{style:{}}},performance:{now:()=>100},shouldDismiss,
   fly:(automatic,samples)=>flights.push({automatic,samples})};
  context.move=vm.runInNewContext('('+source.match(/function move\(e\) \{[\s\S]*?\n    \}/)[0]+')',context);
  const release=vm.runInNewContext('('+source.match(/function release\(e,cancelled=false\) \{[\s\S]*?\n    \}/)[0]+')',context);
  context.move({pointerId:2,clientX:100,clientY:0});assert.equal(flights.length,0);
  context.move({pointerId:1,clientX:36,clientY:0});assert.equal(flights.length,0);
  if(trigger==='move'){
   context.move({pointerId:1,clientX:37,clientY:0});
   assert.equal(context.thrownPointer,1);assert.equal(context.swallowUntil,Infinity);
   context.move({pointerId:1,clientX:80,clientY:0});
  }
  release({pointerId:1,clientX:37,clientY:0});
  assert.equal(flights.length,1);assert.equal(flights[0].automatic,false);
  assert.equal(flights[0].samples.at(-1).x,37);
  assert.equal(context.gesture,null);assert.equal(context.thrownPointer,null);
  assert.equal(context.swallowUntil,500);
  release({pointerId:1,clientX:37,clientY:0});assert.equal(flights.length,1);
 }
});
for(let members=1;members<=4;members++) for(let slots=1;slots<=7;slots++) {
 test(`Core geometry: ${members} members × ${slots} Idents, bounded and collision-free at 280–393px`,()=>{
  for(const mode of ['flashes','avatars']){
   const all=coreOrbitLayout(Array(members).fill(slots),mode);
   assert.equal(all.length,members*slots);
   for(let user=0;user<members;user++)assert.equal(all.filter(p=>p.user===user).length,slots);
   for(const width of [280,320,360,393]){
   const scale=width/360;
    for(const p of all){assert.ok(p.x-p.size/2>=4-1e-8&&p.x+p.size/2<=356+1e-8);assert.ok(p.y-p.size/2>=4-1e-8&&p.y+p.size/2<=356+1e-8);}
    for(let a=0;a<all.length;a++)for(let b=a+1;b<all.length;b++)assert.ok(Math.hypot(all[a].x-all[b].x,all[a].y-all[b].y)*scale>=(all[a].size+10)*scale-1e-8,`markers ${a}/${b} need a margin`);
   }
  }
 });
}
test('additional rings take priority when they allow larger markers',()=>{
 for(const mode of ['flashes','avatars'])for(let total=1;total<=28;total++){
  const targets=Array.from({length:Math.ceil(total/7)},(_,i)=>Math.min(7,total-i*7));
  const points=coreOrbitLayout(targets,mode),maximum=mode==='avatars'?76:360*.43*.95;
  const sine=Math.sin(Math.PI/Math.max(2,total));
  const singleSize=Math.min(maximum,176-(mode==='avatars'?80:70),(352*sine-10)/(1+sine));
  const rows=new Set(points.map(p=>p.radius)).size;
  assert.ok(points[0].size>=singleSize-1e-6,`${mode}, ${total}: never shrink to use more rings`);
  if(rows>1)assert.ok(points[0].size>singleSize+.01,`${mode}, ${total}: added ring must enlarge markers`);
  for(const point of points)assert.ok(point.radius-point.size/2>=(mode==='avatars'?80:70)-1e-6);
 }
 // Eighteen fit in one ring at the old minimum size, but two rings give larger Flashes.
 assert.equal(new Set(coreOrbitLayout([6,6,6]).map(p=>p.radius)).size,2);
 assert.ok(coreOrbitLayout([7,7,7]).every(p=>p.size>=47.99));
 assert.ok(coreOrbitLayout([7,7,7,7]).every(p=>p.size>=43));
});
test('staggered rings enlarge twelve Idents regardless of member grouping',()=>{
 for(const targets of [[4,4,4],[6,6],[3,3,3,3]]){
  const points=coreOrbitLayout(targets);
  assert.equal(new Set(points.map(p=>p.radius)).size,2);
  assert.ok(points.every(p=>p.size>=64.9));
  const radii=[...new Set(points.map(p=>p.radius))];
  // Rows interlock angularly instead of requiring an entire marker diameter radially.
  assert.ok(Math.abs(radii[0]-radii[1])<points[0].size+10);
 }
});
test('ring sizing depends on total occupancy, not special member or Ident combinations',()=>{
 for(const mode of ['flashes','avatars'])for(let members=1;members<=4;members++)for(let slots=1;slots<=7;slots++){
  const grouped=coreOrbitLayout(Array(members).fill(slots),mode);
  const combined=coreOrbitLayout([members*slots],mode);
  assert.deepEqual(grouped.map(({x,y,radius,size})=>({x,y,radius,size})),combined.map(({x,y,radius,size})=>({x,y,radius,size})));
  for(const radius of new Set(grouped.map(p=>p.radius))){
   const ring=grouped.filter(p=>p.radius===radius);
   if(ring.length>1){
    const gaps=ring.map((point,i)=>(ring[(i+1)%ring.length].angle+Math.PI*2-point.angle)%(Math.PI*2));
    const step=Math.min(...gaps);
    for(const gap of gaps)assert.ok(Math.abs(gap/step-Math.round(gap/step))<1e-8);
   }
  }
 }
});
test('sparse rings enlarge markers up to a cap and spread them evenly over the whole circle',()=>{
 for(const mode of ['flashes','avatars']){
  let previous=Infinity;
  for(let total=1;total<=28;total++){
   const points=coreOrbitLayout([total],mode),size=points[0].size;
   assert.ok(size<=previous);assert.ok(size<=(mode==='avatars'?76:360*.43*.95));
   previous=size;
   if(new Set(points.map(p=>p.radius)).size===1&&total>1){
    for(let i=0;i<total;i++)assert.ok(Math.abs((points[(i+1)%total].angle+Math.PI*2-points[i].angle)%(Math.PI*2)-Math.PI*2/total)<1e-8);
   }
  }
  assert.ok(coreOrbitLayout([3],mode)[0].size>coreOrbitLayout([7,7],mode)[0].size);
 }
});
test('sparse Flashes grow beyond the old cap while retaining the TeamFlash clearance',()=>{
 for(const targets of [[1],[2],[1,1],[1,1,1]]){
  const points=coreOrbitLayout(targets);
  assert.ok(points.every(p=>p.size>105.99&&p.size<=360*.43*.95));
  for(const p of points){
   assert.ok(p.radius-p.size/2>=70-1e-7);
   assert.ok(p.radius+p.size/2<=176+1e-7);
   // Further growth would consume the reserved margin to the TeamFlash.
   assert.ok(176-(p.size+.01)<70);
  }
 }
});
test('unequal and zero targets preserve ownership, spacing, and local Ident indices',()=>{
 for(const mode of ['flashes','avatars'])for(let a=0;a<=7;a++)for(let b=0;b<=7;b++)for(let c=0;c<=7;c++)for(let d=0;d<=7;d++){
  const targets=[a,b,c,d],points=coreOrbitLayout(targets,mode);
  assert.equal(points.length,a+b+c+d);
  targets.forEach((slots,user)=>assert.deepEqual(points.filter(p=>p.user===user).map(p=>p.ident),Array.from({length:slots},(_,i)=>i)));
  for(let i=0;i<points.length;i++)for(let j=i+1;j<points.length;j++)assert.ok(Math.hypot(points[i].x-points[j].x,points[i].y-points[j].y)>=points[i].size+10-1e-8);
 }
});
test('browser timers are invoked without binding the DeckSequence as their receiver',()=>{
 const vm=require('node:vm'),fs=require('node:fs');
 const context={module:{exports:{}},setTimeout:function(){assert.notEqual(this?.constructor?.name,'DeckSequence');return 1;},clearTimeout:function(){assert.notEqual(this?.constructor?.name,'DeckSequence');}};
 vm.runInNewContext(fs.readFileSync(__dirname+'/card-deck.js','utf8'),context);
 const d=new context.module.exports.DeckSequence(2,()=>{});d.arm();d.stop();
});
const {swipeFlight,swipeFrames,orbitStep}=require('./card-deck.js');
test('slow and fast pulls both fly out rapidly in the pull direction with a full rotation',()=>{
 const slow=swipeFlight([{x:0,y:0,t:0},{x:160,y:-40,t:1000}]);
 const fast=swipeFlight([{x:0,y:0,t:0},{x:160,y:-40,t:90}]);
 assert.deepEqual(fast,slow);assert.equal(fast.duration,320);assert.equal(Math.abs(fast.spin),360);
 assert.ok(fast.x>0&&fast.y<0);assert.ok(Math.abs(fast.y/fast.x+.25)<1e-8);
});
test('flight follows the pull in every direction and travels beyond the screen',()=>{
 for(const [dx,dy] of [[37,0],[-37,0],[0,37],[0,-37],[30,-30]])for(const viewport of [{width:280,height:600},{width:2560,height:1410}]){
  const flight=swipeFlight([{x:0,y:0},{x:dx,y:dy}],viewport);
  assert.ok(flight.x*dx+flight.y*dy>0);
  assert.ok(Math.hypot(flight.x,flight.y)>Math.hypot(viewport.width,viewport.height));
  const frames=swipeFrames('translate(37px,0)',flight);
  assert.equal(frames.length,2);assert.ok(frames.every(f=>f.opacity===1));
  assert.match(frames[1].transform,/rotate\(-?360deg\)/);assert.ok(!frames[1].transform.includes('rotateX'));
 }
});
test('stationary and zero-duration gestures produce finite, bounded flight parameters',()=>{
 for(const samples of [[{x:0,y:0,t:0}],[{x:0,y:0,t:0},{x:900,y:900,t:0}]]){
  const flight=swipeFlight(samples);assert.ok(Object.values(flight).every(Number.isFinite));
  assert.equal(flight.duration,320);
 }
});
test('orbit boost adds a short impulse and decays back to the same slow rotation',()=>{
 const normal=orbitStep(0,0,1),boosted=orbitStep(0,42,1);
 assert.equal(normal.angle,2);assert.ok(boosted.angle>normal.angle);assert.ok(boosted.boost<42);
 const settled=orbitStep(0,42,12);assert.ok(settled.boost<.001);
 const a=orbitStep(0,42,.5),b=orbitStep(a.angle,a.boost,.5);
 assert.ok(Math.abs(b.angle-boosted.angle)<1e-10);
});
const {orbitPosition,memberArc,autoRotationFrames}=require('./card-deck.js');
test('orbiting changes only position and preserves each marker’s radius through a full revolution',()=>{
 for(let members=1;members<=4;members++) for(let slots=1;slots<=7;slots++){
  for(const point of orbitLayout(members,slots)) for(const angle of [0,45,90,180,270,360]){
   const p=orbitPosition(point,angle);
   assert.deepEqual(Object.keys(p),['x','y']);
   assert.ok(Math.abs(Math.hypot(p.x-180,p.y-180)-point.radius)<1e-9);
   if(angle===360){assert.ok(Math.abs(p.x-point.x)<1e-9);assert.ok(Math.abs(p.y-point.y)<1e-9);}
  }
 }
});
for(let count=1;count<=4;count++)test(`rounded progress arcs: ${count} members, separated segments and correct fill`,()=>{
 const arcs=Array.from({length:count},(_,i)=>memberArc(i,count,i+1,7));
 for(let i=0;i<count;i++){
  const a=arcs[i],b=arcs[(i+1)%count];
  assert.ok(a.sweep>0&&a.sweep<360);assert.equal(a.progress,(i+1)/7);
  const gap=(b.start+360-a.start-a.sweep)%360;
  assert.ok(gap>=19.999,`segment gap ${gap} leaves room for round caps`);
  assert.match(a.track,/^M .* A 146 146 0 [01] 1 /);
 }
 assert.equal(memberArc(0,count,0,7).fill,'');
 assert.equal(memberArc(0,count,0,0).fill,'');
 const full=memberArc(0,count,9,7);assert.equal(full.fill,full.track);
});
test('auto rotation clears the stack before returning behind it without fading',()=>{
 for(const width of [240,300,360]){
  const frames=autoRotationFrames('none',width);
  assert.ok(frames.every(f=>f.opacity===1));
  assert.equal(frames[0].transform,'none');assert.equal(frames[0].zIndex,11);
  const outward=frames.find(f=>f.offset===.48),behind=frames.find(f=>f.offset===.5);
  assert.equal(outward.transform,behind.transform);
  assert.ok(Math.abs(Number(outward.transform.match(/translate\(([-\d.]+)px/)[1]))>width);
  assert.equal(outward.zIndex,11);assert.equal(behind.zIndex,0);assert.equal(frames.at(-1).zIndex,0);
  assert.match(frames.at(-1).transform,/translate\(0,14px\)/);
 }
});
test('orbit selector offers Flashes and progress arcs without a profile image option',()=>{
 const fs=require('node:fs');
 const source=fs.readFileSync(__dirname+'/card-deck.js','utf8');
 const select=source.match(/<select data-core-mode>(.*?)<\/select>/)[1];
 assert.deepEqual([...select.matchAll(/<option value="([^"]+)"/g)].map(m=>m[1]),['flashes','arcs']);
 assert.ok(!select.includes('Profilbilder'));
});
test('Core controls share the control panel while replay belongs to the card group',()=>{
 const source=require('node:fs').readFileSync(__dirname+'/card-deck.js','utf8');
 const core=source.match(/tools.innerHTML = `([\s\S]*?)`;/)[1];
 for(const control of ['data-core-members','data-core-slots','data-core-mode','data-preview-core'])assert.ok(core.includes(control));
 assert.ok(!core.includes('data-replay-deck'));
 assert.ok(source.includes("host.querySelector('.it-design-controls').appendChild(tools)"));
 assert.ok(source.includes("host.querySelector('.it-design-controls').addEventListener('click'"));
});
