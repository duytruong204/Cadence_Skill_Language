procedure(meshSelected(listInfo @optional (cv geGetEditCellView()))
    let((shape box inBox layer purpose direction netName offset width pitch Info width_size length_size mesh)
        shape = car(selectedSet())
        box = shape~>bBox
                
        foreach(Info listInfo 
            layer       = nthelem(1 Info)
            purpose     = nthelem(2 Info)
            direction   = nthelem(3 Info)
            netName     = nthelem(4 Info)
            offset      = nthelem(5 Info)
            width       = nthelem(6 Info)
            pitch       = nthelem(7 Info)
            if(direction == "vertical" then
                inBox = list(
                        list(xCoord(lowerLeft(box))+offset yCoord(lowerLeft(box))) 
                        list(xCoord(upperRight(box)) yCoord(upperRight(box))) 
                    )
                width_size = width
                length_size = yCoord(upperRight(box))-yCoord(lowerLeft(box))
            else
                inBox = list(
                        list(xCoord(lowerLeft(box)) yCoord(lowerLeft(box))+offset) 
                        list(xCoord(upperRight(box)) yCoord(upperRight(box))) 
                    )
                width_size = xCoord(upperRight(box))-xCoord(lowerLeft(box)) 
                length_size = width 
            )
            mesh = rodCreateRect( 
                ?cvId geGetEditCellView()
                ?layer list(layer purpose)
                ?fillBBox inBox
                ?width width_size
                ?length length_size
                ?spaceX pitch-width
                ?spaceY pitch-width
                ?returnBoolean nil
                ;;?netName netName
            )
        )
        ;; vopt = viaGetViaOptions( cstFindConstraintGroupIn(techGetTechFile(cv) "virtuosoDefaultSetup" ) )
        ;; vopt~>automatic~>connectShapesOnSameNet = t
        ;; viaGenerateViasFromShapes(cv vopt)   
        ;; viaGenerateViasInArea(cv box  vopt)
    )
) ;proc
meshSelected(list(
    list("M1" "drawing" "vertical"   "" 0    0.14 0.04+0.14)
    ;;list("M2" "drawing" "horizontal" "" 0    0.25 0.25+0.18)

    list("M2" "drawing" "horizontal" "" 0      0.042 0.158)
    list("M2" "drawing" "horizontal" "" 0.044+0.042  0.042 0.158)

    ;;list("M3" "drawing" "vertical"   "" 0    0.25 0.64)

    list("M3" "drawing" "vertical"   "" 0    0.25 0.96)
    list("M3" "drawing" "vertical"   "" 0.32 0.25 0.96)
))
