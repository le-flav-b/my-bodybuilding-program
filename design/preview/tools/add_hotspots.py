# One-off helper: tags tappable elements in the screen previews with data-go="<target shot id>".
# Re-runnable: skips needles already tagged. Run: python3 design/preview/tools/add_hotspots.py
import re, pathlib
here = pathlib.Path(__file__).resolve().parent.parent

def tag(s, block, needle, target, nth=0):
    a = s.index(f'data-shot-suffix="{block}"')
    nxt = s.find('data-shot-suffix="', a + 10)
    end = nxt if nxt != -1 else len(s)
    seg = s[a:end]
    idx = -1
    for _ in range(nth + 1):
        idx = seg.index(needle, idx + 1)
    m = re.match(r'<(\w+)', seg[idx:])
    ins = idx + len(m.group(0))
    if seg[ins:ins + 9] == ' data-go=':
        return s
    seg = seg[:ins] + f' data-go="{target}"' + seg[ins:]
    return s[:a] + seg + s[end:]

NAV = {'today': 'today_normal', 'fitness_center': 'program_default', 'monitoring': 'progress_calendar', 'person': 'profile_default'}
def navs(s):
    return re.sub(r'<a( class="on")?><span class="ind"><span class="i">(today|fitness_center|monitoring|person)</span>',
                  lambda m: f'<a{m.group(1) or ""} data-go="{NAV[m.group(2)]}"><span class="ind"><span class="i">{m.group(2)}</span>', s)

START = '<button class="btn big filled block"><span class="i fill">play_arrow</span>Start</button>'
BACK = '<button class="iconbtn"><span class="i">arrow_back</span></button>'
spec = {
 'screens-today.html': [
   ('today_normal', START, 'preview_default'), ('today_normal', '<button class="btn text"><span class="i">swap_horiz</span>', 'today_pick-session'),
   ('today_normal', '<div class="card since">', 'workout-detail_default'),
   ('today_after-workout', START, 'preview_default'),
   ('today_in-progress', '<div class="banner">', 'player_reps'),
   ('today_empty', '<button class="btn big filled">', 'session-editor_default'),
   ('today_pick-session', '<div class="session-row next">', 'preview_default'),
   ('today_pick-session', '<div class="scrim-over">', 'today_normal')],
 'screens-workout.html': [
   ('preview_default', '<button class="btn big filled block"><span class="i fill">play_arrow</span>Start workout', 'player_reps'),
   ('preview_default', BACK, 'today_normal'),
   ('player_reps', '<button class="btn big filled block"><span class="i">check</span>Done', 'player_trophy'),
   ('player_reps', '<button class="iconbtn"><span class="i">pause</span>', 'player_paused'),
   ('player_reps', '<button class="iconbtn"><span class="i">view_list</span>', 'workout-list_default'),
   ('player_resting', '<button class="btn big tonal"', 'player_reps'),
   ('player_resting', '<button class="iconbtn"><span class="i">view_list</span>', 'workout-list_default'),
   ('player_resting', '<button class="iconbtn"><span class="i">pause</span>', 'player_paused'),
   ('player_timed', '<button class="iconbtn"><span class="i">view_list</span>', 'workout-list_default')],
 'screens-workout-2.html': [
   ('workout-list_default', '<div class="it"><span class="i">swap_horiz</span>', 'workout-list_swap'),
   ('workout-list_default', '<button class="btn big filled block"><span class="i">flag</span>', 'summary_update-prompt'),
   ('workout-list_default', BACK, 'player_resting'),
   ('workout-list_swap', '<div class="ex-row">', 'workout-list_default'),
   ('workout-list_swap', '<div class="scrim-over">', 'workout-list_default'),
   ('player_trophy', '<button class="btn big filled"', 'player_resting'),
   ('player_paused', '<button class="btn big filled"', 'player_reps'),
   ('summary_update-prompt', '<button class="btn filled">Update', 'summary_default'),
   ('summary_update-prompt', '<button class="btn text">No, keep it', 'summary_default'),
   ('summary_default', '<button class="btn big filled block"><span class="i">check</span>Done', 'today_after-workout')],
 'screens-program.html': [
   ('program_default', '<div class="entry">', 'catalogue_default'),
   ('program_default', '<div class="body"><div class="title">Pull A', 'session-editor_default'),
   ('program_default', '<button class="iconbtn"><span class="i">play_circle</span>', 'preview_default', 1),
   ('session-editor_default', BACK, 'program_default'),
   ('catalogue_default', BACK, 'program_default'),
   ('catalogue_default', '<div class="ex-row">', 'exercise-detail_default'),
   ('exercise-detail_default', BACK, 'catalogue_default'),
   ('exercise-detail_default', '<button class="iconbtn"><span class="i">edit</span>', 'exercise-edit_default'),
   ('exercise-detail_default', '<div class="link-card">', 'exercise-progress_default'),
   ('exercise-edit_default', '<button class="iconbtn"><span class="i">close</span>', 'exercise-detail_default'),
   ('exercise-edit_default', '<button class="btn text" style="font-size:16px">Save', 'exercise-detail_default')],
 'screens-progress.html': [
   ('progress_calendar', '<span class="">Exercises', 'progress_exercises'), ('progress_calendar', '<span class="">History', 'progress_history'),
   ('progress_exercises', '<span class="">Calendar', 'progress_calendar'), ('progress_exercises', '<span class="">History', 'progress_history'),
   ('progress_exercises', '<div class="ex-row"', 'exercise-progress_default'),
   ('progress_history', '<span class="">Calendar', 'progress_calendar'), ('progress_history', '<span class="">Exercises', 'progress_exercises'),
   ('progress_history', '<div class="hist">', 'workout-detail_default'),
   ('exercise-progress_default', BACK, 'progress_exercises'),
   ('exercise-progress_default', '<button class="iconbtn"><span class="i">info</span>', 'exercise-detail_default'),
   ('workout-detail_default', BACK, 'progress_history')],
 'screens-profile.html': [
   ('profile_default', '<button class="iconbtn"><span class="i">settings</span>', 'settings_default'),
   ('profile_default', '<div class="bw-card">', 'bodyweight_default'),
   ('bodyweight_default', BACK, 'profile_default'),
   ('settings_default', BACK, 'profile_default'),
   ('settings_default', '<div class="list-tile"><span class="lead"><span class="i">straighten</span>', 'load-units_default'),
   ('settings_default', '<div class="list-tile"><span class="lead"><span class="i">accessibility_new</span>', 'muscles_default'),
   ('load-units_default', BACK, 'settings_default'),
   ('muscles_default', BACK, 'settings_default')],
}
for f, items in spec.items():
    p = here / f
    s = navs(p.read_text())
    for it in items:
        s = tag(s, *it)
    p.write_text(s)
    print(f, s.count('data-go='))
