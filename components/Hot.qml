import QtQuick

// Clickable hotspot on the canvas: hovering outlines the element, clicking
// selects the palette key that paints it. Declare it as the FIRST child of
// the element so nested hotspots stay on top of it.
Item {
  id: hot

  property string key: ""
  property var studio: null
  property real outset: 3

  anchors.fill: parent

  readonly property bool selected: studio !== null && studio.selectedKey === key

  Rectangle {
    anchors.fill: parent
    anchors.margins: -hot.outset
    color: "transparent"
    radius: 4
    visible: (mouse.containsMouse || hot.selected) && !(hot.studio && hot.studio.capturing)
    border.width: 2
    border.color: hot.selected ? "#ffffff" : Qt.rgba(1, 1, 1, 0.55)
    Rectangle {
      anchors.fill: parent
      anchors.margins: 2
      color: "transparent"
      radius: 3
      border.width: 1
      border.color: "#000000"
      opacity: 0.6
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (hot.studio) hot.studio.selectKey(hot.key)
    onContainsMouseChanged: if (hot.studio) hot.studio.hoverKey = containsMouse ? hot.key : (hot.studio.hoverKey === hot.key ? "" : hot.studio.hoverKey)
  }
}
