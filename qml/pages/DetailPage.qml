import QtQuick 2.2
import Sailfish.Silica 1.0

Page {
    id: detailPage

    property var appData

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Install with Harpoon")
                onClicked: Qt.openUrlExternally("harpoon://add?url=" + encodeURIComponent(appData.repoUrl))
            }
        }

        Column {
            id: contentColumn
            spacing: Theme.paddingMedium
            x: Theme.horizontalPageMargin
            width: detailPage.width - 2 * Theme.horizontalPageMargin

            PageHeader { title: appData.name }

            Label { text: appData.appCategory; font.pixelSize: Theme.fontSizeSmall; color: Theme.secondaryColor }

            Label {
                text: appData.appRating > 0 ? qsTr("Rating") + ": ★ " + Number(appData.appRating).toFixed(1) + " / 5 (" + appData.ratings + ")" : qsTr("No ratings yet")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
            }

            Label {
                visible: appData.currentVersion !== ""
                text: qsTr("Current version") + ": " + appData.currentVersion
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            Label {
                width: parent.width
                text: appData.description
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                text: qsTr("Source") + ": " + appData.repoUrl
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                text: qsTr("Tap 'Install with Harpoon' in the pull-down menu: Harpoon opens with this repository pre-filled — confirm there to install.")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
            }
        }
    }

    onStatusChanged: if (status === PageStatus.Activating) {
        appData.appCategory = appData.appCategory || "General";
        appData.appRating = appData.appRating !== undefined ? appData.appRating : 0;
        appData.ratings = appData.ratings || 0;
        appData.currentVersion = appData.currentVersion || "";
    }
}
