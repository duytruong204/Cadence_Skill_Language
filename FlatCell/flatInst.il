;;; START USER DEFINE ;;;

libName  = "TC03GPG12ILSC12A1"; Set libName
cellList = "/design05/kairosen10vcf/FABBIZ/T03G/users/duyductruong_vf/AI_Accelerator/SKILL/FLAT_CELL/cell_flat"

;;; END USER DEFINE ;;;

procedure(go_flat()
    cells = readList(cellList)
    foreach(cell cells
        ;; Create layout for release
        ;;printf("[Create layout view for Release]\n")
        RVC_CopyView(libName cell "layout_hier" libName cell "layout")
        RVC_Flat(libName cell "layout" 31 t) 
        RVC_Merge(libName cell "layout" 
            list(
                list("M0" "drawing") 
                list("M2" "drawing") 
                list("M5" "drawing")
                list("VIA3" "drawing")
                list("VIA4" "drawing")
            ) t)
        RVC_Merge(libName cell "layout"
            list(
                list("prBoundary" "boundary") 
                ; list("finBoundary" "fb1")
                ; list("finBoundary" "fb2")
                list("CMD" "drawing") list("OD" "drawing")
                list("NP" "drawing") list("PP" "drawing") list("NW" "drawing")
                list("M1" "drawing") list("M3" "drawing") list("M4" "drawing")
                list("M6" "drawing") list("M7" "drawing") list("M8" "drawing")
                list("M9" "drawing") list("M10" "drawing") list("M11" "drawing")
                list("M12" "drawing") list("M13" "drawing") list("M14" "drawing")
            ) )
        RVC_DeleteLayer(libName cell "layout"
            list(
                list("hilite" "drawing9") 
                list("DEXCL" "m3") 
                list("DEXCL" "m4") 
                list("DEXCL" "m5") 
            ))
    )
)

procedure(RVC_CopyView(old_libName old_cell old_view 
                        new_libName new_cell new_view)
    let((cv_hier cv inst)
        cv_hier = dbOpenCellViewByType(old_libName old_cell old_view  "maskLayout" "r")
        cv = dbOpenCellViewByType(new_libName new_cell new_view  "maskLayout" "w")
        dbCreateInst(cv cv_hier nil list(0 0) "R0" 1)
        foreach(inst cv~>instances
            leFlattenInst(inst 1 t )
        )
        dbClose(cv_hier)
        dbSave(cv)
        dbPurge(cv)
    )
)

procedure(RVC_Flat(libName cell view flat_level flat_pcell)
    let((cv labelTable shape grp inst)
        cv = dbOpenCellViewByType(libName cell view  "maskLayout" "a") 
        labelTable=makeTable('labelTable nil)
        foreach(shape cv~>shapes
            when(shape~>objType=="label"
                labelTable[shape]=t
            )
        )
        foreach(grp cv~>figGroups dbDeleteObject(grp)) 
        foreach(inst cv~>instances
           if(inst~>objType == "mosaicInst"
                 then  leFlattenInst(inst~>mosaic flat_level flat_pcell )
                 else  leFlattenInst(inst flat_level flat_pcell )
           )
        )
        foreach(inst cv~>vias
            leFlattenInst(inst flat_level flat_pcell )
        )
        foreach(shape cv~>shapes
            when(shape~>objType=="label" && !labelTable[shape]
                dbDeleteObject(shape)
            )
        )
        foreach(shape cv~>shapes
            when(shape~>objType=="label"
                labelTable[shape]=t
            )
        )
        labelTable=nil 
        dbSave(cv)
        dbPurge(cv)
    )
)

procedure(RVC_LockColor(libName cell view)
    let((cv)
        cv = dbOpenCellViewByType(libName cell view  "maskLayout" "a")
        mptReColor(cv)
        mptLockAll(cv)
        dbSave(cv)
        dbPurge(cv)
    )
)

procedure(RVC_Merge(libName cell view listlayer @optional (Lock nil))
    let((cv origShapes orignLabel shape lp obj)
        cv = dbOpenCellViewByType(libName cell view  "maskLayout" "a")
        layerTable=makeTable('labelTable nil)
        xyTable=makeTable('labelTable nil)
        labelTable=makeTable('labelTable nil)
        justifyTable=makeTable('labelTable nil)
        orientTable=makeTable('labelTable nil)
        fontTable=makeTable('labelTable nil)
        heightTable=makeTable('labelTable nil)
        foreach(shape cv~>shapes
            when(shape~>objType=="label"
                layerTable[shape]=list(shape~>layerName shape~>purpose)
                xyTable[shape]=shape~>xy
                labelTable[shape]=strcat(shape~>theLabel)
                justifyTable[shape]=shape~>justify
                orientTable[shape]=shape~>orient
                fontTable[shape]=shape~>font
                heightTable[shape]=shape~>height
                dbDeleteObject(shape)
            )
        )
        foreach(layer listlayer
            origShapes = car(setof(lp cv~>lpps lp~>layerName==car(layer)&&lp~>purpose==cadr(layer)))~>shapes
            dbLayerOr(cv layer origShapes)
            if(Lock then
                mptReColor(cv list(car(layer)))
                mptLockAll(cv)
            )
            foreach(shape origShapes
                dbDeleteObject(shape)
            )
        )
        foreach(shape labelTable
                dbCreateLabel(cv layerTable[shape] xyTable[shape] labelTable[shape]
                                justifyTable[shape] orientTable[shape] fontTable[shape] heightTable[shape])
        )
        layerTable=nil
        xyTable=nil
        labelTable=nil
        justifyTable=nil
        orientTable=nil
        fontTable=nil
        heightTable=nil
        dbSave(cv)
        dbPurge(cv)
    )
)

procedure(RVC_DeleteLayer(libName cell view listlayer)
    let((cv lp shape)
        cv = dbOpenCellViewByType(libName cell view  "maskLayout" "a")
        foreach(layer listlayer
            foreach(shape car(setof(lp cv~>lpps lp~>layerName==car(layer)&&lp~>purpose==cadr(layer)))~>shapes
                dbDeleteObject(shape)
            ) 
        )
        dbSave(cv)
        dbPurge(cv)
    )
)

procedure(RVC_DrawOBS(libName cell view)
    let((cv)
        cv = dbOpenCellViewByType(libName cell view  "maskLayout" "a")
        dbCreateRect(cv list("M1","boundary") list(list(0 0) list(20 20)))
        dbCreateRect(cv list("M2","boundary") list(list(0 0) list(20 20)))
        dbCreateRect(cv list("C1","boundary") list(list(0.55 0) list(20 20)))
        dbCreateRect(cv list("C2","boundary") list(list(0.55 0) list(20 20)))
        dbSave(cv)
        dbPurge(cv)
    )
)

procedure(readList(fileName)
    prog((inport cell cells)
        inport = infile(fileName)
        unless(inport
            printf("*EEROR* Cannot open file %s.\n" fileName)
            return("error")
        )
        while(fscanf(inport "%s" cell)
            cells = append1(cells cell)
        )
        close(inport)
        return(cells)
    )
)
