# Figma mirror: status

File: [My Bodybuilding Program](https://www.figma.com/design/ut2qBne1bdpEzGoDeNldNK/My-Bodybuilding-Program) (Starter plan). **Viewing only: app sessions read `design/`, never Figma.**

## What was written (design session, 2026-11-15)

| Page | Content | State |
|---|---|---|
| `Archive (legacy FR)` (0:1) | Old design, renamed only | untouched |
| `Foundations & Components` (1726:2) | Variable collection **Color** (72 vars: `light/*` and `dark/*` groups, because Starter allows 1 mode per collection), **Spacing** (8), **Radius** (6); 15 text styles `MBP/*`; native components bound to the variables: Button (4 styles × Default/Big), Filter chip (Off/On), PR chip, Streak chip, Badge · Next, Nav bar, Stat tile, Session card; "Components · Dark (instances)" showcase rebound to `dark/*` | done |
| | 5 frames `Sheet · …` sized for `screens/foundations.png` and `components_1..4.png` | **image fill missing** |
| `Screens & Prototype` (1726:3) | 64 frames 412×915 (`<screen> / light|dark`), 5 rows per theme, captions; 178 transparent hotspots with *On click → Navigate (dissolve 200 ms)* reactions (self-links skipped); flow starting points: Main flow (light), Main flow (dark), Progress → Exercise progress, Profile → Settings → Load units, First launch | **image fills missing** (frames show a plain background) |

## What is left (needs a few `use_figma` calls, i.e. MCP quota)

The Starter plan's MCP call limit was reached right after the PNGs were uploaded with `upload_assets`. The upload API answered 200 for all 69 files, but the images were not attached to their target frames. Next time quota is available:

1. Try setting each frame's fill to `{ type: 'IMAGE', imageHash, scaleMode: 'FILL' }` with the hashes below (the hash is the SHA-1 of the PNG; the blobs were uploaded). If Figma does not know the hash, re-run `upload_assets` with `nodeIds` (needs `mcp.figma.com` in the environment's allowed hosts, now added to the `my-bodybuilding-program` environment) and check the fill afterwards.
2. That is all: structure, variables, components and prototype links are in place.

| Node | PNG (`design/screens/`) | SHA-1 / imageHash |
|---|---|---|
| `1730:228` | `today_normal_light.png` | `c278d9e81304ed9430ad031ad430aa0f487582eb` |
| `1730:230` | `today_after-workout_light.png` | `7a7e47c7b08e7f57cb697c84c9edfbdb9aee5ccd` |
| `1730:232` | `today_in-progress_light.png` | `47e39aeda40e058d6a71dd028fd8f7e5714ee783` |
| `1730:234` | `today_empty_light.png` | `0310d16c1217eba77bc9d5e5c626261c6c69a535` |
| `1730:236` | `today_pick-session_light.png` | `959d0e7d246b94aa5fe3cc31f5d90aa70765293f` |
| `1730:239` | `preview_default_light.png` | `2e810fbc640fd9b9246914cbe3b27bfebef17f4d` |
| `1730:241` | `player_reps_light.png` | `1af2a861481689a022e02ccf0eb299fc4b15859e` |
| `1730:243` | `player_resting_light.png` | `93bc8fbf41bb48f83aa64e8c0af89025c17cbcd2` |
| `1730:245` | `player_timed_light.png` | `040f2b95c1d25b92256220db813edabc844f0ea2` |
| `1730:247` | `player_trophy_light.png` | `ac1b6de7c4ffe066a4e0aa6e6c2e8c6bfec57a6c` |
| `1730:249` | `player_paused_light.png` | `71562d03e154228212cbc1720470c72b1c1d9c2d` |
| `1730:251` | `workout-list_default_light.png` | `3b7026ffeda14d61df351859111fe660df92c304` |
| `1730:253` | `workout-list_swap_light.png` | `d60bfaf7ac8f5d4dd0064ccb968142f3af8f392b` |
| `1730:255` | `summary_update-prompt_light.png` | `efcefb7fded7e27ce0ffd7ad69b43d872a5284e9` |
| `1730:257` | `summary_default_light.png` | `da8671d4e346d3e7362926a02959cf5f58819d20` |
| `1730:260` | `program_default_light.png` | `b67741898016ff13c2491c732b95efbbded2a42e` |
| `1730:262` | `session-editor_default_light.png` | `e1c384a8c80a040ae02d1fd18d926726a16f435d` |
| `1730:264` | `catalogue_default_light.png` | `d6bbad42e812a2b039b20ef36ac530d46e01f152` |
| `1730:266` | `exercise-detail_default_light.png` | `360a056c3414f33af297890b26b57ec9b9a257e3` |
| `1730:268` | `exercise-edit_default_light.png` | `64b694458732b2246de3164602d8b6e8c2181ce7` |
| `1730:271` | `progress_calendar_light.png` | `df6ff2cf4168a21a396dd6906a49be544f09be87` |
| `1730:273` | `progress_exercises_light.png` | `e1c1e18d48ad2fe319c64103cfbf7f43898efb63` |
| `1730:275` | `progress_history_light.png` | `fcd7f5c844bc24e5245d58cbbe9966c6aabfbf01` |
| `1730:277` | `exercise-progress_default_light.png` | `dd2c99c87535ba00a1959051f80997e96bad7585` |
| `1730:279` | `workout-detail_default_light.png` | `32c15baab8055444427f1d8883a4c4a428af3948` |
| `1730:282` | `profile_default_light.png` | `1f4b34a172f01dc15d8691c7eae2d65bdee73e9e` |
| `1730:284` | `bodyweight_default_light.png` | `e61aa2fb5340515cacc4ee20fb9485f27ab94f3f` |
| `1730:286` | `settings_default_light.png` | `0c87a10e0fc868b294cf2114954b67f8518d6b3c` |
| `1730:288` | `load-units_default_light.png` | `74a403790ad20e473e79c1732694d6774af5a346` |
| `1730:290` | `muscles_default_light.png` | `5c29fbfacfea01de8a8ad0a8ca613a0d57d88e63` |
| `1730:292` | `settings_cloud-signed-out_light.png` | `e086df1ab0143daecdc65604ce99ed0ba34da18b` |
| `1730:294` | `settings_cloud-signed-in_light.png` | `07f2ad7ae9cf1230b163e672a8dc91b02d9e7a8f` |
| `1730:298` | `today_normal_dark.png` | `d902080745df8046515550fc8bdd00075a34ab5f` |
| `1730:300` | `today_after-workout_dark.png` | `1e718c0d0a0d16877e6a9502b6898430d87cf294` |
| `1730:302` | `today_in-progress_dark.png` | `b3fd14271e22c6308e86722f83ed302375e3c31f` |
| `1730:304` | `today_empty_dark.png` | `abfbf686f7b88eed74f7ec44bc676f3ceecebba5` |
| `1730:306` | `today_pick-session_dark.png` | `bed1b416b6c73f5f066bfddd180a4635a4eab992` |
| `1730:309` | `preview_default_dark.png` | `ab919a73568853672738591e56f6418904e95b3b` |
| `1730:311` | `player_reps_dark.png` | `c48f55877d3497864d6693feec509efd8ce9aec9` |
| `1730:313` | `player_resting_dark.png` | `a0275e3295cb5185586ead9c8a267557568f927c` |
| `1730:315` | `player_timed_dark.png` | `974ef2da23f744bdd46fba61ff96efca974df6f6` |
| `1730:317` | `player_trophy_dark.png` | `3d60db3e9e5091e49ac3b1b25f10bd595c8a713f` |
| `1730:319` | `player_paused_dark.png` | `f76917b72138197b025571f3f5624595b884bd16` |
| `1730:321` | `workout-list_default_dark.png` | `c6e6cc8a48e83dd7d4d7639faf5eff0711a535f5` |
| `1730:323` | `workout-list_swap_dark.png` | `250534b233aa2892d4ca668d026798185c550c8a` |
| `1730:325` | `summary_update-prompt_dark.png` | `bec9730898c74b8f3422d237283f1a7ec5550d14` |
| `1730:327` | `summary_default_dark.png` | `0ff66fcb626d10aac529955e5008278bd2b96c68` |
| `1730:330` | `program_default_dark.png` | `cf7b93adaa47afaae5591bc1a29b3fb283e6da2e` |
| `1730:332` | `session-editor_default_dark.png` | `379139e68e8ada921782c831788cd4e8d6ea6ffa` |
| `1730:334` | `catalogue_default_dark.png` | `4d75943aac1e9e65589ea3f630ea21d4426e3d59` |
| `1730:336` | `exercise-detail_default_dark.png` | `325a7c3f6a57752590a96e7c14f7fe3b6947f831` |
| `1730:338` | `exercise-edit_default_dark.png` | `d925f76ec9686772da99db3e003fc77766836595` |
| `1730:341` | `progress_calendar_dark.png` | `21fb930d862f51c13c553f9036283ddd766bd653` |
| `1730:343` | `progress_exercises_dark.png` | `57650643b5bf8513fdedc48c7a74bf0862b179aa` |
| `1730:345` | `progress_history_dark.png` | `69b58e889b853a3325ad93cbfb421657d0754bf6` |
| `1730:347` | `exercise-progress_default_dark.png` | `10d3fe3896c26a863e17366f303f37c19bf96261` |
| `1730:349` | `workout-detail_default_dark.png` | `3192c218fa82284fcb9fa53b0f8499f73d6504b3` |
| `1730:352` | `profile_default_dark.png` | `96d92ab507e3b8f6ea6805deb625a621f9c652a1` |
| `1730:354` | `bodyweight_default_dark.png` | `863fff7f99abcd090a59c211ad3f8101a4b21ae8` |
| `1730:356` | `settings_default_dark.png` | `ac77d7b9b45afe2a0d70c47a2f5c0e34525b70b3` |
| `1730:358` | `load-units_default_dark.png` | `d66a922e02efd7fd20841b00197711f2051d55b4` |
| `1730:360` | `muscles_default_dark.png` | `252c6c99f85607187d8f0848f34561aeee56bc42` |
| `1730:362` | `settings_cloud-signed-out_dark.png` | `2c1c7cc2907b0f476fb7947fa57cc8b76d26ee3a` |
| `1730:364` | `settings_cloud-signed-in_dark.png` | `bbaf61dacdaeefe2e9b6de671ff1c723bf3da04e` |
| `1730:221` | `foundations.png` | `f288c1bab8d2b2c025824fb31d7fdc2af4c88195` |
| `1730:222` | `components_1.png` | `85732d00b976634563825e36007991f3acd59893` |
| `1730:223` | `components_2.png` | `e1c72be38c25d90b341692f43071f2c2ab1c8032` |
| `1730:224` | `components_3.png` | `196991107aac571032e21c13b6c0a82dbc0dad51` |
| `1730:225` | `components_4.png` | `fc76c36271af656d22745413540f221882bcd033` |
