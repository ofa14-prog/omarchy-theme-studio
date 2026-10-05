import QtQuick
import qs.Commons // qmllint disable import

// Small text/icon button used across Theme Studio.
Rectangle {
  id: btn

  property string text: ""
  property string icon: ""
  property string kind: "ghost" // ghost | primary | danger | subtle
  property bool active: false
  property bool enabledState: true
  property string tip: ""
  property int fontSize: Style.font.body
  signal clicked()

  readonly property color fg: Color.foreground
  readonly property color accent: Color.accent

  implicitHeight: Math.round(fontSize * 2.4)
  implicitWidth: row.implicitWidth + Math.round(fontSize * 1.4)
  radius: Math.max(4, Style.cornerRadius)
  opacity: enabledState ? 1 : 0.4
  color: {
    if (kind === "primary") return mouse.pressed ? Qt.darker(accent, 1.25) : (mouse.containsMouse ? Qt.lighter(accent, 1.1) : accent)
    if (kind === "danger") return mouse.containsMouse ? Qt.rgba(0.85, 0.25, 0.3, 0.35) : Qt.rgba(0.85, 0.25, 0.3, 0.18)
    if (active) return Qt.rgba(accent.r, accent.g, accent.b, 0.28)
    if (mouse.pressed) return Qt.rgba(fg.r, fg.g, fg.b, 0.2)
    if (mouse.containsMouse) return Qt.rgba(fg.r, fg.g, fg.b, 0.12)
    return kind === "subtle" ? "transparent" : Qt.rgba(fg.r, fg.g, fg.b, 0.06)
  }
  border.width: kind === "ghost" || active ? 1 : 0
  border.color: active ? accent : Qt.rgba(fg.r, fg.g, fg.b, 0.14)

  Row {
    id: row
    anchors.centerIn: parent
    spacing: btn.icon && btn.text ? Math.round(btn.fontSize * 0.5) : 0
    Text {
      visible: btn.icon !== ""
      text: btn.icon
      color: btn.kind === "primary" ? Color.background : (btn.active ? btn.accent : btn.fg)
      font.family: Style.font.family
      font.pixelSize: Math.round(btn.fontSize * 1.15)
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      visible: btn.text !== ""
      text: btn.text
      color: btn.kind === "primary" ? Color.background : btn.fg
      font.family: Style.font.family
      font.pixelSize: btn.fontSize
      font.bold: btn.kind === "primary"
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: btn.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (btn.enabledState) btn.clicked()
  }

  Rectangle {
    visible: btn.tip !== "" && mouse.containsMouse
    z: 100
    color: Color.background
    border.color: Qt.rgba(btn.fg.r, btn.fg.g, btn.fg.b, 0.25)
    radius: 4
    width: tipText.implicitWidth + 12
    height: tipText.implicitHeight + 8
    anchors.top: parent.bottom
    anchors.topMargin: 4
    anchors.horizontalCenter: parent.horizontalCenter
    Text {
      id: tipText
      anchors.centerIn: parent
      text: btn.tip
      color: btn.fg
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }
}
