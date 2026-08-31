import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../"
import "../reusables"

PanelWindow {
    id: ttsWindow

    screen: TtsController.screen

    WlrLayershell.namespace: "qs-tts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ttsWindow.isVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    visible: ttsWindow.isVisible || container.animProgress > 0.001

    Region { id: emptyRegion }
    mask: (ttsWindow.isVisible || container.animProgress > 0.001) ? null : emptyRegion
    HyprlandFocusGrab {
        id: focusGrab
        windows: [ ttsWindow ]
        active: ttsWindow.isVisible
        onCleared: TtsController.hide()
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

    function tr(key, fallback) {
        if (typeof I18n === "undefined" || typeof I18n.t !== "function") return fallback;
        let res = I18n.t(key);
        return (!res || res === key) ? fallback : res;
    }

    function grabInputFocus() {
        ttsInput.forceActiveFocus();
        if (typeof ttsInput.forceInputFocus === "function") {
            ttsInput.forceInputFocus();
        }
    }

    Connections {
        target: (typeof I18n !== "undefined") ? I18n : null
        function onLanguageChanged() {
            ttsInput.placeholderText = ttsWindow.tr("tts.placeholder", "Type text to speak...");
            speakBtn.buttonText = ttsWindow.tr("tts.speak", "Speak");
        }
    }
    function triggerSpeak() {
        let txt = (ttsInput.text || "").trim();
        if (txt === "") {
            if (typeof ttsInput.triggerShake === "function") {
                ttsInput.triggerShake();
            }
            return;
        }

        TtsController.hide();
        ttsInput.clear();

        let dir = (typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : "";
        let scriptPath = dir ? (dir + "/scripts/tts.sh") : (Quickshell.env("HOME") + "/serpantinum/src/scripts/tts.sh");

        Quickshell.execDetached(["bash", scriptPath, txt]);
    }

    property bool isVisible: TtsController.isVisible

    onIsVisibleChanged: {
        if (isVisible) {
            ttsInput.clear();
            ttsInput.placeholderText = ttsWindow.tr("tts.placeholder", "Type text to speak...");
            speakBtn.buttonText = ttsWindow.tr("tts.speak", "Speak");
            ttsWindow.grabInputFocus();
            focusTimer.restart();
        } else {
            focusTimer.stop();
        }
    }

    Timer {
        id: focusTimer
        interval: 30
        repeat: false
        onTriggered: ttsWindow.grabInputFocus()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: TtsController.hide()
    }

    Rectangle {
        id: container
        anchors.centerIn: parent
        width: Math.min(ttsWindow.s(520), ttsWindow.width - ttsWindow.s(32))
        height: ttsWindow.s(56)
        radius: ThemeBackend.clampedBorderRadius
        color: ThemeBackend.base
        border.color: ThemeBackend.surface1
        border.width: 1

        property real animProgress: ttsWindow.isVisible ? 1.0 : 0.0
        Behavior on animProgress {
            NumberAnimation {
                duration: ttsWindow.isVisible ? 200 : 150
                easing.type: Easing.OutCubic
            }
        }

        opacity: animProgress
        scale: 0.95 + (0.05 * animProgress)

        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: ttsWindow.s(8)
            spacing: ttsWindow.s(8)

            Input {
                id: ttsInput
                Layout.fillWidth: true
                Layout.fillHeight: true

                placeholderText: ttsWindow.tr("tts.placeholder", "Type text to speak...")
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: ThemeBackend.surface1
                cornerRadius: Math.max(4, ThemeBackend.clampedBorderRadius - 2)
                fontPixelSize: ttsWindow.s(13)

                onAccepted: function(finalText) {
                    ttsWindow.triggerSpeak();
                }

                Keys.onEscapePressed: function(event) {
                    TtsController.hide();
                    event.accepted = true;
                }

                Keys.onReturnPressed: function(event) {
                    ttsWindow.triggerSpeak();
                    event.accepted = true;
                }
            }

            ClickButton {
                id: speakBtn
                Layout.preferredWidth: ttsWindow.s(84)
                Layout.fillHeight: true
                buttonText: ttsWindow.tr("tts.speak", "Speak")
                buttonIcon: "󰕾"
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.base
                cornerRadius: Math.max(4, ThemeBackend.clampedBorderRadius - 2)
                textFontSize: ttsWindow.s(12)

                onClicked: ttsWindow.triggerSpeak()
            }
        }
    }

    Keys.onEscapePressed: function(event) {
        TtsController.hide();
        event.accepted = true;
    }
}
