import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Statistics.qml
// Full statistics panel for SlowBongo.
// Mount in entryPoints (e.g. as "statistics" page) and pass pluginApi + keyTracker.

ColumnLayout {
    id: root
    spacing: Style.marginL

    property var pluginApi: null
    property var keyTracker: null   // KeyTracker instance from Main.qml

    // ── Helpers ───────────────────────────────────────────────────────────────
    function fmt(n) {
        if (n === undefined || n === null) return "0"
        if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
        if (n >= 1000)    return (n / 1000).toFixed(1) + "k"
        return n.toString()
    }

    // ── QWERTZ layout rows for heatmap ────────────────────────────────────────
    // Each key: { label, evkey }  evkey = what KeyTracker stores (EV_KEY name minus KEY_)
    readonly property var qwertzRows: [
        [
            {l:"^",k:"GRAVE"},{l:"1",k:"1"},{l:"2",k:"2"},{l:"3",k:"3"},{l:"4",k:"4"},
            {l:"5",k:"5"},{l:"6",k:"6"},{l:"7",k:"7"},{l:"8",k:"8"},{l:"9",k:"9"},
            {l:"0",k:"0"},{l:"ß",k:"MINUS"},{l:"´",k:"EQUAL"},{l:"⌫",k:"BACKSPACE"}
        ],
        [
            {l:"Tab",k:"TAB"},{l:"Q",k:"Q"},{l:"W",k:"W"},{l:"E",k:"E"},{l:"R",k:"R"},
            {l:"T",k:"T"},{l:"Z",k:"Z"},{l:"U",k:"U"},{l:"I",k:"I"},{l:"O",k:"O"},
            {l:"P",k:"P"},{l:"Ü",k:"LEFTBRACE"},{l:"+",k:"RIGHTBRACE"},{l:"#",k:"BACKSLASH"}
        ],
        [
            {l:"Caps",k:"CAPSLOCK"},{l:"A",k:"A"},{l:"S",k:"S"},{l:"D",k:"D"},{l:"F",k:"F"},
            {l:"G",k:"G"},{l:"H",k:"H"},{l:"J",k:"J"},{l:"K",k:"K"},{l:"L",k:"L"},
            {l:"Ö",k:"SEMICOLON"},{l:"Ä",k:"APOSTROPHE"},{l:"↵",k:"ENTER"}
        ],
        [
            {l:"⇧",k:"LEFTSHIFT"},{l:"<",k:"102ND"},{l:"Y",k:"Y"},{l:"X",k:"X"},
            {l:"C",k:"C"},{l:"V",k:"V"},{l:"B",k:"B"},{l:"N",k:"N"},{l:"M",k:"M"},
            {l:",",k:"COMMA"},{l:".",k:"DOT"},{l:"-",k:"SLASH"},{l:"⇧",k:"RIGHTSHIFT"}
        ],
        [
            {l:"Ctrl",k:"LEFTCTRL"},{l:"⊞",k:"LEFTMETA"},{l:"Alt",k:"LEFTALT"},
            {l:"                    Space                    ",k:"SPACE"},
            {l:"AltGr",k:"RIGHTALT"},{l:"⊞",k:"RIGHTMETA"},{l:"☰",k:"COMPOSE"},{l:"Ctrl",k:"RIGHTCTRL"}
        ]
    ]

    // ── Max count for heatmap colour scale ────────────────────────────────────
    readonly property int heatmapMax: {
        if (!keyTracker || !keyTracker.keyCounts) return 1
        let m = 1
        const keys = keyTracker.keyCounts
        for (const k in keys) { if (keys[k] > m) m = keys[k] }
        return m
    }

    function heatColor(evkey) {
        if (!keyTracker || !keyTracker.keyCounts) return "transparent"
        const count = keyTracker.keyCounts[evkey] || 0
        if (count === 0) return "transparent"
        const ratio = Math.min(count / heatmapMax, 1.0)
        // Cold (blue) → warm (orange) → hot (red)
        const r = Math.round(30  + ratio * 220)
        const g = Math.round(100 - ratio * 80)
        const b = Math.round(200 - ratio * 190)
        return Qt.rgba(r/255, g/255, b/255, 0.25 + ratio * 0.65)
    }

    // ── Section title helper component ────────────────────────────────────────
    component SectionTitle: Text {
        color: Color.mOnSurface
        font.pointSize: Style.fontSizeM
        font.weight: Font.DemiBold
        Layout.fillWidth: true
    }

    // ════════════════════════════════════════════════════════════════════════
    //  TOTALS CARDS
    // ════════════════════════════════════════════════════════════════════════
    SectionTitle { text: "📊 Statistiky" }

    Row {
        Layout.fillWidth: true
        spacing: Style.marginM

        // Total
        NBox {
            width: (parent.width - Style.marginM * 2) / 3
            implicitHeight: cardCol.implicitHeight + Style.marginM * 2

            ColumnLayout {
                id: cardCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginM }
                spacing: 2

                Text {
                    text: "Celkem stisků"
                    color: Color.mOnSurfaceVariant
                    font.pointSize: Style.fontSizeS
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: fmt(keyTracker?.totalPresses ?? 0)
                    color: Color.mPrimary
                    font.pointSize: Style.fontSizeXL ?? Style.fontSizeL
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Session
        NBox {
            width: (parent.width - Style.marginM * 2) / 3
            implicitHeight: sessionCol.implicitHeight + Style.marginM * 2

            ColumnLayout {
                id: sessionCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginM }
                spacing: 2

                Text {
                    text: "Tato session"
                    color: Color.mOnSurfaceVariant
                    font.pointSize: Style.fontSizeS
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: fmt(keyTracker?.sessionPresses ?? 0)
                    color: Color.mSecondary
                    font.pointSize: Style.fontSizeXL ?? Style.fontSizeL
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Top key
        NBox {
            width: (parent.width - Style.marginM * 2) / 3
            implicitHeight: topKeyCol.implicitHeight + Style.marginM * 2

            ColumnLayout {
                id: topKeyCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginM }
                spacing: 2

                Text {
                    text: "Nejpoužívanější"
                    color: Color.mOnSurfaceVariant
                    font.pointSize: Style.fontSizeS
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: {
                        const top = keyTracker?.topKeys(1) ?? []
                        return top.length > 0 ? top[0].key : "–"
                    }
                    color: Color.mTertiary
                    font.pointSize: Style.fontSizeXL ?? Style.fontSizeL
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    NDivider { Layout.fillWidth: true }

    // ════════════════════════════════════════════════════════════════════════
    //  HEATMAP
    // ════════════════════════════════════════════════════════════════════════
    SectionTitle { text: "🔥 Heatmapa kláves (QWERTZ)" }

    NBox {
        Layout.fillWidth: true
        implicitHeight: heatmapLayout.implicitHeight + Style.marginM * 2

        ColumnLayout {
            id: heatmapLayout
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginM }
            spacing: 3

            Repeater {
                model: root.qwertzRows

                Row {
                    spacing: 3
                    required property var modelData

                    Repeater {
                        model: modelData

                        Rectangle {
                            required property var modelData
                            readonly property int keyCount: keyTracker?.keyCounts[modelData.k] ?? 0
                            readonly property real ratio: Math.min(keyCount / Math.max(root.heatmapMax, 1), 1.0)

                            // Wider keys
                            width: {
                                const l = modelData.l
                                if (l === "⌫" || l === "↵") return 52
                                if (l === "Tab" || l === "Caps" || l === "⇧") return 48
                                if (l === "                    Space                    ") return 210
                                if (l === "Ctrl" || l === "Alt" || l === "AltGr") return 44
                                return 32
                            }
                            height: 30
                            radius: 4
                            color: root.heatColor(modelData.k)
                            border.color: Color.mOutline ?? Color.mOnSurfaceVariant
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 300 } }

                            // Key label
                            Text {
                                anchors.centerIn: parent
                                text: modelData.l === "                    Space                    " ? "Space" : modelData.l
                                color: Color.mOnSurface
                                font.pointSize: Style.fontSizeXS
                                font.weight: parent.ratio > 0.5 ? Font.Bold : Font.Normal
                                elide: Text.ElideRight
                                width: parent.width - 4
                                horizontalAlignment: Text.AlignHCenter
                            }

                            // Tooltip on hover
                            HoverHandler { id: hov }
                            ToolTip {
                                visible: hov.hovered && parent.keyCount > 0
                                text: modelData.l + ": " + parent.keyCount.toLocaleString()
                                delay: 300
                            }
                        }
                    }
                }
            }
        }
    }

    NDivider { Layout.fillWidth: true }

    // ════════════════════════════════════════════════════════════════════════
    //  TOP 15 KLÁVESY
    // ════════════════════════════════════════════════════════════════════════
    SectionTitle { text: "🏅 Nejpoužívanější klávesy" }

    NBox {
        Layout.fillWidth: true
        implicitHeight: topList.implicitHeight + Style.marginM * 2

        ColumnLayout {
            id: topList
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginM }
            spacing: 4

            Repeater {
                model: keyTracker?.topKeys(15) ?? []

                RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    // Rank badge
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: index === 0 ? "#FFD700" : index === 1 ? "#C0C0C0" : index === 2 ? "#CD7F32" : Color.mSurfaceVariant
                        Text {
                            anchors.centerIn: parent
                            text: index + 1
                            font.pointSize: Style.fontSizeXS
                            font.weight: Font.Bold
                            color: index < 3 ? "#000" : Color.mOnSurfaceVariant
                        }
                    }

                    // Key name
                    Text {
                        text: modelData.key
                        color: Color.mOnSurface
                        font.pointSize: Style.fontSizeM
                        font.weight: Font.Medium
                        Layout.preferredWidth: 80
                    }

                    // Progress bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 8
                        radius: 4
                        color: Color.mSurfaceVariant

                        Rectangle {
                            width: parent.width * (modelData.count / Math.max(root.heatmapMax, 1))
                            height: parent.height
                            radius: parent.radius
                            color: index === 0 ? "#FFD700" : Color.mPrimary
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                    }

                    // Count
                    Text {
                        text: fmt(modelData.count)
                        color: Color.mOnSurfaceVariant
                        font.pointSize: Style.fontSizeS
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 50
                    }
                }
            }

            Text {
                visible: (keyTracker?.topKeys(1) ?? []).length === 0
                text: "Zatím žádná data – začni psát! 🐱"
                color: Color.mOnSurfaceVariant
                font.pointSize: Style.fontSizeM
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    NDivider { Layout.fillWidth: true }

    // ════════════════════════════════════════════════════════════════════════
    //  RYCHLÉ FAKTY
    // ════════════════════════════════════════════════════════════════════════
    SectionTitle { text: "🤓 Zajímavosti" }

    NBox {
        Layout.fillWidth: true
        implicitHeight: factsCol.implicitHeight + Style.marginM * 2

        ColumnLayout {
            id: factsCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginM }
            spacing: Style.marginS

            Repeater {
                model: [
                    {
                        label: "Stisků za restart:",
                        value: fmt(keyTracker?.sessionPresses ?? 0)
                    },
                    {
                        label: "Backspace / celkem:",
                        value: {
                            const bs = keyTracker?.keyCounts["BACKSPACE"] ?? 0
                            const tot = keyTracker?.totalPresses ?? 0
                            if (tot === 0) return "–"
                            return (bs / tot * 100).toFixed(1) + "%"
                        }
                    },
                    {
                        label: "Space / celkem:",
                        value: {
                            const sp = keyTracker?.keyCounts["SPACE"] ?? 0
                            const tot = keyTracker?.totalPresses ?? 0
                            if (tot === 0) return "–"
                            return (sp / tot * 100).toFixed(1) + "%"
                        }
                    },
                    {
                        label: "Různých kláves:",
                        value: {
                            const kc = keyTracker?.keyCounts ?? {}
                            return Object.keys(kc).length.toString()
                        }
                    },
                    {
                        label: "Restartů pluginu:",
                        value: (keyTracker?._stats?.restarts ?? 0).toString()
                    }
                ]

                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Text {
                        text: modelData.label
                        color: Color.mOnSurfaceVariant
                        font.pointSize: Style.fontSizeS
                        Layout.fillWidth: true
                    }
                    Text {
                        text: modelData.value
                        color: Color.mOnSurface
                        font.pointSize: Style.fontSizeS
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }

    // Bottom padding
    Item { height: Style.marginL }
}
