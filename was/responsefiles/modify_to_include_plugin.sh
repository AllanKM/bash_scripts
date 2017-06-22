#!/bin/ksh

TEMPLATE=${1:-v51silent.stacked.script}
TOOLSDIR=/lfs/system/tools/was

echo "Modifying the EI WAS install template $TEMPLATE to install the IHS 2.0 was plugin"
sed -e 's/pluginBean.active="false"/pluginBean.active="true"/' ${TOOLSDIR}/responsefiles/${TEMPLATE} > /tmp/template
sed -e 's/ihs20PluginBean.active="false"/ihs20PluginBean.active="true"/' /tmp/template > ${TOOLSDIR}/responsefiles/${TEMPLATE}