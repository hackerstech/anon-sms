#!/bin/bash

# Author: Hemant Sachdeva <hemant.evolver@gmail.com>
# Date Created: 25/07/2021
#
# Dependencies: jq, curl, w3m
#

version=1.2

# By default 'tempmail' uses 'w3m' as it's web browser to render
# the HTML of the email
browser="w3m"

# If the value is set to 'true' tempmail will convert the HTML email
# to raw text and send that to stdout
raw_text=false

# Everything related to 'tempmail' will be stored in ~/tempmail by default
# You can change it to /tmp/tempmail so that the old emails
# and email addresses get cleared after restarting the computer
# or use -d flag to set a custom dir path

dot_dir="$HOME/.tempmail/"
mkdir -p "$dot_dir"
tempmail_dir="$HOME/tempmail"

# Takes directory from user and save it to dot dir
directory() {
    echo "$HOME/$2" >"$dot_dir/custom_tempmail_dir"
    mkdir -p "$HOME/$2"
    echo -e "From now all data related to tempmail will be storing in $HOME/$2"
    echo "We consider your provided directory path after $HOME xD"
}

# Gets the directory path from dot dir so that it will not get
# set to global tempmail_dir path whenever user runs the script
[[ -f "$dot_dir/custom_tempmail_dir" ]] && tempmail_dir=$(cat "$dot_dir/custom_tempmail_dir")

# tempmail_email_address is where we store the temporary email address
# that gets generated. This prevents the user from providing
# the email address everytime they run tempmail
tempmail_email_address="$tempmail_dir/email_address"

# tempmail.html is where the email gets stored.
# Even though the file ends with a .html extension, the raw text version of
# the email will also be stored in this file so that w3m and other browsers
# are able to open this file
tempmail_html_email="$tempmail_dir/tempmail.html"

# Default 1secmail API URL
tempmail_api_url="https://www.1secmail.com/api/v1/"

usage() {
    # Using 'cat << EOF' we can easily output a multiline text. This is much
    # better than using 'echo' for each line or using '\n' to create a new line.
    cat <<EOF
tempmail
tempmail -h | -v | -l | -d
tempmail -g [ADDRESS]
tempmail [-t | -b BROWSER] -r | ID

When called with one argument, tempmail
shows the email message with specified ID.

-b, --browser BROWSER
        Specify BROWSER (default: w3m) that is used to render the HTML of
        the email
-l, --list
        List all the received emails
-d, --directory
        Set a custom directory to store everything related to 'tempmail'
-g, --generate [ADDRESS]
        Generate a new email address, either the specified ADDRESS, or
        randomly create one
-h, --help
        Show help
-r, --recent
        View the most recent email message
-t, --text
        View the email as raw text, where all the HTML tags are removed.
        Without this option, HTML is used.
-v, --version
        Show version
EOF
}

generate_email_address() {
    # There are 2 ways which this function is called in this script.
    #  [1] The user wants to generate a new email and runs 'tempmail --generate'
    #  [2] The user runs 'tempmail' to check the inbox , but $tempmail_dir/email_address
    #      is empty or nonexistant. Therefore a new email gets automatically
    #      generated before showing the inbox. But of course the inbox will
    #      be empty as the newly generated email address has not been
    #      sent any emails.
    #
    # When the function 'generate_email_address()' is called with the arguement
    # 'true', it means that the function was called because the user
    # ran 'tempmail --generate'.
    #
    # We need this variable so we can know whether or not we need to show the user
    # what the email was. <-- More about this can be found further down in this function.
    externally=${1:-false}

    # This variable lets generate_email_address know if the user has provided a custom
    # email address which they want to use. custom is set to false if $2 has no value.
    custom=${2:-false}

    # Generate a random email address.
    # This function is called whenever the user wants to generate a new email
    # address by running 'tempmail --generate' or when the user runs 'tempmail'
    # but $tempmail_dir/email_address is empty or nonexistent.
    #
    # We create a random username by taking the first 10 lines from /dev/random
    # and delete all the characters which are *not* lower case letters from A to Z.
    # So charcters such as dashes, periods, underscore, and numbers are all deleted,
    # giving us a text which only contains lower case letters form A to Z. We then take
    # the first 10 characters, which will be the username of the email address
    username=$(head /dev/urandom | LC_ALL=C tr -dc "[:alnum:]" | cut -c1-11 | tr "[:upper:]" "[:lower:]")

    valid_email_address_regex="[a-z0-9]+@(1secmail\.(com|net|org)|esiix.co|wwjmp.com|xojxe.com|yoggm.com)"
    username_black_list_regex="(abuse|webmaster|contact|postmaster|hostmaster|admin)"
    username_black_list="- abuse\n- webmaster\n- contact\n- postmaster\n- hostmaster\n- admin"
    domains="1secmail.com"

    # Randomly pick one of the domains mentiond above.
    domain=$(echo -e "$domains" | tr " " "\n" | randomize | tail -1)

    email_address="$username@$domain"

    # If the user provided a custom email address then use that email address
    if [ "$custom" != false ]; then

        # Check if user added a valid domain
        valid=0
        dom=$(echo "$custom" | cut -d '@' -f2)
        for d in $domains; do
            [[ "$d" = "$dom" ]] && valid=1 && break
        done

        # Pick random domain if custom domain is not added or invalid
        if [[ valid -eq 0 ]]; then
            echo -e "No valid domain added. Picking one randomly from\n[ $domains ]\n"
            email_address="$custom@$domain"
        else
            email_address=$custom
        fi

        # Check if the user is using username in the email address which appears
        # in the black list.
        if echo "$email_address" | grep -Eq "$username_black_list_regex"; then
            print_error "For security reasons, that username cannot be used. Here are the blacklisted usernames:\n$username_black_list"
        fi

        # Do a regex check to see if the email address provided by the user is a
        # valid email address
        if ! echo "$email_address" | grep -Eq "$valid_email_address_regex"; then
            print_error "Provided email is invalid. Must match $valid_email_address_regex"
        fi
    fi

    # Save the generated email address to the $tempmail_email_address file
    # so that it can be whenever 'tempmail' is run
    echo "$email_address" >"$tempmail_email_address"

    # If this function was called because the user wanted to generate a new
    # email address, show them the email address
    [ "$externally" = true ] && cat "$tempmail_email_address" && echo
}

get_email_address() {
    # This function is only called once and that is when this script
    # get executed. The output of this function gets stored in $email_address
    #
    # If the file that contains the email address is empty,
    # that means we do not have an email address, so generate one.
    [ ! -s "$tempmail_email_address" ] && generate_email_address

    # Output the email address by getting the first line of $tempmail_email
    head -n 1 "$tempmail_email_address"
}

list_emails() {
    # List all the received emails in a nicely formatted order
    #
    # Fetch the email data using 1secmail's API
    data=$(curl -sL "$tempmail_api_url?action=getMessages&login=$username&domain=$domain")

    # Using 'jq' we get the length of the JSON data. From this we can determine whether or not
    # the email address has gotten any emails
    data_length=$(echo "$data" | jq length)

    # We are showing what email address is currently being used
    # in case the user has forgotten what the email address was.
    echo "[ Inbox for $email_address ]"

    # If the length of the data we got is 0, that means the email address
    # has not received any emails yet.
    [ "$data_length" -eq 0 ] && echo "No new mail" && exit

    # This is where we store all of our emails, which is then
    # displayed using 'column'
    inbox=""

    # Go through each mail that has been received
    index=1
    while [ $index -le "${data_length}" ]; do
        # Since arrays in JSON data start at 0, we must subtract
        # the value of $index by 1 so that we dont miss one of the
        # emails in the array
        mail_data=$(echo "$data" | jq -r ".[$index-1]")
        id=$(echo "$mail_data" | jq -r ".id")
        from=$(echo "$mail_data" | jq -r ".from")
        subject=$(echo "$mail_data" | jq -r ".subject")
        date=$(echo "$mail_data" | jq -r ".date")

        # The '||' are used as a divideder for 'column'. 'column' will use this divider as
        # a point of reference to create the division. By default 'column' uses a blank space
        # but that would not work in our case as the email subject could have multiple white spaces
        # and 'column' would split the words that are seperated by white space, in different columns.
        inbox="$inbox ID: $id ||$from ||$subject\n"
        index=$((index + 1))
    done

    echo -e "\nUse 'tempmail ID' to view email in detail."

    # Show the emails cleanly
    echo -e "$inbox" | column -t -s "||"
}

randomize() {
    awk 'BEGIN {srand();} {print rand(), $0}' |
        sort -n -k1 | cut -d' ' -f2
}

view_email() {
    # View an email by providing it's ID
    #
    # The first argument provided to this function will be the ID of the email
    # that has been received
    email_id="$1"
    data=$(curl -sL "$tempmail_api_url?action=readMessage&login=$username&domain=$domain&id=$email_id")

    # After the data is retrieved using the API, we have to check if we got any emails.
    # Luckly 1secmail's API is not complicated and returns 'Message not found' as plain text
    # if our email address as not received any emails.
    # If we received the error message from the API just quit because there is nothing to do
    [ "$data" = "Message not found" ] && print_error "No recent email found"

    # We pass the $data to 'jq' which extracts the values
    from=$(echo "$data" | jq -r ".from")
    subject=$(echo "$data" | jq -r ".subject")
    date=$(echo "$data" | jq -r ".date")
    html_body=$(echo "$data" | jq -r ".htmlBody")
    attachments=$(echo "$data" | jq -r ".attachments | length")

    # If you get an email that is in pure text, the .htmlBody field will be empty and
    # we will need to get the content from .textBody instead
    [ -z "$html_body" ] && html_body="<pre>$(echo "$data" | jq -r ".textBody")</pre>"

    # Create the HTML with all the information that is relevant and then
    # assigning that HTML to the variable html_mail. This is the best method
    # to create a multiline variable
    html_mail=$(
        cat <<EOF
<pre><b>To: </b>$email_address
<b>From: </b>$from
<b>Subject: </b>$subject
<b>Date: </b>$date</pre>
$html_body

EOF
    )

    if [ ! "$attachments" = "0" ]; then
        html_mail="$html_mail<br><b>[Attachments]</b><br>"

        index=1
        while [ "$index" -le "$attachments" ]; do
            filename=$(echo "$data" | jq -r ".attachments | .[$index-1] | .filename")
            link="$tempmail_api_url?action=download&login=$username&domain=$domain&id=$email_id&file=$filename"
            html_link="<a href=$link download=$filename>$filename</a><br>"

            if [ "$raw_text" = true ]; then
                # The actual url is way too long and does not look so nice in STDOUT.
                # Therefore we will shortening it using is.gd so that it looks nicer.
                link=$(curl -s -F"url=$link" "https://is.gd/create.php?format=simple")
                html_mail="$html_mail$link  [$filename]<br>"
            else
                html_mail="$html_mail$html_link"
            fi

            index=$((index + 1))
        done
    fi

    [[ $browser = "w3m" ]] && html_mail="$html_mail <br>[ Press q to exit w3m ]"

    # Save the $html_mail into $tempmail_html_email
    echo "$html_mail" >"$tempmail_html_email"

    # If the '--text' flag is used, then use 'w3m' to convert the HTML of
    # the email to pure text by removing all the HTML tags
    [ "$raw_text" = true ] && w3m -dump "$tempmail_html_email" && exit

    # Open up the HTML file using $browser. By default,
    # this will be 'w3m'.
    $browser "$tempmail_html_email"
}

view_recent_email() {
    # View the most recent email.
    #
    # This is done by listing all the received email like you
    # normally see on the terminal when running 'tempmail'.
    # We then grab the ID of the most recent
    # email, which the first line.
    mail_id=$(list_emails | head -4 | tail -1 | cut -d' ' -f 3)
    view_email "$mail_id"
}

print_error() {
    # Print error message
    #
    # The first argument provided to this function will be the error message.
    # Script will exit after printing the error message.
    echo "Error: $1" >&2
    exit 1
}

ascii() {
    # Color codes
    CL_GRN="\033[1;32m"
    CL_RST="\033[0m"

    # Print a colorful ASCII at first
    echo -e "${CL_GRN}" "  _____                     ___  ___      _ _  " "${CL_RST}"
    echo -e "${CL_GRN}" " |_   _|                    |  \/  |     (_) | " "${CL_RST}"
    echo -e "${CL_GRN}" "   | | ___ _ __ ___  _ __   | .  . | __ _ _| | " "${CL_RST}"
    echo -e "${CL_GRN}" "   | |/ _ \ '_ ' _ \| '_ \  | |\/| |/ _' | | | " "${CL_RST}"
    echo -e "${CL_GRN}" "   | |  __/ | | | | | |_) | | |  | | (_| | | | " "${CL_RST}"
    echo -e "${CL_GRN}" "   \_/\___|_| |_| |_| .__/  \_|  |_/\__,_|_|_| " "${CL_RST}"
    echo -e "${CL_GRN}" "                    | |                        " "${CL_RST}"
    echo -e "${CL_GRN}" "                    |_|                        " "${CL_RST}"
    echo
    echo -e "Welcome to 𝒯𝑒𝓂𝓅 Mail, India's next number one temporary mail generator service.\nSay no to spam mails and use your official mail id without advertisements."
}

main() {
    # Iterate of the array of dependencies and check if the user has them installed.
    # We are checking if $browser is installed instead of checking for 'w3m'. By doing
    # this, it allows the user to not have to install 'w3m' if they are using another
    # browser to view the HTML
    for dependency in jq $browser curl; do
        if ! command -v "$dependency" >/dev/null 2>&1; then
            print_error "Could not find '$dependency', is it installed?"
        fi
    done

    # Create the $tempmail_dir directory and dont throw any errors
    # if it already exists
    mkdir -p "$tempmail_dir"

    # Get the email address and save the value to the email_address variable
    email_address="$(get_email_address)"

    # ${VAR#PATTERN} Removes shortest match of pattern from start of a string.
    # In this case, it takes the email_address and removed everything after
    # the '@' symbol which gives us the username.
    username=${email_address%@*}

    # ${VAR%PATTERN} Remove shortest match of pattern from end of a string.
    # In this case, it takes the email_address and removes everything until the
    # period '.' which gives us the domain
    domain=${email_address#*@}

    # If no arguments are provided then print our ASCII and usage
    [[ $# -eq 0 ]] && ascii && echo && usage

    while [ "$1" ]; do
        case "$1" in
        --browser | -b) browser="$2" ;;
        --list | -l) list_emails && exit ;;
        --directory | -d) directory "$@" && exit ;;
        --generate | -g) generate_email_address true "$2" && exit ;;
        --help | -h) usage && exit ;;
        --recent | -r) view_recent_email && exit ;;
        --text | -t) raw_text=true ;;
        --version | -v) echo "$version" && exit ;;
        *[0-9]*)
            # If the user provides number as an argument,
            # assume its the ID of an email and try getting
            # the email that belongs to the ID
            view_email "$1" && exit
            ;;
        -*) print_error "option '$1' does not exist" ;;
        esac
        shift
    done
}

main "$@"
