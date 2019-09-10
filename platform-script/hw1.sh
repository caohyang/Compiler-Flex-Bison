WORKSPACE=`pwd`

# 获取测试用例的输入(请勿改动此行语句)
input=$2;OLD_IFS="$IFS"; IFS=,; ins=($input);IFS="$OLD_IFS"

bash secret/platform-script/hw1.sh
