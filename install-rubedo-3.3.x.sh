#!/bin/bash
##################################################################################################################
# Installation agent for Rubedo 3.3.x                     		      			 		 #
# This agent will follow these steps:					     					 #
# 1) MongoDB	                                        		     					 #
# 2) Java environment & Elasticsearch                   		     					 #
# 3) PHP and Apache                             						 		 #
# 4) Rubedo and git							     					 #
# For more details: http://docs.rubedo-project.org/en/homepage/install-rubedo 			 		 #
# Compatibility: Ubuntu 14.04 Trusty Tahr, Ubuntu 12.04 Precise Pangolin, Debian 7 Wheezy, CentOS 7 and Rhel     #
# Script for a 64 bits distribution                                                                              #
# Don't edit this script! Please edit the configuration file: data comes from this file	         		 #
# Usage: sudo ./script_name configuration_file token progress_file						 #
# configuration_file: file with configurations									 #
# token: Token of Github (go to your Github account)								 #
# progress_file: file with progression (if you want to resume after an error for example)			 #
##################################################################################################################

set -e # Exit immediately if a command exits with a non-zero status

get_distribution_type()	# Find the distribution type
{
	local lsb_dist
	lsb_dist="$(lsb_release -si 2> /dev/null || echo "unknown")"
	if [ "$lsb_dist" = "unknown" ]; then
		if [ -r /etc/lsb-release ]; then
			lsb_dist="$(. /etc/lsb-release && echo "$DISTRIB_ID")"
		elif [ -r /etc/debian_version ]; then
			lsb_dist='debian'
		elif [ -r /etc/centos-release ]; then
			lsb_dist='centos'
		elif [ -r /etc/redhat-release ]; then
			lsb_dist='rhel'
		elif [ -r /etc/os-release ]; then
			lsb_dist="$(. /etc/os-release && echo "$ID")"
		fi
	fi
	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
	echo $lsb_dist
}

load_config() # Load configurations from the configuration file
{
	count_line=`sed -n '$=' $CONFIGURATION_FILE`
	for i in `seq 1 $count_line`;
	do
       		temp=`sed -n ${i}p $CONFIGURATION_FILE`
		temp=`echo $temp|cut -d"=" -f2`
		if [ -z "$temp" ]
		then
			echo -ne "\n"
			echo "ERROR: The configuration file is invalid"
			echo "Please verify this file: $CONFIGURATION_FILE"
			exit 1
		fi
		pourcentage=$(($i * 100 / $count_line))
		echo -ne "INFO: Loading configurations: $i/$count_line -> $pourcentage%\r"
	done
	cluster_name="$RANDOM.$USER"
	link_script=`echo $(pwd)`
	source $CONFIGURATION_FILE
	echo -ne "INFO: Loading configurations: $i/$count_line -> $pourcentage% DONE\n"
	unset i && unset temp && unset pourcentage && unset count_line
}

load_progress() # Load progression from the progression file
{
	read ID STEP < $PROGRESS_FILE
}

if [ -f "logo" ]
then
	cat "logo"
	echo " "
fi
echo "Installation agent for Rubedo 3.3.x"
echo "WebTales 2016, Antoine LASSERRE"
echo " "

# Initialisation: verify some parameters before starting the installation
echo "INFO: Initialization..."
if [ $# != 3 ] # Nomber of argument is incorrect
then
	echo "ERROR: Argument number is incorrect"
	echo "Usage: sudo ./script_name configuration_file token progress_file"
	exit 1
fi

CONFIGURATION_FILE=$1
if [ -f $CONFIGURATION_FILE ] # File $1 found
then
	echo "INFO: Configuration file ($CONFIGURATION_FILE)"
	load_config $CONFIGURATION_FILE
else
   	echo "ERROR: Configuration file not found"
	echo "Please verify this path: $CONFIGURATION_FILE"
	exit 1
fi

TOKEN_GITHUB=$2
echo "INFO: Token of Github ($TOKEN_GITHUB)"


PROGRESS_FILE=$3
if [ -f $PROGRESS_FILE ] # File $3 found
then
	echo "INFO: Resume an installation" 
	load_progress $PROGRESS_FILE
	echo "INFO: ID ($ID) ; STEP ($STEP) DONE"
	if [ $ID_FILE != $ID ]
	then
		echo "ERROR: ID of this script ($ID_FILE) and ID of progress file ($ID) are different"
		echo "Big issues are possible with different IDs, installation is interrupted"
		exit 1
	fi
else
	echo "INFO: Starting the script from a blank system"
	STEP=0
	touch $PROGRESS_FILE
	echo "$ID_FILE 0" >> $PROGRESS_FILE
	echo "INFO: ID ($ID_FILE) ; STEP ($STEP) ; DONE"
fi

if [ "$(uname -m)" != "x86_64" ] # Architecture is not supported
then
	echo "ERROR: Unsupported architecture: $(uname -m)"
	echo "This script is for a 64 bits distribution"
	exit 1
fi
echo "INFO: Architecture ($(uname -m))"
echo "INFO: Initialization is complete"
echo -ne "Starting up in 3...\r"
sleep 1
echo -ne "Starting up in 2...\r"
sleep 1
echo -ne "Starting up in 1...\r"
sleep 1
echo -ne "Starting up...     \r"
echo -ne "\n"
echo " "

echo "INFO: Type of distribution ($(get_distribution_type))"

case "$(get_distribution_type)" in
	ubuntu|debian)
		echo "INFO: Type of distribution is correct, the setup agent will continue"

		case "$(get_distribution_type)" in
                        ubuntu)
				version=`sed -n 2p /etc/lsb-release`			
                        ;;
                        debian)
				version=`sed -n 1p /etc/issue`
                        ;;
		esac
				
		echo "INFO: Step 1: MongoDB"
		if [ $STEP -le 0 ]
		then
			echo "INFO: Import the public key used by the package management system..."
			apt-key adv --keyserver $MONGODB_PUBLICKEY_KEYSERVER_ALLDEB --recv $MONGODB_PUBLICKEY_RECV_ALLDEB
			STEP=1
			sed -i '1 s/0/1/' $PROGRESS_FILE
		fi
		if [ $STEP -le 1 ]
		then
			echo "INFO: Create a list file for MongoDB..."
			echo "INFO: Distribution release ($version)"
			case "$version" in # Détection de la version
				"DISTRIB_RELEASE=14.04")
					echo "deb $MONGODB_LISTFILE_UBUNTU14_DEB" | tee $MONGODB_LISTFILE_ALLDEB_TEE
				;;
				"DISTRIB_RELEASE=12.04")
					echo "deb $MONGODB_LISTFILE_UBUNTU12_DEB" | tee $MONGODB_LISTFILE_ALLDEB_TEE				
				;;
				"Debian GNU/Linux 7 \n \l")
					echo "deb $MONGODB_LISTFILE_DEBIAN7_DEB" | tee $MONGODB_LISTFILE_ALLDEB_TEE
				;;
				*)
					echo "ERROR: Version not supported"
					echo "For more details: $DOCUMENTATION_SETUP_URL"
					exit 1 
				;;
			esac
			STEP=2
			sed -i '1 s/1/2/' $PROGRESS_FILE
		fi	
		echo "INFO: Reload local package database..."
		apt-get update
		echo "INFO: Installation of the MongoDB packages..."
		apt-get install -y $MONGODB_PACKAGES_ALL
		echo "INFO: Restarting MongoDB..."
		service mongod restart
		echo "INFO: Installation of MongoDB is completed"

		echo "INFO: Step2: Java environment & Elasticsearch"
		echo "INFO: Installation of Java environment..."
		apt-get install -y $OPENJDK_PACKAGES_ALLDEB # Openjdk >= 7.x is needed
		echo "INFO: Updating Java environment..."
		update-java-alternatives -s $OPENJDK_UPDATE_ALLDEB # Choose openjdk-7 as a default version
		if [ $STEP -le 2 ]
		then
			echo "INFO: Import the public key used by the package management system..."
			wget -qO - $ELASTICSEARCH_PUBLICKEY_WGET_ALLDEB | apt-key add -
			STEP=3
			sed -i '1 s/2/3/' $PROGRESS_FILE
		fi
		if [ $STEP -le 3 ]
		then
			echo "INFO: Create a list file for Elasticsearch..."
			echo "deb $ELASTICSEARCH_LISTFILE_ALLDEB" | tee -a $ELASTICSEARCH_LISTFILE_TEE_ALLDEB
			STEP=4
			sed -i '1 s/3/4/' $PROGRESS_FILE
		fi
		echo "INFO: Reload local package database..."
		apt-get update
                echo "INFO: Installation of the Elasticsearch packages..."
                apt-get install -y $ELASTICSEARCH_PACKAGES_ALL
		if [ $STEP -le 4 ]
		then
			echo "INFO: Installation of plugins (1/2)..."
			$ELASTICSEARCH_PLUGIN_ONE_ALL
			STEP=5
			sed -i '1 s/4/5/' $PROGRESS_FILE
		fi
		if [ $STEP -le 5 ]
		then
			echo "INFO: Installation of plugins (2/2)..."
			$ELASTICSEARCH_PLUGIN_TWO_ALL
			STEP=6
			sed -i '1 s/5/6/' $PROGRESS_FILE
		fi
		if [ $STEP -le 6 ]
		then
			echo "INFO: Configuring Elasticsearch..."
			sed -i "$ELASTICSEARCH_CLUSTERNAME_REPLACEMENT" $ELASTICSEARCH_CONFIG_LINK
			sed -i "$ELASTICSEARCH_BINDHOST_REPLACEMENT" $ELASTICSEARCH_CONFIG_LINK
			update-rc.d $ELASTICSEARCH_AUTOLOAD_ALLDEB
			echo "INFO: Cluster.name: $cluster_name, host: 127.0.0.1, automatic start up activated"
			STEP=7
			sed -i '1 s/6/7/' $PROGRESS_FILE
		fi
		echo "INFO: Restarting Elasticsearch..."
		/etc/init.d/elasticsearch restart
		echo "INFO: Installation of Elasticsearch is completed"

		echo "INFO: Step3: PHP"
		if [ $STEP -le 7 ]
		then
			echo "INFO: Installation of the PHP packages..."
			echo "INFO: Distribution release ($version)"
                	case "$version" in # Détection de la version
                        	"DISTRIB_RELEASE=14.04")				
					apt-get install -y $PHP_PACKAGES_UBUNTU14
                        	;;
                        	"DISTRIB_RELEASE=12.04")	
					sudo add-apt-repository -y $PHP_ADDREPOSITORY # Default version of PHP is 5.3.x, or >= 5.4.x is needed
					apt-get update
                                	apt-get install -y $PHP_PACKAGES_UBUNTU12_DEBIAN
					pecl install -f $PHP_PECL_PACKAGES # Php5-mongo does not exist for apt-get in Ubuntu 12.04 LTS
					touch $PHP_CONFIG_LINK_ALLDEB
					echo "$PHP_CONFIG_WRITE" >> $PHP_CONFIG_LINK_ALLDEB
                       	 	;;
                        	"Debian GNU/Linux 7 \n \l")
					apt-get install -y $PHP_PACKAGES_UBUNTU12_DEBIAN
					pecl install -f $PHP_PECL_PACKAGES # Php5-mongo does not exist for apt-get in Debian 7
					touch $PHP_CONFIG_LINK_ALLDEB
					echo "$PHP_CONFIG_WRITE" >> $PHP_CONFIG_LINK_ALLDEB
                        	;;
                        	*)
                                	echo "ERROR: Version not supported"
                                	echo "For more details: $DOCUMENTATION_SETUP_URL"
                                	exit 1
                        	;;
                	esac
			STEP=8
			sed -i '1 s/7/8/' $PROGRESS_FILE
		fi
                if [ $STEP -le 8 ]
		then
			echo "INFO: Configuring PHP..."
			sed -i "$PHP_CONFIG_TIMEZONE_REPLACEMENT_ALLDEB" $PHP_CONFIG_LINK_PHPINI_ALLDEB
			STEP=9
			sed -i '1 s/8/9/' $PROGRESS_FILE
		fi
		echo "INFO: Installation of PHP is completed"

		echo "INFO: Step4: Rubedo"
		echo "INFO: Installation of Git..."
		apt-get install -y $GIT_PACKAGES_ALL
		if [ $STEP -le 9 ]
		then
			echo "INFO: Cloning Rubedo..."
			git clone -b "$GIT_CLONE_VERSION" $GIT_CLONE_LINK
			STEP=10
			sed -i '1 s/9/10/' $PROGRESS_FILE
		fi
		if [ $STEP -le 10 ]
		then
			echo "INFO: Configuring Apache..."
			case "$version" in # Détection de la version
				"DISTRIB_RELEASE=14.04")
					temp_tab=( ONE TWO THREE FOUR FIVE SIX )
					for a in `seq 0 5`;
					do
						temp="APACHE_UBUNTU14_REPLACEMENT_${temp_tab[$a]}"
						sed -i "$(eval echo \$$temp)" $APACHE_UBUNTU14_LINK
					done
					unset a && unset temp && unset temp_tab
				;;
				"DISTRIB_RELEASE=12.04")
					temp_tab=( ONE TWO THREE FOUR FIVE )
					for a in `seq 0 4`;
					do
						temp="APACHE_UBUNTU12_DEBIAN_REPLACEMENT_${temp_tab[$a]}"
						sed -i "$(eval echo \$$temp)" $APACHE_UBUNTU12_DEBIAN_LINK
					done
					unset a && unset temp && unset temp_tab
				;;
				"Debian GNU/Linux 7 \n \l")
					temp_tab=( ONE TWO THREE FOUR FIVE )
					for a in `seq 0 4`;
					do
						temp="APACHE_UBUNTU12_DEBIAN_REPLACEMENT_${temp_tab[$a]}"
						sed -i "$(eval echo \$$temp)" $APACHE_UBUNTU12_DEBIAN_LINK
					done
					unset a && unset temp && unset temp_tab
				;;
				*)
					echo "ERROR: Version not supported"
					echo "For more details: $DOCUMENTATION_SETUP_URL"
					exit 1
				;;
			esac
			STEP=11
			sed -i '1 s/10/11/' $PROGRESS_FILE
		fi
		if [ $STEP -le 11 ]
		then
			a2enmod rewrite
			temp_tab=( ONE TWO THREE )
			for a in `seq 0 2`;
			do
				temp="APACHE_ALLDEB_CONF_REPLACEMENT_${temp_tab[$a]}"
				sed -i "$(eval echo \$$temp)" $APACHE_ALLDEB_CONF_LINK
			done
			unset a && unset temp && unset temp_tab
			STEP=12
			sed -i '1 s/11/12/' $PROGRESS_FILE
		fi
		if [ $STEP -le 12 ]
		then
			echo "INFO: Adding a new host..."
			sed -i "$APACHE_NEWHOST_REPLACEMENT_ALL" $APACHE_NEWHOST_LINK_ALL
			STEP=13
			sed -i '1 s/12/13/' $PROGRESS_FILE
		fi
		if [ $STEP -le 13 ]
		then
			echo "INFO: Installing and preparing composer..."
			curl -sS $COMPOSER_LINK | php -- --install-dir=$COMPOSER_DESTINATION
			cd $COMPOSER_DESTINATION
   			php $COMPOSER_FILE config -g $COMPOSER_WEBSITEGIT "$TOKEN_GITHUB"
			echo "INFO: Installing dependencies..."
			$RUBEDO_INSTALL_SCRIPT
			cd $link_script
			STEP=14
			sed -i '1 s/13/14/' $PROGRESS_FILE
		fi
		if [ $STEP -le 14 ]
		then
			echo "INFO: Preparing the installation page..."
			temp_tab=( ONE TWO )
			for a in `seq 0 1`;
			do
				temp="INSTALL_REPLACEMENT_${temp_tab[$a]}"
				sed -i "$(eval echo \$$temp)" $INSTALL_LINK
			done
			unset a && unset temp && unset temp_tab
			STEP=15
			sed -i '1 s/14/15/' $PROGRESS_FILE
		fi
		echo "INFO: Restarting Apache..."
		service apache2 restart
		echo "INFO: Installation of Rubedo is completed"
	;;
	centos|rhel)
		echo "INFO: Type of distribution is correct, the setup agent will continue"

		echo "INFO: Step 1: MongoDB"
		if [ $STEP -le 0 ]
		then
			echo "INFO: Configuring the package management system..."
			touch $MONGODB_REPO
			temp_tab=( ONE TWO THREE FOUR FIVE )
			for a in `seq 0 4`;
			do
				temp="MONGODB_REPOSITORY_WRITE_${temp_tab[$a]}"
				echo "$(eval echo \$$temp)" >> $MONGODB_REPOSITORY_WRITE_LINK 
			done
			unset a && unset temp && unset temp_tab
			STEP=1
			sed -i '1 s/0/1/' $PROGRESS_FILE
		fi
		
		echo "INFO: Reload local package database..."
		yum -y update
		echo "INFO: Installing the MongoDB packages and associated tools..."
		yum install -y $MONGODB_PACKAGES_ALL
		echo "INFO: Starting MongoDB..."
		service mongod start
		echo "INFO: Installation of MongoDB is completed"

		echo "INFO: Step2: Java environment & Elasticsearch"
		echo "INFO: Installation of Java environment..."
		yum install -y $OPENJDK_PACKAGES_CENTOS # Openjdk >= 7.x is needed
		if [ $STEP -le 1 ]
		then
			echo "INFO: Downloading and installing the Public Signing Key..."
			rpm --import $ELASTICSEARCH_PUBLICKEY_CENTOS
			STEP=2
			sed -i '1 s/1/2/' $PROGRESS_FILE
		fi
		if [ $STEP -le 2 ]
		then
			echo "INFO: Configuring the package management system..."
			touch $ELASTICSEARCH_REPO
			temp_tab=( ONE TWO THREE FOUR FIVE SIX )
			for a in `seq 0 5`;
			do
				temp="ELASTICSEARCH_REPOSITORY_WRITE_${temp_tab[$a]}"
				echo "$(eval echo \$$temp)" >> $ELASTICSEARCH_REPOSITORY_WRITE_LINK
			done
			unset a && unset temp && unset temp_tab
			STEP=3
			sed -i '1 s/2/3/' $PROGRESS_FILE
		fi
		echo "INFO: Installing Elasticsearch..."
		yum install -y $ELASTICSEARCH_PACKAGES_ALL
		if [ $STEP -le 3 ]
		then
			echo "INFO: Activating automatic start-up for Elasticsearch..."
			for a in `seq 0 1`;
			do
				temp="ELASTICSEARCH_AUTOLOAD_CENTOS_${temp_tab[$a]}"
				command_autoload="$(eval echo \$$temp) $ELASTICSEARCH_AUTOLOAD_CENTOS_LINK"
				$command_autoload
			done
			unset a && unset temp && unset temp_tab && unset command_autoload
			STEP=4
			sed -i '1 s/3/4/' $PROGRESS_FILE
		fi
		if [ $STEP -le 4 ]
		then
			echo "INFO: Installation of plugins (1/2)..."
			$ELASTICSEARCH_PLUGIN_ONE_ALL
			STEP=5
			sed -i '1 s/4/5/' $PROGRESS_FILE
		fi
		if [ $STEP -le 5 ]
		then
			echo "INFO: Installation of plugins (2/2)..."
			$ELASTICSEARCH_PLUGIN_TWO_ALL
			STEP=6
			sed -i '1 s/5/6/' $PROGRESS_FILE
		fi
		if [ $STEP -le 6 ]
		then
			echo "INFO: Configuring Elasticsearch..."
			sed -i "$ELASTICSEARCH_CLUSTERNAME_REPLACEMENT" $ELASTICSEARCH_CONFIG_LINK
			sed -i "$ELASTICSEARCH_BINDHOST_REPLACEMENT" $ELASTICSEARCH_CONFIG_LINK
			echo "INFO: Cluster.name: $cluster_name, host: 127.0.0.1"
			STEP=7
			sed -i '1 s/6/7/' $PROGRESS_FILE
		fi
		echo "INFO: Starting Elasticsearch..."
		/etc/init.d/elasticsearch start
		echo "INFO: Installation of Elasticsearch is completed"

		echo "INFO: Step3: PHP"
		if [ $STEP -le 7 ]
		then
			echo "INFO: Installation of the PHP packages..."
			yum install -y $PHP_PACKAGES_CENTOS
			pecl install -f $PHP_PECL_PACKAGES
			echo "$PHP_CONFIG_WRITE" > $PHP_CONFIG_LINK_CENTOS
			STEP=8
			sed -i '1 s/7/8/' $PROGRESS_FILE
		fi
		if [ $STEP -le 8 ]
		then
			echo "INFO: Configuring PHP..."
			sed -i "$PHP_CONFIG_TIMEZONE_REPLACEMENT_ALLDEB" $PHP_CONFIG_LINK_PHPINI_CENTOS
			STEP=9
			sed -i '1 s/8/9/' $PROGRESS_FILE
		fi
		echo "INFO: Installation of PHP is completed"

		echo "INFO: Step4: Rubedo"
		echo "INFO: Installation of Git..."
		yum install -y $GIT_PACKAGES_ALL
		if [ $STEP -le 9 ]
		then
			echo "INFO: Cloning Rubedo..."
			git clone -b "$GIT_CLONE_VERSION" $GIT_CLONE_LINK
			STEP=10
			sed -i '1 s/9/10/' $PROGRESS_FILE
		fi
		if [ $STEP -le 10 ]
		then
			echo "INFO: Configuring Apache..."
			temp_tab=( ONE TWO THREE FOUR FIVE SIX )
			for a in `seq 0 5`;
			do
				temp="APACHE_CONFIG_CENTOS_REPLACEMENT_${temp_tab[$a]}"
				sed -i "$(eval echo \$$temp)" $APACHE_CONFIG_CENTOS_REPLACEMENT_LINK
			done
			unset a && unset temp && unset temp_tab
			STEP=11
			sed -i '1 s/10/11/' $PROGRESS_FILE
		fi
		if [ $STEP -le 11 ]
		then
			echo "INFO: Adding a new host..."
			sed -i "$APACHE_NEWHOST_REPLACEMENT_ALL" $APACHE_NEWHOST_LINK_ALL
			STEP=12
			sed -i '1 s/11/12/' $PROGRESS_FILE
		fi
		if [ $STEP -le 12 ]
		then
			echo "INFO: Installing and preparing composer..."
			curl -sS $COMPOSER_LINK | php -- --install-dir=$COMPOSER_DESTINATION
			cd $COMPOSER_DESTINATION
   			php $COMPOSER_FILE config -g $COMPOSER_WEBSITEGIT "$TOKEN_GITHUB"
			echo "INFO: Installing dependencies..."
			$RUBEDO_INSTALL_SCRIPT
			cd $link_script
			STEP=13
			sed -i '1 s/12/13/' $PROGRESS_FILE
		fi
		if [ $STEP -le 13 ]
		then
			echo "INFO: Preparing the installation page..."
			temp_tab=( ONE TWO )
			for a in `seq 0 1`;
			do
				temp="INSTALL_REPLACEMENT_${temp_tab[$a]}"
				sed -i "$(eval echo \$$temp)" $INSTALL_LINK
			done
			unset a && unset temp && unset temp_tab
			STEP=15
			sed -i '1 s/13/15/' $PROGRESS_FILE
		fi
		echo "INFO: Starting Apache..."
		apachectl start
		echo "INFO: Installation of Rubedo is completed"
		
	;;
	*)
		echo "ERROR: This script cannot detect the type of distribution or it's not supported"
		echo "For more details: $DOCUMENTATION_SETUP_URL"
		exit 1
	;;
esac
echo "INFO: Rubedo is now installed, but not operational"
echo "INFO: Go to rubedo.local/installation with a navigator to complete the installation"
echo "INFO: Thanks for using this agent"  
