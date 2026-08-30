FROM tomcat:11.0.25-jdk21-temurin-noble

# https://get.jenkins.io/war-stable/2.568.2/jenkins.war
COPY downloads/jenkins.war /usr/local/tomcat/webapps/jenkins.war

#https://search.maven.org/remotecontent?filepath=org/jolokia/jolokia-agent-war/2.6.1/jolokia-agent-war-2.6.1.war
COPY downloads/jolokia.war /usr/local/tomcat/webapps/jolokia.war

# Autenticação do Tomcat 
COPY docker/tomcat-users.xml /usr/local/tomcat/conf/tomcat-users.xml

# Permite a leitura de Variáveis de ambiente do Tomcat
ENV CATALINA_OPTS="-Dorg.apache.tomcat.util.digester.PROPERTY_SOURCE=org.apache.tomcat.util.digester.EnvironmentPropertySource"