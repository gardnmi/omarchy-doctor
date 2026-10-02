import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "nixfred.doctor"
  ipcTarget: "nixfred.doctor"

  property var results: []
  property bool scanning: false
  property string lastRun: "Never"
  property int badCount: 0
  property int warnCount: 0
  property int okCount: 0
  property int selectedIndex: 0

  readonly property string overallStatus: badCount > 0 ? "bad" : (warnCount > 0 ? "warn" : (results.length > 0 ? "ok" : "info"))
  readonly property string overallLabel: overallStatus === "bad" ? "Problem found" : overallStatus === "warn" ? "Needs attention" : overallStatus === "ok" ? "All systems healthy" : "Not scanned"
  readonly property string icon: overallStatus === "bad" ? "󰒡" : overallStatus === "warn" ? "󰀪" : overallStatus === "ok" ? "󰓙" : "󰚰"
  readonly property color foreground: Color.popups.text
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  readonly property color good: Color.accent
  readonly property color warning: "#e5a50a"
  readonly property color danger: Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function scriptPath() {
    var url = Qt.resolvedUrl("doctor-checks.sh").toString()
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.slice(7)) : url
  }

  function statusColor(status) {
    if (status === "bad") return danger
    if (status === "warn") return warning
    if (status === "ok") return good
    return dim
  }

  function statusGlyph(status) {
    if (status === "bad") return "●"
    if (status === "warn") return "●"
    if (status === "ok") return "●"
    return "○"
  }

  function parseResults(raw) {
    var rows = String(raw || "").split("\n")
    var next = []
    var bad = 0
    var warn = 0
    var ok = 0
    for (var i = 0; i < rows.length; i++) {
      var line = rows[i]
      if (!line.trim()) continue
      var parts = line.split("\t")
      if (parts.length < 3) continue
      var status = parts[0]
      var item = {
        status: status,
        title: parts[1],
        summary: parts[2],
        command: parts.length >= 4 ? parts.slice(3).join("\t") : ""
      }
      next.push(item)
      if (status === "bad") bad++
      else if (status === "warn") warn++
      else if (status === "ok") ok++
    }
    results = next
    badCount = bad
    warnCount = warn
    okCount = ok
    if (selectedIndex >= next.length) selectedIndex = Math.max(0, next.length - 1)
    lastRun = Qt.formatDateTime(new Date(), "hh:mm AP")
  }

  function refresh() {
    if (collector.running) return
    scanning = true
    collector.command = ["bash", scriptPath()]
    collector.running = true
  }

  function copyCommand(command) {
    if (!command) return
    Quickshell.execDetached(["bash", "-c", "printf %s \"$1\" | wl-copy", "doctor-copy", command])
  }

  function openTerminal(command) {
    if (!command) return
    Quickshell.execDetached(["bash", "-lc", "omarchy-launch-terminal -- bash -lc " + shellQuote(command + "; printf '\\n\\nPress Enter to close...'; read")])
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  onOpenedChanged: {
    if (opened && results.length === 0) refresh()
  }

  Process {
    id: collector
    stdout: StdioCollector { id: collectorOut; waitForEnd: true }
    stderr: StdioCollector { id: collectorErr; waitForEnd: true }
    onExited: function(exitCode) {
      root.scanning = false
      root.parseResults(collectorOut.text)
      if (root.results.length === 0 && exitCode !== 0) {
        root.results = [{
          status: "bad",
          title: "Doctor collector",
          summary: String(collectorErr.text || "The diagnostic collector failed to run.").trim(),
          command: "bash " + root.scriptPath()
        }]
        root.badCount = 1
        root.warnCount = 0
        root.okCount = 0
      }
    }
  }

  Timer {
    interval: 300000
    repeat: true
    running: root.opened
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.scanning ? "󰑐" : root.icon
    active: root.badCount > 0 || root.warnCount > 0
    tooltipText: "Doctor: " + root.overallLabel
    onPressed: function(code) {
      if (code === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(470))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dy === 0 || root.results.length === 0) return
        root.selectedIndex = Math.max(0, Math.min(root.results.length - 1, root.selectedIndex + dy))
        var target = root.selectedIndex * Style.space(76)
        listFlick.contentY = Math.max(0, Math.min(target, Math.max(0, listFlick.contentHeight - listFlick.height)))
      }
      onActivateRequested: {
        var item = root.results[root.selectedIndex]
        if (item && item.command) root.copyCommand(item.command)
      }
      onCloseRequested: root.close()
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        if (t === "c" || t === "C") {
          var item = root.results[root.selectedIndex]
          if (item && item.command) root.copyCommand(item.command)
        }
      }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Omarchy Doctor"
          meta: root.scanning ? "Running diagnostics…" : root.overallLabel + " · checked " + root.lastRun
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: root.icon
              color: root.statusColor(root.overallStatus)
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Rectangle {
            width: (parent.width - parent.spacing * 2) / 3
            height: Style.space(52)
            radius: Style.cornerRadius
            color: Qt.rgba(root.good.r, root.good.g, root.good.b, 0.10)
            Text { anchors.centerIn: parent; text: root.okCount + " healthy"; color: root.good; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
          }
          Rectangle {
            width: (parent.width - parent.spacing * 2) / 3
            height: Style.space(52)
            radius: Style.cornerRadius
            color: Qt.rgba(root.warning.r, root.warning.g, root.warning.b, 0.10)
            Text { anchors.centerIn: parent; text: root.warnCount + " warnings"; color: root.warning; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
          }
          Rectangle {
            width: (parent.width - parent.spacing * 2) / 3
            height: Style.space(52)
            radius: Style.cornerRadius
            color: Qt.rgba(root.danger.r, root.danger.g, root.danger.b, 0.10)
            Text { anchors.centerIn: parent; text: root.badCount + " problems"; color: root.danger; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            text: root.scanning ? "Scanning…" : "Run Doctor"
            enabled: !root.scanning
            onClicked: root.refresh()
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Middle click the bar icon to rescan · R refreshes · C copies command"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        Flickable {
          id: listFlick
          width: parent.width
          height: Math.min(resultsColumn.implicitHeight, Style.space(470))
          contentWidth: width
          contentHeight: resultsColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: resultsColumn
            width: listFlick.width
            spacing: Style.space(8)

            Repeater {
              model: root.results

              Rectangle {
                required property var modelData
                required property int index
                width: resultsColumn.width
                implicitHeight: rowColumn.implicitHeight + Style.space(18)
                radius: Style.cornerRadius
                color: index === root.selectedIndex
                  ? Qt.rgba(root.statusColor(modelData.status).r, root.statusColor(modelData.status).g, root.statusColor(modelData.status).b, 0.10)
                  : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  onEntered: root.selectedIndex = index
                  onClicked: function(mouse) {
                    root.selectedIndex = index
                    if (mouse.button === Qt.RightButton && modelData.command) root.copyCommand(modelData.command)
                  }
                }

                Column {
                  id: rowColumn
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(12)
                  anchors.rightMargin: Style.space(12)
                  spacing: Style.space(4)

                  Row {
                    width: parent.width
                    spacing: Style.space(8)
                    Text {
                      text: root.statusGlyph(modelData.status)
                      color: root.statusColor(modelData.status)
                      font.pixelSize: Style.font.body
                    }
                    Text {
                      text: modelData.title
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }
                  }

                  Text {
                    width: parent.width
                    text: modelData.summary
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                  }

                  Text {
                    visible: modelData.command !== ""
                    width: parent.width
                    text: modelData.command === "" ? "" : "Copy: " + modelData.command
                    color: root.statusColor(modelData.status)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                  }
                }
              }
            }

            Text {
              visible: root.results.length === 0
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: root.scanning ? "Doctor is checking the machine…" : "Run Doctor to check this machine."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              topPadding: Style.space(24)
              bottomPadding: Style.space(24)
            }
          }
        }
      }
    }
  }
}
