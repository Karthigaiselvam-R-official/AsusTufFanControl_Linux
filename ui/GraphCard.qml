import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    property string title: "Graph"
    property string icon: ""
    property string suffix: "%"
    property var dataModel: [] // Array of values 0-100
    property string currentValue: "0"
    property string extraText: ""
    property color graphColor: "#0078d4"
    property real maxValue: 100.0
    property bool autoScale: false
    
    // Premium glassmorphism background
    color: "transparent"
    
    // Glass card
    Rectangle {
        id: glassCard
        anchors.fill: parent
        radius: 16
        color: theme.isDark ? Qt.rgba(25/255, 25/255, 30/255, 0.95) : Qt.rgba(255/255, 255/255, 255/255, 0.95)
        border.width: 1
        border.color: theme.isDark ? Qt.rgba(255,255,255,0.08) : Qt.rgba(0,0,0,0.06)
        
        // Top accent glow line
        Rectangle {
            width: parent.width - 40
            height: 2
            anchors.top: parent.top
            anchors.topMargin: 0
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 1
            color: root.graphColor
            opacity: 0.6
            
            // Animated glow
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: root.graphColor
                
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.3; to: 0.8; duration: 1500; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.8; to: 0.3; duration: 1500; easing.type: Easing.InOutSine }
                }
            }
        }
        

        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8
            
            // Header Row - Premium style
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                // Icon container with gradient
                Rectangle {
                    width: 32; height: 32; radius: 8
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.graphColor }
                        GradientStop { position: 1.0; color: Qt.darker(root.graphColor, 1.3) }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: root.icon
                        font.pixelSize: 16
                    }
                }
                
                // Title with tracking
                ColumnLayout {
                    spacing: 2
                    Text { 
                        text: root.title
                        font.bold: true
                        font.pixelSize: 13
                        font.letterSpacing: 1.5
                        color: theme.textSecondary
                    }
                    Text {
                        visible: root.extraText !== ""
                        text: root.extraText
                        color: theme.textTertiary
                        font.pixelSize: 10
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // Live value with glow effect
                Rectangle {
                    width: valueText.width + 20
                    height: 32
                    radius: 16
                    color: Qt.rgba(root.graphColor.r, root.graphColor.g, root.graphColor.b, 0.15)
                    border.width: 1
                    border.color: Qt.rgba(root.graphColor.r, root.graphColor.g, root.graphColor.b, 0.3)
                    
                    Text { 
                        id: valueText
                        anchors.centerIn: parent
                        text: root.currentValue + root.suffix
                        font.bold: true
                        font.pixelSize: 16
                        color: root.graphColor
                    }
                }
            }
            
            Item { Layout.fillHeight: true; Layout.minimumHeight: 8 }
            
            // Premium Graph Canvas with glow
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                
                // Subtle grid lines
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = theme.isDark ? Qt.rgba(255,255,255,0.05) : Qt.rgba(0,0,0,0.05)
                        ctx.lineWidth = 1
                        
                        // Horizontal lines
                        for (var i = 0; i <= 4; i++) {
                            var y = (height / 4) * i
                            ctx.beginPath()
                            ctx.moveTo(0, y)
                            ctx.lineTo(width, y)
                            ctx.stroke()
                        }
                    }
                }
                
                // Main graph with glow effect
                Canvas {
                    id: graph
                    anchors.fill: parent
                    contextType: "2d"
                    
                    onPaint: {
                        var ctx = context;
                        ctx.clearRect(0, 0, width, height);
                        
                        if (root.dataModel.length < 2) return;
                        
                        var stepX = width / (root.dataModel.length - 1);
                        var minVal = 0;
                        var maxVal = root.maxValue;
                        
                        if (root.autoScale) {
                            minVal = 999999;
                            maxVal = -999999;
                            for(var k=0; k<root.dataModel.length; k++) {
                                var v = root.dataModel[k];
                                if(v < minVal) minVal = v;
                                if(v > maxVal) maxVal = v;
                            }
                            var range = maxVal - minVal;
                            if (range < 2) { 
                                var mid = (minVal + maxVal) / 2;
                                minVal = Math.max(0, mid - 1);
                                maxVal = mid + 1;
                            }
                            minVal -= range * 0.1; 
                            maxVal += range * 0.1;
                            if (minVal < 0) minVal = 0;
                        }
                        
                        // Premium gradient fill
                        var gradient = ctx.createLinearGradient(0, 0, 0, height);
                        gradient.addColorStop(0, Qt.rgba(root.graphColor.r, root.graphColor.g, root.graphColor.b, 0.35));
                        gradient.addColorStop(0.5, Qt.rgba(root.graphColor.r, root.graphColor.g, root.graphColor.b, 0.15));
                        gradient.addColorStop(1, Qt.rgba(root.graphColor.r, root.graphColor.g, root.graphColor.b, 0.02));
                        
                        ctx.beginPath();
                        ctx.moveTo(0, height);
                        
                        for (var i = 0; i < root.dataModel.length; i++) {
                            var val = root.dataModel[i];
                            var norm = (val - minVal) / (maxVal - minVal);
                            norm = Math.max(0, Math.min(1, norm));
                            var y = height - (norm * height);
                            
                            // Smooth curve using quadratic bezier
                            if (i === 0) {
                                ctx.lineTo(0, y);
                            } else {
                                var prevX = (i - 1) * stepX;
                                var prevVal = root.dataModel[i - 1];
                                var prevNorm = (prevVal - minVal) / (maxVal - minVal);
                                prevNorm = Math.max(0, Math.min(1, prevNorm));
                                var prevY = height - (prevNorm * height);
                                
                                var cpX = (prevX + i * stepX) / 2;
                                ctx.quadraticCurveTo(cpX, prevY, i * stepX, y);
                            }
                        }
                        
                        ctx.lineTo((root.dataModel.length-1) * stepX, height);
                        ctx.closePath();
                        ctx.fillStyle = gradient;
                        ctx.fill();
                        
                        // Glowing stroke line
                        ctx.beginPath();
                        ctx.strokeStyle = root.graphColor;
                        ctx.lineWidth = 3;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";
                        
                        // Add shadow/glow
                        ctx.shadowColor = root.graphColor;
                        ctx.shadowBlur = 8;
                        
                        for (var j = 0; j < root.dataModel.length; j++) {
                            var val2 = root.dataModel[j];
                            var norm2 = (val2 - minVal) / (maxVal - minVal);
                            norm2 = Math.max(0, Math.min(1, norm2));
                            var y2 = height - (norm2 * height);
                            
                            if (j === 0) {
                                ctx.moveTo(0, y2);
                            } else {
                                var prevX2 = (j - 1) * stepX;
                                var prevVal2 = root.dataModel[j - 1];
                                var prevNorm2 = (prevVal2 - minVal) / (maxVal - minVal);
                                prevNorm2 = Math.max(0, Math.min(1, prevNorm2));
                                var prevY2 = height - (prevNorm2 * height);
                                
                                var cpX2 = (prevX2 + j * stepX) / 2;
                                ctx.quadraticCurveTo(cpX2, prevY2, j * stepX, y2);
                            }
                        }
                        ctx.stroke();
                        
                        // Draw current value dot with glow
                        if (root.dataModel.length > 0) {
                            var lastVal = root.dataModel[root.dataModel.length - 1];
                            var lastNorm = (lastVal - minVal) / (maxVal - minVal);
                            lastNorm = Math.max(0, Math.min(1, lastNorm));
                            var lastY = height - (lastNorm * height);
                            var lastX = (root.dataModel.length - 1) * stepX;
                            
                            // Outer glow ring
                            ctx.beginPath();
                            ctx.arc(lastX, lastY, 8, 0, 2 * Math.PI);
                            ctx.fillStyle = Qt.rgba(root.graphColor.r, root.graphColor.g, root.graphColor.b, 0.2);
                            ctx.fill();
                            
                            // Inner dot
                            ctx.beginPath();
                            ctx.arc(lastX, lastY, 4, 0, 2 * Math.PI);
                            ctx.fillStyle = root.graphColor;
                            ctx.fill();
                            
                            // Center highlight
                            ctx.beginPath();
                            ctx.arc(lastX - 1, lastY - 1, 1.5, 0, 2 * Math.PI);
                            ctx.fillStyle = "#ffffff";
                            ctx.fill();
                        }
                    }
                }
            }
            

        }
    }
    
    onDataModelChanged: graph.requestPaint()
}
