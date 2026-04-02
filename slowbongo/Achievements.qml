import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Achievements.qml
// Achievement panel for SlowBongo.
// Pass pluginApi + keyTracker (KeyTracker instance).

ColumnLayout {
    id: root
    spacing: Style.marginL

    property var pluginApi: null
    property var keyTracker: null

    property int filterTier: -1   // -1 = all, 0-4 = specific tier
    property bool showLocked: true

    // ── Tier metadata ──────────────────────────────────────────────────────────
    readonly property var tierMeta: [
        { name: "Bronz",   color: "#CD7F32", bg: "#3D2000" },
        { name: "Stříbro", color: "#A0A0A0", bg: "#252525" },
        { name: "Zlato",   color: "#FFD700", bg: "#332200" },
        { name: "Platina", color: "#00E5FF", bg: "#001A1F" },
        { name: "Diamant", color: "#FF00FF", bg: "#1A001A" }
    ]

    // ── Computed achievement list ──────────────────────────────────────────────
    function buildList() {
        if (!keyTracker) return []
        const allAch  = keyTracker.achievements ?? []
        const state   = keyTracker.unlockedAch  ?? {}
        let result = []
        for (let i = 0; i < allAch.length; i++) {
            const ach     = allAch[i]
            const unlocked = !!state[ach.id]?.unlockedAt
            if (root.filterTier >= 0 && ach.tier !== root.filterTier) continue
            if (!root.showLocked && !unlocked) continue
            result.push({
                id:        ach.id,
                title:     ach.title,
                desc:      ach.desc,
                icon:      ach.icon,
                tier:      ach.tier,
                unlocked:  unlocked,
                unlockedAt: state[ach.id]?.unlockedAt ?? 0
            })
        }
        // Sort: unlocked first (newest), then locked
        result.sort((a, b) => {
            if (a.unlocked && !b.unlocked) return -1
            if (!a.unlocked && b.unlocked) return  1
            return b.unlockedAt - a.unlockedAt
        })
        return result
    }

    // ── Summary counts ────────────────────────────────────────────────────────
    readonly property int totalAch: keyTracker?.achievements?.length ?? 0
    readonly property int unlockedCount: {
        if (!keyTracker) return 0
        const state = keyTracker.unlockedAch ?? {}
        return Object.keys(state).filter(id => !!state[id]?.unlockedAt).length
    }

    // ════════════════════════════════════════════════════════════════════════
    //  HEADER
    // ════════════════════════════════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true

        Text {
            text: "🏆 Achievementy"
            color: Color.mOnSurface
            font.pointSize: Style.fontSizeM
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }

        Text {
            text: unlockedCount + " / " + totalAch
            color: Color.mPrimary
            font.pointSize: Style.fontSizeM
            font.weight: Font.Bold
        }
    }

    // Progress bar
    Rectangle {
        Layout.fillWidth: true
        height: 8
        radius: 4
        color: Color.mSurfaceVariant

        Rectangle {
            width: totalAch > 0 ? parent.width * (unlockedCount / totalAch) : 0
            height: parent.height
            radius: parent.radius
            color: Color.mPrimary
            Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        }
    }

    // ── Tier filter chips ─────────────────────────────────────────────────────
    Row {
        Layout.fillWidth: true
        spacing: Style.marginS
        height: 30

        // "Vše" chip
        Rectangle {
            width: allChipText.implicitWidth + Style.marginM * 2
            height: 28
            radius: height / 2
            color: root.filterTier === -1 ? Color.mPrimary : Color.mSurfaceVariant

            Text {
                id: allChipText
                anchors.centerIn: parent
                text: "Vše"
                color: root.filterTier === -1 ? Color.mOnPrimary : Color.mOnSurfaceVariant
                font.pointSize: Style.fontSizeS
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.filterTier = -1
            }
        }

        Repeater {
            model: root.tierMeta

            Rectangle {
                required property var modelData
                required property int index
                width: chipLabel.implicitWidth + Style.marginM * 2
                height: 28
                radius: height / 2
                color: root.filterTier === index ? modelData.color : Color.mSurfaceVariant

                Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: modelData.name
                    color: root.filterTier === index ? "#000" : modelData.color
                    font.pointSize: Style.fontSizeS
                    font.weight: Font.Medium
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.filterTier = (root.filterTier === index ? -1 : index)
                }
            }
        }

        // Spacer + toggle locked
        Item { width: Style.marginM }

        Rectangle {
            width: toggleText.implicitWidth + Style.marginM * 2
            height: 28
            radius: height / 2
            color: root.showLocked ? Color.mSurfaceVariant : Color.mTertiary

            Text {
                id: toggleText
                anchors.centerIn: parent
                text: root.showLocked ? "🔒 Skrýt zamčené" : "🔒 Ukázat zamčené"
                color: root.showLocked ? Color.mOnSurfaceVariant : Color.mOnTertiary ?? Color.mOnPrimary
                font.pointSize: Style.fontSizeS
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showLocked = !root.showLocked
            }
        }
    }

    NDivider { Layout.fillWidth: true }

    // ════════════════════════════════════════════════════════════════════════
    //  ACHIEVEMENT GRID
    // ════════════════════════════════════════════════════════════════════════
    // We build a flat list and use a Flow for multi-column layout
    Flow {
        Layout.fillWidth: true
        spacing: Style.marginM

        Repeater {
            model: root.buildList()

            Rectangle {
                required property var modelData
                readonly property var tier: root.tierMeta[modelData.tier] ?? root.tierMeta[0]
                readonly property bool unlocked: modelData.unlocked

                width: (root.width - Style.marginM) / 2 - Style.marginM
                height: achCard.implicitHeight + Style.marginM * 2
                radius: Style.radiusM ?? 8

                color: unlocked ? Qt.rgba(
                    parseInt(tier.bg.slice(1,3), 16)/255,
                    parseInt(tier.bg.slice(3,5), 16)/255,
                    parseInt(tier.bg.slice(5,7), 16)/255,
                    0.9
                ) : Color.mSurfaceVariant

                border.color: unlocked ? tier.color : Color.mOutline ?? Color.mSurfaceVariant
                border.width: unlocked ? 2 : 1

                opacity: unlocked ? 1.0 : 0.45

                Behavior on opacity { NumberAnimation { duration: 300 } }

                // Tier stripe on left edge
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 4
                    radius: parent.radius
                    color: tier.color
                    opacity: unlocked ? 1.0 : 0.4
                }

                RowLayout {
                    id: achCard
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginM; leftMargin: Style.marginM + 6 }
                    spacing: Style.marginS

                    // Icon
                    Text {
                        text: unlocked ? modelData.icon : "🔒"
                        font.pointSize: Style.fontSizeL
                    }

                    // Text content
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: modelData.title
                            color: unlocked ? Color.mOnSurface : Color.mOnSurfaceVariant
                            font.pointSize: Style.fontSizeS
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.desc
                            color: unlocked ? Color.mOnSurfaceVariant : Qt.rgba(
                                Color.mOnSurfaceVariant.r,
                                Color.mOnSurfaceVariant.g,
                                Color.mOnSurfaceVariant.b, 0.6)
                            font.pointSize: Style.fontSizeXS
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }

                        // Tier badge
                        Text {
                            text: tier.name
                            color: tier.color
                            font.pointSize: Style.fontSizeXS
                            font.weight: Font.Bold
                            opacity: 0.8
                        }
                    }
                }

                // "New" glow for recently unlocked (within last 60s)
                Rectangle {
                    visible: unlocked && (Date.now() - modelData.unlockedAt < 60000)
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.color: tier.color
                    border.width: 3

                    SequentialAnimation on opacity {
                        running: parent.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.2; duration: 700 }
                        NumberAnimation { from: 0.2; to: 1.0; duration: 700 }
                    }
                }
            }
        }

        // Empty state
        Text {
            visible: root.buildList().length === 0
            text: root.showLocked ? "Zatím žádné achievementy 😸" : "Všechna splněná jsou skrytá nebo žádná nezískaná."
            color: Color.mOnSurfaceVariant
            font.pointSize: Style.fontSizeM
            width: root.width
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Bottom padding
    Item { height: Style.marginL }
}
