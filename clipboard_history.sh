#!/bin/bash
# FILENAME: clipboard_history.sh
# AUTHOR: Lorinczi Matyas
# DESCRIPTION: A simple clipboard history tool for macOS using shell scripts and AppleScript.
# USAGE: Run the script with 
#   --start to start the clipboard listener
#   --show to show the history
#   --stop to stop the listener.
# Running detached in the background so you can close the terminal. 
# nohup /path/to/macos-clipboard-history/clipboard_history.sh --start &

PID_FILE="$HOME/.clipboard_history/.listener_pid"
HISTORY_FOLDER="$HOME/.clipboard_history/.history_files"
APPLESCRIPT_FILE="$(dirname "$0")/create_history_ui.applescript"
MAX_HISTORY=20

# Create necessary directories if they don't exist
mkdir -p "$HISTORY_FOLDER"

# Function to rotate history files
rotate_history() {
    local new_content="$1"
    
    # Check if content is different from the most recent entry
    if [[ -f "${HISTORY_FOLDER}/1" ]] && [[ "$(cat "${HISTORY_FOLDER}/1")" == "$new_content" ]]; then
        return
    fi
    
    # Rotate files
    for ((i=MAX_HISTORY; i>1; i--)); do
        prev=$((i-1))
        if [[ -f "${HISTORY_FOLDER}/${prev}" ]]; then
            mv "${HISTORY_FOLDER}/${prev}" "${HISTORY_FOLDER}/${i}"
        fi
    done
    
    # Save new content to file 1
    echo "$new_content" > "${HISTORY_FOLDER}/1"
}

# Function to show history with timestamps and handle selection
show_history() {
    # Create an array to store all valid items
    declare -a history_items
    
    # Build the array of items
    for ((i=1; i<=MAX_HISTORY; i++)); do
        if [[ -f "${HISTORY_FOLDER}/${i}" ]]; then
            content=$(cat "${HISTORY_FOLDER}/${i}")
            # Truncate content for display and escape quotes
            preview="${content:0:100}"
            preview="${preview//\"/\\\"}"
            if [[ ${#content} -gt 100 ]]; then
                preview="${preview}..."
            fi
            history_items+=("$preview")
        fi
    done
    
    # If no items found, exit
    if [ ${#history_items[@]} -eq 0 ]; then
        echo "No clipboard history found."
        exit 0
    fi
    
    # Pass the items directly as arguments to the AppleScript
    local selection=$(osascript "$APPLESCRIPT_FILE" "${history_items[@]}")
    
    # If user made a selection, find and copy the corresponding item
    if [[ "$selection" != "false" ]]; then
        for ((i=1; i<=MAX_HISTORY; i++)); do
            if [[ -f "${HISTORY_FOLDER}/${i}" ]]; then
                content=$(cat "${HISTORY_FOLDER}/${i}")
                preview="${content:0:100}"
                if [[ ${#content} -gt 100 ]]; then
                    preview="${preview}..."
                fi
                if [[ "$selection" == *"$preview"* ]]; then
                    echo "$content" | pbcopy
                    break
                fi
            fi
        done
    fi
}

# Start clipboard listener in background
if [[ "$1" == "--start" ]]; then
    if [[ -f "$PID_FILE" ]]; then
        OLD_PID=$(cat "$PID_FILE")
        if ps -p $OLD_PID > /dev/null 2>&1; then
            echo "Clipboard listener is already running (PID: $OLD_PID)."
            exit 0
        fi
    fi

    # Background listener process
    (
        while true; do
            current_clipboard=$(pbpaste)
            if [[ -n "$current_clipboard" ]]; then
                rotate_history "$current_clipboard"
            fi
            sleep 1
        done
    ) &
    
    echo $! > "$PID_FILE"
    echo "Clipboard listener started (PID: $(cat "$PID_FILE"))"
    exit 0
fi

# Show clipboard history
if [[ "$1" == "--show" ]]; then
    show_history
    exit 0
fi

if [[ "$1" == "--clear" ]]; then
    rm -rf "$HISTORY_FOLDER"
    mkdir -p "$HISTORY_FOLDER"
    echo "Clipboard history cleared."
    exit 0
fi

# Stop the clipboard listener
if [[ "$1" == "--stop" ]]; then
    if [[ -f "$PID_FILE" ]]; then
        kill "$(cat "$PID_FILE")"
        rm "$PID_FILE"
        echo "Clipboard listener stopped."
    else
        echo "No clipboard listener is running."
    fi
    exit 0
fi

# Show usage if no valid argument is provided
echo "Usage: $0 [--start|--clear|--show|--stop]"
exit 1