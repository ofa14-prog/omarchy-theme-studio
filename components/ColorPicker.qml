import QtQuick
import qs.Commons // qmllint disable import
import "../Palette.js" as P

// HSV picker: saturation/value square, hue strip and a hex field.
// `edited(hex, commit)` fires while dragging (commit = false) and once on
// release or on hex entry (commit = true).
Column {
  id: picker

  property string hex: "#888888"
  property real hue: 0
  property real sat: 0
  property real val: 0.5
  property bool dragging: false
  property alias hexFocused: hexInput.activeFocus
  signal edited(string hex, bool commit)

  spacing: Style.space(10)

  function syncFromHex() {
    if (dragging || !P.isHex(hex)) return
    var c = P.toHsv(hex)
    // Keep the hue when the colour is grey so the square does not jump.
    if (c.s > 0.001 && c.v > 0.001) hue = c.h
    sat = c.s
    val = c.v
  }

  onHexChanged: {
    syncFromHex()
    if (!hexInput.activeFocus) hexInput.text = hex
  }
  Component.onCompleted: { syncFromHex(); hexInput.text = hex }

  function emitCurrent(commit) {
    var h = P.fromHsv(hue, sat, val)
    edited(h, commit)
  }

  Rectangle {
    id: square
    width: parent.width
    height: Math.round(width * 0.58)
    radius: 6
    color: P.fromHsv(picker.hue, 1, 1)
    clip: true

    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "#ffffffff" }
        GradientStop { position: 1; color: "#00ffffff" }
      }
    }
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      gradient: Gradient {
        GradientStop { position: 0; color: "#00000000" }
        GradientStop { position: 1; color: "#ff000000" }
      }
    }
    Rectangle {
      width: 16; height: 16; radius: 8
      x: picker.sat * square.width - width / 2
      y: (1 - picker.val) * square.height - height / 2
      color: picker.hex
      border.width: 2
      border.color: picker.val > 0.6 && picker.sat < 0.5 ? "#000000" : "#ffffff"
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.CrossCursor
      function pick(m) {
        picker.sat = P.clamp(m.x / width, 0, 1)
        picker.val = P.clamp(1 - m.y / height, 0, 1)
        picker.emitCurrent(false)
      }
      onPressed: function(m) { picker.dragging = true; pick(m) }
      onPositionChanged: function(m) { if (pressed) pick(m) }
      onReleased: { picker.dragging = false; picker.emitCurrent(true) }
    }
  }

  Rectangle {
    id: hueBar
    width: parent.width
    height: Style.space(14)
    radius: height / 2
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.000; color: "#ff0000" }
      GradientStop { position: 0.167; color: "#ffff00" }
      GradientStop { position: 0.333; color: "#00ff00" }
      GradientStop { position: 0.500; color: "#00ffff" }
      GradientStop { position: 0.667; color: "#0000ff" }
      GradientStop { position: 0.833; color: "#ff00ff" }
      GradientStop { position: 1.000; color: "#ff0000" }
    }
    Rectangle {
      width: hueBar.height + 4; height: width; radius: width / 2
      y: -2
      x: picker.hue * hueBar.width - width / 2
      color: P.fromHsv(picker.hue, 1, 1)
      border.width: 2
      border.color: "#ffffff"
    }
    MouseArea {
      anchors.fill: parent
      anchors.margins: -4
      cursorShape: Qt.PointingHandCursor
      function pick(m) {
        picker.hue = P.clamp((m.x - 4) / hueBar.width, 0, 0.9999)
        picker.emitCurrent(false)
      }
      onPressed: function(m) { picker.dragging = true; pick(m) }
      onPositionChanged: function(m) { if (pressed) pick(m) }
      onReleased: { picker.dragging = false; picker.emitCurrent(true) }
    }
  }

  Row {
    width: parent.width
    spacing: Style.space(8)

    Rectangle {
      width: Style.space(38); height: hexBox.height
      radius: 6
      color: picker.hex
      border.width: 1
      border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.25)
    }

    Rectangle {
      id: hexBox
      width: parent.width - Style.space(46)
      height: Math.round(Style.font.body * 2.4)
      radius: 6
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
      border.width: 1
      border.color: hexInput.activeFocus ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)

      TextInput {
        id: hexInput
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        verticalAlignment: TextInput.AlignVCenter
        color: Color.foreground
        selectionColor: Color.accent
        selectedTextColor: Color.background
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        selectByMouse: true
        maximumLength: 9
        function commit() {
          var h = P.normHex(text)
          if (h) picker.edited(h, true)
          else text = picker.hex
        }
        onAccepted: { commit(); focus = false }
        onActiveFocusChanged: if (!activeFocus) commit()
        Keys.onEscapePressed: function(e) { text = picker.hex; focus = false; e.accepted = true }
      }
    }
  }
}
