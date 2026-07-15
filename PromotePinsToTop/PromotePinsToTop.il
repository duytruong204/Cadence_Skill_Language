
/*******************************************************************
* DISCLAIMER: The following code is provided for Cadence customers *
* to use at their own risk. The code may require modification to   *
* satisfy the requirements of any user. The code and any           *
* modifications to the code may not be compatible with current or  *
* future versions of Cadence products.                             *
* THE CODE IS PROVIDED "AS IS" AND WITH NO WARRANTIES, INCLUDING   *
* WITHOUT LIMITATION ANY EXPRESS WARRANTIES OR IMPLIED WARRANTIES  *
* OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR USE.              *
*******************************************************************/
;; by Michael Merlis, version 0.8 (18/11/2018)
;; Minor changes to pass Lint check
;; Edited usage to run with a GUI MERPromotePinsToTopGUI()
;;;;;
;; by Rupinder Mand, version 0.7 (07/11/2018)
;; Added option to run on selected nets in Navigator
;; Added option to promote pins on visible layers in palette
;;;;;
;; by Michael Merlis, version 0.6 (07/11/2018)
;; Added check for existing pins with same bBox
;;;;;
;; by Michael Merlis, version 0.5 (16/11/2017)
;; Added Simple Form.
;; Error if lxInternal->source don't have type CELLVIEW ( when worked with XL, but schematic unreferenced)
;;;;;
;; by Michael Merlis, version 0.4 (06/09/2017)
;; Create net in the layout, when it ixists in schematic, but not in the layout.
;;;;;
;; by Michael Merlis, version 0.3 (05/09/2017)
;; Chane label height to 0.02
;; Add label rotation according to width/length of the pin
;;;;;
;; by Michael Merlis, version 0.2 (27/08/2017)
;; Change optional arguments to keys
;; Fix existin pins check for layer
;; Add Usage with examples
;;;;;
;; by Michael Merlis, version 0.1 (03/08/2017)
;; Added basic support for pathSeg
;; Fixed multiple pin figures mistyping bug
;;;;;;;;;;;;;;
;; Usage:
;;   Usage with a GUI form:
;; Open selected cellView and run main function MERPromotePinsToTopGUI()
;; Turn On/Off selected options and click Apply
;;;;;;;;;;;;;;
;;   Usage without GUI form:
;; Open selected cellView and run main function MERPromotePinsToTop()
;;
;; Parameters:
;; sel		- Running on selected instances only (default is nil)
;;		In case to promote pins only for selected instances set to t
;; selectedNets	- Promote pins on selected nets in Navigator
;;		In case to promote pins only for selected Nets in Navigator set to t
;; visibleLayers - Promote pins on visible layers in Layer Palette
;;		In case to promote pins for visible layers in palette set to t
;; schTerms	- Check terminals from corresponding schematic view (default is t)
;;              In case, when terminals exist in the layout, this parameter may be set to nil. 
;; onlyMet	- Create pins only in metal layers (default is t)
;;		In case when the pins in other than metal layers and they have to be promoted to top set to nil.
;; cv		- Working cellView (default is current cellView)
;;
;; Examples:
;; 
;; 1. Run on selected cells only:
;;	MERPromotePinsToTop(?sel t)
;; 2. Create pins for pins in all existing layers:
;;	MERPromotePinsToTop(?onlyMet nil)
;; 3. Create pins on selected cells only and check terminals in the layout view:
;;	MERPromotePinsToTop(?sel t ?schTerms nil)
;; 4. Create pins for selected cells for pins in all existing layers
;;	MERPromotePinsToTop(?sel t ?onlyMet nil)


procedure(MERPromotePinsToTop(@key (sel nil) (selectedNets nil) (visibleLayers nil) (schTerms t) (onlyMet t) (cv geGetEditCellView()))
  prog((tecFileId layerFun metalsFun cellProp prop sourceSch schExpanded netId termNameList insts netNames figLay figTopBox topFig topLabel xWidth yHeight lblRot existPins isSameExist sTopBox sExistP )
    tecFileId=techGetTechFile(ddGetObj(cv~>libName))
    layerFun=techGetLayerFunctions(tecFileId)
    metalsFun=mapcar('car setof(layer layerFun cadr(layer)=="metal"))
    if(schTerms then
      termNameList = list()
      if(cellProp=dbFindProp(cv "lxInternal") then
        when(prop=dbFindProp(cellProp "source") 
          if(prop~>type == "CELLVIEW" then
            sourceSch=dbOpenCellViewByType(prop~>lib prop~>cell prop~>view)
            foreach(schTerm sourceSch~>terminals
              schExpanded = dbProduceMemName(schTerm~>name)
                foreach(schExp schExpanded
                  unless(dbFindTermByName(cv schExp)
                    unless(netId = dbFindNetByName(cv schExp)
                      netId = dbCreateNet(cv schExp)
                    );uless
		    dbCreateTerm(netId schExp schTerm~>direction)
                  );unless
                termNameList = cons(schExp termNameList)
                );foreach
            );foreach
          else
            error("There are no connectivity referenced schematic view!") return()
          );if
        );when
      else
        error("There are no connectivity referenced schematic view!") return() 
      );if
    else
      unless(cv~>terminals error("There are no terminals in the cellview!") return())
      termNameList = cv~>terminals~>name
    );if
  unless(cv~>instances error("There are no instances in the cellview!") return())
    if(sel then 
      insts = setof(selObj geGetSelectedSet() selObj~>objType == "inst")
      unless(insts error("No instances are selected but \"Run On Selected Instances Only\" option is checked!") return())
      println("INFO:Running on selected instances")
    else 
      insts = cv~>instances
    );if
    
    if(selectedNets then 
      netNames = car(cdadar(hsmGetSelectedSet(?cellview cv ?type list('net))))
      unless(netNames error("No nets are selected in Navigator but \"Selected Nets\" option is checked!") return())
      println("INFO:Running on selected nets")
    else 
      netNames = cv~>nets~>name
    );if

    foreach(inst insts
      foreach(con inst~>conns
        ;when(member(con~>net~>term~>name termNameList)
        when((member(con~>net~>term~>name termNameList) && member(con~>net~>name netNames))
          foreach(pinFigs con~>term~>pins~>figs
            foreach(pinFig pinFigs
              isSameExist = nil
              case(pinFig~>objType
                ("rect" || "pathSeg"
                  figLay = pinFig~>lpp
                  ;when(member(car(figLay) metalsFun) || !onlyMet
                  when((member(car(figLay) metalsFun) || !onlyMet) && (!visibleLayers || pteIsVisible(buildString(figLay) "Layers"))
                    figTopBox = dbTransformBBox(pinFig~>bBox inst~>transform)
                    when(existPins = leSearchHierarchy(cv figTopBox 0 "pin" list(list( "layer" "==" figLay )))
                      foreach(exP existPins
                        sTopBox = sprintf(nil "%L" figTopBox)
                        sExistP = sprintf(nil "%L" exP~>bBox)
                        when(equal(sTopBox sExistP) 
                          isSameExist = t
                        );when 
                      ); foreach
                    );when
                    unless(isSameExist 
                      printf("INFO:Generate pin %s above inst pin %s cell %s\n" con~>net~>term~>name con~>term~>name inst~>cellName)
                      topFig = dbCreateRect(cv figLay figTopBox)
                      xWidth = xCoord(upperRight(figTopBox)) - xCoord(lowerLeft(figTopBox))
                      yHeight = yCoord(upperRight(figTopBox)) - yCoord(lowerLeft(figTopBox))
                      if(yHeight - xWidth > 1e-6  then
                       lblRot = "R90"
                      else
                       lblRot = "R0"
                      );if
                      topLabel = dbCreateLabel(cv figLay centerBox(figTopBox) con~>net~>term~>name "centerCenter" lblRot "roman" 0.02)
                      leAttachFig(topLabel topFig)
                      dbCreatePin(con~>net topFig)
                    );unless
                  );when
                )
                (t
                  printf("WARNING:There is a NON-rectangular pin %s in cell %s\n" con~>term~>name inst~>cellName)
                )
              );case
            ); foreach
          );foreach
        );when
      );foreach
    );foreach
    return(t)
  );prog
);procedure

procedure(MERPromotePinsToTopGUI()
  let((getSelectedVal termFromSchVal metalsOnlyVal selectedNetsVal visibleLayersVal getSelected selectedNets visibleLayers termFromSch metalsOnly MERPromotePinsToTopForm)
    getSelectedVal = nil 
    selectedNetsVal = nil
    visibleLayersVal = nil
    termFromSchVal = t
    metalsOnlyVal = t
    getSelected = hiCreateBooleanButton(
               ?name           'getSelected
               ?buttonText     "Run On Selected Instances Only"
               ?value          getSelectedVal
               ?defValue       getSelectedVal
               ?buttonLocation 'left
        )

    selectedNets = hiCreateBooleanButton(
               ?name           'selectedNets
               ?buttonText     "Selected Nets"
               ?value          selectedNetsVal
               ?defValue       selectedNetsVal
               ?buttonLocation 'left
        )

    visibleLayers = hiCreateBooleanButton(
               ?name           'visibleLayers
               ?buttonText     "Visible Layers"
               ?value          visibleLayersVal
               ?defValue       visibleLayersVal
               ?buttonLocation 'left
        )
                
    termFromSch = hiCreateBooleanButton(
               ?name           'termFromSch
               ?buttonText     "Use Schematic Reference"
               ?value          termFromSchVal
               ?defValue       termFromSchVal
               ?buttonLocation 'left
        )

    metalsOnly = hiCreateBooleanButton(
               ?name           'metalsOnly
               ?buttonText     "Create Pins On Metals Only"
               ?value          metalsOnlyVal
               ?defValue       metalsOnlyVal
               ?buttonLocation 'left
        )
    MERPromotePinsToTopForm = hiCreateAppForm(
            ?name           'MERPromotePinsToTopForm
            ?formTitle      "Promote Pins To Top Form"
            ?callback       "MERPromotePinsToTop(?sel hiGetCurrentForm()->getSelected->value 
            					?selectedNets hiGetCurrentForm()->selectedNets->value 
            					?visibleLayers hiGetCurrentForm()->visibleLayers->value 
            					?schTerms hiGetCurrentForm()->termFromSch->value 
            					?onlyMet hiGetCurrentForm()->metalsOnly->value)"
            ?fields 
                list(getSelected selectedNets visibleLayers termFromSch metalsOnly
                )
            ?initialSize    t
            ?buttonLayout   'ApplyCancelDef
        )
        ;;
	;;Tooltips
	 MERPromotePinsToTopForm->getSelected->hiToolTip = "Promote pins for selected instances"
	 MERPromotePinsToTopForm->selectedNets->hiToolTip = "Promote pins on selected nets in Navigator"
	 MERPromotePinsToTopForm->visibleLayers->hiToolTip = "Promote pins on visible layers in Layer Palette"
	 MERPromotePinsToTopForm->metalsOnly->hiToolTip = "Promote pins on metal layers only"
	        
        hiDisplayForm(MERPromotePinsToTopForm)
  )
);procedure
