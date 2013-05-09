set -a
source ../MeddleSystem/meddle.config
mkdir -p ${webPagesStaticPath}
cp -vRf * ${webPagesStaticPath}/
rm ${webPagesStaticPath}/install.sh
