import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import ".."

Item {
    id: fanPage
    
    property var backend
    property var theme
    
    // Timer to refresh stats (syncs with Dashboard)
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: backend.statsUpdated()
    }

    // Clean background - no floating orbs
    
    Flickable {
        id: pageFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, mainColumn.implicitHeight + 60)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        
        // Vertical centering wrapper
        Item {
            id: centerWrapper
            width: pageFlickable.width
            height: Math.max(pageFlickable.height, mainColumn.implicitHeight + 60)
            
            ColumnLayout {
                id: mainColumn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                
                width: Math.min(800, parent.width - 40)
                spacing: 24
        
        // ══════════════════════════════════════════════════════════════
        // SECTION 1: PAGE HEADER - Premium Gradient Card
        // ══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            height: 100
            radius: 16
            color: "transparent"
            
            // Gradient background (blue to cyan theme)
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0, 120/255, 212/255, 0.15) }
                    GradientStop { position: 0.5; color: Qt.rgba(0, 180/255, 220/255, 0.1) }
                    GradientStop { position: 1.0; color: Qt.rgba(59/255, 130/255, 246/255, 0.15) }
                }
                border.width: 1
                border.color: theme.isDark ? Qt.rgba(255,255,255,0.1) : Qt.rgba(0,0,0,0.05)
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20
            
                // Fan Icon with animated rotation
                Item {
                    width: 64; height: 64
                    Layout.alignment: Qt.AlignVCenter
                    
                    Canvas {
                        id: fanIcon
                        anchors.fill: parent
                        
                        property real rotation: 0
                        property color iconColor: theme.accent
                        
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.translate(width/2, height/2);
                            ctx.rotate(rotation * Math.PI / 180);
                            ctx.translate(-width/2, -height/2);
                            
                            ctx.fillStyle = iconColor;
                            var cx = width/2; var cy = height/2;
                            
                            // Hub
                            ctx.beginPath();
                            ctx.arc(cx, cy, 8, 0, Math.PI*2);
                            ctx.fill();
                            
                            // 3 Curved Blades (larger, no outer ring)
                            for(var i=0; i<3; i++) {
                                ctx.save();
                                ctx.translate(cx, cy);
                                ctx.rotate(i * (Math.PI*2/3));
                                ctx.beginPath();
                                ctx.moveTo(0, 0);
                                ctx.quadraticCurveTo(14, -16, 28, -5);
                                ctx.quadraticCurveTo(30, 6, 16, 11);
                                ctx.closePath();
                                ctx.fill();
                                ctx.restore();
                            }
                        }
                        
                        // Rotation animation - continuous smooth rotation
                        NumberAnimation on rotation {
                            running: true
                            from: 0; to: 360
                            duration: 2500
                            loops: Animation.Infinite
                            easing.type: Easing.Linear
                        }
                        
                        onRotationChanged: requestPaint()
                        onIconColorChanged: requestPaint()
                    }
                }
                
                ColumnLayout {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        text: "FAN CONTROL"
                        color: theme ? theme.accent : "#0078d4"
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        font.letterSpacing: 2
                    }
                    Text {
                        text: backend.isManualModeActive ? "Manual Override Active" : "Automatic Mode"
                        color: backend.isManualModeActive ? theme.accent : Qt.rgba(0, 180/255, 220/255, 0.8)
                        font.pixelSize: 12
                        font.letterSpacing: 0.5
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // Status Badge
                Rectangle {
                    width: Math.max(100, statusRow.width + 24)
                    height: 32
                    radius: 16
                    color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.15)
                    border.width: 1
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.3)
                    
                    Row {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 8
                        
                        Rectangle {
                            width: 8; height: 8
                            radius: 4
                            color: backend.isManualModeActive ? "#FF9800" : "#4CAF50"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: backend.isManualModeActive ? "MANUAL" : "AUTO"
                            color: theme.textSecondary
                            font.bold: true
                            font.pixelSize: 11
                            font.letterSpacing: 0.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
        
        // ══════════════════════════════════════════════════════════════
        // SECTION 2: DUAL FAN GAUGES (Premium Card)
        // ══════════════════════════════════════════════════════════════
        Rectangle {
            id: gaugesCard
            Layout.fillWidth: true
            Layout.preferredHeight: 380
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.7)
            radius: 16
            border.width: 1
            border.color: theme.isDark ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.08)
            
            // Gradient overlay
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.03) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            
            // Centered gauge layout
            RowLayout {
                anchors.centerIn: parent
                spacing: 40
                
                // CPU Fan Gauge
                ColumnLayout {
                    spacing: 10
                    
                    CircularGauge {
                        Layout.alignment: Qt.AlignHCenter
                        width: 220
                        height: 220
                        value: backend.cpuFanRpm
                        maxValue: 6000
                        text: backend.cpuFanRpm + " RPM"
                        subText: "CPU FAN"
                        progressColor: theme ? theme.accent : "#0078d4"
                        appTheme: theme
                    }
                    
                    // CPU Temperature Display
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        
                        Text {
                            text: "🌡"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: backend.cpuTemp + "°C"
                            font.pixelSize: 16
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                            color: {
                                var temp = backend.cpuTemp
                                if (temp >= 85) return "#ff4757"
                                if (temp >= 70) return "#ffa502"
                                if (temp >= 55) return "#2ed573"
                                return "#1e90ff"
                            }
                        }
                    }
                    
                    // Passive Cooling Indicator
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: backend.cpuFanRpm === 0 && fanSlider.value < 66 && backend.isManualModeActive
                        text: "PASSIVE (0 dB)"
                        color: theme.textTertiary
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }
                
                // Divider
                Rectangle {
                    width: 1
                    height: 180
                    color: theme.divider
                }
                
                // GPU Fan Gauge
                ColumnLayout {
                    spacing: 10
                    
                    CircularGauge {
                        Layout.alignment: Qt.AlignHCenter
                        width: 220
                        height: 220
                        value: backend.gpuFanRpm
                        maxValue: 6000
                        text: backend.gpuFanRpm + " RPM"
                        subText: "GPU FAN"
                        progressColor: "#448aff"
                        appTheme: theme
                    }
                    
                    // GPU Temperature Display
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        
                        Text {
                            text: "🌡"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: backend.gpuTemp + "°C"
                            font.pixelSize: 16
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                            color: {
                                var temp = backend.gpuTemp
                                if (temp >= 85) return "#ff4757"
                                if (temp >= 70) return "#ffa502"
                                if (temp >= 55) return "#2ed573"
                                return "#1e90ff"
                            }
                        }
                    }

                    // Passive Cooling Indicator
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: backend.gpuFanRpm === 0 && fanSlider.value < 66 && backend.isManualModeActive
                        text: "PASSIVE (0 dB)"
                        color: theme.textTertiary
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }
            }
        }
        
        // ══════════════════════════════════════════════════════════════
        // SECTION 3: CONTROL PANEL (Premium Card)
        // ══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: controlColumn.implicitHeight + 56 // Auto-fit content + padding
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.85)
            radius: 16
            border.width: 1
            border.color: theme.isDark ? Qt.rgba(1,1,1,0.1) : Qt.rgba(0,0,0,0.1)
            
            ColumnLayout {
                id: controlColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 28
                spacing: 24
                
                // ────────────────────────────────────────────────────────
                // Toggle Row with Premium Switch
                // ────────────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    
                    ColumnLayout {
                        spacing: 2
                        Text { 
                            text: "MANUAL MODE"
                            color: "#e74c3c"
                            font.bold: true
                            font.pixelSize: 15
                            font.letterSpacing: 1.5
                        }
                        Text {
                            text: "Override automatic fan curves"
                            color: theme.textTertiary
                            font.pixelSize: 11
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Premium Toggle Switch
                    Rectangle {
                        width: 56; height: 30
                        radius: 15
                        color: backend.isManualModeActive ? theme.accent : (theme.isDark ? "#333" : "#ccc")
                        border.width: 2
                        border.color: backend.isManualModeActive ? theme.accent : (theme.isDark ? "#444" : "#bbb")
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        
                        Rectangle {
                            x: backend.isManualModeActive ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24; height: 24
                            radius: 12
                            color: "white"
                            
                            // Inner glow when active
                            Rectangle {
                                visible: backend.isManualModeActive
                                anchors.centerIn: parent
                                width: 10; height: 10; radius: 5
                                color: theme.accent
                            }
                            
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.isManualModeActive ? backend.enableAutoMode() : backend.setFanSpeed(0) // Start in Silent mode
                        }
                    }
                }
                
                // ────────────────────────────────────────────────────────
                // Speed Slider Section
                // ────────────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: sliderContent.height + 30
                    radius: 12
                    color: theme.isDark ? Qt.rgba(0,0,0,0.3) : Qt.rgba(0,0,0,0.05)
                    opacity: backend.isManualModeActive ? 1.0 : 0.4
                    
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    
                    ColumnLayout {
                        id: sliderContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 15
                        spacing: 12
                        enabled: backend.isManualModeActive
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Text { 
                                text: "Target Fan Speed"
                                color: theme.textSecondary
                                font.pixelSize: 13
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            // Premium Value Badge
                            Rectangle {
                                width: 70; height: 32
                                radius: 8
                                color: theme.accent
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: fanSlider.value.toFixed(0) + "%"
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: 16
                                }
                            }
                        }
                        
                        // Premium Slider
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            
                            Slider {
                                id: fanSlider
                                anchors.fill: parent
                                from: 0; to: 100; value: 0
                                
                                background: Rectangle {
                                    x: fanSlider.leftPadding
                                    y: fanSlider.topPadding + fanSlider.availableHeight / 2 - height / 2
                                    width: fanSlider.availableWidth
                                    height: 10
                                    radius: 5
                                    color: theme.isDark ? "#1a1a1a" : "#e0e0e0"
                                    
                                    // Progress with gradient
                                    Rectangle {
                                        width: fanSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: 5
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: "#00E676" }
                                            GradientStop { position: 0.5; color: "#FF9100" }
                                            GradientStop { position: 1.0; color: "#FF1744" }
                                        }
                                    }
                                    
                                    // Tick marks
                                    Row {
                                        anchors.fill: parent
                                        Repeater {
                                            model: 5
                                            Rectangle {
                                                x: index * (parent.width / 4) - 1
                                                width: 2
                                                height: parent.height
                                                color: Qt.rgba(1,1,1, index === 0 ? 0 : 0.3)
                                            }
                                        }
                                    }
                                }
                                
                                handle: Rectangle {
                                    x: fanSlider.leftPadding + fanSlider.visualPosition * (fanSlider.availableWidth - width)
                                    y: fanSlider.topPadding + fanSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 28; implicitHeight: 28
                                    radius: 14
                                    color: "white"
                                    border.width: 3
                                    border.color: {
                                        var pos = fanSlider.value / 100;
                                        if (pos < 0.33) return "#00E676";
                                        if (pos < 0.66) return "#FF9100";
                                        return "#FF1744";
                                    }
                                    
                                    // Inner dot
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 8; height: 8; radius: 4
                                        color: parent.border.color
                                    }
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                preventStealing: true
                                function update(xVal) { fanSlider.value = Math.round(Math.max(0, Math.min(1, xVal/width))*100) }
                                onPressed: update(mouseX)
                                onPositionChanged: update(mouseX)
                                onReleased: backend.setFanSpeed(fanSlider.value)
                            }
                        }
                        
                        // Scale Labels
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "0%"; color: theme.textTertiary; font.pixelSize: 10 }
                            Item { Layout.fillWidth: true }
                            Text { text: "25%"; color: theme.textTertiary; font.pixelSize: 10 }
                            Item { Layout.fillWidth: true }
                            Text { text: "50%"; color: theme.textTertiary; font.pixelSize: 10 }
                            Item { Layout.fillWidth: true }
                            Text { text: "75%"; color: theme.textTertiary; font.pixelSize: 10 }
                            Item { Layout.fillWidth: true }
                            Text { text: "100%"; color: theme.textTertiary; font.pixelSize: 10 }
                        }
                    }
                }
                
                // ────────────────────────────────────────────────────────
                // Preset Buttons (Distinct Colors)
                // ────────────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    opacity: backend.isManualModeActive ? 1.0 : 0.4
                    
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    
                    Repeater {
                        model: [ 
                            {l:"SILENT", v:0, icon:"○", c:"#2ecc71"}, 
                            {l:"BALANCED", v:60, icon:"◐", c:"#f39c12"}, 
                            {l:"TURBO", v:100, icon:"●", c:"#e74c3c"} 
                        ]
                        
                        delegate: Button {
                            id: presetBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            
                            property bool isActive: fanSlider.value === modelData.v
                            property string btnColor: modelData.c
                            enabled: backend.isManualModeActive
                            hoverEnabled: enabled

                            scale: (hovered && enabled) ? 1.05 : (isActive ? 1.02 : 1.0)
                            z: hovered ? 15 : (isActive ? 5 : 1)
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                            background: Rectangle {
                                color: {
                                    if (!presetBtn.enabled) return theme.isDark ? "#151515" : "#e5e5e5"
                                    if (presetBtn.isActive) return presetBtn.btnColor
                                    if (presetBtn.hovered) return presetBtn.btnColor
                                    return theme.isDark ? "#1e1e1e" : "#f0f0f0"
                                }
                                
                                radius: 12
                                
                                border.color: {
                                    if (!presetBtn.enabled) return theme.isDark ? "#222" : "#ddd"
                                    if (presetBtn.isActive || presetBtn.hovered) return presetBtn.btnColor
                                    return theme.isDark ? "#333" : "#ccc"
                                }
                                border.width: (presetBtn.isActive || presetBtn.hovered) ? 0 : 2
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                
                                // Glow
                                Rectangle {
                                    visible: presetBtn.hovered && presetBtn.enabled
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    radius: 14
                                    color: "transparent"
                                    border.color: presetBtn.btnColor
                                    border.width: 2
                                    opacity: 0.35
                                    z: -1
                                }
                            }
                            
                            contentItem: Column {
                                anchors.centerIn: parent
                                spacing: 2
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.icon
                                    color: {
                                        if (!presetBtn.enabled) return theme.isDark ? "#444" : "#aaa"
                                        if (presetBtn.isActive || presetBtn.hovered) return "white"
                                        return presetBtn.btnColor
                                    }
                                    font.pixelSize: 18
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.l
                                    color: {
                                        if (!presetBtn.enabled) return theme.isDark ? "#444" : "#aaa"
                                        if (presetBtn.isActive || presetBtn.hovered) return "white"
                                        return theme.textSecondary
                                    }
                                    font.bold: true
                                    font.pixelSize: 12
                                    font.letterSpacing: 1.2
                                }
                            }
                            
                            onClicked: {
                                if (!enabled) return;
                                fanSlider.value = modelData.v
                                backend.setFanSpeed(modelData.v)
                            }

                        }
                    }
                }

                
                // Status Message Display (Premium Dynamic Pill)
                Item {
                    Layout.fillWidth: true
                    height: 54
                    Layout.topMargin: 12
                    
                    Rectangle {
                        id: statusPill
                        anchors.centerIn: parent
                        width: statusUiRow.implicitWidth + 48
                        height: 44
                        radius: 22
                        
                        // Dynamic Mode Icon (matches buttons)
                        property string modeIcon: {
                            if (fanSlider.value < 34) return "○"  // Silent
                            if (fanSlider.value < 67) return "◐"  // Balanced
                            return "●"  // Turbo
                        }
                        
                        // Dynamic Color Logic
                        property color activeColor: {
                            if (fanSlider.value < 34) return "#2ecc71" // Silent Green
                            if (fanSlider.value < 67) return "#f39c12" // Balanced Orange
                            return "#e74c3c" // Turbo Red
                        }
                        
                        // Gradient darker shade
                        property color darkColor: Qt.darker(activeColor, 1.15)

                        // Gradient Background
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: backend.isManualModeActive ? statusPill.activeColor : "transparent" }
                            GradientStop { position: 1.0; color: backend.isManualModeActive ? statusPill.darkColor : "transparent" }
                        }
                        
                        // Subtle inner border for depth
                        border.width: backend.isManualModeActive ? 1 : 0
                        border.color: Qt.lighter(activeColor, 1.3)
                        
                        // Animate appearance
                        opacity: backend.isManualModeActive ? 1.0 : 0.0
                        scale: backend.isManualModeActive ? 1.0 : 0.95
                        
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        
                        RowLayout {
                            id: statusUiRow
                            anchors.centerIn: parent
                            spacing: 10
                            
                            // Dynamic Mode Icon
                            Text {
                                text: statusPill.modeIcon
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
                                visible: backend.isManualModeActive
                                Layout.alignment: Qt.AlignVCenter
                            }
                            
                            // Status Text
                            Text {
                                text: backend.statusMessage
                                color: "white"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.3
                                visible: backend.isManualModeActive
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }
            } // End control column
        } // End control panel Rectangle
            } // End ColumnLayout
        } // End centerWrapper Item
    } // End Flickable
} // End fanPage Item
