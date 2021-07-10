#!/bin/bash

# Program:
#	This program helps you to use some package and tells you when your job is down. You can add some other software to help you.
# History:
#	2021/04/19	Zhefeng Lou 
# Require:
#	sendmail (You can install by sudo apt-get install sendmail) You can see this web to get some helpful information: https://blog.csdn.net/warlice/article/details/90519232
#
# Do change the email address and password.  
#	-xu  USERNAME             username for SMTP authentication
#	-xp  PASSWORD             password for SMTP authentication
#---------------------------------------------------------------------------------------------------------------------------
echo "How many cores do you want to run with? Please give a number:"
read ncore
echo -e "\n \n Which package do you whant to run "
echo -e "\n \n 1 vasp_std    2 vasp_ncl    3 wannier90.x   4  wt.x"
read a
ulimit -s unlimited
case "$a" in
	"1")
		mpirun -np $ncore vasp_std	
		str="vasp_std"	
	;;
	"2")
		mpirun -np $ncore vasp_ncl
		str="vasp_ncl"		
	;;
	"3")
		wannier90.x wannier90
		echo "wannier90.x down"
		n=`cat wannier90.win | grep "num_wann" | awk '{print $3}'`
		echo " $n wannier bands" 
		line=`sed -n -e '/Final State/=' wannier90.wout`
		((z=line+n+1))
		grep "dis_win_min =" wannier90.win
		grep "dis_win_max =" wannier90.win
		grep "dis_froz_min =" wannier90.win
		grep "dis_froz_max =" wannier90.win
		head -n $z wannier90.wout | tail -n 1 

#--------------------------------------------------------------------------------------------------------------------------------
# Save the result to wannier90fit_log
#
#--------------------------------------------------------------------------------------------------------------------------------
		if [ ! -f "./wannier90fit_log" ];then
		echo " "
		echo "Generate a wannier90fit_log file to start recording"
		echo "dis_win_min	dis_win_max	dis_froz_min	dis_froz_max	Sum_spreads"  > wannier90fit_log
		fi

		diswinmin=`cat wannier90.win | grep "dis_win_min =" | awk '{print $3}'`
		diswinmax=`cat wannier90.win | grep "dis_win_max =" | awk '{print $3}'`
		disfrozmin=`cat wannier90.win | grep "dis_froz_min =" | awk '{print $3}'`
		disfrozmax=`cat wannier90.win | grep "dis_froz_max =" | awk '{print $3}'`
		totalspread=`head -n $z wannier90.wout | tail -n 1 | awk '{print $10}'`
		echo "$diswinmin	$diswinmax	$disfrozmin	$disfrozmax	$totalspread" >> wannier90fit_log
		str="wannier90.x"		
	;;
	"4")
		mpirun -np $ncore wt.x
		str="wt.x"		
	;;
	*)
		echo "wrong number"		
	;;
esac
echo -e "\n \n Job down and send you an E-mail.... \n \n"
sendEmail  -xu USERNAME@qq.com -xp PASSWORD -t USERNAME@qq.com -u "$str down" -m "$str down" -s smtp.qq.com  -f USERNAME@qq.com

#---------------------------------------------------------
