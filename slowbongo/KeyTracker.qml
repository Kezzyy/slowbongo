import QtQuick
import Quickshell.Io
import qs.Commons

// KeyTracker.qml
// Persistent statistics & achievement tracking for SlowBongo.
// Mount this in Main.qml as a child item and call `recordKeyPress(keyName)` on each EV_KEY event.
// Data is stored via pluginApi.pluginSettings under the "stats" and "achievements" keys.

Item {
    id: root

    // ── External API ──────────────────────────────────────────────────────────
    property var pluginApi: null

    // ── Public read-only stats ────────────────────────────────────────────────
    readonly property int totalPresses:    _stats.total        ?? 0
    readonly property var keyCounts:       _stats.keys         ?? ({})
    readonly property var sessionPresses:  _session.total      ?? 0
    readonly property var unlockedAch:     _achState           ?? ({})

    // ── Internal state ────────────────────────────────────────────────────────
    property var _stats:    ({ total: 0, keys: {} })
    property var _session:  ({ total: 0, keys: {} })
    property var _achState: ({})            // achievementId → { unlockedAt, notified }

    // ── Dirty flag → save at most once per second ─────────────────────────────
    property bool _dirty: false
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: { if (root._dirty) { root._save(); root._dirty = false } }
    }

    // ── Load on startup ───────────────────────────────────────────────────────
    onPluginApiChanged: {
        if (pluginApi) _load()
    }

    // ── Public: call this for every key press ─────────────────────────────────
    function recordKeyPress(keyName) {
        // Normalise keyname: strip "KEY_" prefix
        const k = keyName ? keyName.replace(/^KEY_/, "").toUpperCase() : "UNKNOWN"

        // Update persistent stats
        let s = root._stats
        s.total = (s.total || 0) + 1
        if (!s.keys) s.keys = {}
        s.keys[k] = (s.keys[k] || 0) + 1
        root._stats = s

        // Update session stats
        let sess = root._session
        sess.total = (sess.total || 0) + 1
        if (!sess.keys) sess.keys = {}
        sess.keys[k] = (sess.keys[k] || 0) + 1
        root._session = sess

        root._dirty = true

        // Check achievements
        _checkAchievements(k, s)
    }

    // ── Top N keys helper ─────────────────────────────────────────────────────
    function topKeys(n) {
        if (!_stats.keys) return []
        const entries = Object.entries(_stats.keys)
        entries.sort((a, b) => b[1] - a[1])
        return entries.slice(0, n).map(e => ({ key: e[0], count: e[1] }))
    }

    // ── Achievement definitions ───────────────────────────────────────────────
    // Each entry: { id, title, desc, icon, check(keyName, stats) → bool }
    readonly property var achievements: [
        // ── Total presses milestones ──────────────────────────────────────────
        { id:"total_100",      title:"První kroky",          desc:"100 stisků celkem",                  icon:"🐾", tier:0, check: function(k,s){ return s.total >= 100 } },
        { id:"total_500",      title:"Rozbíháme se",         desc:"500 stisků celkem",                  icon:"🐾", tier:0, check: function(k,s){ return s.total >= 500 } },
        { id:"total_1k",       title:"Tisícovka!",           desc:"1 000 stisků celkem",                icon:"🎉", tier:0, check: function(k,s){ return s.total >= 1000 } },
        { id:"total_5k",       title:"Prsty v kondici",      desc:"5 000 stisků celkem",                icon:"💪", tier:1, check: function(k,s){ return s.total >= 5000 } },
        { id:"total_10k",      title:"Desetitisícovka",      desc:"10 000 stisků celkem",               icon:"🔥", tier:1, check: function(k,s){ return s.total >= 10000 } },
        { id:"total_25k",      title:"Čtvrt milionu?",       desc:"25 000 stisků celkem",               icon:"⚡", tier:1, check: function(k,s){ return s.total >= 25000 } },
        { id:"total_50k",      title:"Půl stovky tisíc",     desc:"50 000 stisků celkem",               icon:"🌟", tier:2, check: function(k,s){ return s.total >= 50000 } },
        { id:"total_100k",     title:"Sto tisíc!",           desc:"100 000 stisků celkem",              icon:"💎", tier:2, check: function(k,s){ return s.total >= 100000 } },
        { id:"total_250k",     title:"Čtvrt milionu",        desc:"250 000 stisků celkem",              icon:"🏆", tier:2, check: function(k,s){ return s.total >= 250000 } },
        { id:"total_500k",     title:"Půl milionu",          desc:"500 000 stisků celkem",              icon:"👑", tier:3, check: function(k,s){ return s.total >= 500000 } },
        { id:"total_1m",       title:"Milionář!",            desc:"1 000 000 stisků celkem",            icon:"💫", tier:3, check: function(k,s){ return s.total >= 1000000 } },
        { id:"total_5m",       title:"Pět milionů",          desc:"5 000 000 stisků celkem",            icon:"🌈", tier:3, check: function(k,s){ return s.total >= 5000000 } },
        { id:"total_10m",      title:"Deset milionů",        desc:"10 000 000 stisků celkem",           icon:"🚀", tier:4, check: function(k,s){ return s.total >= 10000000 } },
        { id:"total_50m",      title:"Padesát milionů",      desc:"50 000 000 stisků celkem",           icon:"🌌", tier:4, check: function(k,s){ return s.total >= 50000000 } },
        { id:"total_100m",     title:"Sto milionů – legenda",desc:"100 000 000 stisků celkem",          icon:"🦄", tier:4, check: function(k,s){ return s.total >= 100000000 } },

        // ── Single-key milestones (Space) ─────────────────────────────────────
        { id:"space_100",   title:"Mezerníkář",              desc:"100× Space",                         icon:"⬜", tier:0, check: function(k,s){ return (s.keys["SPACE"]||0) >= 100 } },
        { id:"space_500",   title:"Mezera mazák",            desc:"500× Space",                         icon:"⬜", tier:1, check: function(k,s){ return (s.keys["SPACE"]||0) >= 500 } },
        { id:"space_1k",    title:"Tisíc mezer",             desc:"1 000× Space",                       icon:"⬜", tier:1, check: function(k,s){ return (s.keys["SPACE"]||0) >= 1000 } },
        { id:"space_10k",   title:"Mezerní mistr",           desc:"10 000× Space",                      icon:"⬜", tier:2, check: function(k,s){ return (s.keys["SPACE"]||0) >= 10000 } },
        { id:"space_100k",  title:"Kosmonaut mezer",         desc:"100 000× Space",                     icon:"⬜", tier:3, check: function(k,s){ return (s.keys["SPACE"]||0) >= 100000 } },
        { id:"space_1m",    title:"Mezerní bůh",             desc:"1 000 000× Space",                   icon:"⬜", tier:4, check: function(k,s){ return (s.keys["SPACE"]||0) >= 1000000 } },

        // ── Enter ─────────────────────────────────────────────────────────────
        { id:"enter_500",   title:"Odesílatel",              desc:"500× Enter",                         icon:"↵", tier:1, check: function(k,s){ return (s.keys["ENTER"]||0) >= 500 } },
        { id:"enter_5k",    title:"Enter fanatic",           desc:"5 000× Enter",                       icon:"↵", tier:2, check: function(k,s){ return (s.keys["ENTER"]||0) >= 5000 } },
        { id:"enter_50k",   title:"Enter legend",            desc:"50 000× Enter",                      icon:"↵", tier:3, check: function(k,s){ return (s.keys["ENTER"]||0) >= 50000 } },
        { id:"enter_500k",  title:"Enter bůh",               desc:"500 000× Enter",                     icon:"↵", tier:4, check: function(k,s){ return (s.keys["ENTER"]||0) >= 500000 } },

        // ── Backspace ─────────────────────────────────────────────────────────
        { id:"bs_500",      title:"Opravář",                 desc:"500× Backspace – chyby se dějí",     icon:"⌫", tier:1, check: function(k,s){ return (s.keys["BACKSPACE"]||0) >= 500 } },
        { id:"bs_5k",       title:"Dokonalý mazač",          desc:"5 000× Backspace",                   icon:"⌫", tier:2, check: function(k,s){ return (s.keys["BACKSPACE"]||0) >= 5000 } },
        { id:"bs_50k",      title:"Bezedná guma",            desc:"50 000× Backspace",                  icon:"⌫", tier:3, check: function(k,s){ return (s.keys["BACKSPACE"]||0) >= 50000 } },
        { id:"bs_500k",     title:"Backspace mistr vesmíru", desc:"500 000× Backspace",                 icon:"⌫", tier:4, check: function(k,s){ return (s.keys["BACKSPACE"]||0) >= 500000 } },

        // ── Escape ────────────────────────────────────────────────────────────
        { id:"esc_500",     title:"Útěkář",                  desc:"500× Escape",                        icon:"🏃", tier:1, check: function(k,s){ return (s.keys["ESC"]||0) >= 500 } },
        { id:"esc_10k",     title:"Vim survivor",            desc:"10 000× Escape – každý vim ví",      icon:"🏃", tier:2, check: function(k,s){ return (s.keys["ESC"]||0) >= 10000 } },
        { id:"esc_100k",    title:"Esc legend",              desc:"100 000× Escape",                    icon:"🏃", tier:3, check: function(k,s){ return (s.keys["ESC"]||0) >= 100000 } },

        // ── QWERTZ – písmena (500 / 5k / 50k / 500k / 1M) ───────────────────
        // Q
        { id:"q_500",    title:"Q-maniak",                   desc:"500× Q",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["Q"]||0)>=500 } },
        { id:"q_5k",     title:"Q-master",                   desc:"5 000× Q",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["Q"]||0)>=5000 } },
        { id:"q_50k",    title:"Q-legend",                   desc:"50 000× Q",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["Q"]||0)>=50000 } },
        { id:"q_500k",   title:"Q-bůh",                      desc:"500 000× Q",                         icon:"🔡", tier:4, check: function(k,s){ return (s.keys["Q"]||0)>=500000 } },
        // W
        { id:"w_500",    title:"W-warrior",                  desc:"500× W",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["W"]||0)>=500 } },
        { id:"w_5k",     title:"W-master",                   desc:"5 000× W",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["W"]||0)>=5000 } },
        { id:"w_50k",    title:"W-legend",                   desc:"50 000× W",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["W"]||0)>=50000 } },
        { id:"w_500k",   title:"W-bůh",                      desc:"500 000× W",                         icon:"🔡", tier:4, check: function(k,s){ return (s.keys["W"]||0)>=500000 } },
        // E
        { id:"e_500",    title:"E-enjoyer",                  desc:"500× E",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["E"]||0)>=500 } },
        { id:"e_5k",     title:"E-master",                   desc:"5 000× E",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["E"]||0)>=5000 } },
        { id:"e_50k",    title:"E-legend",                   desc:"50 000× E",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["E"]||0)>=50000 } },
        { id:"e_500k",   title:"E-bůh",                      desc:"500 000× E",                         icon:"🔡", tier:4, check: function(k,s){ return (s.keys["E"]||0)>=500000 } },
        // R
        { id:"r_500",    title:"R-runner",                   desc:"500× R",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["R"]||0)>=500 } },
        { id:"r_5k",     title:"R-master",                   desc:"5 000× R",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["R"]||0)>=5000 } },
        { id:"r_50k",    title:"R-legend",                   desc:"50 000× R",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["R"]||0)>=50000 } },
        { id:"r_500k",   title:"R-bůh",                      desc:"500 000× R",                         icon:"🔡", tier:4, check: function(k,s){ return (s.keys["R"]||0)>=500000 } },
        // T
        { id:"t_500",    title:"T-typer",                    desc:"500× T",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["T"]||0)>=500 } },
        { id:"t_5k",     title:"T-master",                   desc:"5 000× T",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["T"]||0)>=5000 } },
        { id:"t_50k",    title:"T-legend",                   desc:"50 000× T",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["T"]||0)>=50000 } },
        { id:"t_500k",   title:"T-bůh",                      desc:"500 000× T",                         icon:"🔡", tier:4, check: function(k,s){ return (s.keys["T"]||0)>=500000 } },
        // Z  (QWERTZ – Z je na místě Y!)
        { id:"z_500",    title:"Z-zvíře",                    desc:"500× Z",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["Z"]||0)>=500 } },
        { id:"z_5k",     title:"Z-master",                   desc:"5 000× Z",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["Z"]||0)>=5000 } },
        { id:"z_50k",    title:"Z-legend",                   desc:"50 000× Z",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["Z"]||0)>=50000 } },
        { id:"z_500k",   title:"Z-bůh",                      desc:"500 000× Z",                         icon:"🔡", tier:4, check: function(k,s){ return (s.keys["Z"]||0)>=500000 } },
        // U
        { id:"u_500",    title:"U-user",                     desc:"500× U",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["U"]||0)>=500 } },
        { id:"u_5k",     title:"U-master",                   desc:"5 000× U",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["U"]||0)>=5000 } },
        { id:"u_50k",    title:"U-legend",                   desc:"50 000× U",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["U"]||0)>=50000 } },
        // I
        { id:"i_500",    title:"I-enjoyer",                  desc:"500× I",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["I"]||0)>=500 } },
        { id:"i_5k",     title:"I-master",                   desc:"5 000× I",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["I"]||0)>=5000 } },
        { id:"i_50k",    title:"I-legend",                   desc:"50 000× I",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["I"]||0)>=50000 } },
        // O
        { id:"o_500",    title:"O-opičák",                   desc:"500× O",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["O"]||0)>=500 } },
        { id:"o_5k",     title:"O-master",                   desc:"5 000× O",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["O"]||0)>=5000 } },
        { id:"o_50k",    title:"O-legend",                   desc:"50 000× O",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["O"]||0)>=50000 } },
        // P
        { id:"p_500",    title:"P-písař",                    desc:"500× P",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["P"]||0)>=500 } },
        { id:"p_5k",     title:"P-master",                   desc:"5 000× P",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["P"]||0)>=5000 } },
        { id:"p_50k",    title:"P-legend",                   desc:"50 000× P",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["P"]||0)>=50000 } },
        // A
        { id:"a_500",    title:"A-hráč",                     desc:"500× A",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["A"]||0)>=500 } },
        { id:"a_5k",     title:"A-master",                   desc:"5 000× A",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["A"]||0)>=5000 } },
        { id:"a_50k",    title:"A-legend",                   desc:"50 000× A",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["A"]||0)>=50000 } },
        { id:"a_500k",   title:"A-bůh",                      desc:"500 000× A",                         icon:"🔡", tier:4, check: function(k,s){ return (s.keys["A"]||0)>=500000 } },
        // S
        { id:"s_500",    title:"S-shooter",                  desc:"500× S",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["S"]||0)>=500 } },
        { id:"s_5k",     title:"S-master",                   desc:"5 000× S",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["S"]||0)>=5000 } },
        { id:"s_50k",    title:"S-legend",                   desc:"50 000× S",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["S"]||0)>=50000 } },
        // D
        { id:"d_500",    title:"D-drtič",                    desc:"500× D",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["D"]||0)>=500 } },
        { id:"d_5k",     title:"D-master",                   desc:"5 000× D",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["D"]||0)>=5000 } },
        { id:"d_50k",    title:"D-legend",                   desc:"50 000× D",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["D"]||0)>=50000 } },
        // F
        { id:"f_500",    title:"F-fanatic",                  desc:"500× F",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["F"]||0)>=500 } },
        { id:"f_5k",     title:"F-master",                   desc:"5 000× F",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["F"]||0)>=5000 } },
        { id:"f_50k",    title:"F-legend",                   desc:"50 000× F",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["F"]||0)>=50000 } },
        // G
        { id:"g_500",    title:"G-génius",                   desc:"500× G",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["G"]||0)>=500 } },
        { id:"g_5k",     title:"G-master",                   desc:"5 000× G",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["G"]||0)>=5000 } },
        { id:"g_50k",    title:"G-legend",                   desc:"50 000× G",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["G"]||0)>=50000 } },
        // H
        { id:"h_500",    title:"H-hrdina",                   desc:"500× H",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["H"]||0)>=500 } },
        { id:"h_5k",     title:"H-master",                   desc:"5 000× H",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["H"]||0)>=5000 } },
        { id:"h_50k",    title:"H-legend",                   desc:"50 000× H",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["H"]||0)>=50000 } },
        // J
        { id:"j_500",    title:"J-jezdec",                   desc:"500× J",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["J"]||0)>=500 } },
        { id:"j_5k",     title:"J-master",                   desc:"5 000× J",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["J"]||0)>=5000 } },
        { id:"j_50k",    title:"J-legend",                   desc:"50 000× J",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["J"]||0)>=50000 } },
        // K
        { id:"k_500",    title:"K-klikač",                   desc:"500× K",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["K"]||0)>=500 } },
        { id:"k_5k",     title:"K-master",                   desc:"5 000× K",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["K"]||0)>=5000 } },
        { id:"k_50k",    title:"K-legend",                   desc:"50 000× K",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["K"]||0)>=50000 } },
        // L
        { id:"l_500",    title:"L-lídr",                     desc:"500× L",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["L"]||0)>=500 } },
        { id:"l_5k",     title:"L-master",                   desc:"5 000× L",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["L"]||0)>=5000 } },
        { id:"l_50k",    title:"L-legend",                   desc:"50 000× L",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["L"]||0)>=50000 } },
        // Y  (QWERTZ – Y je na místě Z)
        { id:"y_500",    title:"Y-yak",                      desc:"500× Y",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["Y"]||0)>=500 } },
        { id:"y_5k",     title:"Y-master",                   desc:"5 000× Y",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["Y"]||0)>=5000 } },
        { id:"y_50k",    title:"Y-legend",                   desc:"50 000× Y",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["Y"]||0)>=50000 } },
        // X
        { id:"x_500",    title:"X-xpert",                    desc:"500× X",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["X"]||0)>=500 } },
        { id:"x_5k",     title:"X-master",                   desc:"5 000× X",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["X"]||0)>=5000 } },
        { id:"x_50k",    title:"X-legend",                   desc:"50 000× X",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["X"]||0)>=50000 } },
        // C
        { id:"c_500",    title:"C-cíl",                      desc:"500× C",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["C"]||0)>=500 } },
        { id:"c_5k",     title:"C-master",                   desc:"5 000× C",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["C"]||0)>=5000 } },
        { id:"c_50k",    title:"C-legend",                   desc:"50 000× C",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["C"]||0)>=50000 } },
        // V
        { id:"v_500",    title:"V-vítr",                     desc:"500× V",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["V"]||0)>=500 } },
        { id:"v_5k",     title:"V-master",                   desc:"5 000× V",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["V"]||0)>=5000 } },
        { id:"v_50k",    title:"V-legend",                   desc:"50 000× V",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["V"]||0)>=50000 } },
        // B
        { id:"b_500",    title:"Bongo-B",                    desc:"500× B",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["B"]||0)>=500 } },
        { id:"b_5k",     title:"B-master",                   desc:"5 000× B",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["B"]||0)>=5000 } },
        { id:"b_50k",    title:"B-legend",                   desc:"50 000× B",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["B"]||0)>=50000 } },
        // N
        { id:"n_500",    title:"N-nadšenec",                 desc:"500× N",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["N"]||0)>=500 } },
        { id:"n_5k",     title:"N-master",                   desc:"5 000× N",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["N"]||0)>=5000 } },
        { id:"n_50k",    title:"N-legend",                   desc:"50 000× N",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["N"]||0)>=50000 } },
        // M
        { id:"m_500",    title:"M-mág",                      desc:"500× M",                             icon:"🔡", tier:1, check: function(k,s){ return (s.keys["M"]||0)>=500 } },
        { id:"m_5k",     title:"M-master",                   desc:"5 000× M",                           icon:"🔡", tier:2, check: function(k,s){ return (s.keys["M"]||0)>=5000 } },
        { id:"m_50k",    title:"M-legend",                   desc:"50 000× M",                          icon:"🔡", tier:3, check: function(k,s){ return (s.keys["M"]||0)>=50000 } },

        // ── Speciální klávesy ─────────────────────────────────────────────────
        { id:"ctrl_100",  title:"Ctrl nadšenec",             desc:"100× Ctrl (L nebo R)",               icon:"🎮", tier:0, check: function(k,s){ return ((s.keys["LEFTCTRL"]||0)+(s.keys["RIGHTCTRL"]||0))>=100 } },
        { id:"ctrl_5k",   title:"Ctrl addict",               desc:"5 000× Ctrl",                        icon:"🎮", tier:2, check: function(k,s){ return ((s.keys["LEFTCTRL"]||0)+(s.keys["RIGHTCTRL"]||0))>=5000 } },
        { id:"ctrl_50k",  title:"Ctrl mistr",                desc:"50 000× Ctrl",                       icon:"🎮", tier:3, check: function(k,s){ return ((s.keys["LEFTCTRL"]||0)+(s.keys["RIGHTCTRL"]||0))>=50000 } },

        { id:"shift_500", title:"Shift guru",                desc:"500× Shift",                         icon:"⬆️", tier:1, check: function(k,s){ return ((s.keys["LEFTSHIFT"]||0)+(s.keys["RIGHTSHIFT"]||0))>=500 } },
        { id:"shift_10k", title:"Shift maniak",              desc:"10 000× Shift",                      icon:"⬆️", tier:2, check: function(k,s){ return ((s.keys["LEFTSHIFT"]||0)+(s.keys["RIGHTSHIFT"]||0))>=10000 } },
        { id:"shift_100k",title:"Shift vládce",              desc:"100 000× Shift",                     icon:"⬆️", tier:3, check: function(k,s){ return ((s.keys["LEFTSHIFT"]||0)+(s.keys["RIGHTSHIFT"]||0))>=100000 } },

        { id:"tab_500",   title:"Tabulátor",                 desc:"500× Tab",                           icon:"⇥",  tier:1, check: function(k,s){ return (s.keys["TAB"]||0)>=500 } },
        { id:"tab_10k",   title:"Tab fanatik",               desc:"10 000× Tab – programátor?",         icon:"⇥",  tier:2, check: function(k,s){ return (s.keys["TAB"]||0)>=10000 } },
        { id:"tab_100k",  title:"Tab vládce",                desc:"100 000× Tab",                       icon:"⇥",  tier:3, check: function(k,s){ return (s.keys["TAB"]||0)>=100000 } },

        // ── Milestone combo achievements ──────────────────────────────────────
        { id:"all_alpha_500",  title:"Abecedář",             desc:"Každé písmeno aspoň 500×",           icon:"📚", tier:2,
          check: function(k,s){
              const alpha=["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
              return alpha.every(c=>(s.keys[c]||0)>=500);
          }
        },
        { id:"all_alpha_5k",   title:"Polyglot",             desc:"Každé písmeno aspoň 5 000×",         icon:"📚", tier:3,
          check: function(k,s){
              const alpha=["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
              return alpha.every(c=>(s.keys[c]||0)>=5000);
          }
        },
        { id:"all_alpha_50k",  title:"Lexikonista",          desc:"Každé písmeno aspoň 50 000×",        icon:"📚", tier:4,
          check: function(k,s){
              const alpha=["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
              return alpha.every(c=>(s.keys[c]||0)>=50000);
          }
        },

        // ── Fun / Easter-egg achievements ─────────────────────────────────────
        { id:"nerd_first",    title:"Bongo začíná",          desc:"První stisk – bongo cat tě vítá!",   icon:"😸", tier:0, check: function(k,s){ return s.total >= 1 } },
        { id:"vim_mode",      title:"Vim survivor",          desc:"Esc mačkáš víc než Enter",           icon:"😅", tier:1,
          check: function(k,s){ return (s.keys["ESC"]||0) > (s.keys["ENTER"]||0) && s.total > 100 }
        },
        { id:"no_backspace",  title:"Čistý pisatel",         desc:"1 000 stisků bez jediného Backspace", icon:"✨", tier:2,
          check: function(k,s){ return s.total >= 1000 && (s.keys["BACKSPACE"]||0) === 0 }
        },
        { id:"space_half",    title:"Mezeromaniak",          desc:"Space tvoří >30 % všech stisků",     icon:"🌌", tier:2,
          check: function(k,s){ return s.total > 500 && (s.keys["SPACE"]||0) / s.total > 0.3 }
        },
        { id:"night_owl",     title:"Noční sova",            desc:"1 000 stisků (vnitřní timer)",       icon:"🦉", tier:1, check: function(k,s){ return s.total >= 1000 } },
        { id:"cat_nap",       title:"Kočičí dřímota",        desc:"Plugin restartován 5×",              icon:"😴", tier:0, check: function(k,s){ return (s.restarts||0) >= 5 } },
        { id:"speed_demon",   title:"Speed Demon",           desc:"Přes 1M stisků – jsi rychlý",        icon:"👹", tier:3, check: function(k,s){ return s.total >= 1000000 } },
    ]

    // ── Check achievements after each key press ───────────────────────────────
    function _checkAchievements(keyName, stats) {
        let state = root._achState
        let changed = false
        for (let i = 0; i < root.achievements.length; i++) {
            const ach = root.achievements[i]
            if (state[ach.id]?.unlockedAt) continue        // already unlocked
            if (ach.check(keyName, stats)) {
                state[ach.id] = { unlockedAt: Date.now(), notified: false }
                changed = true
                _notifyAchievement(ach)
            }
        }
        if (changed) {
            root._achState = state
            root._dirty = true
        }
    }

    function _notifyAchievement(ach) {
        if (!pluginApi) return
        try {
            // Use Noctalia's ToastService if available
            ToastService.showInfo("🏆 " + ach.title, ach.desc)
        } catch(e) {
            Logger.i("SlowBongo", "Achievement unlocked: " + ach.id)
        }
    }

    // ── Persistence helpers ───────────────────────────────────────────────────
    function _load() {
        try {
            const raw = pluginApi?.pluginSettings?.statsData
            if (raw) root._stats = JSON.parse(raw)
        } catch(e) { Logger.w("SlowBongo", "Could not load stats: " + e) }
        try {
            const raw = pluginApi?.pluginSettings?.achData
            if (raw) root._achState = JSON.parse(raw)
        } catch(e) { Logger.w("SlowBongo", "Could not load achievements: " + e) }

        // Count this startup as a restart
        let s = root._stats
        s.restarts = (s.restarts || 0) + 1
        root._stats = s
    }

    function _save() {
        if (!pluginApi) return
        try {
            pluginApi.pluginSettings.statsData    = JSON.stringify(root._stats)
            pluginApi.pluginSettings.achData      = JSON.stringify(root._achState)
            pluginApi.saveSettings()
        } catch(e) { Logger.w("SlowBongo", "Could not save stats: " + e) }
    }

    // Public force-save (call from Main on shutdown)
    function forceSave() { _save() }
}
