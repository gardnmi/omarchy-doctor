import QtQuick
import Quickshell
ShellRoot {
  Doctor { id: doctor; manageIpc: false }
  Timer {
    interval: 700; running: true
    onTriggered: {
      console.log("DOCTOR_REVIEW " + JSON.stringify({width: doctor.width, implicitWidth: doctor.implicitWidth, height: doctor.height, implicitHeight: doctor.implicitHeight}))
      doctor.parseResults("info\tDrive health\tPermission denied\t")
      console.log("DOCTOR_REVIEW " + JSON.stringify({status: doctor.overallStatus, label: doctor.overallLabel, ok: doctor.okCount, results: doctor.results.length}))
      doctor.refresh()
    }
  }
  Timer {
    interval: 1500; running: true
    onTriggered: {
      console.log("DOCTOR_PARTIAL_EXIT_7 " + JSON.stringify({status: doctor.overallStatus, label: doctor.overallLabel, scanning: doctor.scanning, results: doctor.results}))
      Qt.quit()
    }
  }
}
