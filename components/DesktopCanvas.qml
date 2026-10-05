import QtQuick
import qs.Commons // qmllint disable import
import "../Palette.js" as P

// A mock Omarchy desktop painted only from the palette being edited.
// Designed in a fixed 1280x800 space; the parent scales it to fit.
// Every element is a hotspot that selects the colour key painting it.
Item {
  id: canvas

  property var pal: ({})
  property var studio: null
  property string wallpaper: ""
  property string mono: Style.font.family

  width: 1280
  height: 800
  clip: true

  function tr(text) {
    var args = Array.prototype.slice.call(arguments, 1)
    return studio ? studio.tr.apply(studio, [text].concat(args)) : text
  }

  function c(key) {
    var v = pal[key]
    return P.isHex(v) ? v : "#ff00ff"
  }
  function esc(t) { return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/ /g, "&nbsp;") }
  function s(key, text, bold, italic) {
    var t = "<font color=\"" + c(key) + "\">" + esc(text) + "</font>"
    if (bold) t = "<b>" + t + "</b>"
    if (italic) t = "<i>" + t + "</i>"
    return t
  }
  readonly property var activeBorder: P.borderColors(pal, "hyprland_active_border")
  readonly property var inactiveBorder: P.borderColors(pal, "hyprland_inactive_border")

  // ---------------------------------------------------------------- wallpaper
  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0; color: canvas.c("darker_background") }
      GradientStop { position: 1; color: canvas.c("lighter_background") }
    }
  }
  Image {
    anchors.fill: parent
    source: canvas.wallpaper ? "file://" + canvas.wallpaper : ""
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    sourceSize.width: 1280
    smooth: true
  }

  // ---------------------------------------------------------------- bar
  Rectangle {
    id: bar
    x: 0; y: 0; width: parent.width; height: 30
    color: canvas.c("background")
    Hot { key: "background"; studio: canvas.studio; outset: -1 }

    Row {
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      spacing: 14
      Text { text: "󰣇"; color: canvas.c("foreground"); font.family: canvas.mono; font.pixelSize: 16 }
      Repeater {
        model: 5
        Item {
          width: 14; height: 20
          Text {
            anchors.centerIn: parent
            text: String(index + 1)
            color: index === 1 ? canvas.c("accent") : canvas.c("foreground")
            opacity: index > 2 ? 0.45 : 1
            font.family: canvas.mono; font.pixelSize: 13
            font.bold: index === 1
          }
          Hot { key: index === 1 ? "accent" : "foreground"; studio: canvas.studio }
        }
      }
    }
    Item {
      anchors.centerIn: parent
      width: clock.implicitWidth; height: clock.implicitHeight
      Text {
        id: clock
        text: canvas.tr("Monday 14:32")
        color: canvas.c("foreground")
        font.family: canvas.mono; font.pixelSize: 13; font.bold: true
      }
      Hot { key: "foreground"; studio: canvas.studio }
    }
    Row {
      anchors.right: parent.right
      anchors.rightMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      spacing: 14
      Item {
        width: rec.implicitWidth; height: rec.implicitHeight
        Text { id: rec; text: "󰑋"; color: canvas.c("red"); font.family: canvas.mono; font.pixelSize: 14 }
        Hot { key: "red"; studio: canvas.studio }
      }
      Repeater {
        model: ["󰂯", "󰤨", "󰕾", "󰁹", "󰐥"]
        Text { text: modelData; color: canvas.c("foreground"); font.family: canvas.mono; font.pixelSize: 14 }
      }
    }
  }

  // ---------------------------------------------------------------- terminal (focused)
  Frame {
    cv: canvas
    id: term
    x: 36; y: 46; width: 600; height: 404
    focused: true

    Hot { key: "background"; studio: canvas.studio; outset: -2 }

    Column {
      x: 16; y: 14
      spacing: 3
      Repeater {
        model: [
          canvas.s("green", "❯ ", true) + canvas.s("blue", canvas.tr("~/projects/omarchy"), true) + canvas.s("magenta", "  main") + canvas.s("muted", " ⇡2"),
          canvas.s("foreground", "ls -la"),
          canvas.s("dark_foreground", "drwxr-xr-x  ofa  ") + canvas.s("blue", "config/", true),
          canvas.s("dark_foreground", "-rwxr-xr-x  ofa  ") + canvas.s("green", "install.sh", true),
          canvas.s("dark_foreground", "lrwxrwxrwx  ofa  ") + canvas.s("cyan", "themes") + canvas.s("foreground", " -> ../share/themes"),
          canvas.s("dark_foreground", "-rw-r--r--  ofa  ") + canvas.s("foreground", "README.md"),
          canvas.s("green", "❯ ", true) + canvas.s("foreground", "make build"),
          canvas.s("yellow", "warning:", true) + canvas.s("foreground", canvas.tr(" unused variable 'x'")),
          canvas.s("red", "error:", true) + canvas.s("foreground", canvas.tr(" build failed (exit 1)")),
          canvas.s("cyan", "info:", true) + canvas.s("light_foreground", canvas.tr(" watching 3 files")),
          canvas.s("orange", "  ⏱ 1.42s ") + canvas.s("brown", "[cache]") + canvas.s("bright_foreground", canvas.tr("  ready"), true),
          canvas.s("green", "❯ ", true) + canvas.s("foreground", "fastfetch") + canvas.s("accent", "▋")
        ]
        Text {
          text: modelData
          textFormat: Text.StyledText
          color: canvas.c("foreground")
          font.family: canvas.mono
          font.pixelSize: 14
        }
      }
    }

    Grid {
      x: 16; y: 318
      columns: 8
      spacing: 6
      Repeater {
        model: ["red", "green", "yellow", "blue", "magenta", "cyan", "orange", "brown",
                "bright_red", "bright_green", "bright_yellow", "bright_blue", "bright_magenta", "bright_cyan", "light_foreground", "bright_foreground"]
        Rectangle {
          width: 64; height: 28; radius: 3
          color: canvas.c(modelData)
          Hot { key: modelData; studio: canvas.studio; outset: 2 }
        }
      }
    }
  }

  // ---------------------------------------------------------------- launcher
  Frame {
    cv: canvas
    x: 36; y: 470; width: 600; height: 300
    fill: "background"
    Hot { key: "background"; studio: canvas.studio; outset: -2 }

    Rectangle {
      x: 14; y: 14; width: parent.width - 28; height: 40; radius: 6
      color: canvas.c("lighter_background")
      Hot { key: "lighter_background"; studio: canvas.studio }
      Text {
        x: 14; anchors.verticalCenter: parent.verticalCenter
        text: canvas.s("accent", "  ") + canvas.s("muted", canvas.tr("Search apps…"))
        textFormat: Text.StyledText
        font.family: canvas.mono; font.pixelSize: 14
      }
    }
    Column {
      x: 14; y: 66; width: parent.width - 28
      spacing: 4
      Repeater {
        model: [["󰈹", "Firefox", canvas.tr("Web browser")], ["", "Terminal", "Alacritty"], ["󰉋", canvas.tr("Files"), "Nautilus"], ["", "Neovim", canvas.tr("Text editor")], ["󰏘", "Theme Studio", canvas.tr("Design themes")]]
        Rectangle {
          width: parent.width; height: 40; radius: 6
          color: index === 1 ? canvas.c("selection") : "transparent"
          Hot { key: index === 1 ? "selection" : "foreground"; studio: canvas.studio; outset: 0 }
          Row {
            x: 12; anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Text { text: modelData[0]; color: index === 1 ? canvas.c("accent") : canvas.c("foreground"); font.family: canvas.mono; font.pixelSize: 16; width: 22 }
            Text { text: modelData[1]; color: index === 1 ? canvas.c("accent") : canvas.c("foreground"); font.family: canvas.mono; font.pixelSize: 14; font.bold: index === 1 }
            Text { text: modelData[2]; color: canvas.c("dark_foreground"); font.family: canvas.mono; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- editor
  Frame {
    cv: canvas
    x: 656; y: 46; width: 588; height: 500

    Hot { key: "background"; studio: canvas.studio; outset: -2 }

    Rectangle {
      id: tabs
      width: parent.width; height: 32
      color: canvas.c("darker_background")
      Hot { key: "darker_background"; studio: canvas.studio; outset: -1 }
      Row {
        height: parent.height
        Rectangle {
          width: 150; height: parent.height
          color: canvas.c("background")
          Rectangle { width: parent.width; height: 2; color: canvas.c("accent") }
          Text { anchors.centerIn: parent; text: "  theme.js"; color: canvas.c("foreground"); font.family: canvas.mono; font.pixelSize: 13 }
        }
        Rectangle {
          width: 150; height: parent.height
          color: "transparent"
          Text { anchors.centerIn: parent; text: "  colors.toml"; color: canvas.c("dark_foreground"); font.family: canvas.mono; font.pixelSize: 13 }
          Hot { key: "dark_foreground"; studio: canvas.studio; outset: -2 }
        }
      }
    }

    Rectangle {
      id: gutter
      y: tabs.height; width: 44; height: parent.height - tabs.height - status.height
      color: canvas.c("dark_background")
      Hot { key: "dark_background"; studio: canvas.studio; outset: -1 }
    }

    Rectangle {
      // current line
      x: 0; y: tabs.height + 12 + 4 * 22 - 2; width: parent.width; height: 22
      color: canvas.c("lighter_background")
      opacity: 0.9
      Hot { key: "lighter_background"; studio: canvas.studio; outset: -1 }
    }
    Rectangle {
      // selection
      x: 60 + 16 * 8.4; y: tabs.height + 12 + 6 * 22 - 2; width: 25 * 8.4; height: 22
      color: canvas.c("selection")
      Hot { key: "selection"; studio: canvas.studio; outset: 0 }
    }

    Column {
      x: 0; y: tabs.height + 12
      Repeater {
        model: [
          canvas.s("muted", canvas.tr("// Theme Studio config"), false, true),
          canvas.s("magenta", "import") + canvas.s("foreground", " { palette } ") + canvas.s("magenta", "from") + canvas.s("green", " \"./colors\""),
          "",
          canvas.s("magenta", "const ") + canvas.s("cyan", "ACCENT") + canvas.s("foreground", " = ") + canvas.s("green", "\"" + canvas.c("accent") + "\""),
          canvas.s("magenta", "export function ") + canvas.s("blue", "applyTheme") + canvas.s("foreground", "(name, opts) {"),
          canvas.s("magenta", "  if ") + canvas.s("foreground", "(!opts.live) ") + canvas.s("magenta", "return ") + canvas.s("orange", "false"),
          canvas.s("magenta", "  const ") + canvas.s("foreground", "shades = palette.") + canvas.s("blue", "derive") + canvas.s("foreground", "(name, ") + canvas.s("orange", "0.25") + canvas.s("foreground", ")"),
          canvas.s("magenta", "  for ") + canvas.s("foreground", "(") + canvas.s("magenta", "let ") + canvas.s("foreground", "i = ") + canvas.s("orange", "0") + canvas.s("foreground", "; i < ") + canvas.s("orange", "16") + canvas.s("foreground", "; i++) {"),
          canvas.s("foreground", "    shades[i] = ") + canvas.s("blue", "mix") + canvas.s("foreground", "(ACCENT, ") + canvas.s("green", "\"#000\"") + canvas.s("foreground", ", i / ") + canvas.s("orange", "16") + canvas.s("foreground", ")"),
          canvas.s("foreground", "  }"),
          canvas.s("magenta", "  return new ") + canvas.s("yellow", "Theme") + canvas.s("foreground", "(name, shades)"),
          canvas.s("foreground", "}"),
          "",
          canvas.s("muted", "// TODO: ", false, true) + canvas.s("bright_yellow", canvas.tr("check contrast"), false, true),
          canvas.s("red", "throw ") + canvas.s("magenta", "new ") + canvas.s("yellow", "Error") + canvas.s("foreground", "(") + canvas.s("green", "\"" + canvas.tr("no colour") + "\"") + canvas.s("foreground", ")"),
          canvas.s("light_foreground", "  ") + canvas.s("bright_blue", "console") + canvas.s("foreground", ".") + canvas.s("bright_cyan", "log") + canvas.s("foreground", "(") + canvas.s("bright_green", "\"ok\"") + canvas.s("foreground", ", ") + canvas.s("bright_magenta", "true") + canvas.s("foreground", ")")
        ]
        Row {
          height: 22
          Text {
            width: 44; height: 22
            horizontalAlignment: Text.AlignRight
            rightPadding: 8
            verticalAlignment: Text.AlignVCenter
            text: String(index + 1)
            color: index === 4 ? canvas.c("accent") : canvas.c("dark_foreground")
            font.family: canvas.mono; font.pixelSize: 12
          }
          Text {
            leftPadding: 16
            height: 22
            verticalAlignment: Text.AlignVCenter
            text: modelData
            textFormat: Text.StyledText
            font.family: canvas.mono; font.pixelSize: 14
          }
        }
      }
    }

    Rectangle {
      id: status
      anchors.bottom: parent.bottom
      width: parent.width; height: 26
      color: canvas.c("dark_background")
      Hot { key: "dark_background"; studio: canvas.studio; outset: -1 }
      Rectangle {
        width: 82; height: parent.height
        color: canvas.c("accent")
        Text { anchors.centerIn: parent; text: "NORMAL"; color: canvas.c("background"); font.family: canvas.mono; font.pixelSize: 12; font.bold: true }
        Hot { key: "accent"; studio: canvas.studio; outset: -1 }
      }
      Text {
        x: 96; anchors.verticalCenter: parent.verticalCenter
        text: canvas.s("foreground", "theme.js  ") + canvas.s("green", "+3 ") + canvas.s("yellow", "~1 ") + canvas.s("red", "-2")
        textFormat: Text.StyledText
        font.family: canvas.mono; font.pixelSize: 12
      }
      Text {
        anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
        text: "utf-8   5:12   42%"
        color: canvas.c("light_foreground")
        font.family: canvas.mono; font.pixelSize: 12
      }
    }
  }

  // ---------------------------------------------------------------- system monitor
  Frame {
    cv: canvas
    x: 656; y: 566; width: 588; height: 204
    Hot { key: "background"; studio: canvas.studio; outset: -2 }
    Text {
      x: 14; y: 10
      text: canvas.s("accent", "cpu ", true) + canvas.s("dark_foreground", "─────── ") + canvas.s("light_foreground", "3.4 GHz  ") + canvas.s("green", "38°C")
      textFormat: Text.StyledText
      font.family: canvas.mono; font.pixelSize: 13
    }
    Row {
      x: 14; y: 40
      height: 140
      spacing: 3
      Repeater {
        model: [22, 35, 48, 41, 30, 55, 68, 74, 62, 50, 44, 58, 77, 88, 92, 80, 66, 52, 40, 34, 46, 61, 73, 85, 70, 57, 43, 37, 29, 25, 33, 47, 60, 72, 64, 51, 39, 31, 27, 24, 36, 49, 63, 79, 90, 84, 71, 56, 42, 38, 45, 53, 59, 67, 75, 69, 58, 46, 35, 28, 22, 30, 41, 54, 66, 78, 87, 81, 65, 49]
        Rectangle {
          width: 5
          height: modelData * 1.4
          anchors.bottom: parent.bottom
          radius: 1
          color: modelData > 80 ? canvas.c("red") : (modelData > 60 ? canvas.c("yellow") : canvas.c("green"))
        }
      }
    }
  }

  // ---------------------------------------------------------------- notification
  Rectangle {
    x: parent.width - 380; y: 44; width: 360; height: 84
    radius: 8
    color: canvas.c("background")
    border.width: 2
    border.color: canvas.c("accent")
    Hot { key: "background"; studio: canvas.studio; outset: -2 }
    Row {
      x: 16; anchors.verticalCenter: parent.verticalCenter
      spacing: 14
      Rectangle {
        width: 40; height: 40; radius: 20
        color: canvas.c("accent")
        Text { anchors.centerIn: parent; text: "󰏘"; color: canvas.c("background"); font.family: canvas.mono; font.pixelSize: 20 }
        Hot { key: "accent"; studio: canvas.studio }
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Text { text: "Theme Studio"; color: canvas.c("bright_foreground"); font.family: canvas.mono; font.pixelSize: 14; font.bold: true }
        Text { text: canvas.tr("Theme saved and applied"); color: canvas.c("light_foreground"); font.family: canvas.mono; font.pixelSize: 12 }
      }
    }
  }
}
