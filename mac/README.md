# Instructions for Mac Users

1. Download the “Molecula_Sandbox.sh” script in this repository to the “Downloads” folder.
2. Open the “Terminal” application that exists on your mac.
- You can search for it by clicking the magnifying glass in the top right corner and  typing “terminal”
3. Complete steps 4- 7 by copying commands and pasting them into the terminal window.
4. Navigate to where the script was downloaded by typing or pasting this command in Terminal and pressing ‘ENTER’ 

`cd Downloads`

5. Verify you can see the Molecula_Sandbox.sh file by typing the command below in Terminal and pressing ‘ENTER’:

`ls -lrt`

6. In order to run the script, you must first type the command below in Terminal and press ‘ENTER’:

`chmod +x Molecula_Sandbox.sh`

7. Run the script by typing the command below in Terminal and pressing ‘ENTER’:

`zsh Molecula_Sandbox.sh`

- NOTE: Macs now uses zsh as the default shell since macOS Catalina. If you are olding on an older operating system or the above command did not work for you, you may try the follwing and press enter:

`./Molecula_Sandbox.sh`

8. Enter Username (email)
9. Enter Password (created during UI sign up)
- NOTE: this will not show up visibly in the terminal, but it’s there! This to protect your information. 

The script is now configuring your environment which will take approximately 30 minutes. Navigate back to the [web application][1] to check on your deployment, data tables, and to start exploring the data. 
While the deployment is spinning up, you will see messages in Terminal and in Cloud Manager as the status progresses.



[1]: https://app.molecula.cloud/ "Title"