#!/bin/bash
##
# Remove OLD Kernel package to prevent false possitive DOME9/Nessus check
##
echo -e "Remove Old Kernels\n"
package-cleanup -y --oldkernel --count=1
echo "Update AIDE database"
aide --update &>/dev/null
mv -f /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
echo -e "Clenaup images\n"
yum clean all
history -c