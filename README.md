```bash
# 新增jira用户
useradd -d /home/jira -m -s /bin/bash jira
echo jira | passwd --stdin jira > /dev/null
usermod -a -G root jira
echo "jira     ALL=(ALL)     NOPASSWD: ALL" >> /etc/sudoers
su jira
cd

# 准备Java环境
sudo dnf install java-11-openjdk gcc gcc-c++ pcre pcre-devel zlib zlib-devel openssl openssl-devel
echo "export JAVA_HOME=$(dirname $(dirname $(readlink $(readlink $(which javac)))))" >> ~/.bashrc
echo "export JRE_HOME=$JAVA_HOME/jre" >> ~/.bashrc
echo "export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib" >> ~/.bashrc
echo "export PATH=$PATH:$JAVA_HOME:$JAVA_HOME/bin:$JRE_HOME/bin:$CLASSPATH" >> ~/.bashrc
source ~/.bashrc

# 准备数据库
sudo dnf install postgresql postgresql-server postgresql-jdbc java-11-openjdk
sudo postgresql-setup --initdb --unit postgresql # initialize PG cluster
sudo systemctl start postgresql                  # start cluster
sudo su - postgres                               # login as DB admin
psql                                             # enter psql shell

######################################################################
postgres=# CREATE USER rivai WITH PASSWORD 'rivai';
postgres=# CREATE DATABASE rivai_jiradb WITH ENCODING 'UNICODE' LC_COLLATE 'C' LC_CTYPE 'C' TEMPLATE template0;
postgres=# GRANT ALL PRIVILEGES ON DATABASE rivai_jiradb TO rivai;
postgres=# \c rivai_jiradb postgres
rivai=# GRANT ALL ON SCHEMA public TO rivai;
######################################################################

psql -h 127.0.0.1 -U rivai -W -d rivai_jiradb

mkdir jira_workspace
cd jira_workspace
mkdir -p ./{jirasoftware-installation,jirasoftware-home}
export JIRA_HOME=$(realpath ./jirasoftware-home)
chown -R jira jirasoftware-installation
chmod -R u=rwx,go-rwx jirasoftware-installation
chown -R jira jirasoftware-home
chmod -R u=rwx,go-rwx jirasoftware-home

# 准备agent
wget http://124.222.2.135/zip/atlassian-agent-v1.3.1.zip
unzip atlassian-agent-v1.3.1.zip
export LIB_PATH=$(realpath ./jirasoftware-installation)"/atlassian-jira/WEB-INF/lib/"
export JAVA_OPTS="-javaagent:/home/jira/jira_workspace/atlassian-agent.jar=${LIB_PATH}"

wget https://product-downloads.atlassian.com/software/jira/downloads/atlassian-jira-software-9.12.1.tar.gz
tar xzvf atlassian-jira-software-9.12.1.tar.gz -C jirasoftware-installation
cd jirasoftware-installation/atlassian-jira-software-9.12.1-standalone/bin
./config.sh
```
