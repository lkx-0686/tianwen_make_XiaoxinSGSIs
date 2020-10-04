#!/bin/bash

#from 迷路的小新大大
#action适配 by Pinkdoge

source ./bin.sh

#静态制作

rm -rf ./out
rm -rf ./SGSI
mkdir ./out

if [ -e ./vendor.img ];then

 echo "解压vendor.img中......"
 python3 $bin/imgextractor.py ./vendor.img ./out
fi

echo "解压system.img中......"
python3 $bin/imgextractor.py ./system.img ./out

cd ./make
./new_fs.sh
cd ../

model="$(cat ./out/system/system/build.prop | grep 'model' | cat)"
echo "当前原包机型为:"
echo "$model"

function normal (){

 echo "当前为正常pt 启用正常处理方案"

 read -p "按任意键开始处理" var
 echo "SGSI化处理开始......."
 
 echo "正在修改system外层"
 cd ./make/ab_boot
 ./ab_boot.sh
 cd ../../
 echo "修改完成"
 
 if [ -e ./out/vendor/euclid/ ];then
  echo "检测到OPPO_Color 启用专用处理......."
  ./oppo.sh
  echo "处理完成 请检查细节部分"
 else
  if [ -e ./out/vendor/oppo/ ];then  
   echo "检测到OPPO_Color 启用专用处理......."
   ./oppo.sh
   echo "处理完成 请检查细节部分"
  fi
 fi

 #重置make
 echo "正在重置make文件夹数据....."
 true > ./make/add_etc/vintf/manifest2
 echo "" >> ./make/add_etc/vintf/manifest2
 echo "<!-- oem自定义接口 -->" >> ./make/add_etc/vintf/manifest2

 true > ./make/add_build/build2
 echo "" >> ./make/add_build/build2
 echo "#oem厂商自定义属性" >> ./make/add_build/build2

 true > ./make/add_build/build3
 echo "" >> ./make/add_build/build3
 echo "#oem厂商odm自定义属性" >> ./make/add_build/build3
 echo "重置完成"

 echo "" > /dev/null 2>&1
 
 #系统种类检测
 cd ./make
 ./romtype.sh
 cd ../
 
 #抓logcat
 cp -frp ./make/cp_logcat/bin/* ./out/system/system/bin/
 cp -frp ./make/cp_logcat/etc/* ./out/system/system/etc/

 #manifest.xml处理
 rm -rf ./vintf
 rm -rf ./temp
 mkdir ./vintf
 mkdir ./temp

 cp -frp $(find ./out/system/ -type f -name 'manifest.xml') ./vintf/

 manifest="./vintf/manifest.xml"

 if [ ! $manifest = "" ];then
  cp -frp $manifest ./temp/manifest.xml
  rm -rf $manifest
  while IFS= read -r line ;do
  $flag && echo "$line" >> $manifest
   if [ "$line" = "    </vendor-ndk>" ];then
    flag=false
   fi
   if ! $flag && [ "$line" = "    <system-sdk>" ];then
    flag=true 
    cat ./make/add_etc/vintf/manifest1 >> $manifest
    cat ./make/add_etc/vintf/manifest2 >> $manifest
    echo "" >> $manifest
    echo "$line" >> $manifest
   fi
  done < ./temp/manifest.xml
 fi
 cp -frp $manifest ./out/system/system/etc/vintf/
 rm -rf ./vintf
 rm -rf ./temp
 rm -rf ./make/add_etc/vintf/*.bak

 #usb通用化处理
 cp -frp ./make/cp_usb/* ./out/system/

 #selinux通用化处理
 sed -i "/typetransition location_app/d" ./out/system/system/etc/selinux/plat_sepolicy.cil
 sed -i '/vendor/d' ./out/system/system/etc/selinux/plat_property_contexts
 sed -i 's/sys.usb.config          u:object_r:system_radio_prop:s0//g' ./out/system/system/etc/selinux/plat_property_contexts
 sed -i 's/ro.build.fingerprint    u:object_r:fingerprint_prop:s0//g' ./out/system/system/etc/selinux/plat_property_contexts

 #qssi机型修复
 qssi (){
  cat ./out/system/system/build.prop | grep -o 'qssi' > /dev/null 2>&1
 }
 if qssi ;then
  echo "检测到原包为qssi 启用机型参数修复" 
  
  brand=$(cat ./out/vendor/build.prop | grep 'ro.product.vendor.brand')
  device=$(cat ./out/vendor/build.prop | grep 'ro.product.vendor.device')
  manufacturer=$(cat ./out/vendor/build.prop | grep 'ro.product.vendor.manufacturer')
  model=$(cat ./out/vendor/build.prop | grep 'ro.product.vendor.model')
  mame=$(cat ./out/vendor/build.prop | grep 'ro.product.vendor.name')
  
  echo "当前原包机型参数为:"
  echo "$brand"
  echo "$device"
  echo "$manufacturer"
  echo "$model"
  echo "$mame"
  
  echo "正在修复"
  sed -i '/ro.product.system./d' ./out/system/system/build.prop
  echo "" >> ./out/system/system/build.prop
  echo "#设备参数" >> ./out/system/system/build.prop
  echo "$brand" >> ./out/system/system/build.prop
  echo "$device" >> ./out/system/system/build.prop
  echo "$manufacturer" >> ./out/system/system/build.prop
  echo "$model" >> ./out/system/system/build.prop
  echo "$mame" >> ./out/system/system/build.prop
  sed -i 's/ro.product.vendor./ro.product./g' ./out/system/system/build.prop
  echo "修复完成"
 fi

 #build处理
 sed -i '/ro.apex.updatable/d' ./out/system/system/build.prop
 sed -i '/ro.apex.updatable/d' ./out/system/system/product/build.prop
 echo "" >> ./out/system/system/build.prop
 echo "#关闭apex更新" >> ./out/system/system/build.prop
 echo "ro.apex.updatable=false" >> ./out/system/system/build.prop
 sed -i 's/ro.product.system./ro.product./g' ./out/system/system/build.prop
 #sed -i '/ro.build.ab_update/d' ./out/system/system/build.prop
 sed -i '/system_root_image/d' ./out/system/system/build.prop
 sed -i '/ro.control_privapp_permissions/d' ./out/system/system/build.prop 
 sed -i 's/ro.sf.lcd/#&/' ./out/system/system/build.prop
 sed -i 's/ro.sf.lcd/#&/' ./out/system/system/product/build.prop
 cat ./make/add_build/build1 >> ./out/system/system/build.prop
 cat ./make/add_build/build2 >> ./out/system/system/build.prop
 cat ./make/add_build/build3 >> ./out/system/system/build.prop
 rm -rf ./make/add_build/*.bak

 mainkeys="$(grep 'qemu.hw.mainkeys=' ./out/system/system/build.prop)"
 if [ $mainkeys ];then
  sed -i 's/qemu.hw.mainkeys\=1/qemu.hw.mainkeys\=0/g' ./out/system/system/build.prop
 else
  echo "" >> ./out/system/system/build.prop
  echo "#启用虚拟键" >> ./out/system/system/build.prop
  echo "qemu.hw.mainkeys=0" >> ./out/system/system/build.prop
 fi

 #删除多余文件
 rm -rf ./out/system/verity_key
 rm -rf ./out/system/sbin/dashd
 rm -rf ./out/system/system/recovery-from-boot.p
 rm -rf ./out/system/system/recovery-from-boot.bak
 rm -rf ./out/system/system/priv-app/com.qualcomm.location
 rm -rf ./out/system/system/etc/permissions/qti_permissions.xml
 rm -rf ./out/system/system/app/FidoAuthen
 rm -rf ./out/system/system/app/FidoClient
 rm -rf ./out/system/system/app/MiuiBugReport
 rm -rf ./out/system/system/app/MSA
 rm -rf ./out/system/system/app/GFManager
 rm -rf ./out/system/system/app/GFTest
 rm -rf ./out/system/system/app/FrequentPhrase
 rm -rf ./out/system/system/app/Traceur
 rm -rf ./out/system/system/app/BasicDreams
 rm -rf ./out/system/system/app/CatchLog
 rm -rf ./out/system/system/app/greenguard
 rm -rf ./out/system/system/app/Joyose
 rm -rf ./out/system/system/app/mab
 rm -rf ./out/system/system/app/HybridAccessory
 rm -rf ./out/system/system/app/HybridPlatform
 rm -rf ./out/system/system/app/Cit
 rm -rf ./out/system/system/app/Mipay
 rm -rf ./out/system/system/app/Misound
 rm -rf ./out/system/system/app/MiPlayClient
 rm -rf ./out/system/system/app/AnalyticsCore
 rm -rf ./out/system/system/app/KSICibaEngine
 rm -rf ./out/system/system/app/MiLinkService2
 rm -rf ./out/system/system/app/MiuiAccessibility
 rm -rf ./out/system/system/app/MiuiBugReport
 rm -rf ./out/system/system/app/PaymentService
 rm -rf ./out/system/system/app/PrintRecommendationService
 rm -rf ./out/system/system/app/PrintSpooler
 rm -rf ./out/system/system/app/SensorTestTool
 rm -rf ./out/system/system/app/YouDaoEngine
 rm -rf ./out/system/system/priv-app/MiuiCamera
 rm -rf ./out/system/system/priv-app/MiuiVideo
 rm -rf ./out/system/system/priv-app/MiGameCenterSDKService
 rm -rf ./out/system/system/priv-app/BackupRestoreConfirmation
 rm -rf ./out/system/system/priv-app/Backup
 rm -rf ./out/system/system/priv-app/Calendar
 rm -rf ./out/system/system/priv-app/NewHome
 rm -rf ./out/system/system/priv-app/QuickSearchBox
 rm -rf ./out/system/system/data-app/GameCenter
 rm -rf ./out/system/system/data-app/Health
 rm -rf ./out/system/system/data-app/MiLiveAssistant
 rm -rf ./out/system/system/data-app/SmartTravel
 rm -rf ./out/system/system/data-app/VipAccount
 rm -rf ./out/system/system/data-app/Weather
 rm -rf ./out/system/system/data-app/XMPass
 rm -rf ./out/system/system/app/AiAsstVision
 rm -rf ./out/system/system/app/BookmarkProvider
 rm -rf ./out/system/system/app/BuiltInPrintService
 rm -rf ./out/system/system/app/CameraTools
 rm -rf ./out/system/system/app/CarrierDefaultApp
 rm -rf ./out/system/system/app/CompanionDeviceManager
 rm -rf ./out/system/system/app/HTMLViewer
 rm -rf ./out/system/system/app/MiuiAudioMonitor
 rm -rf ./out/system/system/app/MiuiDaemon
 rm -rf ./out/system/system/app/Stk
 rm -rf ./out/system/system/app/VsimCore
 rm -rf ./out/system/system/app/WapiCertManage
 rm -rf ./out/system/system/app/WAPPushManager
 rm -rf ./out/system/system/priv-app/beyondGeofenceService
 rm -rf ./out/system/system/priv-app/BlockedNumberProvider
 rm -rf ./out/system/system/priv-app/DynamicSystemInstallationService
 rm -rf ./out/system/system/priv-app/LocalTransport
 rm -rf ./out/system/system/priv-app/MusicFx
 rm -rf ./out/system/system/priv-app/Ons
 rm -rf ./out/system/system/priv-app/MiRcs
 rm -rf ./out/system/system/priv-app/StatementService
 rm -rf ./out/system/system/priv-app/Tag
 rm -rf ./out/system/system/priv-app/UserDictionaryProvide
 rm -rf ./out/system/system/data-app/com.Qunar_18
 rm -rf ./out/system/system/data-app/com.taobao.taobao_24
 rm -rf ./out/system/system/data-app/com.xunmeng.pinduoduo_19
 rm -rf ./out/system/system/data-app/MiMobileNoti

 #复制文件
 cp -frp ./make/cp_bin/* ./out/system/system/bin/
 cp -frp ./make/cp_etc/* ./out/system/system/etc/

 #lib层处理
 rm -rf ./out/system/system/lib/vndk-29 
 rm -rf ./out/system/system/lib/vndk-sp-29
 rm -rf ./out/system/system/lib64/vndk-29 
 rm -rf ./out/system/system/lib64/vndk-sp-29
 cp -frp ./make/cp_lib/* ./out/system/system/lib
 cp -frp ./make/cp_lib64/* ./out/system/system/lib64
 rm -rf ./out/system/system/lib/*.sh
 rm -rf ./out/system/system/lib64/*.sh
 cd ./make/cp_lib
 ./add_lib_fs.sh
 cd ../../
 cd ./make/cp_lib64
 ./add_lib64_fs.sh
 cd ../../
 sed -i '/vndk-29/ s/^/#/g' ./out/config/system_file_contexts
 sed -i '/vndk-sp-29/ s/^/#/g' ./out/config/system_file_contexts
 sed -i '/vndk-29/ s/^/#/g' ./out/config/system_fs_config
 sed -i '/vndk-sp-29/ s/^/#/g' ./out/config/system_fs_config
 #sed -i '/libdrm\.so/ s/^/#/g' ./out/config/system_file_contexts
 sed -i '/libdrm.so/ s/^/#/g' ./out/config/system_fs_config
 
 #default处理
 sed -i 's/persist.sys.usb.config=none/persist.sys.usb.config=adb/g' ./out/system/system/etc/prop.default
 sed -i 's/ro.secure=1/ro.secure=0/g' ./out/system/system/etc/prop.default
 sed -i 's/ro.debuggable=0/ro.debuggable=1/g' ./out/system/system/etc/prop.default
 #sed -i 's/ro.adb.secure=1/ro.adb.secure=0/g' ./out/system/system/etc/prop.default
 
 if [ -e ./out/vendor ];then
  rm -rf ./default.txt
  cat ./out/vendor/default.prop | grep 'surface_flinger' > /dev/null 2>&1
 fi

 default="$(find ./out/system/ -type f -name 'prop.default')"
 if [ ! $default = "" ];then
  if [ -e ./default.txt ];then
   surface_flinger (){
    default="$(find ./out/system/ -type f -name 'prop.default')"
    cat $default | grep 'surface_flinger' > /dev/null 2>&1
   }
   if surface_flinger ;then
    rm -rf ./default.txt
   else
    echo "" >> $default
    cat ./default.txt >> $default
    rm -rf ./default.txt
   fi
  fi
 fi

 #phh化处理
 cp -frp ./make/cp_phh/bin/* ./out/system/system/bin/
 cp -frp ./make/cp_phh/etc/* ./out/system/system/etc/
 cp -frp ./make/cp_phh/framework/* ./out/system/system/framework/
 #cp -frp ./make/cp_phh/lib/* ./out/system/system/lib/
 cp -frp ./make/cp_phh/lib64/* ./out/system/system/lib64/
 #rm -rf ./out/system/system/lib/*.sh
 rm -rf ./out/system/system/lib64/*.sh
 #cd ./make/cp_phh/lib
 #./add_phh_lib_fs.sh
 #cd ../../../
 cd ./make/cp_phh/lib64
 ./add_phh_lib64_fs.sh
 cd ../../../

 #fs数据整合
 cat ./make/add_fs/contexts >> ./out/config/system_file_contexts
 cat ./make/add_fs/fs >> ./out/config/system_fs_config
 cat ./make/add_phh_fs/contexts >> ./out/config/system_file_contexts
 cat ./make/add_phh_fs/fs >> ./out/config/system_fs_config
 cat ./make/add_logcat_fs/contexts >> ./out/config/system_file_contexts
 cat ./make/add_logcat_fs/fs >> ./out/config/system_fs_config
 cd ./make/new_fs
 ./mergefs.sh
 cd ../../
 
 #亮度修复
  echo "启用亮度修复"
  cp -frp $(find ./out/system/ -type f -name 'services.jar') ./fixbug/lightfix/
  cd ./fixbug/lightfix
  ./brightness_fix.sh
  dist="$(find ./services.jar.out/ -type d -name 'dist')"
  if [ ! $dist = "" ];then
   cp -frp $dist/services.jar ../../out/system/system/framework/
  fi
  cd ../../
 
 #bug修复
  echo "启用bug修复"
  cd ./fixbug
   ./fixbug.sh
   cd ../
 
 echo "SGSI化处理完成"
 rm -rf ./make/new_fs
 ./makeimg.sh

}

function mandatory_pt (){

 echo "当前为无pt 启用强制pt处理方案"

 read -p "按任意键开始处理" var
 echo "SGSI化处理开始......."

 #分离vendor
 mv ./out/system/system/vendor/ ./out/
 
 #prop.default还原
 cp -frp ./out/system/default.prop ./out/system/system/etc/prop.default
 
 #fs修改
 sed -i '/\/system\/system\/vendor/d' ./out/config/system_file_contexts
 sed -i '/system\/system\/vendor/d' ./out/config/system_fs_config
 echo "/system/system/etc/prop\.default u:object_r:system_file:s0" >> ./out/config/system_file_contexts
 echo "/system/system/etc/ld\.config\.29\.txt u:object_r:system_linker_config_file:s0" >> ./out/config/system_file_contexts
 echo "system/system/etc/prop.default 0 0 0600" >> ./out/config/system_fs_config
 echo "system/system/etc/ld.config.29.txt 0 0 0644 " >> ./out/config/system_fs_config

 echo "正在修改system外层"
 cd ./make/ab_boot
 ./ab_boot.sh
 cd ../../
 rm -rf ./out/system/sepolicy
 rm -rf ./out/system/vendor_service_contexts
 echo "修改完成"
  
 rm -rf ./out/system/system/etc/ld.config.txt
 
 if [ -e ./out/vendor/euclid/ ];then
  echo "检测到OPPO_Color 启用专用处理......."
  ./oppo.sh
  echo "处理完成 请检查细节部分"
 else
  if [ -e ./out/vendor/oppo/ ];then  
   echo "检测到OPPO_Color 启用专用处理......."
   ./oppo.sh
   echo "处理完成 请检查细节部分"
  fi
 fi

 #重置make
 echo "正在重置make文件夹数据....."
 true > ./make/add_etc/vintf/manifest2
 echo "" >> ./make/add_etc/vintf/manifest2
 echo "<!-- oem自定义接口 -->" >> ./make/add_etc/vintf/manifest2

 true > ./make/add_build/build2
 echo "" >> ./make/add_build/build2
 echo "#oem厂商自定义属性" >> ./make/add_build/build2

 true > ./make/add_build/build3
 echo "" >> ./make/add_build/build3
 echo "#oem厂商odm自定义属性" >> ./make/add_build/build3
 echo "重置完成"
 
 echo "" > /dev/null 2>&1
 
 #系统种类检测
 cd ./make
 ./romtype.sh
 cd ../
 
 #抓logcat
 cp -frp ./make/cp_logcat/bin/* ./out/system/system/bin/
 cp -frp ./make/cp_logcat/etc/* ./out/system/system/etc/

 #manifest.xml处理
 rm -rf ./vintf
 mkdir ./vintf
 cp -frp $(find ./out/system/ -type f -name 'manifest.xml') ./vintf/
 
 manifest="./vintf/manifest.xml"
 
 sed -i '/<\/manifest>/d' $manifest
 cat ./make/add_etc/vintf/manifest1 >> ./vintf/manifest.xml
 cat ./make/add_etc/vintf/manifest2 >> ./vintf/manifest.xml
 echo "" >> $manifest
 echo "</manifest>" >> $manifest
 cp -frp $manifest ./out/system/system/etc/vintf/
 rm -rf ./vintf
 rm -rf ./make/add_etc/vintf/*.bak

 #链接还原
 ln -s /vendor ./vendor
 mv ./vendor ./out/system/system/
 
 #usb通用化处理
 cp -frp ./make/cp_usb/* ./out/system/

 #selinux通用化处理
 sed -i "/typetransition location_app/d" ./out/system/system/etc/selinux/plat_sepolicy.cil
 sed -i '/vendor/d' ./out/system/system/etc/selinux/plat_property_contexts
 sed -i 's/sys.usb.config          u:object_r:system_radio_prop:s0//g' ./out/system/system/etc/selinux/plat_property_contexts
 sed -i 's/ro.build.fingerprint    u:object_r:fingerprint_prop:s0//g' ./out/system/system/etc/selinux/plat_property_contexts

#qssi机型修复
 qssi (){
  cat ./out/system/system/build.prop | grep -o 'qssi' > /dev/null 2>&1
 }
 if qssi ;then
  echo "检测到原包为qssi 启用机型参数修复" 
  
  brand=$(cat ./out/vendor/build.prop | grep 'ro.product.vendor.brand')
  device=$(cat ./out/vendor/build.prop | grep 'ro.product.vendor.device')
  manufacturer=$(cat ./out/vendor/build.prop | grep 'ro.product.vendor.manufacturer')
  model=$(cat ./out/vendor/build.prop | grep 'ro.product.vendor.model')
  mame=$(cat ./out/vendor/build.prop | grep 'ro.product.vendor.name')
  
  echo "当前原包机型参数为:"
  echo "$brand"
  echo "$device"
  echo "$manufacturer"
  echo "$model"
  echo "$mame"
  
  echo "正在修复"
  sed -i '/ro.product.system./d' ./out/system/system/build.prop
  echo "" >> ./out/system/system/build.prop
  echo "#设备参数" >> ./out/system/system/build.prop
  echo "$brand" >> ./out/system/system/build.prop
  echo "$device" >> ./out/system/system/build.prop
  echo "$manufacturer" >> ./out/system/system/build.prop
  echo "$model" >> ./out/system/system/build.prop
  echo "$mame" >> ./out/system/system/build.prop
  sed -i 's/ro.product.vendor./ro.product./g' ./out/system/system/build.prop
  echo "修复完成"
 fi

 #build处理
 sed -i '/ro.apex.updatable/d' ./out/system/system/build.prop
 sed -i '/ro.apex.updatable/d' ./out/system/system/product/build.prop
 echo "" >> ./out/system/system/build.prop
 echo "#关闭apex更新" >> ./out/system/system/build.prop
 echo "ro.apex.updatable=false" >> ./out/system/system/build.prop
 sed -i 's/ro.product.system./ro.product./g' ./out/system/system/build.prop
 sed -i 's/ro.treble.enabled=false/ro.treble.enabled=true/g' ./out/system/system/build.prop
 #sed -i '/ro.build.ab_update/d' ./out/system/system/build.prop
 sed -i '/system_root_image/d' ./out/system/system/build.prop
 sed -i '/ro.control_privapp_permissions/d' ./out/system/system/build.prop 
 sed -i 's/ro.sf.lcd/#&/' ./out/system/system/build.prop
 sed -i 's/ro.sf.lcd/#&/' ./out/system/system/product/build.prop
 sed -i '/debug.sf.early_app_phase_offset_ns/d' ./out/system/system/build.prop
 sed -i '/debug.sf.early_gl_app_phase_offset_ns/d' ./out/system/system/build.prop
 sed -i '/debug.sf.early_gl_phase_offset_ns/d' ./out/system/system/build.prop
 sed -i '/debug.sf.early_phase_offset_ns/d' ./out/system/system/build.prop
 cat ./make/add_build/build1 >> ./out/system/system/build.prop
 #cat ./make/add_build/build2 >> ./out/system/system/build.prop
 cat ./make/add_build/build3 >> ./out/system/system/build.prop
 rm -rf ./make/add_build/*.bak

 mainkeys="$(grep 'qemu.hw.mainkeys=' ./out/system/system/build.prop)"
 if [ $mainkeys ];then
  sed -i 's/qemu.hw.mainkeys\=1/qemu.hw.mainkeys\=0/g' ./out/system/system/build.prop
 else
  echo "" >> ./out/system/system/build.prop
  echo "#启用虚拟键" >> ./out/system/system/build.prop
  echo "qemu.hw.mainkeys=0" >> ./out/system/system/build.prop
 fi
 
 #删除多余文件
 rm -rf ./out/system/verity_key
 rm -rf ./out/system/sbin/dashd
 rm -rf ./out/system/system/recovery-from-boot.p
 rm -rf ./out/system/system/recovery-from-boot.bak
 rm -rf ./out/system/system/priv-app/com.qualcomm.location
 rm -rf ./out/system/system/etc/permissions/qti_permissions.xml

 #复制文件
 cp -frp ./make/cp_bin/* ./out/system/system/bin/
 cp -frp ./make/cp_etc/* ./out/system/system/etc/

 #lib层处理
 rm -rf ./out/system/system/lib/vndk-29 
 rm -rf ./out/system/system/lib/vndk-sp-29
 rm -rf ./out/system/system/lib64/vndk-29 
 rm -rf ./out/system/system/lib64/vndk-sp-29
 cp -frp ./make/cp_lib/* ./out/system/system/lib
 cp -frp ./make/cp_lib64/* ./out/system/system/lib64
 rm -rf ./out/system/system/lib/*.sh
 rm -rf ./out/system/system/lib64/*.sh
 cd ./make/cp_lib
 ./add_lib_fs.sh
 cd ../../
 cd ./make/cp_lib64
 ./add_lib64_fs.sh
 cd ../../
 sed -i '/vndk-29/ s/^/#/g' ./out/config/system_file_contexts
 sed -i '/vndk-sp-29/ s/^/#/g' ./out/config/system_file_contexts
 sed -i '/vndk-29/ s/^/#/g' ./out/config/system_fs_config
 sed -i '/vndk-sp-29/ s/^/#/g' ./out/config/system_fs_config
 #sed -i '/libdrm\.so/ s/^/#/g' ./out/config/system_file_contexts
 sed -i '/libdrm.so/ s/^/#/g' ./out/config/system_fs_config
 
 #default处理
 sed -i 's/persist.sys.usb.config=none/persist.sys.usb.config=adb/g' ./out/system/system/etc/prop.default
 sed -i 's/ro.secure=1/ro.secure=0/g' ./out/system/system/etc/prop.default
 sed -i 's/ro.debuggable=0/ro.debuggable=1/g' ./out/system/system/etc/prop.default
 #sed -i 's/ro.adb.secure=1/ro.adb.secure=0/g' ./out/system/system/etc/prop.default
 sed -i '/ro.control_privapp_permissions/d' ./out/system/system/etc/prop.default

 #phh化处理
 cp -frp ./make/cp_phh/bin/* ./out/system/system/bin/
 cp -frp ./make/cp_phh/etc/* ./out/system/system/etc/
 cp -frp ./make/cp_phh/framework/* ./out/system/system/framework/
 #cp -frp ./make/cp_phh/lib/* ./out/system/system/lib/
 cp -frp ./make/cp_phh/lib64/* ./out/system/system/lib64/
 #rm -rf ./out/system/system/lib/*.sh
 rm -rf ./out/system/system/lib64/*.sh
 #cd ./make/cp_phh/lib
 #./add_phh_lib_fs.sh
 #cd ../../../
 cd ./make/cp_phh/lib64
 ./add_phh_lib64_fs.sh
 cd ../../../

 #fs数据整合
 cat ./make/add_fs/contexts >> ./out/config/system_file_contexts
 cat ./make/add_fs/fs >> ./out/config/system_fs_config
 cat ./make/add_phh_fs/contexts >> ./out/config/system_file_contexts
 cat ./make/add_phh_fs/fs >> ./out/config/system_fs_config
 cat ./make/add_logcat_fs/contexts >> ./out/config/system_file_contexts
 cat ./make/add_logcat_fs/fs >> ./out/config/system_fs_config
 cd ./make/new_fs
 ./mergefs.sh
 cd ../../
 
 #亮度修复
 echo "启用亮度修复"
 cp -frp $(find ./out/system/ -type f -name 'services.jar') ./fixbug/lightfix/
 cd ./fixbug/lightfix
 ./brightness_fix.sh
 dist="$(find ./services.jar.out/ -type d -name 'dist')"
 if [ ! $dist = "" ];then
  cp -frp $dist/services.jar ../../out/system/system/framework/
 fi
 cd ../../

 echo "启用bug修复"
 cd ./fixbug
 ./fixbug.sh
 cd ../
 echo "SGSI化处理完成"
 rm -rf ./make/new_fs
 ./makeimg.sh
 
}

if [ -L ./out/system/vendor ];then
 mandatory_pt
else
 normal
fi

echo "正在清理工作目录"

if [ -e ./tmp/payload.bin ];then
 rm -rf ./tmp/*.bin
fi

mv ./tmp/*.zip ./
rm -rf ./tmp/*
rm -rf ./compatibility.zip
mv ./*.zip ./tmp/

