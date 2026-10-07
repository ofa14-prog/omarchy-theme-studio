import QtQuick
import qs.Commons // qmllint disable import

// In-app file browser (no portal/zenity needed). Lists through the helper.
// mode: "images" shows pictures, "themes" shows archives/.toml, "" shows all.
Rectangle {
  id: browser

  property var studio: null
  property string mode: ""
  property string title: browser.tr("Choose file")
  property bool allowFolder: false
  property string path: ""
  property var entries: []
  property string error: ""
  signal chosen(string path)
  signal cancelled()

  function tr(text) {
    var args = Array.prototype.slice.call(arguments, 1)
    return studio ? studio.tr.apply(studio, [text].concat(args)) : text
  }

  readonly property color fg: Color.foreground

  color: Color.background
  radius: Math.max(6, Style.cornerRadius)
  border.width: 1
  border.color: Qt.rgba(fg.r, fg.g, fg.b, 0.2)

  function go(p) {
    if (!studio) return
    studio.run(["ls", p || "", mode], function(r) {
      if (!r.ok) { browser.error = r.error; return }
      browser.error = ""
      browser.path = r.path
      browser.entries = r.entries
      pathInput.text = r.path
      list.positionViewAtBeginning()
    })
  }

  MouseArea { anchors.fill: parent }

  Column {
    anchors.fill: parent
    anchors.margins: Style.space(18)
    spacing: Style.space(10)

    Row {
      width: parent.width
      spacing: Style.space(8)
      Text {
        textFormat: Text.PlainText
        text: browser.title
        color: browser.fg
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Row {
      width: parent.width
      spacing: Style.space(6)
      Btn { icon: "󰁝"; tip: browser.tr("Parent folder"); onClicked: browser.go(browser.path + "/..") }
      Btn { icon: "󰋜"; tip: browser.tr("Home"); onClicked: browser.go("~") }
      Btn { icon: "󰉍"; tip: browser.tr("Downloads"); onClicked: browser.go("~/Downloads") }
      Btn { icon: "󰉏"; tip: browser.tr("Pictures"); onClicked: browser.go("~/Pictures") }
      Rectangle {
        width: parent.width - x
        height: Math.round(Style.font.body * 2.4)
        radius: 6
        color: Qt.rgba(browser.fg.r, browser.fg.g, browser.fg.b, 0.06)
        border.width: 1
        border.color: pathInput.activeFocus ? Color.accent : Qt.rgba(browser.fg.r, browser.fg.g, browser.fg.b, 0.15)
        TextInput {
          id: pathInput
          anchors.fill: parent
          anchors.leftMargin: 10; anchors.rightMargin: 10
          verticalAlignment: TextInput.AlignVCenter
          color: browser.fg
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          selectByMouse: true
          clip: true
          onAccepted: browser.go(text)
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      visible: browser.error !== ""
      text: browser.error
      color: "#e06c75"
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    Rectangle {
      width: parent.width
      height: parent.height - y - footer.height - Style.space(10)
      radius: 6
      color: Qt.rgba(browser.fg.r, browser.fg.g, browser.fg.b, 0.03)
      clip: true

      ListView {
        id: list
        anchors.fill: parent
        anchors.margins: 4
        model: browser.entries
        boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
          width: list.width
          height: Math.round(Style.font.body * 2.3)
          radius: 4
          color: rowMouse.containsMouse ? Qt.rgba(browser.fg.r, browser.fg.g, browser.fg.b, 0.1) : "transparent"
          Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 10
            spacing: 10
            Text {
              textFormat: Text.PlainText
              text: modelData.dir ? "󰉋" : (modelData.image ? "󰋩" : "󰈔")
              color: modelData.dir ? Color.accent : browser.fg
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
            Text {
              textFormat: Text.PlainText
              text: modelData.name
              color: browser.fg
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
          }
          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: modelData.dir ? browser.go(modelData.path) : browser.chosen(modelData.path)
          }
        }
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: browser.entries.length === 0 && browser.error === ""
          text: browser.tr("No matching files in this folder")
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }
    }

    Row {
      id: footer
      anchors.right: parent.right
      spacing: Style.space(8)
      Btn { text: browser.tr("Cancel"); onClicked: browser.cancelled() }
      Btn {
        visible: browser.allowFolder
        text: browser.tr("Choose this folder")
        kind: "primary"
        onClicked: browser.chosen(browser.path)
      }
    }
  }
}
