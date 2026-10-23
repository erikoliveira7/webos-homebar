import QtQuick 2.6
import QtGraphicalEffects 1.0
import WebOSServices 1.0
import WebOS.Global 1.0
import "Config.js" as Config
import "Strings.js" as Strings
import "Themes.js" as Themes

FocusScope {
    id: shell
    property var hostWindow
    property bool ready: false
    property bool foreground: false
    property string page: "home"
    property int selected: 0
    property bool launching: false
    property bool pressing: false
    property string message: ""
    property var applications: Config.apps
    // Favourites are app ids; edited on the TV (hold OK) and saved by FavouriteStore.qml.
    property var favouriteIds: Config.favourites.slice(0)
    readonly property var favourites: resolveFavourites(favouriteIds, applications)
    readonly property var favouriteKeys: favourites.map(function(f) { return f.id; })
    readonly property int favCount: favourites.length
    // Rail places for favourites: one "Add favourites" tile while there are
    // none, but only once the app list is known (not while it is still loading).
    readonly property bool showAddTile: favCount === 0 && applications.length > 0
    readonly property int favSlots: favCount > 0 ? favCount : (showAddTile ? 1 : 0)
    readonly property int maxFavourites: 7
    property int editIndex: -1
    property string notice: ""
    property bool okHeld: false
    property bool longFired: false
    property var inputs: Config.inputs
    property string clock: ""
    property string nowTitle: ""
    // Launcher settings, saved with the favourites (key "settings").
    // lang: "system" or a code from Strings.languages; exitTo (webOS 10 only,
    // sent to the helper): "last" or an HDMI input app id; clock: the top bar;
    // title: the big name of the focused app on Home and Apps.
    // beta: updates also offer test builds (GitHub pre-releases).
    // theme: an id from Themes.ids.
    property var settings: ({lang: "system", theme: "default", exitTo: "last", clock: true, title: true, beta: false})
    property string systemLang: ""
    // The updater (Launcher settings → Updates): idle, checking, current,
    // available, downloading, ready, installing, done or failed; latest is the
    // version found, failed the text key of the failed step.
    property var updateInfo: ({state: "idle", latest: "", failed: ""})
    readonly property string lang: settings.lang && settings.lang !== "system" ? settings.lang : (Strings.supported(systemLang) || "en")
    // LG's own Home can be opened: always on webOS 4 (the panel lives in it); on
    // webOS 10 only when it was kept (the helper says so, see panel-bridge.qml).
    property bool stockHomeAvailable: Config.stockHome !== false
    readonly property var tools: toolsFor(lang, applications, stockHomeAvailable)
    readonly property var settingsItems: settingsFor(lang, settings, systemLang, updateInfo)
    // In place of the favourites while there are none: OK opens Apps.
    readonly property var addFavouritesTile: ({title: t("add_favs_title"), action: "apps", symbol: "add"})
    signal stockRequested()
    signal closeRequested()
    signal exitTargetChosen(string target)

    // Spotlight B2: the focused item is named above a rail of rounded tiles,
    // its colour lights the bottom-left edge, the picture stays visible.
    // Colours come from the theme (Launcher settings → Theme, see Themes.js).
    readonly property var theme: Themes.palette(settings.theme)
    readonly property string ink: theme.ink
    readonly property string ink2: theme.ink2
    readonly property string ink3: theme.ink3
    readonly property string surface: theme.surface   // chips over the picture (status)
    readonly property string chip: theme.chip         // tiles and pills: solid, so nothing shows through
    readonly property string chipEdge: theme.chipEdge
    readonly property string neutral: theme.neutral
    readonly property string warning: theme.warning
    readonly property string fontName: inter.status === FontLoader.Ready ? inter.name : medium.name
    readonly property int margin: 96
    readonly property int tile: 120
    readonly property int gap: 24
    readonly property int appColumns: 12
    readonly property int railY: 888
    // The name sits just above the tiles; a line under it (a setting's value,
    // editing help, a message) lifts it by one line.
    // Without the name (setting "title", Home and Apps only) a line under it
    // still shows, just above the tiles.
    readonly property bool showTitle: settings.title !== false || page === "system" || page === "settings"
    readonly property int heroBaseline: (page === "apps" ? 700 : 842) - (showTitle ? (hero.sub ? 36 : 0) : 20)
    readonly property var hero: heroFor(page, selected, applications, favourites, editIndex, launching, message, notice, settingsItems, tools)
    readonly property var hints: hintsFor(page, selected, favouriteKeys, editIndex, lang, updateInfo)
    property color glowColor: hero.color
    Behavior on glowColor { ColorAnimation { duration: 300 } }

    function closeHome() { closeRequested(); }

    FontLoader { id: inter; source: "file:///var/lib/webosbrew/rawin-launcher/current/fonts/Inter-Regular.ttf" }
    FontLoader { id: interBold; source: "file:///var/lib/webosbrew/rawin-launcher/current/fonts/Inter-Bold.ttf" }
    FontLoader { id: medium; source: "file:///usr/share/fonts/MuseoSans-Medium.ttf" }

    function t(key) { return Strings.get(lang, key); }
    function installed(id, apps) {
        for (var i=0; i<apps.length; i++) if (apps[i].id === id) return true;
        return false;
    }
    function toolsFor(language, apps, stockHome) {
        var list = [
            {title: t("tv_settings"), id: "com.palm.app.settings", symbol: "settings"},
            {title: t("launcher_settings"), action: "launcherSettings", symbol: "tune"},
            {title: "PicCap", id: "org.webosbrew.piccap", symbol: "light", optional: true},
            {title: "Homebrew Channel", id: "org.webosbrew.hbchannel", symbol: "plus"},
            {title: "LG Content Store", id: "com.webos.app.discovery", symbol: "bag"},
            {title: t("stock_home"), action: "stock", symbol: "home", stock: true},
            {title: t("back_to_picture"), action: "close", symbol: "back"}
        ];
        // PicCap only where it is installed; LG's Home only where it is reachable.
        return list.filter(function(x) {
            return !(x.optional && !installed(x.id, apps)) && !(x.stock && !stockHome);
        });
    }
    function settingsFor(language, s, sysLang, upd) {
        var langValue = s.lang === "system"
            ? Strings.format(t("val_system"), {lang: Strings.names[Strings.supported(sysLang) || "en"]})
            : Strings.names[s.lang];
        var list = [{key: "lang", title: t("set_language"), value: langValue, symbol: "language", action: "setting"}];
        list.push({key: "theme", title: t("set_theme"), value: t("theme_" + s.theme), symbol: "theme", action: "setting"});
        if (Config.exitTarget)
            list.push({key: "exitTo", title: t("set_exit"), symbol: "exit", action: "setting",
                       value: s.exitTo === "last" ? t("val_last_input") : "HDMI " + s.exitTo.slice(-1)});
        list.push({key: "clock", title: t("set_clock"), value: s.clock ? t("val_show") : t("val_hide"), symbol: "clock", action: "setting"});
        list.push({key: "title", title: t("set_title"), value: s.title ? t("val_name_show") : t("val_name_hide"), symbol: "title", action: "setting"});
        list.push({key: "update", title: t("set_update"), value: updateText(upd), symbol: "update", action: "update"});
        list.push({key: "beta", title: t("set_beta"), value: s.beta ? t("val_on") : t("val_off"), symbol: "flask", action: "setting"});
        return list;
    }
    function updateText(u) {
        var v = {version: u.latest};
        if (u.state === "checking") return t("upd_checking");
        if (u.state === "current") return Strings.format(t("upd_current"), {version: Config.version});
        if (u.state === "available") return Strings.format(t("upd_available"), v);
        if (u.state === "downloading") return Strings.format(t("upd_downloading"), v);
        if (u.state === "ready") return Strings.format(t("upd_ready"), v);
        if (u.state === "installing") return Strings.format(t("upd_installing"), v);
        if (u.state === "done") return t("upd_done");
        if (u.state === "failed") return t(u.failed);
        return Strings.format(t("upd_idle"), {version: Config.version});
    }
    // OK on Updates: check, download what was found, install what was downloaded.
    function updateAction() {
        var s = updateInfo.state;
        if (s === "available") updateStep("download");
        else if (s === "ready") updateStep("install");
        else if (s === "idle" || s === "current" || s === "failed") updateStep("check");
    }
    function isUpdateIdle() {
        return ["checking", "downloading", "installing", "done"].indexOf(updateInfo.state) < 0;
    }
    function updateStep(step) {
        var busy = {check: "checking", download: "downloading", install: "installing"}[step];
        if (busy) setUpdate({state: busy});
        updateRun(step, settings.beta ? "test" : "stable");
    }
    function setUpdate(change) {
        var next = {}, k;
        for (k in updateInfo) next[k] = updateInfo[k];
        for (k in change) next[k] = change[k];
        updateInfo = next;
    }
    // The answer of one update.sh step (null: no answer).
    function updateResult(step, r) {
        var ok = !!(r && r.ok);
        if (step === "check") setUpdate(ok ? {state: r.newer ? "available" : "current", latest: r.latest} : {state: "failed", failed: "upd_err_check"});
        else if (step === "download") setUpdate(ok ? {state: "ready"} : {state: "failed", failed: "upd_err_download"});
        else if (step === "install") {
            if (ok) installPoll.restart();
            else setUpdate({state: "failed", failed: "upd_err_install"});
        } else if (step === "status" && ok) {
            // On success the installer restarts the launcher, which ends this
            // panel; "done" shows only if it is still here.
            if (r.state === "failed") { installPoll.stop(); setUpdate({state: "failed", failed: "upd_err_install"}); }
            else if (r.state === "done") { installPoll.stop(); setUpdate({state: "done"}); }
        }
    }
    Timer { id: installPoll; interval: 2000; repeat: true; onTriggered: updateRun("status", "stable") }
    function cycleSetting(key) {
        var next = {lang: settings.lang, theme: settings.theme, exitTo: settings.exitTo, clock: settings.clock, title: settings.title, beta: settings.beta};
        if (key === "lang") {
            var langs = ["system"].concat(Strings.languages);
            next.lang = langs[(langs.indexOf(settings.lang) + 1) % langs.length];
        } else if (key === "theme") {
            next.theme = Themes.ids[(Themes.ids.indexOf(settings.theme) + 1) % Themes.ids.length];
        } else if (key === "exitTo") {
            var targets = ["last", "com.webos.app.hdmi1", "com.webos.app.hdmi2", "com.webos.app.hdmi3", "com.webos.app.hdmi4"];
            next.exitTo = targets[(targets.indexOf(settings.exitTo) + 1) % targets.length];
        } else if (key === "clock") next.clock = !settings.clock;
        else if (key === "title") next.title = !settings.title;
        else if (key === "beta") next.beta = !settings.beta;
        settings = next;
        saveSettings();
        if (key === "exitTo") exitTargetChosen(next.exitTo);
        if (key === "beta" && isUpdateIdle()) updateStep("check");
    }
    function saveSettings() {
        try { if (store.item) store.item.save(settings, "settings"); } catch (e) {}
    }
    function loadSettings() {
        try {
            var s = store.item.load("settings");
            if (s && typeof s === "object") settings = {
                lang: s.lang === "system" || Strings.languages.indexOf(s.lang) >= 0 ? s.lang : "system",
                theme: Themes.ids.indexOf(s.theme) >= 0 ? s.theme : "default",
                exitTo: /^(last|com\.webos\.app\.hdmi[1-4])$/.test(s.exitTo) ? s.exitTo : "last",
                clock: s.clock !== false,
                title: s.title !== false,
                beta: s.beta === true
            };
        } catch (e) {}
        if (Config.exitTarget) exitTargetChosen(settings.exitTo);
    }
    function styleFor(id) {
        var s = Config.styles ? Config.styles[id] : null;
        return {accent: s && s.accent ? s.accent : neutral};
    }
    // Installed apps only, in the saved order; an uninstalled favourite simply disappears.
    function resolveFavourites(ids, apps) {
        var out = [];
        for (var i=0; i<ids.length && out.length < maxFavourites; i++) {
            for (var j=0; j<apps.length; j++) {
                if (apps[j].id !== ids[i]) continue;
                var st = styleFor(ids[i]);
                out.push({id: apps[j].id, title: apps[j].title, icon: apps[j].icon, accent: st.accent});
                break;
            }
        }
        return out;
    }
    function heroFor(currentPage, index, apps, favs, editing, busy, error, note, settingsList, toolList) {
        var h, n = favs.length;
        if (currentPage === "apps") {
            var app = apps[index] || {title: ""};
            var st = styleFor(app.id);
            h = {title: app.title, sub: "", color: st.accent};
        } else if (currentPage === "system") {
            var tool = tools[index] || {title: ""};
            h = {title: tool.title, sub: "", color: neutral};
        } else if (currentPage === "settings") {
            var item = settingsItems[index] || {title: "", value: ""};
            h = {title: item.title, sub: item.value, color: neutral};
        } else if (showAddTile && index === 0) {
            h = {title: t("add_favs_title"), sub: t("add_favs_sub"), color: neutral};
        } else if (index < n) {
            var f = favs[index];
            h = editing >= 0
                ? {title: f.title, sub: t("edit_sub"), color: f.accent}
                : {title: f.title, sub: "", color: f.accent};
        } else if (index < favSlots+4) {
            var input = inputs[index-favSlots];
            h = {title: input.title, sub: "", color: neutral};
        } else if (index === favSlots+4) {
            h = {title: t("apps_title"), sub: "", color: neutral};
        } else {
            h = {title: t("system_title"), sub: "", color: neutral};
        }
        if (error) h.sub = error;
        else if (busy) h.sub = t("opening");
        else if (note) h.sub = note;
        return h;
    }
    function hintsFor(currentPage, index, keys, editing, language, upd) {
        if (currentPage === "apps") {
            var app = applications[index];
            var fav = app && keys.indexOf(app.id) >= 0;
            return [["OK", t("hint_open")], [t("hint_hold_ok"), fav ? t("hint_remove_fav") : t("hint_add_fav")], [t("hint_back"), t("hint_favourites")]];
        }
        if (currentPage === "system") return [["OK", t("hint_open")], [t("hint_back"), t("hint_favourites")]];
        if (currentPage === "settings") {
            var item = settingsItems[index];
            if (item && item.action === "update") {
                var verb = upd.state === "available" ? "hint_download" : upd.state === "ready" ? "hint_install"
                    : ["idle", "current", "failed"].indexOf(upd.state) >= 0 ? "hint_check" : "";
                return verb ? [["OK", t(verb)], [t("hint_back"), t("hint_system")]] : [[t("hint_back"), t("hint_system")]];
            }
            return [["OK", t("hint_change")], [t("hint_back"), t("hint_system")]];
        }
        if (editing >= 0) return [["OK", t("hint_done")]];
        if (index < keys.length) return [["OK", t("hint_open")], [t("hint_hold_ok"), t("hint_edit_favs")]];
        return [["OK", t("hint_open")]];
    }

    function saveFavourites() {
        if (!store.item) { message = t("err_store_unavailable"); return; }
        try { store.item.save(favouriteIds, "favourites"); }
        catch (e) { message = t("err_save"); }
    }
    // The list saved on the TV wins over the build's defaults. With nothing
    // saved yet, the build's preset becomes the TV's own list at once, so a
    // later version with other defaults (an update) never changes it.
    function loadFavourites() {
        try {
            var ids = store.item.load("favourites");
            if (ids && ids.length !== undefined) favouriteIds = ids;
            else if (favouriteIds.length) store.item.save(favouriteIds, "favourites");
        } catch (e) {}
    }
    function setFavourites(ids) { favouriteIds = ids; saveFavourites(); }
    function toggleFavourite(app) {
        var ids = favouriteKeys.slice(0), at = ids.indexOf(app.id);
        if (at >= 0) { ids.splice(at, 1); notice = t("removed_fav"); }
        else if (ids.length >= maxFavourites) { notice = Strings.format(t("max_favs"), {n: maxFavourites}); return; }
        else { ids.push(app.id); notice = t("added_fav"); }
        setFavourites(ids);
    }
    function moveFavourite(from, to) {
        var ids = favouriteKeys.slice(0), id = ids[from];
        ids[from] = ids[to]; ids[to] = id;
        setFavourites(ids);
        editIndex = to; selected = to;
    }
    function removeFavourite(index) {
        var ids = favouriteKeys.slice(0);
        ids.splice(index, 1);
        editIndex = -1;
        setFavourites(ids);
        selected = Math.max(0, Math.min(index, ids.length-1));
        notice = t("removed_fav");
    }
    // Hold OK (or the yellow key): edit a favourite on Home, toggle one in All applications.
    function secondaryAction() {
        if (!ready || launching) return;
        if (page === "apps") { if (applications[selected]) toggleFavourite(applications[selected]); }
        else if (page === "home" && selected < favCount) { editIndex = editIndex === selected ? -1 : selected; notice = ""; }
    }
    // HDMI inputs from eim getAllInputStatus: the device under each is its
    // HDMI-CEC name (subList SIMPLINK osdName), else the input's own label when
    // it is not just "HDMI n" (e.g. a name set on the TV), else nothing.
    function inputsFrom(devices) {
        var next = [];
        for (var i=0; i<devices.length; i++) {
            var d = devices[i];
            if (!d.appId || d.appId.indexOf("com.webos.app.hdmi") !== 0) continue;
            var name = "", subs = d.subList || [];
            for (var j=0; j<subs.length; j++) if (subs[j].id === "SIMPLINK" && subs[j].osdName) { name = subs[j].osdName; break; }
            if (!name && d.label && d.label !== "HDMI " + d.port) name = d.label;
            // Something is plugged in: the TV says so (webOS 4: hdmiPlugIn,
            // webOS 10: activate) or a device answers over HDMI-CEC.
            var present = !!(d.hdmiPlugIn || d.activate || subs.some(function(s) { return s.id === "SIMPLINK" && s.osdName; }));
            next.push({id: d.appId, title: "HDMI " + d.port, detail: name, present: present});
        }
        return next;
    }
    function describe(appId) {
        if (!appId || appId === "com.webos.app.home") return false;
        for (var i=0; i<inputs.length; i++) if (inputs[i].id === appId) { nowTitle = inputs[i].title; return true; }
        for (var j=0; j<applications.length; j++) if (applications[j].id === appId) { nowTitle = applications[j].title; return true; }
        nowTitle = appId === "com.webos.app.livetv" ? t("live_tv") : appId;
        return true;
    }
    function activate(item) {
        if (!ready || launching || !item) return;
        message = "";
        if (item.action === "stock") { stockRequested(); return; }
        if (item.action === "close") { closeHome(); return; }
        if (item.action === "setting") { cycleSetting(item.key); return; }
        if (item.action === "update") { updateAction(); return; }
        if (item.action === "launcherSettings") {
            page = "settings"; selected = 0;
            // Look for a new version each time the settings open, unless one is already found.
            var s = updateInfo.state;
            if (s === "idle" || s === "current" || s === "failed") updateStep("check");
            return;
        }
        if (item.action === "apps" || item.action === "system") {
            page = item.action; selected = 0; return;
        }
        launching = true;
        launchTimeout.restart();
        launchService.callService({id: item.id, params: {}, reason: "launcher"});
    }
    function itemAt(index) {
        if (page === "apps") return applications[index];
        if (page === "system") return tools[index];
        if (page === "settings") return settingsItems[index];
        if (showAddTile && index === 0) return addFavouritesTile;
        if (index < favCount) return favourites[index];
        if (index < favSlots+4) return inputs[index-favSlots];
        return index === favSlots+4 ? {title: t("apps_title"), action: "apps", symbol: "apps"} : {title: t("system_title"), action: "system", symbol: "settings"};
    }
    // Home and System are one rail; All applications is a twelve-column grid.
    function isOk(key) { return key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Select; }
    function isBack(key) { return key === WebOS.Key_webOS_Back || key === Qt.Key_Escape || key === Qt.Key_Back || key === Qt.Key_Backspace || key === 461; }
    function isYellow(key) { return key === WebOS.Key_webOS_Yellow || key === 405; }
    function navigate(key) {
        notice = "";
        // Editing a favourite: arrows move it, DOWN removes it, OK/BACK/UP finish.
        if (page === "home" && editIndex >= 0) {
            if (key === Qt.Key_Left) { if (editIndex > 0) moveFavourite(editIndex, editIndex-1); }
            else if (key === Qt.Key_Right) { if (editIndex < favCount-1) moveFavourite(editIndex, editIndex+1); }
            else if (key === Qt.Key_Down) removeFavourite(editIndex);
            else if (isOk(key) || isBack(key) || key === Qt.Key_Up) editIndex = -1;
            else return false;
            return true;
        }
        var count = page === "home" ? favSlots+6 : page === "apps" ? applications.length : page === "settings" ? settingsItems.length : tools.length;
        var columns = page === "apps" ? appColumns : count;
        if (key === Qt.Key_Left) { if (selected % columns > 0) selected--; }
        else if (key === Qt.Key_Right) { if (selected % columns < columns-1 && selected+1 < count) selected++; }
        else if (key === Qt.Key_Up) { if (selected-columns >= 0) selected -= columns; }
        else if (key === Qt.Key_Down) {
            if (selected+columns < count) selected += columns;
            else if (Math.floor(selected/columns) < Math.floor((count-1)/columns)) selected = count-1;
        } else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Select) activate(itemAt(selected));
        else if (key === WebOS.Key_webOS_Back || key === Qt.Key_Escape || key === Qt.Key_Back || key === Qt.Key_Backspace || key === 461) {
            if (page === "home") closeHome();
            else if (page === "settings") { page = "system"; selected = toolIndex("launcherSettings"); }
            else { selected = favSlots + (page === "apps" ? 4 : 5); page = "home"; }
        } else return false;
        return true;
    }
    function toolIndex(action) {
        for (var i=0; i<tools.length; i++) if (tools[i].action === action) return i;
        return 0;
    }
    function actionKey(key) {
        return key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Select || key === WebOS.Key_webOS_Back || key === Qt.Key_Escape || key === Qt.Key_Back || key === Qt.Key_Backspace || key === 461;
    }
    // Activate on release: switching focus on press would deliver the same
    // OK release to LG's ribbon and accidentally launch a second application.
    // Holding OK past holdTimer runs secondaryAction instead of activating.
    Keys.onPressed: {
        if (isYellow(event.key)) { event.accepted=true; return; }
        if (actionKey(event.key)) {
            event.accepted=true;
            if (isOk(event.key) && !event.isAutoRepeat && !okHeld) {
                okHeld=true; longFired=false; pressing=true; holdTimer.restart();
            }
        }
        else if (navigate(event.key)) event.accepted=true;
    }
    Keys.onReleased: {
        if (isYellow(event.key)) { event.accepted=true; if (!event.isAutoRepeat) secondaryAction(); return; }
        if (!actionKey(event.key)) return;
        event.accepted=true;
        if (event.isAutoRepeat) return;
        if (isOk(event.key)) {
            okHeld=false; holdTimer.stop(); pressing=false;
            if (longFired) { longFired=false; return; }
        }
        navigate(event.key);
    }
    Timer { id: holdTimer; interval: 700; onTriggered: { if (okHeld) { longFired=true; pressing=false; secondaryAction(); } } }
    Loader { id: store; source: "FavouriteStore.qml"; onLoaded: { shell.loadFavourites(); shell.loadSettings(); } }
    onForegroundChanged: {
        pressing = false; okHeld = false; longFired = false; holdTimer.stop();
        editIndex = -1; notice = "";
        if (foreground) {
            launching = false; message = ""; page="home"; selected=0; forceActiveFocus();
            clock = Qt.formatTime(new Date(), "hh:mm");
            if (ready) { catalog.callService({}); foregroundInfo.callService({extraInfo: true}); loadInputs(); }
        }
    }
    onReadyChanged: {
        if (!ready) return;
        localeService.callService({keys: ["localeInfo"]});
        catalog.callService({});
        loadInputs();
        if (foreground) foregroundInfo.callService({extraInfo: true});
    }
    onVisibleChanged: { if (visible && foreground) forceActiveFocus(); }
    Component.onCompleted: clock = Qt.formatTime(new Date(), "hh:mm")

    Service {
        id: launchService
        appId: "com.webos.app.home"
        service: "com.webos.applicationManager"
        method: "launch"
        onCallSuccess: {
            launching = false; launchTimeout.stop();
            if (hostWindow && hostWindow.interfaces.application) hostWindow.interfaces.application.hideApp();
        }
        onCallFailure: { launching = false; launchTimeout.stop(); message = t("err_launch"); }
        onError: { launching = false; launchTimeout.stop(); message = t("err_unavailable"); }
    }
    Service {
        id: catalog
        appId: "com.webos.app.home"
        service: "com.webos.applicationManager"
        method: "listLaunchPoints"
        onCallSuccess: {
            if (!response.launchPoints) return;
            var next = [], seen = {};
            for (var i=0; i<response.launchPoints.length; i++) {
                var entry=response.launchPoints[i];
                if (seen[entry.id] || Config.excluded.indexOf(entry.id)>=0) continue;
                seen[entry.id]=true;
                var icon = entry.largeIcon || entry.icon;
                next.push({id: entry.id, title: entry.title || entry.id, icon: icon ? "file://"+icon : ""});
            }
            applications=next;
            if (page === "apps") selected=Math.max(0, Math.min(selected, next.length-1));
        }
    }
    // What stays visible under the transparent top: the card behind Home.
    Service {
        id: foregroundInfo
        appId: "com.webos.app.home"
        service: "com.webos.applicationManager"
        method: "getForegroundAppInfo"
        onCallSuccess: {
            nowTitle = "";
            var list = response.foregroundAppInfo || [];
            for (var i=0; i<list.length; i++) if (describe(list[i].appId)) return;
            describe(response.appId);
        }
    }
    // The TV's language, used while the launcher language is "system".
    Service {
        id: localeService
        appId: "com.webos.app.home"
        service: "com.webos.settingsservice"
        method: "getSystemSettings"
        onCallSuccess: {
            var info = response.settings ? response.settings.localeInfo : null;
            if (info && info.locales && info.locales.UI) systemLang = info.locales.UI;
        }
    }
    // Inputs and the devices on them, read again each time Home opens.
    function loadInputs() { inputService.callService({}); }
    Service {
        id: inputService
        appId: "com.webos.app.home"
        service: "com.webos.service.eim"
        method: "getAllInputStatus"
        onCallSuccess: {
            var next = response.devices ? inputsFrom(response.devices) : [];
            if (next.length) inputs = next;
        }
    }
    // Updates: update.sh, run as root through the Homebrew Channel's exec.
    function updateRun(step, channel) {
        updateService.step = step;
        updateService.callService({command: "sh /var/lib/webosbrew/rawin-launcher/update.sh " + step + " " + channel});
    }
    Service {
        id: updateService
        property string step: ""
        appId: "com.webos.app.home"
        service: "org.webosbrew.hbchannel.service"
        method: "exec"
        onCallSuccess: {
            var r = null;
            try { r = JSON.parse(String(response.stdoutString || "").trim().split("\n").pop()); } catch (e) {}
            updateResult(step, r);
        }
        onCallFailure: updateResult(step, null)
        onError: updateResult(step, null)
    }
    Timer { id: launchTimeout; interval: 8000; onTriggered: { launching=false; message=t("err_slow"); } }
    Timer { interval: 30000; repeat: true; running: shell.foreground; onTriggered: clock = Qt.formatTime(new Date(), "hh:mm") }

    function drawGlyph(c, symbol) {
        c.beginPath();
        if (symbol === "settings") {
            c.moveTo(6,12); c.lineTo(23,12); c.moveTo(31,12); c.lineTo(34,12);
            c.moveTo(6,28); c.lineTo(9,28); c.moveTo(17,28); c.lineTo(34,28); c.stroke();
            c.beginPath(); c.arc(27,12,4,0,Math.PI*2); c.stroke();
            c.beginPath(); c.arc(13,28,4,0,Math.PI*2);
        } else if (symbol === "light") {
            c.roundedRect(9,11,22,16,3,3); c.moveTo(4,8); c.lineTo(4,32); c.moveTo(36,8); c.lineTo(36,32); c.moveTo(14,33); c.lineTo(26,33);
        } else if (symbol === "plus") {
            c.moveTo(8,14); c.lineTo(20,7); c.lineTo(32,14); c.lineTo(32,26); c.lineTo(20,33); c.lineTo(8,26); c.closePath();
            c.moveTo(20,15); c.lineTo(20,25); c.moveTo(15,20); c.lineTo(25,20);
        } else if (symbol === "bag") {
            c.moveTo(9,14); c.lineTo(31,14); c.lineTo(29,33); c.lineTo(11,33); c.closePath();
            c.moveTo(15,14); c.lineTo(15,12); c.arc(20,12,5,Math.PI,0,false); c.lineTo(25,14);
        } else if (symbol === "home") {
            c.moveTo(6,19); c.lineTo(20,8); c.lineTo(34,19); c.moveTo(10,16); c.lineTo(10,33); c.lineTo(30,33); c.lineTo(30,16);
            c.moveTo(17,33); c.lineTo(17,25); c.lineTo(23,25); c.lineTo(23,33);
        } else if (symbol === "back") {
            c.moveTo(16,10); c.lineTo(6,20); c.lineTo(16,30); c.moveTo(6,20); c.lineTo(34,20);
        } else if (symbol === "reset") {
            c.arc(20,21,12,-Math.PI*0.75,Math.PI*1.05,false);
            c.moveTo(5,11); c.lineTo(11.5,12.5); c.lineTo(12,6);
        } else if (symbol === "add") {
            c.moveTo(20,9); c.lineTo(20,31); c.moveTo(9,20); c.lineTo(31,20);
        } else if (symbol === "language") {
            c.arc(20,20,13,0,Math.PI*2); c.moveTo(7,20); c.lineTo(33,20);
            c.moveTo(20,7); c.bezierCurveTo(13,13,13,27,20,33); c.moveTo(20,7); c.bezierCurveTo(27,13,27,27,20,33);
        } else if (symbol === "exit") {
            c.roundedRect(6,9,28,19,3,3); c.moveTo(14,33); c.lineTo(26,33);
            c.moveTo(20,13); c.lineTo(20,23); c.moveTo(16,19); c.lineTo(20,23); c.lineTo(24,19);
        } else if (symbol === "title") {
            c.moveTo(9,10); c.lineTo(31,10); c.moveTo(20,10); c.lineTo(20,31);
        } else if (symbol === "clock") {
            c.arc(20,20,13,0,Math.PI*2); c.moveTo(20,12); c.lineTo(20,20); c.lineTo(26,23);
        } else if (symbol === "tune") {
            c.moveTo(10,6); c.lineTo(10,34); c.moveTo(20,6); c.lineTo(20,34); c.moveTo(30,6); c.lineTo(30,34); c.stroke();
            c.beginPath(); c.roundedRect(6,22,8,6,2,2); c.roundedRect(16,10,8,6,2,2); c.roundedRect(26,18,8,6,2,2);
            c.fillStyle = c.strokeStyle; c.fill();
        } else if (symbol === "update") {
            c.moveTo(20,7); c.lineTo(20,25); c.moveTo(13,18); c.lineTo(20,25); c.lineTo(27,18);
            c.moveTo(8,26); c.lineTo(8,33); c.lineTo(32,33); c.lineTo(32,26);
        } else if (symbol === "flask") {
            c.moveTo(15,7); c.lineTo(25,7); c.moveTo(17,7); c.lineTo(17,17); c.lineTo(8,32); c.lineTo(32,32); c.lineTo(23,17); c.lineTo(23,7);
            c.moveTo(12,25); c.lineTo(28,25);
        } else if (symbol === "theme") {
            c.arc(20,20,13,0,Math.PI*2); c.stroke();
            c.beginPath(); c.arc(20,20,13,-Math.PI/2,Math.PI/2,false); c.closePath();
            c.fillStyle = c.strokeStyle; c.fill();
        } else if (symbol === "apps") {
            c.roundedRect(7,7,11,11,3,3); c.roundedRect(22,7,11,11,3,3); c.roundedRect(7,22,11,11,3,3); c.roundedRect(22,22,11,11,3,3);
        }
        c.stroke();
    }

    // Transparent native HOME surface: keep the current card/video underneath.
    Item {
        id: panel
        anchors.fill: parent
        opacity: shell.foreground ? 1 : 0
        property real lift: shell.foreground ? 0 : 24
        transform: Translate { y: panel.lift }
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on lift { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // Shade only under the name and the rail, in the lower part of the
        // screen; the rest of the picture stays as it is.
        Rectangle {
            id: scrim
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: shell.page === "apps" ? 660 : 540
            property color tint: shell.theme.scrim
            function a(v) { return Qt.rgba(tint.r, tint.g, tint.b, v); }
            gradient: Gradient {
                GradientStop { position: 0.00; color: scrim.a(0) }
                GradientStop { position: 0.22; color: scrim.a(0.30) }
                GradientStop { position: 0.45; color: scrim.a(0.66) }
                GradientStop { position: 0.68; color: scrim.a(0.86) }
                GradientStop { position: 1.00; color: scrim.a(0.93) }
            }
        }
        RadialGradient {
            anchors.fill: parent
            horizontalOffset: -768; verticalOffset: 605
            horizontalRadius: 1200; verticalRadius: 520
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(shell.glowColor.r, shell.glowColor.g, shell.glowColor.b, 0.34) }
                GradientStop { position: 0.72; color: Qt.rgba(shell.glowColor.r, shell.glowColor.g, shell.glowColor.b, 0) }
            }
        }

        // Status: what is underneath, then the clock, on a chip like the input
        // pills, so it reads over any picture without shading the screen.
        Rectangle {
            id: status
            visible: shell.settings.clock !== false
            anchors.right: parent.right; anchors.rightMargin: shell.margin; y: 32
            width: statusRow.width + 48; height: 56; radius: 18
            color: shell.surface; border.width: 1; border.color: shell.theme.surfaceEdge
            Row {
                id: statusRow
                anchors.centerIn: parent; spacing: 18
                Row {
                    visible: nowTitle !== ""; spacing: 10; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 7; height: 7; radius: 3.5; color: shell.theme.focus; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: nowTitle; font.family: shell.fontName; font.pixelSize: 19; color: shell.theme.text; anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle { visible: nowTitle !== ""; width: 1; height: 20; color: shell.theme.divider; anchors.verticalCenter: parent.verticalCenter }
                Text { text: clock; font.family: shell.fontName; font.bold: true; font.pixelSize: 26; font.letterSpacing: -0.4; color: shell.theme.heading; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // Hero: the focused name and one line of context under it.
        Item {
            id: heroGroup
            x: shell.margin; y: shell.heroBaseline - 160
            width: 1700; height: 220
            Item { id: heroBase; y: 160; width: 1; height: 1 }
            Text {
                width: 1700; anchors.baseline: heroBase.top
                visible: shell.showTitle
                text: shell.hero.title; elide: Text.ElideRight
                font.family: shell.fontName; font.bold: true; font.pixelSize: 60; font.letterSpacing: -1.8; color: shell.theme.heading; style: Text.Raised; styleColor: shell.theme.headingShadow
            }
            Text {
                y: 160 + 14
                text: shell.hero.sub; font.family: shell.fontName; font.pixelSize: 22
                color: message ? shell.warning : notice ? shell.theme.heading : shell.theme.text
            }
        }

        // Controls for what is focused, on the bottom line with the version.
        Row {
            x: shell.margin; y: 1033; spacing: 24
            Repeater {
                model: shell.hints
                Row {
                    spacing: 9
                    Rectangle {
                        width: keyLabel.implicitWidth+14; height: 24; radius: 7; color: "transparent"; border.width: 1.5; border.color: shell.theme.keyEdge
                        Text { id: keyLabel; anchors.centerIn: parent; text: modelData[0]; font.family: shell.fontName; font.bold: true; font.pixelSize: 12; color: shell.theme.keyLabel }
                    }
                    Text { text: modelData[1]; font.family: shell.fontName; font.pixelSize: 15; color: shell.theme.hint; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        // Rounded app tile with the double focus ring.
        Component {
            id: appTile
            Item {
                id: cell
                property var entry
                property int navIndex: 0
                readonly property int size: shell.tile
                readonly property int corner: 30
                property bool chosen: shell.selected === navIndex
                readonly property bool editing: shell.page === "home" && shell.editIndex === navIndex
                readonly property bool starred: shell.page === "apps" && entry !== undefined && shell.favouriteKeys.indexOf(entry.id) >= 0
                width: size; height: size
                z: chosen ? 2 : 0
                scale: chosen ? (shell.pressing ? 1.03 : 1.1) : 1
                property real lift: chosen ? -6 : 0
                Behavior on lift { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                transform: Translate { y: cell.lift }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Rectangle { visible: cell.chosen; anchors.centerIn: parent; width: cell.size+14; height: width; radius: cell.corner+7; color: cell.editing ? shell.warning : shell.theme.ring }
                Rectangle { visible: cell.chosen; anchors.centerIn: parent; width: cell.size+8; height: width; radius: cell.corner+4; color: shell.theme.gap }
                Rectangle { anchors.fill: parent; radius: cell.corner; color: shell.theme.tile }
                Text {
                    visible: icon.status !== Image.Ready
                    anchors.centerIn: parent; text: cell.entry && cell.entry.title ? cell.entry.title.charAt(0) : ""
                    font.family: shell.fontName; font.bold: true; font.pixelSize: 40; color: shell.ink2
                }
                Image {
                    id: icon; anchors.fill: parent; visible: false
                    source: cell.entry && cell.entry.icon ? cell.entry.icon : ""
                    fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true
                    sourceSize.width: 240; sourceSize.height: 240
                }
                Rectangle { id: corners; anchors.fill: parent; radius: cell.corner; visible: false }
                OpacityMask { anchors.fill: parent; source: icon; maskSource: corners; visible: icon.status === Image.Ready }
                // Edit handles sit on the tile edges, inside the gap to the neighbours.
                Repeater {
                    model: cell.editing ? ["‹", "›"] : []
                    Rectangle {
                        x: index === 0 ? -14 : cell.size-14; anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 44; radius: 14; color: shell.theme.handle; border.width: 2; border.color: shell.warning
                        Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -2; text: modelData; font.family: shell.fontName; font.bold: true; font.pixelSize: 30; color: shell.warning }
                    }
                }
                // Favourite marker in All applications.
                Rectangle {
                    visible: cell.starred; x: cell.size-20; y: -6; width: 26; height: 26; radius: 13
                    color: shell.theme.focus; border.width: 3; border.color: shell.theme.gap
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: shell.selected=cell.navIndex
                    onClicked: { shell.selected=cell.navIndex; shell.activate(shell.itemAt(cell.navIndex)); }
                }
            }
        }
        // Rounded line-icon tile: All applications, System and its tools.
        Component {
            id: glyphTile
            Item {
                id: glyphCell
                property var entry
                property int navIndex: 0
                // Size comes from the Loader so the Canvas paints once at the right scale.
                readonly property int size: parent && parent.glyphSize ? parent.glyphSize : 88
                readonly property int corner: size > 100 ? 30 : size > 70 ? 24 : 18
                property bool chosen: shell.selected === navIndex
                width: size; height: size
                z: chosen ? 2 : 0
                scale: chosen ? (shell.pressing ? 1.03 : 1.1) : 1
                property real lift: chosen ? -6 : 0
                Behavior on lift { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                transform: Translate { y: glyphCell.lift }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Rectangle { visible: glyphCell.chosen; anchors.centerIn: parent; width: glyphCell.size+14; height: width; radius: glyphCell.corner+7; color: shell.theme.ring }
                Rectangle { visible: glyphCell.chosen; anchors.centerIn: parent; width: glyphCell.size+8; height: width; radius: glyphCell.corner+4; color: shell.theme.gap }
                Rectangle {
                    anchors.fill: parent; radius: glyphCell.corner
                    color: glyphCell.chosen ? shell.theme.focus : shell.chip
                    border.width: glyphCell.chosen ? 0 : 1; border.color: shell.chipEdge
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                Canvas {
                    property int box: glyphCell.size > 100 ? 44 : glyphCell.size > 70 ? 32 : 28
                    anchors.centerIn: parent; width: box; height: box
                    property string symbol: glyphCell.entry && glyphCell.entry.symbol ? glyphCell.entry.symbol : ""
                    property string stroke: glyphCell.chosen ? shell.theme.onFocus : shell.ink
                    onSymbolChanged: requestPaint()
                    onStrokeChanged: requestPaint()
                    onPaint: {
                        var c=getContext("2d"); c.reset(); c.scale(box/40, box/40);
                        c.strokeStyle = stroke; c.lineWidth = 2.2*40/box; c.lineCap="round"; c.lineJoin="round";
                        shell.drawGlyph(c, symbol);
                    }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: shell.selected=glyphCell.navIndex
                    onClicked: { shell.selected=glyphCell.navIndex; shell.activate(shell.itemAt(glyphCell.navIndex)); }
                }
            }
        }

        // Home rail: favourites, sources, then the two doors.
        Row {
            visible: page === "home"
            x: shell.margin; y: shell.railY; height: shell.tile; spacing: 32
            Row {
                spacing: shell.gap; anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: favourites
                    Loader {
                        sourceComponent: appTile; z: item && item.chosen ? 2 : 0
                        onLoaded: { item.entry=modelData; item.navIndex=index; }
                    }
                }
                Loader {
                    active: shell.showAddTile
                    visible: active
                    property int glyphSize: shell.tile
                    sourceComponent: glyphTile
                    onLoaded: { item.entry = Qt.binding(function() { return shell.addFavouritesTile; }); item.navIndex = 0; }
                }
            }
            Row {
                spacing: 12; anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: inputs
                    Rectangle {
                        id: pill
                        property bool chosen: shell.selected === shell.favSlots+index
                        property real lift: chosen ? -4 : 0
                        width: Math.max(pillLabel.implicitWidth, pillDevice.visible ? pillDevice.width : 0)+44; height: 64; radius: 18
                        color: chosen ? shell.theme.focus : shell.chip
                        border.width: chosen ? 0 : 1; border.color: shell.chipEdge
                        // Nothing plugged in: the pill stays solid, its text dimmed.
                        readonly property bool dim: !chosen && !modelData.present
                        scale: chosen ? (shell.pressing ? 1.02 : 1.06) : 1
                        transform: Translate { y: pill.lift }
                        Behavior on lift { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 180 } }
                        // HDMI n, and under it the device the TV sees there (CEC name or the input's label).
                        Column {
                            anchors.centerIn: parent; spacing: 1
                            Text {
                                id: pillLabel; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.title
                                font.family: shell.fontName; font.bold: true; font.pixelSize: pillDevice.visible ? 19 : 21; font.letterSpacing: -0.2
                                color: pill.chosen ? shell.theme.onFocus : pill.dim ? shell.theme.dim : shell.theme.label
                            }
                            Text {
                                id: pillDevice; visible: !!modelData.detail; anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.detail || ""; width: Math.min(implicitWidth, 140); elide: Text.ElideRight
                                font.family: shell.fontName; font.pixelSize: 13
                                color: pill.chosen ? shell.theme.onFocus2 : pill.dim ? shell.theme.dim2 : shell.ink3
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: shell.selected=shell.favSlots+index
                            onClicked: { shell.selected=shell.favSlots+index; shell.activate(modelData); }
                        }
                    }
                }
            }
            Row {
                spacing: 12; anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: 2
                    Loader {
                        property int glyphSize: 64
                        sourceComponent: glyphTile
                        onLoaded: {
                            item.entry = Qt.binding(function() { return index === 0 ? {title: shell.t("apps_title"), action: "apps", symbol: "apps"} : {title: shell.t("system_title"), action: "system", symbol: "settings"}; });
                            item.navIndex = Qt.binding(function() { return shell.favSlots+4+index; });
                        }
                    }
                }
            }
        }

        // All applications: twelve columns of tiles, two rows visible.
        Flickable {
            id: appGrid
            visible: page === "apps"
            x: shell.margin-20; y: 744-24; width: shell.appColumns*(shell.tile+shell.gap)-shell.gap+40; height: 2*shell.tile+shell.gap+48
            clip: true; interactive: false
            readonly property int step: shell.tile+shell.gap
            contentWidth: width; contentHeight: Math.max(height, Math.ceil(applications.length/shell.appColumns)*step+48-shell.gap)
            Behavior on contentY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Repeater {
                model: applications
                Loader {
                    x: 20+(index%shell.appColumns)*appGrid.step; y: 24+Math.floor(index/shell.appColumns)*appGrid.step
                    z: item && item.chosen ? 2 : 0
                    sourceComponent: appTile
                    onLoaded: { item.entry=modelData; item.navIndex=index; }
                }
            }
            Connections {
                target: shell
                onSelectedChanged: {
                    if (shell.page !== "apps") return;
                    var row=Math.floor(shell.selected/shell.appColumns), first=Math.round(appGrid.contentY/appGrid.step);
                    if (row < first) appGrid.contentY=row*appGrid.step;
                    else if (row > first+1) appGrid.contentY=(row-1)*appGrid.step;
                }
                onPageChanged: appGrid.contentY=0
            }
        }
        Rectangle {
            visible: page === "apps" && appGrid.contentHeight > appGrid.height
            x: 1920-shell.margin+20; y: 744; width: 4; height: 2*shell.tile+shell.gap; radius: 2; color: shell.theme.track
            Rectangle {
                width: 4; radius: 2; color: shell.theme.focus
                height: parent.height*appGrid.height/appGrid.contentHeight
                y: (parent.height-height)*appGrid.contentY/Math.max(1, appGrid.contentHeight-appGrid.height)
            }
        }

        // System and launcher settings: the same rail, glyph tiles at full size.
        Row {
            visible: page === "system" || page === "settings"
            x: shell.margin; y: shell.railY; spacing: shell.gap
            Repeater {
                model: page === "settings" ? shell.settingsItems : shell.tools
                Loader {
                    property int glyphSize: shell.tile
                    sourceComponent: glyphTile; z: item && item.chosen ? 2 : 0
                    onLoaded: { item.entry=modelData; item.navIndex=index; }
                }
            }
        }

        Text {
            visible: page === "system" || page === "settings"
            anchors.right: parent.right; anchors.rightMargin: shell.margin; y: 1037
            text: "rawin-launcher " + Config.version + (Config.platform ? " · " + Config.platform : ""); font.family: shell.fontName; font.pixelSize: 14; color: shell.theme.version
        }
    } // panel
}
