import QtQuick
import qs.Commons
import QtQuick.Controls
import "Model.js" as Model

Column {
    id:root
    required property var host
    spacing:14
    readonly property var tally:{
        var t={fixed:0,open:0,failing:0}
        host.fixes.forEach(function(f){if(f.status==="fixed")t.fixed++;else if(f.status==="pending")t.open++;else if(f.status==="still_failing")t.failing++})
        return t
    }
    function label(status){return status==="fixed"?"Fixed":status==="pending"?"With agent":status==="still_failing"?"Still failing":status==="superseded"?"Replaced":"Not started"}
    function tint(status){return status==="fixed"?host.good:status==="pending"?host.unknown:status==="still_failing"?host.warning:host.dim}
    function took(f){
        if(!f.resolved)return ""
        var s=Math.max(0,Math.round(f.resolved-f.started))
        return s<60?s+"s":s<3600?Math.floor(s/60)+"m":Math.floor(s/3600)+"h "+Math.floor(s%3600/60)+"m"
    }
    Row {
        width:parent.width;spacing:12
        Repeater {
            model:[{n:root.tally.fixed,label:"FIXED BY DOCTOR",c:host.good},{n:root.tally.open,label:"WITH AGENT",c:host.unknown},{n:root.tally.failing,label:"STILL FAILING",c:host.warning}]
            Rectangle {
                required property var modelData
                width:(root.width-24)/3;height:78;radius:12;color:host.card;border.color:host.edge
                Text{font.family:Style.font.family;x:18;y:14;text:modelData.label;color:host.dim;font.pixelSize:11;font.letterSpacing:1.6}
                Text{font.family:Style.font.family;x:18;y:32;text:String(modelData.n);color:modelData.n?modelData.c:host.dim;font.pixelSize:28}
            }
        }
    }
    Text{font.family:Style.font.family;width:parent.width;text:"Fix with agent hands a finding to your default Omarchy agent with its evidence. The agent rechecks when it is done; a fix counts only once Doctor measures the check healthy again.";color:host.dim;font.pixelSize:12;wrapMode:Text.WordWrap}
    Rectangle {
        width:parent.width;height:Math.max(140,Math.min(420,list.contentHeight+20));radius:12;color:host.card;border.color:host.edge
        ListView {
            id:list;x:10;y:10;width:parent.width-20;height:parent.height-20;clip:true;spacing:7;model:host.fixes
            boundsBehavior:Flickable.StopAtBounds
            ScrollBar.vertical:ScrollBar{policy:ScrollBar.AsNeeded}
            delegate:Rectangle {
                id:item
                required property var modelData
                width:ListView.view.width-8;height:fixBody.implicitHeight+22;radius:9;color:Qt.alpha(host.ink,0.025)
                Column {
                    id:fixBody;x:14;y:11;width:parent.width-28;spacing:6
                    Row {
                        width:parent.width;spacing:10
                        Rectangle{width:6;height:6;radius:3;color:root.tint(item.modelData.status);anchors.verticalCenter:parent.verticalCenter}
                        Text{font.family:Style.font.family;width:parent.width-statusText.implicitWidth-30;text:item.modelData.title;color:host.ink;font.pixelSize:13;font.bold:true;elide:Text.ElideRight;textFormat:Text.PlainText}
                        Text{font.family:Style.font.family;id:statusText;text:root.label(item.modelData.status).toUpperCase();color:root.tint(item.modelData.status);font.pixelSize:11;font.letterSpacing:1}
                    }
                    Text{font.family:Style.font.family;width:parent.width;text:"Before · "+item.modelData.before_summary;color:host.dim;font.pixelSize:12;wrapMode:Text.WordWrap;textFormat:Text.PlainText}
                    Text{font.family:Style.font.family;width:parent.width;visible:item.modelData.after_summary!=="";text:"After · "+item.modelData.after_summary;color:item.modelData.status==="fixed"?host.good:host.dim;font.pixelSize:12;wrapMode:Text.WordWrap;textFormat:Text.PlainText}
                    Text{
                        font.family:Style.font.family
                        width:parent.width;color:host.dim;font.pixelSize:11;wrapMode:Text.WordWrap
                        text:Model.stamp(item.modelData.started)+(item.modelData.agent?" · "+item.modelData.agent:"")+(root.took(item.modelData)?" · took "+root.took(item.modelData):"")+(item.modelData.attempts?" · "+item.modelData.attempts+" recheck(s) failed":"")
                    }
                }
            }
        }
        Text{font.family:Style.font.family;anchors.centerIn:parent;visible:!host.fixes.length;text:"No fixes yet. Open a finding and choose Fix with agent.";color:host.dim;font.pixelSize:13}
    }
}
