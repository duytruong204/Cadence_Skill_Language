;=============================================
; Owner: Duy Truong 
; Date: Fri Jan 17 15:22:30 JST 2025 
; Description: This script is used to extract labels from a layout cellview. 
;              It searches for specific text labels (or all labels) based on
;              the given layer name and purpose. The labels are recreated in 
;              the main cellview with updated coordinates.
;
; Working: 
; - Recreates the labels in the main cellview. 
; - Use for butplace check LUP rule DRC
;
; Example Usage:
;   ExtractPin() ; Extract all labels
;   ExtractPin("VDD" "metal1" "pin" 2) ; Extract specific labels
;      Explanation:
;      - "VDD"     Search for labels with text "VDD".
;      - "M14"     Look for labels on the "M14" layer.
;      - "pin"     Search for labels with purpose "pin".
;      - 2         Recursively search up to 2 levels deep.
;=============================================

println("=========================================")
println(" Welcome to the ExtractPin Script ")
println("-----------------------------------------")
println(" This script helps extract labels from a layout cellview.")
println(" You can specify text, layerName, purpose, and maxdepth.")
println(" If no parameters are provided, defaults will be used.")
println(" Usage: ExtractPin [text(default=all)] [layerName] [purpose] [maxdepth(default=1)]")
println("=========================================")

; Define a procedure named ExtractPin with optional parameters
procedure(ExtractPin(@optional
                    (text "all") ; Text to search for (default: "all")
                    (layerName "") ; Layer name to search (default: empty)
                    (purpose "") ; Purpose to search (default: empty)
                    (maxdepth 1) ; Maximum depth for recursion (default: 1)
                    (depth 1) ; Current recursion depth (default: 1)
                    (inst nil) ; Instance information (default: none)
                    (x_offset 0) ; X-coordinate offset use for mosaic case (default: 0) 
                    (y_offset 0) ; Y-coordinate offset use for mosaic case (default: 0)
                    (MoveMatrix list())
                    (RotationMatrix list()) ; Y-coordinate offset use for mosaic case (default: 0)
                    (cv_main geGetEditCellView(getCurrentWindow()))) ; Main cellview
    let((cv x y x0 y0 x1 y1 FoundLabel LabelMatrix orient) ; Local variables
        ; If working with an instance
        if(inst then
            printf("Read instance [%s]\n" inst~>cellName) ; Print instance name
            cv = dbOpenCellViewByType(inst~>libName inst~>cellName inst~>viewName)
            if(inst~>orient then
                orient = inst~>orient  ; Get instance orientation
            else
                orient = car(inst~>tileArray) ; Get mosaic orientation
            )
            x = car(inst~>xy)  ; Adjust X-coordinate offset
            y = cadr(inst~>xy) ; Adjust Y-coordinate offset
        else
            ; If no instance, use the current cellview
            cv = geGetEditCellView(getCurrentWindow())
            x = 0 ; Reset X-coordinate
            y = 0 ; Reset Y-coordinate
            orient = "R0" ; Orientation is always R0 for main cellview
            ;; Remove all current label
            foreach(shape cv~>shapes
                if(shape~>theLabel then
                    dbDeleteObject(shape)
                )
            )
        )

        ;; Append movement Matrix
        MoveMatrix = append1(MoveMatrix list(list(x) list(y)))
        ;; Append Rotation Matrix
        RotationMatrix = append1(RotationMatrix orient_to_rotation_matrix(orient))

        ; Loop through all shapes in the current cellview
        foreach(shape cv~>shapes
            FoundLabel = nil ; Reset label found flag 
            ; Check if the shape is a label
            if(shape~>theLabel then
                ; If searching for all labels
                if(text == "all" then
                    if( shape~>layerName != "text" && shape~>layerName != "IP" && shape~>theLabel != "superMaster" then
                        FoundLabel = t ; Label is found
                    )
                else 
                    ; Check if label matches the given text, layer, and purpose
                    if( shape~>theLabel == text &&
                        shape~>layerName == layerName &&
                        shape~>purpose == purpose then
                        FoundLabel = t ; Label is found
                    ) 
                )
            )

            ; If a matching label is found, create it in the main cellview
            if(FoundLabel then
                printf("Found label [%s]\n", shape~>theLabel) ; Print label name
                x0 =  car(shape~>xy) + x_offset
                y0 = cadr(shape~>xy) + y_offset

                ; Apply rotation transformation
                LabelMatrix = list(list(x0) list(y0))
                orient = orient_to_rotation_matrix(shape~>orient)
                for(i 0 length(RotationMatrix)-1
                    LabelMatrix = multiply_matrices(nthelem((length(RotationMatrix) - i) RotationMatrix) LabelMatrix)
                    LabelMatrix = sum_matrices(nthelem((length(RotationMatrix) - i) MoveMatrix) LabelMatrix)
                    orient = multiply_matrices(nthelem((length(RotationMatrix) - i) RotationMatrix) orient)
                )
                x1 = caar(LabelMatrix)
                y1 = caadr(LabelMatrix)
                orient = rotation_matrix_to_orient(orient)

                ; Create a new label in the main cellview
                dbCreateLabel(cv_main list(shape~>layerName shape~>purpose)
                    x1:y1 shape~>theLabel shape~>justify 
                    orient shape~>font shape~>height)
            )
        )
        ; Loop through all instances and process recursively if within depth limit
        foreach(inst cv~>instances
            if(
                pcreMatchp("BEOL_.*" inst~>cellName) == nil &&
                pcreMatchp("FEOL_.*" inst~>cellName) == nil ;; &&
                then
                if(depth <= maxdepth then
                    ; Call ExtractPin recursively for this instance
                    ExtractPin(text layerName purpose maxdepth depth+1 inst 
                                0 0 MoveMatrix RotationMatrix cv_main)
                )
            )
        )
        ; Process mosaics (arrays of instances)
        foreach(mosaic cv~>mosaics
            for(col 0 mosaic~>columns-1
                for(row 0 mosaic~>rows-1
                    ; If the current depth is within the allowed max depth
                    if(depth <= maxdepth then
                        ExtractPin(text layerName purpose maxdepth depth+1 mosaic 
                                    mosaic~>uX*col mosaic~>uY*row MoveMatrix RotationMatrix cv_main)
                    )
                )
            )
        )
        t ; Return true to indicate successful completion
    )
)

;=============================================
; Function: multiply_matrices
; Multiplies two matrices together and returns the result
;=============================================

procedure(multiply_matrices(matrix_a matrix_b)
    prog((rows_a cols_a rows_b cols_b value row_result result)
        rows_a = length(matrix_a)
        cols_a = length(car(matrix_a))
        rows_b = length(matrix_b)
        cols_b = length(car(matrix_b))
        unless(cols_a == rows_b
             error("Number of columns in A must match number of rows in B\n")
        )
        result = list()
        for(i 0 rows_a-1
            row_result = list()
            for(j 0 cols_b-1
                value = 0            
                for(k 0 cols_a-1
                    value = value + nth(k nth(i matrix_a)) *  nth(j nth(k matrix_b))
                )
                row_result = append1(row_result value)
            )
            result = append1(result row_result)
        )
        return(result)
    )
)

;=============================================
; Function: sum_matrices
; Sums two matrices together and returns the result
;=============================================

procedure(sum_matrices(matrix_a matrix_b)
    prog((rows_a cols_a rows_b cols_b value row_result result)
        rows_a = length(matrix_a)
        cols_a = length(car(matrix_a))
        rows_b = length(matrix_b)
        cols_b = length(car(matrix_b))
        unless(cols_a == cols_b && rows_a == rows_b
             error("Number of rows, columns in A must match number of rows, colums in B\n")
        )
        result = list()
        for(i 0 rows_a-1
            row_result = list()
            for(j 0 cols_a-1
                value = nth(j nth(i matrix_a)) +  nth(j nth(i matrix_b))
                row_result = append1(row_result value)
            )
            result = append1(result row_result)
        )
        return(result)
    )
)

;=============================================
; Function: compare_matrices
; Sums two matrices together and returns the result
;=============================================

procedure(compare_matrices(matrix_a matrix_b)
    prog((rows_a cols_a rows_b cols_b)
        rows_a = length(matrix_a)
        cols_a = length(car(matrix_a))
        rows_b = length(matrix_b)
        cols_b = length(car(matrix_b))
        unless(cols_a == cols_b && rows_a == rows_b
             error("Number of rows, columns in A must match number of rows, colums in B\n")
        )
        for(i 0 rows_a-1
            for(j 0 cols_a-1
                if(nth(j nth(i matrix_a)) !=  nth(j nth(i matrix_b)) then
                    return(nil)
                )
            )
        )
        return(t)
    )
)

;=============================================
; Function: orient_to_rotation_matrix
; Returns the rotation matrix for a given orientation
;=============================================

procedure(orient_to_rotation_matrix(orient)
    prog(()
        case(orient
            (("R0")     return(list(list(1 0) list(0 1))))
            (("R90")    return(list(list(0 -1) list(1 0))))
            (("R180")   return(list(list(-1 0) list(0 -1))))
            (("R270")   return(list(list(0 1) list(-1 0))))
            (("MX")     return(list(list(1 0) list(0 -1))))
            (("MXR90")  return(list(list(0 1) list(1 0))))
            (("MY")     return(list(list(-1 0) list(0 1))))
            (("MYR90")  return(list(list(0 -1) list(-1 0))))
            (t          return(list(list(1 0) list(0 1))))
        )
    )
)

;=============================================
; Function: rotation_matrix_to_orient
; Returns the orientation for given rotation_matrix
;=============================================

procedure(rotation_matrix_to_orient(rotation_matrix)
    prog(()
        cond(
            (compare_matrices(rotation_matrix list(list(1 0) list(0 1)))        return("R0"))
            (compare_matrices(rotation_matrix list(list(0 -1) list(1 0)))       return("R90"))
            (compare_matrices(rotation_matrix list(list(-1 0) list(0 -1)))      return("R180"))
            (compare_matrices(rotation_matrix list(list(0 1) list(-1 0)))       return("R270"))
            (compare_matrices(rotation_matrix list(list(1 0) list(0 -1)))       return("MX"))
            (compare_matrices(rotation_matrix list(list(0 1) list(1 0)))        return("MXR90"))
            (compare_matrices(rotation_matrix list(list(-1 0) list(0 1)))       return("MY"))
            (compare_matrices(rotation_matrix list(list(0 -1) list(-1 0)))      return("MYR90"))
            (t                                                                  return("Unknown"))
        )
    )
)
