;------------------------------------------------------------------------
;
; Toggle layer visibility
;
;------------------------------------------------------------------------

procedure(toggleVisibleLayers(num)
let( (drawLayers mainLayer purposeList currentEntryLayer returnLayer mainPurpose)
  returnLayer = list("IP" "drawing")
  mainPurpose = "drawing"
  purposeList = list(mainPurpose "pin" "dummy" "odummy" "drawing1" "blockage" "v_sync" "v_high" "v_low" "v_high_top" "v_low_top")
  currentEntryLayer = leGetEntryLayer()

    ;(0 drawLayers = list( "VD" "VDR" "VG" "M0" "OD" "CM0A" "CM0B" "BCM0" "BCM0V" "BCMD" "MD" "PO" "CPO") mainLayer = "M0")
  case(num 
    (0 drawLayers = list( "M0" "CM0A" "CM0B" "VD" "VG") mainLayer = "M0")
    (1 drawLayers = list( "VIA0" "M1" "VIA1" ) mainLayer = "M1")
    (2 drawLayers = list( "VIA1" "M2" "VIA2" ) mainLayer = "M2")
    (3 drawLayers = list( "VIA2" "M3" "VIA3" ) mainLayer = "M3")
    (4 drawLayers = list( "VIA3" "M4" "VIA4" ) mainLayer = "M4")
    (5 drawLayers = list( "VIA4" "M5" "VIA5" ) mainLayer = "M5")
    (6 drawLayers = list( "VIA5" "M6" "VIA6" ) mainLayer = "M6")
    (7 drawLayers = list( "VIA6" "M7" "VIA7" ) mainLayer = "M7")
    (8 drawLayers = list( "VIA7" "M8" "VIA8" ) mainLayer = "M8")
    (9 drawLayers = list( "VIA8" "M9" "VIA9" ) mainLayer = "M9")
    (10 drawLayers = list( "VIA9" "M10" "VIA10" ) mainLayer = "M10")
    (11 drawLayers = list( "VIA10" "M11" "VIA11" ) mainLayer = "M11")
    (12 drawLayers = list( "VIA11" "M12" "VIA12" ) mainLayer = "M12")
    (13 drawLayers = list( "VIA12" "M13" "VIA13" ) mainLayer = "M13")
    (14 drawLayers = list( "VIA13" "M14" "VIA14" ) mainLayer = "M14")
    (15 drawLayers = list( "VIA14" "M15" "VIA15" ) mainLayer = "M15")
    (16 drawLayers = list( "VIA15" "M16" "VIA16" ) mainLayer = "M16")
    (17 drawLayers = list( "VIA16" "M17" "VIA17" ) mainLayer = "M17")
    (18 drawLayers = list( "VIA17" "M18" "VIA18" ) mainLayer = "M18")
    (19 drawLayers = list( "VIA18" "M19"         ) mainLayer = "M19")
  ); case

  if(list(mainLayer mainPurpose) == currentEntryLayer then
    leSetEntryLayer(returnLayer)
    foreach(layer drawLayers
      foreach(purpose purposeList
        togLayer = list(layer purpose)
        if(leIsLayerValid(togLayer) then
          leSetLayerVisible(togLayer nil)
        ); if
      ); foreach
    ); foreach
  else
    leSetEntryLayer(mainLayer)
    foreach(layer drawLayers
      foreach(purpose purposeList
        togLayer = list(layer purpose)
        if(leIsLayerValid(togLayer) then
          leSetLayerVisible(togLayer t)
          leSetLayerSelectable(togLayer t)
        ); if
      ); foreach
    ); foreach
  ); if

  hiRedraw()
); let
); procedure
hiSetBindKey("Layout" "<Key>0" "toggleVisibleLayers(0)")
hiSetBindKey("Layout" "<Key>1" "toggleVisibleLayers(1)")
hiSetBindKey("Layout" "<Key>2" "toggleVisibleLayers(2)")
hiSetBindKey("Layout" "<Key>3" "toggleVisibleLayers(3)")
hiSetBindKey("Layout" "<Key>4" "toggleVisibleLayers(4)")
hiSetBindKey("Layout" "<Key>5" "toggleVisibleLayers(5)")
hiSetBindKey("Layout" "<Key>6" "toggleVisibleLayers(6)")
hiSetBindKey("Layout" "<Key>7" "toggleVisibleLayers(7)")
hiSetBindKey("Layout" "<Key>8" "toggleVisibleLayers(8)")
hiSetBindKey("Layout" "<Key>9" "toggleVisibleLayers(9)")
hiSetBindKey("Layout" "Ctrl<Key>0" "toggleVisibleLayers(10)")
hiSetBindKey("Layout" "Ctrl<Key>1" "toggleVisibleLayers(11)")
hiSetBindKey("Layout" "Ctrl<Key>2" "toggleVisibleLayers(12)")
hiSetBindKey("Layout" "Ctrl<Key>3" "toggleVisibleLayers(13)")
hiSetBindKey("Layout" "Ctrl<Key>4" "toggleVisibleLayers(14)")
hiSetBindKey("Layout" "Ctrl<Key>5" "toggleVisibleLayers(15)")
hiSetBindKey("Layout" "Ctrl<Key>6" "toggleVisibleLayers(16)")
hiSetBindKey("Layout" "Ctrl<Key>7" "toggleVisibleLayers(17)")
hiSetBindKey("Layout" "Ctrl<Key>8" "toggleVisibleLayers(18)")
hiSetBindKey("Layout" "Ctrl<Key>9" "toggleVisibleLayers(19)")
