label = "VDDM" ; vertical
height = 1
orient = "R0"
;; orient = "R90"
size = 1

procedure(MakeCdl()
    let((pat cv labels label list_label)
        list_label = list()
        list_label_z = list()
        cv = geGetWindowCellView()
        foreach(labels cv~>lpps~>shapes
            foreach(label labels
                if(label~>theLabel != nil && rexMatchp("VDDM" label~>theLabel) then
                    if(rexMatchp("Z_" label~>theLabel) then
                        list_label_z = append1(list_label_z label~>theLabel)
                    else if(! rexMatchp("Z_" label~>theLabel) then
                            list_label = append1(list_label label~>theLabel)
                        )
                    )
                )
            )
        )
        list_label = sort(list_label 'alphalessp)
        list_label_z = sort(list_label_z 'alphalessp)
        i = 0 
        schId = dbOpenCellViewByType(cv~>libName cv~>cellName "schematic" "schematic" "w" )
        ; symbolId = dbOpenCellViewByType("tsmcN3" "rmsp" "symbol" "schematicSymbol" 'r)
        symbolId = dbOpenCellViewByType("cmos22fdsoi" "lvsres" "symbol" "schematicSymbol" 'r)
        while(i<length(list_label_z)
            printf("%s and %s\n" nth(i list_label) nth(i list_label_z))
            inputCVId = dbOpenCellViewByType( "basic" "iopin" "symbol" "schematicSymbol" 'r )
            pinId = schCreatePin(schId inputCVId nth(i list_label) "input" nil 0:i "R0" )
            intId = schCreateInst(schId symbolId nil 1:i "R90" )
            pinId = schCreatePin(schId inputCVId nth(i list_label_z) "input" nil 2:i "R0" )
            schCreateWire(schId "route" "full" list(0:i 1:i) 0.0625 0.0625 0.0)
            schCreateWire(schId "route" "full" list(1.375:i 2:i) 0.0625 0.0625 0.0)
            dbClose(inputCVId)
            i = i + 1
        )
        dbClose(symbolId)
        dbSave(schId)
        dbPurge(schId)
    )
)
procedure(RVC_GoDrawPin()
    let((i num object cv ll ur x1 x2 y1 y2)
        i = 0
        old_layerName = ""
        cv = geGetWindowCellView()
        foreach(object geGetSelSet()
            if(old_layerName != object~>layerName then
                i = 0
                old_layerName = object~>layerName
            )
            if(object~>isShape then
                ll = car(object~>bBox)
                ur = cadr(object~>bBox) 
                x1 = car(ll)
                x2 = car(ur)
                y1 = cadr(ll)
                y2 = cadr(ur)
                number_layer = substring(object~>layerName 2 length(object~>layerName))
                ;;if(mod(atoi(number_layer),2) != 0 then
                if(orient == "R90" then
                    ;; odd metal
                    sprintf(num "%d" i)
                    dbCreateLabel(
                        cv
                        list(object~>layerName "pin")
                        list((x1+x2)/2 y1)
                        strcat(label num "_" object~>layerName)
                        "centerCenter" orient "stick" height
                    )
                    dbCreateLabel(
                        cv
                        list(object~>layerName "pin")
                        list((x1+x2)/2 y2)
                        strcat(label num "Z_" object~>layerName)
                        "centerCenter" orient "stick" height 
                    )
                    i++
                else ;; even metal
                    ;; odd metal
                    sprintf(num "%d" i)
                    dbCreateLabel(
                        cv
                        list(object~>layerName "pin")
                        list(x1 (y1+y2)/2)
                        strcat(label num "_" object~>layerName)
                        "centerCenter" orient "stick" height
                    )
                    dbCreateLabel(
                        cv
                        list(object~>layerName "pin")
                        list(x2 (y1+y2)/2)
                        strcat(label num "Z_" object~>layerName)
                        "centerCenter" orient "stick" height 
                    )
                    i++
                )
            )
        )
    )
)
procedure(RVC_GoDrawResistor()
    let((object cv ll ur x1 x2 y1 y2)
        cv = geGetWindowCellView()
        foreach(object geGetSelSet()
            if(object~>isShape then
                ll = car(object~>bBox)
                ur = cadr(object~>bBox) 
                x1 = car(ll)
                x2 = car(ur)
                y1 = cadr(ll)
                y2 = cadr(ur)
                number_layer = substring(object~>layerName 2 length(object~>layerName))
                if(orient == "R90" then
                ;; if(mod(atoi(number_layer),2) != 0 then
                    ;; odd metal
                    dbCreateRect(cv list(object~>layerName "lvsres") list(x1:y2 x2:(y2+size)))
                    ;;dbCreateRect(cv list("RMDMY" lowerCase(object~>layerName)) list(x1:y2 x2:(y2+size)))
                    leStretchShape(object list( 0 2*size ) list(nil t t nil) t )
                else ;; even metal
                    dbCreateRect(cv list(object~>layerName "lvsres") list(x2:y1 (x2+size):y2))
                    ;;dbCreateRect(cv list("RMDMY" lowerCase(object~>layerName)) list(x2:y1 (x2+size):y2))
                    leStretchShape(object list( 2*size 0 ) list(nil nil nil t) t )
                )
            )
        )
    )
)
