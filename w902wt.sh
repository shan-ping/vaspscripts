#!/bin/bash

#--------------------------------------------------------------+
# Program:                                                     |
#        This program help you to get the wt.in file the       | 
#        wannier90 files generate from the vasp interface.     |
#        Before run this shell script you need wannier90.win   |
#        and wannier90.wout. After running this script you     |
#        should change wt.in by yourself to do different       |
#        calculation by wanniertools                           |
# History:                                                     |
# 2021/05/3     Zhefeng Lou                                    |
# Require:                                                     |
#        vaspkit xcrysden                                      |
#--------------------------------------------------------------+


n=`cat wannier90.win | grep "num_wann" | awk '{print $3}'`
echo " $n wannier bands"



#--------------------------------------------------------------+
#                                                              |
# generate wt.in                                               |
#                                                              |
#--------------------------------------------------------------+

cat > wt.in << EOF
&TB_FILE
Hrfile = "wannier90_hr.dat"
Package = 'VASP'             ! obtained from VASP, it could be 'VASP', 'QE', 'Wien2k', 'OpenMx'
/

LATTICE
Angstrom
EOF



#--------------------------------------------------------------+
#                                                              |
# copy lattice and atom positions in wannier90.win, and write  |
# POSCAR for vaspkit to generate KPATH.in                      |
#                                                              |
#--------------------------------------------------------------+

line=`sed -n -e '/begin unit_cell_cart/=' wannier90.win`
((z=line+3))
head -n $z wannier90.win | tail -n 3 >> wt.in

#POSCAR generate

echo -e "POSCAR generate from wannier90.win \n 1.0 " > POSCAR
head -n $z wannier90.win | tail -n 3 >> POSCAR
# lattice down -------------------------------------------------
linep1=`sed -n -e '/begin projections/=' wannier90.win` # line number for projectors
linep2=`sed -n -e '/end projections/=' wannier90.win`
((npro=linep2-linep1-1))

line1=`sed -n -e '/begin atoms_cart/=' wannier90.win`
line2=`sed -n -e '/end atoms_cart/=' wannier90.win`
((natoms=line2-line1-1))
((atommax=line2-1))
#the line1 and line2 fix the lines to find the atoms

atomstr=""
atomnum=""
for ((i=1;i<=npro;i++));
	do
	((z=linep1+i))
	atomname=`head -n $z wannier90.win | tail -n 1 | awk '{print $1}'`
	atomnum1=`head -n $atommax wannier90.win | tail -n $natoms | grep -c "$atomname"`   #use grep -c to figure out how many lines
	atomstr="$atomstr  $atomname"
	atomnum="$atomnum  $atomnum1"
done
echo "$atomstr" >> POSCAR
echo "$atomnum" >> POSCAR
echo "Cartisen        ! Direct or Cartisen coordinate" >> POSCAR
((z=line2-1))
head -n $z wannier90.win | tail -n $natoms | awk '{print $2 "\t" $3 "\t" $4}'>> POSCAR	

echo " " >> wt.in
echo "ATOM_POSITIONS" >> wt.in

echo " $natoms ! number of atoms in unit cell" >> wt.in
echo "Cartisen        ! Direct or Cartisen coordinate" >> wt.in

((z=line2-1))
head -n $z wannier90.win | tail -n $natoms >> wt.in
echo " " >> wt.in
# atoms down ---------------------------------------------------

#--------------------------------------------------------------+
#                                                              |
# generate PROJECTORS depending on wannier90.win               |
#                                                              |
#--------------------------------------------------------------+


echo "PROJECTORS" >> wt.in

#linep2 linep1 npro is generate in the step of generate POSCAR

((promax=linep2-1))
str=""  #the number of orbitals in the atom
strp="" #the orbital of one atom
for ((i=1;i<=natoms;i++));
	do
	((z=line1+i));
	proj_num=0
	atomname=`head -n $z wannier90.win | tail -n 1 | awk '{print $1}'`
	pro_num=`head -n $promax wannier90.win | tail -n $npro | grep "$atomname" | awk -F "[:;]" '{print NF}'`
	
	strp="$strp$atomname"
	for ((j=2;j<=pro_num;j++));
		do
		
		strwin=`head -n $promax wannier90.win | tail -n $npro | grep "$atomname" | awk -F "[:;]" "{print \$"$j"}" | sed 's/^[ \t]*//g'` # the last one is used for deleat space in the string
		
		
		case "$strwin" in
			"p")
				strp="$strp px py pz"
				((proj_num=proj_num+3))
			;;
			"d")
				strp="$strp dz2 dxz dyz dx2-y2 dxy"
				((proj_num=proj_num+5))
			;;
			*)
				strp="$strp $strwin"
				((proj_num=proj_num+1))
			;;
		esac
		
	done
	strp="$strp \n"
	str="$str$proj_num "
done
echo "$str  ! number of projectors for each atom" >> wt.in
echo -e "$strp" >> wt.in
echo -e "\n \n" >> wt.in
# atoms down ---------------------------------------------------

#--------------------------------------------------------------+
#                                                              |
# generate the &CONTROL in default set BulkBand_calc = T       |
#                                                              |
#--------------------------------------------------------------+


#Then identify SOC is ignored or not
spin=`grep "fermi_energy" wannier90.win | grep "true"`

if [ `grep "spinors" wannier90.win | grep -c "true"` -ne '0' ]; then
	SOC="SOC = 1"
	else
	SOC="SOC = 0"
fi


# Then get the fermi energy might from the wannier90.win
if [ `grep -c "fermi_energy" wannier90.win` -ne '0' ]; then
	E_FERMI="`grep "fermi_energy" wannier90.win | awk -F "[=]" '{print $2 }' | sed 's/^[ \t]*//g'`"
	else
	echo -e " \n Please type the fermi_energy (a float). You can get it from the DOSCAR in scf calculation. "
	read E_FERMI
fi


# Then get the NumOccupied
echo -e "\n Please type the number of occupied band (the first band that cross the fermi energy). You can get it from the plot of fermi surface by run xcrysden --bxsf wannier90.bxsf."
read NumOccupied

#then use this numbers to generate the wt.in

cat >> wt.in << EOF 
&CONTROL
BulkBand_calc         = T
BulkBand_plane_calc   = F
BulkGap_plane_calc    = F
BulkFS_calc           = F
BulkFS_plane_calc     = F
FindNodes_calc        = F
SlabBand_calc         = F
SlabSS_calc           = F
SlabArc_calc          = F
SlabSpintexture_calc  = F
BerryCurvature_calc   = F
WeylChirality_calc    = F
Z2_3D_calc            = F
/

&SYSTEM
NSLAB = 10 
NSLAB1= 4  
NSLAB2= 4  
NumOccupied = ${NumOccupied}        ! NumOccupied
${SOC}                 ! if the SOC effect is included in you TB model.
E_FERMI = ${E_FERMI}          ! e-fermi
surf_onsite= 0.0        ! surf_onsite
/

&PARAMETERS
Eta_Arc = 0.001     ! infinite small value, like brodening 
E_arc = 0.0         ! energy for calculate Fermi Arc
OmegaNum = 101      ! omega number       
OmegaMin = -1     ! energy interval
OmegaMax =  1     ! energy interval
Nk1 =  101            ! number k points 
Nk2 =  51            ! number k points 
Nk3 =  51             ! number k points 
NP = 2              ! number of principle layers
Gap_threshold = 0.0001 ! threshold for GapCube output
/

SURFACE            ! See doc for details
 -1  1  0
 -1  0  1


KPATH_BULK            ! k point path
EOF


# generate k-path --------------------------------------------------------------
echo -e "\n \n"
vaspkit -task 303

echo -e "\n \n Use the vaspkit to generate kpath, you can change the kpath in wt.in by yourself. The information given by vaspkit can help you to check your structure. Files generated by vaspkit will move to vaspkitdata folder."
kpathbegin=`sed -n -e '/Reciprocal/=' KPATH.in`
kpathlast=`awk 'END{print NR}' KPATH.in`
klinenum=$(((kpathlast-kpathbegin)/3))
echo "	$klinenum	!number of k lines" >> wt.in

for ((i=1;i<=klinenum;i++));
	do
	((z=kpathbegin+3*i-2))
	head -n $z KPATH.in | tail -n 1 | awk '{printf $4 "\t" $1 "\t" $2 "\t" $3 "\t"}' >> wt.in
	((z=z+1))
	head -n $z KPATH.in | tail -n 1 | awk '{printf $4 "\t" $1 "\t" $2 "\t" $3 "\n"}' >> wt.in
done

mkdir vaspkitdata
mv HIGH_SYMMETRY_POINTS KPATH.in POSCAR POTCAR PRIMCELL.vasp SYMMETRY vaspkitdata


# kpath done
cat >> wt.in << EOF 

KPATH_SLAB
1        ! numker of k line for 2D case
G 0.0 0.0 M 0.5 0.0

KPLANE_SLAB
-0.2 -0.1      ! Original point for 2D k plane
 0.4  0.0      ! The first vector to define 2D k plane 
 0.0  0.2      ! The second vector to define 2D k plane  for arc plots

KPLANE_BULK
 1.0  1.0 1.0    ! Middle point for a k slice(plane) in 3D BZ. Usually, the position of Dirac points.
 2.00  0.00  -2.00   ! The first vector to define k plane(slice) in 3D BZ
 0.00  2.00  -2.00   ! The second vector to define k plane(slice) in 3D BZ

KCUBE_BULK
 0.00  0.00  0.00   ! Original point for 3D k plane 
 1.00  0.00  0.00   ! The first vector to define 3d k space plane
 0.00  1.00  0.00   ! The second vector to define 3d k space plane
 0.00  0.00  1.00   ! The third vector to define 3d k cube
 
WANNIER_CENTRES     ! copy from wannier90.wout
Cartesian
EOF

# generate the wannier center

line=`sed -n -e '/Final State/=' wannier90.wout`
linemax=$((line+n))

head -n $linemax wannier90.wout | tail -n $n | awk '{print $7 $8 $9}' | awk -F "[,]" '{print $1 "  " $2 "  " $3}' >> wt.in

echo -e "\n \n Finish writting wt.in, then run the wt.x"

mpirun -np 4 wt.x

echo -e "wt.x done"

echo -e "\n \n Please check the band with your DFT calculation."

 #---------------------------------------------------------
