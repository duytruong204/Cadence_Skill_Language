;; Global Variable
SELECTION_TABLE_COLUMN_DEFINITIONS = list(
    list("name"             "name")
    list("type"             "objType" )
    list("lib"              "libName")
    list("cell"             "cellName")
    list("via"              '("viaHeader" "viaDefName") )
    list("layer"            "layerName" )
    list("purpose"          "purpose" )
    list("netname"          '("net" "name") )
    list("width"            "width" )
    list("area"            "abeInit(geGetEditCellView()) \
                            let((listReturn item area) \
                                listReturn = list() \
                                foreach(item list(OBJECT) \
                                    area = nil \
                                    when(item~>isShape area = abeLayerFromShapes(list(item))~>area)
                                    listReturn = append1(listReturn area) \
                                )  \
                                abeDone() \
                                listReturn \
                                )"
        )
    list("origin"           "xy" )
    list("color"            "when(OBJECT~>isShape && !OBJECT~>theLabel && OBJECT~>objType != \"textDisplay\" dbGetShapeColor(OBJECT))" )
    list("isLock"           "when(OBJECT~>isShape && !OBJECT~>theLabel && OBJECT~>objType != \"textDisplay\" dbIsShapeColorLocked(OBJECT))" )
)
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
            selectionRows
            summaryRows
            rowData
            value
            objectId
            groupKey
            groupedObjectIds
            groupedCounts
        )
        ;; Collect selected objects and configured attributes.
        selectedColumns = list(geGetSelectedSet())

        foreach(columnDefinition columnDefinitions 
            selectedColumns = append(
                selectedColumns  
                list(
                    ResolveAttributePath(
                        geGetSelectedSet() 
                        cadr(columnDefinition)
                    )
                )
            )
        )

        ;; Build one row per selected object
        selectionRows = list()

        for(rowIndex  0 length(car(selectedColumns))-1
            rowData = list()

            for(columnIndex 0 length(selectedColumns)-1
                value = nth(rowIndex nth(columnIndex selectedColumns))

                unless(stringp(value)
                    when(columnIndex != 0
                        value = sprintf(nil "%L" value)
                    )
                )
                rowData = append1(rowData value)
            )

            selectionRows = append1(selectionRows rowData) 
        )

        ;; Group rows by attribute values
        groupedObjectIds = makeTable("groupedObjectIds" list())
        groupedCounts = makeTable("groupedCounts" 0)

        foreach(selectedRow selectionRows
            objectId = car(selectedRow)
            groupKey = cdr(selectedRow)

            groupedObjectIds[groupKey] = append1(
                groupedObjectIds[groupKey] 
                objectId
            )

            groupedCounts[groupKey] = groupedCounts[groupKey] + 1 
        )

        ;; Build final summary rows
        summaryRows = list()
        
        foreach(key groupedObjectIds~>?
            rowData = list()
            
            ;;value = sprintf(nil "%L" groupedObjectIds[key])
            value = groupedObjectIds[key]
            
            rowData = append1(rowData value)
            rowData = cons(car(rowData) key)
            rowData = append1(rowData groupedCounts[key])

            summaryRows = append(summaryRows list(rowData))
        )

        summaryRows
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
            ?callback   "RefreshSelectionTable()"
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
            ?callback   "selectHeaderWindowPopUp()"
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
        gridSelectionTableForm = hiCreateGridLayout(
            'gridSelectionTableForm
            ?items      list(
                            list(reportField 'row 1 'col 0 'row_span -1 )
                        )
        )

        selectionTableForm = hiCreateLayoutForm(
            'selectionTableForm
            "Selection table"
            hiCreateVerticalBoxLayout(
                'vbox
                ?items list(
                    gridButtonForm
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
procedure(RefreshSelectionTable()
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
                ?choices    BuildTableSelectionSummary(
                                visibleColumnDefinitions
                            )
                ?selectMode	'extended
                ;;?callback   "ReportFieldCallBack()"
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
procedure(StartSelectionTableAutoRefresh()
    if(selectionTableForm~>autoRefreshToggle~>autoRefresh~>value then
        RefreshSelectionTable()
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
            ?callback       "RefreshSelectionTable()"
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
    let(()
        t
        ;; hilightSelected()
    )
)

procedure(hilightSelected()
    let((cv selectedRow idSelects)
        foreach(selectedRow  hiReportGetSelectedItems(selectionTableForm~>reportField)
            idSelects = append(
                idSelects
                car(nth(selectedRow selectionTableForm~>reportField~>choices))
            )
            cv=geGetWindowCellView()
            HIGHLIGHT_SET = geCreateHilightSet(cv list("hilite" "drawing1") nil)
            HIGHLIGHT_SET->enable = t
            foreach(idSelect idSelects
                geAddHilightFig(HIGHLIGHT_SET idSelect)
            )
        )
    )
)

;; procedure(StartHilightSelected()
;;     let(()
;;         hiRegTimer("when(geGetWindowCellView() hilightSelected()) StartHilightSelected()" 1)
;;     )
;; )


procedure(selectButtonCallBack()
    let((selectedRow selectedRows index idSelects idSelect)
        idSelects = list()
        selectedRows = list()
        foreach(selectedRow  hiReportGetSelectedItems(selectionTableForm~>reportField)
            selectedRows = append1(selectedRows selectedRow)
        )
        for(index 0 length(selectionTableForm~>reportField~>choices)-1
            when(!member(index selectedRows)
                idSelects = append(
                    idSelects
                    car(nth(index selectionTableForm~>reportField~>choices))
                )
            )
        )
        foreach(idSelect idSelects
            geDeselectObject(idSelect) 
        )
        RefreshSelectionTable()
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
        RefreshSelectionTable()
    )
)

procedure(selectHeaderWindowPopUp()
    hiDisplayForm('selectHeaderWindowPopUp)
)

procedure(showDockWindow()
    let((foundDockWindow)
        foundDockWindow = nil
        foreach(winId hiGetWindowList('dockable)
            when(winId~>hiForm == 'selectionTableForm
                foundDockWindow = t
                hiDockWindow(
                    ?window winId 
                    ?session when(
                                getCurrentWindow() != nil hiGetSessionWindow(getCurrentWindow())
                            ) 
                    ?side 'right
                )
            )
        )
        when(!foundDockWindow
            CreateSelectionTableForm()
            foreach(winId hiGetWindowList('dockable)
                when(winId~>hiForm == 'selectionTableForm
                    foundDockWindow = t
                    hiDockWindow(
                        ?window winId 
                        ?session when(
                                    getCurrentWindow() != nil hiGetSessionWindow(getCurrentWindow())
                                ) 
                        ?side 'right
                    )
                )
            )
        )
    )
)

CreateSelectionTableForm()
showDockWindow()

hiSetBindKey("Layout" "None<Btn1Down>"   "mouseSingleSelectPt() StartSelectionTableAutoRefresh()")
hiSetBindKey("Layout" "Shift<Btn1Down>"  "mouseAddSelectPt() StartSelectionTableAutoRefresh()")
hiSetBindKey("Layout" "Ctrl<Btn1Down>"   "mouseSubSelectPt() StartSelectionTableAutoRefresh()")

hiSetBindKeys( "Layout" list(
    list("<DrawThru1>"  "leSelBoxOrStretch() StartSelectionTableAutoRefresh()"  "geSingleSelectBox() StartSelectionTableAutoRefresh()")
    list("Shift<DrawThru1>"  "geAddSelectBox() StartSelectionTableAutoRefresh()"  "geAddSelectBox() StartSelectionTableAutoRefresh()")
    list("Ctrl<DrawThru1>"  "geSubSelectBox() StartSelectionTableAutoRefresh()"  "geSubSelectBox() StartSelectionTableAutoRefresh()")
)) 

hiSetBindKey("Layout" "Ctrl<key>A"      "geSelectAllFig() StartSelectionTableAutoRefresh()")
hiSetBindKey("Layout" "Ctrl<key>D"      "geDeselectAllFig() StartSelectionTableAutoRefresh()")
hiSetBindKey("Layout" "<key>Delete"     "leHiDelete() StartSelectionTableAutoRefresh()")

hiSetBindKey("Layout" "Ctrl Shift<key> Q" "showDockWindow()")
