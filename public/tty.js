(function(){
  function $(id){ return document.getElementById(id); }

  window.TTY_BOOT = function(opts){
    const sess = opts.session;
    const pre  = $('tty');
    const box  = $('cmd');

    async function snap(){
      try{
        const res = await fetch(`/tty/${encodeURIComponent(sess)}/snap`, {cache:'no-store'});
        if(!res.ok){
          pre.textContent = `ERROR: ${res.status} ${res.statusText}`;
          return;
        }
        const txt = await res.text();
        pre.textContent = txt || "[no output yet]";
        pre.scrollTop = pre.scrollHeight;
      }catch(e){
        pre.textContent = "ERROR: " + (e && e.message ? e.message : e);
      }
    }
    setInterval(snap, 600);
    snap();

    window.sendKey = async function(key){
      await fetch(`/tty/${encodeURIComponent(sess)}/send`, {
        method:'POST',
        headers:{'Content-Type':'application/x-www-form-urlencoded'},
        body:`key=${encodeURIComponent(key)}`
      });
      setTimeout(snap, 150);
    };

    window.sendText = async function(){
      const t = box.value;
      if(!t) return;
      await fetch(`/tty/${encodeURIComponent(sess)}/send`, {
        method:'POST',
        headers:{'Content-Type':'application/x-www-form-urlencoded'},
        body:`text=${encodeURIComponent(t)}`
      });
      box.value = '';
      setTimeout(snap, 200);
    };

    box.addEventListener('keydown', (e)=>{
      if(e.key === 'Enter'){
        e.preventDefault();
        window.sendText();
      }
    });
  };
})();
