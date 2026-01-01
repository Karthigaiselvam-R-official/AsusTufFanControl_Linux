import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import AsusTufFanControl 1.0
import "components"
import "pages"

ApplicationWindow {
    id: window
    visible: true
    width: 1200
    height: 800
    minimumWidth: 1000
    minimumHeight: 700
    title: qsTr("ASUS TUF Fan Control")
    color: theme.background
    
    // Restore Aura on close (logic remains)
    onClosing: aura.restoreServices(auraPage.activeMode, auraPage.selectedColor)

    // --- COMPREHENSIVE DESIGN SYSTEM ---
    QtObject {
        id: theme
        
        // Mode toggle
        property bool isDark: true
        function toggle() { isDark = !isDark }
        
        // Background Colors
        property color background: isDark ? "#0a0a0a" : "#f8f9fa"
        property color surface: isDark ? "#1a1a1a" : "#ffffff"
        property color surfaceElevated: isDark ? "#242424" : "#ffffff"
        property color surfaceHighlight: isDark ? "#2d2d2d" : "#f0f0f0"
        
        // Text Colors
        property color textPrimary: isDark ? "#ffffff" : "#0a0a0a"
        property color textSecondary: isDark ? "#b0b0b0" : "#3a3a3a"
        property color textTertiary: isDark ? "#707070" : "#6a6a6a"
        property color textDisabled: isDark ? "#4a4a4a" : "#b0b0b0"
        
        // Border & Divider Colors
        property color border: isDark ? "#2a2a2a" : "#e0e0e0"
        property color borderLight: isDark ? "#1f1f1f" : "#ebebeb"
        property color divider: isDark ? "#333333" : "#d0d0d0"
        
        // Brand Colors
        property color accent: "#0078d4"
        property color accentHover: "#005a9e"
        property color accentLight: isDark ? "#1a8cff" : "#40a0ff"
        
        // Semantic Colors
        property color success: "#00d563"
        property color successBg: isDark ? "#0d2818" : "#e6f7ed"
        property color warning: "#ffa500"
        property color warningBg: isDark ? "#2b2010" : "#fff7e6"
        property color danger: "#ff4444"
        property color dangerBg: isDark ? "#2b1414" : "#ffe6e6"
        property color info: "#3b9eff"
        property color infoBg: isDark ? "#0d1f30" : "#e6f3ff"
        
        // Typography Scale
        property int fontSizeHero: 48
        property int fontSizeH1: 32
        property int fontSizeH2: 24
        property int fontSizeH3: 20
        property int fontSizeH4: 18
        property int fontSizeBody: 14
        property int fontSizeSmall: 12
        property int fontSizeTiny: 10
        
        property int fontWeightLight: Font.Light
        property int fontWeightRegular: Font.Normal
        property int fontWeightMedium: Font.Medium
        property int fontWeightBold: Font.Bold
        property int fontWeightBlack: Font.Black
        
        // Spacing Scale (8px base)
        property int space1: 4
        property int space2: 8
        property int space3: 12
        property int space4: 16
        property int space5: 20
        property int space6: 24
        property int space8: 32
        property int space10: 40
        property int space12: 48
        property int space16: 64
        
        // Border Radius Scale
        property int radiusSmall: 6
        property int radiusMedium: 10
        property int radiusLarge: 14
        property int radiusXLarge: 18
        property int radiusFull: 9999
        
        // Shadow Definitions (using pure QML techniques)
        property color shadowSmall: isDark ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(0, 0, 0, 0.08)
        property color shadowMedium: isDark ? Qt.rgba(0, 0, 0, 0.4) : Qt.rgba(0, 0, 0, 0.12)
        property color shadowLarge: isDark ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(0, 0, 0, 0.16)
        
        // Transition Durations
        property int transitionFast: 150
        property int transitionNormal: 250
        property int transitionSlow: 350
    }
    
    // --- Backend (Global) ---
    // Note: FanController auto-initializes in constructor, no need for Component.onCompleted
    FanController { id: backend }
    SystemStatsMonitor { id: monitor }
    AuraController { id: aura }

    // --- Layout ---
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // 1. Sidebar Navigation
        Sidebar {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: 260
            currentIndex: 0
            theme: theme
        }
        
        // 2. Content Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: theme.background
            clip: true
            
            StackLayout {
                id: contentStack
                anchors.fill: parent
                currentIndex: sidebar.currentIndex
                
                // Index 0: Dashboard
                DashboardPage {
                    id: dashboardPage
                    backend: backend
                    monitor: monitor
                    theme: theme
                }
                
                // Index 1: Fan Control
                FanPage {
                    id: fanPage
                    backend: backend
                    theme: theme
                }
                
                // Index 2: Aura Sync
                AuraPage {
                    id: auraPage
                    aura: aura
                    theme: theme
                }
                
                // Index 3: Battery Health
                BatteryPage {
                    id: batteryPage
                    monitor: monitor
                    theme: theme
                }
            }
        }
    }
}