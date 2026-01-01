import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Rectangle {
    id: sidebar
    width: 320 // Widened for Russian/German support
    
    property int currentIndex: 0
    // i18n Fix: Use ListModel for dynamic translation instead of static array
    property var menuItems: [qsTr("SYSTEM INFO"), qsTr("FAN CONTROL"), qsTr("AURA SYNC"), qsTr("BATTERY")]
    property var menuColors: ["#00bcd4", "#ff9800", "#9b59b6", "#2ecc71"]
    property var theme
    
    // Premium gradient background
    gradient: Gradient {
        GradientStop { position: 0.0; color: theme.isDark ? "#0a0a0f" : "#f8f9fa" }
        GradientStop { position: 0.5; color: theme.isDark ? "#0d0d14" : "#ffffff" }
        GradientStop { position: 1.0; color: theme.isDark ? "#080810" : "#f0f2f5" }
    }
    
    // Subtle right border glow
    Rectangle {
        width: 1
        height: parent.height
        anchors.right: parent.right
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.3; color: theme.isDark ? Qt.rgba(0, 120/255, 212/255, 0.3) : theme.border }
            GradientStop { position: 0.7; color: theme.isDark ? Qt.rgba(0, 120/255, 212/255, 0.3) : theme.border }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 0
        
        // ═══════════════════════════════════════════════════════════
        // LOGO SECTION - Premium Brand Display
        // ═══════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            Layout.bottomMargin: 20
            color: "transparent"
            
            // Glassmorphic background
            Rectangle {
                anchors.fill: parent
                anchors.margins: -10
                radius: 16
                color: theme.isDark ? Qt.rgba(1, 1, 1, 0.03) : Qt.rgba(0, 0, 0, 0.02)
                border.width: 1
                border.color: theme.isDark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.05)
            }
            
            RowLayout {
                anchors.centerIn: parent
                spacing: 16
                
                // Animated Logo Container
                Rectangle {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    radius: 14
                    color: Qt.rgba(0, 120/255, 212/255, 0.15)
                    border.width: 2
                    border.color: Qt.rgba(0, 120/255, 212/255, 0.4)
                    
                    // Inner glow
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 11
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(0, 212/255, 255/255, 0.2)
                    }
                    
                    Image {
                        source: "qrc:/ui/app_icon.png"
                        anchors.centerIn: parent
                        sourceSize.width: 40
                        sourceSize.height: 40
                        width: 40
                        height: 40
                        smooth: true
                        
                        // Subtle pulse animation
                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 1.05; duration: 2000; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1.05; to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                        }
                    }
                }
                
                ColumnLayout {
                    spacing: 4
                    
                    // Brand Name with Gradient Effect
                    Text {
                        text: "ASUS TUF"
                        font.weight: Font.Black
                        font.pixelSize: 24
                        font.letterSpacing: 3
                        color: theme.isDark ? "#00d4ff" : "#0078d4"
                    }
                    
                    Row {
                        spacing: 8
                        
                        // Accent line
                        Rectangle {
                            width: 24
                            height: 2
                            radius: 1
                            color: theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: qsTr("CONTROLLER")
                            color: theme.textTertiary
                            font.weight: Font.Bold
                            font.pixelSize: 10
                            font.letterSpacing: 4
                        }
                    }
                }
            }
        }
        
        // Navigation Separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.bottomMargin: 16
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.2; color: theme.isDark ? Qt.rgba(0, 180/255, 255/255, 0.3) : theme.divider }
                GradientStop { position: 0.8; color: theme.isDark ? Qt.rgba(0, 180/255, 255/255, 0.3) : theme.divider }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        
        // ═══════════════════════════════════════════════════════════
        // NAVIGATION LIST - Premium Menu Items
        // ═══════════════════════════════════════════════════════════
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8
            Layout.bottomMargin: 16
            model: menuItems
            interactive: false
            spacing: 8
            
            delegate: ItemDelegate {
                id: navItem
                width: ListView.view.width
                height: 58
                
                property bool selected: sidebar.currentIndex === index
                property color accentColor: menuColors[index]
                property color itemColor: selected ? "#ffffff" : (hovered ? "#ffffff" : theme.textPrimary)
                
                // Premium hover animation - bring it forward prominently
                scale: hovered ? 1.08 : 1.0
                z: hovered ? 100 : 0
                
                Behavior on scale {
                    NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                }
                
                background: Rectangle {
                    radius: 14
                    
                    // Multi-layer background
                    gradient: {
                        if (selected) {
                            return selectedGradient
                        } else if (hovered) {
                            return hoverGradient
                        }
                        return null
                    }
                    color: (selected || hovered) ? "transparent" : "transparent"
                    
                    Gradient {
                        id: selectedGradient
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: navItem.accentColor }
                        GradientStop { position: 1.0; color: Qt.darker(navItem.accentColor, 1.3) }
                    }
                    
                    Gradient {
                        id: hoverGradient
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: navItem.accentColor }
                        GradientStop { position: 1.0; color: Qt.darker(navItem.accentColor, 1.2) }
                    }
                    
                    border.width: 1 // Always show border
                    border.color: selected ? Qt.rgba(1, 1, 1, 0.4) : (hovered ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(navItem.accentColor.r, navItem.accentColor.g, navItem.accentColor.b, 0.3))
                    
                    Behavior on border.width { NumberAnimation { duration: 150 } }
                    
                    // Left accent bar for selected
                    Rectangle {
                        visible: selected
                        width: 4
                        height: parent.height - 16
                        anchors.left: parent.left
                        anchors.leftMargin: 0
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 2
                        color: "#ffffff"
                        
                        // Glow effect
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: 4
                            color: "#ffffff"
                            opacity: 0.3
                        }
                    }
                    
                    // Right indicator dot
                    Rectangle {
                        visible: selected
                        width: 8
                        height: 8
                        radius: 4
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#ffffff"
                        
                        SequentialAnimation on opacity {
                            running: selected
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 800 }
                            NumberAnimation { to: 1.0; duration: 800 }
                        }
                    }
                }
                
                contentItem: RowLayout {
                    spacing: 16
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    
                    // Icon Container with colored background
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignVCenter
                        radius: 10
                        color: (selected || hovered) ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(navItem.accentColor.r, navItem.accentColor.g, navItem.accentColor.b, 0.1)
                        border.width: (selected || hovered) ? 0 : 1
                        border.color: Qt.rgba(navItem.accentColor.r, navItem.accentColor.g, navItem.accentColor.b, 0.2)
                        
                        // Icons
                        Item {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            
                            // SYSTEM INFO Icon
                            Grid {
                                visible: index === 0
                                anchors.centerIn: parent
                                columns: 2
                                spacing: 3
                                Repeater {
                                    model: 4
                                    Rectangle {
                                        width: 7; height: 7
                                        radius: 2
                                        color: (navItem.selected || navItem.hovered) ? "#ffffff" : navItem.accentColor
                                    }
                                }
                            }
                            
                            // FAN CONTROL Icon
                            Canvas {
                                visible: index === 1
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.fillStyle = (navItem.selected || navItem.hovered) ? "#ffffff" : navItem.accentColor;
                                    var cx = width/2; var cy = height/2;
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, 3, 0, Math.PI*2);
                                    ctx.fill();
                                    for(var i=0; i<3; i++) {
                                        ctx.save();
                                        ctx.translate(cx, cy);
                                        ctx.rotate(i * (Math.PI*2/3));
                                        ctx.beginPath();
                                        ctx.moveTo(0,0);
                                        ctx.quadraticCurveTo(4, -4, 8, -2);
                                        ctx.quadraticCurveTo(9, 2, 5, 3);
                                        ctx.fill();
                                        ctx.restore();
                                    }
                                }
                                property bool sel: navItem.selected
                                property bool hov: navItem.hovered
                                onSelChanged: requestPaint()
                                onHovChanged: requestPaint()
                            }
                            
                            // AURA SYNC Icon
                            Canvas {
                                visible: index === 2
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.fillStyle = (navItem.selected || navItem.hovered) ? "#ffffff" : navItem.accentColor;
                                    var cx = width/2; var cy = height/2;
                                    ctx.beginPath();
                                    ctx.moveTo(cx, 2);
                                    ctx.quadraticCurveTo(cx+2, cy-2, cx+8, cy);
                                    ctx.quadraticCurveTo(cx+2, cy+2, cx, cy+8);
                                    ctx.quadraticCurveTo(cx-2, cy+2, cx-8, cy);
                                    ctx.quadraticCurveTo(cx-2, cy-2, cx, 2);
                                    ctx.fill();
                                }
                                property bool sel: navItem.selected
                                property bool hov: navItem.hovered
                                onSelChanged: requestPaint()
                                onHovChanged: requestPaint()
                            }
                            
                            // BATTERY Icon
                            Item {
                                visible: index === 3
                                anchors.fill: parent
                                Rectangle {
                                    width: 12; height: 16
                                    x: (parent.width - width)/2
                                    y: 3
                                    color: "transparent"
                                    border.width: 2
                                    border.color: (navItem.selected || navItem.hovered) ? "#ffffff" : navItem.accentColor
                                    radius: 3
                                }
                                Rectangle {
                                    width: 5; height: 3
                                    x: (parent.width - width)/2
                                    y: 1
                                    color: (navItem.selected || navItem.hovered) ? "#ffffff" : navItem.accentColor
                                    radius: 1
                                }
                                Rectangle {
                                    width: 6; height: 10
                                    x: (parent.width - width)/2
                                    y: 7
                                    color: (navItem.selected || navItem.hovered) ? "#ffffff" : navItem.accentColor
                                    radius: 1
                                }
                            }
                        }
                    }
                    
                    Text {
                        text: modelData
                        color: navItem.itemColor
                        font.weight: Font.Bold
                        font.pixelSize: 13
                        font.letterSpacing: 1.0
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        verticalAlignment: Text.AlignVCenter
                        
                        // Adaptive Text
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 9 // Slightly smaller min size for wrapping
                        elide: Text.ElideRight
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
                
                onClicked: sidebar.currentIndex = index
            }
        }
        
        // Bottom Separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 8
            Layout.bottomMargin: 20
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.2; color: theme.isDark ? Qt.rgba(0, 180/255, 255/255, 0.2) : theme.divider }
                GradientStop { position: 0.8; color: theme.isDark ? Qt.rgba(0, 180/255, 255/255, 0.2) : theme.divider }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        
        // ═══════════════════════════════════════════════════════════
        // THEME TOGGLE - Premium Switch
        // ═══════════════════════════════════════════════════════════
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 16
            
            Button {
                id: themeToggle
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                flat: true
                hoverEnabled: true
                
                scale: hovered ? 1.08 : 1.0
                z: hovered ? 100 : 0
                Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                }
                
                background: Rectangle {
                    radius: 12
                    color: themeToggle.hovered ? "#ffd700" : (theme.isDark ? "#18181c" : "#f5f5f7")
                    border.width: themeToggle.hovered ? 2 : 1
                    border.color: themeToggle.hovered ? "#ffed4a" : (theme.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08))
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }
                }
                
                contentItem: RowLayout {
                    anchors.fill: parent
                    spacing: 10
                    
                    Item { Layout.fillWidth: true }
                    
                    // Sun/Moon Icon - using styled text for visibility
                    Text {
                        text: theme.isDark ? "☽" : "☀"
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        color: themeToggle.hovered ? "#1a1a1a" : (theme.isDark ? "#ffd700" : "#ff9800")
                        Layout.alignment: Qt.AlignVCenter
                    }
                    
                    Text {
                        text: theme.isDark ? qsTr("Dark Mode") : qsTr("Light Mode")
                        color: themeToggle.hovered ? "#1a1a1a" : theme.textPrimary
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        font.letterSpacing: 1.0
                        Layout.alignment: Qt.AlignVCenter
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    
                    Item { Layout.fillWidth: true }
                }
                
                onClicked: theme.toggle()
            }
            
            // Version Badge
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: versionText.width + 20
                height: 24
                radius: 12
                color: theme.isDark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.03)
                border.width: 1
                border.color: theme.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
                
                Text {
                    id: versionText
                    anchors.centerIn: parent
                    text: "v1.0.0"
                    color: theme.textTertiary
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                    font.weight: Font.Medium
                }
            }
        }
    }
}
