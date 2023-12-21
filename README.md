```bash
# 新增jira用户
useradd -d /home/jira -m -s /bin/bash jira
echo jira | passwd --stdin jira > /dev/null
usermod -a -G root jira
echo "jira     ALL=(ALL)     NOPASSWD: ALL" >> /etc/sudoers
su jira
cd

# 准备Java环境
sudo dnf install -y java-17-openjdk java-17-openjdk-devel gcc gcc-c++ pcre pcre-devel zlib zlib-devel openssl openssl-devel
echo "export JAVA_HOME=$(dirname $(dirname $(readlink $(readlink $(which javac)))))" >> ~/.bashrc
echo "export JRE_HOME=$JAVA_HOME/../jre" >> ~/.bashrc
source ~/.bashrc

# 准备数据库
sudo dnf install postgresql postgresql-server postgresql-jdbc postgresql-contrib
sudo postgresql-setup --initdb --unit postgresql 
sudo systemctl start postgresql
sudo su - postgres                               # login as DB admin
psql                                             # enter psql shell

######################################################################
CREATE USER atlas WITH PASSWORD 'atlas';
CREATE DATABASE atlas WITH ENCODING 'UNICODE' LC_COLLATE 'C' LC_CTYPE 'C' TEMPLATE template0;
GRANT ALL PRIVILEGES ON DATABASE atlas TO atlas;
\c atlas postgres
GRANT ALL ON SCHEMA public TO atlas;
######################################################################

psql -h 127.0.0.1 -U atlas -W -d atlas

mkdir jira_workspace
cd jira_workspace
mkdir -p ./{jirasoftware-installation,jirasoftware-home}
export JIRA_HOME=$(realpath ./jirasoftware-home)
chown -R jira jirasoftware-installation
chmod -R u=rwx,go-rwx jirasoftware-installation
chown -R jira jirasoftware-home
chmod -R u=rwx,go-rwx jirasoftware-home

wget https://product-downloads.atlassian.com/software/jira/downloads/atlassian-jira-software-9.12.1.tar.gz
tar xzvf atlassian-jira-software-9.12.1.tar.gz -C jirasoftware-installation
cd jirasoftware-installation/atlassian-jira-software-9.12.1-standalone/bin
./config.sh

# 准备agent
wget http://124.222.2.135/zip/atlassian-agent-v1.3.1.zip
unzip atlassian-agent-v1.3.1.zip
export LIB_PATH=$(realpath ./jirasoftware-installation)"/atlassian-jira/WEB-INF/lib/"
export JAVA_OPTS="-javaagent:/home/jira/jira_workspace/atlassian-agent-v1.3.1/atlassian-agent.jar=${LIB_PATH}"
```
