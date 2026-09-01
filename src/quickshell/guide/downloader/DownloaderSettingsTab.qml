import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../"
import "../../reusables"
import "../../singletons"

Item {
    id: downloaderTabRoot
    required property var rootObj
    required property int tabIndex

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    property var defaultFormats: [
        { "name": "Best (Video+Audio)", "args": "-f bestvideo+bestaudio/best" },
        { "name": "Audio Only (Best)", "args": "-f bestaudio/best -x" },
        { "name": "Video Only (Best)", "args": "-f bestvideo/best" }
    ]

    property var defaultDownloaderSettings: ({
        "downloadDir": (Quickshell.env("HOME") || "") + "/Downloads",
        "defaultArgs": "",
        "formats": [
            { "name": "Best (Video+Audio)", "args": "-f bestvideo+bestaudio/best" },
            { "name": "Audio Only (Best)", "args": "-f bestaudio/best -x" },
            { "name": "Video Only (Best)", "args": "-f bestvideo/best" }
        ],
        "autoPaste": true,
        "copyAfter": true,
        "autoClose": false
    })

    property var downloaderSettings: {
        let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["downloader"] : undefined;
        if (s !== undefined && s !== null) return s;
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("downloader", downloaderTabRoot.defaultDownloaderSettings);
        }
        return downloaderTabRoot.defaultDownloaderSettings;
    }

    property string currentDownloadDir: downloaderSettings && downloaderSettings.downloadDir !== undefined ? downloaderSettings.downloadDir : ((Quickshell.env("HOME") || "") + "/Downloads")
    property string currentDefaultArgs: downloaderSettings && downloaderSettings.defaultArgs !== undefined ? downloaderSettings.defaultArgs : ""
    property var currentFormats: (downloaderSettings && Array.isArray(downloaderSettings.formats) && downloaderSettings.formats.length > 0)
        ? downloaderSettings.formats
        : defaultFormats
    property bool currentAutoPaste: downloaderSettings && downloaderSettings.autoPaste !== undefined ? downloaderSettings.autoPaste : true
    property bool currentCopyAfter: downloaderSettings && downloaderSettings.copyAfter !== undefined ? downloaderSettings.copyAfter : true
    property bool currentAutoClose: downloaderSettings && downloaderSettings.autoClose !== undefined ? downloaderSettings.autoClose : false
    function tr(key, fallback) {
        if (typeof I18n === "undefined" || typeof I18n.t !== "function") return fallback;
        let res = I18n.t(key);
        return (!res || res === key) ? fallback : res;
    }

    ListModel {
        id: formatsListModel
    }

    function syncFormatsModel(formatsArray) {
        let arr = (formatsArray && Array.isArray(formatsArray) && formatsArray.length > 0)
            ? formatsArray
            : defaultFormats;

        if (formatsListModel.count !== arr.length) {
            formatsListModel.clear();
            for (let i = 0; i < arr.length; i++) {
                formatsListModel.append({
                    "name": arr[i].name || "",
                    "args": arr[i].args || ""
                });
            }
            return;
        }

        for (let i = 0; i < arr.length; i++) {
            let cur = formatsListModel.get(i);
            let n = arr[i].name || "";
            let a = arr[i].args || "";
            if (cur.name !== n) formatsListModel.setProperty(i, "name", n);
            if (cur.args !== a) formatsListModel.setProperty(i, "args", a);
        }
    }

    function syncSettings() {
        let s = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("downloader", downloaderTabRoot.defaultDownloaderSettings)
            : downloaderTabRoot.defaultDownloaderSettings;
        downloaderTabRoot.downloaderSettings = s;
        downloaderTabRoot.currentDownloadDir = s.downloadDir !== undefined ? s.downloadDir : ((Quickshell.env("HOME") || "") + "/Downloads");
        downloaderTabRoot.currentDefaultArgs = s.defaultArgs !== undefined ? s.defaultArgs : "";
        downloaderTabRoot.currentFormats = (s.formats && Array.isArray(s.formats) && s.formats.length > 0) ? s.formats : downloaderTabRoot.defaultFormats;
        downloaderTabRoot.syncFormatsModel(downloaderTabRoot.currentFormats);
        downloaderTabRoot.currentAutoPaste = s.autoPaste !== undefined ? s.autoPaste : true;
        downloaderTabRoot.currentCopyAfter = s.copyAfter !== undefined ? s.copyAfter : true;
        downloaderTabRoot.currentAutoClose = s.autoClose !== undefined ? s.autoClose : false;

        if (downloadDirInput && downloadDirInput.text !== downloaderTabRoot.currentDownloadDir) {
            downloadDirInput.text = downloaderTabRoot.currentDownloadDir;
        }
        if (defaultArgsInput && defaultArgsInput.text !== downloaderTabRoot.currentDefaultArgs) {
            defaultArgsInput.text = downloaderTabRoot.currentDefaultArgs;
        }
    }

    function updateDownloaderSetting(key, value) {
        let current = JSON.parse(JSON.stringify(Config.getSetting("downloader", defaultDownloaderSettings) || defaultDownloaderSettings));
        current[key] = value;
        Config.setSetting("downloader", current);
        downloaderTabRoot.downloaderSettings = current;
    }

    function addFormat() {
        let newName = "Format " + (formatsListModel.count + 1);
        formatsListModel.append({
            "name": newName,
            "args": ""
        });
        saveFormatsFromModel();
    }

    function removeFormat(idx) {
        if (idx >= 0 && idx < formatsListModel.count && formatsListModel.count > 1) {
            formatsListModel.remove(idx, 1);
            saveFormatsFromModel();
        }
    }

    function moveFormat(idx, delta) {
        let targetIdx = idx + delta;
        if (idx >= 0 && idx < formatsListModel.count && targetIdx >= 0 && targetIdx < formatsListModel.count) {
            formatsListModel.move(idx, targetIdx, 1);
            saveFormatsFromModel();
        }
    }

    function updateFormatAt(idx, field, val, immediate) {
        if (idx >= 0 && idx < formatsListModel.count) {
            formatsListModel.setProperty(idx, field, val);
            if (immediate) {
                saveFormatsFromModel();
            } else {
                downloaderTabRoot.triggerDebounced(function() {
                    saveFormatsFromModel();
                });
            }
        }
    }

    function saveFormatsFromModel() {
        let list = [];
        for (let i = 0; i < formatsListModel.count; i++) {
            let item = formatsListModel.get(i);
            list.push({
                "name": item.name || "",
                "args": item.args || ""
            });
        }
        downloaderTabRoot.currentFormats = list;
        downloaderTabRoot.updateDownloaderSetting("formats", list);
    }

    Timer {
        id: debounceTimer
        interval: 150
        repeat: false
        property var pendingCallback: null
        onTriggered: {
            if (pendingCallback) {
                pendingCallback();
                pendingCallback = null;
            }
        }
    }

    function triggerDebounced(cb) {
        debounceTimer.pendingCallback = cb;
        debounceTimer.restart();
    }

    onVisibleChanged: {
        if (visible) {
            syncSettings();
        }
    }

    Component.onCompleted: {
        syncSettings();
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            downloaderTabRoot.syncSettings();
        }
    }

    FilePicker {
        id: dirPicker
        rootObj: downloaderTabRoot.rootObj
        titleText: downloaderTabRoot.tr("guide.downloader.pick_dir", "Select Download Directory")
        places: [
            { name: typeof I18n !== "undefined" ? I18n.t("guide.file_picker.places.home", "Home") : "Home", icon: "󰋜", path: "file://" + (Quickshell.env("HOME") || "") },
            { name: typeof I18n !== "undefined" ? I18n.t("guide.file_picker.places.downloads", "Downloads") : "Downloads", icon: "󰇚", path: "file://" + (Quickshell.env("HOME") || "") + "/Downloads" },
            { name: typeof I18n !== "undefined" ? I18n.t("guide.file_picker.places.videos", "Videos") : "Videos", icon: "󰕧", path: "file://" + (Quickshell.env("HOME") || "") + "/Videos" },
            { name: typeof I18n !== "undefined" ? I18n.t("guide.file_picker.places.music", "Music") : "Music", icon: "󰎈", path: "file://" + (Quickshell.env("HOME") || "") + "/Music" }
        ]
        onFileSelected: function(filePath, fileName) {
            let dirPath = filePath;
            if (dirPath.startsWith("file://")) dirPath = dirPath.substring(7);
            downloaderTabRoot.currentDownloadDir = dirPath;
            downloaderTabRoot.updateDownloaderSetting("downloadDir", dirPath);
            if (downloadDirInput) downloadDirInput.text = dirPath;
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(4)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: 0

            // 1. Download Folder Row
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rowDirLayout.implicitHeight + rootObj.s(18)
                color: "transparent"

                RowLayout {
                    id: rowDirLayout
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(12)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(16)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(2)
                        Text {
                            text: downloaderTabRoot.tr("guide.downloader.dir.title", "Download Directory")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            text: downloaderTabRoot.tr("guide.downloader.dir.desc", "Folder where downloaded files will be stored")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: rootObj.s(8)

                        Input {
                            id: downloadDirInput
                            implicitWidth: rootObj.s(240)
                            implicitHeight: rootObj.s(32)
                            text: downloaderTabRoot.currentDownloadDir
                            placeholderText: "~/Downloads"
                            fontPixelSize: rootObj.s(11)
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            cornerRadius: ThemeBackend.borderRadius
                            onTextEdited: function(newText) {
                                downloaderTabRoot.currentDownloadDir = newText;
                                downloaderTabRoot.triggerDebounced(function() {
                                    downloaderTabRoot.updateDownloaderSetting("downloadDir", newText);
                                });
                            }
                            onAccepted: function(finalText) {
                                downloaderTabRoot.currentDownloadDir = finalText;
                                downloaderTabRoot.updateDownloaderSetting("downloadDir", finalText);
                            }
                        }

                        IconButton {
                            implicitWidth: rootObj.s(32)
                            implicitHeight: rootObj.s(32)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰉋"
                            iconFontSize: rootObj.s(14)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            onClicked: {
                                dirPicker.openWithOptionalPath(downloaderTabRoot.currentDownloadDir);
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(ThemeBackend.surface1, 0.2)
                Layout.topMargin: rootObj.s(5)
                Layout.bottomMargin: rootObj.s(5)
            }

            // 2. Default Arguments Row
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rowArgsLayout.implicitHeight + rootObj.s(18)
                color: "transparent"

                RowLayout {
                    id: rowArgsLayout
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(12)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(16)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(2)
                        Text {
                            text: downloaderTabRoot.tr("guide.downloader.args.title", "Default yt-dlp Arguments")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            text: downloaderTabRoot.tr("guide.downloader.args.desc", "Custom flags passed to yt-dlp by default")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
                    }

                    Input {
                        id: defaultArgsInput
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(280)
                        implicitHeight: rootObj.s(32)
                        text: downloaderTabRoot.currentDefaultArgs
                        placeholderText: "e.g. --embed-subs --add-metadata"
                        fontPixelSize: rootObj.s(11)
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        cornerRadius: ThemeBackend.borderRadius
                        onTextEdited: function(newText) {
                            downloaderTabRoot.currentDefaultArgs = newText;
                            downloaderTabRoot.triggerDebounced(function() {
                                downloaderTabRoot.updateDownloaderSetting("defaultArgs", newText);
                            });
                        }
                        onAccepted: function(finalText) {
                            downloaderTabRoot.currentDefaultArgs = finalText;
                            downloaderTabRoot.updateDownloaderSetting("defaultArgs", finalText);
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(ThemeBackend.surface1, 0.2)
                Layout.topMargin: rootObj.s(5)
                Layout.bottomMargin: rootObj.s(5)
            }

            // 3. Format Presets Header Row
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rowPresetsHeaderLayout.implicitHeight + rootObj.s(18)
                color: "transparent"

                RowLayout {
                    id: rowPresetsHeaderLayout
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(12)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(16)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(2)
                        Text {
                            text: downloaderTabRoot.tr("guide.downloader.formats.title", "Quality Presets")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            text: downloaderTabRoot.tr("guide.downloader.formats.desc", "Custom format names and yt-dlp arguments. Top preset is used by default")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
                    }

                    ClickButton {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        buttonText: downloaderTabRoot.tr("guide.downloader.formats.add", "Add Format")
                        buttonIcon: "󰐕"
                        iconFontSize: rootObj.s(13)
                        textFontSize: rootObj.s(11)
                        cornerRadius: ThemeBackend.borderRadius
                        accentColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        implicitHeight: rootObj.s(32)
                        onClicked: {
                            downloaderTabRoot.addFormat();
                        }
                    }
                }
            }

            // Presets Cards List
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: rootObj.s(12)
                Layout.rightMargin: rootObj.s(12)
                Layout.bottomMargin: rootObj.s(8)
                spacing: rootObj.s(8)

                Repeater {
                    model: formatsListModel

                    Rectangle {
                        id: presetCard
                        required property string name
                        required property string args
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: cardInnerCol.implicitHeight + rootObj.s(16)
                        radius: ThemeBackend.borderRadius
                        color: Qt.alpha(ThemeBackend.surface0, 0.45)
                        border.width: 1
                        border.color: index === 0 ? Qt.alpha(ThemeBackend.mauve, 0.4) : Qt.alpha(ThemeBackend.surface1, 0.35)

                        ColumnLayout {
                            id: cardInnerCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: rootObj.s(8)
                            spacing: rootObj.s(6)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: rootObj.s(8)

                                 Rectangle {
                                     visible: presetCard.index === 0
                                     Layout.preferredHeight: rootObj.s(24)
                                     implicitWidth: badgeRow.implicitWidth + rootObj.s(12)
                                     radius: rootObj.s(6)
                                     color: Qt.alpha(ThemeBackend.mauve, 0.15)
                                     border.width: 1
                                     border.color: Qt.alpha(ThemeBackend.mauve, 0.4)

                                     RowLayout {
                                         id: badgeRow
                                         anchors.centerIn: parent
                                         spacing: rootObj.s(4)
                                         Text {
                                             text: "󰄬"
                                             font.family: "Iosevka Nerd Font"
                                             font.pixelSize: rootObj.s(11)
                                             color: ThemeBackend.mauve
                                         }
                                         Text {
                                             text: downloaderTabRoot.tr("guide.downloader.formats.default_badge", "Default")
                                             font.family: ThemeBackend.fontFamily
                                             font.pixelSize: rootObj.s(10.5)
                                             font.weight: Font.Bold
                                             color: ThemeBackend.mauve
                                         }
                                     }
                                 }

                                 Input {
                                     id: nameInput
                                     Layout.fillWidth: true
                                     implicitHeight: rootObj.s(32)
                                     text: presetCard.name
                                     placeholderText: downloaderTabRoot.tr("guide.downloader.formats.name_placeholder", "Format name (e.g. Best 1080p)")
                                     fontPixelSize: rootObj.s(11)
                                     accentColor: ThemeBackend.mauve
                                     baseColor: ThemeBackend.surface0
                                     borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                                     textColor: ThemeBackend.text
                                     subTextColor: ThemeBackend.subtext0
                                     cornerRadius: ThemeBackend.borderRadius
                                     onTextEdited: function(newText) {
                                         downloaderTabRoot.updateFormatAt(presetCard.index, "name", newText);
                                     }
                                     onAccepted: function(finalText) {
                                         downloaderTabRoot.updateFormatAt(presetCard.index, "name", finalText, true);
                                     }
                                 }

                                 IconButton {
                                     implicitWidth: rootObj.s(32)
                                     implicitHeight: rootObj.s(32)
                                     cornerRadius: ThemeBackend.borderRadius
                                     buttonIcon: "󰅃"
                                     iconFontSize: rootObj.s(16)
                                     accentColor: ThemeBackend.surface0
                                     textColor: presetCard.index > 0 ? ThemeBackend.text : ThemeBackend.subtext0
                                     enabled: presetCard.index > 0
                                     opacity: presetCard.index > 0 ? 1.0 : 0.4
                                     onClicked: {
                                         downloaderTabRoot.moveFormat(presetCard.index, -1);
                                     }
                                 }

                                 IconButton {
                                     implicitWidth: rootObj.s(32)
                                     implicitHeight: rootObj.s(32)
                                     cornerRadius: ThemeBackend.borderRadius
                                     buttonIcon: "󰅀"
                                     iconFontSize: rootObj.s(16)
                                     accentColor: ThemeBackend.surface0
                                     textColor: presetCard.index < formatsListModel.count - 1 ? ThemeBackend.text : ThemeBackend.subtext0
                                     enabled: presetCard.index < formatsListModel.count - 1
                                     opacity: presetCard.index < formatsListModel.count - 1 ? 1.0 : 0.4
                                     onClicked: {
                                         downloaderTabRoot.moveFormat(presetCard.index, 1);
                                     }
                                 }
                                 IconButton {
                                     implicitWidth: rootObj.s(32)
                                     implicitHeight: rootObj.s(32)
                                     cornerRadius: ThemeBackend.borderRadius
                                     buttonIcon: "󰅖"
                                     iconFontSize: rootObj.s(14)
                                     accentColor: Qt.alpha(ThemeBackend.red, 0.15)
                                     textColor: isHoveredOrHighlighted ? Qt.lighter(ThemeBackend.red, 1.2) : ThemeBackend.red
                                     enabled: formatsListModel.count > 1
                                     opacity: formatsListModel.count > 1 ? 1.0 : 0.4
                                     onClicked: {
                                         downloaderTabRoot.removeFormat(presetCard.index);
                                     }
                                 }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: rootObj.s(8)

                                Input {
                                    id: argsInput
                                    Layout.fillWidth: true
                                    implicitHeight: rootObj.s(32)
                                    text: presetCard.args
                                    placeholderText: downloaderTabRoot.tr("guide.downloader.formats.args_placeholder", "yt-dlp arguments (e.g. -f bestvideo+bestaudio/best)")
                                    fontPixelSize: rootObj.s(11)
                                    accentColor: ThemeBackend.mauve
                                    baseColor: ThemeBackend.surface0
                                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                                    textColor: ThemeBackend.text
                                    subTextColor: ThemeBackend.subtext0
                                    cornerRadius: ThemeBackend.borderRadius
                                    onTextEdited: function(newText) {
                                        downloaderTabRoot.updateFormatAt(presetCard.index, "args", newText);
                                    }
                                    onAccepted: function(finalText) {
                                        downloaderTabRoot.updateFormatAt(presetCard.index, "args", finalText, true);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(ThemeBackend.surface1, 0.2)
                Layout.topMargin: rootObj.s(5)
                Layout.bottomMargin: rootObj.s(5)
            }
            // 3. Auto Paste URL Toggle
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rowAutoPasteLayout.implicitHeight + rootObj.s(18)
                color: "transparent"

                RowLayout {
                    id: rowAutoPasteLayout
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(12)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(16)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(2)
                        Text {
                            text: downloaderTabRoot.tr("guide.downloader.autopaste.title", "Auto-paste URL")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            text: downloaderTabRoot.tr("guide.downloader.autopaste.desc", "Automatically paste clipboard URL when opening Downloader")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: downloaderTabRoot.currentAutoPaste
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            downloaderTabRoot.currentAutoPaste = c;
                            downloaderTabRoot.updateDownloaderSetting("autoPaste", c);
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(ThemeBackend.surface1, 0.2)
                Layout.topMargin: rootObj.s(5)
                Layout.bottomMargin: rootObj.s(5)
            }

            // 4. Copy to Clipboard After Download
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rowCopyAfterLayout.implicitHeight + rootObj.s(18)
                color: "transparent"

                RowLayout {
                    id: rowCopyAfterLayout
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(12)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(16)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(2)
                        Text {
                            text: downloaderTabRoot.tr("guide.downloader.copyafter.title", "Copy File to Clipboard")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            text: downloaderTabRoot.tr("guide.downloader.copyafter.desc", "Automatically copy downloaded file to clipboard upon completion")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: downloaderTabRoot.currentCopyAfter
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            downloaderTabRoot.currentCopyAfter = c;
                            downloaderTabRoot.updateDownloaderSetting("copyAfter", c);
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(ThemeBackend.surface1, 0.2)
                Layout.topMargin: rootObj.s(5)
                Layout.bottomMargin: rootObj.s(5)
            }

            // 5. Auto Close Window
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rowAutoCloseLayout.implicitHeight + rootObj.s(18)
                color: "transparent"

                RowLayout {
                    id: rowAutoCloseLayout
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(12)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(16)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(2)
                        Text {
                            text: downloaderTabRoot.tr("guide.downloader.autoclose.title", "Auto-close window")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            text: downloaderTabRoot.tr("guide.downloader.autoclose.desc", "Automatically close Downloader when download begins")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: downloaderTabRoot.currentAutoClose
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            downloaderTabRoot.currentAutoClose = c;
                            downloaderTabRoot.updateDownloaderSetting("autoClose", c);
                        }
                    }
                }
            }
        }
    }
}
