import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../"
import "../reusables"

PanelWindow {
    id: downloaderWindow

    screen: DownloaderController.screen

    WlrLayershell.namespace: "qs-downloader"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: downloaderWindow.isVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    Region { id: emptyRegion }
    mask: (downloaderWindow.isVisible || container.animProgress > 0.001) ? null : emptyRegion
    HyprlandFocusGrab {
        id: focusGrab
        windows: [ downloaderWindow ]
        active: downloaderWindow.isVisible
        onCleared: DownloaderController.hide()
    }
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) {
        return (typeof Scaler !== "undefined" && Scaler.s) ? Scaler.s(val) : val;
    }

    function closeDownloader() {
        DownloaderController.hide();
    }

    property bool isVisible: DownloaderController.isVisible
    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            DownloaderController.hide();
            downloaderWindow.configRevision++;
            downloaderWindow.syncSettings();
        }
    }

    property var defaultFormats: [
        { "name": "Best (Video+Audio)", "args": "-f bestvideo+bestaudio/best" },
        { "name": "Audio Only (Best)", "args": "-f bestaudio/best -x" },
        { "name": "Video Only (Best)", "args": "-f bestvideo/best" }
    ]

    property var defaultDirectories: [
        { "name": "Downloads", "path": "~/Downloads" },
        { "name": "Videos", "path": "~/Videos" },
        { "name": "Music", "path": "~/Music" }
    ]

    property var defaultDownloaderSettings: ({
        "downloadDir": (Quickshell.env("HOME") || "") + "/Downloads",
        "directories": [
            { "name": "Downloads", "path": "~/Downloads" },
            { "name": "Videos", "path": "~/Videos" },
            { "name": "Music", "path": "~/Music" }
        ],
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
        let dummy = configRevision;
        let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["downloader"] : undefined;
        if (s !== undefined && s !== null) return s;
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("downloader", downloaderWindow.defaultDownloaderSettings);
        }
        return downloaderWindow.defaultDownloaderSettings;
    }

    property string currentDownloadDir: downloaderSettings && downloaderSettings.downloadDir !== undefined ? downloaderSettings.downloadDir : ((Quickshell.env("HOME") || "") + "/Downloads")
    property var currentDirectories: {
        let s = downloaderSettings;
        if (s && Array.isArray(s.directories) && s.directories.length > 0) {
            return s.directories;
        }
        let fallbackPath = (s && s.downloadDir !== undefined) ? s.downloadDir : "~/Downloads";
        if (fallbackPath !== "~/Downloads") {
            let name = fallbackPath.replace(/^~\/?/, "").split("/").filter(Boolean).pop() || "Folder";
            return [
                { "name": name, "path": fallbackPath },
                { "name": "Downloads", "path": "~/Downloads" },
                { "name": "Videos", "path": "~/Videos" },
                { "name": "Music", "path": "~/Music" }
            ];
        }
        return defaultDirectories;
    }
    property string currentDefaultArgs: downloaderSettings && downloaderSettings.defaultArgs !== undefined ? downloaderSettings.defaultArgs : ""
    property var currentFormats: (downloaderSettings && Array.isArray(downloaderSettings.formats) && downloaderSettings.formats.length > 0)
        ? downloaderSettings.formats
        : defaultFormats
    property bool autoPasteActive: downloaderSettings && downloaderSettings.autoPaste !== undefined ? downloaderSettings.autoPaste : true
    property bool copyAfterActive: downloaderSettings && downloaderSettings.copyAfter !== undefined ? downloaderSettings.copyAfter : true
    property bool autoCloseActive: downloaderSettings && downloaderSettings.autoClose !== undefined ? downloaderSettings.autoClose : false

    function resolvePath(p) {
        if (!p) return (Quickshell.env("HOME") || "") + "/Downloads";
        let str = p.trim();
        let home = Quickshell.env("HOME") || "";
        if (str === "~") return home;
        if (str.startsWith("~/")) return home + str.substring(1);
        return str;
    }
    function parseArgs(str) {
        if (!str) return [];
        let args = [];
        let cur = "";
        let inDouble = false;
        let inSingle = false;
        let escaped = false;
        for (let i = 0; i < str.length; i++) {
            let c = str[i];
            if (escaped) {
                cur += c;
                escaped = false;
            } else if (c === "\\") {
                escaped = true;
            } else if (c === '"' && !inSingle) {
                inDouble = !inDouble;
            } else if (c === "'" && !inDouble) {
                inSingle = !inSingle;
            } else if ((c === ' ' || c === '\t' || c === '\n') && !inDouble && !inSingle) {
                if (cur.length > 0) {
                    args.push(cur);
                    cur = "";
                }
            } else {
                cur += c;
            }
        }
        if (cur.length > 0) {
            args.push(cur);
        }
        return args;
    }

    function syncSettings() {
        let s = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("downloader", downloaderWindow.defaultDownloaderSettings)
            : downloaderWindow.defaultDownloaderSettings;
        downloaderWindow.currentDownloadDir = s.downloadDir !== undefined ? s.downloadDir : ((Quickshell.env("HOME") || "") + "/Downloads");
        if (s.directories && Array.isArray(s.directories) && s.directories.length > 0) {
            downloaderWindow.currentDirectories = s.directories;
        } else {
            let fallbackPath = downloaderWindow.currentDownloadDir || "~/Downloads";
            if (fallbackPath !== "~/Downloads") {
                let name = fallbackPath.replace(/^~\/?/, "").split("/").filter(Boolean).pop() || "Folder";
                downloaderWindow.currentDirectories = [
                    { "name": name, "path": fallbackPath },
                    { "name": "Downloads", "path": "~/Downloads" },
                    { "name": "Videos", "path": "~/Videos" },
                    { "name": "Music", "path": "~/Music" }
                ];
            } else {
                downloaderWindow.currentDirectories = downloaderWindow.defaultDirectories;
            }
        }
        downloaderWindow.currentDefaultArgs = s.defaultArgs !== undefined ? s.defaultArgs : "";
        downloaderWindow.currentFormats = (s.formats && Array.isArray(s.formats) && s.formats.length > 0) ? s.formats : downloaderWindow.defaultFormats;
        downloaderWindow.autoPasteActive = s.autoPaste !== undefined ? s.autoPaste : true;
        downloaderWindow.copyAfterActive = s.copyAfter !== undefined ? s.copyAfter : true;
        downloaderWindow.autoCloseActive = s.autoClose !== undefined ? s.autoClose : false;
    }
    function updateSetting(key, val) {
        let current = JSON.parse(JSON.stringify((typeof Config !== "undefined" && typeof Config.getSetting === "function") ? Config.getSetting("downloader", defaultDownloaderSettings) : defaultDownloaderSettings));
        current[key] = val;
        if (typeof Config !== "undefined" && typeof Config.setSetting === "function") {
            Config.setSetting("downloader", current);
        }
    }

    property var rawBarSettings: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : ({});
    }
    property string barPosition: (rawBarSettings && rawBarSettings.position !== undefined) ? rawBarSettings.position : "top"
    property string attachEdge: {
        if (barPosition === "bottom") return "top";
        if (barPosition === "left") return "right";
        if (barPosition === "right") return "left";
        return "bottom";
    }

    onBarPositionChanged: {
        DownloaderController.hide();
    }

    property bool isSideAttached: attachEdge === "left" || attachEdge === "right"

    property real cornerRadius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 2 : Math.min(32, 32 - 16 * Math.exp(-(ThemeBackend.borderRadius - 16) / 12))
    property real outerCornerRadius: cornerRadius

    property real baseWindowWidth: isSideAttached ? Math.round(s(640)) : Math.round(s(680))
    property real baseWindowHeight: isSideAttached ? Math.round(s(240)) : Math.round(s(228))

    visible: isVisible || container.animProgress > 0.001

    // Download state
    property string status: "idle" // "idle" | "downloading" | "finished" | "error"
    property real progressPercent: 0.0
    property string statusMessage: ""
    property var logLines: []
    property string downloadedFilePath: ""

    function grabInputFocus() {
        urlInput.forceActiveFocus();
        if (typeof urlInput.forceInputFocus === "function") {
            urlInput.forceInputFocus();
        }
    }
    function isLikelyUrl(str) {
        if (!str) return false;
        let s = str.trim();
        if (s.length < 4 || s.indexOf(" ") !== -1 || s.indexOf("\n") !== -1 || s.indexOf("\r") !== -1 || s.indexOf("\t") !== -1) {
            return false;
        }
        if (/^https?:\/\/[^\s]+$/i.test(s)) {
            return true;
        }
        if (/^www\.[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]+)+[^\s]*$/i.test(s)) {
            return true;
        }
        return false;
    }

    Process {
        id: pasteCheckProc
        running: false
        command: ["wl-paste", "--no-newline"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = (this.text || "").trim();
                if (downloaderWindow.isLikelyUrl(txt)) {
                    if (txt.match(/^www\./i)) {
                        txt = "https://" + txt;
                    }
                    urlInput.text = txt;
                }
            }
        }
    }

    Process {
        id: ytDlpProc
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                downloaderWindow.handleOutputLine(line);
            }
        }
        stderr: SplitParser {
            onRead: function(line) {
                downloaderWindow.handleOutputLine(line);
            }
        }
        onExited: function(exitCode, exitStatus) {
            downloaderWindow.handleProcessExited(exitCode);
        }
    }

    function handleOutputLine(rawLine) {
        let line = (rawLine || "").trim();
        if (line === "") return;

        let logs = downloaderWindow.logLines.slice();
        logs.push(line);
        if (logs.length > 100) logs.shift();
        downloaderWindow.logLines = logs;
        DownloaderController.logLines = logs;

        let pctMatch = line.match(/\[download\]\s+([\d\.]+)%/i);
        if (pctMatch) {
            let pct = parseFloat(pctMatch[1]);
            if (!isNaN(pct)) {
                downloaderWindow.progressPercent = Math.min(100.0, Math.max(0.0, pct));
                DownloaderController.progressPercent = downloaderWindow.progressPercent;
            }
            downloaderWindow.statusMessage = line;
            DownloaderController.statusMessage = line;
        } else if (line.startsWith("[") || line.startsWith("ERROR:")) {
            downloaderWindow.statusMessage = line;
            DownloaderController.statusMessage = line;
        } else if (line.startsWith("/") && line.indexOf("\n") === -1) {
            downloaderWindow.downloadedFilePath = line;
            DownloaderController.downloadedFilePath = line;
        }
    }

    function handleProcessExited(exitCode) {
        let appName = (typeof I18n !== "undefined" && typeof I18n.t === "function") ? I18n.t("downloader.notification.app_name", "Downloader") : "Downloader";

        if (exitCode === 0) {
            downloaderWindow.status = "finished";
            downloaderWindow.progressPercent = 100.0;
            downloaderWindow.statusMessage = "Download completed successfully!";

            DownloaderController.status = "finished";
            DownloaderController.progressPercent = 100.0;
            DownloaderController.statusMessage = "Download completed successfully!";
            DownloaderController.downloadedFilePath = downloaderWindow.downloadedFilePath;

            let fp = downloaderWindow.downloadedFilePath;
            let fileName = fp ? fp.split("/").pop() : "";

            if (downloaderWindow.copyAfterActive && fp !== "") {
                Quickshell.execDetached(["bash", "-c", `wl-copy -t text/uri-list "file://$(realpath '${fp}')" 2>/dev/null || wl-copy < '${fp}' 2>/dev/null`]);
            }
            if (typeof Sounds !== "undefined") Sounds.playSfx("system/success.wav");

            let notifTitle = (typeof I18n !== "undefined" && typeof I18n.t === "function") ? I18n.t("downloader.notification.complete", "Download Complete") : "Download Complete";
            let notifBody = "";
            let copiedText = (typeof I18n !== "undefined" && typeof I18n.t === "function") ? I18n.t("downloader.notification.copied", "Copied to clipboard") : "Copied to clipboard";

            if (fileName !== "") {
                if (downloaderWindow.copyAfterActive) {
                    notifBody = fileName + "\n" + copiedText;
                } else {
                    notifBody = fileName;
                }
            } else if (downloaderWindow.copyAfterActive) {
                notifBody = copiedText;
            }

            Quickshell.execDetached([
                "notify-send",
                "-a", appName,
                "-i", "folder-download",
                notifTitle,
                notifBody
            ]);
        } else {
            downloaderWindow.status = "error";
            downloaderWindow.statusMessage = "Download failed (Exit code " + exitCode + ")";

            DownloaderController.status = "error";
            DownloaderController.statusMessage = downloaderWindow.statusMessage;
            if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/inputfield/error.wav");

            let errTitle = (typeof I18n !== "undefined" && typeof I18n.t === "function") ? I18n.t("downloader.notification.failed", "Download Failed") : "Download Failed";
            Quickshell.execDetached([
                "notify-send",
                "-a", appName,
                "-u", "critical",
                "-i", "dialog-error",
                errTitle,
                downloaderWindow.statusMessage
            ]);
        }
    }

    function startDownload() {
        let rawUrl = (urlInput.text || "").trim();
        if (rawUrl === "") {
            if (typeof urlInput.triggerShake === "function") urlInput.triggerShake();
            return;
        }

        if (ytDlpProc.running) {
            return;
        }

        downloaderWindow.status = "downloading";
        downloaderWindow.progressPercent = 0.0;
        downloaderWindow.statusMessage = "Starting download...";
        downloaderWindow.logLines = [];
        downloaderWindow.downloadedFilePath = "";

        DownloaderController.status = "downloading";
        DownloaderController.progressPercent = 0.0;
        DownloaderController.statusMessage = "Starting download...";
        DownloaderController.logLines = [];
        DownloaderController.downloadedFilePath = "";
        DownloaderController.lastUrl = rawUrl;

        let chosenDir = "";
        let customDirIndex = dirDropdown.options.length - 1;
        if (dirDropdown.currentIndex >= 0 && dirDropdown.currentIndex < downloaderWindow.currentDirectories.length) {
            let selectedDir = downloaderWindow.currentDirectories[dirDropdown.currentIndex];
            chosenDir = selectedDir ? (selectedDir.path || "") : "";
        } else if (dirDropdown.currentIndex === customDirIndex) {
            chosenDir = (customDirInput.text || "").trim();
        }
        let dlDir = downloaderWindow.resolvePath(chosenDir);

        let fmtArgs = [];
        let customIndex = formatDropdown.options.length - 1;
        if (formatDropdown.currentIndex >= 0 && formatDropdown.currentIndex < downloaderWindow.currentFormats.length) {
            let selectedPreset = downloaderWindow.currentFormats[formatDropdown.currentIndex];
            let presetArgs = selectedPreset ? (selectedPreset.args || "") : "";
            if (presetArgs.trim() !== "") {
                let parsed = downloaderWindow.parseArgs(presetArgs);
                for (let i = 0; i < parsed.length; i++) fmtArgs.push(parsed[i]);
            }
        } else if (formatDropdown.currentIndex === customIndex) {
            let customFmt = (customFormatInput.text || "").trim();
            if (customFmt !== "") {
                if (customFmt.startsWith("-")) {
                    let parsed = downloaderWindow.parseArgs(customFmt);
                    for (let i = 0; i < parsed.length; i++) fmtArgs.push(parsed[i]);
                } else {
                    fmtArgs = ["-f", customFmt];
                }
            }
        }

        let cmd = [
            "yt-dlp",
            "--newline",
            "--no-colors",
            "--print", "after_move:filepath",
            "-P", dlDir,
            "-o", "%(title)s.%(ext)s"
        ];

        if (downloaderWindow.currentDefaultArgs && downloaderWindow.currentDefaultArgs.trim() !== "") {
            let extra = downloaderWindow.parseArgs(downloaderWindow.currentDefaultArgs);
            for (let i = 0; i < extra.length; i++) cmd.push(extra[i]);
        }

        for (let i = 0; i < fmtArgs.length; i++) {
            cmd.push(fmtArgs[i]);
        }
        cmd.push(rawUrl);

        ytDlpProc.command = cmd;
        ytDlpProc.running = true;
        if (typeof Sounds !== "undefined") Sounds.playSfx("system/quick_click.wav");

        if (downloaderWindow.autoCloseActive) {
            downloaderWindow.closeDownloader();
        }
    }

    Timer {
        id: focusTimer
        interval: 30
        repeat: false
        onTriggered: downloaderWindow.grabInputFocus()
    }

    Timer {
        id: focusRetryTimer
        interval: 120
        repeat: false
        onTriggered: downloaderWindow.grabInputFocus()
    }

    Timer {
        id: focusFinalTimer
        interval: 250
        repeat: false
        onTriggered: downloaderWindow.grabInputFocus()
    }

    onIsVisibleChanged: {
        if (isVisible) {
            urlInput.clear();
            syncSettings();
            formatDropdown.currentIndex = 0;
            dirDropdown.currentIndex = 0;
            if (customFormatInput) customFormatInput.clear();
            if (customDirInput) customDirInput.clear();
            if (downloaderWindow.status !== "downloading") {
                downloaderWindow.status = "idle";
                downloaderWindow.progressPercent = 0.0;
                downloaderWindow.statusMessage = "";
                downloaderWindow.logLines = [];
                downloaderWindow.downloadedFilePath = "";
            }
            if (downloaderWindow.autoPasteActive) {
                pasteCheckProc.running = false;
                pasteCheckProc.running = true;
            }
            downloaderWindow.grabInputFocus();
            focusTimer.restart();
            focusRetryTimer.restart();
            focusFinalTimer.restart();
        } else {
            focusTimer.stop();
            focusRetryTimer.stop();
            focusFinalTimer.stop();
            if (formatDropdown.isOpen) formatDropdown.closePopup();
            if (dirDropdown.isOpen) dirDropdown.closePopup();
        }
    }
    Component.onCompleted: {
        syncSettings();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: closeDownloader()
    }

    Item {
        id: maskBoundary
        x: container.x - downloaderWindow.outerCornerRadius
        y: container.y - downloaderWindow.outerCornerRadius
        width: container.width + (downloaderWindow.outerCornerRadius * 2)
        height: container.height + (downloaderWindow.outerCornerRadius * 2)
    }

    Item {
        id: container

        property real animProgress: downloaderWindow.isVisible ? 1.0 : 0.0
        Behavior on animProgress {
            NumberAnimation {
                duration: downloaderWindow.isVisible ? 360 : 260
                easing.type: Easing.OutCubic
            }
        }

        property real dynamicCornerRadius: Math.max(0, Math.min(downloaderWindow.outerCornerRadius, (downloaderWindow.isSideAttached ? width : height)))

        x: {
            if (downloaderWindow.attachEdge === "left") return 0;
            if (downloaderWindow.attachEdge === "right") return downloaderWindow.width - width;
            return Math.floor((downloaderWindow.width - downloaderWindow.baseWindowWidth) / 2);
        }
        y: {
            if (downloaderWindow.attachEdge === "top") return 0;
            if (downloaderWindow.attachEdge === "bottom") return downloaderWindow.height - height;
            return Math.floor((downloaderWindow.height - downloaderWindow.baseWindowHeight) / 2);
        }
        width: downloaderWindow.isSideAttached
               ? (downloaderWindow.baseWindowWidth * animProgress)
               : downloaderWindow.baseWindowWidth
        height: !downloaderWindow.isSideAttached
                ? (downloaderWindow.baseWindowHeight * animProgress)
                : downloaderWindow.baseWindowHeight

        opacity: (downloaderWindow.isVisible || animProgress > 0.001) ? 1.0 : 0.0

        // Corner shapes for inverted border radius
        Shape {
            visible: downloaderWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
            x: -container.dynamicCornerRadius
            y: 0
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: container.dynamicCornerRadius; y: 0 }
                PathLine { x: container.dynamicCornerRadius; y: container.dynamicCornerRadius }
                PathArc {
                    x: 0
                    y: 0
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: downloaderWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
            x: parent.width
            y: 0
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: container.dynamicCornerRadius
                startY: 0
                PathLine { x: 0; y: 0 }
                PathLine { x: 0; y: container.dynamicCornerRadius }
                PathArc {
                    x: container.dynamicCornerRadius
                    y: 0
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Shape {
            visible: downloaderWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
            x: -container.dynamicCornerRadius
            y: parent.height - container.dynamicCornerRadius
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: container.dynamicCornerRadius
                PathLine { x: container.dynamicCornerRadius; y: container.dynamicCornerRadius }
                PathLine { x: container.dynamicCornerRadius; y: 0 }
                PathArc {
                    x: 0
                    y: container.dynamicCornerRadius
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Shape {
            visible: downloaderWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
            x: parent.width
            y: parent.height - container.dynamicCornerRadius
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: container.dynamicCornerRadius
                startY: container.dynamicCornerRadius
                PathLine { x: 0; y: container.dynamicCornerRadius }
                PathLine { x: 0; y: 0 }
                PathArc {
                    x: container.dynamicCornerRadius
                    y: container.dynamicCornerRadius
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: downloaderWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
            x: 0
            y: -container.dynamicCornerRadius
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: 0; y: container.dynamicCornerRadius }
                PathLine { x: container.dynamicCornerRadius; y: container.dynamicCornerRadius }
                PathArc {
                    x: 0
                    y: 0
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Shape {
            visible: downloaderWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
            x: 0
            y: parent.height
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: container.dynamicCornerRadius
                PathLine { x: 0; y: 0 }
                PathLine { x: container.dynamicCornerRadius; y: 0 }
                PathArc {
                    x: 0
                    y: container.dynamicCornerRadius
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: downloaderWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
            x: parent.width - container.dynamicCornerRadius
            y: -container.dynamicCornerRadius
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: container.dynamicCornerRadius
                startY: 0
                PathLine { x: container.dynamicCornerRadius; y: container.dynamicCornerRadius }
                PathLine { x: 0; y: container.dynamicCornerRadius }
                PathArc {
                    x: container.dynamicCornerRadius
                    y: 0
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: downloaderWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
            x: parent.width - container.dynamicCornerRadius
            y: parent.height
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: container.dynamicCornerRadius
                startY: container.dynamicCornerRadius
                PathLine { x: container.dynamicCornerRadius; y: 0 }
                PathLine { x: 0; y: 0 }
                PathArc {
                    x: container.dynamicCornerRadius
                    y: container.dynamicCornerRadius
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Rectangle {
            id: bgCard
            anchors.fill: parent
            radius: downloaderWindow.cornerRadius
            color: ThemeBackend.base
            border.width: 0
            border.color: "transparent"
            clip: true

            // Rectangles to fill behind dynamic corner curves
            Rectangle {
                visible: downloaderWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
                x: 0; y: 0; width: container.dynamicCornerRadius; height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }
            Rectangle {
                visible: downloaderWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius; y: 0; width: container.dynamicCornerRadius; height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }
            Rectangle {
                visible: downloaderWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
                x: 0; y: parent.height - container.dynamicCornerRadius; width: container.dynamicCornerRadius; height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }
            Rectangle {
                visible: downloaderWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius; y: parent.height - container.dynamicCornerRadius; width: container.dynamicCornerRadius; height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }
            Rectangle {
                visible: downloaderWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
                x: 0; y: 0; width: container.dynamicCornerRadius; height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }
            Rectangle {
                visible: downloaderWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
                x: 0; y: parent.height - container.dynamicCornerRadius; width: container.dynamicCornerRadius; height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }
            Rectangle {
                visible: downloaderWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius; y: 0; width: container.dynamicCornerRadius; height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }
            Rectangle {
                visible: downloaderWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius; y: parent.height - container.dynamicCornerRadius; width: container.dynamicCornerRadius; height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: downloaderWindow.s(14)
                spacing: downloaderWindow.s(10)

                // 2. URL Input
                RowLayout {
                    Layout.fillWidth: true
                    spacing: downloaderWindow.s(8)

                    Input {
                        id: urlInput
                        focus: true
                        Layout.fillWidth: true
                        Layout.preferredHeight: downloaderWindow.s(36)

                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: Math.min(ThemeBackend.borderRadius, downloaderWindow.s(10))
                        fontPixelSize: downloaderWindow.s(12)
                        charSpacing: 1
                        leadingIcon: "󰌷"

                        placeholderText: "Paste video/audio URL (or press Enter to download)..."
                        showClearButton: true

                        Keys.onReturnPressed: function(event) {
                            downloaderWindow.startDownload();
                            event.accepted = true;
                        }
                        Keys.onEscapePressed: function(event) {
                            downloaderWindow.closeDownloader();
                            event.accepted = true;
                        }
                    }
                }

                // 3. Presets Row (Format & Output Directory)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: downloaderWindow.s(8)

                    Dropdown {
                        id: formatDropdown
                        Layout.fillWidth: true
                        Layout.preferredHeight: downloaderWindow.s(32)
                        options: {
                            let list = [];
                            let fmts = downloaderWindow.currentFormats;
                            for (let i = 0; i < fmts.length; i++) {
                                list.push(fmts[i].name || ("Format " + (i + 1)));
                            }
                            list.push("Custom Format");
                            return list;
                        }
                        currentIndex: 0
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        dropdownColor: ThemeBackend.surface0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        fontPixelSize: downloaderWindow.s(11)
                    }

                    Input {
                        id: customFormatInput
                        visible: formatDropdown.currentIndex === (formatDropdown.options.length - 1)
                        Layout.preferredWidth: downloaderWindow.s(120)
                        Layout.preferredHeight: downloaderWindow.s(32)
                        placeholderText: "e.g. 137+140"
                        fontPixelSize: downloaderWindow.s(11)
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        cornerRadius: Math.min(ThemeBackend.borderRadius, downloaderWindow.s(10))
                        Keys.onReturnPressed: function(event) {
                            downloaderWindow.startDownload();
                            event.accepted = true;
                        }
                    }

                    Dropdown {
                        id: dirDropdown
                        Layout.fillWidth: true
                        Layout.preferredHeight: downloaderWindow.s(32)
                        options: {
                            let list = [];
                            let dirs = downloaderWindow.currentDirectories;
                            for (let i = 0; i < dirs.length; i++) {
                                list.push(dirs[i].name || ("Directory " + (i + 1)));
                            }
                            list.push("Custom Path");
                            return list;
                        }
                        currentIndex: 0
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        dropdownColor: ThemeBackend.surface0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        fontPixelSize: downloaderWindow.s(11)
                    }

                    Input {
                        id: customDirInput
                        visible: dirDropdown.currentIndex === (dirDropdown.options.length - 1)
                        Layout.preferredWidth: downloaderWindow.s(130)
                        Layout.preferredHeight: downloaderWindow.s(32)
                        placeholderText: "~/Downloads"
                        fontPixelSize: downloaderWindow.s(11)
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        cornerRadius: Math.min(ThemeBackend.borderRadius, downloaderWindow.s(10))
                        Keys.onReturnPressed: function(event) {
                            downloaderWindow.startDownload();
                            event.accepted = true;
                        }
                    }
                }

                // 4. Options Row (Toggles)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: downloaderWindow.s(8)

                    Toggle {
                        id: autoPasteToggle
                        Layout.preferredWidth: implicitWidth
                        buttonIcon: "󰅌"
                        buttonText: "Auto-paste"
                        horizontalPadding: downloaderWindow.s(8)
                        checked: downloaderWindow.autoPasteActive
                        onToggled: function(c) {
                            downloaderWindow.autoPasteActive = c;
                            downloaderWindow.updateSetting("autoPaste", c);
                        }
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        textFontSize: downloaderWindow.s(10.5)
                        iconFontSize: downloaderWindow.s(12)
                    }

                    Toggle {
                        id: copyAfterToggle
                        Layout.preferredWidth: implicitWidth
                        buttonIcon: "󰆏"
                        buttonText: "Copy File"
                        horizontalPadding: downloaderWindow.s(8)
                        checked: downloaderWindow.copyAfterActive
                        onToggled: function(c) {
                            downloaderWindow.copyAfterActive = c;
                            downloaderWindow.updateSetting("copyAfter", c);
                        }
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        textFontSize: downloaderWindow.s(10.5)
                        iconFontSize: downloaderWindow.s(12)
                    }

                    Toggle {
                        id: autoCloseToggle
                        Layout.preferredWidth: implicitWidth
                        buttonIcon: "󰅖"
                        buttonText: "Auto-close"
                        horizontalPadding: downloaderWindow.s(8)
                        checked: downloaderWindow.autoCloseActive
                        onToggled: function(c) {
                            downloaderWindow.autoCloseActive = c;
                            downloaderWindow.updateSetting("autoClose", c);
                        }
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        textFontSize: downloaderWindow.s(10.5)
                        iconFontSize: downloaderWindow.s(12)
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
                // 4. Progress Bar row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: downloaderWindow.s(8)
                    visible: downloaderWindow.status === "downloading" || (downloaderWindow.progressPercent > 0 && downloaderWindow.status !== "idle")

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: downloaderWindow.s(6)
                        radius: height / 2
                        color: ThemeBackend.surface1

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, Math.min(parent.width, parent.width * (downloaderWindow.progressPercent / 100.0)))
                            radius: height / 2
                            color: downloaderWindow.status === "finished" ? ThemeBackend.green : (downloaderWindow.status === "error" ? ThemeBackend.red : ThemeBackend.mauve)

                            Behavior on width {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Text {
                        text: Math.round(downloaderWindow.progressPercent) + "%"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: downloaderWindow.s(10)
                        font.weight: Font.Bold
                        color: downloaderWindow.status === "finished" ? ThemeBackend.green : (downloaderWindow.status === "error" ? ThemeBackend.red : ThemeBackend.mauve)
                    }
                }
                // 5. Download Button
                FillButton {
                    id: downloadBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: downloaderWindow.s(38)
                    cornerRadius: Math.min(ThemeBackend.borderRadius, downloaderWindow.s(10))
                    textFontSize: downloaderWindow.s(13)
                    iconFontSize: downloaderWindow.s(16)
                    fillDuration: 400

                    buttonText: {
                        if (downloaderWindow.status === "downloading") {
                            return downloaderWindow.progressPercent > 0
                                ? ("Downloading (" + Math.round(downloaderWindow.progressPercent) + "%)")
                                : "Downloading...";
                        }
                        if (downloaderWindow.status === "finished") return "Download Complete";
                        if (downloaderWindow.status === "error") return "Download Failed";
                        return "Download";
                    }

                    buttonIcon: {
                        if (downloaderWindow.status === "downloading") return "󰑮";
                        if (downloaderWindow.status === "finished") return "󰄬";
                        if (downloaderWindow.status === "error") return "󰅖";
                        return "󰇚";
                    }

                    accentColor: {
                        if (downloaderWindow.status === "downloading") return ThemeBackend.blue;
                        if (downloaderWindow.status === "finished") return ThemeBackend.green;
                        if (downloaderWindow.status === "error") return ThemeBackend.red;
                        return ThemeBackend.mauve;
                    }
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    textColor: ThemeBackend.text

                    onTriggered: {
                        downloaderWindow.startDownload();
                    }
                }
            }
        }
    }
}
