/*
 * SPDX-FileCopyrightText: 2020 Han Young <hanyoung@protonmail.com>
 * SPDX-FileCopyrightText: 2020-2021 Devin Lin <espidev@gmail.com>
 * SPDX-FileCopyrightText: 2021 Nicolas Fella <nicolas.fella@gmx.de>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick 2.15
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.2
import QtCharts 2.3
import org.kde.kirigami 2.13 as Kirigami
import "backgrounds"
import "backgrounds/components"
import kweather 1.0

Kirigami.ScrollablePage {
    id: page
    
    property int currentIndex: 0
    property var weatherLocation: weatherLocationListModel.locations[loader.item.currentIndex]
    property var selectedDay: dailyListView.currentItem ? dailyListView.currentItem.weather : weatherLocation.dayForecasts[0]
    
    property int maximumContentWidth: Kirigami.Units.gridUnit * 35
    
    verticalScrollBarPolicy: ScrollBar.AlwaysOff
    
    // x-drag threshold to change page
    property real pageChangeThreshold: page.width / 4
    
    // page functions
    property bool canGoLeft: currentIndex > 0
    property bool canGoRight: currentIndex < weatherLocationListModel.count - 1
    function moveLeft() {
        if (page.canGoLeft) {
            xOutAnim.goLeft = true;
            xOutAnim.to = pageChangeThreshold;
            xOutAnim.restart();
        }
    }
    function moveRight() {
        if (page.canGoRight) {
            xOutAnim.goLeft = false;
            xOutAnim.to = -pageChangeThreshold;
            xOutAnim.restart();
        }
    }
    function finishMoveLeft() {
        if (page.canGoLeft) {
            --currentIndex;
            // animate as if new cards are coming in from the screen side
            rootMask.x = -pageChangeThreshold;
            xAnim.restart();
        }
    }
    function finishMoveRight() {
        if (page.canGoRight) {
            ++currentIndex;
            // animate as if new cards are coming in from the screen side
            rootMask.x = pageChangeThreshold;
            xAnim.restart();
        }
    }
    
    // animate x fade out before page switch
    NumberAnimation {
        id: xOutAnim
        target: rootMask
        property: "x"
        easing.type: Easing.InOutQuad
        duration: Kirigami.Units.longDuration
        property bool goLeft: false
        onFinished: {
            if (goLeft) finishMoveLeft();
            else finishMoveRight();
        }
    }
    
    // background
    background: Rectangle {
        anchors.fill: parent
        color: "#24a3de"
        
        // background colours
        gradient: Gradient {
            GradientStop { 
                color: backgroundLoader.item.gradientColorTop
                position: 0.0
                Behavior on color {
                    ColorAnimation { duration: Kirigami.Units.longDuration }
                }
            }
            GradientStop { 
                color: backgroundLoader.item.gradientColorBottom
                position: 1.0 
                Behavior on color {
                    ColorAnimation { duration: Kirigami.Units.longDuration }
                }
            }
        }
        
        // background components (ex. cloud, sun, etc.)
        Item {
            anchors.fill: parent
            opacity: { // opacity lightens when you scroll down the page
                let scrollAmount = page.flickable.contentY - (Kirigami.Units.gridUnit * 3);
                if (scrollAmount < 0) {
                    scrollAmount = 0;
                }
                
                return 1 - 0.5 * (scrollAmount / (Kirigami.Units.gridUnit * 5));
            }
            
            // weather elements
            Loader {
                anchors.fill: parent
                opacity: backgroundLoader.item && backgroundLoader.item.sun ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                active: opacity !== 0
                sourceComponent: Sun {}
            }
            Loader {
                anchors.fill: parent
                opacity: backgroundLoader.item && backgroundLoader.item.stars ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                active: opacity !== 0
                sourceComponent: Stars {}
            }
            Loader {
                anchors.fill: parent
                opacity: backgroundLoader.item && backgroundLoader.item.clouds ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                active: opacity !== 0
                sourceComponent: Cloudy { cloudColor: backgroundLoader.item.cloudsColor }
            }
            Loader {
                anchors.fill: parent
                opacity: backgroundLoader.item && backgroundLoader.item.rain ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                active: opacity !== 0
                sourceComponent: Rain {}
            }
            Loader {
                anchors.fill: parent
                opacity: backgroundLoader.item && backgroundLoader.item.snow ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                active: opacity !== 0
                sourceComponent: Snow {}
            }
            
            Loader {
                id: backgroundLoader
                anchors.fill: parent
                Component.onCompleted: source = weatherLocation.backgroundComponent
                
                NumberAnimation {
                    id: backgroundLoaderOpacity
                    target: backgroundLoader.item
                    property: "opacity"
                    duration: Kirigami.Units.longDuration
                    to: 1
                    running: true
                    onFinished: {
                        backgroundLoader.source = weatherLocation.backgroundComponent;
                        to = 1;
                        restart();
                    }
                }
            }
        }
        
        // fade away background when locations changed
        Connections {
            target: page
            function onCurrentIndexChanged() {
                backgroundLoaderOpacity.to = 0;
                backgroundLoaderOpacity.restart();
            }
        }
    }
    
    Connections {
        target: weatherLocation
        function onStopLoadingIndicator() {
            showPassiveNotification(i18n("Weather refreshed for %1", weatherLocation.name));
        }
    }
    
    Rectangle {
        id: rootMask
        color: "transparent"
        opacity: 1 - (Math.abs(x) / (page.width / 4))
        implicitHeight: mainLayout.implicitHeight
        
        // left/right dragging for switching pages
        DragHandler {
            id: dragHandler
            target: rootMask
            yAxis.enabled: false; xAxis.enabled: true
            xAxis.minimum: page.canGoRight ? -page.width : -pageChangeThreshold / 2 // extra feedback
            xAxis.maximum: page.canGoLeft ? page.width : pageChangeThreshold / 2 // extra feedback
            
            // HACK: when a delegate, or the listview is being interacted with, disable the DragHandler so that it doesn't switch pages
            enabled: dailyCard.pressedCount == 0
            
            onActiveChanged: {
                if (!active) {
                    // if drag passed threshold, change page
                    if (rootMask.x >= pageChangeThreshold) {
                        page.finishMoveLeft();
                    } else if (rootMask.x <= -pageChangeThreshold) {
                        page.finishMoveRight();
                    } else {
                        xAnim.restart(); // reset position
                    }
                }
            }
        }
        // reset to position
        NumberAnimation on x {
            id: xAnim; to: 0
            easing.type: Easing.InOutQuad
            duration: Kirigami.Units.longDuration
        }
        
        // header
        RowLayout {
            id: header
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Kirigami.Units.smallSpacing 
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                Label {
                    Layout.fillWidth: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
                    font.weight: Font.Bold
                    text: weatherLocation.name
                    color: "white"
                    wrapMode: Text.Wrap
                }
                Label {
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                    color: "white"
                    opacity: 0.9
                    Layout.alignment: Qt.AlignLeft
                    horizontalAlignment: Text.AlignLeft
                    text: i18n("Updated at %1", weatherLocation.lastUpdated)
                }
            }
            
            property real buttonLength: Kirigami.Units.gridUnit * 2.5
            property real iconLength: Kirigami.Units.gridUnit * 1.2
            
            ToolButton {
                Layout.alignment: Qt.AlignTop
                Layout.minimumWidth: header.buttonLength
                Layout.minimumHeight: header.buttonLength
                
                Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
                Kirigami.Theme.inherit: false
                
                icon.name: "globe"
                icon.height: header.iconLength
                icon.width: header.iconLength
                icon.color: "white"
                
                visible: Kirigami.Settings.isMobile
                text: i18n("Locations")
                display: appwindow.width > Kirigami.Units.gridUnit * 30 ? AbstractButton.TextBesideIcon : ToolButton.IconOnly
                onClicked: addPageLayer(getPage("Locations"), 0)
            }
            ToolButton {
                Layout.alignment: Qt.AlignTop
                Layout.minimumWidth: header.buttonLength
                Layout.minimumHeight: header.buttonLength
                
                Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
                Kirigami.Theme.inherit: false
                
                icon.name: "settings-configure"
                icon.height: header.iconLength
                icon.width: header.iconLength
                icon.color: "white"
                
                visible: Kirigami.Settings.isMobile
                text: i18n("Settings")
                display: appwindow.width > Kirigami.Units.gridUnit * 30 ? AbstractButton.TextBesideIcon : ToolButton.IconOnly
                onClicked: addPageLayer(getPage("Settings"), 0)
            }
            ToolButton {
                Layout.alignment: Qt.AlignTop
                Layout.minimumWidth: header.buttonLength
                Layout.minimumHeight: header.buttonLength
                
                Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
                Kirigami.Theme.inherit: false
                
                icon.name: "view-refresh"
                icon.height: header.iconLength
                icon.width: header.iconLength
                icon.color: "white"
                
                visible: !Kirigami.Settings.isMobile
                text: i18n("Refresh")
                display: ToolButton.IconOnly
                onClicked: weatherLocationListModel.locations[loader.item.currentIndex].update()
            }
            ToolButton {
                Layout.alignment: Qt.AlignTop
                Layout.minimumWidth: header.buttonLength
                Layout.minimumHeight: header.buttonLength
                
                Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
                Kirigami.Theme.inherit: false
                
                icon.name: "arrow-left"
                icon.height: header.iconLength
                icon.width: header.iconLength
                icon.color: "white"
                
                visible: !Kirigami.Settings.isMobile && weatherLocationListModel.count > 1
                text: i18n("Left")
                display: ToolButton.IconOnly
                onClicked: page.moveLeft()
                enabled: page.canGoLeft
            }
            ToolButton {
                Layout.alignment: Qt.AlignTop
                Layout.minimumWidth: header.buttonLength
                Layout.minimumHeight: header.buttonLength
                
                Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
                Kirigami.Theme.inherit: false
                
                icon.name: "arrow-right"
                icon.height: header.iconLength
                icon.width: header.iconLength
                icon.color: "white"
                
                visible: !Kirigami.Settings.isMobile && weatherLocationListModel.count > 1
                text: i18n("Right")
                display: ToolButton.IconOnly
                onClicked: page.moveRight()
                enabled: page.canGoRight
            }
        }
        
        // content
        ColumnLayout {
            id: mainLayout
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(page.width - Kirigami.Units.largeSpacing * 4, maximumContentWidth)
            
            // separator from top
            // used instead of topMargin, since it can be shrunk when needed (small window height)
            Item {
                Layout.preferredHeight: Math.max(header.height + Kirigami.Units.gridUnit * 2, // header height
                                                 page.height - headerText.height - dailyHeader.height - dailyCard.height - Kirigami.Units.gridUnit * 3) // pin to bottom of window
            }
            
            // weather header
            ColumnLayout {
                id: headerText
                Layout.fillWidth: true
                Label {
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 4
                    font.weight: Font.Light
                    color: "white"
                    Layout.alignment: Qt.AlignLeft
                    horizontalAlignment: Text.AlignLeft
                    text: Formatter.formatTemperatureRounded(weatherLocation.hourForecasts[0].temperature, settingsModel.temperatureUnits)
                    font.family: lightHeadingFont.name
                }
                Label {
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
                    font.weight: Font.DemiBold
                    color: "white"
                    Layout.alignment: Qt.AlignLeft
                    horizontalAlignment: Text.AlignLeft
                    text: weatherLocation.hourForecasts[0].weatherDescription
                    font.family: lightHeadingFont.name
                }
            }

            // daily view header
            ColumnLayout {
                id: dailyHeader
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing * 2
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                
                Label {
                    text: i18n("Daily")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                    color: "white"
                }
                Label {
                    text: i18n("Local Date: ") + weatherLocation.currentDate
                    font: Kirigami.Theme.smallFont
                    color: "white"
                    opacity: 0.7
                }
            }
            
            // daily view
            Control {
                id: dailyCard
                Layout.fillWidth: true
                padding: Kirigami.Units.largeSpacing
                
                property int pressedCount: 0
                
                background: Kirigami.ShadowedRectangle {
                    color: weatherLocation.cardBackgroundColor
                    radius: Kirigami.Units.smallSpacing
                    anchors.fill: parent

                    shadow.size: Kirigami.Units.largeSpacing
                    shadow.color: Qt.rgba(0.0, 0.0, 0.0, 0.15)
                    shadow.yOffset: Kirigami.Units.devicePixelRatio * 2
                }

                contentItem: WeatherStrip {
                    id: dailyListView
                    selectable: true

                    highlightMoveDuration: 250
                    highlightMoveVelocity: -1
                    highlight: Rectangle {
                        color: Kirigami.Theme.focusColor
                        border {
                            color: Kirigami.Theme.focusColor
                            width: 1
                        }
                        radius: 4
                        opacity: 0.3
                        focus: true
                    }

                    spacing: Kirigami.Units.largeSpacing

                    onDraggingChanged: dailyCard.pressedCount += dragging? 1 : -1;
                    
                    model: weatherLocation.dayForecasts
                    delegate: WeatherDayDelegate {
                        id: delegate
                        weather: modelData
                        textColor: weatherLocation.cardTextColor
                        
                        Connections {
                            target: delegate.mouseArea
                            function onPressedChanged() {
                                dailyCard.pressedCount += delegate.mouseArea.pressed ? 1 : -1;
                            }
                        }
                    }

                    onCurrentIndexChanged: {
                        weatherLocation.selectedDay = currentIndex
                    }
                }
            }
            
            // temperature chart
            TemperatureChartCard {
                location: weatherLocation
            }

            // hourly view header
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing * 2
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                
                Label {
                    text: i18n("Hourly")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                    color: "white"
                }
                Label {
                    text: i18n("Local Time: ") + weatherLocation.currentTime
                    font: Kirigami.Theme.smallFont
                    color: "white"
                    opacity: 0.7
                }
            }

            // hourly view
            Kirigami.Card {
                id: hourlyCard
                Layout.fillWidth: true
                
                background: Kirigami.ShadowedRectangle {
                    color: weatherLocation.cardBackgroundColor
                    radius: Kirigami.Units.smallSpacing
                    anchors.fill: parent

                    shadow.size: Kirigami.Units.largeSpacing
                    shadow.color: Qt.rgba(0.0, 0.0, 0.0, 0.15)
                    shadow.yOffset: Kirigami.Units.devicePixelRatio * 2
                }

                contentItem: WeatherStrip {
                    id: hourlyListView
                    selectable: false
                    model: weatherLocation.hourForecasts

                    delegate: WeatherHourDelegate {
                        weather: modelData
                        textColor: weatherLocation.cardTextColor
                    }
                }
            }
            
            // bottom card (extra info for selected day)
            InfoCard {
                Layout.fillWidth: true

                textColor: weatherLocation.cardTextColor

                background: Kirigami.ShadowedRectangle {
                    color: weatherLocation.cardBackgroundColor
                    radius: Kirigami.Units.smallSpacing
                    anchors.fill: parent

                    shadow.size: Kirigami.Units.largeSpacing
                    shadow.color: Qt.rgba(0.0, 0.0, 0.0, 0.15)
                    shadow.yOffset: Kirigami.Units.devicePixelRatio * 2
                }
            }

            SunriseCard {
                Layout.fillWidth: true

                textColor: weatherLocation.cardTextColor

                background: Kirigami.ShadowedRectangle {
                    color: weatherLocation.cardBackgroundColor
                    radius: Kirigami.Units.smallSpacing
                    anchors.fill: parent

                    shadow.size: Kirigami.Units.largeSpacing
                    shadow.color: Qt.rgba(0.0, 0.0, 0.0, 0.15)
                    shadow.yOffset: Kirigami.Units.devicePixelRatio * 2
                }
            }
        }
    }
}

