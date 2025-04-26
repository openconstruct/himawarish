# himawarish
Pure shell replacement for himawaripy. downloads the current himawari-8 images and sets to wallpaper. tested in gnome, other DE please open an issue if it isn't working


To use, download and change permissions to be executable, if you want it to run every 10 minutes ( as intended), type 

    crontab -e

  then add the line and replace yourname with your linux username

    */10 * * * * /home/yourname/himawari.sh
