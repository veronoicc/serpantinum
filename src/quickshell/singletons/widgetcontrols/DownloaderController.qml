pragma Singleton
import QtQuick
import Quickshell
import "../../"
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: controller

    property bool isVisible: false
    property var screen: null
    property var previousToplevel: null
    property string previousAddress: ""


    // In-memory download state and logs
    property string status: "idle" // "idle" | "downloading" | "finished" | "error"
    property real progressPercent: 0.0
    property string statusMessage: ""
    property var logLines: []
    property string downloadedFilePath: ""
    property string lastUrl: ""

    function clearLogs() {
        logLines = [];
        status = "idle";
        statusMessage = "";
        progressPercent = 0.0;
        downloadedFilePath = "";
        lastUrl = "";
    }
    Timer {
        id: refocusTimer
        interval: 35
        repeat: false
        onTriggered: controller.doRefocus()
    }

    function doRefocus() {
        if (controller.previousToplevel) {
            try {
                controller.previousToplevel.activate();
            } catch(e) {}
        }
        controller.previousToplevel = null;
        controller.previousAddress = "";
    }

    function getFocusedScreen() {
        try {
            if (typeof Hyprland !== "undefined") {
                let monName = "";
                if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
                    monName = Hyprland.focusedMonitor.name;
                } else if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor && Hyprland.focusedWorkspace.monitor.name) {
                    monName = Hyprland.focusedWorkspace.monitor.name;
                }

                if (monName && typeof Quickshell !== "undefined" && Quickshell.screens) {
                    for (let i = 0; i < Quickshell.screens.length; i++) {
                        if (Quickshell.screens[i].name === monName) {
                            return Quickshell.screens[i];
                        }
                    }
                }
            }
        } catch (e) {}
        return null;
    }

    function getScreen(scr) {
        if (scr === undefined || scr === null) return getFocusedScreen();
        if (typeof scr === "object") {
            if (typeof Quickshell !== "undefined" && Quickshell.screens) {
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i] === scr || Quickshell.screens[i].name === scr.name) {
                        return Quickshell.screens[i];
                    }
                }
            }
            return scr;
        }
        if (typeof Quickshell !== "undefined" && Quickshell.screens) {
            if (typeof scr === "number") {
                if (scr >= 0 && scr < Quickshell.screens.length) {
                    return Quickshell.screens[scr];
                }
            }
            if (typeof scr === "string") {
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === scr) {
                        return Quickshell.screens[i];
                    }
                }
            }
        }
        return getFocusedScreen() || scr;
    }

    function show(scr) {
        controller.previousToplevel = (typeof ToplevelManager !== "undefined") ? ToplevelManager.activeToplevel : null;
        let addr = "";
        try {
            if (typeof Hyprland !== "undefined" && Hyprland.activeToplevel) {
                let ht = Hyprland.activeToplevel.HyprlandToplevel;
                if (ht && ht.address) {
                    addr = ht.address;
                }
            }
        } catch(e) {}
        controller.previousAddress = addr;

        let target = getScreen(scr);
        if (target !== null && target !== undefined) {
            controller.screen = target;
        } else {
            let focused = getFocusedScreen();
            if (focused !== null && focused !== undefined) {
                controller.screen = focused;
            }
        }
        controller.isVisible = true;
    }

    function hide() {
        controller.isVisible = false;
        refocusTimer.restart();
    }

    function toggle(scr) {
        let target = getScreen(scr);
        let resolved = target !== null && target !== undefined ? target : getFocusedScreen();

        if (controller.isVisible) {
            if (resolved !== undefined && resolved !== null && controller.screen !== resolved) {
                controller.screen = resolved;
            } else {
                hide();
            }
        } else {
            show(resolved);
        }
    }
}
