import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import ".."

Item {
    id: batteryPage
    
    property var monitor
    property var theme
    
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
            
            // Gradient background (green theme for battery)
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(46/255, 204/255, 113/255, 0.15) }
                    GradientStop { position: 0.5; color: Qt.rgba(0/255, 217/255, 165/255, 0.1) }
                    GradientStop { position: 1.0; color: Qt.rgba(46/255, 180/255, 100/255, 0.15) }
                }
                border.width: 1
                border.color: theme.isDark ? Qt.rgba(255,255,255,0.1) : Qt.rgba(0,0,0,0.05)
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20
            
                // Premium Animated Battery Icon
                Item {
                    width: 64; height: 64
                    Layout.alignment: Qt.AlignVCenter
                    
                    // Pulsating outer glow rings
                    Repeater {
                        model: 3
                        Rectangle {
                            id: glowRing
                            anchors.centerIn: parent
                            width: 44 + (index * 8); height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: Qt.rgba(46/255, 204/255, 113/255, 0.3 - (index * 0.1))
                            
                            property real pulseScale: 1.0
                            
                            SequentialAnimation on pulseScale {
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.15; duration: 1000 + (index * 200); easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 1000 + (index * 200); easing.type: Easing.InOutSine }
                            }
                            
                            transform: Scale { 
                                origin.x: glowRing.width / 2
                                origin.y: glowRing.height / 2
                                xScale: glowRing.pulseScale
                                yScale: glowRing.pulseScale
                            }
                        }
                    }
                    
                    // Battery body
                    Rectangle {
                        id: batteryBody
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 3
                        width: 26; height: 36
                        radius: 5
                        color: "transparent"
                        border.width: 2.5
                        border.color: monitor.batteryPercent > 20 ? "#2ecc71" : "#FF1744"
                        
                        // Battery fill
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.margins: 4
                            width: parent.width - 8
                            height: Math.max(2, (parent.height - 8) * (monitor.batteryPercent / 100))
                            radius: 3
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: monitor.batteryPercent > 20 ? "#00d9a5" : "#ff6b6b" }
                                GradientStop { position: 1.0; color: monitor.batteryPercent > 20 ? "#2ecc71" : "#FF1744" }
                            }
                            Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                        }
                        
                        // Lightning bolt when charging
                        Canvas {
                            anchors.centerIn: parent
                            width: 12; height: 16
                            visible: monitor.isCharging
                            
                            property real boltGlow: 0.8
                            SequentialAnimation on boltGlow {
                                loops: Animation.Infinite
                                running: monitor.isCharging
                                NumberAnimation { to: 1.0; duration: 400 }
                                NumberAnimation { to: 0.6; duration: 400 }
                            }
                            
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.fillStyle = Qt.rgba(1, 1, 1, boltGlow);
                                ctx.beginPath();
                                ctx.moveTo(7, 0); ctx.lineTo(2, 7); ctx.lineTo(5, 7);
                                ctx.lineTo(4, 16); ctx.lineTo(10, 6); ctx.lineTo(7, 6);
                                ctx.closePath(); ctx.fill();
                            }
                            onBoltGlowChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                        }
                    }
                    
                    // Battery cap
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height / 2 - 18
                        width: 12; height: 5
                        radius: 2
                        color: monitor.batteryPercent > 20 ? "#2ecc71" : "#FF1744"
                    }
                }
                
                ColumnLayout {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        text: "BATTERY MANAGEMENT"
                        color: "#2ecc71"
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        font.letterSpacing: 2
                    }
                    Text {
                        text: monitor.isCharging ? "Charging • " + monitor.batteryPercent + "%" : "On Battery • " + monitor.batteryPercent + "%"
                        color: monitor.isCharging ? Qt.rgba(0, 217/255, 165/255, 0.9) : Qt.rgba(255/255, 152/255, 0, 0.8)
                        font.pixelSize: 12
                        font.letterSpacing: 0.5
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // Status Badge
                Rectangle {
                    Layout.preferredWidth: statusRow.width + 28
                    Layout.preferredHeight: 34
                    radius: 17
                    color: monitor.isCharging ? Qt.rgba(46/255, 204/255, 113/255, 0.15) : Qt.rgba(255/255, 152/255, 0/255, 0.15)
                    border.width: 1
                    border.color: monitor.isCharging ? Qt.rgba(46/255, 204/255, 113/255, 0.4) : Qt.rgba(255/255, 152/255, 0/255, 0.4)
                    
                    Row {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 8
                        
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: monitor.isCharging ? "#2ecc71" : "#FF9800"
                            
                            SequentialAnimation on opacity {
                                running: monitor.isCharging
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600 }
                                NumberAnimation { to: 1.0; duration: 600 }
                            }
                        }
                        Text {
                            text: monitor.isCharging ? "CHARGING" : "DISCHARGING"
                            color: monitor.isCharging ? "#2ecc71" : "#FF9800"
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1.2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
        
        // ══════════════════════════════════════════════════════════════
        // SECTION 2: BATTERY STATUS CARD
        // ══════════════════════════════════════════════════════════════
        Rectangle {
            id: batteryStatusCard
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(180, mainColumn.width * 0.22)
            color: theme ? Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.8) : "#1e1e1e"
            radius: 16
            border.width: 1
            border.color: theme && theme.isDark ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.08)
            
            // Responsive content layout
            RowLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 40
                
                // Large Battery Visualization
                Item {
                    width: 100
                    height: 150
                    
                    // Battery Container
                    Rectangle {
                        id: batteryContainer
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: 70; height: 120
                        color: "transparent"
                        border.width: 5
                        border.color: theme ? theme.textSecondary : "#666"
                        radius: 10
                        
                        // Animated Fill
                        Rectangle {
                            id: batteryFill
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.margins: 6
                            width: parent.width - 12
                            height: (parent.height - 12) * (monitor.batteryPercent / 100)
                            radius: 6
                            
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: monitor.batteryPercent > 50 ? "#2ecc71" : (monitor.batteryPercent > 20 ? "#FF9800" : "#FF1744") }
                                GradientStop { position: 1.0; color: monitor.batteryPercent > 50 ? "#27ae60" : (monitor.batteryPercent > 20 ? "#F57C00" : "#D32F2F") }
                            }
                            
                            Behavior on height { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
                        }
                        
                        // Percentage INSIDE the battery
                        Text {
                            anchors.centerIn: parent
                            text: monitor.batteryPercent + "%"
                            color: "white"
                            font.pixelSize: 18
                            font.bold: true
                            style: Text.Outline
                            styleColor: "#000"
                        }
                        
                        // Charging bolt
                        Text {
                            visible: monitor.isCharging
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            text: "⚡"
                            font.pixelSize: 18
                            color: "#FFD700"
                        }
                        
                        // Cap
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.top
                            anchors.bottomMargin: -3
                            width: 28; height: 10
                            color: theme ? theme.textSecondary : "#666"
                            radius: 4
                        }
                    }
                    
                    // Label below battery
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: monitor.isCharging ? "Charging" : "Battery"
                        color: theme ? theme.textSecondary : "#888"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
                
                // Stats in 2x2 Grid
                GridLayout {
                    columns: 2
                    rowSpacing: 20
                    columnSpacing: 50
                    
                    // Stat Item: Current Level
                    ColumnLayout {
                        spacing: 4
                        Text {
                            text: "CURRENT LEVEL"
                            color: theme ? theme.textTertiary : "#888"
                            font.pixelSize: 10
                            font.letterSpacing: 1
                            font.bold: true
                        }
                        Text {
                            text: monitor.batteryPercent + "%"
                            color: monitor.batteryPercent > 50 ? "#2ecc71" : (monitor.batteryPercent > 20 ? "#FF9800" : "#FF1744")
                            font.pixelSize: 26
                            font.bold: true
                        }
                    }
                    
                    // Stat Item: Charge Limit
                    ColumnLayout {
                        spacing: 4
                        Text {
                            text: "CHARGE LIMIT"
                            color: theme ? theme.textTertiary : "#888"
                            font.pixelSize: 10
                            font.letterSpacing: 1
                            font.bold: true
                        }
                        Text {
                            text: monitor.chargeLimit + "%"
                            color: theme ? theme.accent : "#0078d4"
                            font.pixelSize: 26
                            font.bold: true
                        }
                    }
                    
                    // Stat Item: Status
                    ColumnLayout {
                        spacing: 4
                        Text {
                            text: "STATUS"
                            color: theme ? theme.textTertiary : "#888"
                            font.pixelSize: 10
                            font.letterSpacing: 1
                            font.bold: true
                        }
                        Text {
                            text: monitor.batteryState
                            color: theme ? theme.textPrimary : "#fff"
                            font.pixelSize: 16
                            font.bold: true
                        }
                    }
                    
                    // Stat Item: Health Mode
                    ColumnLayout {
                        spacing: 4
                        Text {
                            text: "HEALTH MODE"
                            color: theme ? theme.textTertiary : "#888"
                            font.pixelSize: 10
                            font.letterSpacing: 1
                            font.bold: true
                        }
                        Text {
                            text: monitor.chargeLimit < 100 ? "ENABLED" : "DISABLED"
                            color: monitor.chargeLimit < 100 ? "#2ecc71" : "#FF9800"
                            font.pixelSize: 16
                            font.bold: true
                        }
                    }
                }
            }
        }
        
        // ══════════════════════════════════════════════════════════════
        // SECTION 3: CHARGE LIMIT CONTROL
        // ══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: limitColumn.height + 50
            color: theme ? Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.85) : "#1e1e1e"
            radius: 16
            border.width: 1
            border.color: theme && theme.isDark ? Qt.rgba(1,1,1,0.1) : Qt.rgba(0,0,0,0.1)
            
            ColumnLayout {
                id: limitColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 28
                spacing: 20
                
                // Header Row
                RowLayout {
                    Layout.fillWidth: true
                    
                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "CHARGE LIMIT"
                            color: "#3498db"
                            font.bold: true
                            font.pixelSize: 16
                            font.letterSpacing: 1.5
                        }
                        Text {
                            text: "Limit charging to extend battery lifespan"
                            color: theme ? theme.textTertiary : "#888"
                            font.pixelSize: 12
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Limit Set Label + Input + Validation Popup
                    RowLayout {
                        spacing: 12
                        
                        // Styled Label with Hover
                        Rectangle {
                            id: customLabel
                            width: labelText.width + 24
                            height: 34
                            radius: 8
                            color: customLabelMouse.containsMouse ? (theme ? theme.accent : "#2ecc71") : (theme && theme.isDark ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.06))
                            border.width: customLabelMouse.containsMouse ? 0 : 1
                            border.color: theme && theme.isDark ? Qt.rgba(1,1,1,0.15) : Qt.rgba(0,0,0,0.1)
                            
                            scale: customLabelMouse.containsMouse ? 1.05 : 1.0
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            
                            Text {
                                id: labelText
                                anchors.centerIn: parent
                                text: "Custom"
                                color: customLabelMouse.containsMouse ? "white" : (theme ? theme.textSecondary : "#aaa")
                                font.pixelSize: 13
                                font.bold: true
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            
                            MouseArea {
                                id: customLabelMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: limitInput.forceActiveFocus()
                            }
                        }
                        
                        // Input Container with Popup
                        Item {
                            width: 110
                            height: 50
                            
                            // Validation Popup (positioned ABOVE input)
                            Rectangle {
                                id: validationPopup
                                visible: validationMsg.text.length > 0
                                anchors.bottom: inputBadge.top
                                anchors.bottomMargin: 8
                                anchors.horizontalCenter: inputBadge.horizontalCenter
                                width: validationMsg.width + 24
                                height: 30
                                radius: 8
                                color: "#1a1a1a"
                                border.width: 2
                                border.color: "#FF1744"
                                z: 100
                                
                                Text {
                                    id: validationMsg
                                    anchors.centerIn: parent
                                    text: ""
                                    color: "#FF1744"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                                
                                // Arrow pointing down to input
                                Canvas {
                                    anchors.top: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 14; height: 8
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.fillStyle = "#FF1744";
                                        ctx.beginPath();
                                        ctx.moveTo(0, 0);
                                        ctx.lineTo(14, 0);
                                        ctx.lineTo(7, 8);
                                        ctx.closePath();
                                        ctx.fill();
                                    }
                                }
                            }
                            
                            // Value Input Badge
                            Rectangle {
                                id: inputBadge
                                anchors.fill: parent
                                radius: 12
                                color: "#2ecc71"
                                border.width: 2
                                border.color: "#1a8f4e"
                                
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    
                                    TextInput {
                                        id: limitInput
                                        text: monitor.chargeLimit.toString()
                                        color: "white"
                                        font.bold: true
                                        font.pixelSize: 20
                                        horizontalAlignment: TextInput.AlignHCenter
                                        validator: IntValidator { bottom: 0; top: 100 }
                                        maximumLength: 3
                                        selectByMouse: true
                                        Layout.preferredWidth: 40
                                        clip: true
                                        
                                        onTextChanged: {
                                            var val = parseInt(text)
                                            if (val < 60 && text.length > 0) {
                                                validationMsg.text = "Minimum 60%"
                                            } else if (val > 100) {
                                                validationMsg.text = "Maximum 100%"
                                            } else {
                                                validationMsg.text = ""
                                            }
                                        }
                                        
                                        onEditingFinished: {
                                            var val = parseInt(text)
                                            if (val >= 60 && val <= 100) {
                                                monitor.chargeLimit = val
                                                batLimitSlider.value = val
                                            } else {
                                                text = monitor.chargeLimit.toString()
                                            }
                                            validationMsg.text = ""
                                            focus = false
                                        }
                                    }
                                    Text {
                                        text: "%"
                                        color: "white"
                                        font.bold: true
                                        font.pixelSize: 18
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Premium Slider Section
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: sliderContent.height + 30
                    radius: 12
                    color: theme && theme.isDark ? Qt.rgba(0,0,0,0.3) : Qt.rgba(0,0,0,0.05)
                    
                    ColumnLayout {
                        id: sliderContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 15
                        spacing: 12
                        
                        // Slider
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            
                            Slider {
                                id: batLimitSlider
                                anchors.fill: parent
                                from: 60; to: 100
                                stepSize: 5
                                value: monitor.chargeLimit
                                
                                background: Rectangle {
                                    x: batLimitSlider.leftPadding
                                    y: batLimitSlider.topPadding + batLimitSlider.availableHeight / 2 - height / 2
                                    width: batLimitSlider.availableWidth
                                    height: 12
                                    radius: 6
                                    color: theme && theme.isDark ? "#1a1a1a" : "#e0e0e0"
                                    
                                    // Progress with gradient
                                    Rectangle {
                                        width: batLimitSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: 6
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: "#FF1744" }
                                            GradientStop { position: 0.5; color: "#FF9800" }
                                            GradientStop { position: 1.0; color: "#2ecc71" }
                                        }
                                    }
                                    
                                    // Tick marks
                                    Repeater {
                                        model: 9
                                        Rectangle {
                                            x: index * (parent.width / 8) - 1
                                            width: 2
                                            height: parent.height
                                            color: Qt.rgba(1,1,1, index === 0 ? 0 : 0.25)
                                        }
                                    }
                                }
                                
                                handle: Rectangle {
                                    x: batLimitSlider.leftPadding + batLimitSlider.visualPosition * (batLimitSlider.availableWidth - width)
                                    y: batLimitSlider.topPadding + batLimitSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 32; implicitHeight: 32
                                    radius: 16
                                    color: "white"
                                    border.width: 4
                                    border.color: "#2ecc71"
                                    
                                    // Inner percentage
                                    Text {
                                        anchors.centerIn: parent
                                        text: batLimitSlider.value.toFixed(0)
                                        color: "#2ecc71"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }
                            }
                            
                            // Drag Logic
                            MouseArea {
                                anchors.fill: parent
                                preventStealing: true
                                function updateVal(xVal) {
                                    var ratio = Math.max(0, Math.min(1, xVal / width))
                                    var raw = 60 + (ratio * 40)
                                    var snapped = Math.round(raw / 5) * 5
                                    if (snapped !== batLimitSlider.value) batLimitSlider.value = snapped
                                    limitInput.text = snapped.toString()
                                }
                                onPressed: updateVal(mouseX)
                                onPositionChanged: updateVal(mouseX)
                                onReleased: {
                                    updateVal(mouseX)
                                    monitor.chargeLimit = batLimitSlider.value
                                }
                            }
                        }
                        
                        // Scale Labels
                        RowLayout {
                            Layout.fillWidth: true
                            Repeater {
                                model: 9
                                Text {
                                    Layout.fillWidth: index > 0 && index < 8
                                    text: (60 + index * 5) + "%"
                                    color: theme ? theme.textTertiary : "#666"
                                    font.pixelSize: 10
                                    font.bold: true
                                    horizontalAlignment: index === 0 ? Text.AlignLeft : (index === 8 ? Text.AlignRight : Text.AlignHCenter)
                                }
                            }
                        }
                    }
                }
                
                // Preset Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Repeater {
                        model: [
                            { label: "60%", value: 60, desc: "Max Lifespan" },
                            { label: "80%", value: 80, desc: "Recommended" },
                            { label: "100%", value: 100, desc: "Full Capacity" }
                        ]
                        
                        property string btnColor: "#2ecc71"
                        
                        delegate: Button {
                            id: presetBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 65
                            
                            property bool isActive: monitor.chargeLimit === modelData.value
                            hoverEnabled: true

                            scale: hovered ? 1.03 : (isActive ? 1.01 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            background: Rectangle {
                                property string btnColor: "#2ecc71"
                                color: {
                                    if (presetBtn.isActive) return btnColor
                                    if (presetBtn.hovered) return btnColor
                                    return theme && theme.isDark ? "#1e1e1e" : "#f0f0f0"
                                }
                                radius: 12
                                border.color: btnColor
                                border.width: presetBtn.isActive || presetBtn.hovered ? 0 : 2
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            
                            contentItem: Item {
                                anchors.fill: parent
                                
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: presetBtn.isActive || presetBtn.hovered ? "white" : "#2ecc71"
                                        font.bold: true
                                        font.pixelSize: 20
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.desc
                                        color: presetBtn.isActive || presetBtn.hovered ? Qt.rgba(1,1,1,0.8) : (theme ? theme.textTertiary : "#888")
                                        font.pixelSize: 11
                                        font.letterSpacing: 0.5
                                    }
                                }
                            }
                            
                            onClicked: {
                                monitor.chargeLimit = modelData.value
                                batLimitSlider.value = modelData.value
                                limitInput.text = modelData.value.toString()
                            }
                        }
                    }
                }
                
                // Info Text
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    text: "💡 Limiting charge to 60-80% can significantly extend your battery's total lifespan, ideal for laptops that stay plugged in."
                    color: theme ? theme.textTertiary : "#888"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
        } // End ColumnLayout
    } // End centerWrapper Item
    } // End Flickable
} // End batteryPage Item
