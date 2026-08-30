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

    property var defaultDownloaderSettings: ({
        "downloadDir": (Quickshell.env("HOME") || "") + "/Downloads",
        "defaultArgs": "",
        "autoPaste": true,
        "copyAfter": true
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
    property bool currentAutoPaste: downloaderSettings && downloaderSettings.autoPaste !== undefined ? downloaderSettings.autoPaste : true
    property bool currentCopyAfter: downloaderSettings && downloaderSettings.copyAfter !== undefined ? downloaderSettings.copyAfter : true
    function tr(key, fallback) {
        if (typeof I18n === "undefined" || typeof I18n.t !== "function") return fallback;
        let res = I18n.t(key);
        return (!res || res === key) ? fallback : res;
    }

    function syncSettings() {
        let s = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("downloader", downloaderTabRoot.defaultDownloaderSettings)
            : downloaderTabRoot.defaultDownloaderSettings;
        downloaderTabRoot.downloaderSettings = s;
        downloaderTabRoot.currentDownloadDir = s.downloadDir !== undefined ? s.downloadDir : ((Quickshell.env("HOME") || "") + "/Downloads");
        downloaderTabRoot.currentDefaultArgs = s.defaultArgs !== undefined ? s.defaultArgs : "";
        downloaderTabRoot.currentAutoPaste = s.autoPaste !== undefined ? s.autoPaste : true;
        downloaderTabRoot.currentCopyAfter = s.copyAfter !== undefined ? s.copyAfter : true;

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
        }
    }
}
