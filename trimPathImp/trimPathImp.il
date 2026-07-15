/********************************************************************
* DISCLAIMER: The following code is provided for Cadence customers *
* to use at their own risk. The code may require modification to   *
* satisfy the requirements of any user. The code and any           *
* modifications to the code may not be compatible with current or  *
* future versions of Cadence products.                             *
* THE CODE IS PROVIDED "AS IS" AND WITH NO WARRANTIES, INCLUDING   *
* WITHOUT LIMITATION ANY EXPRESS WARRANTIES OR IMPLIED WARRANTIES  *
* OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR USE.              *
********************************************************************/
/* USAGE:
This SKILL script trims or chops hanging portion of path and pathSeg
when it overlaps a rectangle of the same layer. The rectangle could be
part of a standard via object.
If the path/pathSeg extends on both side of rectangle, only the shorter
length side is trimmed or chopped.
If the path/pathSeg overlaps more than one rectangle then the trimming 
happens on both ends of the path/pathSeg which extends beyond the rectangles.
Thus, the path/pathSeg remains between/overlapping the rectangles only.
In case of partial selection of path/pathSeg the selected side will be
trimmed irrespective of its length or extension beyond rectangle.
Load the SKILL API via the CIW or .cdsinit file.
     CIW>  load("CCStrimPath.il")
Open concerned layout and select the desired path/pathSeg objects of the
design which need to be trimmed.
Call the function in CIW or press bindkey F10 in Virtuoso Layout Editor:
     CIW>  CCStrimPath()
*/
procedure(CCStrimPathImp(@optional (wires geGetSelSet()))
	let(()
   	wires=setof(id wires id~>objType=="path"||id~>objType=="pathSeg")
        unless(length(wires)>=1
        	error("Please select a path or a pathSeg object to proceed")
        	);unless
        foreach(id wires
        	CCSTrimPathImp_obj_trim(id)         
        	);foreach
	t
	);let
)
hiSetBindKey("Layout" "F10" "CCStrimPath()")
procedure(CCSTrimPathImp_obj_trim(obj)
	let((cv obj_list_tmp obj_list beginPt endPt direction AndShape_L_X AndShape_R_X AndShape_L_Y aOri layer1 obj_list_rect obj_list_pin obj_list_shape obj_list_tmp1 obj_list_tmp2 outLayer AndShape_U_Y dis_U dis_D dis_R dis_L obj_tmp_bbox XClick YClick)
		;;cv=geGetEditCellView()
		cv=obj~>cellView
   		obj_list_shape=setof(tmp dbGetOverlaps(cv obj~>bBox) obj != tmp && (tmp~>objType=="pathSeg" || tmp~>objType=="path") && tmp~>layerName== obj~>layerName)
   		obj_list_pin=setof(tmp dbGetOverlaps(cv obj~>bBox) obj != tmp && tmp~>pin && tmp~>layerName== obj~>layerName)
   		obj_list_tmp1=setof(tmp dbGetOverlaps(cv obj~>bBox) obj != tmp && tmp~>objType=="rect")
   		obj_list_rect=setof(tmp obj_list_tmp1 tmp~>layerName == obj~>layerName)
   		obj_list_tmp2=setof(tmp dbGetOverlaps(cv obj~>bBox) obj != tmp && tmp~>objType=="stdVia")
		;; abeDone()
		abeInit(cv)
    		aOri=abeLayerFromShapes(list(obj))
		obj_list_tmp=list()

		XClick = car(hiGetPoint(hiGetCurrentWindow()))
		YClick = cadr(hiGetPoint(hiGetCurrentWindow()))

		foreach(obj_tmp obj_list_tmp2
   		 	if(obj_tmp~>viaHeader~>viaDef~>layer2~>name == obj~>layerName || obj_tmp~>viaHeader~>viaDef~>layer1~>name == obj~>layerName  then
				obj_tmp_bbox=dbTransformBBox(car(setof(tmp obj_tmp~>viaHeader~>master~>shapes tmp~>layerName == obj~>layerName))~>bBox list(obj_tmp~>origin obj_tmp~>orient 1.0))
				layer1 = abeLayerFromCellView(obj~>layerName ?startLevel 0 ?stopLevel 1 ?onlyVia t ?bBox obj_tmp_bbox)
	    		outLayer=abeNewLayer()
				abeLayerAnd(layer1 aOri outLayer)
				unless(outLayer~>area == 0
					obj_list_tmp=append1(obj_list_tmp obj_tmp)
				) ;unless
			);if
		);foreach
		abeDone()
   		obj_list=setof(tmp obj_list_tmp tmp~>viaHeader~>viaDef~>layer2~>name == obj~>layerName || tmp~>viaHeader~>viaDef~>layer1~>name == obj~>layerName )
		obj_list=append(obj_list obj_list_pin)
		obj_list=append(obj_list obj_list_rect)
		obj_list=append(obj_list obj_list_shape)
		if(obj~>objType == "pathSeg" then
	   		beginPt = obj~>beginPt
   			endPt = obj~>endPt
		);if
		if(obj~>objType == "path" then
	   		beginPt = car(obj~>points)
   			endPt = cadr(obj~>points)
		);if

   		when(obj_list
   			if(car(beginPt) == car(endPt) then
   				direction="V"
   			else
   				direction="H"
   			);if
   			if(direction == "H" then
   				if( car(beginPt) > car(endPt) then
   					;;<-------
   					obj_list=sort(obj_list lambda((x y) lessp( car(upperRight(x~>bBox)) car(upperRight(y~>bBox)))))
   					AndShape_L_X = caar(car(obj_list)~>bBox)
   					AndShape_R_X = caadr(car(last(obj_list))~>bBox)
					case( geGetSelSetFigPoint(obj)
						( ((t t))
							dis_R = car(beginPt) - AndShape_R_X
							dis_L = AndShape_L_X - car(endPt)   
							if(length(obj_list) > 1 then
								if(obj~>objType == "pathSeg" then
   									obj~>beginPt = list(AndShape_R_X cadr(beginPt))
   									obj~>endPt = list(AndShape_L_X cadr(endPt))
								else
									obj~>points=list(list(AndShape_R_X cadr(beginPt)) list(AndShape_L_X cadr(endPt)))
								);if
							else
								if(XClick then
									;;Check Click point
									if(XClick < AndShape_L_X then
										if(obj~>objType == "pathSeg" then
   											obj~>endPt = list(AndShape_L_X cadr(endPt))
										else
											obj~>points = list(beginPt list(AndShape_L_X cadr(endPt)))
										)
									else
										if(obj~>objType == "pathSeg" then
   											obj~>beginPt = list(AndShape_R_X cadr(beginPt))
										else
											obj~>points= list(list(AndShape_R_X cadr(beginPt)) endPt)
										)

									);if
								else
									if(dis_R > dis_L  then
										if(obj~>objType == "pathSeg" then
   											obj~>endPt = list(AndShape_L_X cadr(endPt))
										else
											obj~>points = list(beginPt list(AndShape_L_X cadr(endPt)))
										)
									else
										if(obj~>objType == "pathSeg" then
   											obj~>beginPt = list(AndShape_R_X cadr(beginPt))
										else
											obj~>points= list(list(AndShape_R_X cadr(beginPt)) endPt)
										)
									);if
								);if
							);if
						)
						( ((t nil))
							if(obj~>objType == "pathSeg" then
   								obj~>beginPt = list(AndShape_R_X cadr(beginPt))
							else
								obj~>points=list(list(AndShape_R_X cadr(beginPt)) endPt)
							);if
						)
						( ((nil t))
							if(obj~>objType == "pathSeg" then
   								obj~>endPt = list(AndShape_L_X cadr(endPt))
							else
								obj~>points= list(beginPt list(AndShape_L_X cadr(endPt)))
							);if
						)
						
					);case
   				else
   					;;------->
   					obj_list=sort(obj_list lambda((x y) lessp(car(lowerLeft(x~>bBox)) car(lowerLeft(y~>bBox)))))
   					AndShape_L_X = caar(car(obj_list)~>bBox)
   					AndShape_R_X = caadr(car(last(obj_list))~>bBox)
				
					case( geGetSelSetFigPoint(obj)
						( ((t t))
							dis_R = car(beginPt) - AndShape_R_X
							dis_L = AndShape_L_X - car(endPt)   
					

							if(length(obj_list) > 1 then
								if(obj~>objType == "pathSeg" then
   									obj~>endPt = list(AndShape_R_X cadr(beginPt))
   									obj~>beginPt = list(AndShape_L_X cadr(endPt))
								else
									obj~>points=list(list(AndShape_L_X cadr(endPt)) list(AndShape_R_X cadr(beginPt)))
								);if
							else
								if(XClick then
									;;Check Click point
									if(XClick > AndShape_L_X then
										if(obj~>objType == "pathSeg" then
											obj~>endPt = list(AndShape_R_X cadr(endPt))
										else
											obj~>points = list(beginPt list(AndShape_R_X cadr(beginPt)))
										);if
									else
										if(obj~>objType == "pathSeg" then
											obj~>beginPt = list(AndShape_L_X cadr(endPt))	
										else
											obj~>points = list(list(AndShape_L_X cadr(endPt)) endPt)
										); if
									)

								else
									if(dis_R > dis_L  then
										if(obj~>objType == "pathSeg" then
   											obj~>beginPt = list(AndShape_L_X cadr(endPt))
										else
											obj~>points = list(list(AndShape_L_X cadr(endPt)) endPt)
										)
									else
										if(obj~>objType == "pathSeg" then
   											obj~>endPt = list(AndShape_R_X cadr(beginPt))
										else
											obj~>points = list(beginPt list(AndShape_R_X cadr(beginPt)))
										);if
									);if
								)
							);if
						)
						( ((t nil))
							if(obj~>objType == "pathSeg" then
   								obj~>beginPt = list(AndShape_L_X cadr(endPt))
							else
								obj~>points=list(list(AndShape_L_X cadr(endPt)) endPt)
							);if
						)
						( ((nil t))
							if(obj~>objType == "pathSeg" then
   								obj~>endPt = list(AndShape_R_X cadr(beginPt))
							else
								obj~>points = list(beginPt list(AndShape_R_X cadr(beginPt)))
							);if
						)
					);case
   				);if
   			);if
   			if(direction == "V" then
   				obj_list=sort(obj_list lambda((x y) lessp( cadr(upperRight(x~>bBox)) cadr(upperRight(y~>bBox)))))
   				AndShape_L_Y = cadar(car(obj_list)~>bBox)
   				AndShape_U_Y = cadadr(car(last(obj_list))~>bBox)
   				if( cadr(beginPt) > cadr(endPt) then
					case( geGetSelSetFigPoint(obj)
						( ((t t))
							dis_U = cadr(beginPt) - AndShape_U_Y 
							dis_D = AndShape_L_Y - cadr(endPt)   
							if(length(obj_list) > 1 then
								if(obj~>objType == "pathSeg" then
   									obj~>beginPt = list(car(beginPt) AndShape_U_Y)
   									obj~>endPt = list(car(beginPt) AndShape_L_Y)
								else
									obj~>points = list(list(car(beginPt) AndShape_U_Y) list(car(beginPt) AndShape_L_Y))
								);if
							else
								if(YClick then
									;;Check Click point
									if(YClick > AndShape_L_Y then
										if(obj~>objType == "pathSeg" then
   											obj~>beginPt = list(car(beginPt) AndShape_U_Y)
										else
											obj~>points=list( list(car(beginPt) AndShape_U_Y) endPt)
										);if

									else
										if(obj~>objType == "pathSeg" then
   											obj~>endPt = list(car(beginPt) AndShape_L_Y)
										else
   											obj~>points = list(beginPt list(car(beginPt) AndShape_L_Y) )
										);if
								
									);if
								else


									if(dis_D > dis_U then
										if(obj~>objType == "pathSeg" then
   											obj~>beginPt = list(car(beginPt) AndShape_U_Y)
										else
											obj~>points=list( list(car(beginPt) AndShape_U_Y) endPt)
										);if
									else					
										if(obj~>objType == "pathSeg" then
   											obj~>endPt = list(car(beginPt) AndShape_L_Y)
										else
   											obj~>points = list(beginPt list(car(beginPt) AndShape_L_Y) )
										);if
									);if
								);if
							);if
						)
						( ((t nil))
							if(obj~>objType == "pathSeg" then
	   							obj~>beginPt = list(car(beginPt) AndShape_U_Y)
							else
								obj~>points = list(list(car(beginPt) AndShape_U_Y) endPt)
							);if
						)
						( ((nil t))
							if(obj~>objType == "pathSeg" then
   								obj~>endPt = list(car(beginPt) AndShape_L_Y)
							else
								obj~>points = list(beginPt list(car(beginPt) AndShape_L_Y) )
							);if
						)
					);case
   				else
					case( geGetSelSetFigPoint(obj)
						( ((t t))
							dis_U = cadr(beginPt) - AndShape_U_Y 
							dis_D = AndShape_L_Y - cadr(endPt)   
							if(length(obj_list) > 1 then
								if(obj~>objType == "pathSeg" then
   									obj~>endPt = list(car(beginPt) AndShape_U_Y)
		   							obj~>beginPt = list(car(beginPt) AndShape_L_Y)
								else
									obj~>points=list(list(car(beginPt) AndShape_L_Y) list(car(beginPt) AndShape_U_Y))
								)
							else
								if(YClick then
									;;Check Click point
									if(YClick < AndShape_L_Y then
										if(obj~>objType == "pathSeg" then
		   									obj~>beginPt = list(car(beginPt) AndShape_L_Y)
										else
   											obj~>points = list(list(car(beginPt) AndShape_L_Y) endPt)
										);if	
									else
										if(obj~>objType == "pathSeg" then
   											obj~>endPt  = list(car(beginPt) AndShape_U_Y)
										else
   											obj~>points = list(beginPt list(car(beginPt) AndShape_U_Y) )
										);if
									);if
								else
									if(dis_D > dis_U then
										if(obj~>objType == "pathSeg" then
   											obj~>endPt  = list(car(beginPt) AndShape_U_Y)
										else
   											obj~>points = list(beginPt list(car(beginPt) AndShape_U_Y) )
										);if
									else
										if(obj~>objType == "pathSeg" then
		   									obj~>beginPt = list(car(beginPt) AndShape_L_Y)
										else
   											obj~>points = list(list(car(beginPt) AndShape_L_Y) endPt)
										);if							
									);if
								);if
							);if
						)
						( ((t nil))
							if(obj~>objType == "pathSeg" then
		   						obj~>beginPt = list(car(beginPt) AndShape_L_Y)
							else
								obj~>points = list(list(car(beginPt) AndShape_L_Y) endPt)
							);if
						)
						( ((nil t))
							if(obj~>objType == "pathSeg" then
   								obj~>endPt = list(car(beginPt) AndShape_U_Y)
							else
								obj~>points = list(beginPt list(car(beginPt) AndShape_U_Y))
							);if
						)
					);case
   				);if
   			);if
   		);when
	);let
)
