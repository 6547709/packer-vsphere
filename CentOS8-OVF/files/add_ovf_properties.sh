#!/bin/bash

OUTPUT_PATH="../output-vsphere"
OVF_PATH=$(find ${OUTPUT_PATH} -type f -iname ${CENTOS_APPLIANCE_NAME}.ovf -exec dirname "{}" \;)

# Move ovf files in to a subdirectory of OUTPUT_PATH if not already
if [ "${OUTPUT_PATH}" = "${OVF_PATH}" ]; then
    mkdir ${OUTPUT_PATH}/${CENTOS_APPLIANCE_NAME}
    mv ${OUTPUT_PATH}/*.* ${OUTPUT_PATH}/${CENTOS_APPLIANCE_NAME}
    OVF_PATH=${OUTPUT_PATH}/${CENTOS_APPLIANCE_NAME}
fi

rm -f ${OVF_PATH}/${CENTOS_APPLIANCE_NAME}.mf

sed "s/{{VERSION}}/${CENTOS_VERSION}/g" ${CENTOS_OVF_TEMPLATE} > centos.xml

sed -i 's/<VirtualHardwareSection>/<VirtualHardwareSection ovf:transport="com.vmware.guestInfo">/g' ${OVF_PATH}/${CENTOS_APPLIANCE_NAME}.ovf
sed -i "/    <\/vmw:BootOrderSection>/ r centos.xml" ${OVF_PATH}/${CENTOS_APPLIANCE_NAME}.ovf
sed -i '/^      <vmw:ExtraConfig ovf:required="false" vmw:key="nvram".*$/d' ${OVF_PATH}/${CENTOS_APPLIANCE_NAME}.ovf
sed -i "/^    <File ovf:href=\"${CENTOS_APPLIANCE_NAME}-file1.nvram\".*$/d" ${OVF_PATH}/${CENTOS_APPLIANCE_NAME}.ovf
sed -i 's/ovf:fileRef="file2"//g' ${OVF_PATH}/${CENTOS_APPLIANCE_NAME}.ovf
sed -i '/vmw:ExtraConfig.*/d' ${OVF_PATH}/${CENTOS_APPLIANCE_NAME}.ovf
sed -i "/^    <Disk ovf:capacity=/r ovf-add-disk-1.xml" ${OVF_PATH}/${CENTOS_APPLIANCE_NAME}.ovf
sed -i '/^      <vmw:Config ovf:required="false" vmw:key="cpuHotAddEnabled/i MARKER' ${OVF_PATH}/${CENTOS_APPLIANCE_NAME}.ovf
sed -i '/MARKER/r ovf-add-disk-2.xml' ${OVF_PATH}/${CENTOS_APPLIANCE_NAME}.ovf
sed -i '/MARKER/d' ${OVF_PATH}/${CENTOS_APPLIANCE_NAME}.ovf

ovftool ${OVF_PATH}/${CENTOS_APPLIANCE_NAME}.ovf ${OUTPUT_PATH}/${FINAL_CENTOS_APPLIANCE_NAME}.ova
rm -rf ${OUTPUT_PATH}/${CENTOS_APPLIANCE_NAME}
rm -f centos.xml

