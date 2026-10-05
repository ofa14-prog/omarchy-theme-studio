import QtQuick
import qs.Commons // qmllint disable import

Item {
  id: section
  property string text: ""
  width: parent ? parent.width : 200
  implicitHeight: label.implicitHeight + Style.space(10)

  Rectangle {
    anchors.top: parent.top
    width: parent.width
    height: 1
    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
  }
  Text {
    id: label
    anchors.bottom: parent.bottom
    text: section.text.toUpperCase()
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1
  }
}
