FROM docker:19.03.5

LABEL "com.github.actions.color"="blue"
LABEL "com.github.actions.icon"="anchor"
LABEL "com.github.actions.name"="Monorepo container build action"
LABEL "com.github.actions.description"="Allows you to build a container by calling an existing build script and then push it via a supplied configuration."

ADD entry-point.sh /entry-point.sh
RUN chmod +x /entry-point.sh

ENTRYPOINT ["/entry-point.sh"]