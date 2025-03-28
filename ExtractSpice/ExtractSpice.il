;=============================================
; Owner: Duy Truong
; Date: Mon Jan 20 10:17:02 JST 2025
; Description: 
; This script generates a SPICE netlist for a specified library, cell, and view.
; It automates simulation setup, netlist creation, and file management for HSPICE simulations.
;
; Key Features:
; - Removes any existing simulation directory for the specified cell.
; - Sets up the simulator environment for HSPICE.
; - Creates a netlist for the given library, cell, and view.
; - Copies the generated netlist to a specific location and renames it.
;
; Usage:
; Call `ExtractSpice()` with optional parameters:
; - libName: Name of the library (defaults to the library of the active cell view).
; - cellName: Name of the cell (default: "all" to extract netlists for all cells).
; - viewName: Name of the view (default: "schematic").
; If `libName` is not provided, the current active cell view is used.
;
; Example:
; ExtractSpice("myLibrary" "myCell" "schematic")
; ExtractSpice("myLibrary")  ; Extracts netlists for all cells in "myLibrary".
;=============================================

; Main procedure for extracting SPICE netlist
println("====================================================")
println(" Usage Examples:")
println("   ExtractSpice(myLibrary myCell schematic)")
println("   ExtractSpice(myLibrary)  ; Extracts netlists for all cells.")
println("   ExtractSpice()  ; Extracts netlists Current cellview (Must e schematic).")
println("====================================================")
procedure(ExtractSpice(@optional
            (libName nil)              ; Library name (optional)
            (cellName "all")           ; Cell name (default: "all")
            (viewName "schematic"))    ; View name (default: "schematic")
    ; Configure simulator environment
    simulator('hspiceD)
    envOption('setTopLevelAsSubckt t) ; Treat top level as subcircuit

    let((cmd)   
        ; If library name is not provided, use the current cell view
        if(libName == nil then
            cv = geGetEditCellView(getCurrentWindow())
            libName = cv~>libName
            cellName = cv~>cellName
            viewName = cv~>viewName
            unless(viewName == "schematic"
                error("\nInvalid cell view detected.
                       \nCurrent cell view:
                       \n\t[libName cellName viewName]
                       \n\t[%s %s %s]
                       \nPlease open a schematic cell view.", libName cellName viewName)
            )
            CreateNetlistByType(libName cellName viewName)
        else
            ; Extract netlist for all cells or a specific cell
            if(cellName == "all" then
                println("Extracting netlists for all cells...")
                foreach(cellName ddGetObj(libName)~>cells~>name
                    when(ddGetObj(libName cellName "schematic")
                        CreateNetlistByType(libName cellName "schematic")
                    )
                )
            else
                CreateNetlistByType(libName cellName viewName)
            )
        )
    t ; Return success
    )
)

; Helper procedure for creating a SPICE netlist
procedure(CreateNetlistByType(@optional
            (libName nil)              ; Library name (required)
            (cellName "all")           ; Cell name (default: "all")
            (viewName "schematic"))    ; View name (default: "schematic")
    let((cmd file )
        design(libName cellName viewName "r") ; Load the design for read access
        createNetlist(?display nil)          ; Generate netlist without display
        ; Remove existing netlist files
        cmd = strcat("rm -rf simulation/" cellName "/hspiceD/" viewName "/netlist/" cellName ".sp")
        csh(cmd)

        ; Copy and rename the generated netlist
        cmd = strcat("cp -f simulation/" cellName "/hspiceD/" viewName "/netlist/netlist simulation/" cellName "/hspiceD/" viewName "/netlist/" cellName ".sp")
        csh(cmd)
        file = strcat(getWorkingDir() "/simulation/" cellName "/hspiceD/" viewName "/netlist/" cellName ".sp") 
        println(file)
    )
    t ; Return success
)
