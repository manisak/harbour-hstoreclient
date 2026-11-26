import QtQuick 2.2
import Sailfish.Silica 1.0

// Harpoon Store — native Sailfish OS Silica client.
// Runs under `sailfish-qml harbour-hstoreclient` (Rectangle root, no ApplicationWindow).
// v0.4.0 — Jolla-Store-inspired redesign with horizontal swipe navigation.

Rectangle {
    id: root
    color: Theme.rgba(Theme.overlayBackgroundColor, 1.0)
    anchors.fill: parent

    property string storeUrl: "https://harpoon-store.manisak.com"
    property string statusMsg: ""
    property bool   busy: false

    // currently open detail-app (null = closed)
    property var    detail: null
    // currently open developer page (null = closed)
    property var    devData: null
    // currently open category list (null = closed)
    property var    catData: null

    // search filter
    property string searchText: ""

    // Cover mode
    readonly property bool appActive: Qt.application.state === Qt.ApplicationActive

    // data models
    ListModel { id: masterModel }   // all apps
    ListModel { id: newModel }      // newest apps (by id desc)
    ListModel { id: bestModel }     // best rated apps
    ListModel { id: catModel }      // categories
    ListModel { id: viewModel }     // filtered/search results
    ListModel { id: catAppsModel }  // apps in selected category

    // current horizontal page index (0=home, 1=categories, 2=search)
    property int currentPage: 0

    // ------------------------- helpers -------------------------

    function harpoonLink(repoUrl) {
        if (!repoUrl) return "";
        var link = "harpoon://add?url=" + encodeURIComponent(repoUrl);
        var host = "";
        try { host = repoUrl.replace(/^https?:\/\//, "").split("/")[0].toLowerCase(); } catch (e) {}
        if (host === "github.com" || host === "www.github.com") return link;
        if (host === "codeberg.org" || host === "codefloe.com") return link;
        if (host === "gitlab.com" || host === "www.gitlab.com") return link;
        if (/^(git|code|forge|gitea|forgejo|gitlab|git\.)/.test(host) ||
            host.indexOf("gitea") !== -1 || host.indexOf("forgejo") !== -1) {
            if (host.indexOf("gitlab") !== -1) return link + "&source=GitLab";
            return link + "&source=Forgejo";
        }
        return link;
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
                newModel.clear();
                bestModel.clear();
                for (var i = 0; i < o.apps.length; ++i) {
                    var a = o.apps[i];
                    var entry = {
                        appId: a.id, name: a.name, description: a.description || "",
                        repoUrl: a.repo_url, appCategory: a.category || "General",
                        cat_slug: a.cat_slug || "",
                        iconUrl: a.iconUrl,
                        fullIconUrl: a.iconUrl ? (root.storeUrl + a.iconUrl) : "",
                        appRating: a.rating > 0 ? a.rating : 0,
                        ratings: a.ratings || 0, currentVersion: a.current_version || "",
                        owner: a.owner || ""
                    };
                    masterModel.append(entry);
                    // newest: first 6 (server returns by id desc = newest first)
                    if (i < 6) newModel.append(entry);
                    // best: rating > 0, sorted by rating desc
                    if (entry.appRating > 0) bestModel.append(entry);
                }
                // sort bestModel by rating desc
                for (var k = 0; k < bestModel.count; ++k) {
                    for (var l = k + 1; l < bestModel.count; ++l) {
                        if (bestModel.get(l).appRating > bestModel.get(k).appRating) {
                            var tmp = bestModel.get(k);
                            bestModel.set(k, bestModel.get(l));
                            bestModel.set(l, tmp);
                        }
                    }
                }
                // keep only top 6
                while (bestModel.count > 6) bestModel.remove(bestModel.count - 1);
                refreshView();
            } catch (e) { statusMsg = "Parse error: " + e; }
        };
        x.send();
    }

    function refreshView() {
        viewModel.clear();
        var needle = searchText.toLowerCase();
        for (var i = 0; i < masterModel.count; ++i) {
            var a = masterModel.get(i);
            if (needle.length) {
                var hay = (a.name + " " + a.description + " " + a.owner).toLowerCase();
                if (hay.indexOf(needle) === -1) continue;
            }
            viewModel.append({
                appId: a.appId, name: a.name, description: a.description,
                repoUrl: a.repoUrl, appCategory: a.appCategory, cat_slug: a.cat_slug,
                iconUrl: a.iconUrl, fullIconUrl: a.fullIconUrl,
                appRating: a.appRating, ratings: a.ratings,
                currentVersion: a.currentVersion, owner: a.owner
            });
        }
    }

    function loadCategory(slug, name) {
        busy = true;
        catAppsModel.clear();
        var x = new XMLHttpRequest();
        x.open("GET", storeUrl + "/api/apps.json" + (slug ? "?cat=" + slug : ""), true);
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            busy = false;
            if (x.status !== 200) { statusMsg = "Cat apps HTTP " + x.status; return; }
            try {
                var o = JSON.parse(x.responseText);
                for (var i = 0; i < o.apps.length; ++i) {
                    var a = o.apps[i];
                    catAppsModel.append({
                        appId: a.id, name: a.name, description: a.description || "",
                        repoUrl: a.repo_url, appCategory: a.category || "General",
                        cat_slug: a.cat_slug || "",
                        iconUrl: a.iconUrl,
                        fullIconUrl: a.iconUrl ? (root.storeUrl + a.iconUrl) : "",
                        appRating: a.rating > 0 ? a.rating : 0,
                        ratings: a.ratings || 0, currentVersion: a.current_version || "",
                        owner: a.owner || ""
                    });
                }
                catData = { slug: slug, name: name };
            } catch (e) { statusMsg = "Cat apps parse: " + e; }
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
            } catch (e) { statusMsg = "Dev parse: " + e; }
        };
        x.send();
    }

    function goHome() {
        detail = null;
        devData = null;
        catData = null;
        currentPage = 0;
    }

    function goBack() {
        if (detail) { detail = null; return; }
        if (devData) { devData = null; return; }
        if (catData) { catData = null; return; }
        if (currentPage > 0) currentPage = 0;
    }

    Component.onCompleted: { loadCats(); loadApps(); }

    // ============================================================
    //  HORIZONTAL PAGE NAVIGATION (SlideshowView-like)
    // ============================================================
    ListView {
        id: pageView
        anchors.fill: parent
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: width
        currentIndex: root.currentPage
        onCurrentIndexChanged: root.currentPage = currentIndex
        interactive: !root.detail && !root.devData && !root.catData  // disable when overlay open
        model: 3

        delegate: Item {
            width: pageView.width
            height: pageView.height

            // ============ PAGE 0: HOME ============
            Loader {
                active: index === 0
                anchors.fill: parent
                sourceComponent: Component {
                    SilicaFlickable {
                        id: homeFlick
                        contentHeight: homeCol.height + Theme.paddingLarge * 2
                        clip: true

                        PullDownMenu {
                            MenuItem { text: qsTr("About Harpoon Store"); onClicked: aboutOverlay.visible = true }
                            MenuItem { text: qsTr("Reload");              onClicked: { loadCats(); loadApps(); } }
                        }

                        PushUpMenu {
                            visible: homeFlick.contentHeight > homeFlick.height
                            MenuItem { text: qsTr("Back to top"); onClicked: homeFlick.scrollToTop() }
                        }

                        Column {
                            id: homeCol
                            width: parent.width
                            spacing: Theme.paddingMedium

                            // hero header
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

                            // ---- section: New apps ----
                            SectionHeader {
                                text: qsTr("New apps")
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { loadCategory("", qsTr("All apps")); }
                                }
                                Label {
                                    anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin
                                              verticalCenter: parent.verticalCenter }
                                    text: "›"
                                    color: Theme.highlightColor
                                    font.pixelSize: Theme.fontSizeLarge
                                }
                            }
                            GridView {
                                width: parent.width
                                height: Math.ceil(newModel.count / 2) * (Theme.itemSizeHuge + Theme.paddingLarge)
                                cellWidth: width / 2
                                cellHeight: Theme.itemSizeHuge + Theme.paddingLarge
                                model: newModel
                                interactive: false
                                delegate: BackgroundItem {
                                    width: cellWidth
                                    height: cellHeight
                                    onClicked: loadDetail(model.appId)
                                    Column {
                                        anchors { centerIn: parent; margins: Theme.paddingSmall }
                                        spacing: Theme.paddingSmall
                                        width: parent.width - Theme.paddingMedium * 2
                                        Item {
                                            width: Theme.itemSizeMedium; height: Theme.itemSizeMedium
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: Theme.paddingSmall
                                                color: Theme.rgba(Theme.highlightColor, 0.10)
                                            }
                                            Image {
                                                anchors { fill: parent; margins: 4 }
                                                width: parent.width - 8; height: parent.height - 8
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: false; cache: false; smooth: true
                                                sourceSize.width: Theme.itemSizeMedium
                                                sourceSize.height: Theme.itemSizeMedium
                                                source: model.fullIconUrl
                                            }
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.name.charAt(0).toUpperCase()
                                                color: Theme.highlightColor
                                                font.pixelSize: Theme.fontSizeLarge
                                                visible: parent.children[1].status !== Image.Ready
                                            }
                                        }
                                        Label {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: model.name
                                            color: Theme.primaryColor
                                            font.pixelSize: Theme.fontSizeExtraSmall
                                            maximumLineCount: 2
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                        }
                                        Label {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: "@" + model.owner
                                            color: Theme.secondaryColor
                                            font.pixelSize: Theme.fontSizeTiny
                                            truncationMode: TruncationMode.Fade
                                        }
                                    }
                                }
                            }

                            // ---- section: Best apps ----
                            SectionHeader {
                                text: qsTr("Best apps")
                                visible: bestModel.count > 0
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { /* TODO: best apps page */ }
                                }
                                Label {
                                    anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin
                                              verticalCenter: parent.verticalCenter }
                                    text: "›"
                                    color: Theme.highlightColor
                                    font.pixelSize: Theme.fontSizeLarge
                                }
                            }
                            GridView {
                                width: parent.width
                                height: Math.ceil(bestModel.count / 2) * (Theme.itemSizeHuge + Theme.paddingLarge)
                                cellWidth: width / 2
                                cellHeight: Theme.itemSizeHuge + Theme.paddingLarge
                                model: bestModel
                                interactive: false
                                visible: bestModel.count > 0
                                delegate: BackgroundItem {
                                    width: cellWidth
                                    height: cellHeight
                                    onClicked: loadDetail(model.appId)
                                    Column {
                                        anchors { centerIn: parent; margins: Theme.paddingSmall }
                                        spacing: Theme.paddingSmall
                                        width: parent.width - Theme.paddingMedium * 2
                                        Item {
                                            width: Theme.itemSizeMedium; height: Theme.itemSizeMedium
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: Theme.paddingSmall
                                                color: Theme.rgba(Theme.highlightColor, 0.10)
                                            }
                                            Image {
                                                anchors { fill: parent; margins: 4 }
                                                width: parent.width - 8; height: parent.height - 8
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: false; cache: false; smooth: true
                                                sourceSize.width: Theme.itemSizeMedium
                                                sourceSize.height: Theme.itemSizeMedium
                                                source: model.fullIconUrl
                                            }
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.name.charAt(0).toUpperCase()
                                                color: Theme.highlightColor
                                                font.pixelSize: Theme.fontSizeLarge
                                                visible: parent.children[1].status !== Image.Ready
                                            }
                                        }
                                        Label {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: model.name
                                            color: Theme.primaryColor
                                            font.pixelSize: Theme.fontSizeExtraSmall
                                            maximumLineCount: 2
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                        }
                                        Label {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: "★ " + Number(model.appRating).toFixed(1) + "  ·  @" + model.owner
                                            color: Theme.highlightColor
                                            font.pixelSize: Theme.fontSizeTiny
                                            truncationMode: TruncationMode.Fade
                                        }
                                    }
                                }
                            }

                            // ---- section: Categories ----
                            SectionHeader {
                                text: qsTr("Categories")
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.currentPage = 1
                                }
                                Label {
                                    anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin
                                              verticalCenter: parent.verticalCenter }
                                    text: "›"
                                    color: Theme.highlightColor
                                    font.pixelSize: Theme.fontSizeLarge
                                }
                            }
                            Repeater {
                                model: catModel
                                delegate: BackgroundItem {
                                    width: homeCol.width
                                    height: Theme.itemSizeSmall
                                    onClicked: { loadCategory(model.slug, model.name); }
                                    Label {
                                        anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin
                                                  verticalCenter: parent.verticalCenter }
                                        text: model.name
                                        color: highlighted ? Theme.highlightColor : Theme.primaryColor
                                        font.pixelSize: Theme.fontSizeMedium
                                    }
                                    Label {
                                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin
                                                  verticalCenter: parent.verticalCenter }
                                        text: model.count + " " + qsTr("apps") + "  ›"
                                        color: Theme.secondaryColor
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ============ PAGE 1: CATEGORIES ============
            Loader {
                active: index === 1
                anchors.fill: parent
                sourceComponent: Component {
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
                            MenuItem { text: qsTr("‹ Back to main"); onClicked: goHome() }
                        }
                        delegate: BackgroundItem {
                            width: ListView.view.width
                            height: Theme.itemSizeSmall
                            onClicked: { loadCategory(model.slug, model.name); }
                            Label {
                                anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin
                                          verticalCenter: parent.verticalCenter }
                                text: model.name
                                color: highlighted ? Theme.highlightColor : Theme.primaryColor
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
            }

            // ============ PAGE 2: SEARCH ============
            Loader {
                active: index === 2
                anchors.fill: parent
                sourceComponent: Component {
                    SilicaFlickable {
                        anchors.fill: parent
                        contentHeight: searchCol.height + Theme.paddingLarge * 2
                        clip: true

                        PullDownMenu {
                            MenuItem { text: qsTr("‹ Back to main"); onClicked: goHome() }
                        }

                        Column {
                            id: searchCol
                            width: parent.width
                            spacing: Theme.paddingMedium

                            Item {
                                width: parent.width
                                height: searchHeader.height + Theme.paddingLarge * 2
                                Column {
                                    id: searchHeader
                                    anchors { left: parent.left; right: parent.right; top: parent.top
                                              leftMargin: Theme.horizontalPageMargin
                                              rightMargin: Theme.horizontalPageMargin
                                              topMargin: Theme.paddingLarge }
                                    spacing: Theme.paddingSmall
                                    Label {
                                        text: qsTr("Search")
                                        font.pixelSize: Theme.fontSizeExtraLarge
                                        font.family: Theme.fontFamilyHeading
                                        color: Theme.highlightColor
                                    }
                                }
                            }

                            SearchField {
                                width: parent.width
                                placeholderText: qsTr("Search apps, developers…")
                                onTextChanged: { root.searchText = text; refreshView(); }
                                EnterKey.onClicked: focus = false
                            }

                            Repeater {
                                model: viewModel
                                delegate: BackgroundItem {
                                    width: searchCol.width
                                    height: Math.max(Theme.itemSizeMedium, searchRow.height + Theme.paddingMedium)
                                    onClicked: loadDetail(model.appId)
                                    Row {
                                        id: searchRow
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
                                                width: parent.width - 8; height: parent.height - 8
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: false; cache: false; smooth: true
                                                sourceSize.width: Theme.itemSizeSmall
                                                sourceSize.height: Theme.itemSizeSmall
                                                source: model.fullIconUrl
                                            }
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.name.charAt(0).toUpperCase()
                                                color: Theme.highlightColor
                                                font.pixelSize: Theme.fontSizeMedium
                                                visible: parent.children[1].status !== Image.Ready
                                            }
                                        }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - Theme.itemSizeSmall - Theme.paddingMedium
                                            spacing: 2
                                            Label {
                                                width: parent.width
                                                text: model.name
                                                color: Theme.primaryColor
                                                font.pixelSize: Theme.fontSizeMedium
                                                truncationMode: TruncationMode.Fade
                                            }
                                            Label {
                                                text: model.appCategory + (model.currentVersion ? "  ·  v" + model.currentVersion : "") + "  ·  @" + model.owner
                                                color: Theme.secondaryColor
                                                font.pixelSize: Theme.fontSizeExtraSmall
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: Theme.itemSizeLarge * 2
                                visible: viewModel.count === 0
                                Label {
                                    anchors.centerIn: parent
                                    text: root.searchText.length > 0 ? qsTr("No apps match your search.") : qsTr("Type to search…")
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    //  OVERLAY: CATEGORY APPS LIST
    // ============================================================
    Item {
        id: catOverlay
        anchors.fill: parent
        visible: !!root.catData
        Rectangle { anchors.fill: parent; color: Theme.overlayBackgroundColor }

        SilicaListView {
            anchors.fill: parent
            model: catAppsModel
            header: Item {
                width: parent.width
                height: Theme.itemSizeLarge
                Label {
                    anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin
                              verticalCenter: parent.verticalCenter }
                    text: root.catData ? root.catData.name : ""
                    font.pixelSize: Theme.fontSizeExtraLarge
                    font.family: Theme.fontFamilyHeading
                    color: Theme.highlightColor
                }
            }
            PullDownMenu {
                MenuItem { text: qsTr("‹ Back to main"); onClicked: goHome() }
            }
            delegate: BackgroundItem {
                width: ListView.view.width
                height: Math.max(Theme.itemSizeMedium, catAppRow.height + Theme.paddingMedium)
                onClicked: loadDetail(model.appId)
                Row {
                    id: catAppRow
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
                            width: parent.width - 8; height: parent.height - 8
                            fillMode: Image.PreserveAspectFit
                            asynchronous: false; cache: false; smooth: true
                            sourceSize.width: Theme.itemSizeSmall
                            sourceSize.height: Theme.itemSizeSmall
                            source: model.fullIconUrl
                        }
                        Label {
                            anchors.centerIn: parent
                            text: model.name.charAt(0).toUpperCase()
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeMedium
                            visible: parent.children[1].status !== Image.Ready
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.itemSizeSmall - Theme.paddingMedium
                        spacing: 2
                        Label {
                            width: parent.width
                            text: model.name
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeMedium
                            truncationMode: TruncationMode.Fade
                        }
                        Label {
                            text: model.appCategory + (model.currentVersion ? "  ·  v" + model.currentVersion : "") + "  ·  @" + model.owner
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    //  OVERLAY: DETAIL PAGE
    // ============================================================
    Item {
        id: detailOverlay
        anchors.fill: parent
        visible: !!root.detail
        Rectangle { anchors.fill: parent; color: Theme.overlayBackgroundColor }

        SilicaFlickable {
            id: detailFlick
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
                    onClicked: if (root.detail) Qt.openUrlExternally(harpoonLink(root.detail.repo_url))
                }
                MenuItem { text: qsTr("‹ Back to main"); onClicked: goHome() }
            }

            PushUpMenu {
                visible: detailFlick.contentHeight > detailFlick.height
                MenuItem { text: qsTr("Back to top"); onClicked: detailFlick.scrollToTop() }
            }

            Column {
                id: detailCol
                width: parent.width
                spacing: Theme.paddingMedium
                visible: !!root.detail

                // hero: icon + name + meta
                Item {
                    width: parent.width
                    height: heroRow.height + Theme.paddingLarge * 2
                    Row {
                        id: heroRow
                        anchors { left: parent.left; right: parent.right; top: parent.top
                                  topMargin: Theme.paddingLarge
                                  leftMargin: Theme.horizontalPageMargin
                                  rightMargin: Theme.horizontalPageMargin }
                        spacing: Theme.paddingMedium
                        Item {
                            width: Theme.itemSizeHuge; height: Theme.itemSizeHuge
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.paddingMedium
                                color: Theme.rgba(Theme.highlightColor, 0.10)
                                border { color: Theme.rgba(Theme.highlightColor, 0.30); width: 1 }
                            }
                            Image {
                                id: detailIcon
                                anchors { fill: parent; margins: Theme.paddingSmall }
                                width: parent.width - Theme.paddingSmall * 2
                                height: parent.height - Theme.paddingSmall * 2
                                fillMode: Image.PreserveAspectFit
                                asynchronous: false; cache: false; smooth: true
                                sourceSize.width: Theme.itemSizeHuge
                                sourceSize.height: Theme.itemSizeHuge
                            }
                            Label {
                                anchors.centerIn: parent
                                text: root.detail ? root.detail.name.charAt(0).toUpperCase() : "?"
                                color: Theme.highlightColor
                                font.pixelSize: Theme.fontSizeHuge
                                visible: detailIcon.status !== Image.Ready
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

                // install CTA
                BackgroundItem {
                    width: parent.width
                    height: installBtn.height + Theme.paddingMedium * 2
                    onClicked: if (root.detail) Qt.openUrlExternally(harpoonLink(root.detail.repo_url))
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

                // developer card
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

                // contributors
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

                // screenshots
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
                                width: parent.width - 4; height: parent.height - 4
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: false; cache: false; smooth: true
                                sourceSize.width: width; sourceSize.height: height
                                Component.onCompleted: { if (modelData) source = root.storeUrl + modelData; }
                            }
                        }
                    }
                }

                // description
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

                // source
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

                // more from this developer
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

                // comments
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
    //  OVERLAY: DEVELOPER PAGE
    // ============================================================
    Item {
        id: devOverlay
        anchors.fill: parent
        visible: !!root.devData
        Rectangle { anchors.fill: parent; color: Theme.overlayBackgroundColor }

        SilicaFlickable {
            anchors.fill: parent
            contentHeight: devCol.height + Theme.paddingLarge * 2
            clip: true

            PullDownMenu {
                MenuItem { text: qsTr("‹ Back to main"); onClicked: goHome() }
            }

            Column {
                id: devCol
                width: parent.width
                spacing: Theme.paddingMedium
                visible: !!root.devData

                Item {
                    width: parent.width
                    height: devHeaderRow.height + Theme.paddingLarge * 2
                    Row {
                        id: devHeaderRow
                        anchors { left: parent.left; right: parent.right; top: parent.top
                                  topMargin: Theme.paddingLarge
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
                        onClicked: { devData = null; loadDetail(modelData.id); }
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
                                    width: parent.width - 8; height: parent.height - 8
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: false; cache: false; smooth: true
                                    sourceSize.width: Theme.itemSizeSmall
                                    sourceSize.height: Theme.itemSizeSmall
                                    source: modelData.iconUrl ? (root.storeUrl + modelData.iconUrl) : ""
                                }
                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.name.charAt(0).toUpperCase()
                                    color: Theme.highlightColor
                                    font.pixelSize: Theme.fontSizeMedium
                                    visible: parent.children[1].status !== Image.Ready
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
        SilicaFlickable {
            anchors.fill: parent
            PullDownMenu {
                MenuItem { text: qsTr("‹ Back to main"); onClicked: goHome() }
            }
        }
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
    //  GLOBAL BUSY INDICATOR
    // ============================================================
    BusyIndicator {
        size: BusyIndicatorSize.Large
        running: root.busy
        visible: running
        anchors.centerIn: parent
    }

    // ============================================================
    //  COVER overlay — shown when minimized
    // ============================================================
    Rectangle {
        id: coverOverlay
        anchors.fill: parent
        visible: !root.appActive
        color: Theme.overlayBackgroundColor
        z: 1000
        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingMedium
            width: parent.width * 0.7
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "⚓"
                font.pixelSize: Theme.fontSizeHuge * 1.6
                color: Theme.highlightColor
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr("Harpoon Store")
                font.pixelSize: Theme.fontSizeExtraLarge
                font.family: Theme.fontFamilyHeading
                color: Theme.highlightColor
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr("Community apps for Sailfish OS")
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.secondaryColor
            }
        }
    }

    // detail icon loader
    onDetailChanged: {
        if (root.detail && root.detail.iconUrl) {
            detailIcon.source = root.storeUrl + root.detail.iconUrl;
        }
    }
}
