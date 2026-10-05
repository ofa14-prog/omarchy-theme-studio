import QtQuick
import qs.Commons // qmllint disable import

// Window on the canvas: a 2px Hyprland-style border (solid or gradient)
// around a content area filled with a palette colour.
Rectangle {
  id: frame

  property var cv: null
  property bool focused: false
  property string fill: "background"
  default property alias content: inner.data
  readonly property var spec: cv ? (focused ? cv.activeBorder : cv.inactiveBorder) : ({ colors: ["#888888"], angle: 0 })

  radius: Style.cornerRadius > 0 ? 8 : 0
  gradient: Gradient {
    orientation: frame.spec.angle > 45 && frame.spec.angle < 135 ? Gradient.Vertical : Gradient.Horizontal
    GradientStop { position: 0; color: frame.spec.colors[0] }
    GradientStop { position: 1; color: frame.spec.colors[frame.spec.colors.length - 1] }
  }

  Hot {
    key: frame.focused ? "border:active:0" : "border:inactive:0"
    studio: frame.cv ? frame.cv.studio : null
    outset: 2
  }

  Rectangle {
    id: inner
    anchors.fill: parent
    anchors.margins: 2
    radius: Math.max(0, frame.radius - 2)
    color: frame.cv ? frame.cv.c(frame.fill) : "#000000"
    clip: true
  }
}
