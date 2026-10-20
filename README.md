# [manacode] VuhDo KickFix

Fix for **VuhDo 2.22** on WoW 3.3.5a: raid frames freeze or break when someone is kicked or leaves the group during combat, and stay broken until `/reload`.

**Install:** download the zip from [Releases](../../releases), extract the `VuhDo_KickFix` folder into `Interface\AddOns` next to `VuhDo`, restart the game. VuhDo files are not modified.

**How it works:** in combat VuhDo sets an internal "reloading" flag, refreshes the roster and then clears the flag. If the refresh hits a Lua error on the player who just left, the flag is never cleared and every later update is postponed forever. The patch runs the refresh steps in protected mode, shows the slot freed by the renumbering as an empty "left" bar (so nobody is shown twice), and resets the flag if it ever gets stuck. Caught errors are printed once in chat as `VuhDo KickFix: ...` — please send them in [Issues](../../issues).

---

Фикс для **VuhDo 2.22** на WoW 3.3.5a: если в бою кикнуть игрока или он сам выйдет из группы, рейдовые рамки зависают или ломаются до `/reload`.

**Установка:** скачайте архив из [Releases](../../releases), распакуйте папку `VuhDo_KickFix` в `Interface\AddOns` рядом с `VuhDo` и перезапустите игру. Файлы VuhDo не меняются.

**Как работает:** в бою VuhDo ставит внутренний флаг «идёт перезагрузка», обновляет состав и снимает флаг. Если на вышедшем игроке случается Lua-ошибка, флаг не снимается, и все дальнейшие обновления откладываются навсегда. Патч выполняет обновление в защищённом режиме, показывает освободившийся после перенумерации слот пустой полосой «вышел» (никто не дублируется) и сбрасывает флаг, если тот завис. Пойманные ошибки один раз пишутся в чат как `VuhDo KickFix: ...` — присылайте их в [Issues](../../issues).
