/***************************************************************
*
*                       (abArea object)                        *
*                                                              *
*               Calculate the area of an object.               *
*      Currently only works with polygons and rectangles.      *
*                                                              *
***************************************************************/
procedure(getDensity()
    density_calculate(geGetSelSet())
)

procedure(density_calculate(objects)
    ;;sum_area = 0
    densityTable=makeTable('densityTable 0.0)
    foreach(object objects
        densityTable[object~>layerName] = densityTable[object~>layerName] + abArea(object)
        ;;sum_area = sum_area + abArea(object)
    )
    foreach(element densityTable
        printf("Density of %s = %f \n", element, densityTable[element]/400)
    )
    densityTable=nil
)
(procedure (abArea object)
  (let (sum crd lastPt firstPt crdList area corners ll ur dx dy objType)
        (setq objType (dbGetq object objType))
        (if (equal objType "polygon") 
            (progn
             (setq crdList (dbGetq object points))
             (setq sum 0)
             (setq firstPt (setq lastPt (car crdList)))
             (setq crdList (cdr crdList))
             (foreach crd crdList
                      (setq dx (difference (xCoord crd) (xCoord lastPt)))
                      (setq sum (plus sum (times dx (plus (yCoord crd) (yCoord lastPt)))))
                      (setq lastPt crd))
             (setq sum (plus sum
                             (times (difference (xCoord firstPt) (xCoord lastPt))
                                    (plus (yCoord firstPt) (yCoord lastPt)))))
             (setq area (times 0.5 (abs sum))))
            (when (equal objType "rect") 
                  (setq corners (dbGetq object bBox))
                  (setq ll (car corners))
                  (setq ur (cadr corners))
                  (setq dx (difference (xCoord ll) (xCoord ur)))
                  (setq dy (difference (yCoord ll) (yCoord ur)))
                  (setq area (abs (times dx dy))))
            )
       area))
