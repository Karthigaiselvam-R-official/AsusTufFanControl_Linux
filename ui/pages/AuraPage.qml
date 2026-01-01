import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import ".."

Item {
    id: auraPage
    
    property var aura
    property var theme
    
    // Local State
    property string activeMode: "Static"
    property string selectedColor: "FF0000"
    property real colorHue: 0.0
    property int brightnessLevel: 3
    property int initSpeed: 2
    
    // Helpers
    function applyAura() {
        aura.setBrightness(brightnessLevel)
        if (activeMode === "Static") aura.setStatic(selectedColor)
        else if (activeMode === "Breathing") aura.setBreathing(selectedColor, initSpeed)
        else if (activeMode === "Rainbow") aura.setRainbow(initSpeed)
        else if (activeMode === "Strobing") aura.setPulsing(selectedColor, initSpeed)
        
        aura.saveState(activeMode, selectedColor);
    }

    Component.onCompleted: { initTimer.start() }
    
    Timer {
        id: initTimer
        interval: 100; repeat: false
        onTriggered: {
             var sysB = aura.getSystemBrightness(); 
             if (sysB !== -1) brightnessLevel = sysB; 
             
             var lastM = aura.getLastMode();
             var lastC = aura.getLastColor();
             if (lastM && lastM !== "") activeMode = lastM;
             if (lastC && lastC !== "") {
                 selectedColor = lastC;
                 var c = Qt.color("#" + lastC);
                 if (c.hslSaturation > 0) colorHue = Math.max(0, c.hslHue);
                 else colorHue = 0;
             }
             applyAura();
        }
    }

    // Main scrollable content with vertical centering
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
            
            // Premium Header with gradient accent
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 30; Layout.rightMargin: 30; Layout.topMargin: 20
                height: 100
                radius: 16
                color: "transparent"
                
                // Gradient background
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(168/255, 85/255, 247/255, 0.15) }
                        GradientStop { position: 0.5; color: Qt.rgba(236/255, 72/255, 153/255, 0.1) }
                        GradientStop { position: 1.0; color: Qt.rgba(59/255, 130/255, 246/255, 0.15) }
                    }
                    border.width: 1
                    border.color: theme.isDark ? Qt.rgba(255,255,255,0.1) : Qt.rgba(0,0,0,0.05)
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20
                    
                    // Premium Animated Gaming Laptop Icon with RGB Effects
                    Item {
                        width: 64; height: 64
                        Layout.alignment: Qt.AlignVCenter
                        
                        Canvas {
                            id: laptopIcon
                            anchors.fill: parent
                            anchors.verticalCenterOffset: -4  // Move icon slightly higher
                            
                            property real rainbowPhase: 0
                            property real pulsePhase: 0
                            property real wavePhase: 0
                            
                            // Get color from user's selection
                            property color userColor: Qt.color("#" + auraPage.selectedColor)
                            property string currentMode: auraPage.activeMode
                            
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                
                                var cx = width / 2;
                                var cy = height / 2 - 2;  // Shift drawing up
                                
                                // === LAPTOP SCREEN (Top part) ===
                                var screenW = 50, screenH = 28;
                                var screenX = cx - screenW/2;
                                var screenY = cy - 18;
                                
                                // Screen bezel/frame
                                ctx.fillStyle = "#1a1a2e";
                                ctx.strokeStyle = "#2a2a4a";
                                ctx.lineWidth = 2;
                                ctx.beginPath();
                                ctx.moveTo(screenX + 4, screenY);
                                ctx.lineTo(screenX + screenW - 4, screenY);
                                ctx.arcTo(screenX + screenW, screenY, screenX + screenW, screenY + 4, 4);
                                ctx.lineTo(screenX + screenW, screenY + screenH - 2);
                                ctx.lineTo(screenX, screenY + screenH - 2);
                                ctx.lineTo(screenX, screenY + 4);
                                ctx.arcTo(screenX, screenY, screenX + 4, screenY, 4);
                                ctx.closePath();
                                ctx.fill();
                                ctx.stroke();
                                
                                // Screen display background
                                var displayX = screenX + 3;
                                var displayY = screenY + 3;
                                var displayW = screenW - 6;
                                var displayH = screenH - 6;
                                
                                // Determine colors based on mode
                                var isRainbow = (currentMode === "Rainbow");
                                var isBreathing = (currentMode === "Breathing");
                                var isStrobing = (currentMode === "Strobing");
                                var isStatic = (currentMode === "Static");
                                
                                // Aurora gradient background - mode aware
                                var auroraGrad = ctx.createLinearGradient(displayX, displayY, displayX + displayW, displayY + displayH);
                                if (isRainbow) {
                                    auroraGrad.addColorStop(0, Qt.hsla(rainbowPhase, 0.8, 0.15, 1));
                                    auroraGrad.addColorStop(0.5, Qt.hsla((rainbowPhase + 0.3) % 1, 0.8, 0.18, 1));
                                    auroraGrad.addColorStop(1, Qt.hsla((rainbowPhase + 0.6) % 1, 0.75, 0.12, 1));
                                } else {
                                    var baseHue = userColor.hslHue >= 0 ? userColor.hslHue : 0;
                                    var baseBright = isBreathing ? (0.12 + pulsePhase * 0.08) : 0.15;
                                    auroraGrad.addColorStop(0, Qt.hsla(baseHue, 0.7, baseBright, 1));
                                    auroraGrad.addColorStop(1, Qt.hsla(baseHue, 0.8, baseBright * 0.8, 1));
                                }
                                ctx.fillStyle = auroraGrad;
                                ctx.fillRect(displayX, displayY, displayW, displayH);
                                
                                // Aurora wave lines on screen
                                for (var wave = 0; wave < 3; wave++) {
                                    var waveY = displayY + 6 + wave * 7;
                                    var waveHue;
                                    if (isRainbow) {
                                        waveHue = (rainbowPhase + wave * 0.15) % 1;
                                    } else {
                                        waveHue = userColor.hslHue >= 0 ? userColor.hslHue : 0;
                                    }
                                    var waveAlpha = isStrobing ? (pulsePhase > 0.5 ? 0.8 : 0.2) : (0.7 - wave * 0.15);
                                    ctx.strokeStyle = Qt.hsla(waveHue, 0.9, 0.6, waveAlpha);
                                    ctx.lineWidth = 2;
                                    ctx.beginPath();
                                    for (var wx = 0; wx < displayW; wx += 2) {
                                        var wy = waveY + Math.sin((wx / 8) + wavePhase + wave) * 3;
                                        if (wx === 0) ctx.moveTo(displayX + wx, wy);
                                        else ctx.lineTo(displayX + wx, wy);
                                    }
                                    ctx.stroke();
                                }
                                
                                // Center glow
                                var glowHue = isRainbow ? rainbowPhase : (userColor.hslHue >= 0 ? userColor.hslHue : 0);
                                var glowAlpha = isBreathing ? (0.4 + pulsePhase * 0.5) : 0.7;
                                var logoGlow = ctx.createRadialGradient(cx, displayY + displayH/2, 0, cx, displayY + displayH/2, 12);
                                logoGlow.addColorStop(0, Qt.hsla(glowHue, 0.9, 0.7, glowAlpha));
                                logoGlow.addColorStop(1, "transparent");
                                ctx.fillStyle = logoGlow;
                                ctx.beginPath();
                                ctx.arc(cx, displayY + displayH/2, 12, 0, Math.PI * 2);
                                ctx.fill();
                                
                                // === LAPTOP BASE (Keyboard area) ===
                                var baseW = 52, baseH = 16;
                                var baseX = cx - baseW/2;
                                var baseY = screenY + screenH;
                                
                                // Base body
                                ctx.fillStyle = "#0d0d18";
                                ctx.strokeStyle = "#2a2a4a";
                                ctx.lineWidth = 1.5;
                                ctx.beginPath();
                                ctx.moveTo(baseX, baseY);
                                ctx.lineTo(baseX + baseW, baseY);
                                ctx.lineTo(baseX + baseW + 4, baseY + baseH - 3);
                                ctx.arcTo(baseX + baseW + 4, baseY + baseH, baseX + baseW, baseY + baseH, 3);
                                ctx.lineTo(baseX, baseY + baseH);
                                ctx.arcTo(baseX - 4, baseY + baseH, baseX - 4, baseY + baseH - 3, 3);
                                ctx.lineTo(baseX - 4, baseY + baseH - 3);
                                ctx.closePath();
                                ctx.fill();
                                ctx.stroke();
                                
                                // RGB Keyboard keys (5 columns x 2 rows) - mode aware
                                var keyW = 6, keyH = 4;
                                var keySpacingX = 8, keySpacingY = 6;
                                var keysStartX = baseX + 4;
                                var keysStartY = baseY + 2;
                                
                                for (var row = 0; row < 2; row++) {
                                    for (var col = 0; col < 5; col++) {
                                        var kx = keysStartX + col * keySpacingX;
                                        var ky = keysStartY + row * keySpacingY;
                                        
                                        // Key color based on mode
                                        var keyHue, keyBrightness, keyAlpha;
                                        if (isRainbow) {
                                            keyHue = (rainbowPhase + (col * 0.08) + (row * 0.1) + wavePhase * 0.5) % 1;
                                            keyBrightness = 0.5 + pulsePhase * 0.25;
                                            keyAlpha = 1;
                                        } else if (isBreathing) {
                                            keyHue = userColor.hslHue >= 0 ? userColor.hslHue : 0;
                                            keyBrightness = 0.3 + pulsePhase * 0.4;
                                            keyAlpha = 1;
                                        } else if (isStrobing) {
                                            keyHue = userColor.hslHue >= 0 ? userColor.hslHue : 0;
                                            keyBrightness = pulsePhase > 0.5 ? 0.7 : 0.2;
                                            keyAlpha = 1;
                                        } else {
                                            // Static
                                            keyHue = userColor.hslHue >= 0 ? userColor.hslHue : 0;
                                            keyBrightness = 0.6;
                                            keyAlpha = 1;
                                        }
                                        
                                        // Key glow
                                        ctx.fillStyle = Qt.hsla(keyHue, 0.9, 0.5, 0.5);
                                        ctx.beginPath();
                                        ctx.arc(kx + keyW/2, ky + keyH/2, 5, 0, Math.PI * 2);
                                        ctx.fill();
                                        
                                        // Key body
                                        ctx.fillStyle = "#050508";
                                        ctx.fillRect(kx, ky, keyW, keyH);
                                        
                                        // Key RGB strip
                                        ctx.strokeStyle = Qt.hsla(keyHue, 0.95, keyBrightness, keyAlpha);
                                        ctx.lineWidth = 1.5;
                                        ctx.beginPath();
                                        ctx.moveTo(kx + 1, ky + 1);
                                        ctx.lineTo(kx + keyW - 1, ky + 1);
                                        ctx.stroke();
                                    }
                                }
                                
                                // Front edge RGB strip - mode aware
                                var stripGrad = ctx.createLinearGradient(baseX, 0, baseX + baseW, 0);
                                if (isRainbow) {
                                    for (var s = 0; s <= 1; s += 0.1) {
                                        stripGrad.addColorStop(s, Qt.hsla((rainbowPhase + s) % 1, 0.95, 0.55, 1));
                                    }
                                } else {
                                    var stripHue = userColor.hslHue >= 0 ? userColor.hslHue : 0;
                                    var stripBright = isBreathing ? (0.4 + pulsePhase * 0.3) : (isStrobing ? (pulsePhase > 0.5 ? 0.7 : 0.2) : 0.55);
                                    stripGrad.addColorStop(0, Qt.hsla(stripHue, 0.95, stripBright, 1));
                                    stripGrad.addColorStop(1, Qt.hsla(stripHue, 0.95, stripBright, 1));
                                }
                                ctx.strokeStyle = stripGrad;
                                ctx.lineWidth = 2.5;
                                ctx.beginPath();
                                ctx.moveTo(baseX - 2, baseY + baseH);
                                ctx.lineTo(baseX + baseW + 2, baseY + baseH);
                                ctx.stroke();
                                
                                // Outer RGB glow aura - mode aware
                                for (var g = 2; g >= 0; g--) {
                                    var outerGlowAlpha = 0.2 - (g * 0.06);
                                    var outerHue = isRainbow ? ((rainbowPhase + g * 0.1) % 1) : (userColor.hslHue >= 0 ? userColor.hslHue : 0);
                                    ctx.strokeStyle = Qt.hsla(outerHue, 0.9, 0.55, outerGlowAlpha);
                                    ctx.lineWidth = 3;
                                    ctx.beginPath();
                                    ctx.moveTo(screenX - 4 - g*2, screenY + 4);
                                    ctx.lineTo(screenX - 4 - g*2, baseY + baseH - 2);
                                    ctx.arcTo(screenX - 6 - g*2, baseY + baseH + 2 + g*2, screenX, baseY + baseH + 2 + g*2, 4);
                                    ctx.lineTo(screenX + screenW, baseY + baseH + 2 + g*2);
                                    ctx.arcTo(screenX + screenW + 6 + g*2, baseY + baseH + 2 + g*2, screenX + screenW + 4 + g*2, baseY + 4, 4);
                                    ctx.lineTo(screenX + screenW + 4 + g*2, screenY + 4);
                                    ctx.stroke();
                                }
                            }
                            
                            NumberAnimation on rainbowPhase {
                                from: 0; to: 1
                                duration: 3000
                                loops: Animation.Infinite
                            }
                            
                            SequentialAnimation on pulsePhase {
                                loops: Animation.Infinite
                                NumberAnimation { from: 0; to: 1; duration: 1200; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 1; to: 0; duration: 1200; easing.type: Easing.InOutSine }
                            }
                            
                            NumberAnimation on wavePhase {
                                from: 0; to: Math.PI * 2
                                duration: 2000
                                loops: Animation.Infinite
                            }
                            
                            onRainbowPhaseChanged: requestPaint()
                            onPulsePhaseChanged: requestPaint()
                            onWavePhaseChanged: requestPaint()
                            onUserColorChanged: requestPaint()
                            onCurrentModeChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter
                        
                        // Adaptive RGB Gradient Title using Canvas
                        Canvas {
                            id: titleCanvas
                            // Adaptive Sizing: Start with default, but allow growing
                            implicitWidth: Math.max(140, drawnTextWidth + 10) 
                            height: 28
                            
                            property real hueShift: 0
                            property real drawnTextWidth: 140 // Will be updated after measure
                            property string titleText: qsTr("AURA SYNC")
                            
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.font = "bold 22px sans-serif";
                                
                                // 1. Measure Text Width
                                var metrics = ctx.measureText(titleCanvas.titleText);
                                var textW = metrics.width;
                                
                                // 2. Update Canvas Width if needed (triggering re-layout)
                                if (Math.abs(titleCanvas.drawnTextWidth - textW) > 1) {
                                    titleCanvas.drawnTextWidth = textW;
                                    // Note: changing property in onPaint usually safe if it doesn't trigger immediate repaint loop
                                    // requestPaint() is called by hueShift animation anyway.
                                }
                                
                                // 3. Create Gradient based on dynamic width
                                var gradient = ctx.createLinearGradient(0, 0, width, 0);
                                gradient.addColorStop(0, Qt.hsla((hueShift) % 1, 0.9, 0.65, 1));
                                gradient.addColorStop(0.25, Qt.hsla((hueShift + 0.15) % 1, 0.9, 0.65, 1));
                                gradient.addColorStop(0.5, Qt.hsla((hueShift + 0.3) % 1, 0.9, 0.6, 1));
                                gradient.addColorStop(0.75, Qt.hsla((hueShift + 0.45) % 1, 0.9, 0.65, 1));
                                gradient.addColorStop(1, Qt.hsla((hueShift + 0.6) % 1, 0.9, 0.65, 1));
                                
                                ctx.fillStyle = gradient;
                                ctx.fillText(titleCanvas.titleText, 0, 22);
                            }
                            
                            NumberAnimation on hueShift {
                                from: 0; to: 1
                                duration: 4000
                                loops: Animation.Infinite
                            }
                            
                            // Re-paint when text changes (Translation fallback)
                            onTitleTextChanged: requestPaint()
                            onHueShiftChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                        }
                        
                        Text {
                            text: qsTr("RGB Keyboard Lighting Control")
                            color: Qt.rgba(168/255, 85/255, 247/255, 0.8)
                            font.pixelSize: 12
                            font.letterSpacing: 0.5
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Status badge
                    Rectangle {
                        width: statusRow.width + 20; height: 32; radius: 16
                        color: Qt.rgba(16/255, 185/255, 129/255, 0.15)
                        border.width: 1
                        border.color: "#10b981"
                        
                        Row {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: 8
                            
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: "#10b981"
                                anchors.verticalCenter: parent.verticalCenter
                                
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1; to: 0.4; duration: 800 }
                                    NumberAnimation { from: 0.4; to: 1; duration: 800 }
                                }
                            }
                            Text { text: qsTr("Connected"); color: "#10b981"; font.bold: true; font.pixelSize: 12 }
                        }
                    }
                    

                }
            }
            
            // Main content card
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 30; Layout.rightMargin: 30
                Layout.preferredHeight: controlsColumn.implicitHeight + 60
                radius: 16
                color: theme.isDark ? Qt.rgba(25/255, 25/255, 30/255, 0.95) : Qt.rgba(255/255, 255/255, 255/255, 0.98)
                border.width: 1
                border.color: theme.isDark ? Qt.rgba(255,255,255,0.08) : Qt.rgba(0,0,0,0.06)
                
                ColumnLayout {
                    id: controlsColumn
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 28
                    
                    // ===== LIGHTING MODE SECTION =====
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        
                        RowLayout {
                            spacing: 8
                            Canvas {
                                width: 16; height: 16
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.fillStyle = theme.accent;
                                    ctx.beginPath();
                                    ctx.moveTo(8, 0); ctx.lineTo(12, 6); ctx.lineTo(9, 6);
                                    ctx.lineTo(11, 16); ctx.lineTo(4, 8); ctx.lineTo(7, 8); ctx.lineTo(5, 0);
                                    ctx.closePath(); ctx.fill();
                                }
                            }
                            Text { text: qsTr("LIGHTING MODE"); color: theme.textSecondary; font.bold: true; font.pixelSize: 12; font.letterSpacing: 1.5 }
                        }
                        
                        // Mode buttons grid
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            
                            Repeater {
                                model: [
                                    { name: "Static", displayName: qsTr("Static"), icon: "●" },
                                    { name: "Breathing", displayName: qsTr("Breathing"), icon: "◐" },
                                    { name: "Rainbow", displayName: qsTr("Rainbow"), icon: "◎" },
                                    { name: "Strobing", displayName: qsTr("Strobing"), icon: "※" }
                                ]
                                delegate: Rectangle {
                                    // Delegate ID needed for referencing width
                                    id: modeDelegate

                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1 // FORCE EQUAL WIDTHS
                                    height: 55
                                    radius: 12
                                    color: isActive ? theme.accent : (modeHover.containsMouse ? theme.accent : "transparent")
                                    border.width: isActive || modeHover.containsMouse ? 0 : 1
                                    border.color: theme.isDark ? Qt.rgba(255,255,255,0.15) : Qt.rgba(0,0,0,0.25)
                                    
                                    property bool isActive: activeMode === modelData.name
                                    
                                    scale: modeHover.containsMouse ? 1.03 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    
                                    MouseArea {
                                        id: modeHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { activeMode = modelData.name; applyAura() }
                                    }
                                    
                                    RowLayout {
                                        anchors.centerIn: parent
                                        width: parent.width - 20 // Constrain Layout width to container
                                        spacing: 8
                                        
                                        Text {
                                            text: modelData.icon
                                            font.pixelSize: 16
                                            color: isActive || modeHover.containsMouse ? "#ffffff" : theme.accent
                                            font.bold: true
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        Text {
                                            text: modelData.displayName
                                            color: isActive || modeHover.containsMouse ? "#ffffff" : theme.textPrimary
                                            font.bold: true
                                            font.pixelSize: 13
                                            
                                            // Safe Adaptive Text Sizing
                                            Layout.fillWidth: true
                                            Layout.maximumWidth: modeDelegate.width - 50 // Explicitly reference delegate width
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            horizontalAlignment: Text.AlignLeft
                                            verticalAlignment: Text.AlignVCenter
                                            fontSizeMode: Text.Fit
                                            minimumPixelSize: 8
                                            elide: Text.ElideRight 
                                        }

                                    }
                                }
                            }
                        }
                    }
                    
                    // Divider
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.isDark ? Qt.rgba(255,255,255,0.06) : Qt.rgba(0,0,0,0.06) }
                    
                    // Initialize Button Removed (Auto-Init Implemented)
                    
                    // ===== COLOR SELECTION SECTION =====
                    ColumnLayout {
                        visible: activeMode !== "Rainbow"
                        Layout.fillWidth: true
                        spacing: 16
                        
                        RowLayout {
                            spacing: 12
                            Canvas {
                                width: 14; height: 14
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.fillStyle = theme.accent;
                                    ctx.beginPath(); ctx.moveTo(7, 0); ctx.lineTo(14, 7); ctx.lineTo(7, 14); ctx.lineTo(0, 7); ctx.closePath(); ctx.fill();
                                }
                            }
                            Text { text: qsTr("COLOR SELECTION"); color: theme.textSecondary; font.bold: true; font.pixelSize: 12; font.letterSpacing: 1.5 }
                            Item { Layout.fillWidth: true }
                            
                            // Current color preview
                            Rectangle {
                                width: 34; height: 34; radius: 8
                                color: "#" + selectedColor
                                border.width: 2
                                border.color: theme.isDark ? "#fff" : "#333"
                            }
                        }
                        
                        // Hue slider with premium design
                        Rectangle {
                            Layout.fillWidth: true
                            height: 50
                            radius: 14
                            color: theme.isDark ? Qt.rgba(0,0,0,0.3) : Qt.rgba(0,0,0,0.05)
                            border.width: 1
                            border.color: theme.isDark ? Qt.rgba(255,255,255,0.1) : Qt.rgba(0,0,0,0.08)
                            
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 8
                                radius: 10
                                
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#FF0000" }
                                    GradientStop { position: 0.17; color: "#FFFF00" }
                                    GradientStop { position: 0.33; color: "#00FF00" }
                                    GradientStop { position: 0.5; color: "#00FFFF" }
                                    GradientStop { position: 0.67; color: "#0000FF" }
                                    GradientStop { position: 0.83; color: "#FF00FF" }
                                    GradientStop { position: 1.0; color: "#FF0000" }
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    preventStealing: true
                                    function pick(xVal) {
                                        var h = Math.max(0, Math.min(1, xVal / width))
                                        colorHue = h 
                                        var c = Qt.hsla(h, 1.0, 0.5, 1.0)
                                        selectedColor = c.toString().substring(1)
                                        applyAura()
                                    }
                                    onPressed: pick(mouseX)
                                    onPositionChanged: pick(mouseX)
                                }
                                
                                // Selector handle
                                Rectangle {
                                    width: 36; height: 36; radius: 18
                                    color: "#" + selectedColor
                                    border.width: 4
                                    border.color: "#ffffff"
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: (colorHue * parent.width) - (width/2)
                                    
                                    // Shadow
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        radius: 24
                                        color: "transparent"
                                        border.width: 2
                                        border.color: "#" + selectedColor
                                        opacity: 0.5
                                    }
                                }
                            }
                        }
                        
                        // Color presets grid with hover effects
                        GridLayout {
                            columns: 8
                            rowSpacing: 10
                            columnSpacing: 10
                            Layout.fillWidth: true
                            
                            Repeater {
                                model: [
                                    "#FF0000", "#FF4500", "#FFA500", "#FFD700", "#FFFF00", "#ADFF2F", "#00FF00", "#00FA9A",
                                    "#00FFFF", "#1E90FF", "#0000FF", "#8A2BE2", "#FF00FF", "#FF1493", "#FFFFFF", "#808080"
                                ]
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    radius: 10
                                    color: modelData
                                    
                                    property bool isSelected: ("#" + selectedColor).toLowerCase() === modelData.toLowerCase()
                                    
                                    border.width: isSelected ? 3 : (presetHover.containsMouse ? 2 : 1)
                                    border.color: isSelected ? "#ffffff" : (presetHover.containsMouse ? "#ffffff" : Qt.rgba(0,0,0,0.2))
                                    
                                    scale: presetHover.containsMouse ? 1.1 : 1.0
                                    z: presetHover.containsMouse ? 10 : 1
                                    
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    Behavior on border.width { NumberAnimation { duration: 100 } }
                                    Behavior on border.color { ColorAnimation { duration: 100 } }
                                    
                                    // Outer glow on hover
                                    Rectangle {
                                        visible: presetHover.containsMouse || isSelected
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        radius: parent.radius + 4
                                        color: "transparent"
                                        border.width: 2
                                        border.color: modelData
                                        opacity: 0.5
                                    }
                                    
                                    // Checkmark for selected
                                    Text {
                                        visible: isSelected
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: modelData === "#FFFFFF" || modelData === "#FFFF00" || modelData === "#FFD700" ? "#000" : "#fff"
                                        font.bold: true
                                        font.pixelSize: 16
                                    }
                                    
                                    MouseArea {
                                        id: presetHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var c = Qt.color(modelData)
                                            selectedColor = modelData.substring(1).toUpperCase()
                                            if (c.hslSaturation > 0) colorHue = Math.max(0, c.hslHue)
                                            else colorHue = 0
                                            applyAura()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Divider
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.isDark ? Qt.rgba(255,255,255,0.06) : Qt.rgba(0,0,0,0.06) }
                    
                    // ===== CONTROLS SECTION =====
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        
                        RowLayout {
                            spacing: 8
                            Canvas {
                                width: 16; height: 16
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.strokeStyle = theme.accent; ctx.lineWidth = 2; ctx.lineCap = "round";
                                    ctx.beginPath(); ctx.moveTo(2, 8); ctx.lineTo(14, 8); ctx.stroke();
                                    ctx.fillStyle = theme.accent;
                                    ctx.beginPath(); ctx.arc(6, 8, 4, 0, Math.PI * 2); ctx.fill();
                                }
                            }
                            Text { text: qsTr("CONTROLS"); color: theme.textSecondary; font.bold: true; font.pixelSize: 12; font.letterSpacing: 1.5 }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 24
                            
                            // Speed control
                            Rectangle {
                                visible: activeMode !== "Static"
                                Layout.fillWidth: true
                                height: 90
                                radius: 12
                                color: theme.isDark ? Qt.rgba(255,255,255,0.03) : Qt.rgba(0,0,0,0.02)
                                border.width: 1
                                border.color: theme.isDark ? Qt.rgba(255,255,255,0.06) : Qt.rgba(0,0,0,0.04)
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 12
                                    
                                    RowLayout {
                                        spacing: 6
                                        Canvas {
                                            width: 14; height: 14
                                            onPaint: {
                                                var ctx = getContext("2d");
                                                ctx.strokeStyle = "#a855f7"; ctx.lineWidth = 2; ctx.lineCap = "round";
                                                ctx.beginPath(); ctx.moveTo(7, 2); ctx.lineTo(7, 7); ctx.lineTo(11, 7); ctx.stroke();
                                                ctx.beginPath(); ctx.arc(7, 7, 5, 0, Math.PI * 2); ctx.stroke();
                                            }
                                        }
                                        Text { text: qsTr("SPEED"); color: theme.textSecondary; font.bold: true; font.pixelSize: 11 }
                                    }
                                    
                                    // Segmented buttons for speed
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        
                                        Repeater {
                                            model: [{ val: 1, label: qsTr("Slow") }, { val: 2, label: qsTr("Medium") }, { val: 3, label: qsTr("Fast") }]
                                            delegate: Rectangle {
                                                Layout.fillWidth: true
                                                height: 36
                                                radius: 8
                                                color: initSpeed === modelData.val ? "#a855f7" : (speedBtnHover.containsMouse ? Qt.rgba(168/255, 85/255, 247/255, 0.2) : "transparent")
                                                border.width: initSpeed === modelData.val ? 0 : 1
                                                border.color: speedBtnHover.containsMouse ? "#a855f7" : (theme.isDark ? Qt.rgba(255,255,255,0.1) : Qt.rgba(0,0,0,0.1))
                                                
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                
                                                MouseArea {
                                                    id: speedBtnHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: { initSpeed = modelData.val; applyAura() }
                                                }
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    color: initSpeed === modelData.val ? "#fff" : theme.textSecondary
                                                    font.bold: true
                                                    font.pixelSize: 12
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Brightness control
                            Rectangle {
                                Layout.fillWidth: true
                                height: 90
                                radius: 12
                                color: theme.isDark ? Qt.rgba(255,255,255,0.03) : Qt.rgba(0,0,0,0.02)
                                border.width: 1
                                border.color: theme.isDark ? Qt.rgba(255,255,255,0.06) : Qt.rgba(0,0,0,0.04)
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 12
                                    
                                    RowLayout {
                                        spacing: 6
                                        Canvas {
                                            width: 14; height: 14
                                            onPaint: {
                                                var ctx = getContext("2d");
                                                ctx.fillStyle = "#f59e0b";
                                                ctx.beginPath(); ctx.arc(7, 7, 4, 0, Math.PI * 2); ctx.fill();
                                                ctx.strokeStyle = "#f59e0b"; ctx.lineWidth = 1.5;
                                                for (var i = 0; i < 8; i++) {
                                                    var angle = i * Math.PI / 4;
                                                    ctx.beginPath();
                                                    ctx.moveTo(7 + Math.cos(angle) * 5, 7 + Math.sin(angle) * 5);
                                                    ctx.lineTo(7 + Math.cos(angle) * 7, 7 + Math.sin(angle) * 7);
                                                    ctx.stroke();
                                                }
                                            }
                                        }
                                        Text { text: qsTr("BRIGHTNESS"); color: theme.textSecondary; font.bold: true; font.pixelSize: 11 }
                                    }
                                    
                                    // Segmented buttons for brightness
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        
                                        Repeater {
                                            model: [{ val: 0, label: qsTr("Off") }, { val: 1, label: qsTr("Low") }, { val: 2, label: qsTr("Med") }, { val: 3, label: qsTr("High") }]
                                            delegate: Rectangle {
                                                Layout.fillWidth: true
                                                height: 36
                                                radius: 8
                                                color: brightnessLevel === modelData.val ? "#f59e0b" : (brightBtnHover.containsMouse ? Qt.rgba(245/255, 158/255, 11/255, 0.2) : "transparent")
                                                border.width: brightnessLevel === modelData.val ? 0 : 1
                                                border.color: brightBtnHover.containsMouse ? "#f59e0b" : (theme.isDark ? Qt.rgba(255,255,255,0.1) : Qt.rgba(0,0,0,0.1))
                                                
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                
                                                MouseArea {
                                                    id: brightBtnHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: { brightnessLevel = modelData.val; aura.setBrightness(brightnessLevel) }
                                                }
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    color: brightnessLevel === modelData.val ? "#fff" : theme.textSecondary
                                                    font.bold: true
                                                    font.pixelSize: 12
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    

                }
            }
            
            Item { Layout.preferredHeight: 30 }
            } // End ColumnLayout
        } // End centerWrapper Item
    } // End Flickable
} // End auraPage Item
