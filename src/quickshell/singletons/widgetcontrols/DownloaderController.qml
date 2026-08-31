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

    function getScreen(scr) {
        if (scr === undefined || scr === null) return null;
        if (typeof scr === "object") return scr;
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
        return scr;
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
        } else if (scr !== undefined && scr !== null) {
            controller.screen = scr;
        }
        controller.isVisible = true;
    }

    function hide() {
        controller.isVisible = false;
        refocusTimer.restart();
    }

    function toggle(scr) {
        let target = getScreen(scr);
        let resolved = target !== null ? target : scr;

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
