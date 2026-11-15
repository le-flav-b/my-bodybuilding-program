// Review-sheet helper: in each .review block, clones its <template> into every <section data-theme>.
document.querySelectorAll('.review').forEach((block) => {
  const tpl = block.querySelector('template');
  if (!tpl) return;
  block.querySelectorAll('section[data-theme]').forEach((s) => {
    if (s.childElementCount) return;
    s.append(tpl.content.cloneNode(true));
  });
});
