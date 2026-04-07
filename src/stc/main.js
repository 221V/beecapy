
const ws = new WebSocket("ws://localhost:3010/ws"); // same PORT
ws.onmessage = (e) => console.log("ws <- ", e.data); // todo reconnect + ping-pong from n2o

ws.onopen = () => {
  qi('ws_status_err').style.display = 'none';
  qi('ws_status_ok').style.display = 'block';
  ws.send("Hello from browser!");
};

ws.onclose = (e) => {
  qi('ws_status_ok').style.display = 'none';
  qi('ws_status_err').style.display = 'block';
  console.log("ws closed", e);
};


function show_ignore_dirs_left(){
  var el1 = qi('label_ignore_dirs_left'); if(el1){ el1.style.display = 'inline-block'; }
  var el2 = qi('hide_ignore_dirs_left'); if(el2){ el2.style.display = 'inline-block'; }
  var el3 = qi('show_ignore_dirs_left'); if(el3){ el3.style.display = 'none'; }
}

function show_ignore_dirs_right(){
  var el1 = qi('label_ignore_dirs_right'); if(el1){ el1.style.display = 'inline-block'; }
  var el2 = qi('hide_ignore_dirs_right'); if(el2){ el2.style.display = 'inline-block'; }
  var el3 = qi('show_ignore_dirs_right'); if(el3){ el3.style.display = 'none'; }
}

function hide_ignore_dirs_left(){
  var el1 = qi('label_ignore_dirs_left'); if(el1){ el1.style.display = 'none'; }
  var el2 = qi('hide_ignore_dirs_left'); if(el2){ el2.style.display = 'none'; }
  var el3 = qi('show_ignore_dirs_left'); if(el3){ el3.style.display = 'inline-block'; }
}

function hide_ignore_dirs_right(){
  var el1 = qi('label_ignore_dirs_right'); if(el1){ el1.style.display = 'none'; }
  var el2 = qi('hide_ignore_dirs_right'); if(el2){ el2.style.display = 'none'; }
  var el3 = qi('show_ignore_dirs_right'); if(el3){ el3.style.display = 'inline-block'; }
}



window.addEventListener("load", function(){
  
  //var el1 = qi('show_ignore_dirs_left'); // use onclick="" instead
  //if(el1){ el1.addEventListener("click", show_ignore_dirs_left); }
  
  
  
}, false);

