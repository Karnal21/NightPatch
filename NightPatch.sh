#!/bin/sh
VERSION=99
BUILD=

if [[ "${1}" == help || "${1}" == "-help" || "${1}" == "--help" ]]; then
	echo "./NightPatch.sh : Patch macOS."
	echo "I introduce a few NightPatch options."
	echo
	echo "./NightPatch.sh [option]"
	echo "-revert : Revert using backup."
	echo "-revert combo : Revert using macOS Combo uptate. (works without backup)"
	echo "-skipCheckSHA : Skip checking SHA1 verification."
	echo "-customBuild : Set fake system build."
	echo "-verbose : verbose mode."
	echo
	echo "example)"
	echo "$ ./NightPatch.sh -revert combo -customBuild"
	echo "$ ./NightPatch.sh -skipCheckSHA -verbose"
	exit 0
fi

function removeTmp(){
	if [[ -f /tmp/NightPatch.zip ]]; then
		rm /tmp/NightPatch.zip
	fi
	if [[ -d /tmp/NightPatch-master ]]; then
		rm -rf /tmp/NightPatch-master
	fi
	cleanComboProcess
}

function cleanComboProcess(){
	if [[ -d /tmp/NightPatch-tmp ]]; then
		echo "Cleaning..."
		if [[ -d /tmp/NightPatch-tmp/macOSUpdate ]]; then
			if [[ "${verbose}" == YES ]]; then
				hdiutil eject /tmp/NightPatch-tmp/macOSUpdate
			else
				hdiutil eject /tmp/NightPatch-tmp/macOSUpdate > /dev/null 2>&1
			fi
			if [[ -d /tmp/NightPatch-tmp/macOSUpdate ]]; then
				rm -rf /tmp/NightPatch-tmp/macOSUpdate
			fi
		fi
		rm -rf /tmp/NightPatch-tmp
	fi
}

function revertSystem(){
	if [[ -f /Library/NightPatch/NightPatchBuild ]]; then
		if [[ "$(cat /Library/NightPatch/NightPatchBuild)" == "${SYSTEM_BUILD}" ]]; then
			if [[ ! "${1}" == "-doNotPrint" && ! "${2}" == "-doNotPrint" && ! "${3}" == "-doNotPrint" ]]; then
				echo "Reverting..."
			fi
			if [[ -f /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness ]]; then
				sudo rm /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness
			fi
			if [[ -d /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/_CodeSignature ]]; then
				sudo rm -rf /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/_CodeSignature
			fi
			sudo cp /Library/NightPatch/CoreBrightness.bak /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness
			sudo cp -r /Library/NightPatch/_CodeSignature.bak /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/_CodeSignature
			chmod +x /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness
			codesignCB
			if [[ "${1}" == "-rebootMessage" || "${2}" == "-rebootMessage" || "${3}" == "-rebootMessage" ]]; then
				echo "Done. Please reboot your Mac to complete."
			fi
			if [[ ! "${1}" == "-doNotQuit" && ! "${2}" == "-doNotQuit" && ! "${3}" == "-doNotQuit" ]]; then
				quitTool0
			fi
		else
			echo "This backup is not for this macOS. Seems like you've updated your macOS."
			if [[ ! "${1}" == "-doNotQuit" && ! "${2}" == "-doNotQuit" ]]; then
				quitTool1
			fi
		fi
	else
		if [[ -f "combo/url-${SYSTEM_BUILD}.txt" ]]; then
			showLines "*"
			echo "\033[1;31mERROR : No backup.\033[0m"
			echo "If you want to download a original macOS system file from Apple, try this command \033[1;31mwithout $\033[0m. (takes a few minutes)"
			echo
			showCommandGuide "-revert combo"
			echo
			showLines "*"
		else
			echo "\033[1;31mERROR : No backup.\033[0m"
		fi
		if [[ ! "${1}" == "-doNotQuit" && ! "${2}" == "-doNotQuit" ]]; then
			quitTool1
		fi
	fi
}

function revertUsingCombo(){
	if [[ -f "combo/url-${SYSTEM_BUILD}.txt" ]]; then
		if [[ ! -d "$(xcode-select -p)" ]]; then
			echo "\033[1;31mERROR : Requires Command Line Tool.\033[0m Enter 'xcode-select --install' command to install this."
			quitTool1
		fi
		if [[ ! -d /usr/local/Cellar/xz ]]; then
			showLines "*"
			echo "\033[1;31mERROR : Requires lzma.\033[0m"
			echo "1. Install Homebrew. https://brew.sh"
			echo "2. Enter 'brew install xz' command to install."
			echo
			showLines "*"
			quitTool1
		fi
		if [[ ! -f /tmp/update.dmg ]]; then
			downloadCombo
		fi
		if [[ ! "${skipCheckSHA}" == YES ]]; then
			echo "Checking downloaded file..."
			if [[ ! -f "combo/sha-${SYSTEM_BUILD}.txt" ]]; then
				echo "\033[1;31mERROR : I can't find combo/sha-${SYSTEM_BUILD}.txt file.\033[0m"
				quitTool1
			fi
			if [[ ! "$(shasum /tmp/update.dmg | awk '{ print $1 }')" == "$(cat "combo/sha-${SYSTEM_BUILD}.txt")" ]]; then
				echo "\033[1;31mERROR : Downloaded file is wrong. Downloading again...\033[0m"
				downloadCombo
				echo "Checking downloaded file..."
				if [[ ! "$(shasum /tmp/update.dmg | awk '{ print $1 }')" == "$(cat "combo/sha-${SYSTEM_BUILD}.txt")" ]]; then
					echo "\033[1;31mERROR : SHA not matching.\033[0m"
					quitTool1
				fi
			fi
		fi
		cleanComboProcess
		mkdir /tmp/NightPatch-tmp
		# See https://github.com/NiklasRosenstein/pbzx
		echo "Downloading pbzx-master... (https://github.com/NiklasRosenstein/pbzx)"
		if [[ "${verbose}" == YES ]]; then
			curl -o /tmp/NightPatch-tmp/pbzx-master.zip https://codeload.github.com/NiklasRosenstein/pbzx/zip/master
			unzip -o /tmp/NightPatch-tmp/pbzx-master.zip -d /tmp/NightPatch-tmp
		else
			curl -o /tmp/NightPatch-tmp/pbzx-master.zip https://codeload.github.com/NiklasRosenstein/pbzx/zip/master > /dev/null 2>&1
			unzip -o /tmp/NightPatch-tmp/pbzx-master.zip -d /tmp/NightPatch-tmp > /dev/null 2>&1
		fi
		cd /tmp/NightPatch-tmp/pbzx-master
		echo "Compiling pbzx..."
		clang -llzma -lxar -I /usr/local/include pbzx.c -o pbzx
		cp pbzx /tmp/NightPatch-tmp
		if [[ ! -f /tmp/NightPatch-tmp/pbzx ]]; then
			echo "\033[1;31mERROR : Failed to compile pbzx.\033[0m"
			quitTool1
		fi
		if [[ -d /tmp/NightPatch-tmp/macOSUpdate ]]; then
			if [[ "${verbose}" == YES ]]; then
				hdiutil eject /tmp/NightPatch-tmp/macOSUpdate
			else
				hdiutil eject /tmp/NightPatch-tmp/macOSUpdate > /dev/null 2>&1
			fi
			if [[ -d /tmp/NightPatch-tmp/macOSUpdate ]]; then
				rm -rf /tmp/NightPatch-tmp/macOSUpdate
			fi
		fi
		if [[ "${verbose}" == YES ]]; then
			hdiutil attach /tmp/update.dmg -mountpoint /tmp/NightPatch-tmp/macOSUpdate
		else
			hdiutil attach /tmp/update.dmg -mountpoint /tmp/NightPatch-tmp/macOSUpdate > /dev/null 2>&1
		fi
		echo "\033[1;36mDO NOT OPEN $(ls /tmp/NightPatch-tmp/macOSUpdate).\033[0m"
		echo "Extracting... (1)"
		pkgutil --expand /tmp/NightPatch-tmp/macOSUpdate/* /tmp/NightPatch-tmp/1
		cd /tmp/NightPatch-tmp/1/macOSUpdCombo*
		if [[ ! -f Payload ]]; then
			echo "\033[1;31mERROR : Failed to extract pkg file.\033[0m"
			quitTool1
		fi
		mv Payload /tmp/NightPatch-tmp
		if [[ -d /tmp/NightPatch-tmp/2 ]]; then
			rm -rf /tmp/NightPatch-tmp/2
		fi
		mkdir /tmp/NightPatch-tmp/2
		cd /tmp/NightPatch-tmp/2
		echo "Extracting... (2)"
		if [[ "${verbose}" == YES ]]; then
			/tmp/NightPatch-tmp/pbzx -n /tmp/NightPatch-tmp/Payload | cpio -i
		else
			/tmp/NightPatch-tmp/pbzx -n /tmp/NightPatch-tmp/Payload | cpio -i > /dev/null 2>&1
		fi
		echo "Creating backup from update..."
		if [[ ! -f /tmp/NightPatch-tmp/2/System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness ]]; then
			echo "\033[1;31mERROR : CoreBrightness file not found.\033[0m"
			quitTool1
		fi
		if [[ -d /Library/NightPatch ]]; then
			sudo rm -rf /Library/NightPatch
		fi
		sudo mkdir /Library/NightPatch
		sudo cp /tmp/NightPatch-tmp/2/System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness /Library/NightPatch/CoreBrightness.bak
		sudo cp -r /tmp/NightPatch-tmp/2/System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/_CodeSignature /Library/NightPatch/_CodeSignature.bak
		if [[ -f /tmp/NightPatchBuild ]]; then
			sudo rm /tmp/NightPatchBuild
		fi
		echo "${SYSTEM_BUILD}" >> /tmp/NightPatchBuild
		sudo mv /tmp/NightPatchBuild /Library/NightPatch
		echo "Reverting from backup..."
		revertSystem -rebootMessage -doNotPrint
	else
		echo "\033[1;31mERROR : Your macOS is not supported. (${SYSTEM_BUILD})\033[0m"
		quitTool1
	fi
}

function downloadCombo(){
	if [[ ! -f "combo/url-${SYSTEM_BUILD}.txt" ]]; then
		echo "\033[1;31mERROR : I can't find combo/url-${SYSTEM_BUILD}.txt file.\033[0m"
		quitTool1
	fi
	if [[ -z "$(cat "combo/url-${SYSTEM_BUILD}.txt")" ]]; then
		echo "\033[1;31mERROR : combo/url-${SYSTEM_BUILD}.txt is wrong.\033[0m"
		quitTool1
	fi
	echo "Downloading update... (takes a few minutes)"
	if [[ "${verbose}" == YES ]]; then
		curl -o /tmp/update.dmg "$(cat "combo/url-${SYSTEM_BUILD}.txt")"
	else
		curl -o /tmp/update.dmg "$(cat "combo/url-${SYSTEM_BUILD}.txt")" > /dev/null 2>&1
	fi
	if [[ ! -f /tmp/update.dmg ]]; then
		echo "\033[1;31mERROR : Failed to download file.\033[0m"
		quitTool1
	fi
}

function moveOldBackup(){
	# Version 1~38
	if [[ -d ~/_CodeSignature.bak ]]; then
		if [[ ! -d ~/Library/NightPatch ]]; then
			mkdir ~/Library/NightPatch
		fi
		if [[ -d ~/Library/NightPatch/_CodeSignature.bak ]]; then
			rm -rf ~/Library/NightPatch/_CodeSignature.bak
		fi
		echo "Move : ~/_CodeSignature.bak >> ~/Library/NightPatch"
		mv ~/_CodeSignature.bak ~/Library/NightPatch
	fi
	if [[ -f ~/CoreBrightness.bak ]]; then
		if [[ ! -d ~/Library/NightPatch ]]; then
			mkdir ~/Library/NightPatch
		fi
		if [[ -f ~/Library/NightPatch/CoreBrightness.bak ]]; then
			rm ~/Library/NightPatch/CoreBrightness.bak
		fi
		echo "Move : ~/CoreBrightness.bak >> ~/Library/NightPatch"
		mv ~/CoreBrightness.bak ~/Library/NightPatch
	fi
	if [[ -f ~/NightPatchBuild ]]; then
		if [[ ! -d ~/Library/NightPatch ]]; then
			mkdir ~/Library/NightPatch
		fi
		if [[ -f ~/Library/NightPatch/NightPatchBuild ]]; then
			rm ~/Library/NightPatch/NightPatchBuild
		fi
		echo "Move : ~/NightPatchBuild >> ~/Library/NightPatch"
		mv ~/NightPatchBuild ~/Library/NightPatch
	fi

	# Version 39~40
	if [[ -d ~/Library/NightPatch/_CodeSignature.bak ]]; then
		if [[ ! -d /Library/NightPatch ]]; then
			sudo mkdir /Library/NightPatch
		fi
		if [[ -d /Library/NightPatch/_CodeSignature.bak ]]; then
			sudo rm -rf /Library/NightPatch/_CodeSignature.bak
		fi
		echo "Move : ~/Library/NightPatch/_CodeSignature.bak >> /Library/NightPatch"
		sudo mv ~/Library/NightPatch/_CodeSignature.bak /Library/NightPatch
	fi
	if [[ -f ~/Library/NightPatch/CoreBrightness.bak ]]; then
		if [[ ! -d /Library/NightPatch ]]; then
			sudo mkdir /Library/NightPatch
		fi
		if [[ -f /Library/NightPatch/CoreBrightness.bak ]]; then
			sudo rm /Library/NightPatch/CoreBrightness.bak
		fi
		echo "Move : ~/Library/NightPatch/CoreBrightness.bak >> /Library/NightPatch"
		sudo mv ~/Library/NightPatch/CoreBrightness.bak /Library/NightPatch/CoreBrightness.bak
	fi
	if [[ -f ~/Library/NightPatch/NightPatchBuild ]]; then
		if [[ ! -d /Library/NightPatch ]]; then
			sudo mkdir /Library/NightPatch
		fi
		if [[ -f /Library/NightPatch/NightPatchBuild ]]; then
			sudo rm /Library/NightPatch/NightPatchBuild
		fi
		echo "Move : ~/Library/NightPatch/NightPatchBuild >> /Library/NightPatch"
		sudo mv ~/Library/NightPatch/NightPatchBuild /Library/NightPatch/NightPatchBuild
	fi
	if [[ -d ~/Library/NightPatch ]]; then
		sudo rm -rf ~/Library/NightPatch
	fi
}

function checkSHA(){
	if [[ -f "sha/sha-${SYSTEM_BUILD}_${1}.txt" ]]; then
		if [[ ! "$(cat "sha/sha-${SYSTEM_BUILD}_${1}.txt")" == "$(shasum /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness | awk '{ print $1 }')" ]]; then
			showLines "*"
			if [[ "${customBuild}" == YES ]]; then
				echo "\033[1;31mERROR : SHA not matching. Patch was failed.\033[0m (c-$(sw_vers -buildVersion)) (${SYSTEM_BUILD}-${1}-$(shasum /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness | awk '{ print $1 }'))"
			else
				echo "\033[1;31mERROR : SHA not matching. Patch was failed.\033[0m (${SYSTEM_BUILD}-${1}-$(shasum /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness | awk '{ print $1 }'))"
			fi
			echo "Seems like your macOS system file was damaged or already patched by other tool."
			if [[ -f "combo/url-${SYSTEM_BUILD}.txt" ]]; then
				echo "Try this command to repair system file. \033[1;31mDo not type $\033[0m. (takes a few minutes)"
				echo
				showCommandGuide "-revert combo"
			fi
			echo
			echo "If you want to patch your macOS by force, Try this command but this is not recommended. \033[1;31mDo not type $\033[0m."
			echo
			showCommandGuide "-skipCheckSHA"
			echo
			showLines "*"
			revertSystem -doNotQuit
			quitTool1
		fi
	else
		showLines "*"
		echo "\033[1;31mERROR : SHA file not found.\033[0m"
		echo "If you want to patch your macOS by force, Try this command but this is not recommended. \033[1;31mDo not type $.\033[0m"
		echo
		showCommandGuide "-skipCheckSHA"
		echo
		showLines "*"
		revertSystem -doNotQuit
		quitTool1
	fi
}

function showCommandGuide(){
	if [[ "$(pwd)" == /tmp/NightPatch-master ]]; then
		echo "\033[1;31m$\033[0m cd /tmp; curl -s -o NightPatch.zip https://codeload.github.com/pookjw/NightPatch/zip/master; unzip -o -qq NightPatch.zip; cd NightPatch-master; chmod +x NightPatch.sh; ./NightPatch.sh ${1}"
	else
		echo "\033[1;31m$\033[0m ./NightPatch.sh ${1}"
	fi
}

function checkSystem(){
	if [[ "$(sw_vers -productVersion | cut -d"." -f2)" -lt 12 ]]; then
		MACOS_ERROR=YES
	elif [[ "$(sw_vers -productVersion | cut -d"." -f2)" == 12 ]]; then
		if [[ "$(sw_vers -productVersion | cut -d"." -f3)" -lt 4 ]]; then
			MACOS_ERROR=YES
		fi
	fi
	if [[ "${MACOS_ERROR}" == YES ]]; then
		echo "\033[1;31mERROR : Requires macOS 10.12.4 or higher.\033[0m (Detected version : $(sw_vers -productVersion))"
		quitTool1
	fi
	if [[ ! "$(csrutil status)" == "System Integrity Protection status: disabled." ]]; then
		echo "\033[1;31mERROR : Turn off System Integrity Protection before doing this.\033[0m"
		quitTool1
	fi
}

function patchSystem(){
	if [[ ! -d patch ]]; then
		echo "\033[1;31mERROR : I can't find patch folder. Try again.\033[0m"
		quitTool1
	fi
	if [[ ! -f "patch/${SYSTEM_BUILD}.patch" ]]; then
		echo "\033[1;31mERROR : I can't find patch/${SYSTEM_BUILD}.patch file.\033[0m (seems like not supported macOS)"
		quitTool1
	fi
	if [[ -f /Library/NightPatch/NightPatchBuild ]]; then
		if [[ "$(cat /Library/NightPatch/NightPatchBuild)" == "${SYSTEM_BUILD}" ]]; then
			if [[ "${verbose}" == YES ]]; then
				echo "Detected backup. Reverting..."
			fi
			revertSystem -doNotQuit -doNotPrint
			if [[ "${verbose}" == YES ]]; then
				echo "Patching again..."
			fi
		fi
	fi
	if [[ -d /Library/NightPatch ]]; then
		sudo rm -rf /Library/NightPatch
	fi
	sudo mkdir /Library/NightPatch
	if [[ -f /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness-patch ]]; then
		sudo rm /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness-patch
	fi
	sudo cp /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness /Library/NightPatch/CoreBrightness.bak
	sudo cp -r /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/_CodeSignature /Library/NightPatch/_CodeSignature.bak
	if [[ -f /tmp/NightPatchBuild ]]; then
		sudo rm /tmp/NightPatchBuild
	fi
	echo "${SYSTEM_BUILD}" >> /tmp/NightPatchBuild
	sudo mv /tmp/NightPatchBuild /Library/NightPatch
	codesignCB
	if [[ ! "${skipCheckSHA}" == YES ]]; then
		checkSHA original
	fi
	sudo bspatch /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness-patch "patch/${SYSTEM_BUILD}.patch"
	sudo rm /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness
	sudo mv /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness-patch /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness
	sudo chmod +x /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness
	codesignCB
	if [[ "${verbose}" == YES ]]; then
		echo
	fi
	if [[ ! "${skipCheckSHA}" == YES ]]; then
		checkSHA patched
	fi
	echo "Backup was saved on \033[1;36m/Library/NightPatch\033[0m."
	echo "Patch was done. Please reboot your Mac to complete."
	quitTool0
}

function codesignCB(){
	if [[ "${verbose}" == YES ]]; then
		sudo codesign -f -s - /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness
	else
		sudo codesign -f -s - /System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness > /dev/null 2>&1
	fi
}

function checkRoot(){
	sudo touch /System/test
	if [[ ! -f /System/test ]]; then
		echo "\033[1;31mERROR : Can't write a file to root.\033[0m"
		quitTool1
	fi
	sudo rm /System/test
}

function setToolMode(){
	mode=patch
	if [[ "${1}" == "-skipCheckSHA" || "${2}" == "-skipCheckSHA" || "${3}" == "-skipCheckSHA" || "${4}" == "-skipCheckSHA" || "${5}" == "-skipCheckSHA" || "${6}" == "-skipCheckSHA" || "${7}" == "-skipCheckSHA" || "${8}" == "-skipCheckSHA" || "${9}" == "-skipCheckSHA" ]]; then
		echo "skipCheckSHA=\033[1;36mYES\033[0m"
		skipCheckSHA=YES
	fi
	if [[ "${1}" == "-customBuild" || "${2}" == "-customBuild" || "${3}" == "-customBuild" || "${4}" == "-customBuild" || "${5}" == "-customBuild" || "${6}" == "-customBuild" || "${7}" == "-customBuild" || "${8}" == "-customBuild" || "${9}" == "-customBuild" ]]; then
		echo "customBuild=\033[1;36mYES\033[0m"
		customBuild=YES
	fi
	if [[ "${1}" == "-verbose" || "${2}" == "-verbose" || "${3}" == "-verbose" || "${4}" == "-verbose" || "${5}" == "-verbose" || "${6}" == "-verbose" || "${7}" == "-verbose" || "${8}" == "-verbose" || "${9}" == "-verbose" ]]; then
		echo "verbose=\033[1;36mYES\033[0m"
		verbose=YES
	fi
	if [[ "${1}" == "-moveOldBackup" || "${2}" == "-moveOldBackup" || "${3}" == "-moveOldBackup" || "${4}" == "-moveOldBackup" || "${5}" == "-moveOldBackup" || "${6}" == "-moveOldBackup" || "${7}" == "-moveOldBackup" || "${8}" == "-moveOldBackup" || "${9}" == "-moveOldBackup" ]]; then
		echo "mode=\033[1;36mmoveOldBackup\033[0m"
		mode=moveOldBackup
	fi
	if [[ "${1}" == "-revert" || "${2}" == "-revert" || "${3}" == "-revert" || "${4}" == "-revert" || "${5}" == "-revert" || "${6}" == "-revert" || "${7}" == "-revert" || "${8}" == "-revert" || "${9}" == "-revert" ]]; then
		if [[ "${1}" == "combo" || "${2}" == "combo" || "${3}" == "combo" || "${4}" == "combo" || "${5}" == "combo" || "${6}" == "combo" || "${7}" == "combo" || "${8}" == "combo" || "${9}" == "combo" ]]; then
			echo "mode=\033[1;36mrevert \033[1;35m(combo)\033[0m"
			mode=revertUsingCombo
		else
			echo "mode=\033[1;36mrevert\033[0m"
			mode=revert
		fi
	fi
	if [[ "${mode}" == patch ]]; then
		echo "mode=\033[1;36mpatch\033[0m"
	fi
}

function setBuild(){
	if [[ "${customBuild}" == YES ]]; then
		echo "Enter custom system build. (ex: 16E195)"
		while(true); do
			read -p "- " SYSTEM_BUILD
			if [[ "${SYSTEM_BUILD}" == exit ]]; then
				quitTool0
			elif [[ ! -z "${SYSTEM_BUILD}" ]]; then
				echo "SYSTEM_BUILD=\033[1;36m${SYSTEM_BUILD}\033[0m"
				break
			fi
		done
		echo
	else
		SYSTEM_BUILD="$(sw_vers -buildVersion)"
	fi
}

function showInitialMessage(){
	showLines "*"
	echo "NightPatch.sh by @pookjw. Version : ${VERSION}"
	showLines "*"
	if [[ "${BUILD}" == beta ]]; then
		echo "**WARNING : This is beta version. I don't guarantee of any problems."
		read -s -n 1 -p "Press any key to continue..."
	fi
}

function showLines(){
	PRINTED_COUNTS=0
	COLS=`tput cols`
	if [ "${COLS}" -ge 1 ]; then
		while [[ ! ${PRINTED_COUNTS} == $COLS ]]; do
			printf "${1}"
			PRINTED_COUNTS=$((${PRINTED_COUNTS}+1))
		done
		echo
	fi
}

function quitTool0(){
	removeTmp
	exit 0
}

function quitTool1(){
	removeTmp
	exit 1
}

#########################################################################

showInitialMessage
checkSystem
checkRoot
setToolMode "${1}" "${2}" "${3}" "${4}" "${5}" "${6}" "${7}" "${8}" "${9}"
echo
setBuild
if [[ "${verbose}" == YES ]]; then
	moveOldBackup
else
	moveOldBackup  > /dev/null 2>&1
fi
if [[ "${mode}" == moveOldBackup ]]; then
	quitTool0
elif [[ "${mode}" == revertUsingCombo ]]; then
	revertUsingCombo
elif [[ "${mode}" == revert ]]; then
	revertSystem -rebootMessage
elif [[ "${mode}" == patch ]]; then
	patchSystem
fi
