import QtQuick
import QtQuick.Controls
import qs.Commons

Column {
    id:root
    required property var host
    spacing:14
    Rectangle {
        width:parent.width;height:head.implicitHeight+44;radius:12;color:host.card;border.color:host.edge
        Row {
            id:head;x:22;y:22;width:parent.width-44;spacing:20
            MedicalCross{width:54;height:54;state:"ok";anchors.verticalCenter:parent.verticalCenter}
            Column {
                width:parent.width-74;spacing:8
                Text{font.family:Style.font.family;text:"OMARCHY DOCTOR / "+host.version;color:host.dim;font.pixelSize:11;font.letterSpacing:1.7}
                Text{font.family:Style.font.family;width:parent.width;text:"A visual checkup for your Omarchy machine.";color:host.ink;font.pixelSize:22;wrapMode:Text.WordWrap}
                Text{font.family:Style.font.family;width:parent.width;text:"16 diagnostic checks with the evidence behind every result, live hardware graphics, seven days of history, and a hand off to your own agent when something needs fixing.";color:host.dim;font.pixelSize:13;wrapMode:Text.WordWrap;lineHeight:1.3}
                Row {
                    spacing:10;topPadding:6
                    DoctorAction{text:"Source code on GitHub  →";primary:true;ink:host.ink;accent:host.good;onClicked:host.openUrl(host.repoUrl)}
                    DoctorAction{text:"nixfred.com  →";ink:host.ink;accent:host.good;onClicked:host.openUrl(host.homeUrl)}
                }
            }
        }
    }
    Grid {
        width:parent.width;columns:width>=800?2:1;spacing:14
        Repeater {
            model:[
                {title:"HOW FIXES WORK",body:"Fix with agent gives a finding, its evidence and its inspect command to your default Omarchy agent (choose one with: omarchy default agent <name>). The agent works in its own terminal under its own permission settings, then asks Doctor to recheck. A fix counts only when Doctor measures the check healthy again, and is marked as came back if the problem returns within a day."},
                {title:"WHAT DOCTOR ITSELF DOES",body:"The collector only reads. It never repairs, removes packages, restarts services or kills applications, and nothing is uploaded. Clicking a finding runs nothing; inspect commands are copied only when you ask."},
                {title:"HONEST RESULTS",body:"Healthy means the checks completed with no detected concern. Unavailable, skipped, partial and stale results stay visible. Crash and journal checks count only what happens after a hand off, so a fix is proven by what comes next."},
                {title:"YOUR DATA",body:"History, fix records and exported reports stay in ~/.local/state/omarchy-doctor on this machine. Evidence can include device, service and journal details, so read an export before sharing it."}
            ]
            Rectangle {
                required property var modelData
                width:parent.columns===2?(root.width-14)/2:root.width;height:Math.max(150,card.implicitHeight+36);radius:12;color:host.card;border.color:host.edge
                Column {
                    id:card;x:20;y:18;width:parent.width-40;spacing:9
                    Text{font.family:Style.font.family;text:modelData.title;color:host.dim;font.pixelSize:11;font.letterSpacing:1.7}
                    Text{font.family:Style.font.family;width:parent.width;text:modelData.body;color:host.ink;font.pixelSize:13;wrapMode:Text.WordWrap;lineHeight:1.3;textFormat:Text.PlainText}
                }
            }
        }
    }
    Text{font.family:Style.font.family;width:parent.width;text:"Made by Fred Nix · MIT license";color:host.dim;font.pixelSize:11}
}
