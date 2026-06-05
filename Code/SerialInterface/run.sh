# Usage: bash run.sh
# Use Cmd + W to close the new Terminal window when it becomes unresponsive to
# Ctrl + C.

dialog () {
 osascript <<EOD
 tell app "Terminal" to do script "cd $(pwd) && swift run -Xswiftc -Ounchecked SerialInterface"
EOD
}

dialogDebug () {
 osascript <<EOD
 tell app "Terminal" to do script "cd $(pwd) && swift run SerialInterface"
EOD
}

# Function to display usage instructions
show_help() {
  echo "Usage: $0 [--debug]"
  exit 1
}

# Check the first command-line argument
case "$1" in
  "")
    # --- CODE SECTION A (Default) ---
    dialog $@
    # Your default code goes here
    ;;

  "--debug")
    # --- CODE SECTION B (Debug Mode) ---
    dialogDebug $@
    # Your debug code goes here
    ;;

  *)
    # --- INVALID ARGUMENT ---
    # Exits early with a help message if anything else is entered
    show_help
    ;;
esac
