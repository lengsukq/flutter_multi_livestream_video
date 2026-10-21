import assert from 'node:assert/strict';
import test from 'node:test';
import { ClassroomStateDirectory } from '../classroom/classroom-state.ts';
import type { RoomEntry } from '../types.ts';
function fixture() {
  const entry: RoomEntry = { provider:'livekit', roomCode:'board123',roomMode:'meeting', classroomTeacherUserId:'teacher',
    createdAt:new Date().toISOString(),lastHeartbeatMs:Date.now(),attendees:['teacher','alice','bob'].map((name,i)=>({
      attendeeId:`p${i}`,userId:name,externalUserId:name,displayName:name,joinedAt:new Date().toISOString(),
    })) };
  const directory = new ClassroomStateDirectory();
  const snap = (teacher = true, user = 'teacher') => directory.snapshot(entry,teacher,user);
  const act = (action:string,data:object,eventId?:string,student=false) => directory.act(entry,entry.attendees[student?1:0]!,!student,
    {action:`tool.${action}`,payload:JSON.stringify(data),eventId});
  const mode = (mode:string,sourceKey?:string) => act('content.mode',{mode,sourceKey,expectedRevision:snap().tools.content.revision});
  const board = (action:string,data:object={},eventId?:string) => {
    const b=snap().tools.content.whiteboard;
    return act(`whiteboard.${action}`,{expectedRevision:b.revision,pageId:b.activePageId,canvasId:b.canvas.canvasId,...data},eventId);
  };
  return {entry,directory,snap,act,mode,board};
}
test('teacher plus two students follow pages, modes and every annotation tool; late join restores current canvas',()=>{
  const f=fixture(); f.mode('whiteboard');
  const first=f.snap().tools.content.whiteboard;
  for (const tool of ['pen','highlight','circle','arrow','text']) f.board('begin',{id:tool,tool,color:0xffffaa00,width:3,text:'Lesson',points:[{x:.1,y:.2},{x:.5,y:.6}]});
  f.board('append',{id:'pen',points:[{x:.8,y:.7}]});
  for (const user of ['alice','bob']) {
    const c=f.snap(false,user).tools.content;
    assert.equal(c.mode,'whiteboard'); assert.equal(c.canManage,false); assert.equal(c.whiteboard.canEdit,false);
    assert.equal(c.whiteboard.canvas.shapes.length,5);
  }
  assert.throws(()=>f.act('whiteboard.clear',{expectedRevision:0},undefined,true),/Teacher permission/);
  f.board('page.add',{title:'Second'}); const second=f.snap().tools.content.whiteboard.activePageId;
  f.mode('screen','screen1'); const screen1=f.snap().tools.annotation.canvasId;
  f.act('annotation.begin',{canvasId:screen1,id:'screen-note',tool:'text',color:0xffffffff,width:3,text:'Screen',points:[{x:.3,y:.3}]});
  assert.equal(f.snap(false,'alice').tools.content.screen.shapes.length,1);
  f.mode('whiteboard'); assert.equal(f.snap().tools.content.whiteboard.activePageId,second);
  f.board('page.select',{pageId:first.activePageId}); assert.equal(f.snap().tools.content.whiteboard.canvas.shapes.length,5);
  assert.throws(()=>f.board('begin',{canvasId:first.canvas.canvasId,id:'late',tool:'pen',width:3,color:1,points:[{x:0,y:0}]}),/changed/);
  f.board('undo'); assert.equal(f.snap().tools.content.whiteboard.canvas.shapes.length,4);
  f.board('clear'); assert.equal(f.snap().tools.content.whiteboard.canvas.shapes.length,0);
  f.mode('screen','screen2'); assert.notEqual(f.snap().tools.annotation.canvasId,screen1);
  assert.throws(()=>f.act('annotation.clear',{canvasId:screen1}),/changed/);
  const rejoined=f.snap(false,'bob'); assert.equal(rejoined.tools.content.mode,'screen');
  f.mode('whiteboard'); f.board('page.delete',{pageId:second});
  assert.throws(()=>f.board('page.delete'),/at least one/);
});
test('teacher erases a selected mark, students see deletion, undo restores it',()=>{
  const f=fixture(); f.mode('whiteboard');
  for (const id of ['first','middle','last']) f.board('begin', {
    id,tool:'pen',color:0xff1f2a3c,width:3,points:[{x:.2,y:.4},{x:.5,y:.4}],
  });
  const before = f.snap().tools.content.whiteboard;
  f.board('erase',{id:'middle'});
  assert.deepEqual(f.snap(false,'alice').tools.content.whiteboard.canvas.shapes.map((s:{id:string})=>s.id),['first','last']);
  assert.throws(()=>f.act('whiteboard.erase',{
    id:'first',expectedRevision:before.revision,pageId:before.activePageId,canvasId:before.canvas.canvasId,
  },undefined,true),/Teacher permission/);
  assert.throws(()=>f.board('erase',{id:'nonexistent'}),/Shape not found/);
  f.board('undo');
  assert.deepEqual(f.snap(false,'bob').tools.content.whiteboard.canvas.shapes.map((s:{id:string})=>s.id),['first','middle','last']);
  f.board('erase',{id:'last'});
  f.board('begin',{id:'new',tool:'pen',color:1,width:3,points:[{x:.1,y:.3}]});
  f.board('undo');
  assert.deepEqual(f.snap().tools.content.whiteboard.canvas.shapes.map((s:{id:string})=>s.id),['first','middle']);
});

test('whiteboard persists marks outside the original page; screen annotation stays bounded',()=>{
  const f=fixture();
  f.mode('whiteboard');
  f.board('begin',{
    id:'beyond-page', tool:'pen', color:0xff2563eb, width:3,
    points:[{x:-2.5,y:1.4},{x:1.7,y:-0.5}],
  });
  assert.deepEqual(
    f.snap(false,'alice').tools.content.whiteboard.canvas.shapes[0]?.points,
    [{x:-2.5,y:1.4},{x:1.7,y:-0.5}],
  );
  assert.throws(()=>f.board('begin',{
    id:'huge',tool:'pen',color:1,width:3,points:[{x:1001,y:0}],
  }),/out of range/);
  f.mode('screen','display1');
  const canvasId=f.snap().tools.annotation.canvasId;
  assert.throws(()=>f.act('annotation.begin',{
    canvasId,id:'bad-screen',tool:'pen',color:1,width:3,
    points:[{x:-.5,y:1.4}],
  }),/normalized/);
});
test('page limits, revision conflicts, idempotency and active-page deletion are enforced',()=>{
  const f=fixture(); f.mode('whiteboard');
  const state=f.snap().tools.content.whiteboard;
  const payload={expectedRevision:state.revision,title:'Second'};
  const added=f.act('whiteboard.page.add',payload,'page-add-0001');
  const replay=f.act('whiteboard.page.add',payload,'page-add-0001'); assert.equal(added.revision,replay.revision);
  assert.throws(()=>f.act('whiteboard.page.add',{...payload,title:'Other'},'page-add-0001'),/Reused/);
  assert.throws(()=>f.act('whiteboard.page.add',payload),/revision/);
  f.board('page.add',{title:'Third'}); f.board('page.delete');
  assert.equal(f.snap().tools.content.whiteboard.activePageId,added.tools.content.whiteboard.activePageId);
  assert.notEqual(f.snap().tools.content.whiteboard.canvas.canvasId,added.tools.content.whiteboard.canvas.canvasId);
  for(let i=0;i<18;i++) f.board('page.add',{title:`Page ${i}`});
  assert.equal(f.snap().tools.content.whiteboard.pages.length,20);
  assert.throws(()=>f.board('page.add',{title:'Overflow'}),/limit/);
  assert.throws(()=>f.act('content.mode',{mode:'members',expectedRevision:-1}),/revision/);
  f.mode('members'); assert.throws(()=>f.board('clear'),/not active/);
  const snapshot=f.snap(); assert.ok(!('canvas' in snapshot.tools.content.whiteboard.pages[0]!));
});
