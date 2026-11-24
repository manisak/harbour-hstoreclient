import QtQuick 2.2
import Sailfish.Silica 1.0

Page {
    id: rootPage

    property string storeUrl: "https://harpoon-store.manisak.com"
    property string appStatus: "loading…"
    property string activeCat: ""

    ListModel { id: catModel }
    ListModel { id: listModel }

    // --- header ---
    Label {
        id: header
        x: Theme.horizontalPageMargin
        topPadding: Theme.paddingLarge
        text: qsTr("⚓ Harpoon Store")
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.highlightColor
    }

    // --- categories listed vertically ---
    Column {
        id: catColumn
        anchors {
            left: parent.left; right: parent.right
            top: header.bottom; topMargin: Theme.paddingMedium
        }
        spacing: 0

        Repeater {
            model: catModel
            delegate: ListItem {
                id: catItem

                contentHeight: Theme.itemSizeSmall + (index === 0 && slug !== "" ? 20 : 0)

                onClicked: rootPage.selectCat(slug)

                Rectangle {
                    anchors.fill: parent
                    color: rootPage.activeCat === slug ? Theme.highlightColor : "transparent"
                    opacity: 0.35
                }
                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr(name ? name : "All") + "  (" + count + ")"
                    color: rootPage.activeCat === slug ? Theme.primaryColor : Theme.highlightColor
                }
            }
        }
    }

    Rectangle {
        anchors {
            left: parent.left; right: parent.right
            top: catColumn.bottom; topMargin: Theme.paddingSmall
        }
        height: 2
        color: Theme.rgba(255, 255, 255, 0.15)
    }

    // --- app list ---
    SilicaListView {
        id: appList
        model: listModel

        anchors {
            left: parent.left; right: parent.right
            top: catColumn.bottom; topMargin: Theme.paddingMedium
            bottom: parent.bottom
        }

        clip: true

        PullDownMenu {
            MenuItem { text: qsTr("Reload"); onClicked: rootPage.loadApps() }
        }

        delegate: ListItem {
            width: appList.width
            height: Theme.itemSizeMedium

            onClicked: pageStack.push(Qt.resolvedUrl("DetailPage.qml"), { appData: model })

            Column {
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Label { text: name + (appRating > 0 ? "   ★ " + Number(appRating).toFixed(1) : ""); font.pixelSize: Theme.fontSizeMedium }
                Label {
                    text: appCategory + (currentVersion ? "  ·  v" + currentVersion : "")
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                }
            }
        }
    }

    BusyIndicator {
        visible: listModel.count === 0 && appStatus === "loading…"
        running: visible
        anchors.centerIn: parent
    }

    Label {
        visible: listModel.count === 0 && appStatus !== "loading…"
        anchors.centerIn: parent
        width: page.width - 2 * Theme.horizontalPageMargin
        horizontalAlignment: Text.AlignHCenter
        text: appStatus
        color: Theme.secondaryColor
        wrapMode: Text.Wrap
    }

    onStatusChanged: if (status === PageStatus.Activating) { loadCats(); loadApps(); }

    function loadCats() {
        var x = new XMLHttpRequest();
        x.open("GET", rootPage.storeUrl + "/api/categories.json", true);
        x.onreadystatechange = function () {
            if (x.readyState === XMLHttpRequest.DONE) {
                if (x.status === 200) {
                    try {
                        var obj = JSON.parse(x.responseText);
                        var cur = activeCat;
                        catModel.clear();
                        catModel.append({ slug: "", name: "All", count: 0 });
                        for (var i = 0; i < obj.categories.length; i++) catModel.append(obj.categories[i]);
                        for (var j = 0; j < catModel.count; j++) catModel.setProperty(j, "sel", catModel.get(j).slug === cur);
                    } catch (e) { appStatus = "Cat parse error: " + e; }
                } else if (x.status !== 0) { appStatus = "Store not reachable (HTTP " + x.status + ")"; }
            }
        };
        x.send();
    }

    function loadApps() {
        appStatus = "loading…";
        var listUrl = rootPage.storeUrl + "/api/apps.json" + (activeCat !== "" ? "?cat=" + activeCat : "");
        var x = new XMLHttpRequest();
        x.open("GET", listUrl, true);
        x.onreadystatechange = function () {
            if (x.readyState === XMLHttpRequest.DONE) {
                if (x.status === 200) {
                    try {
                        var obj = JSON.parse(x.responseText);
                        listModel.clear();
                        for (var i = 0; i < obj.apps.length; i++) {
                            var a = obj.apps[i];
                            var r = a.rating > 0 ? Number(a.rating) : 0;
                            listModel.append({
                                appId: a.id,
                                name: a.name,
                                description: a.description,
                                repoUrl: a.repo_url,
                                appCategory: a.category,
                                appRating: r,
                                ratings: a.ratings,
                                currentVersion: a.current_version
                            });
                        }
                        appStatus = "";
                    } catch (e) { appStatus = "Parse error: " + e; }
                } else if (x.status === 0) {
                    appStatus = "Store not reachable (offline?)";
                } else { appStatus = "Store not reachable (HTTP " + x.status + ")"; }
            }
        };
        x.send();
    }

    function selectCat(slug) {
        activeCat = slug;
        loadApps();
        for (var j = 0; j < catModel.count; j++) catModel.setProperty(j, "sel", catModel.get(j).slug === activeCat);
    }
}
