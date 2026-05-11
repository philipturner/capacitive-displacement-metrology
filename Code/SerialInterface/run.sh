# Usage: bash run.sh
# Use Cmd + W to close the new Terminal window when it becomes unresponsive to
# Ctrl + C.

dialog () {
 osascript <<EOD
 tell app "Terminal" to do script "cd $(pwd) && swift run -Xswiftc -Ounchecked SerialInterface"
EOD
}

dialog $@
