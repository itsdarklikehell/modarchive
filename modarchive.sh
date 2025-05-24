#!/bin/bash

###############################################################################
#                                                                             #
#                               MODARCHIVE JUKEBOX SCRIPT                     #
#                                                                             #
#  Made by: Fernando Sancho AKA 'toptnc'                                      #
#  email: toptnc@gmail.com                                                    #
#                                                                             #
#  This script plays mods from http://modarchive.org in random order          #
#  It can fetch files from various categories                                 #
#                                                                             #
#  This script is released under the terms of GNU GPL License                 #
#                                                                             #
###############################################################################
eval "$(resize)"

MODPATH='/tmp/modarchive'
SHUFFLE=""
PLAYLISTFILE='modarchive.url'
RANDOMSONG=""
PAGES=""
MODLIST=""
PL_AGE="3600"

TRACKSNUM=0

#Configuration file overrides defaults
if [ -f $HOME/.modarchiverc ]; then
	source $HOME/.modarchiverc
fi

# Check if whiptail is installed
if ! command -v whiptail &>/dev/null; then
	echo "Error: whiptail is not installed."
	echo "Please install it using your distribution's package manager (e.g., sudo apt-get install whiptail)."
	exit 1
fi

# --- Whiptail Menu Logic ---

# Main Menu
MAIN_CHOICE=$(whiptail --title "Modarchive Jukebox" --menu "Choose an option:" $LINES $COLUMNS $((LINES - 8)) \
	"section" "Play from a specific section" \
	"artist" "Search by artist" \
	"module" "Search by module title/filename" \
	"random" "Play a random module" \
	"settings" "Configure player, tracks, shuffle" \
	"exit" "Exit the jukebox" 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus != 0 ]; then
	echo "User cancelled."
	exit 1
fi

case $MAIN_CHOICE in
section)
	SECTION_CHOICE=$(whiptail --title "Select Section" --menu "Choose a section:" $LINES $COLUMNS $((LINES - 8)) \
		"featured" "Featured modules" \
		"favourites" "Favourite modules" \
		"downloads" "Top downloaded modules" \
		"topscore" "Top scored modules" \
		"newadd" "New additions" \
		"newratings" "Recent rated modules" 3>&1 1>&2 2>&3)

	exitstatus=$?
	if [ $exitstatus != 0 ]; then
		echo "User cancelled section selection."
		exit 1
	fi

	case $SECTION_CHOICE in
	featured)
		MODURL="http://modarchive.org/index.php?request=view_chart&query=featured"
		MODLIST="list.featured"
		;;
	favourites)
		MODURL="http://modarchive.org/index.php?request=view_top_favourites"
		MODLIST="list.favourites"
		;;
	downloads)
		MODURL="http://modarchive.org/index.php?request=view_chart&query=tophits"
		MODLIST="list.downloads"
		;;
	topscore)
		MODURL="http://modarchive.org/index.php?request=view_chart&query=topscore"
		MODLIST="list.topscore"
		;;
	newadd)
		MODURL="http://modarchive.org/index.php?request=view_actions_uploads"
		MODLIST="list.newadd"
		PAGES='0' # New additions page structure is different
		;;
	newratings)
		MODURL="http://modarchive.org/index.php?request=view_actions_ratings"
		MODLIST="list.newratings"
		PAGES='0' # New ratings page structure is different
		;;
	esac
	;;
artist)
	ARTIST_QUERY=$(whiptail --title "Search Artist" --inputbox "Enter artist name:" $LINES $COLUMNS "" 3>&1 1>&2 2>&3)
	exitstatus=$?
	if [ $exitstatus != 0 ]; then
		echo "User cancelled artist search."
		exit 1
	fi
	if [ -z "$ARTIST_QUERY" ]; then
		whiptail --msgbox "Artist name cannot be empty." $LINES $COLUMNS
		exit 1
	fi
	QUERY=$(echo "${ARTIST_QUERY}" | sed 's/ /+/g')
	QUERYURL="http://modarchive.org/index.php?query=$QUERY&submit=Find&request=search&search_type=search_artist"
	ARTISTNO=$(curl -s "$QUERYURL" | grep -A 10 "Search Results" | grep member.php | sed 's/>/>\n/g' | head -1 | cut -d "?" -f 2 | cut -d "\"" -f 1)
	if [ -z "$ARTISTNO" ]; then
		whiptail --msgbox "The artist search returned no results." $LINES $COLUMNS
		exit 1
	fi
	MODURL="http://modarchive.org/index.php?request=view_artist_modules&query=${ARTISTNO}"
	MODLIST="artist.${ARTIST_QUERY}"
	;;
module)
	MODULE_QUERY=$(whiptail --title "Search Module" --inputbox "Enter module title or filename:" $LINES $COLUMNS "" 3>&1 1>&2 2>&3)
	exitstatus=$?
	if [ $exitstatus != 0 ]; then
		echo "User cancelled module search."
		exit 1
	fi
	if [ -z "$MODULE_QUERY" ]; then
		whiptail --msgbox "Module title/filename cannot be empty." $LINES $COLUMNS
		exit 1
	fi
	MODURL="http://modarchive.org/index.php?request=search&query=${MODULE_QUERY}&submit=Find&search_type=filename_or_songtitle"
	MODLIST="search.${MODULE_QUERY}"
	;;
random)
	RANDOMSONG="true"
	MODURL="http://modarchive.org/index.php?request=view_random"
	PAGES='0' # Random doesn't use pagination like lists
	;;
settings)
	SETTINGS_CHOICE=$(whiptail --title "Settings" --menu "Configure options:" $LINES $COLUMNS $((LINES - 8)) \
		"player" "Select player profile" \
		"tracks" "Set number of tracks to play" \
		"shuffle" "Toggle shuffle mode" \
		"back" "Back to main menu" 3>&1 1>&2 2>&3)

	exitstatus=$?
	if [ $exitstatus != 0 ]; then
		# User cancelled settings menu, go back to main menu
		# Re-run the script or loop back if implemented
		echo "User cancelled settings, exiting for now. Re-run to choose again."
		exit 1 # Simple exit for now, a loop would be better
	fi

	case $SETTINGS_CHOICE in
	player)
		PLAYER_CHOICE=$(whiptail --title "Select Player" --menu "Choose a player:" $LINES $COLUMNS $((LINES - 8)) \
			"mikmod" "Console player (default)" \
			"audacious" "X11 player" \
			"opencp" "Open Cubic Player" \
			"sunvox" "SunVox" \
			"openmpt123" "OpenMPT" \
			"vlc" "vlc player" \
			"cvlc" "console vlc player" 3>&1 1>&2 2>&3)

		exitstatus=$?
		if [ $exitstatus != 0 ]; then
			echo "User cancelled player selection."
			# Decide whether to exit or go back to settings menu
			exit 1 # Simple exit for now
		fi

		case $PLAYER_CHOICE in
		audacious)
			cat <<EOF >>~/.modarchiverc
MODPATH='$HOME/sunvox/examples/modarchive'

PLAYER='$(which audacious)'
PLAYEROPTS='-e'
PLAYERBG='true'
EOF
			whiptail --msgbox "audacious selected. Ensure 'audacious' command is in your PATH and can play modules directly." $LINES $COLUMNS
			;;
		mikmod)
			cat <<EOF >>~/.modarchiverc
MODPATH='$HOME/sunvox/examples/modarchive'

PLAYER='$(which mikmod)'
PLAYEROPTS='-i -X --surround --hqmixer -f 48000 -X'
PLAYERBG='false'
EOF
			whiptail --msgbox "mikmod selected. Ensure 'mikmod' command is in your PATH and can play modules directly." $LINES $COLUMNS
			;;
		opencp)
			cat <<EOF >>~/.modarchiverc
MODPATH='$HOME/sunvox/examples/modarchive'

PLAYER='$(which ocp)'
PLAYEROPTS='-p'
PLAYERBG='false'
EOF
			whiptail --msgbox "Open Cubic Player selected. Ensure 'ocp' command is in your PATH and can play modules directly." $LINES $COLUMNS
			;;
		sunvox)
			cat <<EOF >>~/.modarchiverc
MODPATH='$HOME/sunvox/examples/modarchive'

PLAYER='$(which sunvox)'
PLAYEROPTS='-p'
PLAYERBG='false'
EOF
			whiptail --msgbox "SunVox selected. Ensure 'sunvox' command is in your PATH and can play modules directly." $LINES $COLUMNS
			;;
		openmpt123)
			cat <<EOF >>~/.modarchiverc
MODPATH='$HOME/sunvox/examples/modarchive'
PLAYER='$(which openmpt123)'
PLAYEROPTS=''
PLAYERBG='false'
EOF
			whiptail --msgbox "OpenMPT123 selected. Ensure 'openmpt123' command is in your PATH and can play modules directly." $LINES $COLUMNS
			;;
		vlc)
			cat <<EOF >>~/.modarchiverc
MODPATH='$HOME/sunvox/examples/modarchive'
PLAYER='$(which vlc)'
PLAYEROPTS='--play-and-exit'
PLAYERBG='false'
EOF
			whiptail --msgbox "VLC selected. Ensure 'vlc' command is in your PATH and can play modules directly." $LINES $COLUMNS
			;;
		cvlc)
			cat <<EOF >>~/.modarchiverc
MODPATH='$HOME/sunvox/examples/modarchive'
PLAYER='$(which cvlc)'
PLAYEROPTS='--play-and-exit'
PLAYERBG='false'
EOF
			whiptail --msgbox "VLC selected. Ensure 'vlc' command is in your PATH and can play modules directly." $LINES $COLUMNS
			;;
		*)
			whiptail --msgbox "ERROR: ${PLAYER_CHOICE} player is not supported." $LINES $COLUMNS
			exit 1
			;;
		esac
		# After setting player, ideally go back to settings menu or main menu
		# For simplicity now, we'll let it proceed, but a loop would be better
		;;
	tracks)
		TRACKS_INPUT=$(whiptail --title "Number of Tracks" --inputbox "Enter number of tracks to play (0 for all):" 8 78 "0" 3>&1 1>&2 2>&3)
		exitstatus=$?
		if [ $exitstatus != 0 ]; then
			echo "User cancelled track number input."
			exit 1 # Simple exit for now
		fi
		if [[ "$TRACKS_INPUT" =~ ^[0-9]+$ ]]; then
			TRACKSNUM=${TRACKS_INPUT}
		else
			whiptail --msgbox "Invalid input. Please enter a number." $LINES $COLUMNS
			exit 1 # Exit on invalid input
		fi
		# After setting tracks, ideally go back to settings menu or main menu
		# For simplicity now, we'll let it proceed
		;;
	shuffle)
		if (whiptail --title "Shuffle" --yesno "Enable shuffle mode?" $LINES $COLUMNS); then
			SHUFFLE="true"
			whiptail --msgbox "Shuffle enabled." $LINES $COLUMNS
		else
			SHUFFLE=""
			whiptail --msgbox "Shuffle disabled." $LINES $COLUMNS
		fi
		# After setting shuffle, ideally go back to settings menu or main menu
		# For simplicity now, we'll let it proceed
		;;
	back)
		# This case would ideally loop back to the main menu
		echo "Going back to main menu (requires script loop)."
		exit 1 # Simple exit for now, needs loop
		;;
	esac
	# After settings, ideally loop back to main menu or proceed if main choice was already made
	# For simplicity now, we'll let it proceed if MODURL is set
	;;
exit)
	echo "Exiting Modarchive Jukebox."
	exit 0
	;;
esac

# --- End of Whiptail Menu Logic ---

# Check if a source was selected (MODURL should be set unless user exited or cancelled early)
if [ -z "$MODURL" ] && [ -z "$RANDOMSONG" ]; then
	echo "No source selected. Exiting."
	exit 1
fi

# Check if player exists AFTER potential player selection in settings
if [ ! -e "$PLAYER" ]; then
	whiptail --msgbox "This script needs $PLAYER to run. Please install it or change the player in settings." $LINES $COLUMNS
	exit 1
fi

if [ "${PLAYERBG}" = "true" ] && [ -z "$(pidof "$(basename $PLAYER)")" ]; then
	whiptail --msgbox "$PLAYER isn't running. Please, launch it first." $LINES $COLUMNS
	exit 1
fi

echo "Starting Modarchive JukeBox Player"
mkdir -p "$MODPATH" # Use quotes for safety

LOOP="true"

if [ -z "$RANDOMSONG" ]; then
	echo "Creating playlist"
	create_playlist

	# Check if playlist file was created and has content
	if [ ! -f "$MODPATH/$PLAYLISTFILE" ]; then
		whiptail --msgbox "Failed to create playlist or query returned no results." $LINES $COLUMNS
		exit 1
	fi

	TRACKSFOUND=$(wc -l "$MODPATH/$PLAYLISTFILE" | cut -d " " -f 1)
	whiptail --msgbox "Your query returned ${TRACKSFOUND} results." $LINES $COLUMNS
fi

COUNTER=1
while [ "$LOOP" = "true" ]; do # Use quotes for variable comparison
	if [ -z "$RANDOMSONG" ]; then # Use quotes
		SONGURL=$(cat "$MODPATH/$PLAYLISTFILE" | head -n ${COUNTER} | tail -n 1)
		let COUNTER=$COUNTER+1
		if [ $TRACKSNUM -gt 0 ]; then
			if [ $COUNTER -gt $TRACKSNUM ] || [ $COUNTER -gt $TRACKSFOUND ]; then
				LOOP="false"
			fi
		elif [ $COUNTER -gt $TRACKSFOUND ]; then
			LOOP="false"
		fi
	else
		# Note: The random song logic here still just gets the first result from the random page.
		# To get truly random songs repeatedly, this curl command would need to be inside the loop
		# and the MODURL for random is designed to give a single random result per request.
		# The current logic will just download and play the *same* random song N times if TRACKSNUM > 1.
		# A better random implementation would fetch a new random URL in each loop iteration.
		SONGURL=$(curl -s "$MODURL" | sed 's/href=\"/href=\"\n/g' | sed 's/\">/\n\">/g' | grep downloads.php | head -n 1)
		let COUNTER=$COUNTER+1
		if [ $TRACKSNUM -gt 0 ] && [ $COUNTER -gt $TRACKSNUM ]; then
			LOOP="false"
		fi
	fi

	# Check if SONGURL is empty (e.g., end of playlist)
	if [ -z "$SONGURL" ]; then
		echo "End of playlist."
		LOOP="false"
		continue # Skip to next loop iteration
	fi

	MODFILE=$(echo "$SONGURL" | cut -d "#" -f 2)
	# Revert to original filename logic for simplicity with whiptail version
	# If you want the artist/title filename, you'd need to re-integrate that logic here
	DOWNLOAD_FILENAME="${MODPATH}/${MODFILE}"

	if [ ! -e "${DOWNLOAD_FILENAME}" ]; then
		echo "Downloading $SONGURL to $DOWNLOAD_FILENAME"
		curl -s -o "${DOWNLOAD_FILENAME}" "$SONGURL"
	else
		echo "File already exists: ${DOWNLOAD_FILENAME}"
	fi

	if [ -e "${DOWNLOAD_FILENAME}" ]; then
		echo "Playing: $(basename "${DOWNLOAD_FILENAME}")" # Show just the filename being played
		$PLAYER $PLAYEROPTS "${DOWNLOAD_FILENAME}"
	else
		echo "Error: Download failed or file not found for playing: ${DOWNLOAD_FILENAME}"
	fi

	# Add a small delay or wait for player if not running in background
	if [ "${PLAYERBG}" = "false" ]; then
		# Simple wait - might need adjustment depending on player
		# For mikmod, it runs in foreground, so the script waits automatically.
		# For others, you might need a 'read -p "Press Enter to play next..."' or similar
		: # No explicit wait needed for foreground players
	fi

done

echo "Playback finished."

create_playlist() {
	PLAYLIST=""

	# Check if the list file exists and is recent enough
	if [ ! -e "$MODPATH/$MODLIST" ] || [ "$(($(date +%s) - $(stat -c %Y "$MODPATH/$MODLIST")))" -gt $PL_AGE ]; then
		echo "Fetching module list..."
		if [ ! -z "$PAGES" ] && [ "$PAGES" -eq 0 ]; then
			# Handle cases like newadd/newratings where PAGES is explicitly 0 or not applicable
			# Fetch the single page list
			PLAYLIST=$(curl -s "${MODURL}" | grep href | sed 's/href=/\n/g' | sed 's/>/\n/g' | grep downloads.php | sed 's/\"//g' | sed 's/'\''//g' | cut -d " " -f 1 | uniq)
		else
			# Fetch total pages if not set
			if [ -z "$PAGES" ]; then
				PAGES=$(curl -s "$MODURL" | html2text | grep "Jump" | sed 's/\\//\\n/g' | tail -1 | cut -d "]" -f1)
				[ -z "$PAGES" ] && PAGES=1 # Default to 1 page if parsing fails
				echo "Need to download ${PAGES} pages of results. This may take a while..."
			fi

			PLAYLIST="" # Initialize playlist for multi-page fetch
			for ((PLPAGE = 1; PLPAGE <= PAGES; PLPAGE++)); do
				((PERCENT = PLPAGE * 100 / PAGES))
				echo -ne "${PERCENT}% completed\\r"
				PLPAGEARG="&page=$PLPAGE"
				LIST=$(curl -s "${MODURL}${PLPAGEARG}" | grep href | sed 's/href=/\n/g' | sed 's/>/\n/g' | grep downloads.php | sed 's/\"//g' | sed 's/'\''//g' | cut -d " " -f 1 | uniq)
				PLAYLIST=$(printf "${PLAYLIST}\\n${LIST}")
			done
			echo "" # Newline after progress
		fi
		echo "$PLAYLIST" | sed '/^$/d' >"$MODPATH/$MODLIST"
		echo "Module list saved to $MODPATH/$MODLIST"
	else
		echo "Using cached module list from $MODPATH/$MODLIST"
	fi

	# Apply shuffle if enabled
	if [ -z "$SHUFFLE" ]; then
		cat "$MODPATH/$MODLIST" >"$MODPATH/$PLAYLISTFILE"
		echo "Playlist created (not shuffled)."
	else
		cat "$MODPATH/$MODLIST" | awk 'BEGIN { srand() } { print rand() "\t" $0 }' | sort -n | cut -f2- >"$MODPATH/$PLAYLISTFILE"
		echo "Playlist created (shuffled)."
	fi
}

if [ -z "$RANDOMSONG" ]; then
	create_playlist
	TRACKSFOUND=$(wc -l "$MODPATH/$PLAYLISTFILE" | cut -d " " -f 1)
	whiptail --msgbox "Your query returned ${TRACKSFOUND} results." $LINES $COLUMNS
fi
