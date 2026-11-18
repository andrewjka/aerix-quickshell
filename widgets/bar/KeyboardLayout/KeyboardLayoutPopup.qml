pragma ComponentBehavior: Bound

import QtQuick
import "../../shared" as Shared
import "../../../core"
import "../../../services"

Shared.BarPopup {
    id: popup
    layerNamespace: "aerix:keyboard-layout"
    preferredWidth: 196
    property int pendingSelectionToken: 0
    readonly property int rowHeight: 32
    // У маленьких экранов оставляем место под ошибку и spring overshoot.
    readonly property int maximumSurfaceHeight: Math.max(0, Math.floor(
        (screen.height - layout.popupTop - layout.shadowMargin - layout.bottomOverflow)
        / (1 + layout.scaleOverflow)))
    readonly property int maximumErrorHeight: Math.max(0,
        maximumSurfaceHeight - 2 * Metrics.spacing - rowHeight - Metrics.popupRowSpacing)
    readonly property int errorHeight: errorLabel.visible
        ? Math.min(errorLabel.implicitHeight, maximumErrorHeight) : 0
    readonly property int availableListHeight: Math.max(0, maximumSurfaceHeight
        - 2 * Metrics.spacing - (errorLabel.visible ? errorHeight + Metrics.spacing : 0))
    readonly property int visibleRows: Math.min(5, KeyboardService.layouts.length,
        Math.max(0, Math.floor((availableListHeight - 2 + Metrics.popupRowSpacing)
            / (rowHeight + Metrics.popupRowSpacing))))
    readonly property int listHeight: visibleRows * rowHeight
        + Math.max(0, visibleRows - 1) * Metrics.popupRowSpacing + 2
    surfaceHeight: listHeight + 2 * Metrics.spacing
        + (errorLabel.visible ? errorHeight + Metrics.spacing : 0)

    function selectLayout(entry) {
        if (!entry || !expanded) return;
        if (entry.index === KeyboardService.activeIndex)
            dismiss();
        else if (KeyboardService.select(entry.index))
            pendingSelectionToken = KeyboardService.pendingSelectionToken;
    }
    onExpandedChanged: {
        if (!expanded) pendingSelectionToken = 0;
    }
    Connections {
        target: KeyboardService
        function onLayoutSelectionResolved(token, confirmed) {
            if (popup.pendingSelectionToken !== token) return;
            popup.pendingSelectionToken = 0;
            if (confirmed) popup.dismiss();
        }
    }

    Shared.SelectionList {
        id: layoutList
        x: Metrics.spacing
        y: Metrics.spacing
        width: parent.width - 2 * Metrics.spacing
        height: popup.listHeight
        rowHeight: popup.rowHeight
        model: KeyboardService.layouts
        detailFor: entry => entry.name
        selectedFor: entry => entry.index === KeyboardService.activeIndex
        interactiveRows: popup.expanded && !KeyboardService.selectionBlocked
        onChosen: entry => popup.selectLayout(entry)
    }
    Text {
        id: errorLabel
        x: Metrics.spacing
        y: layoutList.y + layoutList.height + Metrics.spacing
        width: layoutList.width
        visible: KeyboardService.errorKey.length > 0
        text: I18n.tr(KeyboardService.errorKey)
        color: Theme.accentColor
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        height: popup.errorHeight
        clip: true
    }
}
