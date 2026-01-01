import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "transparent"
    
    // API Properties
    property string title: "CPU"
    property real usage: 0
    property real temp: 0
    property real freq: 0
    property real rpm: 0
    property string accentColor: "#0078d4"
    property bool isGpu: false
    property bool showRpm: true
    property var appTheme: null
    
    // Safe theme accessors
    property bool _isDark: appTheme ? appTheme.isDark : true
    property int _space1: appTheme ? appTheme.space1 : 4
    property int _space2: appTheme ? appTheme.space2 : 8
    property int _space3: appTheme ? appTheme.space3 : 12
    property int _space4: appTheme ? appTheme.space4 : 16
    property int _space5: appTheme ? appTheme.space5 : 20
    property int _radiusLarge: appTheme ? appTheme.radiusLarge : 14
    property int _radiusMedium: appTheme ? appTheme.radiusMedium : 10
    property color _surface: appTheme ? appTheme.surface : (_isDark ? "#1a1a1a" : "#f5f5f5")
    property color _border: appTheme ? appTheme.border : (_isDark ? "#2a2a2a" : "#d0d0d0")
    property color _borderLight: appTheme ? appTheme.borderLight : (_isDark ? "#1f1f1f" : "#e0e0e0")
    property color _textPrimary: appTheme ? appTheme.textPrimary : (_isDark ? "#ffffff" : "#0a0a0a")
    property color _textSecondary: appTheme ? appTheme.textSecondary : (_isDark ? "#b0b0b0" : "#3a3a3a")
    property color _textTertiary: appTheme ? appTheme.textTertiary : (_isDark ? "#707070" : "#6a6a6a")
    property color _success: appTheme ? appTheme.success : "#00d563"
    property color _warning: appTheme ? appTheme.warning : "#ffa500"
    property color _danger: appTheme ? appTheme.danger : "#ff4444"
    property int _fontSizeH4: appTheme ? appTheme.fontSizeH4 : 18
    property int _fontSizeSmall: appTheme ? appTheme.fontSizeSmall : 12
    property int _fontSizeTiny: appTheme ? appTheme.fontSizeTiny : 10
    property int _fontWeightBold: appTheme ? appTheme.fontWeightBold : Font.Bold
    property int _transitionSlow: appTheme ? appTheme.transitionSlow : 350
    property color _shadowSmall: appTheme ? appTheme.shadowSmall : Qt.rgba(0, 0, 0, 0.3)
    
    // Internal state
    property real animatedUsage: 0
    property real animatedRpm: 0
    
    Behavior on animatedUsage {
        NumberAnimation { duration: _transitionSlow; easing.type: Easing.OutCubic }
    }
    Behavior on animatedRpm {
        NumberAnimation { duration: _transitionSlow; easing.type: Easing.OutCubic }
    }
    
    onUsageChanged: animatedUsage = usage
    onRpmChanged: animatedRpm = rpm
    
    Component.onCompleted: {
        animatedUsage = usage
        animatedRpm = rpm
    }
    
    // Multi-layer shadow system
    Repeater {
        model: 3
        Rectangle {
            anchors.fill: cardBase
            anchors.margins: -index * 3 - 2
            radius: _radiusLarge + index * 2
            color: "transparent"
            border.color: _shadowSmall
            border.width: 1
            opacity: 0.2 - index * 0.06
            z: -10 - index
        }
    }
    
    // Main card container
    Rectangle {
        id: cardBase
        anchors.fill: parent
        anchors.margins: _space2
        radius: _radiusLarge
        color: _surface
        border.width: 1
        border.color: _border
        
        // Subtle gradient overlay for depth
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: 0.15
            
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(root.accentColor, 1.8) }
                GradientStop { position: 0.6; color: "transparent" }
                GradientStop { position: 1.0; color: _isDark ? "#000000" : "#ffffff" }
            }
        }
        
        // Content Layout
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: _space5
            spacing: _space4
            
            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: _space3
                
                // Title
                Text {
                    text: root.title
                    color: _textPrimary
                    font.pixelSize: _fontSizeH4
                    font.weight: _fontWeightBold
                    font.letterSpacing: 1.2
                }
                
                Item { Layout.fillWidth: true }
                
                // Live Status Indicator
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: root.accentColor
                    
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 1000 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 1000 }
                    }
                    
                    // Glow ring
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 8
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.color: root.accentColor
                        border.width: 1
                        opacity: 0.35
                    }
                }
            }
            
            // Gauge Section
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 260
                
                Item {
                    id: gaugeContainer
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height)
                    height: width
                    
                    // Main gauge canvas
                    Canvas {
                        id: gaugeCanvas
                        anchors.fill: parent
                        antialiasing: true
                        renderStrategy: Canvas.Threaded
                        
                        property real displayValue: root.showRpm ? root.animatedRpm : root.animatedUsage
                        
                        onDisplayValueChanged: requestPaint()
                        
                        onPaint: {
                            var ctx = getContext("2d")
                            if (!ctx) return
                            
                            ctx.clearRect(0, 0, width, height)
                            
                            var cx = width / 2
                            var cy = height / 2
                            var outerR = (width / 2) - 20
                            var innerR = outerR - 18
                            
                            var startAngle = 0.70 * Math.PI
                            var endAngle = 2.30 * Math.PI
                            var fullSweep = endAngle - startAngle
                            
                            // Calculate progress
                            var progress = 0.0
                            if (root.showRpm) {
                                progress = Math.min(1.0, displayValue / 6000.0)
                            } else {
                                progress = Math.min(1.0, displayValue / 100.0)
                            }
                            
                            // Background track (shows full arc path)
                            ctx.beginPath()
                            ctx.arc(cx, cy, outerR, startAngle, endAngle)
                            ctx.lineWidth = 20
                            ctx.strokeStyle = _isDark ? Qt.rgba(0.25, 0.25, 0.25, 0.8) : Qt.rgba(0.80, 0.80, 0.80, 0.8)
                            ctx.lineCap = "round"
                            ctx.stroke()
                            
                            // Progress arc with gradient
                            if (progress > 0.01) {
                                var progressGradient = ctx.createLinearGradient(0, 0, width, height)
                                progressGradient.addColorStop(0, root.accentColor)
                                progressGradient.addColorStop(0.5, Qt.lighter(root.accentColor, 1.4))
                                progressGradient.addColorStop(1, root.accentColor)
                                
                                ctx.beginPath()
                                ctx.arc(cx, cy, outerR, startAngle, startAngle + (fullSweep * progress))
                                ctx.lineWidth = 22
                                ctx.strokeStyle = progressGradient
                                ctx.lineCap = "round"
                                ctx.stroke()
                                
                                // Inner glow
                                ctx.globalAlpha = 0.40
                                ctx.lineWidth = 28
                                ctx.stroke()
                                ctx.globalAlpha = 1.0
                                
                                // Endpoint dot
                                var progressAngle = startAngle + (fullSweep * progress)
                                var dotX = cx + outerR * Math.cos(progressAngle)
                                var dotY = cy + outerR * Math.sin(progressAngle)
                                
                                ctx.beginPath()
                                ctx.arc(dotX, dotY, 12, 0, 2 * Math.PI)
                                ctx.fillStyle = "#ffffff"
                                ctx.fill()
                                
                                ctx.beginPath()
                                ctx.arc(dotX, dotY, 9, 0, 2 * Math.PI)
                                ctx.fillStyle = root.accentColor
                                ctx.fill()
                            }
                            
                            // Tick marks - solid color for visibility
                            ctx.strokeStyle = _isDark ? "#666666" : "#999999"
                            ctx.lineWidth = 3
                            for (var i = 0; i <= 12; i++) {
                                var tickAngle = startAngle + (fullSweep * i / 12)
                                var isMajor = (i % 3 === 0)
                                var tickR1 = outerR + 14
                                var tickR2 = tickR1 + (isMajor ? 8 : 5)
                                
                                ctx.beginPath()
                                ctx.moveTo(cx + tickR1 * Math.cos(tickAngle), cy + tickR1 * Math.sin(tickAngle))
                                ctx.lineTo(cx + tickR2 * Math.cos(tickAngle), cy + tickR2 * Math.sin(tickAngle))
                                ctx.stroke()
                            }
                        }
                    }
                    
                    // Center text display (no background circle)
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: _space1
                        width: parent.width * 0.45
                        
                        // Value with text glow
                        Item {
                            Layout.preferredHeight: 48
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            
                            Text {
                                id: valueText
                                anchors.centerIn: parent
                                width: parent.width
                                text: root.showRpm ? root.animatedRpm.toFixed(0) : root.animatedUsage.toFixed(1) + "%"
                                color: _textPrimary
                                font.pixelSize: {
                                    // Responsive font size based on text length
                                    if (text.length <= 2) return 32  // "0", "12"
                                    if (text.length <= 3) return 28  // "100", "5.2%"
                                    if (text.length <= 4) return 24  // "2300"
                                    return 22  // "10000"
                                }
                                font.weight: _fontWeightBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                fontSizeMode: Text.Fit
                                minimumPixelSize: 20
                                elide: Text.ElideNone
                            }
                            
                            // Glow simulation
                            Repeater {
                                model: 2
                                Text {
                                    anchors.centerIn: parent
                                    width: valueText.width
                                    text: valueText.text
                                    color: root.accentColor
                                    font: valueText.font
                                    opacity: 0.22 - index * 0.10
                                    scale: 1.0 + index * 0.015
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    fontSizeMode: Text.Fit
                                    minimumPixelSize: 20
                                }
                            }
                        }
                        
                        Text {
                            text: root.showRpm ? qsTr("RPM") : qsTr("USAGE")
                            color: _textSecondary
                            font.pixelSize: _fontSizeTiny
                            font.weight: _fontWeightBold
                            font.letterSpacing: 2.2
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
            
            // Bottom metrics row
            RowLayout {
                Layout.fillWidth: true
                spacing: _space3
                
                // Temperature Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    radius: _radiusMedium
                    color: _isDark ? Qt.rgba(0.10, 0.10, 0.10, 0.95) : Qt.rgba(0.96, 0.96, 0.96, 0.95)
                    border.color: _borderLight
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: _space1
                        
                        Text {
                            text: qsTr("TEMPERATURE")
                            color: _textTertiary
                            font.pixelSize: _fontSizeTiny
                            font.weight: _fontWeightBold
                            font.letterSpacing: 1.5
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Text {
                            text: root.temp.toFixed(0) + "°C"
                            color: {
                                if (!appTheme) return "#00d563"
                                if (root.temp > 80) return _danger
                                if (root.temp > 65) return _warning
                                return _success
                            }
                            font.pixelSize: 22
                            font.weight: _fontWeightBold
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 3
                            radius: 1.5
                            Layout.alignment: Qt.AlignHCenter
                            color: {
                                if (!appTheme) return "#00d563"
                                if (root.temp > 80) return _danger
                                if (root.temp > 65) return _warning
                                return _success
                            }
                            opacity: 0.6
                        }
                    }
                }
                
                // Frequency Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    radius: _radiusMedium
                    color: _isDark ? Qt.rgba(0.10, 0.10, 0.10, 0.95) : Qt.rgba(0.96, 0.96, 0.96, 0.95)
                    border.color: _borderLight
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: _space1
                        
                        Text {
                            text: qsTr("FREQUENCY")
                            color: _textTertiary
                            font.pixelSize: _fontSizeTiny
                            font.weight: _fontWeightBold
                            font.letterSpacing: 1.5
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Text {
                            text: root.freq.toFixed(0) + " MHz"
                            color: root.accentColor
                            font.pixelSize: 22
                            font.weight: _fontWeightBold
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 3
                            radius: 1.5
                            Layout.alignment: Qt.AlignHCenter
                            color: root.accentColor
                            opacity: 0.6
                        }
                    }
                }
            }
        }
    }
}
