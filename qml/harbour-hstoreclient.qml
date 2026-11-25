import QtQuick 2.2
import Sailfish.Silica 1.0

// Harpoon Store — native Sailfish OS Silica client.
// Runs under `sailfish-qml harbour-hstoreclient` (Rectangle root, no ApplicationWindow).
// Manual page-stack via visible-toggled Items; Silica components inside.

Rectangle {
    id: root
    color: Theme.rgba(Theme.overlayBackgroundColor, 1.0)
    anchors.fill: parent

    property string storeUrl: "https://harpoon-store.manisak.com"
    property string statusMsg: ""
    property string activeCat: ""
    property string activeCatName: "All"
    property bool   busy: false

    // currently open detail-app (null = closed)
    property var    detail: null
    // currently open developer page (null = closed)
    property var    devData: null

    // search filter
    property string searchText: ""

    // master list (all apps across all cats) + view list (filtered)
    ListModel { id: masterModel }
    ListModel { id: viewModel }
    ListModel { id: catModel }

    // ------------------------- helpers -------------------------

    function refreshView() {
        viewModel.clear();
        var needle = searchText.toLowerCase();
        for (var i = 0; i < masterModel.count; ++i) {
            var a = masterModel.get(i);
            if (activeCat && a.cat_slug !== activeCat) continue;
            if (needle.length) {
                var hay = (a.name + " " + a.description + " " + a.owner).toLowerCase();
                if (hay.indexOf(needle) === -1) continue;
            }
            viewModel.append({
                appId: a.appId, name: a.name, description: a.description,
                repoUrl: a.repoUrl, appCategory: a.appCategory, cat_slug: a.cat_slug,
                iconUrl: a.iconUrl, appRating: a.appRating, ratings: a.ratings,
                currentVersion: a.currentVersion, owner: a.owner
            });
        }
    }

    function loadCats() {
        var x = new XMLHttpRequest();
        x.open("GET", storeUrl + "/api/categories.json", true);
        x.onreadystatechange = function () {
            if (x.readyState === XMLHttpRequest.DONE && x.status === 200) {
                try {
                    var o = JSON.parse(x.responseText);
                    catModel.clear();
                    var total = 0;
                    for (var i = 0; i < o.categories.length; ++i) total += o.categories[i].count;
                    catModel.append({ slug: "", name: "All apps", count: total });
                    for (var j = 0; j < o.categories.length; ++j) catModel.append(o.categories[j]);
                } catch (e) { statusMsg = "Cat parse: " + e; }
            }
        };
        x.send();
    }

    function loadApps() {
        busy = true;
        statusMsg = "";
        var x = new XMLHttpRequest();
        x.open("GET", storeUrl + "/api/apps.json", true);
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            busy = false;
            if (x.status !== 200) {
                statusMsg = x.status === 0 ? "Store not reachable (offline?)" : "HTTP " + x.status;
                return;
            }
            try {
                var o = JSON.parse(x.responseText);
                masterModel.clear();
                // server already exposes cat name; cat_slug not in /api/apps.json — fetch via /api/app/:id.json only when needed.
                for (var i = 0; i < o.apps.length; ++i) {
                    var a = o.apps[i];
                    masterModel.append({
                        appId: a.id, name: a.name, description: a.description || "",
                        repoUrl: a.repo_url, appCategory: a.category || "General",
                        cat_slug: a.cat_slug || "",
                        iconUrl: a.iconUrl, appRating: a.rating > 0 ? a.rating : 0,
                        ratings: a.ratings || 0, currentVersion: a.current_version || "",
                        owner: a.owner || ""
                    });
                }
                refreshView();
            } catch (e) { statusMsg = "Parse error: " + e; }
        };
        x.send();
    }

    function loadDetail(appId) {
        busy = true;
        var x = new XMLHttpRequest();
        x.open("GET", storeUrl + "/api/app/" + appId + ".json", true);
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            busy = false;
            if (x.status !== 200) { statusMsg = "Detail HTTP " + x.status; return; }
            try {
                var o = JSON.parse(x.responseText);
                detail = o;
                detailPage.visible = true;
                devPage.visible = false;
            } catch (e) { statusMsg = "Detail parse: " + e; }
        };
        x.send();
    }

    function loadDeveloper(username) {
        if (!username) return;
        busy = true;
        var x = new XMLHttpRequest();
        x.open("GET", storeUrl + "/api/developer/" + encodeURIComponent(username) + ".json", true);
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            busy = false;
            if (x.status !== 200) { statusMsg = "Dev HTTP " + x.status; return; }
            try {
                var o = JSON.parse(x.responseText);
                devData = o;
                devPage.visible = true;
            } catch (e) { statusMsg = "Dev parse: " + e; }
        };
        x.send();
    }

    function selectCat(slug, name) {
        activeCat = slug;
        activeCatName = name;
        refreshView();
        catOverlay.visible = false;
    }

    Component.onCompleted: { loadCats(); loadApps(); }

    // ============================================================
    //  MAIN PAGE  (search + categories button + app list)
    // ============================================================
    Item {
        id: mainPage
        anchors.fill: parent
        visible: !detailPage.visible && !devPage.visible && !catOverlay.visible

        SilicaFlickable {
            anchors.fill: parent
            contentHeight: mainCol.height + Theme.paddingLarge * 2
            clip: true

            PullDownMenu {
                MenuItem { text: qsTr("About Harpoon Store"); onClicked: aboutOverlay.visible = true }
                MenuItem { text: qsTr("Categories");          onClicked: catOverlay.visible = true }
                MenuItem { text: qsTr("Reload");              onClicked: { loadCats(); loadApps(); } }
            }

            Column {
                id: mainCol
                width: parent.width
                spacing: Theme.paddingMedium

                // ---- hero header ----
                Item {
                    width: parent.width
                    height: heroCol.height + Theme.paddingLarge * 2

                    Column {
                        id: heroCol
                        anchors { left: parent.left; right: parent.right; top: parent.top
                                  leftMargin: Theme.horizontalPageMargin
                                  rightMargin: Theme.horizontalPageMargin
                                  topMargin: Theme.paddingLarge }
                        spacing: Theme.paddingSmall

                        Row {
                            spacing: Theme.paddingMedium
                            Label {
                                text: "⚓"
                                font.pixelSize: Theme.fontSizeHuge
                                color: Theme.highlightColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Label {
                                text: qsTr("Harpoon Store")
                                font.pixelSize: Theme.fontSizeExtraLarge
                                font.family: Theme.fontFamilyHeading
                                color: Theme.highlightColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Label {
                            text: qsTr("Community apps for Sailfish OS")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.secondaryColor
                        }
                    }
                }

                // ---- search field ----
                SearchField {
                    id: search
                    width: parent.width
                    placeholderText: qsTr("Search apps, developers…")
                    onTextChanged: { root.searchText = text; refreshView(); }
                    EnterKey.onClicked: focus = false
                }

                // ---- active category chip ----
                BackgroundItem {
                    width: parent.width
                    height: Theme.itemSizeSmall
                    onClicked: catOverlay.visible = true
                    Row {
                        anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin
                                  verticalCenter: parent.verticalCenter }
                        spacing: Theme.paddingSmall
                        Label {
                            text: qsTr("Category:")
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Label {
                            text: activeCatName
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                        }
                        Label {
                            text: "▾"
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                    Label {
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin
                                  verticalCenter: parent.verticalCenter }
                        text: viewModel.count + " " + qsTr("apps")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }

                SectionHeader { text: qsTr("Browse") }

                // ---- app list ----
                Repeater {
                    model: viewModel
                    delegate: BackgroundItem {
                        id: rowItem
                        width: mainCol.width
                        height: Math.max(Theme.itemSizeLarge, appRow.height + Theme.paddingMedium)

                        onClicked: loadDetail(model.appId)

                        Row {
                            id: appRow
                            anchors { left: parent.left; right: parent.right
                                      verticalCenter: parent.verticalCenter
                                      leftMargin: Theme.horizontalPageMargin
                                      rightMargin: Theme.horizontalPageMargin }
                            spacing: Theme.paddingMedium

                            // icon
                            Item {
                                width: Theme.itemSizeMedium
                                height: Theme.itemSizeMedium
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.paddingSmall
                                    color: Theme.rgba(Theme.highlightColor, 0.08)
                                    border { color: Theme.rgba(Theme.highlightColor, 0.25); width: 1 }
                                }
                                Image {
                                    anchors { fill: parent; margins: Theme.paddingSmall }
                                    source: model.iconUrl ? (root.storeUrl + model.iconUrl) : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                    visible: model.iconUrl ? true : false
                                }
                                Label {
                                    anchors.centerIn: parent
                                    text: model.name ? model.name.charAt(0).toUpperCase() : "?"
                                    color: Theme.highlightColor
                                    font.pixelSize: Theme.fontSizeLarge
                                    visible: !model.iconUrl
                                }
                            }

                            // text column
                            Column {
                                width: parent.width - Theme.itemSizeMedium - Theme.paddingMedium
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter

                                Label {
                                    width: parent.width
                                    text: model.name
                                    color: rowItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeMedium
                                    truncationMode: TruncationMode.Fade
                                }
                                Label {
                                    width: parent.width
                                    text: model.description
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideRight
                                    visible: model.description.length > 0
                                }
                                Row {
                                    spacing: Theme.paddingSmall
                                    Label {
                                        text: model.appCategory
                                        color: Theme.secondaryHighlightColor
                                        font.pixelSize: Theme.fontSizeTiny
                                    }
                                    Label {
                                        visible: model.currentVersion.length > 0
                                        text: "· v" + model.currentVersion
                                        color: Theme.secondaryColor
                                        font.pixelSize: Theme.fontSizeTiny
                                    }
                                    Label {
                                        visible: model.owner.length > 0
                                        text: "· @" + model.owner
                                        color: Theme.secondaryColor
                                        font.pixelSize: Theme.fontSizeTiny
                                    }
                                    Label {
                                        visible: model.appRating > 0
                                        text: "· ★ " + Number(model.appRating).toFixed(1)
                                        color: Theme.highlightColor
                                        font.pixelSize: Theme.fontSizeTiny
                                    }
                                }
                            }
                        }
                    }
                }

                // empty / status
                Item {
                    width: parent.width
                    height: emptyCol.height + Theme.paddingLarge * 2
                    visible: viewModel.count === 0
                    Column {
                        id: emptyCol
                        anchors.centerIn: parent
                        spacing: Theme.paddingSmall
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        BusyIndicator {
                            size: BusyIndicatorSize.Large
                            running: root.busy
                            visible: root.busy
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            color: Theme.secondaryColor
                            text: root.busy ? qsTr("Loading…")
                                            : (root.searchText.length > 0
                                               ? qsTr("No apps match your search.")
                                               : (statusMsg.length > 0 ? statusMsg : qsTr("No apps.")))
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    //  CATEGORY OVERLAY
    // ============================================================
    Item {
        id: catOverlay
        anchors.fill: parent
        visible: false
        Rectangle { anchors.fill: parent; color: Theme.overlayBackgroundColor }

        SilicaListView {
            anchors.fill: parent
            model: catModel
            header: Item {
                width: parent.width
                height: Theme.itemSizeLarge
                Label {
                    anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin
                              verticalCenter: parent.verticalCenter }
                    text: qsTr("Categories")
                    font.pixelSize: Theme.fontSizeExtraLarge
                    font.family: Theme.fontFamilyHeading
                    color: Theme.highlightColor
                }
            }
            PullDownMenu {
                MenuItem { text: qsTr("Close"); onClicked: catOverlay.visible = false }
            }
            delegate: BackgroundItem {
                width: ListView.view.width
                height: Theme.itemSizeSmall
                onClicked: selectCat(model.slug, model.name)
                Label {
                    anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin
                              verticalCenter: parent.verticalCenter }
                    text: model.name
                    color: highlighted ? Theme.highlightColor
                                       : (root.activeCat === model.slug ? Theme.highlightColor : Theme.primaryColor)
                    font.pixelSize: Theme.fontSizeMedium
                }
                Label {
                    anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin
                              verticalCenter: parent.verticalCenter }
                    text: model.count
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }

    // ============================================================
    //  DETAIL PAGE
    // ============================================================
    Item {
        id: detailPage
        anchors.fill: parent
        visible: false
        Rectangle { anchors.fill: parent; color: Theme.overlayBackgroundColor }

        SilicaFlickable {
            anchors.fill: parent
            contentHeight: detailCol.height + Theme.paddingLarge * 2
            clip: true

            PullDownMenu {
                MenuItem {
                    text: qsTr("Open repository in browser")
                    onClicked: if (root.detail) Qt.openUrlExternally(root.detail.repo_url)
                }
                MenuItem {
                    text: qsTr("Install with Harpoon")
                    onClicked: if (root.detail) Qt.openUrlExternally("harpoon://add?url=" + encodeURIComponent(root.detail.repo_url))
                }
                MenuItem { text: qsTr("Back"); onClicked: detailPage.visible = false }
            }

            Column {
                id: detailCol
                width: parent.width
                spacing: Theme.paddingMedium
                visible: !!root.detail

                // ---- back bar ----
                BackgroundItem {
                    width: parent.width
                    height: Theme.itemSizeSmall
                    onClicked: detailPage.visible = false
                    Label {
                        anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin
                                  verticalCenter: parent.verticalCenter }
                        text: "‹ " + qsTr("Back")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                    }
                }

                // ---- hero: icon + name + meta ----
                Item {
                    width: parent.width
                    height: heroRow.height + Theme.paddingMedium
                    Row {
                        id: heroRow
                        anchors { left: parent.left; right: parent.right; top: parent.top
                                  leftMargin: Theme.horizontalPageMargin
                                  rightMargin: Theme.horizontalPageMargin }
                        spacing: Theme.paddingMedium

                        Item {
                            width: Theme.itemSizeHuge
                            height: Theme.itemSizeHuge
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.paddingMedium
                                color: Theme.rgba(Theme.highlightColor, 0.10)
                                border { color: Theme.rgba(Theme.highlightColor, 0.30); width: 1 }
                            }
                            Image {
                                anchors { fill: parent; margins: Theme.paddingSmall }
                                source: root.detail && root.detail.iconUrl ? (root.storeUrl + root.detail.iconUrl) : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                visible: !!(root.detail && root.detail.iconUrl)
                            }
                            Label {
                                anchors.centerIn: parent
                                text: root.detail ? root.detail.name.charAt(0).toUpperCase() : "?"
                                color: Theme.highlightColor
                                font.pixelSize: Theme.fontSizeHuge
                                visible: !(root.detail && root.detail.iconUrl)
                            }
                        }

                        Column {
                            width: parent.width - Theme.itemSizeHuge - Theme.paddingMedium
                            spacing: Theme.paddingSmall / 2
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                width: parent.width
                                text: root.detail ? root.detail.name : ""
                                color: Theme.highlightColor
                                font.pixelSize: Theme.fontSizeLarge
                                font.family: Theme.fontFamilyHeading
                                wrapMode: Text.Wrap
                            }
                            Label {
                                text: root.detail ? root.detail.category : ""
                                color: Theme.secondaryHighlightColor
                                font.pixelSize: Theme.fontSizeSmall
                            }
                            Row {
                                spacing: Theme.paddingSmall
                                Label {
                                    visible: root.detail && root.detail.current_version
                                    text: root.detail ? "v" + root.detail.current_version : ""
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                                Label {
                                    visible: root.detail && root.detail.rating > 0
                                    text: root.detail ? "★ " + Number(root.detail.rating).toFixed(1) + "  (" + root.detail.ratings + ")" : ""
                                    color: Theme.highlightColor
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }
                        }
                    }
                }

                // ---- install CTA ----
                BackgroundItem {
                    width: parent.width
                    height: installBtn.height + Theme.paddingMedium * 2
                    onClicked: if (root.detail) Qt.openUrlExternally("harpoon://add?url=" + encodeURIComponent(root.detail.repo_url))
                    Rectangle {
                        id: installBtn
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                  leftMargin: Theme.horizontalPageMargin
                                  rightMargin: Theme.horizontalPageMargin }
                        height: Theme.itemSizeSmall
                        radius: Theme.itemSizeSmall / 2
                        color: Theme.highlightColor
                        Label {
                            anchors.centerIn: parent
                            text: "⚓  " + qsTr("Install with Harpoon")
                            color: Theme.overlayBackgroundColor
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                        }
                    }
                }

                // ---- developer card ----
                SectionHeader { text: qsTr("Developer") }
                BackgroundItem {
                    width: parent.width
                    height: devRow.height + Theme.paddingMedium * 2
                    onClicked: if (root.detail && root.detail.owner) loadDeveloper(root.detail.owner)
                    Row {
                        id: devRow
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                  leftMargin: Theme.horizontalPageMargin
                                  rightMargin: Theme.horizontalPageMargin }
                        spacing: Theme.paddingMedium
                        Rectangle {
                            width: Theme.itemSizeSmall; height: Theme.itemSizeSmall
                            radius: Theme.itemSizeSmall / 2
                            color: Theme.rgba(Theme.highlightColor, 0.20)
                            anchors.verticalCenter: parent.verticalCenter
                            Label {
                                anchors.centerIn: parent
                                text: root.detail && root.detail.owner ? root.detail.owner.charAt(0).toUpperCase() : "?"
                                color: Theme.highlightColor
                                font.pixelSize: Theme.fontSizeLarge
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: parent.width - Theme.itemSizeSmall - Theme.paddingMedium
                            Label {
                                text: root.detail ? ("@" + root.detail.owner) : ""
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeMedium
                            }
                            Label {
                                text: qsTr("Tap to see all apps by this developer ›")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                            }
                        }
                    }
                }

                // ---- contributors ----
                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    visible: !!(root.detail && root.detail.contributors && root.detail.contributors.length > 0)

                    SectionHeader { text: qsTr("Contributors") }
                    Flow {
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        x: Theme.horizontalPageMargin
                        spacing: Theme.paddingSmall
                        Repeater {
                            model: root.detail ? root.detail.contributors : []
                            delegate: BackgroundItem {
                                width: contribChip.width + Theme.paddingMedium * 2
                                height: contribChip.height + Theme.paddingSmall * 2
                                onClicked: Qt.openUrlExternally("https://github.com/" + modelData)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: Theme.rgba(Theme.highlightColor, 0.12)
                                }
                                Label {
                                    id: contribChip
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: Theme.highlightColor
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                }
                            }
                        }
                    }
                }

                // ---- screenshots ----
                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    visible: !!(root.detail && root.detail.screenshots && root.detail.screenshots.length > 0)
                    SectionHeader { text: qsTr("Screenshots") }
                    SilicaListView {
                        width: parent.width
                        height: Theme.itemSizeHuge * 2
                        orientation: ListView.Horizontal
                        model: root.detail ? root.detail.screenshots : []
                        spacing: Theme.paddingSmall
                        leftMargin: Theme.horizontalPageMargin
                        rightMargin: Theme.horizontalPageMargin
                        clip: true
                        delegate: Item {
                            width: height * 0.6
                            height: ListView.view.height
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.paddingSmall
                                color: Theme.rgba(Theme.highlightColor, 0.06)
                            }
                            Image {
                                anchors { fill: parent; margins: 2 }
                                source: root.storeUrl + modelData
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                            }
                        }
                    }
                }

                // ---- description ----
                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    visible: !!(root.detail && root.detail.description && root.detail.description.length > 0)
                    SectionHeader { text: qsTr("About this app") }
                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        text: root.detail ? root.detail.description : ""
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }

                // ---- source ----
                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    SectionHeader { text: qsTr("Source") }
                    BackgroundItem {
                        width: parent.width
                        height: srcLbl.height + Theme.paddingMedium * 2
                        onClicked: if (root.detail) Qt.openUrlExternally(root.detail.repo_url)
                        Label {
                            id: srcLbl
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                      leftMargin: Theme.horizontalPageMargin
                                      rightMargin: Theme.horizontalPageMargin }
                            text: root.detail ? root.detail.repo_url : ""
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }

                // ---- more from this developer ----
                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    visible: !!(root.detail && root.detail.more_from_developer && root.detail.more_from_developer.length > 0)
                    SectionHeader { text: qsTr("More from this developer") }
                    Repeater {
                        model: root.detail ? root.detail.more_from_developer : []
                        delegate: BackgroundItem {
                            width: parent.width
                            height: Theme.itemSizeSmall
                            onClicked: loadDetail(modelData.id)
                            Label {
                                anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin
                                          verticalCenter: parent.verticalCenter }
                                text: modelData.name
                                color: highlighted ? Theme.highlightColor : Theme.primaryColor
                                font.pixelSize: Theme.fontSizeMedium
                            }
                            Label {
                                anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin
                                          verticalCenter: parent.verticalCenter }
                                text: "›"
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeMedium
                            }
                        }
                    }
                }

                // ---- comments ----
                Column {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    SectionHeader {
                        text: root.detail
                              ? qsTr("Comments") + " (" + (root.detail.comments ? root.detail.comments.length : 0) + ")"
                              : qsTr("Comments")
                    }
                    Repeater {
                        model: root.detail ? root.detail.comments : []
                        delegate: Item {
                            width: parent.width
                            height: cmCol.height + Theme.paddingMedium
                            Column {
                                id: cmCol
                                anchors { left: parent.left; right: parent.right; top: parent.top
                                          leftMargin: Theme.horizontalPageMargin
                                          rightMargin: Theme.horizontalPageMargin
                                          topMargin: Theme.paddingSmall }
                                spacing: Theme.paddingSmall / 2
                                Label {
                                    width: parent.width
                                    text: modelData.body
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeSmall
                                    wrapMode: Text.Wrap
                                }
                                Label {
                                    text: "— " + modelData.username + "  ·  " + (modelData.created_at || "").slice(0, 10)
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeTiny
                                }
                            }
                        }
                    }
                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        visible: !(root.detail && root.detail.comments && root.detail.comments.length > 0)
                        text: qsTr("No comments yet. Visit the website to add one.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    // ============================================================
    //  DEVELOPER PAGE
    // ============================================================
    Item {
        id: devPage
        anchors.fill: parent
        visible: false
        Rectangle { anchors.fill: parent; color: Theme.overlayBackgroundColor }

        SilicaFlickable {
            anchors.fill: parent
            contentHeight: devCol.height + Theme.paddingLarge * 2
            clip: true

            PullDownMenu {
                MenuItem { text: qsTr("Back"); onClicked: devPage.visible = false }
            }

            Column {
                id: devCol
                width: parent.width
                spacing: Theme.paddingMedium
                visible: !!root.devData

                BackgroundItem {
                    width: parent.width
                    height: Theme.itemSizeSmall
                    onClicked: devPage.visible = false
                    Label {
                        anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin
                                  verticalCenter: parent.verticalCenter }
                        text: "‹ " + qsTr("Back")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeMedium
                    }
                }

                // header: avatar + username + role
                Item {
                    width: parent.width
                    height: devHeaderRow.height + Theme.paddingMedium
                    Row {
                        id: devHeaderRow
                        anchors { left: parent.left; right: parent.right; top: parent.top
                                  leftMargin: Theme.horizontalPageMargin
                                  rightMargin: Theme.horizontalPageMargin }
                        spacing: Theme.paddingMedium
                        Rectangle {
                            width: Theme.itemSizeHuge; height: Theme.itemSizeHuge
                            radius: Theme.itemSizeHuge / 2
                            color: Theme.rgba(Theme.highlightColor, 0.20)
                            Label {
                                anchors.centerIn: parent
                                text: root.devData ? root.devData.username.charAt(0).toUpperCase() : "?"
                                color: Theme.highlightColor
                                font.pixelSize: Theme.fontSizeHuge
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.paddingSmall / 2
                            Label {
                                text: root.devData ? ("@" + root.devData.username) : ""
                                color: Theme.highlightColor
                                font.pixelSize: Theme.fontSizeExtraLarge
                                font.family: Theme.fontFamilyHeading
                            }
                            Label {
                                text: root.devData
                                      ? (root.devData.app_count + " " + qsTr("published apps") +
                                         "  ·  " + (root.devData.role || "user"))
                                      : ""
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }
                            Label {
                                visible: !!(root.devData && root.devData.member_since)
                                text: root.devData ? qsTr("Member since") + " " + (root.devData.member_since || "").slice(0, 10) : ""
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeTiny
                            }
                        }
                    }
                }

                SectionHeader { text: qsTr("Apps by this developer") }

                Repeater {
                    model: root.devData ? root.devData.apps : []
                    delegate: BackgroundItem {
                        width: parent.width
                        height: Math.max(Theme.itemSizeMedium, devAppRow.height + Theme.paddingMedium)
                        onClicked: { devPage.visible = false; loadDetail(modelData.id); }

                        Row {
                            id: devAppRow
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                      leftMargin: Theme.horizontalPageMargin
                                      rightMargin: Theme.horizontalPageMargin }
                            spacing: Theme.paddingMedium

                            Item {
                                width: Theme.itemSizeSmall; height: Theme.itemSizeSmall
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.paddingSmall
                                    color: Theme.rgba(Theme.highlightColor, 0.10)
                                }
                                Image {
                                    anchors { fill: parent; margins: 4 }
                                    source: modelData.iconUrl ? (root.storeUrl + modelData.iconUrl) : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: !!modelData.iconUrl
                                }
                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.name.charAt(0).toUpperCase()
                                    color: Theme.highlightColor
                                    font.pixelSize: Theme.fontSizeMedium
                                    visible: !modelData.iconUrl
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - Theme.itemSizeSmall - Theme.paddingMedium
                                spacing: 2
                                Label {
                                    width: parent.width
                                    text: modelData.name
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeMedium
                                    truncationMode: TruncationMode.Fade
                                }
                                Label {
                                    text: modelData.category +
                                          (modelData.current_version ? ("  ·  v" + modelData.current_version) : "") +
                                          (modelData.rating > 0 ? ("  ·  ★ " + Number(modelData.rating).toFixed(1)) : "")
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    //  ABOUT OVERLAY
    // ============================================================
    Item {
        id: aboutOverlay
        anchors.fill: parent
        visible: false
        Rectangle { anchors.fill: parent; color: Theme.rgba(0,0,0,0.85) }
        MouseArea { anchors.fill: parent; onClicked: aboutOverlay.visible = false }
        Column {
            anchors.centerIn: parent
            width: parent.width - 2 * Theme.horizontalPageMargin
            spacing: Theme.paddingMedium
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "⚓"
                font.pixelSize: Theme.fontSizeHuge * 1.5
                color: Theme.highlightColor
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Harpoon Store")
                font.pixelSize: Theme.fontSizeExtraLarge
                color: Theme.highlightColor
                font.family: Theme.fontFamilyHeading
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr("A community app index for Sailfish OS.\nAll apps are published by their respective developers. Install via Harpoon.")
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "harpoon-store.manisak.com"
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }
            BackgroundItem {
                anchors.horizontalCenter: parent.horizontalCenter
                width: closeLbl.width + Theme.paddingLarge * 2
                height: closeLbl.height + Theme.paddingMedium * 2
                onClicked: aboutOverlay.visible = false
                Rectangle { anchors.fill: parent; radius: height/2; color: Theme.highlightColor }
                Label {
                    id: closeLbl
                    anchors.centerIn: parent
                    text: qsTr("Close")
                    color: Theme.overlayBackgroundColor
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                }
            }
        }
    }

    // ============================================================
    //  GLOBAL BUSY INDICATOR (overlay)
    // ============================================================
    BusyIndicator {
        size: BusyIndicatorSize.Large
        running: root.busy && (detailPage.visible || devPage.visible)
        visible: running
        anchors.centerIn: parent
    }
}
