import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// omcron's bar presence. All logic lives in the CLI: `omcron list --json` emits
// {count, waiting, active, tooltip} and this only renders it. That split is
// deliberate — it keeps every decision somewhere testable without a compositor.
BarWidget {
  id: root
  moduleName: "netors.omcron"

  property int jobCount: 0
  property int waitingCount: 0
  property string tooltipBody: ""
  property bool cliOk: true

  readonly property bool showWhenEmpty: setting("showWhenEmpty", true) === true
  readonly property bool attentionOnly: setting("attentionOnly", false) === true
  readonly property int refreshSec: Math.max(15, Number(setting("refreshIntervalSec", 60)))

  // ModuleSlot collapses a slot whose widget is invisible to zero width, so
  // hiding leaves no gap in the bar. Placing the widget is itself a statement of
  // intent, though, so the default is to stay put and dim rather than vanish —
  // a user who adds a widget and sees nothing reasonably files a bug.
  visible: attentionOnly
    ? waitingCount > 0
    : (jobCount > 0 || waitingCount > 0 || showWhenEmpty)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!jsonProc.running) jsonProc.running = true
  }

  function update(raw) {
    var d = Util.parseModuleJson(raw)
    jobCount = Number(d.count || 0)
    waitingCount = Number(d.waiting || 0)
    tooltipBody = String(d.tooltip || "")
  }

  Component.onCompleted: refresh()

  // An IPC target routes to a single handler, but there is one bar per monitor —
  // broadcast() relays to every instance so a refresh does not land on one screen
  // and leave the others stale.
  IpcHandler {
    target: "netors.omcron"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Process {
    id: jsonProc
    command: ["omcron", "list", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.update(text)
    }
    onExited: function (exitCode) {
      root.cliOk = exitCode === 0
      if (exitCode !== 0) {
        // Someone who ran `omarchy plugin add` but not install.sh lands here.
        // Say so in the tooltip rather than rendering a permanently empty widget.
        root.jobCount = 0
        root.waitingCount = 0
        root.tooltipBody = "omcron command not found\nRun install.sh from the plugin directory"
      }
    }
  }

  // "Next run" ages by itself even when nothing broadcasts, so re-read on a slow
  // tick as well as on demand. Every mutating CLI command also pokes the IPC.
  Timer {
    interval: root.refreshSec * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar

    // 󰀦 alert when a decision is waiting, 󰅒 timer otherwise. Standing alone the
    // widget can also carry the urgent colour, which the cluster version could
    // not — at this size a colour change reads faster than a shape change.
    text: root.waitingCount > 0 ? "󰀦" : "󰅒"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    active: root.waitingCount > 0
    useActiveColor: true
    dimmed: !root.cliOk || (root.jobCount === 0 && root.waitingCount === 0)
    tooltipText: root.tooltipBody

    onPressed: function () {
      if (root.waitingCount > 0) Quickshell.execDetached(["omcron", "answer"])
      else Quickshell.execDetached(["omcron", "status"])
    }
  }
}
