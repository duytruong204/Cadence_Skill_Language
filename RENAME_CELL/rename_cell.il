;; user setting
libName = "GC22AFSBV3_test_copy"
cell_list = "/design01/kairosen9vcf/FABBIZ/GF22FDX/users/duyductruong_vf/1_GF22FDX_U5M/SKILL/RENAME_CELL/cell.list"
;;
procedure(go_rename()
    let((cell cells)
        cells = readList(cell_list)
        foreach(cell cells
            CCSRenameCell(libName car(cell) cadr(cell)) 
        )
    )
)
procedure( CCSRenameCell( libName cellName newCellName)
    let( ( srcSpec destSrc )
        if(ddGetObj(libName cellName) then
            srcSpec = gdmCreateSpec(libName cellName nil nil "LibraryUnix")
            destSrc = gdmCreateSpec(libName newCellName nil nil "LibraryUnix")
            ccpRename(srcSpec destSrc t 'CCP_EXPAND_COMANAGED 'CCP_UPDATE_DESTLIB_ONLY)
        else
            error("CCSRenameCell : Cell %s from lib %s does not exists\\n" libName cellName ) ; error
        ) ; if
    ) ; let
) ; procedure

procedure(readList(fileName)
    prog((inport cell cells)
        inport = infile(fileName)
        unless(inport
            printf("*EEROR* Cannot open file %s.\n" fileName)
            return("error")
        )
        while(cell = lineread(inport)
            cells = append1(cells cell)
        )
        close(inport)
        return(cells)
    )
)
