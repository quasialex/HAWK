(function(){
  function esc(s){ return s.replace(/[&<>]/g, c=>({ '&':'&amp;','<':'&lt;','>':'&gt;' }[c])); }

  window.TTY_BOOT = function(opts){
    const sess = opts.session;
    const pre  = document.getElementById('tty');
    const cmd  = document.getElementById('cmd');

    const es = new EventSource(`/tty/${encodeURIComponent(sess)}/stream`);
    es.onmessage = (e)=>{
      pre.textContent += e.data + "\n";
      pre.scrollTop = pre.scrollHeight;
    };
    es.onerror = ()=>{ /* keep quiet; tmux may end */ };

    window.sendKey = async function(key){
      await fetch(`/tty/${encodeURIComponent(sess)}/send`, {
        method:'POST',
        headers:{'Content-Type':'application/x-www-form-urlencoded'},
        body: `key=${encodeURIComponent(key)}`
      });
    };

    window.sendText = async function(){
      const t = cmd.value;
      if(!t) return;
      // send the text then an Enter
      await fetch(`/tty/${encodeURIComponent(sess)}/send`, {
        method:'POST',
        headers:{'Content-Type':'application/x-www-form-urlencoded'},
        body: `text=${encodeURIComponent(t)}`
      });
      await fetch(`/tty/${encodeURIComponent(sess)}/send`, {
        method:'POST',
        headers:{'Content-Type':'application/x-www-form-urlencoded'},
        body: `key=ENTER`
      });
      cmd.value = '';
    };

    cmd.addEventListener('keydown', (e)=>{
      if(e.key === 'Enter'){
        e.preventDefault();
        window.sendText();
      }
    });
  };
})();
