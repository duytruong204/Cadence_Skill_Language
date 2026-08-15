;; Global Variable
SELECTION_TABLE_COLUMN_DEFINITIONS = list(
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

    list("area"             "let((area) abeInit(geGetEditCellView()) when(OBJECT~>isShape area = abeLayerFromShapes(list(OBJECT))~>area) abeDone() area)")
    list("origin"           "OBJECT~>xy")

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

GLOBAL_HIGHLIGHT_SET = nil

;; Build table column definitions from SELECTION_TABLE_COLUMN_DEFINITIONS 
;;
;; Adds
;; - An "id" column at the beginning
;; - Attribute Columns for each configured definition.
;; - A "count" column at the end.
procedure(BuildTableColumnDefinitions(columnDefinitions)
    let((tableColumns)

        tableColumns = list()

        ;; Add identifier column.
        tableColumns = append(
            tableColumns
            list(
                list(
                    "id" 0 stringToSymbol("left") stringToSymbol("string") t)
            )
        )

        ;; Create columns from configuration
        foreach(columnDefinition columnDefinitions 
            tableColumns = append(
                tableColumns
                list(
                    ;; list(car(columnDefinition) length(car(columnDefinition))*10 stringToSymbol("left") stringToSymbol("string") t)
                    list(car(columnDefinition) 70 stringToSymbol("left") stringToSymbol("string") t)
                )
            )
        )

        ;; Add occurrence count column
        tableColumns = append(
            tableColumns 
            list(
                list("count" length("count")*10 stringToSymbol("left") stringToSymbol("int") t)
            )
        )

        tableColumns 
    )
)

;; Build toggle items used to control column visibility.
;;
;; Adds:
;; - A "Select All" toggle.
;; - One toggle for each configured column.
procedure(BuildColumnToggleItems(columnDefinitions)
    let((toggleItems)

        toggleItems = list()

        ;; Add select-all option
        toggleItems = append(toggleItems list(list(stringToSymbol("Select All"))))

        ; Add one toggle item per column
        foreach(columnDefinition columnDefinitions
            toggleItems = append(toggleItems list(list(stringToSymbol(car(columnDefinition)))))
        )

        toggleItems 
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
procedure(BuildTableSelectionSummary(columnDefinitions)
    let((
            selectedColumns
            groupedObjectIds
            groupedCounts
            rowCount
            columnCount
            rowIndex
            columnIndex
            value
            objectId
            groupKey
            keyValues
            summaryRows
            rowData
        )

        ;; Collect selected objects and configured attributes
        selectedColumns = list(geGetSelectedSet())

        foreach(columnDefinition columnDefinitions
            selectedColumns = cons(
                ResolveAttributePath(
                    geGetSelectedSet()
                    cadr(columnDefinition)
                )
                selectedColumns
            )
        )

        selectedColumns = reverse(selectedColumns)

        rowCount = length(car(selectedColumns))
        columnCount = length(selectedColumns)

        ;; Hash tables for grouping
        groupedObjectIds = makeTable("groupedObjectIds" nil)
        groupedCounts    = makeTable("groupedCounts" 0)

        ;; Build grouping directly
        for(rowIndex 0 rowCount - 1

            objectId = nth(rowIndex car(selectedColumns))
            keyValues = nil

            for(columnIndex 1 columnCount - 1

                value = nth(
                    rowIndex
                    nth(columnIndex selectedColumns)
                )

                unless(stringp(value)
                    value = sprintf(nil "%L" value)
                )

                keyValues = cons(value keyValues)
            )

            groupKey = reverse(keyValues)

            groupedObjectIds[groupKey] =
                cons(
                    objectId
                    groupedObjectIds[groupKey]
                )

            groupedCounts[groupKey] =
                groupedCounts[groupKey] + 1
        )

        ;; Build summary rows
        summaryRows = nil

        foreach(key groupedObjectIds->?

            rowData = cons(
                reverse(groupedObjectIds[key])
                key
            )

            rowData = append1(
                rowData
                groupedCounts[key]
            )

            summaryRows = cons(rowData summaryRows)
        )

        reverse(summaryRows)
    )
)


;; Resolve an attribute path against one or more objects.
;;
;; Examples:
;;     "layerName"          ==> object~>layerName
;;     '("net" "name")      ==> object~>net~>name
;;     '("bBox" "car()")    ==> car(object~>bBox)
;;
;; Function calls are identified by the "()" suffix and
;; evaluated on each current value.
procedure(ResolveAttributePath(objects attributePath)
    let((
            nextValues
            currentValues
        )
        currentValues = objects

        if(!listp(attributePath) then
            attributePath = list(attributePath)
        )

        foreach(pathElement attributePath

            if(rexMatchp("OBJECT" pathElement) then

                nextValues = list()

                rexCompile("OBJECT")

                foreach(currentValue currentValues
                    nextValues = append1(
                        nextValues
                        evalstring(
                            rexReplace(pathElement "currentValue" 0) 
                        )
                    )
                )

                currentValues = nextValues
            else
                currentValues = dbGet(currentValues pathElement)
            )
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
;; The report field is initialized using SELECTION_TABLE_COLUMN_DEFINITIONS.
procedure(CreateSelectionTableForm()
    let((
            	reportField
            	refreshButton
            	selectButton
            	deSelectButton
            	gridButtonForm
            	gridSelectionTableForm
            	autoRefreshToggle
			    selectHeader
                searchField
            	;;selectionTableForm
        )
        
        ;; Main report field displaying grouped selection data
        reportField = hiCreateReportField(
		    ?name       'reportField
		    ?headers    BuildTableColumnDefinitions(
                            SELECTION_TABLE_COLUMN_DEFINITIONS
                        ) 
            ?choices    BuildTableSelectionSummary(
                            SELECTION_TABLE_COLUMN_DEFINITIONS
                        )
		    ?selectMode	'extended
            ?enableDeselectCB   t
            ?callback   "ReportFieldCallBack()"
	    )
        
        ;; Refresh report data from the current selection.
        refreshButton = hiCreateButton(
            ?name       'refreshButton
            ?buttonText "Refresh"
            ?enabled    nil
            ?callback   "RefreshSelectionTableCallBack()"
        )

        autoRefreshToggle = hiCreateToggleField(
            ?name           'autoRefreshToggle
            ?choices        list(
                                list(stringToSymbol("autoRefresh"))
                            )
            ?defValue       list(t) 
            ?callback       list(
                                "selectionTableForm~>refreshButton~>enabled = !car(selectionTableForm~>autoRefreshToggle~>value)"                                
                            )
        )

        ;; Select objects corresponding to selected report rows.
        selectButton = hiCreateButton(
            ?name    'selectbutton
            ?buttonText "select"
            ?callback   "selectButtonCallBack()"
        )

        ;; Remove objects corresponding to selected report rows from the current selection.
        deSelectButton = hiCreateButton(
            ?name    'deSelectButton
            ?buttonText "deSelect"
            ?callback   "deSelectButtonCallBack()"
        )

        ;; Open the column visibility configuration dialog.
        selectHeader = hiCreateButton(
            ?name    'selectHeader
            ?buttonText "Options"
            ?callback   "hiDisplayForm('selectHeaderWindowPopUp -1:-1)"
        )

        ;; Close last docked window
        foreach(winId hiGetWindowList('dockable)
            when(winId~>hiForm == 'selectionTableForm
                hiCloseWindow(winId) 
            )
        )
        gridButtonForm = hiCreateGridLayout(
            'gridButtonForm
            ?items      list(
                            list(refreshButton 'row 0 'col 0)
                            list(autoRefreshToggle 'row 0 'col 1) 
                            list(selectButton 'row 1 'col 0) 
                            list(deSelectButton 'row 1 'col 1) 
                            list(selectHeader 'row 1 'col 2) 
                        )
        )

        searchField = hiCreateStringField(
            ?name           `searchField
            ?prompt         "Search"
            ?defValue       ""
            ?callback       "RefreshSelectionTableByKey()"
            ?editable t
        )

        gidSearchForm   = hiCreateGridLayout(
            'gidSearchForm
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

        selectionTableForm = hiCreateLayoutForm(
            'selectionTableForm
            "Selection table"
            hiCreateVerticalBoxLayout(
                'vbox
                ?items list(
                    gridButtonForm
                    gidSearchForm
                    gridSelectionTableForm
                )
            )
            ?minSize 600:200
        )
        

        ;; Create the column configuration dialog used by
        ;; the Options button.
        CreateSelectHeaderWindowPopUp()
        ;; StartHilightSelected()
        hiCreateDockWindow(
            ?appType        "layout"
            ?widgetType     "form"
            ?form           selectionTableForm 
            ?scrollBar      t
            ?title          "Selection table"
            ?dockSizeHint   list(220 900)
        )
    )
)

;; Refresh the Selection Table using the currently visible columns.
procedure(RefreshSelectionTableByOptions()
    let((
            visibleColumnDefinitions
            reportField
        )

            visibleColumnDefinitions = GetVisibleColumnDefinitions(
                selectHeaderWindowPopUp
            )
            reportField = hiCreateReportField(
                ?name       'reportField
                ?headers    BuildTableColumnDefinitions(
                                visibleColumnDefinitions
                            ) 
                ?choices    filterSummaryBySearch(
                                BuildTableSelectionSummary(
                                    visibleColumnDefinitions
                                )
                            )
                ?selectMode	'extended
                ?enableDeselectCB   t
                ?callback   "ReportFieldCallBack()"
            )

            hiDeleteField(
                selectionTableForm 
                'reportField
            )

            hiAddField(
                selectionTableForm 
                list(reportField 0:60 220:900 30)
            )
    )
)

;; Start a periodic refresh of the Selection Table.
;;
;; The table is refreshed only when the current selection
;; differs from the previously cached selection.
procedure(RefreshSelectionTableCallBack()
    let((visibleColumnDefinitions)
        visibleColumnDefinitions = GetVisibleColumnDefinitions(
            selectHeaderWindowPopUp
        )

        when(geIsValidHilightId(GLOBAL_HIGHLIGHT_SET)
            geDeleteHilightSet(GLOBAL_HIGHLIGHT_SET)
        )
        visibleColumnDefinitions = GetVisibleColumnDefinitions(
            selectHeaderWindowPopUp
        )
        selectionTableForm~>reportField~>headers = BuildTableColumnDefinitions(
            visibleColumnDefinitions
        )

        selectionTableForm~>reportField~>choices = filterSummaryBySearch(
            BuildTableSelectionSummary(
                visibleColumnDefinitions
            )
        )
    )
)

procedure(RefreshSelectionTableByKey()
    let((visibleColumnDefinitions)
        visibleColumnDefinitions = GetVisibleColumnDefinitions(
            selectHeaderWindowPopUp
        )

        when(geIsValidHilightId(GLOBAL_HIGHLIGHT_SET)
            geDeleteHilightSet(GLOBAL_HIGHLIGHT_SET)
        )
        if(selectionTableForm~>autoRefreshToggle~>autoRefresh~>value then
            visibleColumnDefinitions = GetVisibleColumnDefinitions(
                selectHeaderWindowPopUp
            )
            selectionTableForm~>reportField~>headers = BuildTableColumnDefinitions(
                visibleColumnDefinitions
            )

            selectionTableForm~>reportField~>choices = filterSummaryBySearch(
                BuildTableSelectionSummary(
                    visibleColumnDefinitions
                )
            )
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
procedure(CreateSelectHeaderWindowPopUp()
    let((
            toggleField
            defaultToggleValues
        )

        ;; One default value is required for each toggle item,
        ;; including the "Select All" option.
        defaultToggleValues = list()
        for(i 0 length(SELECTION_TABLE_COLUMN_DEFINITIONS)
            defaultToggleValues = append1(defaultToggleValues  t)
        )

        toggleField = hiCreateToggleField( 
            ?name           'toggleField
            ?choices        BuildColumnToggleItems(
                                SELECTION_TABLE_COLUMN_DEFINITIONS
                            )
            ?itemsPerRow    1
            ?defValue       defaultToggleValues 
            ?callback       list(
                                "ToggleAllColumnSelections(hiGetCurrentForm())" 
                                ""
                            )
        )

        selectHeaderWindowPopUp = hiCreateAppForm(
            ?name	        'selectHeaderWindowPopUp
            ?formTitle      "Options"
            ?fields	        list(toggleField)
            ?buttonLayout   'OKCancel
            ?callback       "geDeleteAllHilightSet(geGetWindowCellView()) RefreshSelectionTableByOptions()"
        )

        hiSetFormSize(
            selectHeaderWindowPopUp
            30:300 
            t
        )
    )
)

;; Return the column definitions selected in the Options dialog.
;;
;; The first toggle item ("Select All") is ignored.
procedure(GetVisibleColumnDefinitions(form)
    let((
            selectedColumnNames
            visibleColumnDefinitions
        )

        selectedColumnNames = list()

        ;; Skip the first toggle item ("Select All")
        for(index 1 length(form~>toggleField~>value) - 1
            when(nth(index form~>toggleField~>value)
                selectedColumnNames = append1(
                    selectedColumnNames
                    symbolToString(
                        nth(index form~>toggleField~>_toggleItems)
                    )
                )
            )
        )

        visibleColumnDefinitions = list()

        foreach(columnDefinition  SELECTION_TABLE_COLUMN_DEFINITIONS 
            when(member(
                    car(columnDefinition) 
                    selectedColumnNames
                )
                visibleColumnDefinitions = append1(visibleColumnDefinitions columnDefinition)
            )
        ) 

        visibleColumnDefinitions
    )
)


;; Toggle all column selections based on the state of the
;; "Select All" checkbox.
procedure(ToggleAllColumnSelections(form)
    let((valueSet toggleValue)
        toggleValue = car(form->toggleField->value)

        valueSet = list()

        
        for(index 0 length(form~>toggleField~>value) - 1
            valueSet = append1(valueSet toggleValue)
        )

        form~>toggleField~>value = valueSet
    )
)

procedure(ReportFieldCallBack()
    let((selectedRow idSelects)
        when(geIsValidHilightId(GLOBAL_HIGHLIGHT_SET)
            geDeleteHilightSet(GLOBAL_HIGHLIGHT_SET)
        )
        ;; ;; GLOBAL_HIGHLIGHT_SET = geCreateHilightSet(geGetWindowCellView() list("hilite" "drawing1") nil)
        GLOBAL_HIGHLIGHT_SET = geCreateHilightSet(geGetWindowCellView() list("y4" "drawing") nil)
        geSetHilightSetHaloParameters(GLOBAL_HIGHLIGHT_SET "over" "fadeout" "normal" 50 nil )
        GLOBAL_HIGHLIGHT_SET->enable = t
        foreach(selectedRow  hiReportGetSelectedItems(selectionTableForm~>reportField)
            idSelects = append(
                idSelects
                car(nth(selectedRow selectionTableForm~>reportField~>choices))
            )
        )
        foreach(idSelect idSelects
            geAddHilightFig(GLOBAL_HIGHLIGHT_SET idSelect t)
        )
    )
)

;; procedure(selectItemInPropertiesEditor()
;;     let((cv idSelects propertiesEditorName)
;;         cv = geGetWindowCellView()
;;         foreach(selectedRow  hiReportGetSelectedItems(selectionTableForm~>reportField)
;;             idSelects = append(
;;                 idSelects
;;                 car(nth(selectedRow selectionTableForm~>reportField~>choices))
;;             )
;;         )
;;         propertiesEditorName = strcat("gevPl" cv~>libName cv~>cellName cv~>viewName "CDFForm")
;;         foreach(appform hiFormList()
;;             when(rexMatchp(propertiesEditorName appform)
;;                 println(symeval(appform)~>??)
;;                 foreach(idSelect idSelects
;;                     symeval(appform)~>figId = idSelects 
;;                 )
;;             )
;;         )
;;         t
;;     )
;; )


procedure(selectButtonCallBack()
    let((selectedRow selectedRows index idSelects idSelect)
        idSelects = list()
        selectedRows = list()
        foreach(selectedRow  hiReportGetSelectedItems(selectionTableForm~>reportField)
            idSelects = append(
                idSelects
                car(nth(selectedRow selectionTableForm~>reportField~>choices))
            )
        )

        foreach(item geGetSelectedSet()
            when(!member(item idSelects)
                geDeselectObject(item) 
            )
        )

        when(geIsValidHilightId(GLOBAL_HIGHLIGHT_SET)
            geDeleteHilightSet(GLOBAL_HIGHLIGHT_SET)
        )

        RefreshSelectionTableByKey()
    )
)

procedure(deSelectButtonCallBack()
    let((idSelects)
        idSelects = list()
        foreach(selectedRow  hiReportGetSelectedItems(selectionTableForm~>reportField)
            idSelects = append(
                idSelects
                car(nth(selectedRow selectionTableForm~>reportField~>choices))
            )
        )

        foreach(idSelect idSelects
            geDeselectFig(idSelect) 
        )

        when(geIsValidHilightId(GLOBAL_HIGHLIGHT_SET)
            geDeleteHilightSet(GLOBAL_HIGHLIGHT_SET)
        )

        RefreshSelectionTableByKey()
    )
)

procedure(filterSummaryBySearch(tableSelectionSummaries)
    let((newTableSelectionSummaries searchValue found stringItem)
        newTableSelectionSummaries = list()
        searchValue = selectionTableForm~>searchField~>value
        if(searchValue == "" then 
            newTableSelectionSummaries = tableSelectionSummaries
        else
            foreach(tableSelectionSummary tableSelectionSummaries
                found = nil
                foreach(item tableSelectionSummary
                    stringItem = sprintf(nil "%L" item)
                    ;; when(rexMatchp(searchValue stringItem)
                    when(pcreMatchp(searchValue stringItem)
                        found = t
                    )
                )
                when(found
                    newTableSelectionSummaries = append1(newTableSelectionSummaries tableSelectionSummary)
                )
            )
        )
        newTableSelectionSummaries
    )
)

procedure(GetDockWindowByName(winName)
    prog((winId)
        winId = nil
        foreach(winId hiGetWindowList('dockable)
            when(hiGetWindowName(winId) == winName 
                return(winId)
            )
        )
    )
)

procedure(showDockWindow()
    let((winId)
        winId = GetDockWindowByName("Selection table") 
        unless(winId && hiGetSessionWindow(getCurrentWindow()) == hiGetSessionWindow(winId)
            CreateSelectionTableForm()
        )
        winId = GetDockWindowByName("Selection table")
        hiDockWindow(
            ?window winId 
            ?session when(
                        getCurrentWindow() != nil hiGetSessionWindow(getCurrentWindow())
                    ) 
            ?side 'right
        )
    )
)


CreateSelectionTableForm()
showDockWindow()

hiSetBindKey("Layout" "None<Btn1Down>"   "mouseSingleSelectPt() RefreshSelectionTableByKey()")
hiSetBindKey("Layout" "Shift<Btn1Down>"  "mouseAddSelectPt() RefreshSelectionTableByKey()")
hiSetBindKey("Layout" "Ctrl<Btn1Down>"   "mouseSubSelectPt() RefreshSelectionTableByKey()")

hiSetBindKeys( "Layout" list(
    list("<DrawThru1>"  "leSelBoxOrStretch() RefreshSelectionTableByKey()"  "geSingleSelectBox() RefreshSelectionTableByKey()")
    list("Shift<DrawThru1>"  "geAddSelectBox() RefreshSelectionTableByKey()"  "geAddSelectBox() RefreshSelectionTableByKey()")
    list("Ctrl<DrawThru1>"  "geSubSelectBox() RefreshSelectionTableByKey()"  "geSubSelectBox() RefreshSelectionTableByKey()")
)) 

hiSetBindKey("Layout" "Ctrl<key>A"      "geSelectAllFig() RefreshSelectionTableByKey()")
hiSetBindKey("Layout" "Ctrl<key>D"      "geDeselectAllFig() RefreshSelectionTableByKey()")
hiSetBindKey("Layout" "<key>Delete"     "leHiDelete() RefreshSelectionTableByKey()")

hiSetBindKey("Layout" "Ctrl Shift<key> Q" "showDockWindow()")
