#!/bin/bash

# Exit on error
set -e

# Variables
MAVEN_VERSION="3.9.9"
SONARQUBE_VERSION="9.9.1.69595"

# Functions for messages
info() { echo -e "\n\e[1;34m[INFO] $1\e[0m"; }
error() { echo -e "\n\e[1;31m[ERROR] $1\e[0m" >&2; }

# Log output
exec > >(tee -i setup.log) 2>&1

# Update system packages
info "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Java 17 (required for SonarQube and Jenkins)
info "Installing Java 17..."
sudo apt install -y openjdk-17-jdk
java -version || { error "Java installation failed"; exit 1; }

# Install Jenkins
info "Setting up Jenkins repository..."
sudo wget -q -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
info "Installing Jenkins..."
sudo apt install -y jenkins

# Enable, start, and verify Jenkins
info "Enabling and starting Jenkins service..."
sudo systemctl enable jenkins
sudo systemctl start jenkins || {
  error "Jenkins service failed to start. Check system logs with 'sudo journalctl -xe'."
  exit 1
}
sudo systemctl status jenkins --no-pager

# Install Terraform
info "Installing Terraform..."
sudo apt install -y gnupg software-properties-common
wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install -y terraform
terraform --version || { error "Terraform installation failed"; exit 1; }

# Install Ansible
info "Installing Ansible..."
sudo apt install -y python3-pip
sudo pip3 install ansible
ansible --version || { error "Ansible installation failed"; exit 1; }

# Install Git
info "Installing Git..."
sudo apt install -y git

# Install Maven
info "Installing Maven version $MAVEN_VERSION..."
wget -q https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz
sudo tar -xvzf apache-maven-${MAVEN_VERSION}-bin.tar.gz -C /opt

# Force create the symbolic link, overwriting if it already exists
sudo ln -sf /opt/apache-maven-${MAVEN_VERSION} /opt/maven

# Update PATH for Maven
echo 'export PATH=$PATH:/opt/maven/bin' | sudo tee /etc/profile.d/maven.sh
sudo chmod +x /etc/profile.d/maven.sh
source /etc/profile.d/maven.sh

# Clean up
rm apache-maven-${MAVEN_VERSION}-bin.tar.gz

# Verify Maven installation
mvn -version || { error "Maven installation failed"; exit 1; }


# Install required packages for SonarQube
info "Installing SonarQube version $SONARQUBE_VERSION..."
sudo apt install -y unzip

# Create a user for SonarQube (if it doesn't exist)
if ! id "sonar" &>/dev/null; then
    sudo useradd -m -d /opt/sonarqube sonar
fi

# Download and install SonarQube
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONARQUBE_VERSION}.zip
sudo unzip sonarqube-${SONARQUBE_VERSION}.zip -d /opt

# Remove any existing SonarQube directory and move the extracted directory
sudo mv /opt/sonarqube-${SONARQUBE_VERSION} /opt/sonarqube

# Set proper permissions for SonarQube directory
sudo chown -R sonar:sonar /opt/sonarqube

# Switch to the sonar user and start SonarQube
sudo su - sonar -c "/opt/sonarqube/sonarqube-${SONARQUBE_VERSION}/bin/linux-x86-64/sonar.sh start" || {
  error "SonarQube failed to start. Check logs in /opt/sonarqube/logs."
  exit 1
}

# Output SonarQube status (as sonar user)
sudo su - sonar -c "/opt/sonarqube/sonarqube-${SONARQUBE_VERSION}/bin/linux-x86-64/sonar.sh status"

# Clean up downloaded files
rm -f sonarqube-${SONARQUBE_VERSION}.zip

# Output SonarQube status
echo "SonarQube is now running."

# Show Jenkins initial password
info "Displaying initial Jenkins admin password..."
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

info "Setup completed successfully!"
