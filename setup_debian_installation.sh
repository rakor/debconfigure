#!/bin/sh

#######################
#
# Script to setup a fresh Debain installation for my personal needs
#
#######################

# Default programs to install
PAKETE="vim apt-transport-https ufw git fish wget aptitude curl bzip2"


# Programpaths
WHICH=/usr/bin/which
APT=/usr/bin/apt
GIT=/usr/bin/git
UFW=/usr/sbin/ufw
CHSH=/usr/bin/chsh
FISH=/usr/bin/fish
WGET=/usr/bin/wget
UNZIP=/usr/bin/unzip
APTITUDE=/usr/bin/aptitude
CURL=/usr/bin/curl
BZIP=/bin/bzip2



# Where is restic located?
set_restic()
{
    # Defaultpath if nothing is found
    DEF_RESTIC_PATH=/usr/local/bin/restic
	RESTIC=`$WHICH restic`
	if [ -z $RESTIC ]; then
		echo "There was no restic found! We assume $DEF_RESTIC_PATH"
		RESTIC=$DEF_RESTIC_PATH
	else
		echo "Restic was found in $RESTIC"
	fi
}


####
# check for root
if [ `id -u` -ne 0 ]; then
	echo "This script must be run as root."
	exit 1
fi

####
# Ask for username
USERSET=N
while [ ! $USERSET = "Y" ]; do
    read -p "Please enter the username of your defaultuser: " USER
    while true; do
        read -p "Do you want to use username \"${USER}\" (y/n) " yn
        case $yn in 
            [Yy]* ) USERSET=Y;
                    if ! grep -q "^${USER}:" /etc/passwd ; then
                        echo "The username was not found in /etc/passwd."
                        USERSET=N
                    fi
                    break;;
            [nN]* ) USERSET=N; break;;
            * ) echo "Please anser y or n ";;
        esac
    done
done
echo "Username \"${USER}\" will be used as default username."




####
# Ask for restic
while true; do
    read -p "Restic: Install from official Debian package [p], from upstream-repository on github [u], or don't install at all [n] " yn
    case $yn in
        [Pp]* ) INSTRESTIC=P; break;;
        [Uu]* ) INSTRESTIC=U; break;;
        [Nn]* ) break;;
        * ) echo "Please answer p, u or n";;
    esac
done


####
# Ask for syncthing
while true; do
    read -p "Syncthing: Install from official Debian package [p], add upstream-repository to install [u], or don't install at all [n] " yn
    case $yn in
        [Pp]* ) SYNCTHING=P; break;;
        [Uu]* ) SYNCTHING=U; break;;
        [Nn]* ) break;;
        * ) echo "Please answer p, u or n";;
    esac
done

while true; do
    read -p "Open firewall for syncthing? (y/n) " yn
    case $yn in
        [Yy]* ) SYNCTHINGFW=Y; break;;
        [Nn]* ) break;;
        * ) echo "Please answer y or n";;
    esac
done


######
# Install default packages
# don't install anything from cd.
sed -i_old -e "s/^\s*deb\s*cdrom/#deb cdrom/" /etc/apt/sources.list
$APT update
$APT install $PAKETE -y
#now curl, wget, unzip eg are available


#####
# Restic Installtion
if [ $INSTRESTIC = "P" ]; then
    echo "Restic will be installed from the official Debian package"
    ZUSAETZLICHEPAKETE="$ZUSAETZLICHEPAKETE restic"
fi
if [ $INSTRESTIC = "U" ]; then
    echo "Restic will be downloaded from Github"
    RESTICURL=`curl -s https://api.github.com/repos/restic/restic/releases/latest | grep browser_download_url | grep linux_amd64 | cut -d '"' -f 4`
    $WGET $RESTICURL
    RESTICDLFILENAME=`basename $RESTICURL`
    $BZIP -d $RESTICDLFILENAME
    RESTICFILENAMEUNZIP=`echo $RESTICDLFILENAME | /bin/sed -e "s/\.[^\.]*$//"`
    /bin/mv $RESTICFILENAMEUNZIP /usr/local/bin/restic
    /bin/chmod 755 /usr/local/bin/restic
    /bin/chown root:root /usr/local/bin/restic
fi

####
# Syncthing installation
if [ $SYNCTHING = "P" ]; then
    echo "Syncthing will be installed from the official Debian package"
    ZUSAETZLICHEPAKETE="$ZUSAETZLICHEPAKETE syncthing"
fi

if [ $SYNCTHING = "U" ]; then
    echo "Upstream Repository for Syncthing will ne added" # from https://apt.syncthing.net/ übernommen
    $CURL -s https://syncthing.net/release-key.txt | /usr/bin/apt-key add -
    echo "deb https://apt.syncthing.net/ syncthing stable" | /usr/bin/tee /etc/apt/sources.list.d/syncthing.list
    ZUSAETZLICHEPAKETE="$ZUSAETZLICHEPAKETE syncthing"
fi

####
# install additional packages
$APT update
$APT install $ZUSAETZLICHEPAKETE -y


######
# install my restic-backupscript 
set_restic
$WGET https://github.com/rakor/resticbackupscript/archive/master.zip
$UNZIP master.zip
/bin/rm master.zip
/bin/sh resticbackupscript-master/install.sh
/bin/sed -e "s[^\s*RESTIC=.*\$[RESTIC=$RESTIC[" resticbackupscript-master/resticrc_debian > /root/.resticrc
/bin/rm -rf resticbackupscript-master
echo "#!/bin/sh\n/usr/local/bin/resticbackup cron" > /etc/cron.hourly/backup
/bin/chmod 755 /etc/cron.hourly/backup


####
# Backup of packagelist
echo "#!/bin/sh\n$APTITUDE search --disable-columns -F%p '~i!~M!~v' > /root/package_list" > /etc/cron.daily/paketliste_erstellen 
/bin/chmod 755 /etc/cron.daily/paketliste_erstellen


####
# enable UFW
$UFW enable
$UFW status verbose

if [ $SYNCTHINGFW = "Y" ]; then
    $UFW allow syncthing
fi

####
# set FISH
$CHSH -s $FISH $USER


####
# vimrc
$WGET https://raw.githubusercontent.com/rakor/config/master/home/.vimrc
/bin/cp .vimrc /root
/bin/chown root:root /root/.vimrc
/bin/chmod 644 /root/.vimrc
/bin/cp .vimrc /home/$USER
/bin/chown $USER:$USER /home/$USER/.vimrc
/bin/chmod 644 /home/$USER/.vimrc
/bin/mkdir -p /root/.vim/colors
/bin/mkdir -p /home/$USER/.vim/colors
$WGET https://raw.githubusercontent.com/tomasr/molokai/master/colors/molokai.vim -O /home/$USER/.vim/colors/molokai.vim
/bin/cp /home/$USER/.vim/colors/molokai.vim /root/.vim/colors/molokai.vim
/bin/chown $USER:$USER -R /home/$USER/.vim


####
# configure the shell of root
/bin/mv /root/.bashrc /root/.bashrc_old
$WGET https://raw.githubusercontent.com/rakor/config/master/root/.bashrc -O /root/.bashrc


####
# Ask for microcode
while true; do
    echo "\n######  YOUR /etc/apt/sources.list  ######"
    /bin/cat /etc/apt/sources.list
    echo "##########################################\n"
    echo "You need to have \"non-free\" and \"contrib\" activated in sources.list to install the microcode"
    read -p "Do you want to install intel-microcode (y/n) " yn
    case $yn in 
        [Yy] ) $APT install intel-microcode; break;;
        [Nn] ) break;;
        * ) echo "Please anser y or n" ;;
    esac
done


####
# Comments
if [ ! $INSTRESTIC = "N" ]; then
    echo "\n###################################################################\n"
    echo "RESTIC"
    echo "======"
    echo "Please don't forget to set repository and password for the restic-backups in /root/.resticrc."
    echo "Then you have to 'resticcmd init' the repository if it is a new one."
fi

if [ ! $SYNCTHING = "N" ]; then
    echo "\n"
    echo "Syncthing"
    echo "========="
    echo "If you want to start syncthing automatically at logon of your"
    echo "user run as user $USER:"
    echo "  systemctl --user enable syncthing.service"
    echo "  systemctl --user start syncthing.service"
    echo "Syncthing will be listening on Port 8384 for the Webinterface"
    echo "If you also want to allow external access to the Syncthing web GUI, run:"
    echo "  ufw allow syncthing-gui"
    echo "Allowing external access is not necessary for a typical installation."
fi
