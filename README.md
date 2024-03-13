This is new branch for code6004
```bash
# 系统扩容
/bin/echo "d
4
n
4
N
w
" | fdisk -c -u /dev/mmcblk1
# 上面这一步解释为：对于设备mmcblk1的p4分区(即所需扩容的root)，删除(d)该分区,新建(n)之,不修改签名(N),并保存退出(w)
# 这一操作也可简单使用 "growpart /dev/mmcblk1 4" 替换
resize2fs  /dev/mmcblk1p4

# 准备数据库服务
sudo dnf -y install postgresql postgresql-server postgresql-jdbc postgresql-contrib
sudo postgresql-setup --initdb --unit postgresql
sudo systemctl enable postgresql
sudo systemctl start postgresql

# 添加database和user
sudo su - postgres
psql <<EOF
CREATE USER atlas WITH PASSWORD 'atlas';
CREATE DATABASE atlas WITH ENCODING 'UNICODE' LC_COLLATE 'C' LC_CTYPE 'C' TEMPLATE template0;
GRANT ALL PRIVILEGES ON DATABASE atlas TO atlas;
\c atlas postgres
GRANT ALL ON SCHEMA public TO atlas;
EOF
exit

# 调整连接认证方式
sudo sed -i 's/ident/trust/g' /var/lib/pgsql/data/pg_hba.conf
sudo systemctl restart postgresql
# 测试数据库连接
# psql -h 127.0.0.1 -U atlas -W -d atlas

# 新增jira用户
useradd -d /home/jira -m -s /bin/bash jira
echo jira | passwd --stdin jira > /dev/null
usermod -a -G root jira
echo "jira     ALL=(ALL)     NOPASSWD: ALL" >> /etc/sudoers
su jira
cd ~

# 准备Java环境
sudo dnf install -y java-17-openjdk java-17-openjdk-devel gcc gcc-c++ pcre pcre-devel zlib zlib-devel openssl openssl-devel
echo "export JAVA_HOME=$(dirname $(dirname $(readlink $(readlink $(which javac)))))" >> ~/.bashrc
echo "export JRE_HOME=\${JAVA_HOME}/../jre" >> ~/.bashrc
source ~/.bashrc

# 准备jira
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

# 配置jira home
sudo sed -i 's#jira.home =.*#jira.home = /home/jira/jira_workspace/jirasoftware-home#g' \
    ./jirasoftware-installation/atlassian-jira-software-9.12.1-standalone/atlassian-jira/WEB-INF/classes/jira-application.properties

# 配置jira与数据库的连接
cat << EOF > ./jirasoftware-home/dbconfig.xml
<?xml version="1.0" encoding="UTF-8"?>
<jira-database-config>
  <name>defaultDS</name>
  <delegator-name>default</delegator-name>
  <database-type>postgres72</database-type>
  <schema-name>public</schema-name>
  <jdbc-datasource>
    <url>jdbc:postgresql://127.0.0.1:5432/atlas</url>
    <driver-class>org.postgresql.Driver</driver-class>
    <username>atlas</username>
    <password>atlas</password>
    <pool-min-size>40</pool-min-size>
    <pool-max-size>40</pool-max-size>
    <pool-max-wait>30000</pool-max-wait>
    <validation-query>select 1</validation-query>
    <min-evictable-idle-time-millis>60000</min-evictable-idle-time-millis>
    <time-between-eviction-runs-millis>300000</time-between-eviction-runs-millis>
    <pool-max-idle>40</pool-max-idle>
    <pool-remove-abandoned>true</pool-remove-abandoned>
    <pool-remove-abandoned-timeout>300</pool-remove-abandoned-timeout>
    <pool-test-on-borrow>false</pool-test-on-borrow>
    <pool-test-while-idle>true</pool-test-while-idle>
    <connection-properties>tcpKeepAlive=true;socketTimeout=240</connection-properties>
  </jdbc-datasource>
</jira-database-config>
EOF

# 准备agent
wget http://124.222.2.135/zip/atlassian-agent-v1.3.1.zip
unzip atlassian-agent-v1.3.1.zip
export LIB_PATH=$(realpath ./jirasoftware-installation)"/atlassian-jira/WEB-INF/lib/"
export JAVA_OPTS="-javaagent:/home/jira/jira_workspace/atlassian-agent-v1.3.1/atlassian-agent.jar=${LIB_PATH}"
echo "export JAVA_OPTS='${JAVA_OPTS}'" >> ~/.bashrc
source ~/.bashrc

# 启动jira
cd ./jirasoftware-installation/atlassian-jira-software-9.12.1-standalone/bin
./start-jira.sh

# 浏览器访问 http://localhost:8080，过程会需要根据网页上提供的key(XXXX-XXXX-XXXX-XXXX)，生成agent提供的密钥，使用下面的命令，将生成的密钥粘贴到网页
java -jar atlassian-agent.jar -m 'jira@gmail.com' -p jira -o 'http://localhost:8080' -s 'XXXX-XXXX-XXXX-XXXX'

# 流程结束
```
