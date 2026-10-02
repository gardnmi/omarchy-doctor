import QtQuick
import qs.Commons
import "Model.js" as Model

Column {
    id:root
    required property var host
    spacing:17
    Text{font.family:Style.font.family;text:"Make Doctor feel right.";color:host.ink;font.pixelSize:27}
    Rectangle {
        width:parent.width;height:115;radius:12;color:host.card;border.color:host.edge
        Column {
            x:20;y:18;width:parent.width-40;spacing:11
            Text{font.family:Style.font.family;text:"MOTION";color:host.dim;font.pixelSize:11;font.letterSpacing:1.7}
            Row {
                spacing:10
                DoctorAction{text:"Animated";selected:host.motion;ink:host.ink;accent:host.good;onClicked:host.saveSetting("motion",true)}
                DoctorAction{text:"Reduced motion";selected:!host.motion;ink:host.ink;accent:host.good;onClicked:host.saveSetting("motion",false)}
                Text{font.family:Style.font.family;text:"Drawings animate only while visible.";color:host.dim;font.pixelSize:12;anchors.verticalCenter:parent.verticalCenter}
            }
        }
    }
    Rectangle {
        width:parent.width;height:140;radius:12;color:host.card;border.color:host.edge
        Column {
            x:20;y:18;width:parent.width-40;spacing:11
            Text{font.family:Style.font.family;text:"AUTOMATIC CHECKUPS";color:host.dim;font.pixelSize:11;font.letterSpacing:1.7}
            Row {
                spacing:10
                Repeater {
                    model:[{n:0,label:"Manual"},{n:120,label:"Every 2 minutes"},{n:300,label:"Every 5 minutes"}]
                    DoctorAction{required property var modelData;text:modelData.label;selected:host.refreshSeconds===modelData.n;ink:host.ink;accent:host.good;onClicked:host.saveSetting("refreshSeconds",modelData.n)}
                }
            }
            Text{font.family:Style.font.family;width:parent.width;text:"Automatic scans and live sampling run while the panel is open. Deep scans include package file integrity; routine scans keep that expensive check separate.";color:host.dim;font.pixelSize:12;wrapMode:Text.WordWrap}
        }
    }
    Rectangle {
        width:parent.width;height:about.implicitHeight+40;radius:12;color:host.card;border.color:host.edge
        Column {
            id:about;x:20;y:20;width:parent.width-40;spacing:13
            Text{font.family:Style.font.family;text:"OMARCHY DOCTOR / "+host.version;color:host.dim;font.pixelSize:11;font.letterSpacing:1.7}
            Text{font.family:Style.font.family;width:parent.width;text:"A visual checkup for your machine. Inspired by Pulse's drawn hardware, clear priorities and live histories, with diagnostic evidence behind every result.";color:host.ink;font.pixelSize:13;wrapMode:Text.WordWrap;lineHeight:1.3}
            Text{font.family:Style.font.family;width:parent.width;text:"Doctor never repairs, removes packages, restarts services or kills applications. Diagnostic commands are shown for inspection and copied only when you choose. Scan records and observations stay in your local state directory for up to seven days; exported reports remain until you remove them.";color:host.dim;font.pixelSize:13;wrapMode:Text.WordWrap;lineHeight:1.3}
            Text{font.family:Style.font.family;width:parent.width;text:"Healthy means the checks completed with no detected concerns. Unavailable, skipped, partial and stale results remain visible. Missing tools and SMART permissions are reported honestly.";color:host.dim;font.pixelSize:13;wrapMode:Text.WordWrap;lineHeight:1.3}
            DoctorAction{text:"Export scan evidence";ink:host.ink;accent:host.good;onClicked:host.exportReport()}
        }
    }
}
