import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import ".."

Item {
    id: dashboardPage
    
    // Dependencies
    property var backend
    property var monitor
    property var theme
    
    // History Data (Moved from Main.qml)
    property var ramHistory: []
    property var diskHistory: []
    property var netDownHistory: []
    property var netUpHistory: []
    property var tempHistory: []
    property var cpuHistory: []
    property var gpuHistory: []

    // Timer for Graphs
    Timer { 
        interval: 1000; running: true; repeat: true; 
        onTriggered: {
            backend.statsUpdated(); // Fetch backend temps
            
            // Push values to history
            var rh = ramHistory; rh.push(monitor.memoryUsage); if(rh.length>60) rh.shift(); ramHistory = rh;
            var dh = diskHistory; dh.push(monitor.diskUsage); if(dh.length>60) dh.shift(); diskHistory = dh;
            var th = tempHistory; th.push(backend.cpuTemp); if(th.length>60) th.shift(); tempHistory = th;
            var nd = netDownHistory; nd.push(monitor.netDown); if(nd.length>60) nd.shift(); netDownHistory = nd;
            var ch = cpuHistory; ch.push(monitor.cpuUsage); if(ch.length>60) ch.shift(); cpuHistory = ch;
            var gh = gpuHistory; gh.push(monitor.gpuUsage); if(gh.length>60) gh.shift(); gpuHistory = gh;
        } 
    }

    // Helper
    function formatNet(kb) {
        if (kb > 1024) return (kb/1024).toFixed(1) + " MB/s"
        return kb.toFixed(1) + " KB/s"
    }
    
    // Battery Color Logic
    function getBatteryColor(pct) {
        if (pct <= 30) return "#ff1744" // Red
        if (pct <= 60) return "#ff9100" // Orange
        if (pct <= 90) return "#00e676" // Green
        return "#00e5ff" // Cyan
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: parent.width
        contentHeight: contentCol.implicitHeight + 40
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            id: contentCol
            width: dashboardPage.width
            spacing: 30 // Increased from 20 for better visual separation
            anchors.margins: 20
            
            // Spacer top
            Item { height: 10; Layout.fillWidth: true }

            // 1. System Info & Battery (The "Header" Card)
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 20; Layout.rightMargin: 20
                Layout.preferredHeight: sysInfoContent.implicitHeight + 40
                color: theme.surface
                radius: 8
                
                RowLayout {
                    id: sysInfoContent
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20
                    
                    // Laptop Model Info
                    ColumnLayout {
                        Layout.fillHeight: true
                        Layout.preferredWidth: parent.width * 0.4
                        spacing: 5
                        Text { 
                            text: monitor.laptopModel
                            color: theme.accent
                            font.bold: true
                            font.pixelSize: 22 
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        Text { 
                            text: monitor.osVersion
                            color: "#26c6da"
                            font.pixelSize: 12
                        }
                        Item { Layout.fillHeight: true }
                        
                        // Battery
                         RowLayout {
                            spacing: 12
                            Rectangle {
                                width: 40; height: 20
                                color: "transparent"
                                border.color: getBatteryColor(monitor.batteryPercent)
                                border.width: 2; radius: 4
                                Rectangle {
                                    width: (parent.width - 6) * (monitor.batteryPercent / 100.0)
                                    height: parent.height - 6
                                    x: 3; y: 3; radius: 2
                                    color: parent.border.color
                                }
                                // Charging Bolt
                                Text {
                                    visible: monitor.isCharging
                                    text: "⚡"
                                    color: "#fff"
                                    font.pixelSize: 14
                                    anchors.centerIn: parent
                                    style: Text.Outline; styleColor: "#000"
                                }
                            }
                            Text { 
                                text: monitor.batteryPercent + "%"
                                color: getBatteryColor(monitor.batteryPercent)
                                font.bold: true
                                font.pixelSize: 18
                            }
                             Text { 
                                visible: monitor.isCharging
                                text: qsTr("(Charging)")
                                color: theme.textSecondary
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                    
                    Rectangle { width: 1; Layout.fillHeight: true; color: theme.border }
                    
                    // Hardware Specs (CPU/GPU Names)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        // CPU
                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle { width: 40; height: 20; color: theme.isDark ? "#4a2a1a" : "#fff3e0"; radius: 4; 
                                Text { text: "CPU"; anchors.centerIn: parent; color: "#ff9800"; font.bold: true; font.pixelSize: 10 }
                            }
                            Text { 
                                text: monitor.cpuModel.replace("11th Gen ", "").replace("(R)", "").replace("(TM)", "").replace(" @ 2.70GHz", "")
                                color: "#4dd0e1"; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true 
                            }
                        }
                        
                        // GPUs
                        Repeater {
                            model: monitor.gpuModels
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                Rectangle { width: 40; height: 20; color: theme.isDark ? "#3a1a4a" : "#f3e5f5"; radius: 4; 
                                    Text { text: "GPU"; anchors.centerIn: parent; color: "#ab47bc"; font.bold: true; font.pixelSize: 10 }
                                }
                                Text { 
                                    text: modelData
                                    color: "#ffd54f"; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true 
                                }
                            }
                        }
                    }
                }
            }

            // 2. Live Stats Cards (CPU / GPU)
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20; Layout.rightMargin: 20
                spacing: 20
                
                StatsCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 360
                    title: "CPU"
                    usage: monitor.cpuUsage
                    temp: backend.cpuTemp
                    freq: monitor.cpuFreq
                    rpm: backend.cpuFanRpm
                    accentColor: theme ? theme.accent : "#0078d4"
                    showRpm: true
                    appTheme: theme
                }
                StatsCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 360
                    title: "GPU"
                    usage: monitor.gpuUsage
                    temp: backend.gpuTemp
                    freq: monitor.gpuFreq
                    rpm: backend.gpuFanRpm
                    accentColor: "#448aff"
                    isGpu: true
                    showRpm: true
                    appTheme: theme
                }
            }
            
            // 3. Graphs (CPU / GPU / RAM / Net)
            GridLayout {
                columns: parent.width > 1400 ? 4 : 2
                Layout.fillWidth: true
                Layout.leftMargin: 20; Layout.rightMargin: 20
                columnSpacing: 20; rowSpacing: 20
                
                GraphCard {
                    Layout.fillWidth: true; Layout.preferredHeight: 160
                    title: qsTr("CPU USAGE")
                    icon: "⚡"
                    suffix: "%"
                    currentValue: monitor.cpuUsage.toFixed(1)
                    extraText: qsTr("History")
                    dataModel: cpuHistory
                    maxValue: 100
                    graphColor: theme.accent // Revert to Blue
                }
                 GraphCard {
                    Layout.fillWidth: true; Layout.preferredHeight: 160
                    title: qsTr("GPU USAGE")
                    icon: "🎮"
                    suffix: "%"
                    currentValue: monitor.gpuUsage.toFixed(1)
                    extraText: qsTr("History")
                    dataModel: gpuHistory
                    maxValue: 100
                    graphColor: "#448aff" 
                }
                GraphCard {
                    Layout.fillWidth: true; Layout.preferredHeight: 160
                    title: qsTr("RAM USAGE")
                    icon: "💾"
                    suffix: "%"
                    currentValue: monitor.memoryUsage.toFixed(1)
                    extraText: qsTr("System Memory")
                    dataModel: ramHistory
                    maxValue: 100
                    graphColor: "#00bfa5" 
                }
                GraphCard {
                    Layout.fillWidth: true; Layout.preferredHeight: 160
                    title: qsTr("NETWORK")
                    icon: "🌐"
                    suffix: ""
                    currentValue: formatNet(monitor.netDown)
                    extraText: qsTr("Up: ") + formatNet(monitor.netUp)
                    dataModel: netDownHistory
                    maxValue: 1000 
                    autoScale: true
                    graphColor: "#e040fb"
                }
            }
            
            // 4. Disk Usage - Ultra Premium Design
             Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 20; Layout.rightMargin: 20
                Layout.preferredHeight: diskCol.implicitHeight + 60
                color: "transparent"
                
                // Glassmorphism background
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: theme.isDark ? Qt.rgba(30/255, 30/255, 35/255, 0.95) : Qt.rgba(250/255, 250/255, 252/255, 0.98)
                    border.width: 1
                    border.color: theme.isDark ? Qt.rgba(255,255,255,0.08) : Qt.rgba(0,0,0,0.06)
                    
                    // Top accent gradient line
                    Rectangle {
                        width: parent.width - 60
                        height: 3
                        anchors.top: parent.top
                        anchors.topMargin: -1
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#00b4d8" }
                            GradientStop { position: 0.5; color: "#4361ee" }
                            GradientStop { position: 1.0; color: "#7209b7" }
                        }
                    }
                }
                
                ColumnLayout {
                    id: diskCol
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 24
                    
                    // Premium Header
                    RowLayout {
                        spacing: 16
                        
                        // Icon with gradient bg
                        Rectangle {
                            width: 44; height: 44; radius: 12
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#4361ee" }
                                GradientStop { position: 1.0; color: "#3a0ca3" }
                            }
                            Text { anchors.centerIn: parent; text: "💿"; font.pixelSize: 22 }
                        }
                        
                        ColumnLayout {
                            spacing: 2
                            Text { text: qsTr("Storage Overview"); color: theme.textPrimary; font.bold: true; font.pixelSize: 18 }
                            Text { text: monitor.diskPartitions.length + " " + qsTr("drives detected"); color: theme.textTertiary; font.pixelSize: 12 }
                        }
                        Item { Layout.fillWidth: true }
                    }
                    // Sleek Divider
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.isDark ? Qt.rgba(255,255,255,0.06) : Qt.rgba(0,0,0,0.06) }
                    
                    // Premium Drives List
                    Repeater {
                        model: monitor.diskPartitions
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: modelData.hasUsage ? 100 : 70
                            radius: 12
                            color: theme.isDark ? Qt.rgba(255,255,255,0.03) : Qt.rgba(0,0,0,0.02)
                            border.width: driveHover.containsMouse ? 2 : 1
                            border.color: driveHover.containsMouse ? theme.accent : (theme.isDark ? Qt.rgba(255,255,255,0.06) : Qt.rgba(0,0,0,0.04))
                            
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            
                            MouseArea { 
                                id: driveHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { /* Single click does nothing now, helps selection feel */ }
                                onDoubleClicked: monitor.openFileManager(modelData.mount, modelData.device)
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 16
                                
                                // Drive Icon - always centered vertically
                                Rectangle {
                                    width: 42; height: 42; radius: 10
                                    Layout.alignment: Qt.AlignVCenter
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: modelData.hasUsage ? (modelData.usage > 90 ? "#ff4444" : "#4361ee") : "#6b7280" }
                                        GradientStop { position: 1.0; color: modelData.hasUsage ? (modelData.usage > 90 ? "#dc2626" : "#3730a3") : "#4b5563" }
                                    }
                                    Text { anchors.centerIn: parent; text: modelData.hasUsage ? "🖴" : "💾"; font.pixelSize: 20 }
                                }
                                
                                // Info Column - centered for all cases
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: modelData.hasUsage ? 6 : 8
                                    
                                    // Row 1: Name + Badges
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        
                                        Text {
                                            text: modelData.name
                                            color: theme.textPrimary
                                            font.bold: true
                                            font.pixelSize: 15
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        
                                        // Total size badge - cyan
                                        Rectangle {
                                            width: sizeBadge.width + 14; height: 22; radius: 11
                                            color: theme.isDark ? Qt.rgba(0,180,216,0.15) : Qt.rgba(0,180,216,0.1)
                                            Text { id: sizeBadge; anchors.centerIn: parent; text: Number(modelData.total).toFixed(1) + " GB"; color: "#00b4d8"; font.pixelSize: 11; font.bold: true }
                                        }
                                        
                                        // Used space badge - purple (mounted only)
                                        Rectangle {
                                            visible: modelData.hasUsage
                                            width: usedBadge.width + 14; height: 22; radius: 11
                                            color: theme.isDark ? Qt.rgba(168,85,247,0.15) : Qt.rgba(168,85,247,0.1)
                                            Text { id: usedBadge; anchors.centerIn: parent; text: Number(modelData.used).toFixed(1) + " " + qsTr("GB used"); color: "#a855f7"; font.pixelSize: 11; font.bold: true }
                                        }
                                        
                                        // Free space badge - green (mounted only)
                                        Rectangle {
                                            visible: modelData.hasUsage
                                            width: freeBadge.width + 14; height: 22; radius: 11
                                            color: theme.isDark ? Qt.rgba(16,185,129,0.15) : Qt.rgba(16,185,129,0.1)
                                            Text { id: freeBadge; anchors.centerIn: parent; text: Number(modelData.free).toFixed(1) + " " + qsTr("GB free"); color: "#10b981"; font.pixelSize: 11; font.bold: true }
                                        }
                                    }
                                    
                                    // Row 2: Progress Bar (mounted only)
                                    Rectangle {
                                        visible: modelData.hasUsage
                                        Layout.fillWidth: true
                                        height: 8
                                        radius: 4
                                        color: theme.isDark ? Qt.rgba(255,255,255,0.08) : Qt.rgba(0,0,0,0.08)
                                        
                                        Rectangle {
                                            width: parent.width * (modelData.usage / 100.0)
                                            height: parent.height
                                            radius: parent.radius
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0; color: modelData.usage > 90 ? "#ff4444" : (modelData.usage > 70 ? "#f59e0b" : "#06b6d4") }
                                                GradientStop { position: 1.0; color: modelData.usage > 90 ? "#ef4444" : (modelData.usage > 70 ? "#eab308" : "#4361ee") }
                                            }
                                            
                                            // Shine
                                            Rectangle {
                                                width: parent.width; height: parent.height / 2; radius: parent.radius
                                                anchors.top: parent.top
                                                gradient: Gradient { GradientStop { position: 0.0; color: Qt.rgba(255,255,255,0.3) } GradientStop { position: 1.0; color: "transparent" } }
                                            }
                                        }
                                    }
                                    
                                    // Row 3: Percentage text (mounted only)
                                    Text {
                                        visible: modelData.hasUsage
                                        text: Math.round(modelData.usage) + "% " + qsTr("of storage used")
                                        color: modelData.usage > 90 ? "#ff4444" : (modelData.usage > 70 ? "#ffa500" : theme.textSecondary)
                                        font.pixelSize: 11
                                    }
                                    
                                    // Unmounted status
                                    RowLayout {
                                        visible: !modelData.hasUsage
                                        spacing: 8
                                        Rectangle { width: 8; height: 8; radius: 4; color: "#f59e0b" }
                                        Text { text: qsTr("Drive not mounted"); color: "#f59e0b"; font.pixelSize: 12 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Item { Layout.preferredHeight: 20 } // Bottom padding
        }
    }
}
