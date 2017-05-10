# Version 0.0.3

FROM hubo/wildfly-jdk:latest

MAINTAINER HuBo <hubo@21cn.com>

USER root

RUN yum update -y && yum -y install openssh-server && yum clean all

RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key \
	&& ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key \
	&& ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key

USER jboss

# Set the WILDFLY_VERSION env variable
ENV WILDFLY_VERSION 10.1.0.Final

# Add the WildFly distribution to /opt, and make wildfly the owner of the extracted tar content
# Make sure the distribution is available from a well-known place
RUN cd $HOME && curl http://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz | tar zx && mv $HOME/wildfly-$WILDFLY_VERSION $HOME/wildfly

ENV MYSQL_CONNECTOR mysql-connector-java-5.1.42

RUN curl -LO http://dev.mysql.com/get/Downloads/Connector-J/$MYSQL_CONNECTOR.tar.gz

RUN tar xf $MYSQL_CONNECTOR.tar.gz

# Set the JBOSS_HOME env variable
ENV JBOSS_HOME /opt/jboss/wildfly

ENV JBOSS_CLI /opt/jboss/wildfly/bin/jboss-cli.sh -c

RUN /opt/jboss/wildfly/bin/add-user.sh jboss jboss --silent

RUN keytool -genkeypair -alias wildfly -keyalg RSA -keysize 2048 -keypass jbosswildfly -keystore /opt/jboss/wildfly/standalone/configuration/app.keystore -storepass jbosswildfly -dname "CN=HuBo,OU=wildfly,O=jboss,L=WH,ST=HB,C=CN" -validity 36500 -v

RUN /opt/jboss/wildfly/bin/standalone.sh --admin-only & sleep 30 \
	&& $JBOSS_CLI "module add --name=com.mysql --resources=$MYSQL_CONNECTOR/$MYSQL_CONNECTOR-bin.jar --dependencies=javax.api\,javax.transaction.api" \
	&& $JBOSS_CLI "/subsystem=datasources/jdbc-driver=mysql:add(driver-name=mysql,driver-module-name=com.mysql,driver-xa-datasource-class-name=com.mysql.jdbc.jdbc2.optional.MysqlXADataSource)" \
	&& $JBOSS_CLI "/core-service=management/security-realm=ApplicationRealm/server-identity=ssl:write-attribute(name=keystore-path,value=app.keystore)" \
	&& $JBOSS_CLI "/core-service=management/security-realm=ApplicationRealm/server-identity=ssl:write-attribute(name=keystore-password,value=jbosswildfly)" \
	&& $JBOSS_CLI "/core-service=management/security-realm=ApplicationRealm/server-identity=ssl:write-attribute(name=key-password,value=jbosswildfly)" \
	&& $JBOSS_CLI "/core-service=management/security-realm=ApplicationRealm/server-identity=ssl:write-attribute(name=alias,value=wildfly)" \
	&& $JBOSS_CLI "/subsystem=datasources/data-source=mysqluser:add(connection-url=jdbc:mysql://mysql:3306/wildfly?useSSL\=false,jndi-name=java:jboss/datasources/mysqluser,driver-name=mysql,user-name=jboss,password=jboss,enabled=true,use-ccm=true,jta=true)" \
	&& $JBOSS_CLI command=:shutdown \
	&& rm -rf $MYSQL_CONNECTOR.tar.gz \
	&& rm -rf $MYSQL_CONNECTOR \
	&& rm -rf /opt/jboss/wildfly/standalone/configuration/standalone_xml_history


VOLUME /opt/jboss/wildfly/standalone/deployments

EXPOSE 22 8080 8443 9990

CMD /usr/sbin/sshd -D


