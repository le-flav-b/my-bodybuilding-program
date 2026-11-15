// Review-sheet helper: in each .review block, clones its <template> into every <section data-theme>.
// Elements with data-shot-suffix="name" get data-shot="name_<theme>" (used by tools/shoot.mjs).
document.querySelectorAll('.review').forEach((block) => {
  const tpl = block.querySelector('template');
  if (!tpl) return;
  block.querySelectorAll('section[data-theme]').forEach((s) => {
    if (s.childElementCount) return;
    s.append(tpl.content.cloneNode(true));
    s.querySelectorAll('[data-shot-suffix]').forEach((el) => el.setAttribute('data-shot', `${el.dataset.shotSuffix}_${s.dataset.theme}`));
  });
});
