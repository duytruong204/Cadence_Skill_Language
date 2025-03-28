#! /bin/csh -f
#=========Config=========
#---------START--------
set os = "RHEL7"
set server = "HOSTGR_L"
set mem = "32000"

set cell = $1
set flag = $2
echo "$flag"

set FEOL_rule = "Dummy_FEOL_CalibreYE_3nm_E_15M_1Xa1Xb1Xc1Xd1Ya1Yb4Y2Yy2Z_014.11a_MOD_CELL"
set BEOL_rule = "Dummy_BEOL_CalibreYE_3nm_E_15M_1Xa1Xb1Xc1Xd1Ya1Yb4Y2Yy2Z_014.11a_MOD_CELL"
set FEOL_rule_fullchip = "Dummy_FEOL_CalibreYE_3nm_E_15M_1Xa1Xb1Xc1Xd1Ya1Yb4Y2Yy2Z_014.11a_MOD_CHIP"
set BEOL_rule_fullchip = "Dummy_BEOL_CalibreYE_3nm_E_15M_1Xa1Xb1Xc1Xd1Ya1Yb4Y2Yy2Z_014.11a_MOD_CHIP"

set env_dir = "/eda01/Foundry/TSMC/tools/Calibre/ENV"
set env_pdk = "calibre.CSHRC_v2022.2_24.16"
#---------END---------
set dir = `pwd`

if (-d DF4DMY) then
	echo "DF4DMY existed"
else
	mkdir DF4DMY
	echo "DONE create DF4DMY folder"
endif

if (-d input) then
	echo "input existed"
else
	mkdir input
	echo "DONE create input folder"
endif

if (-d output) then
	echo "output existed"
else
	mkdir output
	echo "DONE create output folder"
endif

if (-d LOG) then
	echo "LOG existed"
else
	mkdir output
	echo "DONE create LOG folder"
endif

foreach f ( \
$cell \
)
	cd output
	if (-d ${f}_${flag}) then
	rm -rf ${f}_${flag}
	endif
	mkdir ${f}_${flag}
	set gds_file = "${dir}/input/${f}.gds"
    # rm -rf  "$gds_file.gz"
	set top_cellname = "${f}"
	switch ($flag)
		case prepare:
			#Prepare for future feature
			breaksw
		case cell:
			####### FEOL #######
			cat ${dir}/rules/${FEOL_rule} | \
			sed 's/^DFM DEFAULTS RDB GDS FILE "FEOL.gds" PREFIX.*/DFM DEFAULTS RDB GDS FILE "FEOL.gds" PREFIX FEOL_/g' | \
			sed 's/^DFM DEFAULTS RDB OASIS FILE "FEOL.oas" PREFIX.*/DFM DEFAULTS RDB OASIS FILE "FEOL.oas" PREFIX FEOL_/g' | \
			sed "s#GDSFILENAME#${gds_file}#" | \
			sed "s#TOPCELLNAME#${top_cellname}#" | \
			sed "s#FEOL.gds#${top_cellname}_FEOL.gds#" | \
			sed "s#FEOL.sum#${top_cellname}_FEOL.sum#" | \
			sed "s#FEOL.oas#${top_cellname}_FEOL.oas#" | \
			sed "s#FEOL.db#${top_cellname}_FEOL.db#" >! ${f}_${flag}/${FEOL_rule}_mod
			####### BEOL #######
			cat ${dir}/rules/${BEOL_rule} | \
			sed 's/^DFM DEFAULTS RDB GDS FILE "BEOL.gds" PREFIX.*/DFM DEFAULTS RDB GDS FILE "BEOL.gds" PREFIX BEOL_/g' | \
			sed 's/^DFM DEFAULTS RDB OASIS FILE "BEOL.oas" PREFIX.*/DFM DEFAULTS RDB OASIS FILE "BEOL.oas" PREFIX BEOL_/g' | \
			sed "s#GDSFILENAME#${gds_file}#" | \
			sed "s#TOPCELLNAME#${top_cellname}#" | \
			sed "s#BEOL.gds#${top_cellname}_BEOL.gds#" | \
			sed "s#BEOL.sum#${top_cellname}_BEOL.sum#" | \
			sed "s#BEOL.oas#${top_cellname}_BEOL.oas#" | \
			sed "s#BEOL.db#${top_cellname}_BEOL.db#" >! ${f}_${flag}/${BEOL_rule}_mod
			cd ${f}_${flag}
			echo "Generating dummy $f..."
			####### FEOL #######
			#bs -M 1000 -os RHEL6 -source ${env_dir}/$env_pdk calibre -drc ${FEOL_rule}_mod
			#bs -M 1000 -os RHEL5 -source ${env_dir}/$env_pdk calibre -drc -hier  -turbo 2 -hyper ${FEOL_rule}_mod
			bs -M $mem -m $server -os $os -source ${env_dir}/$env_pdk calibre -drc -hier -turbo 4 -hyper 8 ${FEOL_rule}_mod &
            #bs -M $mem -m $server -os $os -source ${env_dir}/$env_pdk calibre -drc -hier ${FEOL_rule}_mod &
			####### BEOL #######
			#bs -M 1000 -os RHEL6 -source ${env_dir}/$env_pdk calibre -drc ${BEOL_rule}_mod
			#bs -M 1000 -os RHEL5 -source ${env_dir}/$env_pdk calibre -drc -hier  -turbo 2 -hyper ${BEOL_rule}_mod
			bs -M $mem -m $server -os $os -source ${env_dir}/$env_pdk calibre -drc -hier -turbo 4 -hyper 8 ${BEOL_rule}_mod &
            #bs -M $mem -m $server -os $os -source ${env_dir}/$env_pdk calibre -drc -hier ${BEOL_rule}_mod &
			####### CutOD #######
			#  bs -M 1000 -os RHEL5 -source ${env_dir}/$env_pdk calibre -drc -hier -turbo 16 -hyper ${CutOD_rule}_mod
			cd ${dir}
			#  mv -f $f ./output/
			breaksw
		case fullchip:
			####### FEOL #######
			cat ${dir}/rules/${FEOL_rule_fullchip} | \
			sed 's/^DFM DEFAULTS RDB GDS FILE "FEOL.gds" PREFIX.*/DFM DEFAULTS RDB GDS FILE "FEOL.gds" PREFIX FEOL_/g' | \
			sed 's/^DFM DEFAULTS RDB OASIS FILE "FEOL.oas" PREFIX.*/DFM DEFAULTS RDB OASIS FILE "FEOL.oas" PREFIX FEOL_/g' | \
			sed "s#GDSFILENAME#${gds_file}#" | \
			sed "s#TOPCELLNAME#${top_cellname}#" | \
			sed "s#FEOL.gds#${top_cellname}_FEOL.gds#" | \
			sed "s#FEOL.sum#${top_cellname}_FEOL.sum#" | \
			sed "s#FEOL.oas#${top_cellname}_FEOL.oas#" | \
			sed "s#FEOL.db#${top_cellname}_FEOL.db#" >! ${f}_${flag}/${FEOL_rule_fullchip}_mod
			####### BEOL #######
			cat ${dir}/rules/${BEOL_rule_fullchip} | \
			sed 's/^DFM DEFAULTS RDB GDS FILE "BEOL.gds" PREFIX.*/DFM DEFAULTS RDB GDS FILE "BEOL.gds" PREFIX BEOL_/g' | \
			sed 's/^DFM DEFAULTS RDB OASIS FILE "BEOL.oas" PREFIX.*/DFM DEFAULTS RDB OASIS FILE "BEOL.oas" PREFIX BEOL_/g' | \
			sed "s#GDSFILENAME#${gds_file}#" | \
			sed "s#TOPCELLNAME#${top_cellname}#" | \
			sed "s#BEOL.gds#${top_cellname}_BEOL.gds#" | \
			sed "s#BEOL.sum#${top_cellname}_BEOL.sum#" | \
			sed "s#BEOL.oas#${top_cellname}_BEOL.oas#" | \
			sed "s#BEOL.db#${top_cellname}_BEOL.db#" >! ${f}_${flag}/${BEOL_rule_fullchip}_mod
			cd ${f}_${flag}
			echo "Generating dummy $f..."
			####### FEOL #######
			#bs -M 1000 -os RHEL6 -source ${env_dir}/$env_pdk calibre -drc ${FEOL_rule}_mod
			#bs -M 1000 -os RHEL5 -source ${env_dir}/$env_pdk calibre -drc -hier  -turbo 2 -hyper ${FEOL_rule}_mod
			bs -M $mem -m $server -os $os -source ${env_dir}/$env_pdk calibre -drc -hier -turbo 4 -hyper 8 ${FEOL_rule_fullchip}_mod &
			####### BEOL #######
			#bs -M 1000 -os RHEL6 -source ${env_dir}/$env_pdk calibre -drc ${BEOL_rule}_mod
			#bs -M 1000 -os RHEL5 -source ${env_dir}/$env_pdk calibre -drc -hier  -turbo 2 -hyper ${BEOL_rule}_mod
			bs -M $mem -m $server -os $os -source ${env_dir}/$env_pdk calibre -drc -hier -turbo 20 -hyper 8 ${BEOL_rule_fullchip}_mod &
			####### CutOD #######
			#  bs -M 1000 -os RHEL5 -source ${env_dir}/$env_pdk calibre -drc -hier -turbo 16 -hyper ${CutOD_rule}_mod
			cd ${dir}
			#  mv -f $f ./output/
			breaksw
	endsw
    # gzip $gds_file
end
