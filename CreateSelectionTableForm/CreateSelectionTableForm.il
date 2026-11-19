;; Selection Table
;;
;; A dockable form for Layout windows that summarizes the current selection.
;; Selected objects are grouped by the values of the columns ticked in the
;; Options dialog, with one table row per unique combination and a count.
;;
;; - Clicking a row highlights its objects.
;; - "select" keeps only the highlighted rows selected, "deSelect" removes them.
;; - The table follows the selection through a poller (see "Selection polling").
;; - Ctrl Shift Q opens the table. All names start with "stbl" to avoid
;;   clashing with other skill files.
;;
;; Global Variable
;;
;; Each column is list(name expression [setupExpression cleanupExpression]).
;; In expression, OBJECT stands for the selected object.
stblColumnDefinitions = list(
    ;; Common
    list("name"             "OBJECT~>name")
    list("type"             "OBJECT~>objType")

    list("library"          "OBJECT~>libName")
    list("cell"             "OBJECT~>cellName")
    list("view"             "OBJECT~>viewName")

    list("via"              "nth(0 OBJECT~>viaHeader~>viaDef~>params)")
    list("ViaSize"          "let((bBox x1 x2 y1 y2) when(OBJECT~>viaHeader~>viaDef~>params bBox = car(OBJECT~>viaHeader~>master~>shapes)~>bBox x1 = xCoord(car(bBox)) y1 = yCoord(car(bBox)) x2 = xCoord(cadr(bBox)) y2 = yCoord(cadr(bBox)) list(x2-x1 y2-y1)))" )
    
    list("netname"          "OBJECT~>net~>name")
    list("layer"            "OBJECT~>layerName")
    list("purpose"          "OBJECT~>purpose")
    list("width"            "OBJECT~>width")

    list("text"             "OBJECT~>owner~>name")

    ;; Optional 3rd / 4th entries are evaluated once per refresh, before and
    ;; after the expression is applied to all selected objects.
    list("area"             "when(OBJECT~>isShape abeLayerFromShapes(list(OBJECT))~>area)"
                            "abeInit(geGetEditCellView())"
                            "abeDone()")
    list("x"                "car(OBJECT~>xy)")
    list("y"                "cadr(OBJECT~>xy)")
    list("bBox"             "OBJECT~>bBox")

    list("color"            "when(OBJECT~>isShape && !OBJECT~>theLabel && OBJECT~>objType != \"textDisplay\" dbGetShapeColor(OBJECT))" )
    list("isLock"           "when(OBJECT~>isShape && !OBJECT~>theLabel && OBJECT~>objType != \"textDisplay\" dbIsShapeColorLocked(OBJECT))" )

    ;; More custom
    ;; DFB cell 
    list("DFB_srcCell"      "when(OBJECT~>master~>superMaster cdfFindParamByName(cdfGetInstCDF(OBJECT) \"srcCell\")~>value)")
    ;; STD marker
    list("STD_marker_net"   "when(OBJECT~>master~>superMaster OBJECT~>conns~>net~>name)")
    list("STD_marker_layer" "when(OBJECT~>master~>superMaster cdfFindParamByName(cdfGetInstCDF(OBJECT) \"Metal_Layer\")~>value)")
    list("STD_marker_high"  "when(OBJECT~>master~>superMaster cdfFindParamByName(cdfGetInstCDF(OBJECT) \"High_Voltage\")~>value)")
    list("STD_marker_low"   "when(OBJECT~>master~>superMaster cdfFindParamByName(cdfGetInstCDF(OBJECT) \"Low_Voltage\")~>value)")
    list("STD_marker_markOnTop" "when(OBJECT~>master~>superMaster cdfFindParamByName(cdfGetInstCDF(OBJECT) \"Mark_As_Top_Level\")~>value)")
)


;; Highlight set holding the objects of the rows picked in the table.
stblHighlightSet = nil

;; Layer-purpose pair used to highlight the rows picked in the table.
;; It must exist in the tech file of the cellview being edited.
stblHighlightLayer = list("y4" "drawing")


;; Options dialog holding the column visibility toggles.
;; Created together with the table form.
stblOptionsForm = nil

;; Build table column definitions from stblColumnDefinitions 
;;
;; Adds
;; - An "id" column at the beginning
;; - Attribute Columns for each configured definition.
;; - A "count" column at the end.
procedure(stblBuildTableColumnDefinitions(columnDefinitions)
    ;; Add identifier column, one column per configured definition,
    ;; and the occurrence count column.
    cons(
        list("id" 0 'left 'string t)
        append(
            mapcar(
                lambda((columnDefinition)
                    list(car(columnDefinition) 70 'left 'string t)
                )
                columnDefinitions
            )
            list(list("count" 50 'left 'int t))
        )
    )
)

;; Build toggle items used to control column visibility.
;;
;; Adds:
;; - A "Select All" toggle.
;; - One toggle for each configured column.
procedure(stblBuildColumnToggleItems(columnDefinitions)
    ;; Select-all option followed by one toggle item per column
    cons(
        list(stringToSymbol("Select All"))
        mapcar(
            lambda((columnDefinition)
                list(stringToSymbol(car(columnDefinition)))
            )
            columnDefinitions
        )
    )
)

;; Build a summary of the current selection for table display.
;;
;; Returns one row per unique attribute combination:
;; (
;;     objectIds
;;     attributeValues...
;;     occurrenceCount
;; )
procedure(stblBuildTableSelectionSummary(columnDefinitions)
    let((
            selectedSet
            remainingColumns
            groupedObjectIds
            groupKey
            objectIds
            summaryRows
        )

        ;; Collect selected objects and resolve each configured attribute once
        selectedSet = when(getCurrentWindow() geGetSelectedSet())

        ;; One list of values per column, aligned with selectedSet.
        ;; Each row's values are taken from the head of every column,
        ;; then every column is advanced, so no nth() lookups are needed.
        remainingColumns = mapcar(
            lambda((columnDefinition)
                stblResolveAttributePath(
                    selectedSet
                    cadr(columnDefinition)
                    caddr(columnDefinition)
                    cadddr(columnDefinition)
                )
            )
            columnDefinitions
        )

        ;; Group object ids by their attribute values
        ;; (key: list of the row's values as strings, value: list of object ids)
        groupedObjectIds = makeTable("groupedObjectIds" nil)

        foreach(objectId selectedSet
            ;; Row key built from the head of every column list
            groupKey = mapcar(
                lambda((column)
                    let((value)
                        value = car(column)
                        if(stringp(value) then value else sprintf(nil "%L" value))
                    )
                )
                remainingColumns
            )
            ;; Advance every column to the next object
            remainingColumns = mapcar('cdr remainingColumns)

            groupedObjectIds[groupKey] = cons(objectId groupedObjectIds[groupKey])
        )

        ;; Build summary rows: (objectIds attributeValues... count)
        summaryRows = nil

        foreach(key groupedObjectIds->?
            objectIds = reverse(groupedObjectIds[key])
            summaryRows = cons(
                cons(objectIds append1(key length(objectIds)))
                summaryRows
            )
        )

        reverse(summaryRows)
    )
)


;; Call evaluator on value, returning nil if the evaluation raises an error.
procedure(stblEvaluateSafely(evaluator value)
    let((result)
        result = errset(funcall(evaluator value))
        when(result car(result))
    )
)

;; Resolve an attribute path against one or more objects.
;;
;; Returns one value per object, in the same order as objects.
;; The path is a string or a list of strings. Each element is applied to the
;; values produced by the previous element (the objects for the first one):
;;
;;     "OBJECT~>net~>name"      ==> evaluate the expression, OBJECT being the
;;                                  current value
;;     "layerName"              ==> dbGet(currentValue "layerName")
;;     '("net" "name")          ==> dbGet(dbGet(object "net") "name")
;;
;; An element containing "OBJECT" is an expression and is evaluated on each
;; current value. Any other element is an attribute name read with dbGet.
;; A value that can not be resolved becomes nil instead of raising an error.
;;
;; setupExpression and cleanupExpression are optional strings evaluated once,
;; before and after the path is applied to all objects.
procedure(stblResolveAttributePath(objects attributePath @optional setupExpression cleanupExpression)
    let((
            currentValues
            evaluator
        )
        currentValues = objects

        if(!listp(attributePath) then
            attributePath = list(attributePath)
        )

        ;; Run the one-time setup (e.g. abeInit) once, not once per object.
        when(objects && setupExpression
            errset(evalstring(setupExpression))
        )

        foreach(pathElement attributePath

            if(rexMatchp("OBJECT" pathElement) then

                ;; Parse the expression once, then call it for every object.
                rexCompile("OBJECT")
                evaluator = evalstring(
                    sprintf(
                        nil
                        "lambda((currentValue) %s)"
                        rexReplace(pathElement "currentValue" 0)
                    )
                )

                ;; A failing expression (e.g. area on a non-shape) gives nil for
                ;; that object instead of aborting the whole refresh.
                currentValues = foreach(mapcar currentValue currentValues
                    stblEvaluateSafely(evaluator currentValue)
                )
            else
                ;; dbGet takes one object, so resolve every current value separately.
                currentValues = foreach(mapcar currentValue currentValues
                    let((result)
                        result = when(currentValue errset(dbGet(currentValue pathElement)))
                        when(result car(result))
                    )
                )
            )
        )

        ;; Always release what the setup acquired (e.g. abeDone).
        when(objects && cleanupExpression
            errset(evalstring(cleanupExpression))
        )

        currentValues
    )
)


;; Create and display the Selection Table form.
;;
;; The form contains:
;; - A report field showing summarized selected-object data.
;; - Buttons for updating, selecting, and deselecting objects.
;; - An options button for configuring visible columns.
;;
;; The report field is initialized using stblColumnDefinitions.
procedure(stblCreateSelectionTableForm()
    let((
            reportField
            refreshButton
            selectButton
            deSelectButton
            gridButtonForm
            gridSelectionTableForm
            autoRefreshToggle
            optionsButton
            searchField
            gridSearchForm
            visibleColumnDefinitions
            ;;stblForm
        )
        

        ;; Create the column configuration dialog used by
        ;; the Options button.
        stblCreateSelectHeaderWindowPopUp()
        
        ;; Main report field displaying grouped selection data
        visibleColumnDefinitions = stblGetVisibleColumnDefinitions(
            stblOptionsForm
        )

        reportField = hiCreateReportField(
            ?name       'reportField
            ?headers    stblBuildTableColumnDefinitions(
                            visibleColumnDefinitions 
                        ) 
            ?choices    stblBuildTableSelectionSummary(
                            visibleColumnDefinitions 
                        )
            ?selectMode    'extended
            ?enableDeselectCB   t
            ?callback   "stblReportFieldCallBack()"
        )
        
        ;; Refresh report data from the current selection.
        refreshButton = hiCreateButton(
            ?name       'refreshButton
            ?buttonText "Refresh"
            ?enabled    nil
            ?callback   "stblRefreshSelectionTableCallBack()"
        )

        ;; Auto-refresh toggle. Ticked: the poller keeps the table up to date and
        ;; Refresh is disabled. Unticked: Refresh is enabled and used manually.
        autoRefreshToggle = hiCreateToggleField(
            ?name           'autoRefreshToggle
            ?choices        list(
                                list(stringToSymbol("autoRefresh"))
                            )
            ?defValue       list(t) 
            ?callback       list(
                                "stblForm~>refreshButton~>enabled = !car(stblForm~>autoRefreshToggle~>value)"                                
                            )
        )

        ;; Select objects corresponding to selected report rows.
        selectButton = hiCreateButton(
            ?name    'selectButton
            ?buttonText "select"
            ?callback   "stblSelectButtonCallBack()"
        )

        ;; Remove objects corresponding to selected report rows from the current selection.
        deSelectButton = hiCreateButton(
            ?name    'deSelectButton
            ?buttonText "deSelect"
            ?callback   "stblDeSelectButtonCallBack()"
        )

        ;; Open the column visibility configuration dialog.
        optionsButton = hiCreateButton(
            ?name    'optionsButton
            ?buttonText "Options"
            ?callback   "hiDisplayForm('stblOptionsForm -1:-1)"
        )

        ;; Close the previously docked Selection table window(s)
        stblCloseDockWindows()
        ;; Layout: button grid, search row, then the table.
        gridButtonForm = hiCreateGridLayout(
            'gridButtonForm
            ?items      list(
                            list(refreshButton 'row 0 'col 0)
                            list(autoRefreshToggle 'row 0 'col 1) 
                            list(selectButton 'row 1 'col 0) 
                            list(deSelectButton 'row 1 'col 1) 
                            list(optionsButton 'row 1 'col 2) 
                        )
        )

        ;; Search box, a regular expression matched against the attribute values.
        searchField = hiCreateStringField(
            ?name           `searchField
            ?prompt         "Search"
            ?defValue       ""
            ?callback       "stblRefreshSelectionTableByKey()"
            ?editable t
        )

        gridSearchForm = hiCreateGridLayout(
            'gridSearchForm
            ?items      list(
                            list(searchField 'row 0 'col 0 'row_span -1)
                        )
        )
        
        gridSelectionTableForm = hiCreateGridLayout(
            'gridSelectionTableForm
            ?items      list(
                            list(reportField 'row 0 'col 0 'row_span -1 )
                        )
        )

        stblForm = hiCreateLayoutForm(
            'stblForm
            "Selection table"
            hiCreateVerticalBoxLayout(
                'vbox
                ?items list(
                    gridButtonForm
                    gridSearchForm
                    gridSelectionTableForm
                )
            )
            ?minSize 600:200
        )

        ;; Show the form in a dock window. stblShowDockWindow docks it afterwards.
        hiCreateDockWindow(
            ?appType        "layout"
            ?widgetType     "form"
            ?form           stblForm 
            ?scrollBar      t
            ?title          "Selection table"
            ?dockSizeHint   list(220 900)
        )
    )
)

;; Refresh the Selection Table using the currently visible columns.
;;
;; The column count can change, so the report field is rebuilt with new
;; headers and swapped into the form. Called when Options is applied.
procedure(stblRefreshSelectionTableByOptions()
    let((
            visibleColumnDefinitions
            reportField
        )

        when(stblForm && stblOptionsForm
            visibleColumnDefinitions = stblGetVisibleColumnDefinitions(
                stblOptionsForm
            )
            reportField = hiCreateReportField(
                ?name       'reportField
                ?headers    stblBuildTableColumnDefinitions(
                                visibleColumnDefinitions
                            )
                ?choices    stblFilterSummaryBySearch(
                                stblBuildTableSelectionSummary(
                                    visibleColumnDefinitions
                                )
                            )
                ?selectMode    'extended
                ?enableDeselectCB   t
                ?callback   "stblReportFieldCallBack()"
            )

            hiDeleteField(
                stblForm
                'reportField
            )

            hiAddField(
                stblForm
                list(reportField 0:60 220:900 30)
            )
        )
    )
)

;; Refresh the table rows from the current selection, right away.
;;
;; Rebuilds the headers and the grouped rows for the visible columns and
;; applies the Search filter. It does not check the auto-refresh toggle, the
;; callers decide when to refresh. The poller (stblPollSelection) is what calls
;; it automatically when the selection changes.
procedure(stblRefreshSelectionTableData()
    let((visibleColumnDefinitions)
        visibleColumnDefinitions = stblGetVisibleColumnDefinitions(
            stblOptionsForm
        )

        stblForm~>reportField~>headers = stblBuildTableColumnDefinitions(
            visibleColumnDefinitions
        )

        stblForm~>reportField~>choices = stblFilterSummaryBySearch(
            stblBuildTableSelectionSummary(
                visibleColumnDefinitions
            )
        )
    )
)

;; Delete only the highlight set created by this table.
;; Other tools' highlight sets in the cellview are left untouched.
procedure(stblClearHighlight()
    when(geIsValidHilightId(stblHighlightSet)
        geDeleteHilightSet(stblHighlightSet)
    )
    stblHighlightSet = nil
)

;; Refresh button callback, also used after select and deSelect.
;; Refreshes unconditionally, whatever the auto-refresh toggle says.
procedure(stblRefreshSelectionTableCallBack()
    stblClearHighlight()
    stblRefreshSelectionTableData()
)

;; Refresh used for automatic updates (poller, Search field).
;; Does nothing without a window or form, or when auto-refresh is unticked.
procedure(stblRefreshSelectionTableByKey()
    when(getCurrentWindow() && boundp('stblForm) && stblForm
        stblClearHighlight()
        when(stblForm~>autoRefreshToggle~>autoRefresh~>value
            stblRefreshSelectionTableData()
        )
    )
)

;; Create the Options popup used to control visible table columns.
;;
;; The popup contains:
;; - A "Select All" toggle.
;; - One toggle for each configured table column.
;;
;; All toggle items are enabled by default.
procedure(stblCreateSelectHeaderWindowPopUp()
    let((
            toggleField
            defaultToggleValues
        )

        ;; One default value is required for each toggle item,
        ;; including the "Select All" option.
        defaultToggleValues = list()
        if(stblOptionsForm then
            defaultToggleValues = stblOptionsForm~>toggleField~>value
        else 
            for(i 0 length(stblColumnDefinitions)
                defaultToggleValues = append1(defaultToggleValues  t)
            )
        )

        toggleField = hiCreateToggleField( 
            ?name           'toggleField
            ?choices        stblBuildColumnToggleItems(
                                stblColumnDefinitions
                            )
            ?itemsPerRow    1
            ?defValue       defaultToggleValues 
            ?callback       list(
                                "stblToggleAllColumnSelections(hiGetCurrentForm())" 
                                ""
                            )
        )

        stblOptionsForm = hiCreateAppForm(
            ?name            'stblOptionsForm
            ?formTitle      "Options"
            ?fields            list(toggleField)
            ?buttonLayout   'OKCancel
            ?callback       "stblClearHighlight() stblRefreshSelectionTableByOptions()"
        )

        hiSetFormSize(
            stblOptionsForm
            30:300 
            t
        )
    )
)

;; Return the column definitions selected in the Options dialog.
;;
;; The toggle values are aligned with the toggle items built by
;; stblBuildColumnToggleItems: "Select All" first, then one value per entry of
;; stblColumnDefinitions in the same order. The first value is skipped.
procedure(stblGetVisibleColumnDefinitions(form)
    let((
            toggleValues
            visibleColumns
        )

        ;; Skip the first toggle item ("Select All")
        toggleValues = cdr(form~>toggleField~>value)

        visibleColumns = nil
        foreach(columnDefinition stblColumnDefinitions
            when(car(toggleValues)
                visibleColumns = cons(columnDefinition visibleColumns)
            )
            toggleValues = cdr(toggleValues)
        )

        reverse(visibleColumns)
    )
)


;; Toggle all column selections based on the state of the
;; "Select All" checkbox.
procedure(stblToggleAllColumnSelections(form)
    let((toggleValue)
        toggleValue = car(form~>toggleField~>value)

        form~>toggleField~>value = mapcar(
            lambda((oldValue) toggleValue)
            form~>toggleField~>value
        )
    )
)

;; Return the object ids of every selected row in the report field.
procedure(stblGetSelectedRowIds()
    let((choices ids)
        choices = stblForm~>reportField~>choices
        ids = nil
        ;; cons + reverse keeps this linear in the number of ids
        foreach(selectedRow hiReportGetSelectedItems(stblForm~>reportField)
            foreach(id car(nth(selectedRow choices))
                ids = cons(id ids)
            )
        )
        reverse(ids)
    )
)

;; Row click callback: highlight the objects of the selected rows.
;; A missing highlight layer only produces a warning.
procedure(stblReportFieldCallBack()
    let((idSelects result)
        stblClearHighlight()

        ;; The highlight layer may not exist in the tech file, so do not let
        ;; a missing layer-purpose pair raise an error on every row click.
        result = errset(
            geCreateHilightSet(geGetWindowCellView() stblHighlightLayer nil)
        )
        if(result && car(result) then
            stblHighlightSet = car(result)
            geSetHilightSetHaloParameters(stblHighlightSet "over" "fadeout" "normal" 50 nil )
            stblHighlightSet->enable = t
            idSelects = stblGetSelectedRowIds()
            foreach(idSelect idSelects
                geAddHilightFig(stblHighlightSet idSelect t)
            )
        else
            warn("Selection table: cannot highlight on layer %L, check stblHighlightLayer.\n" stblHighlightLayer)
        )
    )
)

;; Keep only the objects in keepIds selected.
;;
;; Every currently selected object that is not in keepIds is deselected.
;; Objects in keepIds that are not selected are NOT added, so keepIds is
;; expected to be a subset of the current selection (as table rows always are).
;; Only the objects that must go are touched.
procedure(stblApplySelectionSet(newIds)
    let((oldSelected keepSet)
        oldSelected = geGetSelectedSet()
        keepSet = makeTable("keepSet" nil)
        foreach(id newIds keepSet[id] = t)
        ;; Deselect only what must go (single pass, table lookup)
        foreach(item oldSelected
            unless(keepSet[item] geDeselectFig(item))
        )
    )
)

;; "select" button callback: keep only the objects of the picked rows selected.
procedure(stblSelectButtonCallBack()
    stblApplySelectionSet(stblGetSelectedRowIds())
    ;; Refresh even with auto-refresh off, the table rows are stale otherwise
    stblRefreshSelectionTableCallBack()
)

;; "deSelect" button callback: remove the objects of the picked rows from the
;; selection and keep the rest selected.
procedure(stblDeSelectButtonCallBack()
    let((dropSet remaining)
        dropSet = makeTable("dropSet" nil)
        foreach(id stblGetSelectedRowIds() dropSet[id] = t)
        remaining = setof(item geGetSelectedSet() !dropSet[item])
        stblApplySelectionSet(remaining)
        stblRefreshSelectionTableCallBack()
    )
)

;; Filter summary rows by the Search field (regular expression).
;;
;; Only the attribute values of a row are searched. The leading object ids
;; and the trailing occurrence count are skipped. An invalid regular
;; expression leaves the rows unfiltered.
procedure(stblFilterSummaryBySearch(tableSelectionSummaries)
    let((searchValue)
        searchValue = stblForm~>searchField~>value
        if(searchValue == "" || !errset(pcreMatchp(searchValue "")) then
            tableSelectionSummaries
        else
            setof(tableSelectionSummary tableSelectionSummaries
                exists(item reverse(cdr(reverse(cdr(tableSelectionSummary))))
                    pcreMatchp(searchValue sprintf(nil "%L" item))
                )
            )
        )
    )
)

;; Close every docked "Selection table" window.
;; Windows are matched by title, the form name can not be compared directly.
procedure(stblCloseDockWindows()
    foreach(dockWindow hiGetWindowList('dockable)
        when(hiGetWindowName(dockWindow) == "Selection table"
            errset(hiCloseWindow(dockWindow))
        )
    )
    t
)

;; Return the first docked window titled winName, or nil.
procedure(stblGetDockWindowByName(winName)
    prog((winId)
        winId = nil
        foreach(winId hiGetWindowList('dockable)
            when(hiGetWindowName(winId) == winName 
                return(winId)
            )
        )
    )
)

;; Create the table if needed and dock it on the right of the current window.
;; Needs an open window; without one it only prints a warning.
procedure(stblShowDockWindow()
    let((winId currentWin)
        currentWin = getCurrentWindow()
        ;; Docking needs a layout session; without an open window do nothing
        ;; (Ctrl Shift Q can be used again once a cellview is open).
        if(!currentWin then
            warn("Selection table: open a cellview first, then press Ctrl Shift Q.")
        else
            winId = stblGetDockWindowByName("Selection table")
            unless(winId && stblForm && stblOptionsForm && hiGetSessionWindow(currentWin) == hiGetSessionWindow(winId)
                stblCreateSelectionTableForm()
            )
            winId = stblGetDockWindowByName("Selection table")
            when(winId
                hiDockWindow(
                    ?window winId
                    ?session hiGetSessionWindow(currentWin)
                    ?side 'right
                )
                stblStartSelectionPolling()
            )
        )
    )
)


;; Selection polling
;;
;; The table follows the selection by polling instead of rebinding mouse and
;; keyboard events, so no default Layout bindkey is overwritten and every way
;; of changing the selection (box select, Select All, delete, other scripts...)
;; is covered.
;;
;; Each start gets a new token. A timer left over from a previous load carries
;; an old token, so it stops itself instead of running alongside the new one.
unless(boundp('stblPollToken) && numberp(stblPollToken)
    stblPollToken = 0
)
stblLastSelection = nil

;; Poll interval in tenths of a second.
stblPollDelay = 5

;; Start (or restart) the poller, which invalidates any earlier timer.
procedure(stblStartSelectionPolling()
    stblPollToken = stblPollToken + 1
    stblLastSelection = nil
    hiRegTimer(sprintf(nil "stblPollSelection(%d)" stblPollToken) stblPollDelay)
)

;; Timer callback: refresh the table when the selection changed, then re-arm.
;; A token that is no longer current means a newer load took over, stop then.
procedure(stblPollSelection(token)
    let((currentSelection)
        when(token == stblPollToken
            ;; Re-arm first so an error below can not stop the polling.
            hiRegTimer(sprintf(nil "stblPollSelection(%d)" token) stblPollDelay)

            when(getCurrentWindow() && stblForm
                currentSelection = geGetSelectedSet()
                unless(equal(currentSelection stblLastSelection)
                    ;; Record first so a failing refresh is not retried every tick.
                    stblLastSelection = currentSelection
                    errset(stblRefreshSelectionTableByKey())
                )
            )
        )
    )
)

;; Reloading resets stblOptionsForm (above), so close any dock window left over
;; from the previous load and rebuild the form and the Options popup.
stblCloseDockWindows()
stblForm = nil
stblShowDockWindow()

hiSetBindKey("Layout" "Ctrl Shift<key> Q" "stblShowDockWindow()")
