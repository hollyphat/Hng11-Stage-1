#!/bin/bash

# Define the variable to accept input file
INPUT_FILE="$1"

# Check if file exist

#if [ ! -f INPUT_FILE ]; then
#    echo "File does not exist!"
#    exit 1
#fi


# Define the log file and password file
USER_INPUT_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a $USER_INPUT_FILE > /dev/null
}

# Function to generate random password
random_password() {    
    < /dev/urandom tr -dc 'A-Za-z0-9' | head -c 12
}

# Create neccessary directories if they do not exist
sudo mkdir -p /var/log
sudo mkdir -p /var/secure

# create log file if it does not exist, and set the neccessary permission
sudo touch $USER_INPUT_FILE
sudo chmod 600 $USER_INPUT_FILE

# create password file if it does not exist, and set the neccessary permission
sudo touch $PASSWORD_FILE
sudo chmod 600 $PASSWORD_FILE

# Read the input file line by line
while IFS=';' read -r username groups; do
    # Remove whitespace from username and group
    username=$(echo $username | xargs)
    groups=$(echo $groups | xargs)

    # Create the new user 
    if id -u "$username" >/dev/null 2>&1; then
        log_message "User $username already exists. Creation skipped."
    else
        sudo useradd -m -s /bin/bash "$username"
        if [ $? -eq 0 ]; then
            log_message "New user: $username created successfully."
        else
            log_message "Unable to create user: $username."
            continue
        fi
    fi

    # Create the new user personal group
    if ! getent group "$username" >/dev/null 2>&1; then
        sudo groupadd "$username"
        log_message "Personal group $username created successfully"
    fi

    # Add user to group
    sudo usermod -aG "$username" "$username"

    # Add the user to other groups
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        group=$(echo $group | xargs) # Remove whitespace
        if ! getent group "$group" >/dev/null 2>&1; then
            sudo groupadd "$group"
            log_message "Group $group created."
        fi
        sudo usermod -aG "$group" "$username"
        log_message "User $username added to group: $group."
    done

    # Generate a random password and set it for the created user
    password=$(random_password)
    echo "$username:$password" | sudo chpasswd
    echo "$username,$password" | sudo tee -a $PASSWORD_FILE > /dev/null

    log_message "Password set for user $username."
done < "$INPUT_FILE"

log_message "User creation script completed."
echo "User creation process is complete. Check $USER_INPUT_FILE for details"