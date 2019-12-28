# Example
# sh ./update.sh cordova/cordova-plugin-document-reader-core full fullrfid Release Release + + fullrfid Beta +
#1) path to module
#2) ios core name
#3) android core name
#4) ios core branch(Beta or Release)
#5) android core branch(Beta or Release)
#6) ios core version
#7) android core version
#8) core name for module name(if mrz, module name will be changed to cordova-plugin-document-reader-core-mrz in package.json)
#9) module branch(Beta or Release, if Beta, module name will be changed to cordova-plugin-document-reader-core-CORENAME-beta in package.json)
#10) module version
Base_path=$1
Core_ios=$2
Core_android=$3
Branch_ios=$4
Branch_android=$5
Version_ios=$6
Version_android=$7
Destination_core=$8
Destination_type=$9
Cordova_module_version=${10}
PODS_URL='https://pods.regulaforensics.com/'
MAVEN_URL_RELEASE='http://maven.regulaforensics.com/RegulaDocumentReader/com/regula/documentreader/'
MAVEN_URL_BETA='http://maven.regulaforensics.com/RegulaDocumentReader/Beta/com/regula/documentreader/'
podName="DocumentReader"
if [ $Core_ios == "creditcard" ];
then
	podName="BankCard"
elif [ $Core_ios == "barcode" ];
then
	podName="Barcode"
elif [ $Core_ios == "bounds" ];
then
	podName="Bounds"
elif [ $Core_ios == "full" ];
then
	podName="Full"
elif [ $Core_ios == "mrz" ];
then
	podName="MRZ"
elif [ $Core_ios == "barcodemrz" ];
then
	podName="MRZBarcode"
elif [ $Core_ios == "ocrandmrz" ];
then
	podName="OCR"
elif [ $Core_ios == "ocrandmrzcc" ];
then
	podName="OCRBankCard"
elif [ $Core_ios == "doctype" ];
then
  podName="DocType"
else
	exit 1
fi

if [ $Branch_ios == "Beta" ];
then
	podName="${podName}Beta"
    STATE_IOS='Beta'
else
	if [ $Branch_ios == "Release" ];
	then
		STATE_IOS=''
	else
		echo "Incorrect ios type(must be Beta or Release)"
		exit 1
	fi
fi
if [ $Branch_android == "Beta" ];
then
    STATE_ANDROID='Beta'
	URL_ANDROID=$MAVEN_URL_BETA
else
	if [ $Branch_android == "Release" ];
	then
		STATE_ANDROID=''
		URL_ANDROID=$MAVEN_URL_RELEASE
	else
		echo "Incorrect android type(must be Beta or Release)"
		exit 1
	fi
fi
if [ $Destination_type == 'Beta' ]; then
    DEST_TYPE='-beta'
else
	if [ $Destination_type == 'Release' ]; then
		DEST_TYPE=''
	else
		echo "Incorrect destination type(must be Beta or Release)"
		exit 1
	fi
fi
PKG_NAME="cordova-plugin-document-reader-core-$Destination_core$DEST_TYPE"
if [ "$Cordova_module_version" == '+' ]; then
	LatestModuleVersion="$(sudo npm view $PKG_NAME version)"
	Cordova_module_version="${LatestModuleVersion%.*}.$((${LatestModuleVersion##*.}+1))"
fi
if [ "$Cordova_module_version" == '.1' ]; then
	Cordova_module_version='0.0.1'
	ModuleIsNew='(new)'
fi

if [ "$Version_ios" == '+' ]; then
    /usr/local/bin/wget -O index.html "$PODS_URL$podName/"
    if [[ $? -ne 0 ]]; then
        echo "Failed on wget call for $PODS_URL$podName/"
    	exit 1
    fi
    size=$(xmllint --html -xpath "count(//a)" index.html)
    count=$(( size - 2 ))
    v=$(xmllint --html -xpath "//html/body/table/tr[$count]/td[2]/a/text()" index.html)
    Version_ios=${v:0:${#v}-1}
    rm index.html
fi
if [ "$Version_android" == '+' ]; then
    MAVEN_MATADATA="$URL_ANDROID$Core_android/core/maven-metadata.xml"
    /usr/local/bin/wget -O maven-metadata.xml $MAVEN_MATADATA
    if [[ $? -ne 0 ]]; then
        echo "Failed on wget call for $MAVEN_MATADATA"
    	exit 1
    fi
    Version_android=$(xmllint --xpath 'string(//metadata/versioning/release)' maven-metadata.xml)
    rm maven-metadata.xml
fi

/usr/local/bin/wget -O DocumentReaderCoreAndroidTemp.zip $URL_ANDROID$Core_android/core/$Version_android/core-$Version_android.aar
if [[ $? -ne 0 ]]; then
    echo "Failed on wget call for android: $URL_ANDROID$Core_android/core/$Version_android/core-$Version_android.aar"
	exit 1
fi

rm DocumentReaderCoreAndroidTemp.zip

cd "$Base_path/script/"

cp -RfXv documentreader.gradle "$Base_path/src/android/"
sed -i -e "s/version_place_holder/$Version_android/" "$Base_path/src/android/documentreader.gradle"
sed -i -e "s/core_place_holder/$Core_android/" "$Base_path/src/android/documentreader.gradle"
rm -fr "$Base_path/src/android/documentreader.gradle-e"

cp -RfXv plugin.xml "$Base_path/"
sed -i -e "s/pkg_name_place_holder/$PKG_NAME/" "$Base_path/plugin.xml"
sed -i -e "s/version_place_holder/$Cordova_module_version/" "$Base_path/plugin.xml"
rm -fr "$Base_path/plugin.xml-e"

/usr/local/bin/wget -O DocumentReaderCore.zip $PODS_URL$podName/$Version_ios/DocumentReaderCore${STATE_IOS}_${Core_ios}_$Version_ios.zip
if [[ $? -ne 0 ]]; then
    echo "Failed on wget call for ios: $PODS_URL$podName/$Version_ios/DocumentReaderCore${STATE_IOS}_${Core_ios}_$Version_ios.zip"
	exit 1
fi
cp DocumentReaderCore.zip "$Base_path/src/ios/"
rm DocumentReaderCore.zip
cd "$Base_path/src/ios/"
rm -fr DocumentReaderCore.framework
unzip -P pcp9100 DocumentReaderCore.zip
rm -fr __MACOSX
rm DocumentReaderCore.zip

cd "$Base_path"
/usr/local/bin/jq --arg PKG_NAME "$PKG_NAME" '.name = $PKG_NAME' package.json > tmp.$$.json && mv tmp.$$.json package.json
/usr/local/bin/jq --arg Cordova_module_version "$Cordova_module_version" '.version = $Cordova_module_version' package.json > tmp.$$.json && mv tmp.$$.json package.json
/usr/local/bin/jq --arg PKG_NAME "$PKG_NAME" '.cordova.id = $PKG_NAME' package.json > tmp.$$.json && mv tmp.$$.json package.json

sudo /usr/local/bin/npm publish

echo ''
echo 'SUCCESS!'
echo ''
echo "Android: $Branch_android $Core_android $Version_android"
echo "IOS: $Branch_ios $Core_ios $Version_ios"
echo "Module: $Destination_type $Cordova_module_version$ModuleIsNew"
echo ''