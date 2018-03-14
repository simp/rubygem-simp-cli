#!/bin/sh

if [ "$SIMP_CLI_CERTIFICATES_FAIL" = "true" ]; then
  exit 1
fi

# mocked gencerts_nopass.sh
for hosts in `cat togen`; do
  hosts=`echo $hosts | sed -e 's/[ \t]//g'`
  hname=`echo $hosts | cut -d',' -f1`
  keydist="../site_files/pki_files/files/keydist"
  mkdir -p "${keydist}/${hname}"
  echo "$hname: dummy generated" >>  ${keydist}/${hname}/${hname}.pub
  cat ${keydist}/${hname}/${hname}.pub >> ${keydist}/${hname}/${hname}.pem
done
exit 0
