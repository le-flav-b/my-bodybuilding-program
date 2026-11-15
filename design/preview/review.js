// Review-sheet helper: clones <template id="tpl"> into every <section data-theme>.
document.querySelectorAll('section[data-theme]').forEach((s) => {
  s.append(document.getElementById('tpl').content.cloneNode(true));
  s.querySelectorAll('[data-shot-suffix]').forEach((el) => {
    el.setAttribute('data-shot', el.getAttribute('data-shot-suffix') + '_' + s.dataset.theme);
  });
});
