procedure(ChangeInstance(inst old_name new_name)   
    prog((old_cellName colonNum new_cellName master old_width new_width)
        old_cellName = inst~>cellName
        old_width = caar(cdr(inst~>bBox))-caar(inst~>bBox)
        colonNum = pcreCompile(old_name)

        new_cellName = pcreReplace(colonNum old_cellName new_name 0)
        master=dbOpenCellViewByType(inst~>libName new_cellName inst~>viewName)
        inst~>master=master
        new_width = caar(cdr(inst~>bBox))-caar(inst~>bBox)
        ;; Instance whose has MY or R180 orientation need to be moved after changing name
        if(inst~>orient == "MY" || inst~>orient == "R180" then
            new_x = car(inst~>xy)+new_width-old_width
            new_y = cadr(inst~>xy)
            inst~>xy = list(new_x new_y)
        )
        return(new_width-old_width)
    )
)

procedure(MoveInstance(inst move)   
    let((new_x new_y xform)
        xform=list(move:0 "R0" 1)
        dbMoveFig(inst nil xform)
    )
)

procedure(StretchInstance(inst move side)   
    printf("%s %f %s\n", inst move side)
    if(side == "rightstretch" then
        leStretchFig(inst list(move 0) list(nil t nil nil) t )
    else
        if(side == "leftstretch" then
            leStretchFig(inst list(move 0) list(nil nil t nil) t )
        )
    )
)

procedure(FindNearest(number list)
    prog((element diff minimum_diff)
        minimum_diff = 10e10
        foreach(element list
            diff = abs(number - element)
            if(minimum_diff > diff then
                minimum_diff = diff
                return_number = element
            )
        )
        return(return_number)
    )   
)

procedure(GroupObject()
    prog((cv instTable inst keys index shape)
        cv = geGetWindowCellView()
        instTable=makeTable('instTable nil)
        ;; Group instance only
        foreach(inst cv~>instances
            index = caar(inst~>bBox)
            instTable[index] = append1(instTable[index] list(inst, "moveInst"))
        ) 
        keys=sort(instTable->? 'lessp)
        foreach(inst cv~>vias
            index = caar(inst~>bBox)
            instTable[index] = append1(instTable[index] list(inst, "move"))
        ) 
        foreach(inst cv~>shapes
            if(inst~>objType != "label" then
                if(inst~>layerName != "IA" then
                    index = caar(inst~>bBox)
                    index = FindNearest(caar(inst~>bBox) keys)
                    instTable[index] = append1(instTable[index] list(inst, "move"))
                else
                    leConvertShapeToPolygon(inst)
                    index = FindNearest(caar(inst~>bBox) keys)
                    instTable[index] = append1(instTable[index] list(inst, "leftstretch"))
                    index = FindNearest(caadr(inst~>bBox) keys)
                    instTable[index] = append1(instTable[index] list(inst, "rightstretch"))
                )
            )
        ) 
        return(instTable)
    )
)

procedure(ChangeInstanceAndMove(old new)
    let((instTable inst keys key_sort key input)
        instTable=GroupObject()
        keys=sort(instTable->? 'lessp)
        key_sort = keys
        foreach(key keys
            foreach(inst instTable[key]
                object = car(inst)
                decision = cadr(inst)
                if(decision == "moveInst" then
                     move = ChangeInstance(object old new)                
                else if(decision == "rightstretch" then
                        StretchInstance(object move decision)
                    )
                )
            )
            key_sort=cdr(key_sort)
            foreach(key key_sort
                foreach(inst instTable[key]
                    object = car(inst)
                    decision = cadr(inst)
                    if(decision == "moveInst" || decision == "move" then
                        MoveInstance(object move)
                    else
                        StretchInstance(object move decision)
                    )
                )
            )
        )
        instTable=nil
    )
)
